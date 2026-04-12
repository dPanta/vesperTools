local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local SearchOverlay = vesperTools:NewModule("SearchOverlay", "AceEvent-3.0")

local FRAME_WIDTH = 560
local FRAME_TOP_OFFSET = -104
local FRAME_SIDE_PADDING = 14
local FRAME_TOP_PADDING = 14
local SEARCH_BAR_HEIGHT = 38
local SEARCH_BAR_TEXT_INSET = 12
local SEARCH_CLEAR_BUTTON_SIZE = 16
local RESULTS_TOP_GAP = 10
local RESULTS_SIDE_PADDING = 10
local RESULTS_BOTTOM_PADDING = 10
local RESULT_ROW_HEIGHT = 46
local RESULT_ROW_GAP = 4
local MAX_VISIBLE_RESULT_ROWS = 9
local MAX_SEARCH_RESULTS = 30
local RESULTS_SCROLL_STEP_ROWS = 2
local RESULTS_SCROLL_FRAME_RIGHT_PADDING = 28
local OVERLAY_BASE_FRAME_LEVEL = 500
local OVERLAY_SEARCH_FRAME_LEVEL_OFFSET = 12
local OVERLAY_RESULTS_FRAME_LEVEL_OFFSET = 11
local MIN_SEARCH_QUERY_CHARACTERS = 3
local SEARCH_DEBOUNCE_SECONDS = 0.03
local FALLBACK_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local SEARCH_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\SearchGlass-64"
local SETTINGS_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\Cogwheel-64"
local TOY_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Toy_10"
local SPELL_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Book_09"
local TALENT_ICON_TEXTURE = "Interface\\Icons\\Ability_Marksmanship"
local BAG_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Bag_10"
local BANK_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Coin_01"
local ACTION_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\vesperTools.png"
local CLICK_CAST_ADDON_CANDIDATES = {
    "Blizzard_ClickBindingUI",
    "Blizzard_ClickBindings",
    "Blizzard_ClickBinding",
}
local SEARCH_PLACEHOLDER_TEXT = string.format("Type at least %d characters to search", MIN_SEARCH_QUERY_CHARACTERS)
local SEARCH_NO_RESULTS_TEXT = "No matching results."
local FIXED_RESULTS_HEIGHT = (MAX_VISIBLE_RESULT_ROWS * RESULT_ROW_HEIGHT) + (math.max(MAX_VISIBLE_RESULT_ROWS - 1, 0) * RESULT_ROW_GAP)
local FIXED_RESULTS_PANEL_HEIGHT = RESULTS_SIDE_PADDING + FIXED_RESULTS_HEIGHT + RESULTS_BOTTOM_PADDING

local KIND_LABELS = {
    action = "Action",
    config = "Config",
    settings = "Settings",
    toy = "Toy",
    spell = "Spell",
    talent = "Talent",
    bag = "Bags",
    bank = "Bank",
}

local KIND_PRIORITIES = {
    action = 90,
    config = 75,
    settings = 60,
    toy = 50,
    spell = 44,
    talent = 42,
    bag = 38,
    bank = 36,
}

local ACTION_DEFS = {
    {
        key = "open_config",
        title = "vesperTools Configuration",
        subtitle = "Open addon configuration",
        icon = SETTINGS_ICON_TEXTURE,
        searchTags = "config configuration options settings preferences addon",
        suggested = true,
        priority = 40,
    },
    {
        key = "open_roster",
        title = "Guild Roster Window",
        subtitle = "Show the vesperTools roster window",
        icon = ACTION_ICON_TEXTURE,
        searchTags = "guild roster members window launcher",
        suggested = true,
        priority = 34,
    },
    {
        key = "open_portals",
        title = "Portals Window",
        subtitle = "Show mage portals, hearthstones, and weekly panels",
        icon = ACTION_ICON_TEXTURE,
        searchTags = "portals hearthstones toys travel launcher",
        suggested = true,
        priority = 33,
    },
    {
        key = "open_bags",
        title = "Bags Window",
        subtitle = "Open the vesperTools bags window",
        icon = BAG_ICON_TEXTURE,
        searchTags = "bags backpack inventory items",
        suggested = true,
        priority = 32,
    },
    {
        key = "open_bank",
        title = "Bank Window",
        subtitle = "Open the character bank window",
        icon = BANK_ICON_TEXTURE,
        searchTags = "bank storage character bank",
        suggested = true,
        priority = 31,
    },
    {
        key = "open_warband_bank",
        title = "Warband Bank Window",
        subtitle = "Open the warband bank view",
        icon = BANK_ICON_TEXTURE,
        searchTags = "warband account bank storage shared",
        suggested = true,
        priority = 30,
    },
    {
        key = "open_vault",
        title = "Great Vault Window",
        subtitle = "Open the weekly vault helper window",
        icon = ACTION_ICON_TEXTURE,
        searchTags = "vault weekly rewards mythic raid delve",
        suggested = true,
        priority = 29,
    },
    {
        key = "open_click_cast_bindings",
        title = "Click Cast Bindings",
        subtitle = "Open Blizzard click cast bindings",
        icon = SPELL_ICON_TEXTURE,
        searchTags = "click cast clickcasting click binding click bindings mouse casting mouseover ccb clickcast",
        suggested = true,
        priority = 31,
    },
}

local CONFIG_DEFS = {
    {
        title = "Roster Settings",
        subtitle = "vesperTools configuration",
        tabKey = "roster",
        searchTags = "guild roster settings options",
        priority = 28,
    },
    {
        title = "Portals Settings",
        subtitle = "vesperTools configuration",
        tabKey = "portals",
        searchTags = "portals hearthstones toys settings options",
        priority = 28,
    },
    {
        title = "Best Keys Settings",
        subtitle = "vesperTools configuration",
        tabKey = "bestKeys",
        searchTags = "best keys mythic plus settings options",
        priority = 24,
    },
    {
        title = "Bags Settings",
        subtitle = "vesperTools configuration",
        tabKey = "bags",
        searchTags = "bags inventory settings options",
        priority = 28,
    },
    {
        title = "Bank Settings",
        subtitle = "vesperTools configuration",
        tabKey = "bank",
        searchTags = "bank warband settings options",
        priority = 27,
    },
    {
        title = "Shared Font Family",
        subtitle = "Configuration - all tabs",
        tabKey = "roster",
        searchTags = "font typography text",
        priority = 22,
    },
    {
        title = "Roster Online Count Blacklist",
        subtitle = "Configuration - Roster",
        tabKey = "roster",
        searchTags = "online count blacklist guild members roster",
        priority = 18,
    },
    {
        title = "Portals Primary Hearthstone",
        subtitle = "Configuration - Portals",
        tabKey = "portals",
        searchTags = "hearthstone primary utility button",
        priority = 20,
    },
    {
        title = "Portals Utility Toy Whitelist",
        subtitle = "Configuration - Portals",
        tabKey = "portals",
        searchTags = "toys whitelist utility portals",
        priority = 20,
    },
    {
        title = "Portals Utility Button Size",
        subtitle = "Configuration - Portals",
        tabKey = "portals",
        searchTags = "size scale utility buttons hearthstone toys",
        priority = 18,
    },
    {
        title = "Bags Replace Blizzard Backpack",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "replace blizzard backpack bags inventory",
        priority = 22,
    },
    {
        title = "Bags Show Currency Bar",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "currency bar backpack bags",
        priority = 16,
    },
    {
        title = "Bags Guild Lookup Requests",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "guild lookup requests bag search sharing",
        priority = 16,
    },
    {
        title = "Bags Columns",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "columns layout grid bags",
        priority = 16,
    },
    {
        title = "Bags Icon Size",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "icon size item buttons bags",
        priority = 16,
    },
    {
        title = "Bags Stack Count Text Size",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "stack count font size bags",
        priority = 14,
    },
    {
        title = "Bags Item Level Text Size",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "item level font size bags",
        priority = 14,
    },
    {
        title = "Bags Quality Glow",
        subtitle = "Configuration - Bags",
        tabKey = "bags",
        searchTags = "quality glow border color bags",
        priority = 14,
    },
    {
        title = "Bank Replace Blizzard Bank",
        subtitle = "Configuration - Bank",
        tabKey = "bank",
        searchTags = "replace blizzard bank character bank",
        priority = 22,
    },
    {
        title = "Bank Columns",
        subtitle = "Configuration - Bank",
        tabKey = "bank",
        searchTags = "columns layout grid bank",
        priority = 16,
    },
    {
        title = "Bank Icon Size",
        subtitle = "Configuration - Bank",
        tabKey = "bank",
        searchTags = "icon size item buttons bank",
        priority = 16,
    },
    {
        title = "Bank Stack Count Text Size",
        subtitle = "Configuration - Bank",
        tabKey = "bank",
        searchTags = "stack count font size bank",
        priority = 14,
    },
    {
        title = "Bank Item Level Text Size",
        subtitle = "Configuration - Bank",
        tabKey = "bank",
        searchTags = "item level font size bank",
        priority = 14,
    },
    {
        title = "Bank Quality Glow",
        subtitle = "Configuration - Bank",
        tabKey = "bank",
        searchTags = "quality glow border color bank",
        priority = 14,
    },
}

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

local function addTextPart(parts, value)
    if type(value) ~= "string" or value == "" then
        return
    end

    parts[#parts + 1] = value
end

local function buildSubtitle(prefix, ownerName, count)
    local parts = { prefix }
    if type(ownerName) == "string" and ownerName ~= "" then
        parts[#parts + 1] = ownerName
    end
    if tonumber(count) and tonumber(count) > 1 then
        parts[#parts + 1] = string.format("x%d", math.floor(tonumber(count) + 0.5))
    end
    return table.concat(parts, " - ")
end

local function tokenizeSearch(text)
    local normalized = normalizeSearchText(text)
    if not normalized then
        return nil
    end

    local tokens = {}
    for token in normalized:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    return #tokens > 0 and tokens or nil
end

local function getClassAccentColor()
    local _, englishClass = UnitClass("player")
    local classColor = englishClass and C_ClassColor.GetClassColor(englishClass) or nil
    if classColor then
        return classColor.r, classColor.g, classColor.b
    end

    return 0.26, 0.58, 0.92
end

local function setFontIfPresent(widget, size, flags)
    if widget then
        vesperTools:ApplyConfiguredFont(widget, size, flags)
    end
end

local function safeGetSpellInfo(spellID)
    local numericSpellID = tonumber(spellID)
    if not numericSpellID or numericSpellID <= 0 then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(numericSpellID)
        if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info
        end
    end

    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(numericSpellID)
        if type(name) == "string" and name ~= "" then
            return {
                name = name,
                iconID = icon,
                spellID = numericSpellID,
            }
        end
    end

    return nil
end

local function loadBlizzardAddon(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName) then
        return true
    end

    if UIParentLoadAddOn then
        local ok = UIParentLoadAddOn(addonName)
        if ok ~= nil then
            return ok and true or false
        end
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        local ok = C_AddOns.LoadAddOn(addonName)
        return ok and true or false
    end

    return false
end

local function openCollectionsJournal()
    loadBlizzardAddon("Blizzard_Collections")

    if ToggleCollectionsJournal then
        ToggleCollectionsJournal()
        return true
    end

    if CollectionsMicroButton and CollectionsMicroButton.Click then
        CollectionsMicroButton:Click()
        return true
    end

    return false
end

local function openSpellBookFrame()
    loadBlizzardAddon("Blizzard_PlayerSpells")

    if PlayerSpellsUtil and type(PlayerSpellsUtil.ToggleSpellBookFrame) == "function" then
        PlayerSpellsUtil.ToggleSpellBookFrame()
        return true
    end

    if TogglePlayerSpellsFrame and PlayerSpellsUtil and PlayerSpellsUtil.FrameTabs and PlayerSpellsUtil.FrameTabs.SpellBook then
        TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.SpellBook)
        return true
    end

    if ToggleSpellBook then
        ToggleSpellBook(BOOKTYPE_SPELL)
        return true
    end

    return false
end

local function openClickCastBindings()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if C_GameRules and C_GameRules.IsPlunderstorm and C_GameRules.IsPlunderstorm() then
        return false
    end

    if not ToggleClickBindingFrame then
        for index = 1, #CLICK_CAST_ADDON_CANDIDATES do
            loadBlizzardAddon(CLICK_CAST_ADDON_CANDIDATES[index])
            if ToggleClickBindingFrame then
                break
            end
        end
    end

    if ToggleClickBindingFrame then
        ToggleClickBindingFrame()
        return true
    end

    return false
end

local function openTalentFrame()
    loadBlizzardAddon("Blizzard_PlayerSpells")
    loadBlizzardAddon("Blizzard_ClassTalentUI")

    if PlayerSpellsUtil and type(PlayerSpellsUtil.ToggleClassTalentFrame) == "function" then
        PlayerSpellsUtil.ToggleClassTalentFrame()
        return true
    end

    if TogglePlayerSpellsFrame and PlayerSpellsUtil and PlayerSpellsUtil.FrameTabs and PlayerSpellsUtil.FrameTabs.ClassTalents then
        TogglePlayerSpellsFrame(PlayerSpellsUtil.FrameTabs.ClassTalents)
        return true
    end

    if ToggleTalentFrame then
        ToggleTalentFrame()
        return true
    end

    return false
end

local function scrollSettingsCategoryIntoView(category)
    if not SettingsPanel or not category then
        return
    end

    local categoryList = SettingsPanel.GetCategoryList and SettingsPanel:GetCategoryList() or nil
    if not categoryList or type(categoryList.FindCategoryElementData) ~= "function" then
        return
    end

    local elementData = categoryList:FindCategoryElementData(category)
    if not elementData or not categoryList.ScrollBox or type(categoryList.ScrollBox.ScrollToElementData) ~= "function" then
        return
    end

    local alignNearest = ScrollBoxConstants and ScrollBoxConstants.AlignNearest or nil
    categoryList.ScrollBox:ScrollToElementData(elementData, alignNearest)
end

local function openSettingsCategoryByPath(categoryName, subcategoryName)
    if not (Settings and Settings.OpenToCategory and SettingsPanel and SettingsPanel.GetCategoryList) then
        return false
    end

    local categoryList = SettingsPanel:GetCategoryList()
    if categoryList and type(categoryList.CreateCategories) == "function" then
        pcall(categoryList.CreateCategories, categoryList)
    end

    local groups = categoryList and categoryList.groups or nil
    if type(groups) ~= "table" then
        return false
    end

    for i = 1, #groups do
        local categories = groups[i] and groups[i].categories or nil
        if type(categories) == "table" then
            for j = 1, #categories do
                local category = categories[j]
                local resolvedName = category and category.GetName and category:GetName() or nil
                if resolvedName == categoryName then
                    Settings.OpenToCategory(category:GetID())
                    scrollSettingsCategoryIntoView(category)

                    if type(subcategoryName) == "string" and subcategoryName ~= "" and category.GetSubcategories then
                        local subcategories = category:GetSubcategories()
                        if type(subcategories) == "table" then
                            for k = 1, #subcategories do
                                local subcategory = subcategories[k]
                                if subcategory and subcategory.GetName and subcategory:GetName() == subcategoryName then
                                    if SettingsPanel.SelectCategory then
                                        SettingsPanel:SelectCategory(subcategory)
                                    elseif Settings.OpenToCategory then
                                        Settings.OpenToCategory(subcategory:GetID())
                                    end
                                    scrollSettingsCategoryIntoView(subcategory)
                                    return true
                                end
                            end
                        end
                    end

                    return true
                end
            end
        end
    end

    return false
end

function SearchOverlay:OnInitialize()
    self.frame = nil
    self.searchBar = nil
    self.searchBox = nil
    self.searchPlaceholder = nil
    self.searchClearButton = nil
    self.resultsFrame = nil
    self.resultsScrollFrame = nil
    self.resultsScrollBar = nil
    self.resultsContainer = nil
    self.emptyText = nil
    self.resultButtons = {}
    self.visibleResults = {}
    self.staticEntries = nil
    self.indexEntries = {}
    self.indexDirty = true
    self.pendingSearchTimer = nil
    self.selectedResultIndex = 0
end

function SearchOverlay:OnEnable()
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnIndexSourceChanged")
    self:RegisterMessage("VESPERTOOLS_BAGS_SNAPSHOT_UPDATED", "OnIndexSourceChanged")
    self:RegisterMessage("VESPERTOOLS_BAGS_CHARACTER_UPDATED", "OnIndexSourceChanged")
    self:RegisterMessage("VESPERTOOLS_BAGS_INDEX_UPDATED", "OnIndexSourceChanged")
    self:RegisterMessage("VESPERTOOLS_BANK_SNAPSHOT_UPDATED", "OnIndexSourceChanged")
    self:RegisterMessage("VESPERTOOLS_BANK_CHARACTER_UPDATED", "OnIndexSourceChanged")
    self:RegisterMessage("VESPERTOOLS_WARBAND_BANK_UPDATED", "OnIndexSourceChanged")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("TOYS_UPDATED", "OnIndexSourceChanged")
    self:RegisterEvent("SPELLS_CHANGED", "OnIndexSourceChanged")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnIndexSourceChanged")
    self:RegisterEvent("TRAIT_CONFIG_CREATED", "OnIndexSourceChanged")
    self:RegisterEvent("TRAIT_CONFIG_DELETED", "OnIndexSourceChanged")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "OnIndexSourceChanged")
end

function SearchOverlay:ADDON_LOADED()
    self:OnIndexSourceChanged()
end

function SearchOverlay:OnIndexSourceChanged()
    self.indexDirty = true
    if self.frame then
        self:RefreshFonts()
    end
    if self.frame and self.frame:IsShown() then
        self:ScheduleRefresh(0)
    end
end

function SearchOverlay:CreateIndexEntry(spec)
    local entry = spec or {}
    local parts = {}
    addTextPart(parts, entry.title)
    addTextPart(parts, entry.subtitle)
    addTextPart(parts, entry.searchText)
    addTextPart(parts, entry.searchTags)
    entry.normalizedTitle = normalizeSearchText(entry.title) or ""
    entry.searchText = normalizeSearchText(table.concat(parts, " ")) or entry.normalizedTitle
    entry.icon = entry.icon or FALLBACK_ICON_TEXTURE
    entry.kind = entry.kind or "action"
    entry.priority = tonumber(entry.priority) or 0
    return entry
end

function SearchOverlay:RefreshWindowLayer()
    local baseLevel = OVERLAY_BASE_FRAME_LEVEL

    local Roster = vesperTools:GetModule("Roster", true)
    if Roster and Roster.frame and Roster.frame.GetFrameLevel then
        baseLevel = math.max(baseLevel, (Roster.frame:GetFrameLevel() or 0) + 40)
    end

    local Portals = vesperTools:GetModule("Portals", true)
    if Portals and Portals.VesperPortalsUI and Portals.VesperPortalsUI.GetFrameLevel then
        baseLevel = math.max(baseLevel, (Portals.VesperPortalsUI:GetFrameLevel() or 0) + 40)
    end

    if self.frame then
        vesperTools:ApplyAddonWindowLayer(self.frame, baseLevel)
    end

    if self.searchBar then
        self.searchBar:SetFrameStrata(vesperTools:GetAddonWindowStrata())
        self.searchBar:SetFrameLevel(baseLevel + OVERLAY_SEARCH_FRAME_LEVEL_OFFSET)
    end

    if self.resultsFrame then
        self.resultsFrame:SetFrameStrata(vesperTools:GetAddonWindowStrata())
        self.resultsFrame:SetFrameLevel(baseLevel + OVERLAY_RESULTS_FRAME_LEVEL_OFFSET)
    end

    if self.resultsContainer then
        self.resultsContainer:SetFrameStrata(vesperTools:GetAddonWindowStrata())
        self.resultsContainer:SetFrameLevel(baseLevel + OVERLAY_RESULTS_FRAME_LEVEL_OFFSET + 1)
    end

    if self.resultsScrollFrame then
        self.resultsScrollFrame:SetFrameStrata(vesperTools:GetAddonWindowStrata())
        self.resultsScrollFrame:SetFrameLevel(baseLevel + OVERLAY_RESULTS_FRAME_LEVEL_OFFSET + 1)
    end

    if self.resultsScrollBar then
        self.resultsScrollBar:SetFrameStrata(vesperTools:GetAddonWindowStrata())
        self.resultsScrollBar:SetFrameLevel(baseLevel + OVERLAY_RESULTS_FRAME_LEVEL_OFFSET + 3)
    end

    for i = 1, #self.resultButtons do
        local button = self.resultButtons[i]
        if button then
            button:SetFrameStrata(vesperTools:GetAddonWindowStrata())
            button:SetFrameLevel(baseLevel + OVERLAY_RESULTS_FRAME_LEVEL_OFFSET + 2 + i)
        end
    end
end

function SearchOverlay:BuildStaticEntries()
    local entries = {}

    for i = 1, #ACTION_DEFS do
        local def = ACTION_DEFS[i]
        entries[#entries + 1] = self:CreateIndexEntry({
            kind = "action",
            title = def.title,
            subtitle = def.subtitle,
            icon = def.icon,
            actionKey = def.key,
            searchTags = def.searchTags,
            suggested = def.suggested,
            priority = def.priority,
        })
    end

    for i = 1, #CONFIG_DEFS do
        local def = CONFIG_DEFS[i]
        entries[#entries + 1] = self:CreateIndexEntry({
            kind = "config",
            title = def.title,
            subtitle = def.subtitle,
            icon = SETTINGS_ICON_TEXTURE,
            tabKey = def.tabKey,
            searchTags = def.searchTags,
            priority = def.priority,
        })
    end

    return entries
end

function SearchOverlay:AddSettingsEntries(entries)
    if not (Settings and Settings.OpenToCategory and SettingsPanel and SettingsPanel.GetCategoryList) then
        return
    end

    local categoryList = SettingsPanel:GetCategoryList()
    if categoryList and type(categoryList.CreateCategories) == "function" then
        pcall(categoryList.CreateCategories, categoryList)
    end

    local groups = categoryList and categoryList.groups or nil
    if type(groups) ~= "table" then
        return
    end

    local seen = {}
    for i = 1, #groups do
        local categories = groups[i] and groups[i].categories or nil
        if type(categories) == "table" then
            for j = 1, #categories do
                local category = categories[j]
                local categoryName = category and category.GetName and category:GetName() or nil
                local categoryID = category and category.GetID and category:GetID() or nil
                if type(categoryName) == "string" and categoryName ~= "" then
                    local topLevelKey = string.format("top:%s", categoryName)
                    if not seen[topLevelKey] then
                        seen[topLevelKey] = true
                        entries[#entries + 1] = self:CreateIndexEntry({
                            kind = "settings",
                            title = categoryName,
                            subtitle = "Settings",
                            icon = SETTINGS_ICON_TEXTURE,
                            categoryName = categoryName,
                            categoryID = categoryID,
                            searchTags = "settings options configuration game addon",
                            priority = 16,
                        })
                    end

                    local subcategories = category.GetSubcategories and category:GetSubcategories() or nil
                    if type(subcategories) == "table" then
                        for k = 1, #subcategories do
                            local subcategory = subcategories[k]
                            local subcategoryName = subcategory and subcategory.GetName and subcategory:GetName() or nil
                            local subcategoryID = subcategory and subcategory.GetID and subcategory:GetID() or nil
                            if type(subcategoryName) == "string" and subcategoryName ~= "" then
                                local subKey = string.format("%s\001%s", categoryName, subcategoryName)
                                if not seen[subKey] then
                                    seen[subKey] = true
                                    entries[#entries + 1] = self:CreateIndexEntry({
                                        kind = "settings",
                                        title = subcategoryName,
                                        subtitle = string.format("Settings - %s", categoryName),
                                        icon = SETTINGS_ICON_TEXTURE,
                                        categoryName = categoryName,
                                        categoryID = categoryID,
                                        subcategoryName = subcategoryName,
                                        subcategoryID = subcategoryID,
                                        searchTags = string.format("settings options configuration addon %s", categoryName),
                                        priority = 14,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function SearchOverlay:AddBlizzardSettingEntries(entries)
    local BlizzardSettingsIndex = vesperTools:GetModule("BlizzardSettingsIndex", true)
    if not BlizzardSettingsIndex or type(BlizzardSettingsIndex.GetEntrySpecs) ~= "function" then
        return
    end

    local ok, specs = pcall(BlizzardSettingsIndex.GetEntrySpecs, BlizzardSettingsIndex)
    if not ok or type(specs) ~= "table" then
        return
    end

    for index = 1, #specs do
        local spec = specs[index]
        if type(spec) == "table" then
            entries[#entries + 1] = self:CreateIndexEntry(spec)
        end
    end
end

function SearchOverlay:AddToyEntries(entries)
    if type(vesperTools.GetOwnedToyOptions) ~= "function" then
        return
    end

    local toys = vesperTools:GetOwnedToyOptions()
    if type(toys) ~= "table" then
        return
    end

    for i = 1, #toys do
        local toy = toys[i]
        if toy and toy.itemID and toy.name then
            entries[#entries + 1] = self:CreateIndexEntry({
                kind = "toy",
                title = toy.name,
                subtitle = "Toy Collection",
                icon = toy.icon or TOY_ICON_TEXTURE,
                toyID = toy.itemID,
                searchTags = "toy collection toys",
                priority = 12,
            })
        end
    end
end

function SearchOverlay:AddSpellEntries(entries)
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo) then
        return
    end

    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or nil
    local seenSpellIDs = {}
    local numLines = tonumber(C_SpellBook.GetNumSpellBookSkillLines()) or 0

    for lineIndex = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        local skillLineName = lineInfo and lineInfo.name or nil
        local offset = lineInfo and lineInfo.itemIndexOffset or 0
        local count = lineInfo and lineInfo.numSpellBookItems or 0

        for slot = offset + 1, offset + count do
            local itemInfo = C_SpellBook.GetSpellBookItemInfo(slot, bank)
            local itemType = itemInfo and itemInfo.itemType or nil
            local spellID = itemInfo and (itemInfo.spellID or itemInfo.actionID) or nil
            if spellID and not seenSpellIDs[spellID] and (spellType == nil or itemType == spellType) then
                local spellInfo = safeGetSpellInfo(spellID)
                if spellInfo and spellInfo.name then
                    seenSpellIDs[spellID] = true
                    local subtitle = itemInfo and itemInfo.isPassive and "Spellbook - Passive" or "Spellbook"
                    if type(skillLineName) == "string" and skillLineName ~= "" then
                        subtitle = string.format("%s - %s", subtitle, skillLineName)
                    end
                    entries[#entries + 1] = self:CreateIndexEntry({
                        kind = "spell",
                        title = spellInfo.name,
                        subtitle = subtitle,
                        icon = spellInfo.iconID or SPELL_ICON_TEXTURE,
                        spellID = spellID,
                        searchTags = "spell spellbook player spells",
                        priority = itemInfo and itemInfo.isPassive and 8 or 12,
                    })
                end
            end
        end
    end
end

function SearchOverlay:AddTalentEntries(entries)
    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or nil
    if specID and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_Traits and C_Traits.GetConfigInfo then
        local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
        if type(configIDs) ~= "table" then
            configIDs = {}
        end
        local activeConfigID = C_ClassTalents.GetLastSelectedSavedConfigID and C_ClassTalents.GetLastSelectedSavedConfigID(specID) or nil
        for index = 1, #configIDs do
            local configID = configIDs[index]
            local configInfo = C_Traits.GetConfigInfo(configID)
            local configName = configInfo and configInfo.name or nil
            if type(configName) == "string" and configName ~= "" then
                entries[#entries + 1] = self:CreateIndexEntry({
                    kind = "talent",
                    title = configName,
                    subtitle = configID == activeConfigID and "Talent Loadout - Active" or "Talent Loadout",
                    icon = TALENT_ICON_TEXTURE,
                    loadoutConfigID = configID,
                    loadoutIndex = index,
                    searchTags = "talent loadout talents specialization spec",
                    priority = configID == activeConfigID and 18 or 15,
                })
            end
        end
    end

    local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil
    if not activeConfigID or not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then
        return
    end

    local configInfo = C_Traits.GetConfigInfo(activeConfigID)
    local treeIDs = configInfo and configInfo.treeIDs or nil
    if type(treeIDs) ~= "table" then
        return
    end

    local seenSpellIDs = {}
    for treeIndex = 1, #treeIDs do
        local treeID = treeIDs[treeIndex]
        local nodeIDs = C_Traits.GetTreeNodes(treeID) or {}
        if type(nodeIDs) ~= "table" then
            nodeIDs = {}
        end
        for nodeIndex = 1, #nodeIDs do
            local nodeID = nodeIDs[nodeIndex]
            local nodeInfo = C_Traits.GetNodeInfo(activeConfigID, nodeID)
            local activeEntry = nodeInfo and nodeInfo.activeEntry or nil
            if activeEntry and tonumber(activeEntry.rank) and tonumber(activeEntry.rank) > 0 then
                local entryInfo = C_Traits.GetEntryInfo(activeConfigID, activeEntry.entryID)
                local definitionID = entryInfo and entryInfo.definitionID or nil
                if definitionID then
                    local definitionInfo = C_Traits.GetDefinitionInfo(definitionID)
                    local spellID = definitionInfo and (definitionInfo.overriddenSpellID or definitionInfo.spellID) or nil
                    if spellID and not seenSpellIDs[spellID] then
                        local spellInfo = safeGetSpellInfo(spellID)
                        if spellInfo and spellInfo.name then
                            seenSpellIDs[spellID] = true
                            entries[#entries + 1] = self:CreateIndexEntry({
                                kind = "talent",
                                title = spellInfo.name,
                                subtitle = "Active Talent",
                                icon = spellInfo.iconID or TALENT_ICON_TEXTURE,
                                spellID = spellID,
                                searchTags = "talent active node hero class spec specialization",
                                priority = 13,
                            })
                        end
                    end
                end
            end
        end
    end
end

function SearchOverlay:AddBagEntries(entries)
    local store = vesperTools:GetModule("BagsStore", true)
    if not store or type(store.GetDisplayCharacters) ~= "function" or type(store.GetCharacterBagSnapshot) ~= "function" then
        return
    end

    local characters = store:GetDisplayCharacters()
    if type(characters) ~= "table" then
        return
    end

    for i = 1, #characters do
        local character = characters[i]
        local snapshot = store:GetCharacterBagSnapshot(character.key)
        local carried = snapshot and snapshot.carried or nil
        local bags = carried and carried.bags or nil
        local itemTotals = carried and carried.itemTotals or nil
        if type(bags) == "table" then
            local seenItems = {}
            for _, bag in pairs(bags) do
                if type(bag) == "table" and type(bag.slots) == "table" then
                    for slotID = 1, tonumber(bag.size) or 0 do
                        local record = bag.slots[slotID]
                        if type(record) == "table" and record.itemID and not seenItems[record.itemID] then
                            seenItems[record.itemID] = true
                            local count = type(itemTotals) == "table" and tonumber(itemTotals[record.itemID]) or tonumber(record.stackCount) or 1
                            entries[#entries + 1] = self:CreateIndexEntry({
                                kind = "bag",
                                title = record.itemName or tostring(record.itemID),
                                subtitle = buildSubtitle("Bags", character.fullName, count),
                                icon = record.iconFileID or BAG_ICON_TEXTURE,
                                itemID = record.itemID,
                                itemName = record.itemName,
                                queryText = record.itemName,
                                characterKey = character.key,
                                categoryKey = record.categoryKey,
                                bagID = record.bagID,
                                slotID = record.slotID,
                                isCurrentCharacter = character.isCurrent == true,
                                searchText = record.searchText,
                                searchTags = string.format("bags inventory carried %s", character.fullName or ""),
                                priority = character.isCurrent and 26 or 6,
                            })
                        end
                    end
                end
            end
        end
    end
end

function SearchOverlay:AddBankEntries(entries)
    local store = vesperTools:GetModule("BankStore", true)
    if not store or type(store.GetDisplayCharacters) ~= "function" or type(store.GetCharacterBankSnapshot) ~= "function" then
        return
    end

    local characters = store:GetDisplayCharacters()
    if type(characters) ~= "table" then
        return
    end

    for i = 1, #characters do
        local character = characters[i]
        local record = store:GetCharacterBankSnapshot(character.key)
        local bank = record and record.bank or nil
        local bags = bank and bank.bags or nil
        local itemTotals = bank and bank.itemTotals or nil
        if type(bags) == "table" then
            local seenItems = {}
            for _, bag in pairs(bags) do
                if type(bag) == "table" and type(bag.slots) == "table" then
                    for slotID = 1, tonumber(bag.size) or 0 do
                        local itemRecord = bag.slots[slotID]
                        if type(itemRecord) == "table" and itemRecord.itemID and not seenItems[itemRecord.itemID] then
                            seenItems[itemRecord.itemID] = true
                            local count = type(itemTotals) == "table" and tonumber(itemTotals[itemRecord.itemID]) or tonumber(itemRecord.stackCount) or 1
                            entries[#entries + 1] = self:CreateIndexEntry({
                                kind = "bank",
                                title = itemRecord.itemName or tostring(itemRecord.itemID),
                                subtitle = buildSubtitle("Bank", character.fullName, count),
                                icon = itemRecord.iconFileID or BANK_ICON_TEXTURE,
                                itemID = itemRecord.itemID,
                                itemName = itemRecord.itemName,
                                queryText = itemRecord.itemName,
                                viewKey = "character",
                                characterKey = character.key,
                                categoryKey = itemRecord.categoryKey,
                                bagID = itemRecord.bagID,
                                slotID = itemRecord.slotID,
                                isCurrentCharacter = character.isCurrent == true,
                                searchText = itemRecord.searchText,
                                searchTags = string.format("bank storage %s", character.fullName or ""),
                                priority = character.isCurrent and 20 or (character.isLive and 12 or 9),
                            })
                        end
                    end
                end
            end
        end
    end

    if type(store.GetWarbandBankSnapshot) ~= "function" then
        return
    end

    local warband = store:GetWarbandBankSnapshot()
    local bags = warband and warband.bags or nil
    local itemTotals = warband and warband.itemTotals or nil
    if type(bags) ~= "table" then
        return
    end

    local seenItems = {}
    for _, bag in pairs(bags) do
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and record.itemID and not seenItems[record.itemID] then
                    seenItems[record.itemID] = true
                    local count = type(itemTotals) == "table" and tonumber(itemTotals[record.itemID]) or tonumber(record.stackCount) or 1
                    entries[#entries + 1] = self:CreateIndexEntry({
                        kind = "bank",
                        title = record.itemName or tostring(record.itemID),
                        subtitle = buildSubtitle("Warband Bank", nil, count),
                        icon = record.iconFileID or BANK_ICON_TEXTURE,
                        itemID = record.itemID,
                        itemName = record.itemName,
                        queryText = record.itemName,
                        viewKey = "warband",
                        categoryKey = record.categoryKey,
                        bagID = record.bagID,
                        slotID = record.slotID,
                        searchText = record.searchText,
                        searchTags = "warband bank shared storage account",
                        priority = 10,
                    })
                end
            end
        end
    end
end

function SearchOverlay:RebuildIndex()
    local entries = {}

    if type(self.staticEntries) ~= "table" then
        local ok, staticEntries = pcall(self.BuildStaticEntries, self)
        self.staticEntries = ok and type(staticEntries) == "table" and staticEntries or {}
    end

    for i = 1, #self.staticEntries do
        entries[#entries + 1] = self.staticEntries[i]
    end

    -- Keep search usable even if one retail API-backed provider changes underneath us.
    local providers = {
        "AddSettingsEntries",
        "AddBlizzardSettingEntries",
        "AddToyEntries",
        "AddSpellEntries",
        "AddTalentEntries",
        "AddBagEntries",
        "AddBankEntries",
    }

    for i = 1, #providers do
        local method = self[providers[i]]
        if type(method) == "function" then
            pcall(method, self, entries)
        end
    end

    self.indexEntries = entries
    self.indexDirty = false
end

function SearchOverlay:ScoreEntry(entry, tokens)
    if type(entry) ~= "table" or type(entry.searchText) ~= "string" then
        return nil
    end

    local score = KIND_PRIORITIES[entry.kind] or 0
    score = score + (tonumber(entry.priority) or 0)
    if entry.kind == "bag" and entry.isCurrentCharacter then
        score = score + 24
    elseif entry.kind == "bank" and entry.isCurrentCharacter then
        score = score + 18
    end

    if not tokens or #tokens == 0 then
        return nil
    end

    local titleText = entry.normalizedTitle or ""
    for i = 1, #tokens do
        local token = tokens[i]
        if not string.find(entry.searchText, token, 1, true) then
            return nil
        end

        if titleText == token then
            score = score + 420
        elseif string.sub(titleText, 1, #token) == token then
            score = score + 280
        elseif string.find(titleText, " " .. token, 1, true) then
            score = score + 240
        elseif string.sub(entry.searchText, 1, #token) == token then
            score = score + 180
        elseif string.find(entry.searchText, " " .. token, 1, true) then
            score = score + 150
        else
            score = score + 120
        end
    end

    local fullQuery = table.concat(tokens, " ")
    if titleText == fullQuery then
        score = score + 180
    end

    return score
end

function SearchOverlay:EnsureFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "vesperToolsSearchOverlay", UIParent)
    frame:SetSize(FRAME_WIDTH, SEARCH_BAR_HEIGHT + RESULTS_TOP_GAP + FIXED_RESULTS_PANEL_HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, FRAME_TOP_OFFSET)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:Hide()
    vesperTools:ApplyAddonWindowLayer(frame, OVERLAY_BASE_FRAME_LEVEL)
    vesperTools:RegisterEscapeFrame(frame, function()
        self:HideOverlay()
    end)
    self.frame = frame

    local accentR, accentG, accentB = getClassAccentColor()

    local searchBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    searchBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    searchBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    searchBar:SetHeight(SEARCH_BAR_HEIGHT)
    searchBar:EnableMouse(true)
    vesperTools:ApplyRoundedWindowBackdrop(searchBar)
    searchBar:SetBackdropColor(0.08, 0.08, 0.1, 0.94)
    searchBar:SetBackdropBorderColor(accentR, accentG, accentB, 1)
    self.searchBar = searchBar

    local searchIcon = searchBar:CreateTexture(nil, "ARTWORK")
    searchIcon:SetPoint("LEFT", searchBar, "LEFT", 10, 0)
    searchIcon:SetSize(18, 18)
    searchIcon:SetTexture(SEARCH_ICON_TEXTURE)
    searchIcon:SetVertexColor(1, 1, 1, 0.78)

    local searchBox = CreateFrame("EditBox", nil, searchBar)
    searchBox:SetPoint("TOPLEFT", searchBar, "TOPLEFT", 34, 0)
    searchBox:SetPoint("BOTTOMRIGHT", searchBar, "BOTTOMRIGHT", -(SEARCH_CLEAR_BUTTON_SIZE + 12), 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(120)
    searchBox:SetTextInsets(SEARCH_BAR_TEXT_INSET, SEARCH_BAR_TEXT_INSET, 0, 0)
    setFontIfPresent(searchBox, 13, "")
    searchBox:SetScript("OnTextChanged", function()
        self:UpdatePlaceholder()
        self:ScheduleRefresh(SEARCH_DEBOUNCE_SECONDS)
    end)
    searchBox:SetScript("OnEditFocusGained", function()
        self:UpdatePlaceholder()
    end)
    searchBox:SetScript("OnEditFocusLost", function()
        self:UpdatePlaceholder()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        self:HideOverlay()
    end)
    searchBox:SetScript("OnEnterPressed", function()
        self:ActivateSelectedResult()
    end)
    searchBox:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then
            self:MoveSelection(-1)
        elseif key == "DOWN" then
            self:MoveSelection(1)
        end
    end)
    searchBox:SetScript("OnTabPressed", function()
        self:MoveSelection(1)
    end)
    self.searchBox = searchBox

    local placeholder = searchBar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBar, "LEFT", 46, 0)
    placeholder:SetPoint("RIGHT", searchBar, "RIGHT", -(SEARCH_CLEAR_BUTTON_SIZE + 16), 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(false)
    placeholder:SetText(SEARCH_PLACEHOLDER_TEXT)
    placeholder:SetTextColor(0.82, 0.86, 0.92, 0.52)
    setFontIfPresent(placeholder, 12, "")
    self.searchPlaceholder = placeholder

    local clearButton = vesperTools:CreateModernCloseButton(searchBar, function()
        if self.searchBox then
            self.searchBox:SetText("")
            self.searchBox:SetFocus()
        end
        self:ScheduleRefresh(0)
    end, {
        size = SEARCH_CLEAR_BUTTON_SIZE,
        iconScale = 0.54,
        backgroundAlpha = 0,
        borderAlpha = 0,
        hoverAlpha = 0.08,
        pressedAlpha = 0.12,
        iconAlpha = 0.82,
        iconHoverAlpha = 1,
    })
    clearButton:SetPoint("RIGHT", searchBar, "RIGHT", -6, 0)
    self.searchClearButton = clearButton

    local resultsFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    resultsFrame:SetPoint("TOPLEFT", searchBar, "BOTTOMLEFT", 0, -RESULTS_TOP_GAP)
    resultsFrame:SetPoint("TOPRIGHT", searchBar, "BOTTOMRIGHT", 0, -RESULTS_TOP_GAP)
    resultsFrame:SetHeight(FIXED_RESULTS_PANEL_HEIGHT)
    resultsFrame:EnableMouse(true)
    vesperTools:ApplyRoundedWindowBackdrop(resultsFrame)
    resultsFrame:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    resultsFrame:SetBackdropBorderColor(accentR, accentG, accentB, 1)
    self.resultsFrame = resultsFrame

    local scrollFrame = CreateFrame("ScrollFrame", "vesperToolsSearchResultsScrollFrame", resultsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", RESULTS_SIDE_PADDING, -RESULTS_SIDE_PADDING)
    scrollFrame:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -RESULTS_SCROLL_FRAME_RIGHT_PADDING, RESULTS_BOTTOM_PADDING)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(selfFrame, delta)
        local current = selfFrame:GetVerticalScroll() or 0
        local maximum = math.max(0, (selfFrame.contentHeight or 0) - (selfFrame:GetHeight() or 0))
        local step = (RESULT_ROW_HEIGHT + RESULT_ROW_GAP) * RESULTS_SCROLL_STEP_ROWS
        local nextValue = math.max(0, math.min(maximum, current - (delta * step)))
        selfFrame:SetVerticalScroll(nextValue)
    end)
    self.resultsScrollFrame = scrollFrame
    self.resultsScrollBar = scrollFrame.ScrollBar or _G.vesperToolsSearchResultsScrollFrameScrollBar

    local resultsContainer = CreateFrame("Frame", nil, scrollFrame)
    resultsContainer:SetSize(1, 1)
    scrollFrame:SetScrollChild(resultsContainer)
    self.resultsContainer = resultsContainer

    local emptyText = resultsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", RESULTS_SIDE_PADDING + 2, -(RESULTS_SIDE_PADDING + 2))
    emptyText:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -(RESULTS_SCROLL_FRAME_RIGHT_PADDING + 4), -(RESULTS_SIDE_PADDING + 2))
    emptyText:SetJustifyH("LEFT")
    emptyText:SetJustifyV("TOP")
    emptyText:SetSpacing(2)
    emptyText:SetText(SEARCH_NO_RESULTS_TEXT)
    setFontIfPresent(emptyText, 12, "")
    self.emptyText = emptyText

    resultsFrame:Hide()
    frame:SetHeight(SEARCH_BAR_HEIGHT)

    frame:SetScript("OnHide", function()
        self:CancelPendingRefresh()
    end)

    self:RefreshWindowLayer()
    self:RefreshFonts()
end

function SearchOverlay:RefreshFonts()
    if not self.frame then
        return
    end

    setFontIfPresent(self.searchBox, 13, "")
    setFontIfPresent(self.searchPlaceholder, 12, "")
    setFontIfPresent(self.emptyText, 12, "")

    for i = 1, #self.resultButtons do
        local button = self.resultButtons[i]
        if button then
            setFontIfPresent(button.title, 13, "")
            setFontIfPresent(button.subtitle, 11, "")
            setFontIfPresent(button.kindText, 10, "OUTLINE")
        end
    end
end

function SearchOverlay:CancelPendingRefresh()
    if self.pendingSearchTimer and type(self.pendingSearchTimer.Cancel) == "function" then
        self.pendingSearchTimer:Cancel()
    end
    self.pendingSearchTimer = nil
end

function SearchOverlay:ScheduleRefresh(delaySeconds)
    self:CancelPendingRefresh()

    local delay = tonumber(delaySeconds) or 0
    if delay <= 0 then
        self:RefreshResults()
        return
    end

    self.pendingSearchTimer = C_Timer.NewTimer(delay, function()
        self.pendingSearchTimer = nil
        self:RefreshResults()
    end)
end

function SearchOverlay:UpdatePlaceholder()
    if not self.searchBox or not self.searchPlaceholder then
        return
    end

    local text = self.searchBox:GetText()
    local hasText = type(text) == "string" and text ~= ""
    if hasText then
        self.searchPlaceholder:Hide()
    else
        self.searchPlaceholder:Show()
    end

    if self.searchClearButton then
        self.searchClearButton:SetEnabled(hasText)
        self.searchClearButton:SetAlpha(hasText and 1 or 0.42)
    end
end

function SearchOverlay:AcquireResultButton(index)
    local button = self.resultButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, self.resultsContainer, "BackdropTemplate")
    button:SetHeight(RESULT_ROW_HEIGHT)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.1, 0.82)
    button:SetBackdropBorderColor(1, 1, 1, 0.08)

    button.hoverTexture = button:CreateTexture(nil, "ARTWORK")
    button.hoverTexture:SetAllPoints()
    button.hoverTexture:SetColorTexture(1, 1, 1, 0.06)
    button.hoverTexture:Hide()

    local accentR, accentG, accentB = getClassAccentColor()
    button.selectionTexture = button:CreateTexture(nil, "ARTWORK")
    button.selectionTexture:SetAllPoints()
    button.selectionTexture:SetColorTexture(accentR, accentG, accentB, 0.2)
    button.selectionTexture:Hide()

    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("LEFT", button, "LEFT", 10, 0)
    icon:SetSize(22, 22)
    button.icon = icon

    local kindText = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    kindText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -8)
    kindText:SetJustifyH("RIGHT")
    kindText:SetWordWrap(false)
    button.kindText = kindText

    local title = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -7)
    title:SetPoint("RIGHT", kindText, "LEFT", -8, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    button.title = title

    local subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -24)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    subtitle:SetTextColor(0.78, 0.82, 0.9, 1)
    button.subtitle = subtitle

    button:SetScript("OnEnter", function()
        self:SetSelectedResultIndex(index)
        button.hoverTexture:Show()
    end)
    button:SetScript("OnLeave", function()
        if self.selectedResultIndex ~= index then
            button.hoverTexture:Hide()
        end
    end)
    button:SetScript("OnClick", function()
        if button.entry then
            self:ActivateResult(button.entry)
        end
    end)

    self.resultButtons[index] = button
    self:RefreshWindowLayer()
    self:RefreshFonts()
    return button
end

function SearchOverlay:EnsureSelectedResultVisible()
    if not self.resultsScrollFrame then
        return
    end

    local index = tonumber(self.selectedResultIndex) or 0
    if index < 1 or index > #self.visibleResults then
        return
    end

    local rowTop = (index - 1) * (RESULT_ROW_HEIGHT + RESULT_ROW_GAP)
    local rowBottom = rowTop + RESULT_ROW_HEIGHT
    local currentScroll = self.resultsScrollFrame:GetVerticalScroll() or 0
    local viewportHeight = self.resultsScrollFrame:GetHeight() or FIXED_RESULTS_HEIGHT

    if rowTop < currentScroll then
        self.resultsScrollFrame:SetVerticalScroll(rowTop)
    elseif rowBottom > (currentScroll + viewportHeight) then
        self.resultsScrollFrame:SetVerticalScroll(math.max(0, rowBottom - viewportHeight))
    end
end

function SearchOverlay:SetSelectedResultIndex(index)
    if index == self.selectedResultIndex then
        return
    end

    self.selectedResultIndex = index
    for i = 1, #self.resultButtons do
        local button = self.resultButtons[i]
        local isSelected = button and button:IsShown() and i == index
        if button then
            button.selectionTexture:SetShown(isSelected)
            button.hoverTexture:SetShown(isSelected)
        end
    end

    self:EnsureSelectedResultVisible()
end

function SearchOverlay:MoveSelection(direction)
    if #self.visibleResults == 0 then
        return
    end

    local nextIndex = self.selectedResultIndex
    if nextIndex < 1 or nextIndex > #self.visibleResults then
        nextIndex = 1
    else
        nextIndex = nextIndex + (direction < 0 and -1 or 1)
        if nextIndex < 1 then
            nextIndex = #self.visibleResults
        elseif nextIndex > #self.visibleResults then
            nextIndex = 1
        end
    end

    self:SetSelectedResultIndex(nextIndex)
end

function SearchOverlay:ActivateSelectedResult()
    local index = self.selectedResultIndex
    if index < 1 or index > #self.visibleResults then
        index = 1
    end

    local entry = self.visibleResults[index]
    if entry then
        self:ActivateResult(entry)
    end
end

function SearchOverlay:ActivateAction(entry)
    local actionKey = entry and entry.actionKey or nil
    if actionKey == "open_config" then
        vesperTools:OpenConfig()
        return
    end

    if actionKey == "open_roster" then
        local Roster = vesperTools:GetModule("Roster", true)
        if Roster and type(Roster.ShowRoster) == "function" then
            Roster:ShowRoster()
        end
        return
    end

    if actionKey == "open_portals" then
        local Portals = vesperTools:GetModule("Portals", true)
        if not Portals then
            return
        end

        if Portals.VesperPortalsUI and Portals.VesperPortalsUI:IsShown() then
            Portals.VesperPortalsUI:Show()
            if Portals.VesperPortalsUI.Raise then
                Portals.VesperPortalsUI:Raise()
            end
        elseif type(Portals.Toggle) == "function" then
            Portals:Toggle()
        end
        return
    end

    if actionKey == "open_bags" then
        local BagsWindow = vesperTools:GetModule("BagsWindow", true)
        if BagsWindow and type(BagsWindow.ShowWindow) == "function" then
            BagsWindow:ShowWindow()
        end
        return
    end

    if actionKey == "open_bank" then
        local BankWindow = vesperTools:GetModule("BankWindow", true)
        if BankWindow and type(BankWindow.ShowWindow) == "function" then
            BankWindow:ShowWindow("character")
        end
        return
    end

    if actionKey == "open_warband_bank" then
        local BankWindow = vesperTools:GetModule("BankWindow", true)
        if BankWindow and type(BankWindow.ShowWindow) == "function" then
            BankWindow:ShowWindow("warband")
        end
        return
    end

    if actionKey == "open_vault" then
        local VaultWindow = vesperTools:GetModule("VaultWindow", true)
        if VaultWindow and type(VaultWindow.ShowWindow) == "function" then
            VaultWindow:ShowWindow()
        elseif VaultWindow and type(VaultWindow.Toggle) == "function" then
            VaultWindow:Toggle()
        end
        return
    end

    if actionKey == "open_click_cast_bindings" then
        openClickCastBindings()
    end
end

function SearchOverlay:ActivateResult(entry)
    if type(entry) ~= "table" then
        return
    end

    self:HideOverlay()

    if entry.kind == "action" then
        self:ActivateAction(entry)
        return
    end

    if entry.kind == "config" then
        local Configuration = vesperTools:GetModule("Configuration", true)
        if Configuration and type(Configuration.OpenConfig) == "function" then
            Configuration:OpenConfig()
            if entry.tabKey and type(Configuration.SetActiveTab) == "function" then
                Configuration:SetActiveTab(entry.tabKey)
            end
        end
        return
    end

    if entry.kind == "settings" then
        openSettingsCategoryByPath(entry.categoryName, entry.subcategoryName)
        return
    end

    if entry.kind == "toy" then
        openCollectionsJournal()
        return
    end

    if entry.kind == "spell" then
        openSpellBookFrame()
        return
    end

    if entry.kind == "talent" then
        openTalentFrame()
        if entry.loadoutConfigID and not (InCombatLockdown and InCombatLockdown()) then
            if ClassTalentHelper and type(ClassTalentHelper.SwitchToLoadoutByIndex) == "function" and entry.loadoutIndex then
                ClassTalentHelper.SwitchToLoadoutByIndex(entry.loadoutIndex)
            elseif C_ClassTalents and type(C_ClassTalents.SetActiveConfigID) == "function" then
                C_ClassTalents.SetActiveConfigID(entry.loadoutConfigID)
            end
        end
        return
    end

    if entry.kind == "bag" then
        local BagsWindow = vesperTools:GetModule("BagsWindow", true)
        if BagsWindow and type(BagsWindow.OpenSearchResult) == "function" then
            BagsWindow:OpenSearchResult(entry)
        elseif BagsWindow and type(BagsWindow.ShowWindow) == "function" then
            BagsWindow:ShowWindow()
        end
        return
    end

    if entry.kind == "bank" then
        local BankWindow = vesperTools:GetModule("BankWindow", true)
        if BankWindow and type(BankWindow.OpenSearchResult) == "function" then
            BankWindow:OpenSearchResult(entry)
        elseif BankWindow and type(BankWindow.ShowWindow) == "function" then
            BankWindow:ShowWindow(entry.viewKey)
        end
    end
end

function SearchOverlay:LayoutVisibleResults()
    local resultCount = #self.visibleResults
    local resultsHeight = math.max(1, (resultCount * RESULT_ROW_HEIGHT) + (math.max(resultCount - 1, 0) * RESULT_ROW_GAP))
    local viewportWidth = math.max(1, math.floor((self.resultsScrollFrame and self.resultsScrollFrame:GetWidth() or (FRAME_WIDTH - RESULTS_SIDE_PADDING - RESULTS_SCROLL_FRAME_RIGHT_PADDING)) + 0.5))

    self.resultsContainer:SetWidth(viewportWidth)
    self.resultsContainer:SetHeight(resultsHeight)
    if self.resultsScrollFrame then
        self.resultsScrollFrame.contentHeight = resultsHeight
    end

    for i = 1, #self.resultButtons do
        if i > resultCount and self.resultButtons[i] then
            self.resultButtons[i]:Hide()
        end
    end

    if resultCount == 0 then
        self.emptyText:Hide()
        if self.resultsScrollFrame then
            self.resultsScrollFrame:SetVerticalScroll(0)
            self.resultsScrollFrame:Hide()
        end
        if self.resultsScrollBar then
            self.resultsScrollBar:Hide()
        end
        if self.resultsFrame then
            self.resultsFrame:Hide()
        end
        self:SetSelectedResultIndex(0)
        self.frame:SetHeight(SEARCH_BAR_HEIGHT)
        return
    else
        if self.resultsScrollFrame then
            self.resultsScrollFrame:Show()
        end
        if self.resultsFrame then
            self.resultsFrame:Show()
        end
    end

    for i = 1, resultCount do
        local entry = self.visibleResults[i]
        local button = self:AcquireResultButton(i)
        button.entry = entry
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.resultsContainer, "TOPLEFT", 0, -((i - 1) * (RESULT_ROW_HEIGHT + RESULT_ROW_GAP)))
        button:SetPoint("TOPRIGHT", self.resultsContainer, "TOPRIGHT", 0, -((i - 1) * (RESULT_ROW_HEIGHT + RESULT_ROW_GAP)))
        button.icon:SetTexture(entry.icon or FALLBACK_ICON_TEXTURE)
        button.title:SetText(entry.title or UNKNOWN)
        button.subtitle:SetText(entry.subtitle or "")
        button.kindText:SetText(KIND_LABELS[entry.kind] or "")
        button.selectionTexture:SetShown(i == self.selectedResultIndex)
        button.hoverTexture:SetShown(i == self.selectedResultIndex)
        button:Show()
    end

    if resultCount > 0 then
        if self.selectedResultIndex < 1 or self.selectedResultIndex > resultCount then
            self:SetSelectedResultIndex(1)
        else
            self:SetSelectedResultIndex(self.selectedResultIndex)
        end
    end

    if resultCount > 0 and self.resultsScrollFrame then
        local maximumScroll = math.max(0, resultsHeight - (self.resultsScrollFrame:GetHeight() or FIXED_RESULTS_HEIGHT))
        local currentScroll = self.resultsScrollFrame:GetVerticalScroll() or 0
        self.resultsScrollFrame:SetVerticalScroll(math.max(0, math.min(maximumScroll, currentScroll)))
        self:EnsureSelectedResultVisible()
    end

    if self.resultsScrollBar then
        self.resultsScrollBar:SetShown(resultCount > MAX_VISIBLE_RESULT_ROWS)
    end

    self.frame:SetHeight(SEARCH_BAR_HEIGHT + RESULTS_TOP_GAP + FIXED_RESULTS_PANEL_HEIGHT)
end

function SearchOverlay:RefreshResults()
    if not (self.frame and self.frame:IsShown()) then
        return
    end

    if self.indexDirty then
        self:RebuildIndex()
    end

    local query = self.searchBox and self.searchBox:GetText() or ""
    local normalizedQuery = normalizeSearchText(query)
    if not normalizedQuery or string.len(normalizedQuery) < MIN_SEARCH_QUERY_CHARACTERS then
        wipe(self.visibleResults)
        self.selectedResultIndex = 0
        if self.resultsScrollFrame then
            self.resultsScrollFrame:SetVerticalScroll(0)
        end
        self:LayoutVisibleResults()
        return
    end

    local tokens = tokenizeSearch(query)
    local scored = {}

    for i = 1, #self.indexEntries do
        local entry = self.indexEntries[i]
        local score = self:ScoreEntry(entry, tokens)
        if score then
            scored[#scored + 1] = {
                entry = entry,
                score = score,
            }
        end
    end

    table.sort(scored, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.entry and b.entry and a.entry.kind == "bag" and b.entry.kind == "bag" and a.entry.isCurrentCharacter ~= b.entry.isCurrentCharacter then
            return a.entry.isCurrentCharacter == true
        end
        local aTitle = a.entry and a.entry.title or ""
        local bTitle = b.entry and b.entry.title or ""
        return aTitle < bTitle
    end)

    wipe(self.visibleResults)
    local limit = math.min(#scored, MAX_SEARCH_RESULTS)
    for i = 1, limit do
        self.visibleResults[i] = scored[i].entry
    end

    if self.resultsScrollFrame then
        self.resultsScrollFrame:SetVerticalScroll(0)
    end

    self:LayoutVisibleResults()
end

function SearchOverlay:ShowOverlay()
    self:EnsureFrame()
    self:RefreshWindowLayer()
    self.indexDirty = true
    if self.resultsFrame then
        self.resultsFrame:Hide()
    end
    self.frame:Show()
    self.frame:SetHeight(SEARCH_BAR_HEIGHT)
    if self.searchBox then
        self.searchBox:SetText("")
        self.searchBox:ClearFocus()
    end
    self:UpdatePlaceholder()
    self:ScheduleRefresh(0)
end

function SearchOverlay:HideOverlay()
    self:CancelPendingRefresh()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end
end
