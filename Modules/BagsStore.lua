local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local BagsStore = vesperTools:NewModule("BagsStore", "AceEvent-3.0")
local L = vesperTools.L

-- BagsStore owns the live carried-bag snapshot for the current character and the
-- account-wide aggregate index used by the replacement inventory views.
local ITEM_CLASS = Enum and Enum.ItemClass or {}
local CURRENT_BAGS_SCHEMA_VERSION = 7
local NEW_CATEGORY_KEY = "new"
local NEW_ITEM_TIMEOUT_SECONDS = 3600
local BAG_CATEGORY_DEFS = {
    { key = "new", labelKey = "BAGS_CATEGORY_NEW", order = 0 },
    { key = "quest", labelKey = "BAGS_CATEGORY_QUEST", order = 1 },
    { key = "season", labelKey = "BAGS_CATEGORY_SEASON", order = 2 },
    { key = "junk", labelKey = "BAGS_CATEGORY_JUNK", order = 3 },
    { key = "reagent", labelKey = "BAGS_CATEGORY_REAGENT", order = 4 },
    { key = "enhancements", labelKey = "BAGS_CATEGORY_ENHANCEMENTS", order = 4.5 },
    { key = "consumable", labelKey = "BAGS_CATEGORY_CONSUMABLE", order = 5 },
    { key = "equipment", labelKey = "BAGS_CATEGORY_EQUIPMENT", order = 6 },
    { key = "recipe", labelKey = "BAGS_CATEGORY_RECIPE", order = 7 },
    { key = "tradegoods", labelKey = "BAGS_CATEGORY_TRADE_GOODS", order = 8 },
    { key = "container", labelKey = "BAGS_CATEGORY_CONTAINER", order = 9 },
    { key = "misc", labelKey = "BAGS_CATEGORY_MISC", order = 10 },
    { key = "past_expansions", labelKey = "BAGS_CATEGORY_PAST_EXPANSIONS", order = 100 },
}

local CATEGORY_ORDER = {}
local CATEGORY_LABEL_KEY_BY_ID = {}
local CATEGORY_PRIORITY_BY_ID = {}
local EXPANSION_CATEGORY_KEY_PREFIX = "expansion:"
local PAST_EXPANSIONS_CATEGORY_KEY = "past_expansions"
local LEGACY_SEASONAL_EQUIPMENT_TRACK_MARKERS = {
    "upgrade level: explorer",
    "upgrade level: adventurer",
    "upgrade level: veteran",
    "upgrade level: champion",
    "upgrade level: hero",
    "upgrade level: myth",
    "upgrade: explorer",
    "upgrade: adventurer",
    "upgrade: veteran",
    "upgrade: champion",
    "upgrade: hero",
    "upgrade: myth",
    "track: explorer",
    "track: adventurer",
    "track: veteran",
    "track: champion",
    "track: hero",
    "track: myth",
}
local SEASON_SPECIAL_ITEM_IDS = {
    [274476] = true, -- Spark of Tides (Midnight Season 2)
    [233071] = true, -- Delver's Bounty
    [235628] = true, -- Delver's Bounty with upgrade data
    [264414] = true, -- Midnight Delver's Flare Gun
    [253342] = true, -- Beacon of Hope
    [279382] = true, -- Venom-Cursed Fragment
    [273000] = true, -- Corrosive Soul
    [265714] = true, -- Trovehunter's Bounty
    [274374] = true, -- Trovehunter's Bounty (12.1 variant)
}
local SEASON_SPARK_NAME_PREFIXES = {
    "spark of ",
    "fractured spark of ",
}
for i = 1, #BAG_CATEGORY_DEFS do
    local def = BAG_CATEGORY_DEFS[i]
    CATEGORY_ORDER[i] = def.key
    CATEGORY_LABEL_KEY_BY_ID[def.key] = def.labelKey
    CATEGORY_PRIORITY_BY_ID[def.key] = def.order
end

local TRACKED_BAG_IDS = {}
local TRACKED_BAG_SET = {}

-- Build one canonical ordered list of carried bagIDs used by scanning and rendering.
local function addTrackedBagID(bagID)
    if type(bagID) ~= "number" or TRACKED_BAG_SET[bagID] then
        return
    end
    TRACKED_BAG_SET[bagID] = true
    TRACKED_BAG_IDS[#TRACKED_BAG_IDS + 1] = bagID
end

if Enum and Enum.BagIndex then
    addTrackedBagID(Enum.BagIndex.Backpack)
    addTrackedBagID(Enum.BagIndex.Bag_1)
    addTrackedBagID(Enum.BagIndex.Bag_2)
    addTrackedBagID(Enum.BagIndex.Bag_3)
    addTrackedBagID(Enum.BagIndex.Bag_4)
    addTrackedBagID(Enum.BagIndex.ReagentBag)
end

local function makeEmptyAggregate()
    return {
        itemTotals = {},
        categoryTotals = {},
        categoryItems = {},
    }
end

-- Resolve the localized display name shown for one carried bag.
local function getBagName(bagID)
    if bagID == (Enum and Enum.BagIndex and Enum.BagIndex.Backpack) then
        return BACKPACK_TOOLTIP or L["BAGS_BACKPACK"]
    end

    if C_Container and C_Container.GetBagName then
        local name = C_Container.GetBagName(bagID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    if GetBagName then
        local name = GetBagName(bagID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    return string.format("Bag %s", tostring(bagID))
end

-- Resolve the icon used for bag-slot summary buttons and headers.
local function getBagIcon(bagID)
    if bagID == (Enum and Enum.BagIndex and Enum.BagIndex.Backpack) then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end

    if C_Container and C_Container.ContainerIDToInventoryID then
        local inventoryID = C_Container.ContainerIDToInventoryID(bagID)
        if inventoryID then
            local texture = GetInventoryItemTexture("player", inventoryID)
            if texture then
                return texture
            end
        end
    end

    return "Interface\\Icons\\INV_Misc_Bag_08"
end

local function normalizeName(text)
    if type(text) ~= "string" then
        return nil
    end
    local trimmed = strtrim(text)
    if trimmed == "" then
        return nil
    end
    return trimmed
end

local function textContainsAnyMarker(text, markers)
    if type(text) ~= "string" or text == "" then
        return false
    end

    for i = 1, #markers do
        if text:find(markers[i], 1, true) then
            return true
        end
    end

    return false
end

local function textStartsWithAnyMarker(text, markers)
    if type(text) ~= "string" or text == "" then
        return false
    end

    for i = 1, #markers do
        if text:find(markers[i], 1, true) == 1 then
            return true
        end
    end

    return false
end

local function isKnownSeasonItemID(itemID)
    local numericID = tonumber(itemID)
    if not numericID then
        return false
    end

    numericID = math.floor(numericID + 0.5)
    return SEASON_SPECIAL_ITEM_IDS[numericID] and true or false
end

local function isSeasonSparkItem(meta, info)
    local isCraftingReagent = (info and info.isCraftingReagent) or (meta and meta.isCraftingReagent)
    if not isCraftingReagent then
        return false
    end

    local itemName = vesperTools:NormalizeSearchText((meta and meta.itemName) or (info and info.itemName) or "")
    return textStartsWithAnyMarker(itemName, SEASON_SPARK_NAME_PREFIXES)
end

local function normalizeExpansionID(expansionID)
    local numericID = tonumber(expansionID)
    if not numericID then
        return nil
    end

    numericID = math.floor(numericID + 0.5)
    if numericID < 0 then
        return nil
    end

    return numericID
end

local function normalizeRequiredLevel(requiredLevel)
    local numericLevel = tonumber(requiredLevel)
    if not numericLevel then
        return nil
    end

    numericLevel = math.floor(numericLevel + 0.5)
    if numericLevel <= 0 then
        return nil
    end

    return numericLevel
end

local function extractRequiredLevel(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    return normalizeRequiredLevel(text:match("requires level (%d+)"))
end

local function getExpansionIDFromCategoryKey(categoryKey)
    if type(categoryKey) ~= "string" then
        return nil
    end

    local suffix = string.match(categoryKey, "^" .. EXPANSION_CATEGORY_KEY_PREFIX .. "(%d+)$")
    if not suffix then
        return nil
    end

    return normalizeExpansionID(suffix)
end

local function canonicalizeCategoryKey(categoryKey)
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return "misc"
    end

    if categoryKey == PAST_EXPANSIONS_CATEGORY_KEY then
        return categoryKey
    end

    if getExpansionIDFromCategoryKey(categoryKey) ~= nil then
        return PAST_EXPANSIONS_CATEGORY_KEY
    end

    return categoryKey
end

local function getCurrentExpansionID()
    local currentExpansionID = normalizeExpansionID(_G and _G.LE_EXPANSION_LEVEL_CURRENT)
    if currentExpansionID ~= nil then
        return currentExpansionID
    end

    if type(GetServerExpansionLevel) == "function" then
        currentExpansionID = normalizeExpansionID(GetServerExpansionLevel())
        if currentExpansionID ~= nil then
            return currentExpansionID
        end
    end

    if type(GetExpansionLevel) == "function" then
        currentExpansionID = normalizeExpansionID(GetExpansionLevel())
        if currentExpansionID ~= nil then
            return currentExpansionID
        end
    end

    return nil
end

local function getCurrentExpansionMaxLevel()
    if type(GetMaxLevelForExpansionLevel) == "function" then
        local currentExpansionID = getCurrentExpansionID()
        if currentExpansionID ~= nil then
            local maxLevel = normalizeRequiredLevel(GetMaxLevelForExpansionLevel(currentExpansionID))
            if maxLevel ~= nil then
                return maxLevel
            end
        end
    end

    if type(GetMaxLevelForLatestExpansion) == "function" then
        local maxLevel = normalizeRequiredLevel(GetMaxLevelForLatestExpansion())
        if maxLevel ~= nil then
            return maxLevel
        end
    end

    if type(GetMaxLevelForPlayerExpansion) == "function" then
        local maxLevel = normalizeRequiredLevel(GetMaxLevelForPlayerExpansion())
        if maxLevel ~= nil then
            return maxLevel
        end
    end

    if type(GetMaxPlayerLevel) == "function" then
        local maxLevel = normalizeRequiredLevel(GetMaxPlayerLevel())
        if maxLevel ~= nil then
            return maxLevel
        end
    end

    return nil
end

local function getItemInfoRecord(itemRef)
    if not itemRef or itemRef == "" then
        return nil
    end

    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemRef)
    end

    if GetItemInfo then
        return GetItemInfo(itemRef)
    end

    return nil
end

local function getEmptySlotCountForBag(bag)
    if type(bag) ~= "table" then
        return 0
    end

    local size = math.max(0, tonumber(bag.size) or 0)
    if size == 0 then
        return 0
    end

    local used = 0
    local slots = type(bag.slots) == "table" and bag.slots or nil
    if not slots then
        return size
    end

    for slotID = 1, size do
        local record = slots[slotID]
        if type(record) == "table" and record.itemID then
            used = used + 1
        end
    end

    return math.max(0, size - used)
end

local function collectTooltipTextParts(tooltipData)
    if type(tooltipData) ~= "table" or type(tooltipData.lines) ~= "table" then
        return nil
    end

    local parts = {}
    for i = 1, #tooltipData.lines do
        local line = tooltipData.lines[i]
        if type(line) == "table" then
            local leftText = normalizeName(line.leftText or line.text)
            local rightText = normalizeName(line.rightText)

            if leftText then
                parts[#parts + 1] = leftText
            end
            if rightText then
                parts[#parts + 1] = rightText
            end
        end
    end

    if #parts == 0 then
        return nil
    end

    return parts
end

function BagsStore:OnInitialize()
    -- These flags buffer bag events until a single consolidated scan can run.
    self.dirtyBagSet = {}
    self.needsFullCarryRescan = false
    self.pendingBagUpdate = false
    self.pendingRescanReason = nil
    self.pendingInitialScan = false
    -- Ingesting C_NewItems flags before the login-noise clear has run would
    -- stamp the whole inventory as new; hold ingestion until then.
    self.suppressNewItemIngestion = true
    self.pendingItemBagIDs = {}
end

function BagsStore:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("BAG_CONTAINER_UPDATE")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
end

function BagsStore:GetDB()
    return vesperTools:GetBagsDB()
end

function BagsStore:GetProfile()
    return vesperTools:GetBagsProfile()
end

function BagsStore:GetGlobalDB()
    local db = self:GetDB()
    if not db then
        return nil
    end

    local global = db.global or {}
    db.global = global
    local schemaVersion = tonumber(global.schemaVersion) or 1
    global.schemaVersion = schemaVersion
    global.charactersByGUID = global.charactersByGUID or {}
    global.itemMeta = global.itemMeta or {}
    global.accountIndex = global.accountIndex or {}
    global.accountIndex.itemOwners = global.accountIndex.itemOwners or {}
    global.accountIndex.itemTotals = global.accountIndex.itemTotals or {}
    global.accountIndex.categoryTotals = global.accountIndex.categoryTotals or {}
    global.accountIndex.categoryItems = global.accountIndex.categoryItems or {}

    if schemaVersion < CURRENT_BAGS_SCHEMA_VERSION then
        local migrated = self:RunGlobalMigrations(global, schemaVersion)
        if not migrated then
            global.schemaVersion = schemaVersion
        end
    end

    return global
end

function BagsStore:GetTrackedBagIDs()
    return TRACKED_BAG_IDS
end

function BagsStore:GetCategoryKeys()
    return CATEGORY_ORDER
end

function BagsStore:IsTrackedBagID(bagID)
    return TRACKED_BAG_SET[bagID] and true or false
end

function BagsStore:GetCategoryDisplayName(categoryKey)
    categoryKey = canonicalizeCategoryKey(categoryKey)
    local labelKey = CATEGORY_LABEL_KEY_BY_ID[categoryKey]
    if labelKey then
        return L[labelKey]
    end

    return L["BAGS_CATEGORY_MISC"]
end

function BagsStore:GetCategoryOrder(categoryKey)
    categoryKey = canonicalizeCategoryKey(categoryKey)
    return CATEGORY_PRIORITY_BY_ID[categoryKey] or 999
end

function BagsStore:UpdateCurrentScaledLegacyEquipmentFlag(meta)
    if type(meta) ~= "table" then
        return false
    end

    local expansionID = normalizeExpansionID(meta.expansionID)
    local currentExpansionID = getCurrentExpansionID()
    local classID = meta.classID
    local searchText = meta.searchText or vesperTools:NormalizeSearchText(meta.itemDescription or "")
    local requiredLevel = normalizeRequiredLevel(meta.requiredLevel) or extractRequiredLevel(searchText)
    local currentExpansionMaxLevel = getCurrentExpansionMaxLevel()
    local isLegacySeasonalDungeonEquipment = expansionID ~= nil
        and currentExpansionID ~= nil
        and expansionID ~= currentExpansionID
        and (classID == ITEM_CLASS.Weapon or classID == ITEM_CLASS.Armor)
        and requiredLevel == nil
        and textContainsAnyMarker(searchText, LEGACY_SEASONAL_EQUIPMENT_TRACK_MARKERS)
    local isCurrentLevelLegacyEquipment = expansionID ~= nil
        and currentExpansionID ~= nil
        and expansionID ~= currentExpansionID
        and (classID == ITEM_CLASS.Weapon or classID == ITEM_CLASS.Armor)
        and requiredLevel ~= nil
        and currentExpansionMaxLevel ~= nil
        and requiredLevel >= currentExpansionMaxLevel
    local isCurrentScaledLegacyEquipment = isLegacySeasonalDungeonEquipment or isCurrentLevelLegacyEquipment

    meta.requiredLevel = requiredLevel
    meta.isLegacySeasonalDungeonEquipment = isLegacySeasonalDungeonEquipment and true or nil
    meta.isCurrentScaledLegacyEquipment = isCurrentScaledLegacyEquipment and true or nil
    return isCurrentScaledLegacyEquipment
end

-- Return the stable GUID-like key used for current-character bag storage.
function BagsStore:GetCurrentCharacterKey()
    return vesperTools:GetCurrentCharacterGUID()
end

-- Ensure the current-character record exists before scan results are written into it.
function BagsStore:CreateOrUpdateCurrentCharacter()
    local global = self:GetGlobalDB()
    if not global then
        return nil, nil
    end

    local characterKey = self:GetCurrentCharacterKey()
    local character = global.charactersByGUID[characterKey]
    if not character then
        character = {}
        global.charactersByGUID[characterKey] = character
    end

    local name = UnitName("player") or UNKNOWN
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
    local _, _, classID = UnitClass("player")
    local faction = UnitFactionGroup("player") or UNKNOWN

    character.guid = characterKey
    character.name = name
    character.realm = realm
    character.fullName = string.format("%s-%s", name, realm)
    character.classID = classID
    character.faction = faction
    character.lastSeen = time()
    character.carried = character.carried or { bags = {} }
    character.carried.bags = character.carried.bags or {}
    character.carried.itemTotals = character.carried.itemTotals or {}
    character.carried.categoryTotals = character.carried.categoryTotals or {}
    character.carried.categoryItems = character.carried.categoryItems or {}
    character.newItems = character.newItems or {}

    return characterKey, character
end

local function normalizeCurrencyID(currencyID)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID then
        return nil
    end

    numericCurrencyID = math.floor(numericCurrencyID + 0.5)
    if numericCurrencyID <= 0 then
        return nil
    end

    return numericCurrencyID
end

local function normalizeCurrencyQuantity(quantity)
    return math.max(0, math.floor((tonumber(quantity) or 0) + 0.5))
end

function BagsStore:AddCurrencySnapshotEntry(snapshot, seen, info)
    if type(snapshot) ~= "table" or type(info) ~= "table" then
        return false
    end

    local currencyID = normalizeCurrencyID(info.currencyID)
    if not currencyID or seen[currencyID] then
        return false
    end

    snapshot.currencies[currencyID] = {
        name = normalizeName(info.name),
        quantity = normalizeCurrencyQuantity(info.quantity),
        iconFileID = info.iconFileID,
        maxQuantity = normalizeCurrencyQuantity(info.maxQuantity),
        maxWeeklyQuantity = normalizeCurrencyQuantity(info.maxWeeklyQuantity),
        quantityEarnedThisWeek = normalizeCurrencyQuantity(info.quantityEarnedThisWeek),
        totalEarned = tonumber(info.totalEarned) or nil,
        discovered = info.discovered ~= false,
    }
    seen[currencyID] = true
    return true
end

function BagsStore:BuildCurrentCurrencySnapshot()
    local snapshot = {
        money = GetMoney and normalizeCurrencyQuantity(GetMoney()) or 0,
        currencies = {},
        scannedAt = time(),
    }
    local seen = {}

    if vesperTools.GetConfiguredBagCurrencyIDs and vesperTools.GetCurrencyInfoByID then
        local selectedIDs = vesperTools:GetConfiguredBagCurrencyIDs()
        for i = 1, #selectedIDs do
            local info = vesperTools:GetCurrencyInfoByID(selectedIDs[i])
            self:AddCurrencySnapshotEntry(snapshot, seen, info)
        end
    end

    if vesperTools.GetTrackedBagCurrencyOptions then
        local trackedOptions = vesperTools:GetTrackedBagCurrencyOptions()
        for i = 1, #trackedOptions do
            local option = trackedOptions[i]
            if option and option.currencyID and not seen[option.currencyID] and vesperTools.GetCurrencyInfoByID then
                option = vesperTools:GetCurrencyInfoByID(option.currencyID) or option
            end
            self:AddCurrencySnapshotEntry(snapshot, seen, option)
        end
    end

    if vesperTools.GetCurrencyBarSelectionOptions and vesperTools.GetCurrencyInfoByID then
        local selectionOptions = vesperTools:GetCurrencyBarSelectionOptions()
        for i = 1, #selectionOptions do
            local option = selectionOptions[i]
            if option and option.currencyID and not seen[option.currencyID] then
                self:AddCurrencySnapshotEntry(snapshot, seen, vesperTools:GetCurrencyInfoByID(option.currencyID) or option)
            end
        end
    end

    return snapshot
end

function BagsStore:CurrencySnapshotsEqual(a, b)
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    if normalizeCurrencyQuantity(a.money) ~= normalizeCurrencyQuantity(b.money) then
        return false
    end

    local aCurrencies = type(a.currencies) == "table" and a.currencies or {}
    local bCurrencies = type(b.currencies) == "table" and b.currencies or {}

    for currencyID, aEntry in pairs(aCurrencies) do
        local bEntry = bCurrencies[currencyID] or bCurrencies[tostring(currencyID)]
        if type(aEntry) ~= "table" or type(bEntry) ~= "table" then
            return false
        end
        if normalizeCurrencyQuantity(aEntry.quantity) ~= normalizeCurrencyQuantity(bEntry.quantity)
            or normalizeCurrencyQuantity(aEntry.maxQuantity) ~= normalizeCurrencyQuantity(bEntry.maxQuantity)
            or normalizeCurrencyQuantity(aEntry.maxWeeklyQuantity) ~= normalizeCurrencyQuantity(bEntry.maxWeeklyQuantity)
            or normalizeCurrencyQuantity(aEntry.quantityEarnedThisWeek) ~= normalizeCurrencyQuantity(bEntry.quantityEarnedThisWeek)
            or (tonumber(aEntry.totalEarned) or 0) ~= (tonumber(bEntry.totalEarned) or 0)
            or aEntry.name ~= bEntry.name
            or aEntry.iconFileID ~= bEntry.iconFileID
            or (aEntry.discovered ~= false) ~= (bEntry.discovered ~= false) then
            return false
        end
    end

    for currencyID in pairs(bCurrencies) do
        if aCurrencies[currencyID] == nil and aCurrencies[tonumber(currencyID) or currencyID] == nil then
            return false
        end
    end

    return true
end

function BagsStore:CommitCurrentCurrencySnapshot()
    local characterKey, character = self:CreateOrUpdateCurrentCharacter()
    if not characterKey or not character then
        return false
    end

    local newSnapshot = self:BuildCurrentCurrencySnapshot()
    if self:CurrencySnapshotsEqual(character.currency, newSnapshot) then
        return true
    end

    character.currency = newSnapshot
    vesperTools:SendMessage("VESPERTOOLS_BAGS_CHARACTER_UPDATED", characterKey)
    return true
end

function BagsStore:GetCharacterCurrencyQuantity(characterKey, currencyID, isGold)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    if not snapshot or type(snapshot.currency) ~= "table" then
        return nil, false
    end

    if isGold then
        return normalizeCurrencyQuantity(snapshot.currency.money), true
    end

    local normalizedCurrencyID = normalizeCurrencyID(currencyID)
    if not normalizedCurrencyID then
        return nil, false
    end

    local currencies = type(snapshot.currency.currencies) == "table" and snapshot.currency.currencies or {}
    local entry = currencies[normalizedCurrencyID] or currencies[tostring(normalizedCurrencyID)]
    if type(entry) == "table" then
        return normalizeCurrencyQuantity(entry.quantity), true
    end
    if entry ~= nil then
        return normalizeCurrencyQuantity(entry), true
    end

    return nil, false
end

-- Adjust nested aggregate counters while automatically cleaning up empty tables.
function BagsStore:AdjustNestedCount(container, parentKey, childKey, delta)
    if delta == 0 then
        return true
    end

    local parent = container[parentKey]
    if not parent then
        if delta < 0 then
            return false
        end
        parent = {}
        container[parentKey] = parent
    end

    local nextValue = (tonumber(parent[childKey]) or 0) + delta
    if nextValue < 0 then
        return false
    end

    if nextValue == 0 then
        parent[childKey] = nil
        if not next(parent) then
            container[parentKey] = nil
        end
    else
        parent[childKey] = nextValue
    end

    return true
end

-- Adjust one flat aggregate counter while avoiding negative totals.
function BagsStore:AdjustCount(container, key, delta)
    if delta == 0 then
        return true
    end

    local nextValue = (tonumber(container[key]) or 0) + delta
    if nextValue < 0 then
        return false
    end

    if nextValue == 0 then
        container[key] = nil
    else
        container[key] = nextValue
    end

    return true
end

-- Apply one character aggregate delta into the account-wide item/category index.
function BagsStore:ApplyAggregateToAccount(characterKey, aggregate, direction)
    local global = self:GetGlobalDB()
    if not global or not aggregate then
        return true
    end

    local sign = direction == "subtract" and -1 or 1
    local accountIndex = global.accountIndex

    for itemID, count in pairs(aggregate.itemTotals or {}) do
        if not self:AdjustCount(accountIndex.itemTotals, itemID, sign * count) then
            return false
        end
        if not self:AdjustNestedCount(accountIndex.itemOwners, itemID, characterKey, sign * count) then
            return false
        end
    end

    for categoryKey, count in pairs(aggregate.categoryTotals or {}) do
        local canonicalCategoryKey = canonicalizeCategoryKey(categoryKey)
        if not self:AdjustCount(accountIndex.categoryTotals, canonicalCategoryKey, sign * count) then
            return false
        end
    end

    for categoryKey, categoryItems in pairs(aggregate.categoryItems or {}) do
        local canonicalCategoryKey = canonicalizeCategoryKey(categoryKey)
        for itemID, count in pairs(categoryItems) do
            if not self:AdjustNestedCount(accountIndex.categoryItems, canonicalCategoryKey, itemID, sign * count) then
                return false
            end
        end
    end

    return true
end

function BagsStore:GetItemDescription(itemID, hyperlink, bagID, slotID, itemName)
    local tooltipData
    if C_TooltipInfo then
        if bagID and slotID and C_TooltipInfo.GetBagItem then
            tooltipData = C_TooltipInfo.GetBagItem(bagID, slotID)
        elseif type(hyperlink) == "string" and hyperlink ~= "" and C_TooltipInfo.GetHyperlink then
            tooltipData = C_TooltipInfo.GetHyperlink(hyperlink)
        elseif itemID and C_TooltipInfo.GetItemByID then
            tooltipData = C_TooltipInfo.GetItemByID(itemID)
        end
    end

    local parts = collectTooltipTextParts(tooltipData)
    if not parts then
        return nil
    end

    local normalizedItemName = vesperTools:NormalizeSearchText(itemName)
    local descriptionParts = {}
    local skippedName = false

    for i = 1, #parts do
        local part = parts[i]
        local normalizedPart = vesperTools:NormalizeSearchText(part)
        if normalizedPart then
            if not skippedName and normalizedItemName and normalizedPart == normalizedItemName then
                skippedName = true
            else
                descriptionParts[#descriptionParts + 1] = part
            end
        end
    end

    if #descriptionParts == 0 then
        return nil
    end

    return table.concat(descriptionParts, "\n")
end

function BagsStore:BuildItemMeta(itemID, hyperlink, info, bagID, slotID)
    local global = self:GetGlobalDB()
    if not global or not itemID then
        return nil
    end

    -- Metadata such as required level and tooltip text belongs to the full link.
    -- Do not let a different bonus/scaling variant inherit it from the same ID.
    local previous = global.itemMeta[itemID] or {}
    local meta = {}
    for key, value in pairs(previous) do
        meta[key] = value
    end
    if previous.hyperlink ~= hyperlink then
        meta.requiredLevel = nil
        meta.itemDescription = nil
        meta.searchText = nil
    end
    global.itemMeta[itemID] = meta

    local _, _, _, equipLoc, iconFileID, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    meta.classID = classID or meta.classID
    meta.subClassID = subClassID or meta.subClassID
    meta.equipLoc = equipLoc or meta.equipLoc
    meta.iconFileID = info and info.iconFileID or iconFileID or meta.iconFileID

    local itemInfoRef = hyperlink or itemID
    local resolvedName, _, quality, _, itemMinLevel, _, _, _, _, _, _, resolvedClassID, resolvedSubClassID, _, expansionID, _, isCraftingReagent = getItemInfoRecord(itemInfoRef)
    if resolvedClassID ~= nil then
        meta.classID = resolvedClassID
    end
    if resolvedSubClassID ~= nil then
        meta.subClassID = resolvedSubClassID
    end
    if quality ~= nil then
        meta.quality = quality
    end
    meta.requiredLevel = normalizeRequiredLevel(itemMinLevel)
    expansionID = normalizeExpansionID(expansionID)
    if expansionID ~= nil then
        meta.expansionID = expansionID
    end
    if isCraftingReagent ~= nil then
        meta.isCraftingReagent = isCraftingReagent and true or false
    end

    if info and info.quality ~= nil then
        meta.quality = info.quality
    end

    local itemName = normalizeName(resolvedName or (info and info.itemName))
    if not resolvedName then
        self:RequestMissingItemData(itemID, bagID)
    end
    if itemName then
        meta.itemName = itemName
    elseif not meta.itemName then
        meta.itemName = vesperTools:BuildFallbackItemName(itemID)
    end

    local shouldRefreshDescription = not meta.itemDescription
    if not shouldRefreshDescription and type(hyperlink) == "string" and hyperlink ~= "" and meta.hyperlink ~= hyperlink then
        shouldRefreshDescription = true
    end

    if shouldRefreshDescription then
        local itemDescription = self:GetItemDescription(itemID, hyperlink, bagID, slotID, meta.itemName)
        if itemDescription then
            meta.itemDescription = itemDescription
        end
    end

    if type(hyperlink) == "string" and hyperlink ~= "" then
        meta.hyperlink = hyperlink
    end

    meta.searchText = vesperTools:NormalizeSearchText(table.concat({
        meta.itemName or vesperTools:BuildFallbackItemName(itemID),
        meta.itemDescription or "",
        vesperTools:GetEquipLocSearchTerms(meta.equipLoc) or "",
    }, " ")) or meta.searchText
    meta.requiredLevel = meta.requiredLevel or extractRequiredLevel(meta.searchText)
    self:UpdateCurrentScaledLegacyEquipmentFlag(meta)

    meta.lastResolved = time()
    return meta
end

function BagsStore:ResolveCategoryKey(meta, info, questInfo)
    local classID = meta and meta.classID
    local subClassID = meta and meta.subClassID
    local consumableSubclass = Enum and Enum.ItemConsumableSubclass or {}
    local reagentSubclass = Enum and Enum.ItemReagentSubclass or {}
    -- Include old enchants and temporary weapon enhancements, even when they
    -- also carry the crafting-reagent flag. Enchanting materials remain reagents.
    if classID == ITEM_CLASS.Gem or classID == ITEM_CLASS.ItemEnhancement
        or (classID == ITEM_CLASS.Consumable and subClassID == consumableSubclass.Itemenhancement) then
        return "enhancements"
    end

    -- Keystone expansion metadata can refer to an older dungeon in the rotation.
    if classID == ITEM_CLASS.Reagent and subClassID == reagentSubclass.Keystone then
        return "season"
    end

    local expansionID = meta and normalizeExpansionID(meta.expansionID) or nil
    local currentExpansionID = getCurrentExpansionID()
    if expansionID ~= nil and currentExpansionID ~= nil and expansionID ~= currentExpansionID then
        if meta and self:UpdateCurrentScaledLegacyEquipmentFlag(meta) then
            return "equipment"
        end
        return PAST_EXPANSIONS_CATEGORY_KEY
    end

    if questInfo and questInfo.isQuestItem then
        return "quest"
    end

    if isKnownSeasonItemID(info and info.itemID)
        or isSeasonSparkItem(meta, info)
    then
        return "season"
    end

    if tonumber((info and info.quality) or (meta and meta.quality)) == 0 then
        return "junk"
    end

    if (info and info.isCraftingReagent) or (meta and meta.isCraftingReagent) then
        return "reagent"
    end

    if classID == ITEM_CLASS.Consumable then
        return "consumable"
    end

    if classID == ITEM_CLASS.Weapon or classID == ITEM_CLASS.Armor then
        return "equipment"
    end

    if classID == ITEM_CLASS.Recipe then
        return "recipe"
    end

    if classID == ITEM_CLASS.Tradegoods or classID == ITEM_CLASS.Reagent then
        return "tradegoods"
    end

    if classID == ITEM_CLASS.Container then
        return "container"
    end

    return "misc"
end

function BagsStore:BuildSlotRecord(bagID, slotID)
    if not (C_Container and C_Container.GetContainerItemInfo) then
        return false
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    local itemID = info and info.itemID
    if not itemID then
        return false
    end

    local questInfo = {}
    if C_Container.GetContainerItemQuestInfo then
        questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID) or {}
    end

    local meta = self:BuildItemMeta(itemID, info.hyperlink, info, bagID, slotID)
    local itemGUID
    if ItemLocation and C_Item and C_Item.GetItemGUID then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
        if itemLocation and itemLocation:IsValid() and itemLocation:IsBagAndSlot() then
            itemGUID = C_Item.GetItemGUID(itemLocation)
        end
    end

    local itemName = meta and normalizeName(meta.itemName) or nil
    local itemDescription = meta and normalizeName(meta.itemDescription) or nil
    local categoryKey = self:ResolveCategoryKey(meta, info, questInfo)
    local quality = info.quality
    if quality == nil and meta then
        quality = meta.quality
    end

    return {
        bagID = bagID,
        slotID = slotID,
        itemID = itemID,
        itemGUID = itemGUID,
        itemName = itemName or vesperTools:BuildFallbackItemName(itemID),
        itemDescription = itemDescription,
        hyperlink = info.hyperlink,
        iconFileID = info.iconFileID or (meta and meta.iconFileID) or "Interface\\Icons\\INV_Misc_QuestionMark",
        stackCount = tonumber(info.stackCount) or 1,
        quality = quality,
        expansionID = meta and meta.expansionID or nil,
        requiredLevel = meta and meta.requiredLevel or nil,
        classID = meta and meta.classID or nil,
        subClassID = meta and meta.subClassID or nil,
        isLocked = info.isLocked and true or false,
        isQuestItem = questInfo.isQuestItem and true or false,
        isCraftingReagent = (info.isCraftingReagent or (meta and meta.isCraftingReagent)) and true or false,
        categoryKey = categoryKey,
        sortKey = string.lower(itemName or vesperTools:BuildFallbackItemName(itemID)),
        searchText = meta and meta.searchText or vesperTools:NormalizeSearchText(table.concat({
            itemName or vesperTools:BuildFallbackItemName(itemID),
            itemDescription or "",
        }, " ")),
    }
end

function BagsStore:BuildBagSnapshot(bagID)
    local bag = {
        bagID = bagID,
        name = getBagName(bagID),
        iconFileID = getBagIcon(bagID),
        size = 0,
        bagFamily = 0,
        scannedAt = time(),
        slots = {},
    }

    if not (C_Container and C_Container.GetContainerNumSlots) then
        return bag
    end

    local size = tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
    local bagFamily = 0
    if C_Container.GetContainerNumFreeSlots then
        local _, resolvedFamily = C_Container.GetContainerNumFreeSlots(bagID)
        bagFamily = tonumber(resolvedFamily) or 0
    end
    bag.size = size
    bag.bagFamily = bagFamily

    for slotID = 1, size do
        bag.slots[slotID] = self:BuildSlotRecord(bagID, slotID)
    end

    return bag
end

function BagsStore:BagSnapshotsEqual(a, b)
    if a == b then
        return true
    end

    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    if tonumber(a.size) ~= tonumber(b.size) then
        return false
    end
    if tonumber(a.bagFamily) ~= tonumber(b.bagFamily) then
        return false
    end

    local maxSlots = math.max(tonumber(a.size) or 0, tonumber(b.size) or 0)
    for slotID = 1, maxSlots do
        local oldRecord = a.slots and a.slots[slotID] or false
        local newRecord = b.slots and b.slots[slotID] or false

        if oldRecord ~= newRecord then
            if oldRecord == false or newRecord == false then
                return false
            end

            if type(oldRecord) ~= "table" or type(newRecord) ~= "table" then
                return false
            end

            if oldRecord.itemID ~= newRecord.itemID
                or oldRecord.itemName ~= newRecord.itemName
                or oldRecord.itemDescription ~= newRecord.itemDescription
                or oldRecord.stackCount ~= newRecord.stackCount
                or oldRecord.hyperlink ~= newRecord.hyperlink
                or oldRecord.iconFileID ~= newRecord.iconFileID
                or oldRecord.quality ~= newRecord.quality
                or oldRecord.expansionID ~= newRecord.expansionID
                or oldRecord.requiredLevel ~= newRecord.requiredLevel
                or oldRecord.classID ~= newRecord.classID
                or oldRecord.subClassID ~= newRecord.subClassID
                or oldRecord.isLocked ~= newRecord.isLocked
                or oldRecord.isQuestItem ~= newRecord.isQuestItem
                or oldRecord.isCraftingReagent ~= newRecord.isCraftingReagent
                or oldRecord.categoryKey ~= newRecord.categoryKey
                or oldRecord.sortKey ~= newRecord.sortKey
                or oldRecord.searchText ~= newRecord.searchText
                or oldRecord.itemGUID ~= newRecord.itemGUID then
                return false
            end
        end
    end

    return true
end

-- Build lightweight aggregate totals from a full bag snapshot table.
function BagsStore:BuildAggregatesFromBags(bags)
    local aggregate = makeEmptyAggregate()
    if type(bags) ~= "table" then
        return aggregate
    end

    for _, bagID in ipairs(TRACKED_BAG_IDS) do
        local bag = bags[bagID]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemID then
                    local count = math.max(1, tonumber(record.stackCount) or 1)
                    local categoryKey = canonicalizeCategoryKey(record.categoryKey)

                    self:AdjustCount(aggregate.itemTotals, record.itemID, count)
                    self:AdjustCount(aggregate.categoryTotals, categoryKey, count)

                    aggregate.categoryItems[categoryKey] = aggregate.categoryItems[categoryKey] or {}
                    self:AdjustCount(aggregate.categoryItems[categoryKey], record.itemID, count)
                    if not next(aggregate.categoryItems[categoryKey]) then
                        aggregate.categoryItems[categoryKey] = nil
                    end
                end
            end
        end
    end

    return aggregate
end

-- Capture every tracked carried bag and derive the aggregate counts from that snapshot.
function BagsStore:BuildFullCarriedSnapshot()
    local carried = {
        bags = {},
        itemTotals = {},
        categoryTotals = {},
        categoryItems = {},
    }

    for i = 1, #TRACKED_BAG_IDS do
        local bagID = TRACKED_BAG_IDS[i]
        carried.bags[bagID] = self:BuildBagSnapshot(bagID)
    end

    local aggregate = self:BuildAggregatesFromBags(carried.bags)
    carried.itemTotals = aggregate.itemTotals
    carried.categoryTotals = aggregate.categoryTotals
    carried.categoryItems = aggregate.categoryItems
    return carried
end

-- Rebuild the global cross-character inventory index from all saved characters.
function BagsStore:BuildAccountIndexFromCharacters(charactersByGUID)
    local rebuilt = {
        itemOwners = {},
        itemTotals = {},
        categoryTotals = {},
        categoryItems = {},
    }

    local resolvedCharacters = charactersByGUID
    if resolvedCharacters == nil then
        local global = self:GetGlobalDB()
        resolvedCharacters = global and global.charactersByGUID or nil
    end

    charactersByGUID = resolvedCharacters
    if not charactersByGUID then
        return rebuilt
    end

    for characterKey, character in pairs(charactersByGUID) do
        local carried = character and character.carried
        if type(carried) == "table" then
            for itemID, count in pairs(carried.itemTotals or {}) do
                self:AdjustCount(rebuilt.itemTotals, itemID, count)
                self:AdjustNestedCount(rebuilt.itemOwners, itemID, characterKey, count)
            end

            for categoryKey, count in pairs(carried.categoryTotals or {}) do
                local canonicalCategoryKey = canonicalizeCategoryKey(categoryKey)
                self:AdjustCount(rebuilt.categoryTotals, canonicalCategoryKey, count)
            end

            for categoryKey, categoryItems in pairs(carried.categoryItems or {}) do
                local canonicalCategoryKey = canonicalizeCategoryKey(categoryKey)
                for itemID, count in pairs(categoryItems) do
                    self:AdjustNestedCount(rebuilt.categoryItems, canonicalCategoryKey, itemID, count)
                end
            end
        end
    end

    return rebuilt
end

function BagsStore:GetRecordCategoryMeta(global, record)
    local meta = {}
    for key, value in pairs(global.itemMeta[record.itemID] or {}) do
        meta[key] = value
    end
    if record.hyperlink ~= meta.hyperlink then
        meta.requiredLevel = nil
        meta.itemDescription = nil
        meta.searchText = nil
    end
    for key, value in pairs(record) do
        meta[key] = value
    end
    -- Class data is available instantly even for offline snapshots with no meta.
    if not meta.classID and C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(record.itemID)
        meta.classID, meta.subClassID = classID, subClassID
    end
    return meta
end

function BagsStore:RecategorizeCarriedSnapshot(global, carried)
    if type(global) ~= "table" or type(carried) ~= "table" or type(carried.bags) ~= "table" then
        return false
    end

    local changed = false

    for _, bagID in ipairs(TRACKED_BAG_IDS) do
        local bag = carried.bags[bagID]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemID then
                    local meta = self:GetRecordCategoryMeta(global, record)
                    local nextCategoryKey = record.categoryKey

                    if meta then
                        self:UpdateCurrentScaledLegacyEquipmentFlag(meta)
                        nextCategoryKey = self:ResolveCategoryKey(meta, record, record)
                    end

                    if nextCategoryKey ~= record.categoryKey then
                        record.categoryKey = nextCategoryKey
                        changed = true
                    end
                end
            end
        end
    end

    local aggregate = self:BuildAggregatesFromBags(carried.bags)
    carried.itemTotals = aggregate.itemTotals
    carried.categoryTotals = aggregate.categoryTotals
    carried.categoryItems = aggregate.categoryItems

    return changed
end

function BagsStore:RefreshCurrentScaledLegacyEquipmentData(global)
    if type(global) ~= "table" then
        return
    end

    for _, meta in pairs(global.itemMeta or {}) do
        if type(meta) == "table" then
            self:UpdateCurrentScaledLegacyEquipmentFlag(meta)
        end
    end

    for _, character in pairs(global.charactersByGUID or {}) do
        if type(character) == "table" and type(character.carried) == "table" then
            self:RecategorizeCarriedSnapshot(global, character.carried)
        end
    end

    global.accountIndex = self:BuildAccountIndexFromCharacters(global.charactersByGUID)
end

function BagsStore:RunGlobalMigrations(global, startingVersion)
    if type(global) ~= "table" then
        return false
    end

    local schemaVersion = tonumber(startingVersion) or 1
    if schemaVersion >= CURRENT_BAGS_SCHEMA_VERSION then
        global.schemaVersion = schemaVersion
        return true
    end

    if getCurrentExpansionID() == nil then
        return false
    end

    if schemaVersion < CURRENT_BAGS_SCHEMA_VERSION then
        self:RefreshCurrentScaledLegacyEquipmentData(global)
        schemaVersion = CURRENT_BAGS_SCHEMA_VERSION
    end

    global.schemaVersion = schemaVersion
    return true
end

function BagsStore:RebuildAccountIndex()
    local global = self:GetGlobalDB()
    if not global then
        return
    end

    global.accountIndex = self:BuildAccountIndexFromCharacters()
end

function BagsStore:ApplyCharacterAggregateReplacement(characterKey, oldAggregate, newAggregate)
    if not self:ApplyAggregateToAccount(characterKey, oldAggregate, "subtract") then
        return false
    end
    if not self:ApplyAggregateToAccount(characterKey, newAggregate, "add") then
        return false
    end
    return true
end

-- Login performs a deferred full scan so bag APIs are ready before reading them.
-- On a fresh login the client marks whole bags as "new"; clear that noise
-- synchronously — before any scan can run — so it never enters the new-item
-- overlay map, then release the ingestion hold set at initialize.
function BagsStore:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUI)
    if isInitialLogin and not isReloadingUI and C_NewItems and C_NewItems.ClearAll then
        pcall(C_NewItems.ClearAll)
    end
    self.suppressNewItemIngestion = false

    self.pendingInitialScan = true
    C_Timer.After(0, function()
        if not self:IsEnabled() then
            return
        end
        self:MarkFullCarryRescan("initial")
        self:CommitPendingBagWork()
    end)
end

function BagsStore:CURRENCY_DISPLAY_UPDATE()
    self:CommitCurrentCurrencySnapshot()
end

function BagsStore:PLAYER_MONEY()
    self:CommitCurrentCurrencySnapshot()
end

-- One request per missing item, with all interested bag IDs retained. The load
-- event need not be followed by BAG_UPDATE_DELAYED, so schedule our own commit.
function BagsStore:RequestMissingItemData(itemID, bagID)
    if bagID == nil or not C_Item or not C_Item.RequestLoadItemDataByID then
        return
    end
    local bags = self.pendingItemBagIDs[itemID]
    if bags then
        bags[bagID] = true
        return
    end
    self.pendingItemBagIDs[itemID] = { [bagID] = true }
    C_Item.RequestLoadItemDataByID(itemID)
end

function BagsStore:QueuePendingBagCommit()
    if self.bagCommitQueued then
        return
    end
    self.bagCommitQueued = true
    C_Timer.After(0, function()
        self.bagCommitQueued = false
        if self:IsEnabled() then
            self:BAG_UPDATE_DELAYED()
        end
    end)
end

function BagsStore:ITEM_DATA_LOAD_RESULT(_, itemID, success)
    local bags = self.pendingItemBagIDs[itemID]
    self.pendingItemBagIDs[itemID] = nil
    if not bags or not success then
        return
    end

    local global = self:GetGlobalDB()
    local meta = global and global.itemMeta[itemID]
    if meta then
        meta.itemDescription = nil
        meta.searchText = nil
    end
    for bagID in pairs(bags) do
        self:BAG_UPDATE(nil, bagID)
    end
    self:QueuePendingBagCommit()
    vesperTools:SendMessage("VESPERTOOLS_CONTAINER_ITEM_DATA_READY", bags)
end

function BagsStore:BAG_UPDATE(_, bagID)
    if not self:IsTrackedBagID(bagID) then
        return
    end

    self.pendingBagUpdate = true
    self.dirtyBagSet[bagID] = true
end

function BagsStore:BAG_CONTAINER_UPDATE()
    self.pendingBagUpdate = true
    self:MarkFullCarryRescan("container")
    self:QueuePendingBagCommit()
end

function BagsStore:BAG_UPDATE_DELAYED()
    if not self.pendingBagUpdate and not self.needsFullCarryRescan and not self.pendingInitialScan then
        return
    end
    self:CommitPendingBagWork()
end

-- Mark a full rescan when incremental updates are not safe enough anymore.
function BagsStore:MarkFullCarryRescan(reason)
    self.needsFullCarryRescan = true
    self.pendingRescanReason = reason or self.pendingRescanReason or "manual"
end

function BagsStore:ClearPendingState()
    self.pendingBagUpdate = false
    self.pendingInitialScan = false
    self.needsFullCarryRescan = false
    self.pendingRescanReason = nil
    wipe(self.dirtyBagSet)
end

-- Broadcast every bag-data view that depends on the current character snapshot.
function BagsStore:BroadcastBagChange(characterKey)
    vesperTools:SendMessage("VESPERTOOLS_BAGS_SNAPSHOT_UPDATED", characterKey)
    vesperTools:SendMessage("VESPERTOOLS_BAGS_CHARACTER_UPDATED", characterKey)
    vesperTools:SendMessage("VESPERTOOLS_BAGS_INDEX_UPDATED", characterKey)
end

-- Replace the full carried snapshot in one pass and rebuild account-wide indexes.
function BagsStore:DoFullCarryRescan(characterKey, character)
    local newCarried = self:BuildFullCarriedSnapshot()
    character.carried = newCarried
    character.currency = self:BuildCurrentCurrencySnapshot()
    character.lastSeen = time()
    self:UpdateNewItemTracking(character)
    self:RebuildAccountIndex()
    self:ClearPendingState()
    self:BroadcastBagChange(characterKey)
    return true
end

-- Collapse queued bag events into either one full rescan or one incremental commit.
function BagsStore:CommitPendingBagWork()
    local characterKey, character = self:CreateOrUpdateCurrentCharacter()
    if not characterKey or not character then
        self:ClearPendingState()
        return false
    end

    if self.pendingInitialScan or self.needsFullCarryRescan then
        return self:DoFullCarryRescan(characterKey, character)
    end

    if not next(self.dirtyBagSet) then
        self:MarkFullCarryRescan("empty-dirty-set")
        return self:DoFullCarryRescan(characterKey, character)
    end

    if type(character.carried) ~= "table" or type(character.carried.bags) ~= "table" then
        self:MarkFullCarryRescan("missing-snapshot")
        return self:DoFullCarryRescan(characterKey, character)
    end

    local changed = false
    for bagID in pairs(self.dirtyBagSet) do
        local oldBag = character.carried.bags[bagID]
        if type(oldBag) ~= "table" then
            self:MarkFullCarryRescan("missing-bag")
            return self:DoFullCarryRescan(characterKey, character)
        end

        local newBag = self:BuildBagSnapshot(bagID)
        if tonumber(oldBag.size) ~= tonumber(newBag.size) or tonumber(oldBag.bagFamily) ~= tonumber(newBag.bagFamily) then
            self:MarkFullCarryRescan("bag-layout")
            return self:DoFullCarryRescan(characterKey, character)
        end

        if not self:BagSnapshotsEqual(oldBag, newBag) then
            changed = true
            character.carried.bags[bagID] = newBag
        end
    end

    local newCurrencySnapshot = self:BuildCurrentCurrencySnapshot()
    local currencyChanged = not self:CurrencySnapshotsEqual(character.currency, newCurrencySnapshot)
    self.pendingBagUpdate = false
    wipe(self.dirtyBagSet)

    if not changed then
        if currencyChanged then
            character.currency = newCurrencySnapshot
            vesperTools:SendMessage("VESPERTOOLS_BAGS_CHARACTER_UPDATED", characterKey)
        end
        character.lastSeen = time()
        return true
    end

    local oldAggregate = {
        itemTotals = character.carried.itemTotals,
        categoryTotals = character.carried.categoryTotals,
        categoryItems = character.carried.categoryItems,
    }
    local aggregate = self:BuildAggregatesFromBags(character.carried.bags)
    character.carried.itemTotals = aggregate.itemTotals
    character.carried.categoryTotals = aggregate.categoryTotals
    character.carried.categoryItems = aggregate.categoryItems
    character.currency = newCurrencySnapshot
    character.lastSeen = time()
    self.pendingRescanReason = nil
    self:UpdateNewItemTracking(character)
    if not self:ApplyCharacterAggregateReplacement(characterKey, oldAggregate, aggregate) then
        self:RebuildAccountIndex()
    end
    self:BroadcastBagChange(characterKey)
    return true
end

function BagsStore:GetCharacterBagSnapshot(characterKey)
    local global = self:GetGlobalDB()
    if not global or type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end
    return global.charactersByGUID[characterKey]
end

function BagsStore:ResolveCharacterBagSnapshot(characterRef)
    local global = self:GetGlobalDB()
    if not global or type(characterRef) ~= "string" or characterRef == "" then
        return nil, nil
    end

    local direct = global.charactersByGUID[characterRef]
    if type(direct) == "table" then
        return characterRef, direct
    end

    local normalizedRef = vesperTools:NormalizePlayerFullName(characterRef)
    if not normalizedRef then
        return nil, nil
    end

    for characterKey, snapshot in pairs(global.charactersByGUID) do
        if type(snapshot) == "table" then
            local storedFullName = vesperTools:NormalizePlayerFullName(snapshot.fullName)
            if not storedFullName and type(snapshot.name) == "string" and snapshot.name ~= "" then
                local realm = type(snapshot.realm) == "string" and strtrim(snapshot.realm) or ""
                if realm ~= "" then
                    storedFullName = vesperTools:NormalizePlayerFullName(string.format("%s-%s", snapshot.name, realm))
                else
                    storedFullName = vesperTools:NormalizePlayerFullName(snapshot.name)
                end
            end

            if storedFullName == normalizedRef then
                return characterKey, snapshot
            end
        end
    end

    return nil, nil
end

function BagsStore:GetCharacterItemCount(characterKey, itemID)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    if not snapshot or not snapshot.carried or not snapshot.carried.itemTotals then
        return 0
    end
    return tonumber(snapshot.carried.itemTotals[itemID]) or 0
end

function BagsStore:GetAccountItemOwners(itemID)
    local global = self:GetGlobalDB()
    if not global then
        return nil
    end
    return global.accountIndex.itemOwners[itemID]
end

function BagsStore:GetCharacterCategoryItems(characterKey, categoryKey)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    if not snapshot or not snapshot.carried or not snapshot.carried.bags then
        return {}
    end

    local newItems = self:GetNewItemsMap(snapshot, false)
    local now = time()
    local wantsNewCategory = categoryKey == NEW_CATEGORY_KEY
    local targetCategoryKey = canonicalizeCategoryKey(categoryKey)
    local items = {}

    for i = 1, #TRACKED_BAG_IDS do
        local bagID = TRACKED_BAG_IDS[i]
        local bag = snapshot.carried.bags[bagID]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" then
                    local isNewRecord = newItems ~= nil
                        and record.itemGUID ~= nil
                        and self:IsNewItemEntryActive(newItems[record.itemGUID], now)

                    if wantsNewCategory then
                        if isNewRecord then
                            items[#items + 1] = record
                        end
                    elseif not isNewRecord and canonicalizeCategoryKey(record.categoryKey) == targetCategoryKey then
                        items[#items + 1] = record
                    end
                end
            end
        end
    end

    table.sort(items, function(a, b)
        if wantsNewCategory then
            local aSeenAt = tonumber(newItems and newItems[a.itemGUID]) or 0
            local bSeenAt = tonumber(newItems and newItems[b.itemGUID]) or 0
            if aSeenAt ~= bSeenAt then
                return aSeenAt > bSeenAt
            end
        end
        if a.sortKey ~= b.sortKey then
            return a.sortKey < b.sortKey
        end
        if a.itemID ~= b.itemID then
            return a.itemID < b.itemID
        end
        if a.bagID ~= b.bagID then
            return a.bagID < b.bagID
        end
        return a.slotID < b.slotID
    end)

    return items
end

function BagsStore:GetAccountCategoryItems(categoryKey)
    local global = self:GetGlobalDB()
    if not global then
        return nil
    end

    local targetCategoryKey = canonicalizeCategoryKey(categoryKey)
    if targetCategoryKey ~= PAST_EXPANSIONS_CATEGORY_KEY then
        return global.accountIndex.categoryItems[targetCategoryKey]
    end

    local mergedItems = {}
    for storedCategoryKey, itemCounts in pairs(global.accountIndex.categoryItems or {}) do
        if canonicalizeCategoryKey(storedCategoryKey) == targetCategoryKey then
            for itemID, count in pairs(itemCounts) do
                self:AdjustCount(mergedItems, itemID, count)
            end
        end
    end

    return mergedItems
end

function BagsStore:GetCharacterCategoryList(characterKey)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    if not snapshot or not snapshot.carried or not snapshot.carried.categoryTotals then
        return {}
    end

    local mergedCounts = {}
    for categoryKey, rawCount in pairs(snapshot.carried.categoryTotals) do
        local count = tonumber(rawCount) or 0
        if count > 0 then
            local canonicalCategoryKey = canonicalizeCategoryKey(categoryKey)
            self:AdjustCount(mergedCounts, canonicalCategoryKey, count)
        end
    end

    -- Pull active new items out of their natural categories into the pinned
    -- "new" overlay category.
    local newItems = self:GetNewItemsMap(snapshot, false)
    if newItems and next(newItems) and type(snapshot.carried.bags) == "table" then
        local now = time()
        for i = 1, #TRACKED_BAG_IDS do
            local bag = snapshot.carried.bags[TRACKED_BAG_IDS[i]]
            if type(bag) == "table" and type(bag.slots) == "table" then
                for slotID = 1, tonumber(bag.size) or 0 do
                    local record = bag.slots[slotID]
                    if type(record) == "table" and record.itemGUID
                        and self:IsNewItemEntryActive(newItems[record.itemGUID], now)
                    then
                        local count = math.max(1, tonumber(record.stackCount) or 1)
                        self:AdjustCount(mergedCounts, canonicalizeCategoryKey(record.categoryKey), -count)
                        self:AdjustCount(mergedCounts, NEW_CATEGORY_KEY, count)
                    end
                end
            end
        end
    end

    local categories = {}
    for categoryKey, count in pairs(mergedCounts) do
        if count > 0 then
            categories[#categories + 1] = {
                key = categoryKey,
                count = count,
                label = self:GetCategoryDisplayName(categoryKey),
                order = self:GetCategoryOrder(categoryKey),
            }
        end
    end

    table.sort(categories, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end

        if a.label ~= b.label then
            return a.label < b.label
        end

        return a.key < b.key
    end)

    return categories
end

function BagsStore:GetCharacterEmptySlotSummary(characterKey)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    local reagentBagID = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or nil
    local summary = {
        {
            key = "regular",
            label = L["BAGS_EMPTY_REGULAR_SLOTS"],
            count = 0,
            iconFileID = "Interface\\Buttons\\Button-Backpack-Up",
        },
        {
            key = "reagent",
            label = L["BAGS_EMPTY_REAGENT_SLOTS"],
            count = 0,
            iconFileID = "Interface\\Icons\\INV_Misc_Bag_10_Green",
        },
    }

    if not snapshot or not snapshot.carried or not snapshot.carried.bags then
        return summary
    end

    for i = 1, #TRACKED_BAG_IDS do
        local bagID = TRACKED_BAG_IDS[i]
        local bag = snapshot.carried.bags[bagID]
        local freeSlots = getEmptySlotCountForBag(bag)

        if reagentBagID ~= nil and bagID == reagentBagID then
            summary[2].count = summary[2].count + freeSlots
            if type(bag) == "table" and bag.iconFileID then
                summary[2].iconFileID = bag.iconFileID
            end
        else
            summary[1].count = summary[1].count + freeSlots
        end
    end

    return summary
end

-- New-item overlay: BagsStore stamps recently looted item GUIDs and serves the
-- transient "new" category without ever writing it into stored slot records.
function BagsStore:GetNewItemsMap(character, create)
    if type(character) ~= "table" then
        return nil
    end
    if create and type(character.newItems) ~= "table" then
        character.newItems = {}
    end
    return type(character.newItems) == "table" and character.newItems or nil
end

function BagsStore:IsNewItemEntryActive(firstSeenAt, now)
    local seenAt = tonumber(firstSeenAt)
    if not seenAt then
        return false
    end
    return ((now or time()) - seenAt) < NEW_ITEM_TIMEOUT_SECONDS
end

-- Stamp newly looted item GUIDs and drop stale/departed entries after a scan commit.
function BagsStore:UpdateNewItemTracking(character)
    local carried = type(character) == "table" and character.carried or nil
    local bags = type(carried) == "table" and carried.bags or nil
    if type(bags) ~= "table" then
        return
    end

    local newItems = self:GetNewItemsMap(character, true)
    if not newItems then
        return
    end

    local now = time()
    local presentGUIDs = {}
    local canQueryLiveMarkers = not self.suppressNewItemIngestion
        and C_NewItems and type(C_NewItems.IsNewItem) == "function"

    for i = 1, #TRACKED_BAG_IDS do
        local bag = bags[TRACKED_BAG_IDS[i]]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemGUID then
                    presentGUIDs[record.itemGUID] = true
                    if canQueryLiveMarkers and newItems[record.itemGUID] == nil then
                        local ok, isNewItem = pcall(C_NewItems.IsNewItem, record.bagID, record.slotID)
                        if ok and isNewItem then
                            newItems[record.itemGUID] = now
                        end
                    end
                end
            end
        end
    end

    for itemGUID, firstSeenAt in pairs(newItems) do
        if not presentGUIDs[itemGUID] or not self:IsNewItemEntryActive(firstSeenAt, now) then
            newItems[itemGUID] = nil
        end
    end
end

function BagsStore:IsNewItemGUID(characterKey, itemGUID)
    if not itemGUID then
        return false
    end

    local newItems = self:GetNewItemsMap(self:GetCharacterBagSnapshot(characterKey), false)
    if not newItems then
        return false
    end

    return self:IsNewItemEntryActive(newItems[itemGUID])
end

function BagsStore:GetNextNewItemExpiry(characterKey)
    local newItems = self:GetNewItemsMap(self:GetCharacterBagSnapshot(characterKey), false)
    if not newItems then
        return nil
    end

    local now = time()
    local earliestSeenAt = nil
    for _, firstSeenAt in pairs(newItems) do
        if self:IsNewItemEntryActive(firstSeenAt, now) then
            local seenAt = tonumber(firstSeenAt)
            if not earliestSeenAt or seenAt < earliestSeenAt then
                earliestSeenAt = seenAt
            end
        end
    end

    if not earliestSeenAt then
        return nil
    end

    return earliestSeenAt + NEW_ITEM_TIMEOUT_SECONDS
end

function BagsStore:HasActiveNewItems(characterKey)
    return self:GetNextNewItemExpiry(characterKey) ~= nil
end

function BagsStore:ClearNewItems(characterKey)
    local character = self:GetCharacterBagSnapshot(characterKey)
    if not character then
        return false
    end

    local newItems = self:GetNewItemsMap(character, false)
    if newItems and next(newItems) then
        wipe(newItems)
    end

    vesperTools:SendMessage("VESPERTOOLS_BAGS_SNAPSHOT_UPDATED", characterKey)
    return true
end

function BagsStore:GetDisplayCharacters()
    local global = self:GetGlobalDB()
    if not global then
        return {}
    end

    local currentKey = self:GetCurrentCharacterKey()
    local characters = {}
    for characterKey, data in pairs(global.charactersByGUID) do
        if type(data) == "table" then
            characters[#characters + 1] = {
                key = characterKey,
                fullName = data.fullName or characterKey,
                classID = data.classID,
                faction = data.faction,
                lastSeen = tonumber(data.lastSeen) or 0,
                isCurrent = characterKey == currentKey,
            }
        end
    end

    table.sort(characters, function(a, b)
        if a.isCurrent ~= b.isCurrent then
            return a.isCurrent
        end
        return a.fullName < b.fullName
    end)

    return characters
end
