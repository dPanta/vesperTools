local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local BlizzardSettingsIndex = vesperTools:NewModule("BlizzardSettingsIndex", "AceEvent-3.0")

local SETTINGS_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\Cogwheel-64"
local MAX_LAYOUT_SCAN_DEPTH = 7

local SKIP_LAYOUT_KEYS = {
    category = true,
    categories = true,
    frame = true,
    frames = true,
    owner = true,
    owners = true,
    parent = true,
    pool = true,
    pools = true,
    registry = true,
    scrollBox = true,
    ScrollBox = true,
}

local function collapseWhitespace(value)
    if type(value) ~= "string" then
        return nil
    end

    local text = string.gsub(value, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then
        return nil
    end

    return text
end

local function shallowCopy(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function addUniqueText(parts, seen, value)
    local text = collapseWhitespace(value)
    if not text then
        return
    end

    local lookupKey = string.lower(text)
    if seen[lookupKey] then
        return
    end

    seen[lookupKey] = true
    parts[#parts + 1] = text
end

local function appendValueStrings(parts, seen, value, visited, depth)
    local valueType = type(value)
    if valueType == "string" then
        addUniqueText(parts, seen, value)
        return
    end

    if valueType ~= "table" then
        return
    end

    visited = visited or {}
    if visited[value] then
        return
    end
    visited[value] = true

    local currentDepth = tonumber(depth) or 0
    if currentDepth >= 3 then
        return
    end

    for key, nestedValue in pairs(value) do
        if type(key) == "number" then
            appendValueStrings(parts, seen, nestedValue, visited, currentDepth + 1)
        elseif key == "name" or key == "text" or key == "label" or key == "title" or key == "tooltip" or key == "description" or key == "desc" or key == "searchTag" or key == "searchTags" or key == "searchtags" or key == "variable" or key == "cvar" then
            appendValueStrings(parts, seen, nestedValue, visited, currentDepth + 1)
        end
    end
end

local function safeMethodValue(object, methodName, ...)
    local objectType = type(object)
    if objectType ~= "table" and objectType ~= "userdata" then
        return nil
    end

    local method = object[methodName]
    if type(method) ~= "function" then
        return nil
    end

    local ok, result = pcall(method, object, ...)
    if ok then
        return result
    end

    return nil
end

local function getSettingsCategoryList()
    if not (Settings and SettingsPanel and SettingsPanel.GetCategoryList) then
        return nil
    end

    local categoryList = SettingsPanel:GetCategoryList()
    if categoryList and type(categoryList.CreateCategories) == "function" then
        pcall(categoryList.CreateCategories, categoryList)
    end

    return categoryList
end

local function getCategoryLayout(category)
    if not (SettingsPanel and type(SettingsPanel.GetLayout) == "function" and category) then
        return nil
    end

    local ok, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, category)
    if ok then
        return layout
    end

    return nil
end

local function isInitializerCandidate(value)
    if type(value) ~= "table" then
        return false
    end

    if type(value.GetSetting) == "function" or type(value.GetTooltip) == "function" or type(value.GetData) == "function" then
        return true
    end

    if type(value.AddSearchTags) == "function" or type(value.InitFrame) == "function" or type(value.SetSetting) == "function" then
        return true
    end

    if type(value.data) == "table" and (type(value.template) == "string" or type(value.templateName) == "string") then
        return true
    end

    return false
end

local function shouldSkipLayoutKey(key)
    if type(key) ~= "string" then
        return false
    end

    if SKIP_LAYOUT_KEYS[key] then
        return true
    end

    local lowerKey = string.lower(key)
    return string.find(lowerKey, "frame", 1, true) ~= nil
        or string.find(lowerKey, "pool", 1, true) ~= nil
        or string.find(lowerKey, "registry", 1, true) ~= nil
        or string.find(lowerKey, "scroll", 1, true) ~= nil
end

local function collectInitializers(value, out, seenTables, depth)
    if type(value) ~= "table" then
        return
    end

    if seenTables[value] then
        return
    end
    seenTables[value] = true

    local currentDepth = tonumber(depth) or 0
    if currentDepth > MAX_LAYOUT_SCAN_DEPTH then
        return
    end

    if isInitializerCandidate(value) then
        out[#out + 1] = value
    end

    for key, nestedValue in pairs(value) do
        if type(nestedValue) == "table" and not shouldSkipLayoutKey(key) then
            collectInitializers(nestedValue, out, seenTables, currentDepth + 1)
        end
    end
end

local function getInitializerData(initializer)
    local data = safeMethodValue(initializer, "GetData")
    if type(data) == "table" then
        return data
    end

    if type(initializer.data) == "table" then
        return initializer.data
    end

    return nil
end

local function getInitializerTitle(initializer, data)
    return collapseWhitespace(
        safeMethodValue(initializer, "GetName")
        or (data and (data.name or data.label or data.text or data.title))
        or initializer.name
        or initializer.label
        or initializer.text
        or initializer.title
    )
end

local function getTemplateName(initializer, data)
    return collapseWhitespace(
        initializer.template
        or initializer.templateName
        or (data and (data.template or data.templateName))
    )
end

local function buildSubtitle(categoryName, subcategoryName)
    if subcategoryName then
        return string.format("Settings - %s / %s", categoryName, subcategoryName)
    end

    return string.format("Settings - %s", categoryName)
end

local function extractInitializerSpec(initializer, categoryName, subcategoryName)
    local data = getInitializerData(initializer)
    local title = getInitializerTitle(initializer, data)
    if not title then
        return nil
    end

    local tooltipParts = {}
    local tooltipSeen = {}
    addUniqueText(tooltipParts, tooltipSeen, safeMethodValue(initializer, "GetTooltip"))
    addUniqueText(tooltipParts, tooltipSeen, data and data.tooltip)
    addUniqueText(tooltipParts, tooltipSeen, data and data.description)
    addUniqueText(tooltipParts, tooltipSeen, data and data.desc)
    addUniqueText(tooltipParts, tooltipSeen, data and data.helpTip)
    addUniqueText(tooltipParts, tooltipSeen, data and data.hint)
    addUniqueText(tooltipParts, tooltipSeen, initializer.tooltip)
    addUniqueText(tooltipParts, tooltipSeen, initializer.description)
    addUniqueText(tooltipParts, tooltipSeen, initializer.desc)

    local metadataParts = {}
    local metadataSeen = {}
    addUniqueText(metadataParts, metadataSeen, table.concat(tooltipParts, " "))
    appendValueStrings(metadataParts, metadataSeen, data and data.helpTip, nil, 0)
    appendValueStrings(metadataParts, metadataSeen, data and data.searchtags, nil, 0)
    appendValueStrings(metadataParts, metadataSeen, data and data.searchTags, nil, 0)
    appendValueStrings(metadataParts, metadataSeen, initializer.searchtags, nil, 0)
    appendValueStrings(metadataParts, metadataSeen, initializer.searchTags, nil, 0)

    local setting = safeMethodValue(initializer, "GetSetting")
    if type(setting) ~= "table" and type(setting) ~= "userdata" and type(data) == "table" then
        if type(data.setting) == "table" or type(data.setting) == "userdata" then
            setting = data.setting
        elseif type(data.setting) == "string" then
            addUniqueText(metadataParts, metadataSeen, data.setting)
        end
    end

    if type(setting) == "table" or type(setting) == "userdata" then
        addUniqueText(metadataParts, metadataSeen, safeMethodValue(setting, "GetVariable"))
        addUniqueText(metadataParts, metadataSeen, safeMethodValue(setting, "GetVariableKey"))
        addUniqueText(metadataParts, metadataSeen, safeMethodValue(setting, "GetName"))
        addUniqueText(metadataParts, metadataSeen, safeMethodValue(setting, "GetKey"))
        addUniqueText(metadataParts, metadataSeen, safeMethodValue(setting, "GetCVar"))
    end

    local templateName = getTemplateName(initializer, data)
    local isDecorativeTemplate = templateName and (
        string.find(templateName, "SectionHeader", 1, true)
        or string.find(templateName, "SectionHint", 1, true)
        or string.find(templateName, "ExpandableSection", 1, true)
    )

    if isDecorativeTemplate and #metadataParts == 0 then
        return nil
    end

    local lowerTitle = string.lower(title)
    if (categoryName and lowerTitle == string.lower(categoryName)) or (subcategoryName and lowerTitle == string.lower(subcategoryName)) then
        if #metadataParts == 0 then
            return nil
        end
    end

    local searchParts = {}
    local searchSeen = {}
    addUniqueText(searchParts, searchSeen, categoryName)
    addUniqueText(searchParts, searchSeen, subcategoryName)
    addUniqueText(searchParts, searchSeen, table.concat(metadataParts, " "))

    local dedupeKey = table.concat({
        categoryName or "",
        subcategoryName or "",
        title,
        templateName or "",
        table.concat(searchParts, " "),
    }, "\001")

    return {
        dedupeKey = dedupeKey,
        kind = "settings",
        title = title,
        subtitle = buildSubtitle(categoryName, subcategoryName),
        icon = SETTINGS_ICON_TEXTURE,
        categoryName = categoryName,
        subcategoryName = subcategoryName,
        searchTags = table.concat(searchParts, " "),
        priority = subcategoryName and 28 or 30,
    }
end

local function appendCategoryInitializerSpecs(specs, seenKeys, category, categoryName, subcategoryName)
    if not category or not categoryName then
        return
    end

    local layout = getCategoryLayout(category)
    if type(layout) ~= "table" then
        return
    end

    local initializers = {}
    collectInitializers(layout, initializers, {}, 0)

    for index = 1, #initializers do
        local spec = extractInitializerSpec(initializers[index], categoryName, subcategoryName)
        local dedupeKey = spec and spec.dedupeKey or nil
        if dedupeKey and not seenKeys[dedupeKey] then
            seenKeys[dedupeKey] = true
            spec.dedupeKey = nil
            specs[#specs + 1] = spec
        end
    end
end

function BlizzardSettingsIndex:OnInitialize()
    self.cacheDirty = true
    self.cachedEntrySpecs = {}
end

function BlizzardSettingsIndex:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "OnSourceChanged")
end

function BlizzardSettingsIndex:OnSourceChanged()
    self.cacheDirty = true
end

function BlizzardSettingsIndex:RebuildCache()
    local specs = {}
    local seenKeys = {}
    local categoryList = getSettingsCategoryList()
    local groups = categoryList and categoryList.groups or nil

    if type(groups) == "table" then
        for groupIndex = 1, #groups do
            local categories = groups[groupIndex] and groups[groupIndex].categories or nil
            if type(categories) == "table" then
                for categoryIndex = 1, #categories do
                    local category = categories[categoryIndex]
                    local categoryName = category and category.GetName and category:GetName() or nil
                    categoryName = collapseWhitespace(categoryName)
                    if categoryName then
                        appendCategoryInitializerSpecs(specs, seenKeys, category, categoryName, nil)

                        local subcategories = category.GetSubcategories and category:GetSubcategories() or nil
                        if type(subcategories) == "table" then
                            for subIndex = 1, #subcategories do
                                local subcategory = subcategories[subIndex]
                                local subcategoryName = subcategory and subcategory.GetName and subcategory:GetName() or nil
                                subcategoryName = collapseWhitespace(subcategoryName)
                                if subcategoryName then
                                    appendCategoryInitializerSpecs(specs, seenKeys, subcategory, categoryName, subcategoryName)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    self.cachedEntrySpecs = specs
    self.cacheDirty = false
end

function BlizzardSettingsIndex:GetEntrySpecs()
    if self.cacheDirty then
        self:RebuildCache()
    end

    local specs = {}
    for index = 1, #self.cachedEntrySpecs do
        specs[index] = shallowCopy(self.cachedEntrySpecs[index])
    end

    return specs
end
