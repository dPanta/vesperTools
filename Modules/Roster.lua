local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Roster = VesperGuild:NewModule("Roster", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local L = VesperGuild.L
local HEADER_ACTION_BUTTON_HEIGHT = 22
local HEADER_ACTION_BUTTON_GAP = 6

local function createHeaderActionButton(parent, anchor, width, label, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetPoint("RIGHT", anchor, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
    button:SetSize(width, HEADER_ACTION_BUTTON_HEIGHT)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    button:SetBackdropBorderColor(1, 1, 1, 0.12)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    button:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    button:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    button:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    if type(onClick) == "function" then
        button:SetScript("OnClick", onClick)
    end

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(label)
    VesperGuild:ApplyConfiguredFont(text, 11, "")
    button.text = text

    return button
end

function Roster:OnInitialize()
    -- Called when the module is initialized
end

function Roster:OnEnable()
    self:RegisterMessage("VESPERGUILD_ILVL_UPDATE", "OnSyncUpdate")
    self:RegisterMessage("VESPERGUILD_BESTKEYS_UPDATE", "OnSyncUpdate")
    self:RegisterMessage("VESPERGUILD_CONFIG_CHANGED", "OnConfigChanged")
end

function Roster:OnSyncUpdate()
    if self.frame and self.frame:IsShown() then
        self:UpdateRosterList()
    end
end

-- Handle central style/config updates (font + opacity) and repaint visible UI.
function Roster:OnConfigChanged()
    if not self.frame then
        return
    end

    local baseFontSize = VesperGuild:GetConfiguredFontSize("roster", 12, 8, 24)
    self.frame:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("roster"))
    if self.titleText then
        VesperGuild:ApplyConfiguredFont(self.titleText, baseFontSize + 4, "")
    end
    if self.frame:IsShown() then
        self:UpdateRosterList()
    end
end

function Roster:OnDisable()
    -- Called when the module is disabled
end

-- Lazily create one dropdown frame used by legacy fallback context menus.
function Roster:GetContextMenuDropdown()
    local dropdownLevel = 80
    if self.frame and self.frame.GetFrameLevel then
        dropdownLevel = math.max(dropdownLevel, (self.frame:GetFrameLevel() or 0) + 40)
    end

    if self.contextMenuDropdown and self.contextMenuDropdown.GetName then
        self.contextMenuDropdown:SetFrameStrata("TOOLTIP")
        self.contextMenuDropdown:SetFrameLevel(dropdownLevel)
        self.contextMenuDropdown:SetToplevel(true)
        return self.contextMenuDropdown
    end

    self.contextMenuDropdown = CreateFrame("Frame", "VesperGuildRosterContextMenu", UIParent, "UIDropDownMenuTemplate")
    self.contextMenuDropdown:SetFrameStrata("TOOLTIP")
    self.contextMenuDropdown:SetFrameLevel(dropdownLevel)
    self.contextMenuDropdown:SetToplevel(true)
    return self.contextMenuDropdown
end

-- Create a neutral top-level anchor so Blizzard context menus do not inherit row layering.
function Roster:GetContextMenuAnchor(anchorButton)
    local anchorLevel = 80
    if self.frame and self.frame.GetFrameLevel then
        anchorLevel = math.max(anchorLevel, (self.frame:GetFrameLevel() or 0) + 40)
    end

    if not (self.contextMenuAnchor and self.contextMenuAnchor.GetName) then
        self.contextMenuAnchor = CreateFrame("Frame", "VesperGuildRosterContextMenuAnchor", UIParent)
        self.contextMenuAnchor:SetSize(2, 2)
        self.contextMenuAnchor:SetClampedToScreen(true)
    end

    local anchor = self.contextMenuAnchor
    anchor:SetFrameStrata("TOOLTIP")
    anchor:SetFrameLevel(anchorLevel)
    anchor:SetToplevel(true)
    anchor:Show()
    anchor:ClearAllPoints()

    local uiScale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    if uiScale > 0 and cursorX and cursorY and cursorX > 0 and cursorY > 0 then
        anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX / uiScale, cursorY / uiScale)
        return anchor
    end

    if anchorButton and anchorButton.GetCenter then
        local centerX, centerY = anchorButton:GetCenter()
        if centerX and centerY then
            anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
            return anchor
        end
    end

    anchor:SetPoint("CENTER", UIParent, "CENTER")
    return anchor
end

-- Open manual roster right-click menu with stable cross-client fallbacks.
function Roster:OpenRosterContextMenu(anchorButton, fullName)
    local resolvedFullName = strtrim(tostring(fullName or ""))
    if resolvedFullName == "" then
        return false
    end

    local function invitePlayer()
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            C_PartyInfo.InviteUnit(resolvedFullName)
        elseif InviteUnit then
            InviteUnit(resolvedFullName)
        end
    end

    local function whisperPlayer()
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. resolvedFullName .. " ")
        elseif ChatFrame_SendTell then
            ChatFrame_SendTell(resolvedFullName)
        end
    end

    if anchorButton and MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local menuAnchor = self:GetContextMenuAnchor(anchorButton)
        GameTooltip:Hide()
        MenuUtil.CreateContextMenu(menuAnchor, function(_, rootDescription)
            rootDescription:CreateButton(L["CONTEXT_MENU_INVITE"], invitePlayer)
            rootDescription:CreateButton(L["CONTEXT_MENU_WHISPER"], whisperPlayer)
            rootDescription:CreateButton(L["CONTEXT_MENU_CLOSE"], function() end)
        end)
        return true
    end

    if EasyMenu then
        local menu = {
            { text = L["CONTEXT_MENU_INVITE"], func = invitePlayer, notCheckable = true },
            { text = L["CONTEXT_MENU_WHISPER"], func = whisperPlayer, notCheckable = true },
            { text = L["CONTEXT_MENU_CLOSE"], func = function() end, notCheckable = true },
        }
        local dropdown = self:GetContextMenuDropdown()
        GameTooltip:Hide()
        dropdown:Raise()
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
        return true
    end

    return false
end

-- --- GUI Creation ---

function Roster:ShowRoster()
    if self.frame then
        self.frame:Show()
        self.frame:Raise()
        self:UpdateRosterList()
        return
    end

    -- Create Custom Frame
    self.frame = CreateFrame("Frame", "VesperGuildRosterFrame", UIParent, "BackdropTemplate" )
    self.frame:SetSize(600, 250)

    -- Restore saved position or use default
    if VesperGuild.db.profile.rosterPosition then
        local pos = VesperGuild.db.profile.rosterPosition
        self.frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        self.frame:SetPoint("RIGHT", UIParent, "CENTER", -250, 0)
    end

    VesperGuild:ApplyAddonWindowLayer(self.frame)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetResizable(true)
    self.frame:SetResizeBounds(600, 250)
    
--   Background
     self.frame:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8x8",
         edgeFile = "Interface\\Buttons\\WHITE8x8",
         edgeSize = 1,
     })
     self.frame:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("roster")) -- #121212
     local _, englishClass = UnitClass("player")
     local classColor = C_ClassColor.GetClassColor(englishClass)
     self.frame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    
--   Titlebar
    local titlebar = CreateFrame("Frame", nil, self.frame)
    titlebar:SetHeight(32)
    titlebar:SetPoint("TOPLEFT", 1, -1)
    titlebar:SetPoint("TOPRIGHT", -1, -1)
    
    local titlebg = titlebar:CreateTexture(nil, "BACKGROUND")
    titlebg:SetAllPoints()
    titlebg:SetColorTexture(0.1, 0.1, 0.1, 1) -- #1A1A1A
    
    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 10, 0)
    local guildName = GetGuildInfo("player")
    title:SetText(guildName or L["ROSTER_TITLE_FALLBACK"])
    VesperGuild:ApplyConfiguredFont(title, VesperGuild:GetConfiguredFontSize("roster", 12, 8, 24) + 4, "")
    self.titleText = title
    
    -- Make draggable via titlebar
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")
    titlebar:SetScript("OnDragStart", function() self.frame:StartMoving() end)
    titlebar:SetScript("OnDragStop", function()
        self.frame:StopMovingOrSizing()
        -- Save position to database
        local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
        VesperGuild.db.profile.rosterPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end)
    
    -- Close Button
    local closeBtn = VesperGuild:CreateModernCloseButton(titlebar, function()
        -- Clean up portal buttons before closing
        if self.portalButtons then
            for _, btn in ipairs(self.portalButtons) do
                btn:Hide()
                btn:SetParent(nil)
            end
            self.portalButtons = nil
        end

        self.frame:Hide()
        self.frame = nil
        self.scroll = nil
        self.contentFrame = nil
        self.titleText = nil
        if self.dungeonPanel then
            self.dungeonPanel:Hide()
            self.dungeonPanel = nil
        end
        -- Also hide the Portals frame
        local Portals = VesperGuild:GetModule("Portals", true)
        if Portals and Portals.VesperPortalsUI then
            Portals.VesperPortalsUI:Hide()
        end
    end, {
        size = 20,
        iconScale = 0.52,
        backgroundAlpha = 0.04,
        borderAlpha = 0.08,
        hoverAlpha = 0.12,
        pressedAlpha = 0.18,
    })
    closeBtn:SetPoint("RIGHT", -6, 0)
    
    -- Resize Grip
    local resizeBtn = CreateFrame("Button", nil, self.frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT")
    resizeBtn:EnableMouse(true)

    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    resizeBtn:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self.frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
    end)
    
    -- Sync Button
    local syncBtn = createHeaderActionButton(titlebar, closeBtn, 72, L["ROSTER_BUTTON_SYNC"], function()
        local KeystoneSync = VesperGuild:GetModule("KeystoneSync", true)
        if KeystoneSync then
            KeystoneSync:RequestGuildKeystones()
        end
        local Auto = VesperGuild:GetModule("Automation", true)
        if Auto then
            Auto:ManualSync()
        end
        self:UpdateRosterList()
    end)

    -- Configuration button (left of Sync) opens the custom config panel.
    local confBtn = createHeaderActionButton(titlebar, syncBtn, 56, L["ROSTER_BUTTON_CONFIG"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            VesperGuild:OpenConfig()
        end
    end)

    local bagsBtn = createHeaderActionButton(titlebar, confBtn, 56, L["ROSTER_BUTTON_BAGS"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BagsWindow = VesperGuild:GetModule("BagsWindow", true)
            if BagsWindow and type(BagsWindow.Toggle) == "function" then
                BagsWindow:Toggle()
            end
        end
    end)

    local bankBtn = createHeaderActionButton(titlebar, bagsBtn, 56, L["ROSTER_BUTTON_BANK"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BankWindow = VesperGuild:GetModule("BankWindow", true)
            if BankWindow and type(BankWindow.Toggle) == "function" then
                BankWindow:Toggle()
            end
        end
    end)
    
    -- Content Container
    local contentFrame = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("BOTTOMRIGHT", -5, 20)
    self.contentFrame = contentFrame
    
    self.scroll = AceGUI:Create("ScrollFrame")
    self.scroll:SetLayout("Flow")
    self.scroll.frame:SetParent(contentFrame)
    self.scroll.frame:SetAllPoints()
    self.scroll.frame:Show()

    self.frame:Raise()

    self:UpdateRosterList()
end

function Roster:Toggle()
    if self.frame and self.frame:IsShown() then
        -- Clean up portal buttons before hiding
        if self.portalButtons then
            for _, btn in ipairs(self.portalButtons) do
                btn:Hide()
                btn:SetParent(nil)
            end
            self.portalButtons = nil
        end

        self.frame:Hide()
        self.frame = nil
        self.scroll = nil
        self.contentFrame = nil
        self.titleText = nil
    else
        self:ShowRoster()
    end
end

-- Helper: vertically center text inside AceGUI Label/InteractiveLabel
local function CenterLabelV(widget)
    if widget.label then
        widget.label:SetJustifyV("MIDDLE")
        widget.label:ClearAllPoints()
        widget.label:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 0, 0)
        widget.label:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", 0, 0)
    end
end

-- Apply the currently selected addon font to an AceGUI widget.
-- Falls back to applying the font directly on the underlying label.
local function ApplyWidgetFont(widget, size, flags)
    if not widget then
        return
    end

    local path = VesperGuild:GetConfiguredFontPath()
    local resolvedSize = tonumber(size) or 12
    local resolvedFlags = type(flags) == "string" and flags or ""

    if type(widget.SetFont) == "function" then
        local ok = pcall(widget.SetFont, widget, path, resolvedSize, resolvedFlags)
        if ok then
            return
        end
    end

    if widget.label then
        VesperGuild:ApplyConfiguredFont(widget.label, resolvedSize, resolvedFlags)
    end
end

-- Sort arrow indicators (WoW built-in arrow textures)
local ARROW_UP = " |TInterface\\Buttons\\Arrow-Up-Up:12:12|t"
local ARROW_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12|t"

-- Column definitions: key, label, width, sort type
local COLUMNS = {
    { key = "name",    label = L["ROSTER_COLUMN_NAME"], width = 0.15, sort = "string" },
    { key = "faction", label = L["ROSTER_COLUMN_FACTION"], width = 0.05, sort = "string" },
    { key = "zone",    label = L["ROSTER_COLUMN_ZONE"], width = 0.20, sort = "string" },
    { key = "status",  label = L["ROSTER_COLUMN_STATUS"], width = 0.10, sort = "string" },
    { key = "ilvl",    label = L["ROSTER_COLUMN_ILVL"], width = 0.10, sort = "number" },
    { key = "rating",  label = L["ROSTER_COLUMN_RATING"], width = 0.1, sort = "number" },
    { key = "keyLevel", label = L["ROSTER_COLUMN_KEY"], width = 0.2, sort = "number" },
}

function Roster:UpdateRosterList()
    if not self.frame then return end

    -- Base row/header typography controlled from config per-frame tab.
    local rosterFontSize = VesperGuild:GetConfiguredFontSize("roster", 12, 8, 24)

    -- Clean up any existing portal buttons
    if self.portalButtons then
        for _, btn in ipairs(self.portalButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
    end
    self.portalButtons = {}

    self.scroll:ReleaseChildren() -- Clear existing list

    -- Header row with clickable sort labels
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetLayout("Flow")
    headerGroup:SetFullWidth(true)

    for _, col in ipairs(COLUMNS) do
        local arrow = ""
        if self.sortColumn == col.key then
            arrow = self.sortAscending and ARROW_UP or ARROW_DOWN
        end

        local header = AceGUI:Create("InteractiveLabel")
        header:SetText(col.label .. arrow)
        header:SetRelativeWidth(col.width)
        ApplyWidgetFont(header, rosterFontSize, "")
        CenterLabelV(header)

        header:SetCallback("OnClick", function()
            if self.sortColumn == col.key then
                self.sortAscending = not self.sortAscending
            else
                self.sortColumn = col.key
                -- Strings feel more natural ascending by default; numbers default descending.
                self.sortAscending = (col.sort == "string")
            end
            self:UpdateRosterList()
        end)

        header:SetCallback("OnEnter", function(widget)
            GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(string.format(L["ROSTER_SORT_BY_FMT"], col.label))
            GameTooltip:Show()
        end)
        header:SetCallback("OnLeave", function() GameTooltip:Hide() end)

        headerGroup:AddChild(header)
    end

    -- Header background (no hover highlight)
    local headerFrame = headerGroup.frame
    if not headerFrame.vesperBg then
        headerFrame.vesperBg = headerFrame:CreateTexture(nil, "BACKGROUND")
        headerFrame.vesperBg:SetAllPoints()
    end
    headerFrame.vesperBg:SetColorTexture(0.1, 0.1, 0.1, 1)
    headerFrame:SetScript("OnEnter", nil)
    headerFrame:SetScript("OnLeave", nil)

    self.scroll:AddChild(headerGroup)

    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    self.scroll:AddChild(line)

    -- Cache lookups before the loop
    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    local KeystoneSync = VesperGuild:GetModule("KeystoneSync", true)
    local playerRealm = GetRealmName()
    local playerRealmNormalized = GetNormalizedRealmName()
    local playerFaction = UnitFactionGroup("player")

    -- Build group member lookup table for O(1) checks
    local groupMembers = {}
    if IsInGroup() then
        for j = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and ("raid" .. j) or (j == 1 and "player" or ("party" .. (j - 1)))
            local gName = UnitName(unit)
            if gName then groupMembers[gName] = true end
        end
    end

    -- Collect all online member data for sorting
    local members = {}
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, _, _, zone, _, _, isOnline, status, classFileName = GetGuildRosterInfo(i)

        if isOnline then
            -- Normalize "Name-Realm" variants so lookups match across different data producers.
            local displayName = name:match("([^-]+)") or name
            local fullName = name
            if not string.find(name, "-") then
                fullName = name .. "-" .. playerRealmNormalized
            end

            -- Faction
            local factionText = "?"
            if playerFaction == "Alliance" then factionText = L["FACTION_ALLIANCE_SHORT"]
            elseif playerFaction == "Horde" then factionText = L["FACTION_HORDE_SHORT"] end

            -- Status
            local statusRaw = L["STATUS_ONLINE"]
            if status == 1 then statusRaw = L["STATUS_AFK"]
            elseif status == 2 then statusRaw = L["STATUS_DND"] end

            -- iLvl
            local ilvlNum = 0
            if DataHandle then
                -- Try multiple key formats because senders may include/exclude realm suffix.
                local ilvlData = DataHandle:GetIlvlForPlayer(fullName)
                    or DataHandle:GetIlvlForPlayer(name)
                    or DataHandle:GetIlvlForPlayer(displayName)
                    or DataHandle:GetIlvlForPlayer(displayName .. "-" .. playerRealm)
                if ilvlData then ilvlNum = ilvlData.ilvl end
            end

            -- Rating
            local ratingNum = 0
            local keyData = VesperGuild.db.global.keystones
                and (
                    -- Same multi-key fallback strategy as ilvl for cross-realm consistency.
                    VesperGuild.db.global.keystones[fullName]
                    or VesperGuild.db.global.keystones[name]
                    or VesperGuild.db.global.keystones[displayName]
                    or VesperGuild.db.global.keystones[displayName .. "-" .. playerRealm]
                )
            if keyData and keyData.rating then
                ratingNum = keyData.rating
            end

            -- Keystone
            local keystoneText = "-"
            local keystoneMapID = nil
            local keyLevel = 0
            if KeystoneSync then
                keystoneText = KeystoneSync:GetKeystoneForPlayer(fullName)
                    or KeystoneSync:GetKeystoneForPlayer(name)
                    or "-"
                if keyData then
                    keystoneMapID = keyData.mapID
                    keyLevel = keyData.level or 0
                end
            end

            table.insert(members, {
                name = displayName,
                fullName = fullName,
                classFileName = classFileName,
                faction = factionText,
                zone = zone or UNKNOWN,
                status = statusRaw,
                ilvl = ilvlNum,
                rating = ratingNum,
                keystoneText = keystoneText,
                keystoneMapID = keystoneMapID,
                keyLevel = keyLevel,
                isInGroup = groupMembers[displayName] or false,
            })
        end
    end

    -- Sort members
    if self.sortColumn then
        table.sort(members, function(a, b)
            local va, vb = a[self.sortColumn], b[self.sortColumn]
            -- Stable-ish tie-break by name to avoid row jitter between refreshes.
            if va == vb then return a.name < b.name end
            if self.sortAscending then
                return va < vb
            else
                return va > vb
            end
        end)
    end

    -- Render sorted rows
    for i, m in ipairs(members) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)

        -- Name (class colored)
        local classColor = C_ClassColor.GetClassColor(m.classFileName)
        local nameText = m.name
        if classColor then
            nameText = string.format("|c%s%s|r", classColor:GenerateHexColor(), m.name)
        end

        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText(nameText)
        nameLabel:SetRelativeWidth(0.15)
        ApplyWidgetFont(nameLabel, rosterFontSize, "")
        CenterLabelV(nameLabel)
        row:AddChild(nameLabel)

        -- Faction
        local factionColor = "|cffFFFFFF"
        if m.faction == L["FACTION_ALLIANCE_SHORT"] then factionColor = "|cff0070DD"
        elseif m.faction == L["FACTION_HORDE_SHORT"] then factionColor = "|cffA335EE" end

        local factionLabel = AceGUI:Create("Label")
        factionLabel:SetText(factionColor .. m.faction .. "|r")
        factionLabel:SetRelativeWidth(0.05)
        ApplyWidgetFont(factionLabel, rosterFontSize, "")
        CenterLabelV(factionLabel)
        row:AddChild(factionLabel)

        -- Zone
        local zoneLabel = AceGUI:Create("Label")
        zoneLabel:SetText(m.zone)
        zoneLabel:SetRelativeWidth(0.20)
        ApplyWidgetFont(zoneLabel, rosterFontSize, "")
        CenterLabelV(zoneLabel)
        row:AddChild(zoneLabel)

        -- Status
        local statusDisplay = m.status
        if m.status == L["STATUS_AFK"] then
            statusDisplay = "|cffFFFF00" .. L["STATUS_AFK"] .. "|r"
        elseif m.status == L["STATUS_DND"] then
            statusDisplay = "|cffFF0000" .. L["STATUS_DND"] .. "|r"
        end

        local statusLabel = AceGUI:Create("Label")
        statusLabel:SetText(statusDisplay)
        statusLabel:SetRelativeWidth(0.10)
        ApplyWidgetFont(statusLabel, rosterFontSize, "")
        CenterLabelV(statusLabel)
        row:AddChild(statusLabel)

        -- iLvl
        local ilvlLabel = AceGUI:Create("Label")
        ilvlLabel:SetText(m.ilvl > 0 and tostring(m.ilvl) or "-")
        ilvlLabel:SetRelativeWidth(0.10)
        ApplyWidgetFont(ilvlLabel, rosterFontSize, "")
        CenterLabelV(ilvlLabel)
        row:AddChild(ilvlLabel)

        -- Rating
        local ratingText = "-"
        if m.rating > 0 then
            local colorCode = DataHandle and DataHandle:GetRatingColor(m.rating) or "|cff9d9d9d"
            ratingText = string.format("%s%d|r", colorCode, m.rating)
        end
        local ratingLabel = AceGUI:Create("Label")
        ratingLabel:SetText(ratingText)
        ratingLabel:SetRelativeWidth(0.1)
        ApplyWidgetFont(ratingLabel, rosterFontSize, "")
        CenterLabelV(ratingLabel)
        row:AddChild(ratingLabel)

        -- Keystone
        local keyLabel = AceGUI:Create("Label")
        keyLabel:SetText(m.keystoneText)
        keyLabel:SetRelativeWidth(0.2)
        ApplyWidgetFont(keyLabel, rosterFontSize, "")
        CenterLabelV(keyLabel)
        row:AddChild(keyLabel)

        -- Row background (must be before rowBtn so closures can capture these locals)
        local rowFrame = row.frame
        if not rowFrame.vesperBg then
            rowFrame.vesperBg = rowFrame:CreateTexture(nil, "BACKGROUND")
            rowFrame.vesperBg:SetAllPoints()
        end

        local baseColorR, baseColorG, baseColorB
        if m.isInGroup then
            -- Slightly different tint for current party members to improve scanability.
            baseColorR, baseColorG, baseColorB = 0.12, 0.24, 0.24
        elseif (i % 2 == 0) then
            baseColorR, baseColorG, baseColorB = 0.17, 0.17, 0.17
        else
            baseColorR, baseColorG, baseColorB = 0.12, 0.12, 0.12
        end

        rowFrame.vesperBg:SetColorTexture(baseColorR, baseColorG, baseColorB, 1)

        -- Row overlay button: left-click = portal cast, right-click = context menu
        local rowBtn = CreateFrame("Button", nil, row.frame, "InsecureActionButtonTemplate")
        rowBtn:SetPoint("TOPLEFT", row.frame, "TOPLEFT")
        rowBtn:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT")
        rowBtn:SetFrameLevel(row.frame:GetFrameLevel() + 1)
        rowBtn:RegisterForClicks("AnyUp", "AnyDown")

        -- Left-click cast path uses secure button attributes (spell assignment at build time).
        local portalSpellName = nil
        if m.keystoneMapID and DataHandle then
            local dungInfo = DataHandle:GetDungeonByMapID(m.keystoneMapID)
            if dungInfo then
                local spellInfo = C_Spell.GetSpellInfo(dungInfo.spellID)
                local spellName = spellInfo and spellInfo.name
                local hasPortal = C_SpellBook and C_SpellBook.IsSpellInSpellBook
                    and C_SpellBook.IsSpellInSpellBook(dungInfo.spellID)
                if spellName and hasPortal then
                    portalSpellName = spellName
                    rowBtn:SetAttribute("type1", "spell")
                    rowBtn:SetAttribute("spell1", spellName)
                end
            end
        end

        -- Use HookScript so secure left-click casting remains intact while adding right-click behavior.
        local rosterModule = self
        local memberFullName = m.fullName
        rowBtn:HookScript("OnClick", function(selfButton, button, down)
            if button == "RightButton" and not down then
                rosterModule:OpenRosterContextMenu(selfButton, memberFullName)
            end
        end)

        -- Tooltip with best keys for this dungeon
        local tooltipMapID = m.keystoneMapID
        rowBtn:SetScript("OnEnter", function(rowButton)
            -- Highlight row background
            if rowFrame.vesperBg then
                rowFrame.vesperBg:SetColorTexture(0.24, 0.24, 0.24, 1)
            end
            GameTooltip:SetOwner(rowButton, "ANCHOR_TOPLEFT")
            if portalSpellName then
                GameTooltip:SetText(string.format(L["ROSTER_ROW_TOOLTIP_LEFT_RIGHT_FMT"], portalSpellName))
            else
                GameTooltip:SetText(L["ROSTER_ROW_TOOLTIP_RIGHT_ONLY"])
            end

            if tooltipMapID then
                local dungName = C_ChallengeMode.GetMapUIInfo(tooltipMapID)
                if dungName then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format(L["ROSTER_ROW_TOOLTIP_GUILD_BEST_FMT"], dungName), 1, 0.82, 0, true)

                    local entries = {}
                    local seen = {}

                    -- Primary source: addon-synced per-player best keys.
                    if DataHandle then
                        local bestKeysDB = DataHandle:GetBestKeysDB()
                        if bestKeysDB then
                            for playerName, data in pairs(bestKeysDB) do
                                local info = data[tooltipMapID]
                                if info and info.level and info.level > 0 then
                                    local shortName = playerName:match("([^-]+)") or playerName
                                    seen[shortName] = true
                                    table.insert(entries, {
                                        name = shortName,
                                        level = info.level,
                                        inTime = info.inTime
                                    })
                                end
                            end
                        end
                    end

                    -- Secondary source: Blizzard guild leaderboard entries.
                    local guildLeaders = C_ChallengeMode.GetGuildLeaders()
                    if guildLeaders then
                        for _, attempt in ipairs(guildLeaders) do
                            if attempt.mapChallengeModeID == tooltipMapID and attempt.keystoneLevel > 0 then
                                if not seen[attempt.name] then
                                    seen[attempt.name] = true
                                    table.insert(entries, { name = attempt.name, level = attempt.keystoneLevel })
                                end
                            end
                        end
                    end

                    table.sort(entries, function(a, b)
                        -- Highest key first, then lexical name for deterministic ordering.
                        if a.level == b.level then return a.name < b.name end
                        return a.level > b.level
                    end)
                    for _, e in ipairs(entries) do
                        local colorCode = DataHandle and DataHandle:GetKeyColor(e.level) or "|cffffffff"
                        local r, g, b = 0.8, 0.8, 0.8
                        if e.inTime then r, g, b = 0.51, 0.78, 0.52 end
                        GameTooltip:AddDoubleLine(e.name, colorCode .. "+" .. e.level .. "|r", 1, 1, 1, r, g, b)
                    end
                    if #entries == 0 then
                        GameTooltip:AddLine(L["ROSTER_ROW_TOOLTIP_NO_DATA"], 0.5, 0.5, 0.5)
                    end
                end
            end

            GameTooltip:Show()
        end)
        rowBtn:SetScript("OnLeave", function()
            -- Restore row background
            if rowFrame.vesperBg then
                rowFrame.vesperBg:SetColorTexture(baseColorR, baseColorG, baseColorB, 1)
            end
            GameTooltip:Hide()
        end)

        table.insert(self.portalButtons, rowBtn)

        self.scroll:AddChild(row)
    end
end
