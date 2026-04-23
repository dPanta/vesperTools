local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local BankStore = vesperTools:NewModule("BankStore", "AceEvent-3.0")
local L = vesperTools.L

-- BankStore mirrors BagsStore for live bank data, but splits snapshots into
-- character-bank and warband-bank views with their own dirty tracking.
local ITEM_CLASS = Enum and Enum.ItemClass or {}
local BAG_CATEGORY_DEFS = {
    { key = "quest", labelKey = "BAGS_CATEGORY_QUEST", order = 1 },
    { key = "junk", labelKey = "BAGS_CATEGORY_JUNK", order = 2 },
    { key = "reagent", labelKey = "BAGS_CATEGORY_REAGENT", order = 3 },
    { key = "consumable", labelKey = "BAGS_CATEGORY_CONSUMABLE", order = 4 },
    { key = "equipment", labelKey = "BAGS_CATEGORY_EQUIPMENT", order = 5 },
    { key = "recipe", labelKey = "BAGS_CATEGORY_RECIPE", order = 6 },
    { key = "tradegoods", labelKey = "BAGS_CATEGORY_TRADE_GOODS", order = 7 },
    { key = "container", labelKey = "BAGS_CATEGORY_CONTAINER", order = 8 },
    { key = "misc", labelKey = "BAGS_CATEGORY_MISC", order = 9 },
}

local CATEGORY_ORDER = {}
local CATEGORY_LABEL_KEY_BY_ID = {}
local CATEGORY_PRIORITY_BY_ID = {}
for i = 1, #BAG_CATEGORY_DEFS do
    local def = BAG_CATEGORY_DEFS[i]
    CATEGORY_ORDER[i] = def.key
    CATEGORY_LABEL_KEY_BY_ID[def.key] = def.labelKey
    CATEGORY_PRIORITY_BY_ID[def.key] = def.order
end

local CHARACTER_BANK_BAG_IDS = {}
local ACCOUNT_BANK_BAG_IDS = {}
local TRACKED_BANK_BAG_IDS = {}
local TRACKED_BANK_BAG_SET = {}
local CHARACTER_BANK_BAG_SET = {}
local ACCOUNT_BANK_BAG_SET = {}

-- Register each bank bagID once while preserving the display order per bank type.
local function addTrackedBag(list, set, bagID)
    if type(bagID) ~= "number" then
        return
    end
    if not TRACKED_BANK_BAG_SET[bagID] then
        TRACKED_BANK_BAG_SET[bagID] = true
        TRACKED_BANK_BAG_IDS[#TRACKED_BANK_BAG_IDS + 1] = bagID
    end
    if not set[bagID] then
        set[bagID] = true
        list[#list + 1] = bagID
    end
end

if Enum and Enum.BagIndex then
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.Characterbanktab)
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.CharacterBankTab_1)
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.CharacterBankTab_2)
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.CharacterBankTab_3)
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.CharacterBankTab_4)
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.CharacterBankTab_5)
    addTrackedBag(CHARACTER_BANK_BAG_IDS, CHARACTER_BANK_BAG_SET, Enum.BagIndex.CharacterBankTab_6)

    addTrackedBag(ACCOUNT_BANK_BAG_IDS, ACCOUNT_BANK_BAG_SET, Enum.BagIndex.AccountBankTab_1)
    addTrackedBag(ACCOUNT_BANK_BAG_IDS, ACCOUNT_BANK_BAG_SET, Enum.BagIndex.AccountBankTab_2)
    addTrackedBag(ACCOUNT_BANK_BAG_IDS, ACCOUNT_BANK_BAG_SET, Enum.BagIndex.AccountBankTab_3)
    addTrackedBag(ACCOUNT_BANK_BAG_IDS, ACCOUNT_BANK_BAG_SET, Enum.BagIndex.AccountBankTab_4)
    addTrackedBag(ACCOUNT_BANK_BAG_IDS, ACCOUNT_BANK_BAG_SET, Enum.BagIndex.AccountBankTab_5)
end

local function makeEmptyAggregate()
    return {
        itemTotals = {},
        categoryTotals = {},
        categoryItems = {},
    }
end

-- Bank views bundle bag snapshots with aggregate counts and a last-seen timestamp.
local function makeEmptyBankView()
    local view = makeEmptyAggregate()
    view.bags = {}
    view.lastSeen = 0
    return view
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

local function normalizeSearchText(text)
    if type(text) ~= "string" then
        return nil
    end

    local normalized = text
    normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|T.-|t", " ")
    normalized = normalized:gsub("|A.-|a", " ")
    normalized = normalized:gsub("[%z\1-\31]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = strtrim(normalized)
    if normalized == "" then
        return nil
    end

    return string.lower(normalized)
end

local function buildFallbackItemName(itemID)
    return string.format(L["ITEM_FALLBACK_FMT"], tostring(itemID))
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

local function getBagName(bagID)
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

    if CHARACTER_BANK_BAG_SET[bagID] then
        return L["BANK_SWITCH_CHARACTER"]
    end
    if ACCOUNT_BANK_BAG_SET[bagID] then
        return L["BANK_SWITCH_WARBAND"]
    end

    return string.format(L["BANK_BAG_LABEL_FMT"], tostring(bagID))
end

local function getBagIcon(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        local inventoryID = C_Container.ContainerIDToInventoryID(bagID)
        if inventoryID then
            local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", inventoryID) or nil
            if texture then
                return texture
            end
        end
    end

    if ACCOUNT_BANK_BAG_SET[bagID] then
        return "Interface\\Icons\\INV_Misc_Coin_01"
    end

    return "Interface\\Icons\\INV_Misc_Bag_10"
end

function BankStore:OnInitialize()
    self.bankOpen = false
    self.pendingBankUpdate = false
    self.needsFullCharacterRescan = false
    self.needsFullWarbandRescan = false
    self.dirtyCharacterBankSet = {}
    self.dirtyWarbandBankSet = {}
end

function BankStore:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("BANKFRAME_OPENED")
    self:RegisterEvent("BANKFRAME_CLOSED")
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("BAG_CONTAINER_UPDATE")
    self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    self:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
    self:RegisterEvent("BANK_TAB_SETTINGS_UPDATED")
end

function BankStore:GetDB()
    return vesperTools:GetBagsDB()
end

function BankStore:GetGlobalDB()
    local db = self:GetDB()
    if not db then
        return nil
    end

    local global = db.global or {}
    db.global = global
    global.itemMeta = global.itemMeta or {}
    global.bank = global.bank or {}
    global.bank.charactersByGUID = global.bank.charactersByGUID or {}
    global.bank.warband = global.bank.warband or makeEmptyBankView()
    global.bank.warband.bags = global.bank.warband.bags or {}
    global.bank.warband.itemTotals = global.bank.warband.itemTotals or {}
    global.bank.warband.categoryTotals = global.bank.warband.categoryTotals or {}
    global.bank.warband.categoryItems = global.bank.warband.categoryItems or {}
    global.bank.warband.lastSeen = tonumber(global.bank.warband.lastSeen) or 0

    return global
end

function BankStore:GetBankRoot()
    local global = self:GetGlobalDB()
    return global and global.bank or nil
end

function BankStore:GetCurrentCharacterKey()
    return vesperTools:GetCurrentCharacterGUID()
end

function BankStore:GetCategoryDisplayName(categoryKey)
    local labelKey = CATEGORY_LABEL_KEY_BY_ID[categoryKey]
    if labelKey then
        return L[labelKey]
    end
    return L["BAGS_CATEGORY_MISC"]
end

function BankStore:GetCategoryOrder(categoryKey)
    return CATEGORY_PRIORITY_BY_ID[categoryKey] or 999
end

function BankStore:IsTrackedBankBagID(bagID)
    return TRACKED_BANK_BAG_SET[bagID] and true or false
end

function BankStore:IsCharacterBankBagID(bagID)
    return CHARACTER_BANK_BAG_SET[bagID] and true or false
end

function BankStore:IsWarbandBankBagID(bagID)
    return ACCOUNT_BANK_BAG_SET[bagID] and true or false
end

function BankStore:GetBankBagIDsForView(viewKey)
    if viewKey == "warband" then
        return ACCOUNT_BANK_BAG_IDS
    end

    return CHARACTER_BANK_BAG_IDS
end

function BankStore:CanUseBankType(bankType)
    if not self.bankOpen then
        return false
    end

    if C_Bank and C_Bank.CanUseBank and bankType ~= nil then
        local ok, canUse = pcall(C_Bank.CanUseBank, bankType)
        if ok then
            return canUse and true or false
        end
    end

    return true
end

-- Character bank is considered live only while the current interaction allows writing.
function BankStore:CanScanCharacterBank()
    return self:CanUseBankType(Enum and Enum.BankType and Enum.BankType.Character or nil)
end

-- Warband bank scanning is gated by both support in the client and live access rights.
function BankStore:CanScanWarband()
    if #ACCOUNT_BANK_BAG_IDS == 0 then
        return false
    end
    return self:CanUseBankType(Enum and Enum.BankType and Enum.BankType.Account or nil)
end

function BankStore:IsCharacterBankLive()
    return self:CanScanCharacterBank()
end

function BankStore:IsWarbandBankLive()
    return self:CanScanWarband()
end

-- Ensure the current-character bank record exists before persisting scans into it.
function BankStore:CreateOrUpdateCurrentCharacter()
    local root = self:GetBankRoot()
    if not root then
        return nil, nil
    end

    local characterKey = self:GetCurrentCharacterKey()
    local character = root.charactersByGUID[characterKey]
    if not character then
        character = {}
        root.charactersByGUID[characterKey] = character
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
    character.bank = character.bank or makeEmptyBankView()
    character.bank.bags = character.bank.bags or {}
    character.bank.itemTotals = character.bank.itemTotals or {}
    character.bank.categoryTotals = character.bank.categoryTotals or {}
    character.bank.categoryItems = character.bank.categoryItems or {}
    character.bank.lastSeen = tonumber(character.bank.lastSeen) or 0

    return characterKey, character
end

function BankStore:GetItemDescription(itemID, hyperlink, bagID, slotID, itemName)
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

    local normalizedItemName = normalizeSearchText(itemName)
    local descriptionParts = {}
    local skippedName = false

    for i = 1, #parts do
        local part = parts[i]
        local normalizedPart = normalizeSearchText(part)
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

function BankStore:BuildItemMeta(itemID, hyperlink, info, bagID, slotID)
    local global = self:GetGlobalDB()
    if not global or not itemID then
        return nil
    end

    local meta = global.itemMeta[itemID] or {}
    global.itemMeta[itemID] = meta

    local _, _, _, equipLoc, iconFileID, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    meta.classID = classID or meta.classID
    meta.subClassID = subClassID or meta.subClassID
    meta.equipLoc = equipLoc or meta.equipLoc
    meta.iconFileID = info and info.iconFileID or iconFileID or meta.iconFileID

    if info and info.quality ~= nil then
        meta.quality = info.quality
    end

    local itemName
    if C_Item and C_Item.GetItemNameByID then
        itemName = C_Item.GetItemNameByID(itemID)
    end
    if not itemName or itemName == "" then
        itemName = GetItemInfo(itemID)
    end
    itemName = normalizeName(itemName)
    if itemName then
        meta.itemName = itemName
    elseif not meta.itemName then
        meta.itemName = buildFallbackItemName(itemID)
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

    meta.searchText = normalizeSearchText(table.concat({
        meta.itemName or buildFallbackItemName(itemID),
        meta.itemDescription or "",
    }, " ")) or meta.searchText
    meta.lastResolved = time()

    return meta
end

function BankStore:ResolveCategoryKey(meta, info, questInfo)
    if questInfo and questInfo.isQuestItem then
        return "quest"
    end

    if info and tonumber(info.quality) == 0 then
        return "junk"
    end

    if info and info.isCraftingReagent then
        return "reagent"
    end

    local classID = meta and meta.classID
    if classID == ITEM_CLASS.Consumable then
        return "consumable"
    end

    if classID == ITEM_CLASS.Weapon or classID == ITEM_CLASS.Armor then
        return "equipment"
    end

    if classID == ITEM_CLASS.Recipe then
        return "recipe"
    end

    if classID == ITEM_CLASS.Tradegoods or classID == ITEM_CLASS.Gem or classID == ITEM_CLASS.Reagent then
        return "tradegoods"
    end

    if classID == ITEM_CLASS.Container then
        return "container"
    end

    return "misc"
end

function BankStore:BuildSlotRecord(bagID, slotID)
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
        itemName = itemName or buildFallbackItemName(itemID),
        itemDescription = itemDescription,
        hyperlink = info.hyperlink,
        iconFileID = info.iconFileID or (meta and meta.iconFileID) or "Interface\\Icons\\INV_Misc_QuestionMark",
        stackCount = tonumber(info.stackCount) or 1,
        quality = quality,
        isLocked = info.isLocked and true or false,
        isQuestItem = questInfo.isQuestItem and true or false,
        isCraftingReagent = info.isCraftingReagent and true or false,
        categoryKey = categoryKey,
        sortKey = string.lower(itemName or buildFallbackItemName(itemID)),
        searchText = meta and meta.searchText or normalizeSearchText(table.concat({
            itemName or buildFallbackItemName(itemID),
            itemDescription or "",
        }, " ")),
    }
end

function BankStore:BuildBagSnapshot(bagID)
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

function BankStore:BagSnapshotsEqual(a, b)
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

function BankStore:BuildAggregatesFromBags(bags, bagIDs)
    local aggregate = makeEmptyAggregate()
    if type(bags) ~= "table" then
        return aggregate
    end

    for i = 1, #bagIDs do
        local bagID = bagIDs[i]
        local bag = bags[bagID]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemID then
                    local count = math.max(1, tonumber(record.stackCount) or 1)
                    local categoryKey = record.categoryKey or "misc"
                    aggregate.itemTotals[record.itemID] = (tonumber(aggregate.itemTotals[record.itemID]) or 0) + count
                    aggregate.categoryTotals[categoryKey] = (tonumber(aggregate.categoryTotals[categoryKey]) or 0) + count
                    aggregate.categoryItems[categoryKey] = aggregate.categoryItems[categoryKey] or {}
                    aggregate.categoryItems[categoryKey][record.itemID] = (tonumber(aggregate.categoryItems[categoryKey][record.itemID]) or 0) + count
                end
            end
        end
    end

    return aggregate
end

-- Build one complete bank view snapshot from the supplied ordered bag list.
function BankStore:BuildViewSnapshot(bagIDs)
    local view = makeEmptyBankView()
    for i = 1, #bagIDs do
        local bagID = bagIDs[i]
        view.bags[bagID] = self:BuildBagSnapshot(bagID)
    end

    local aggregate = self:BuildAggregatesFromBags(view.bags, bagIDs)
    view.itemTotals = aggregate.itemTotals
    view.categoryTotals = aggregate.categoryTotals
    view.categoryItems = aggregate.categoryItems
    view.lastSeen = time()
    return view
end

-- Prime the current-character bank record early so later scans have a destination.
function BankStore:PLAYER_ENTERING_WORLD()
    self:CreateOrUpdateCurrentCharacter()
end

-- Opening the bank marks the relevant views dirty and defers one consolidated scan.
function BankStore:BANKFRAME_OPENED()
    self.bankOpen = true
    self:CreateOrUpdateCurrentCharacter()
    if self:CanScanCharacterBank() then
        self:MarkFullCharacterRescan("open")
    end
    if self:CanScanWarband() then
        self:MarkFullWarbandRescan("open")
    end
    C_Timer.After(0, function()
        if self:IsEnabled() and self.bankOpen then
            self:CommitPendingBankWork()
        end
    end)
end

-- Closing the bank drops any pending runtime scan state.
function BankStore:BANKFRAME_CLOSED()
    self.bankOpen = false
    self:ClearPendingState()
end

function BankStore:BAG_UPDATE(_, bagID)
    if not self.bankOpen or not self:IsTrackedBankBagID(bagID) then
        return
    end

    self.pendingBankUpdate = true
    if self:IsCharacterBankBagID(bagID) then
        self.dirtyCharacterBankSet[bagID] = true
    elseif self:IsWarbandBankBagID(bagID) then
        self.dirtyWarbandBankSet[bagID] = true
    end
end

function BankStore:BAG_UPDATE_DELAYED()
    if not self.bankOpen then
        return
    end

    if not self.pendingBankUpdate and not self.needsFullCharacterRescan and not self.needsFullWarbandRescan then
        return
    end

    self:CommitPendingBankWork()
end

function BankStore:BAG_CONTAINER_UPDATE()
    if not self.bankOpen then
        return
    end

    self.pendingBankUpdate = true
    self:MarkFullCharacterRescan("container")
    self:MarkFullWarbandRescan("container")
end

function BankStore:PLAYERBANKSLOTS_CHANGED()
    if not self.bankOpen then
        return
    end

    self.pendingBankUpdate = true
    self:MarkFullCharacterRescan("slots")
end

function BankStore:PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED()
    if not self.bankOpen then
        return
    end

    self.pendingBankUpdate = true
    self:MarkFullWarbandRescan("account-slots")
end

function BankStore:BANK_TAB_SETTINGS_UPDATED(_, bankType)
    if not self.bankOpen then
        return
    end

    self.pendingBankUpdate = true
    if bankType == (Enum and Enum.BankType and Enum.BankType.Account or nil) then
        self:MarkFullWarbandRescan("settings")
    elseif bankType == (Enum and Enum.BankType and Enum.BankType.Character or nil) then
        self:MarkFullCharacterRescan("settings")
    else
        self:MarkFullCharacterRescan("settings")
        self:MarkFullWarbandRescan("settings")
    end
end

-- Flag a full character-bank rebuild when incremental updates are no longer safe.
function BankStore:MarkFullCharacterRescan()
    self.needsFullCharacterRescan = true
end

-- Flag a full warband-bank rebuild when incremental updates are no longer safe.
function BankStore:MarkFullWarbandRescan()
    self.needsFullWarbandRescan = true
end

function BankStore:ClearPendingState()
    self.pendingBankUpdate = false
    self.needsFullCharacterRescan = false
    self.needsFullWarbandRescan = false
    wipe(self.dirtyCharacterBankSet)
    wipe(self.dirtyWarbandBankSet)
end

function BankStore:RefreshPendingFlag()
    self.pendingBankUpdate = self.needsFullCharacterRescan
        or self.needsFullWarbandRescan
        or next(self.dirtyCharacterBankSet) ~= nil
        or next(self.dirtyWarbandBankSet) ~= nil
end

-- Broadcast all bank-dependent views after a successful rescan or incremental update.
function BankStore:BroadcastBankChange()
    vesperTools:SendMessage("VESPERTOOLS_BANK_SNAPSHOT_UPDATED")
    vesperTools:SendMessage("VESPERTOOLS_BANK_CHARACTER_UPDATED")
    vesperTools:SendMessage("VESPERTOOLS_WARBAND_BANK_UPDATED")
end

-- Full rescan path for the character bank snapshot.
function BankStore:DoFullCharacterBankRescan(character)
    if not character then
        return false
    end

    character.bank = self:BuildViewSnapshot(CHARACTER_BANK_BAG_IDS)
    character.lastSeen = time()
    return true
end

-- Full rescan path for the account-wide warband bank snapshot.
function BankStore:DoFullWarbandRescan()
    local root = self:GetBankRoot()
    if not root then
        return false
    end

    root.warband = self:BuildViewSnapshot(ACCOUNT_BANK_BAG_IDS)
    root.warband.lastSeen = time()
    return true
end

-- Attempt an incremental update of only the bank bags marked dirty.
function BankStore:CommitDirtyView(view, dirtySet, bagIDs)
    if type(view) ~= "table" or type(view.bags) ~= "table" then
        return nil
    end

    local changed = false
    for bagID in pairs(dirtySet) do
        local oldBag = view.bags[bagID]
        if type(oldBag) ~= "table" then
            return nil
        end

        local newBag = self:BuildBagSnapshot(bagID)
        if tonumber(oldBag.size) ~= tonumber(newBag.size) or tonumber(oldBag.bagFamily) ~= tonumber(newBag.bagFamily) then
            return nil
        end

        if not self:BagSnapshotsEqual(oldBag, newBag) then
            changed = true
            view.bags[bagID] = newBag
        end
    end

    if changed then
        local aggregate = self:BuildAggregatesFromBags(view.bags, bagIDs)
        view.itemTotals = aggregate.itemTotals
        view.categoryTotals = aggregate.categoryTotals
        view.categoryItems = aggregate.categoryItems
    end

    view.lastSeen = time()
    return changed
end

-- Collapse queued bank events into the smallest safe combination of rescans and commits.
function BankStore:CommitPendingBankWork()
    local _, character = self:CreateOrUpdateCurrentCharacter()
    if not character then
        self:ClearPendingState()
        return false
    end

    local anyChanged = false

    if self.needsFullCharacterRescan and self:CanScanCharacterBank() then
        anyChanged = self:DoFullCharacterBankRescan(character) or anyChanged
        self.needsFullCharacterRescan = false
        wipe(self.dirtyCharacterBankSet)
    elseif next(self.dirtyCharacterBankSet) ~= nil and self:CanScanCharacterBank() then
        local changed = self:CommitDirtyView(character.bank, self.dirtyCharacterBankSet, CHARACTER_BANK_BAG_IDS)
        if changed == nil then
            anyChanged = self:DoFullCharacterBankRescan(character) or anyChanged
        else
            anyChanged = changed or anyChanged
        end
        wipe(self.dirtyCharacterBankSet)
    end

    if self.needsFullWarbandRescan and self:CanScanWarband() then
        anyChanged = self:DoFullWarbandRescan() or anyChanged
        self.needsFullWarbandRescan = false
        wipe(self.dirtyWarbandBankSet)
    elseif next(self.dirtyWarbandBankSet) ~= nil and self:CanScanWarband() then
        local root = self:GetBankRoot()
        local changed = root and self:CommitDirtyView(root.warband, self.dirtyWarbandBankSet, ACCOUNT_BANK_BAG_IDS) or nil
        if changed == nil then
            anyChanged = self:DoFullWarbandRescan() or anyChanged
        else
            anyChanged = changed or anyChanged
        end
        wipe(self.dirtyWarbandBankSet)
    end

    self:RefreshPendingFlag()
    if anyChanged then
        self:BroadcastBankChange()
    end

    return true
end

function BankStore:GetCharacterBankSnapshot(characterKey)
    local root = self:GetBankRoot()
    if not root or type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    return root.charactersByGUID[characterKey]
end

function BankStore:GetWarbandBankSnapshot()
    local root = self:GetBankRoot()
    return root and root.warband or nil
end

function BankStore:GetCurrentCharacterRecord()
    local currentKey = self:GetCurrentCharacterKey()
    return currentKey and self:GetCharacterBankSnapshot(currentKey) or nil
end

function BankStore:GetDisplayCharacters()
    local root = self:GetBankRoot()
    if not root then
        return {}
    end

    local currentKey = self:GetCurrentCharacterKey()
    local currentIsLive = self:IsCharacterBankLive()
    local characters = {}
    local currentPlaceholder = nil

    for characterKey, data in pairs(root.charactersByGUID) do
        if type(data) == "table" then
            local bank = type(data.bank) == "table" and data.bank or nil
            local bankLastSeen = tonumber(bank and bank.lastSeen) or 0
            local isCurrent = characterKey == currentKey
            local entry = {
                key = characterKey,
                fullName = data.fullName or characterKey,
                classID = data.classID,
                faction = data.faction,
                lastSeen = math.max(bankLastSeen, tonumber(data.lastSeen) or 0),
                bankLastSeen = bankLastSeen,
                hasSnapshot = bankLastSeen > 0,
                isCurrent = isCurrent,
                isLive = isCurrent and currentIsLive or false,
            }

            if entry.hasSnapshot or entry.isLive then
                characters[#characters + 1] = entry
            elseif isCurrent then
                currentPlaceholder = entry
            end
        end
    end

    if #characters == 0 and currentPlaceholder then
        characters[#characters + 1] = currentPlaceholder
    end

    table.sort(characters, function(a, b)
        if a.isCurrent ~= b.isCurrent then
            return a.isCurrent
        end
        if a.hasSnapshot ~= b.hasSnapshot then
            return a.hasSnapshot
        end
        return a.fullName < b.fullName
    end)

    return characters
end

function BankStore:GetCategoryListFromView(view)
    if not view or type(view.categoryTotals) ~= "table" then
        return {}
    end

    local categories = {}
    for i = 1, #CATEGORY_ORDER do
        local categoryKey = CATEGORY_ORDER[i]
        local count = tonumber(view.categoryTotals[categoryKey]) or 0
        if count > 0 then
            categories[#categories + 1] = {
                key = categoryKey,
                count = count,
                label = self:GetCategoryDisplayName(categoryKey),
                order = self:GetCategoryOrder(categoryKey),
            }
        end
    end

    return categories
end

function BankStore:GetCharacterBankCategoryList(characterKey)
    local record = self:GetCharacterBankSnapshot(characterKey)
    local view = record and record.bank or nil
    return self:GetCategoryListFromView(view)
end

function BankStore:GetWarbandCategoryList()
    return self:GetCategoryListFromView(self:GetWarbandBankSnapshot())
end

function BankStore:GetCategoryItemsFromView(view, bagIDs, categoryKey)
    if not view or type(view.bags) ~= "table" then
        return {}
    end

    local items = {}
    for i = 1, #bagIDs do
        local bagID = bagIDs[i]
        local bag = view.bags[bagID]
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.categoryKey == categoryKey then
                    items[#items + 1] = record
                end
            end
        end
    end

    table.sort(items, function(a, b)
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

function BankStore:GetCharacterBankCategoryItems(characterKey, categoryKey)
    local record = self:GetCharacterBankSnapshot(characterKey)
    local view = record and record.bank or nil
    return self:GetCategoryItemsFromView(view, CHARACTER_BANK_BAG_IDS, categoryKey)
end

function BankStore:GetWarbandCategoryItems(categoryKey)
    return self:GetCategoryItemsFromView(self:GetWarbandBankSnapshot(), ACCOUNT_BANK_BAG_IDS, categoryKey)
end

function BankStore:GetCharacterBankEmptySlotSummary(characterKey)
    local record = self:GetCharacterBankSnapshot(characterKey)
    local view = record and record.bank or nil
    local summary = {
        {
            key = "character",
            label = L["BANK_EMPTY_CHARACTER_SLOTS"],
            count = 0,
            iconFileID = "Interface\\Icons\\INV_Misc_Bag_10",
        },
    }

    if not view or type(view.bags) ~= "table" then
        return summary
    end

    for i = 1, #CHARACTER_BANK_BAG_IDS do
        local bagID = CHARACTER_BANK_BAG_IDS[i]
        local bag = view.bags[bagID]
        summary[1].count = summary[1].count + getEmptySlotCountForBag(bag)
        if type(bag) == "table" and bag.iconFileID then
            summary[1].iconFileID = bag.iconFileID
        end
    end

    return summary
end

function BankStore:GetWarbandEmptySlotSummary()
    local view = self:GetWarbandBankSnapshot()
    local summary = {
        {
            key = "warband",
            label = L["BANK_EMPTY_WARBAND_SLOTS"],
            count = 0,
            iconFileID = "Interface\\Icons\\INV_Misc_Coin_01",
        },
    }

    if not view or type(view.bags) ~= "table" then
        return summary
    end

    for i = 1, #ACCOUNT_BANK_BAG_IDS do
        local bagID = ACCOUNT_BANK_BAG_IDS[i]
        local bag = view.bags[bagID]
        summary[1].count = summary[1].count + getEmptySlotCountForBag(bag)
        if type(bag) == "table" and bag.iconFileID then
            summary[1].iconFileID = bag.iconFileID
        end
    end

    return summary
end
