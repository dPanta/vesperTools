local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local BagsStore = VesperGuild:NewModule("BagsStore", "AceEvent-3.0")
local L = VesperGuild.L

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

local TRACKED_BAG_IDS = {}
local TRACKED_BAG_SET = {}

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

function BagsStore:OnInitialize()
    self.dirtyBagSet = {}
    self.needsFullCarryRescan = false
    self.pendingBagUpdate = false
    self.pendingRescanReason = nil
    self.pendingInitialScan = false
end

function BagsStore:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("BAG_CONTAINER_UPDATE")
end

function BagsStore:GetDB()
    return VesperGuild:GetBagsDB()
end

function BagsStore:GetProfile()
    return VesperGuild:GetBagsProfile()
end

function BagsStore:GetGlobalDB()
    local db = self:GetDB()
    if not db then
        return nil
    end

    local global = db.global or {}
    db.global = global
    global.schemaVersion = tonumber(global.schemaVersion) or 1
    global.charactersByGUID = global.charactersByGUID or {}
    global.itemMeta = global.itemMeta or {}
    global.accountIndex = global.accountIndex or {}
    global.accountIndex.itemOwners = global.accountIndex.itemOwners or {}
    global.accountIndex.itemTotals = global.accountIndex.itemTotals or {}
    global.accountIndex.categoryTotals = global.accountIndex.categoryTotals or {}
    global.accountIndex.categoryItems = global.accountIndex.categoryItems or {}

    return global
end

function BagsStore:GetTrackedBagIDs()
    return TRACKED_BAG_IDS
end

function BagsStore:IsTrackedBagID(bagID)
    return TRACKED_BAG_SET[bagID] and true or false
end

function BagsStore:GetCategoryDisplayName(categoryKey)
    local labelKey = CATEGORY_LABEL_KEY_BY_ID[categoryKey]
    if labelKey then
        return L[labelKey]
    end
    return L["BAGS_CATEGORY_MISC"]
end

function BagsStore:GetCategoryOrder(categoryKey)
    return CATEGORY_PRIORITY_BY_ID[categoryKey] or 999
end

function BagsStore:GetCurrentCharacterKey()
    return VesperGuild:GetCurrentCharacterGUID()
end

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

    return characterKey, character
end

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
        if not self:AdjustCount(accountIndex.categoryTotals, categoryKey, sign * count) then
            return false
        end
    end

    for categoryKey, categoryItems in pairs(aggregate.categoryItems or {}) do
        for itemID, count in pairs(categoryItems) do
            if not self:AdjustNestedCount(accountIndex.categoryItems, categoryKey, itemID, sign * count) then
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

function BagsStore:BuildItemMeta(itemID, hyperlink, info, bagID, slotID)
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

function BagsStore:ResolveCategoryKey(meta, info, questInfo)
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
                    local categoryKey = record.categoryKey or "misc"

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

function BagsStore:BuildAccountIndexFromCharacters()
    local global = self:GetGlobalDB()
    local rebuilt = {
        itemOwners = {},
        itemTotals = {},
        categoryTotals = {},
        categoryItems = {},
    }

    if not global then
        return rebuilt
    end

    for characterKey, character in pairs(global.charactersByGUID) do
        local carried = character and character.carried
        if type(carried) == "table" then
            for itemID, count in pairs(carried.itemTotals or {}) do
                self:AdjustCount(rebuilt.itemTotals, itemID, count)
                self:AdjustNestedCount(rebuilt.itemOwners, itemID, characterKey, count)
            end

            for categoryKey, count in pairs(carried.categoryTotals or {}) do
                self:AdjustCount(rebuilt.categoryTotals, categoryKey, count)
            end

            for categoryKey, categoryItems in pairs(carried.categoryItems or {}) do
                for itemID, count in pairs(categoryItems) do
                    self:AdjustNestedCount(rebuilt.categoryItems, categoryKey, itemID, count)
                end
            end
        end
    end

    return rebuilt
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

function BagsStore:PLAYER_ENTERING_WORLD()
    self.pendingInitialScan = true
    C_Timer.After(0, function()
        if not self:IsEnabled() then
            return
        end
        self:MarkFullCarryRescan("initial")
        self:CommitPendingBagWork()
    end)
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
end

function BagsStore:BAG_UPDATE_DELAYED()
    if not self.pendingBagUpdate and not self.needsFullCarryRescan and not self.pendingInitialScan then
        return
    end
    self:CommitPendingBagWork()
end

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

function BagsStore:BroadcastBagChange(characterKey)
    VesperGuild:SendMessage("VESPERGUILD_BAGS_SNAPSHOT_UPDATED", characterKey)
    VesperGuild:SendMessage("VESPERGUILD_BAGS_CHARACTER_UPDATED", characterKey)
    VesperGuild:SendMessage("VESPERGUILD_BAGS_INDEX_UPDATED", characterKey)
end

function BagsStore:DoFullCarryRescan(characterKey, character)
    local newCarried = self:BuildFullCarriedSnapshot()
    character.carried = newCarried
    character.lastSeen = time()
    self:RebuildAccountIndex()
    self:ClearPendingState()
    self:BroadcastBagChange(characterKey)
    return true
end

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

    self.pendingBagUpdate = false
    wipe(self.dirtyBagSet)

    if not changed then
        character.lastSeen = time()
        return true
    end

    local aggregate = self:BuildAggregatesFromBags(character.carried.bags)
    character.carried.itemTotals = aggregate.itemTotals
    character.carried.categoryTotals = aggregate.categoryTotals
    character.carried.categoryItems = aggregate.categoryItems
    character.lastSeen = time()
    self.pendingRescanReason = nil
    self:RebuildAccountIndex()
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

    local items = {}
    for i = 1, #TRACKED_BAG_IDS do
        local bagID = TRACKED_BAG_IDS[i]
        local bag = snapshot.carried.bags[bagID]
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

function BagsStore:GetAccountCategoryItems(categoryKey)
    local global = self:GetGlobalDB()
    if not global then
        return nil
    end
    return global.accountIndex.categoryItems[categoryKey]
end

function BagsStore:GetCharacterCategoryList(characterKey)
    local snapshot = self:GetCharacterBagSnapshot(characterKey)
    if not snapshot or not snapshot.carried or not snapshot.carried.categoryTotals then
        return {}
    end

    local categories = {}
    for i = 1, #CATEGORY_ORDER do
        local categoryKey = CATEGORY_ORDER[i]
        local count = tonumber(snapshot.carried.categoryTotals[categoryKey]) or 0
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
