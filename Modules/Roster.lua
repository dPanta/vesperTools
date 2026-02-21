local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Roster = VesperGuild:NewModule("Roster", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function Roster:OnInitialize()
    -- Called when the module is initialized
end

function Roster:OnEnable()
    self:RegisterMessage("VESPERGUILD_ILVL_UPDATE", "OnSyncUpdate")
    self:RegisterMessage("VESPERGUILD_BESTKEYS_UPDATE", "OnSyncUpdate")
end

function Roster:OnSyncUpdate()
    if self.frame and self.frame:IsShown() then
        self:UpdateRosterList()
    end
end

function Roster:OnDisable()
    -- Called when the module is disabled
end

-- --- GUI Creation ---

function Roster:ShowRoster()
    if self.frame then
        self.frame:Show()
        self.dungeonPanel:Show()
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

    self.frame:SetFrameStrata("MEDIUM")
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
     self.frame:SetBackdropColor(0.07, 0.07, 0.07, 0.95) -- #121212
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
    title:SetText(guildName or "Guild Roster")
    
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
    local closeBtn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -5, 0)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function()
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
        if self.dungeonPanel then
            self.dungeonPanel:Hide()
            self.dungeonPanel = nil
        end
        -- Also hide the Portals frame
        local Portals = VesperGuild:GetModule("Portals", true)
        if Portals and Portals.VesperPortalsUI then
            Portals.VesperPortalsUI:Hide()
        end
    end)
    
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
    local syncBtn = CreateFrame("Button", nil, titlebar, "UIPanelButtonTemplate")
    syncBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    syncBtn:SetSize(80, 22)
    syncBtn:SetText("Sync")
    syncBtn:SetScript("OnClick", function()
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
    
    -- Content Container
    local contentFrame = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("BOTTOMRIGHT", -5, 20)
    
    self.scroll = AceGUI:Create("ScrollFrame")
    self.scroll:SetLayout("Flow")
    self.scroll.frame:SetParent(contentFrame)
    self.scroll.frame:SetAllPoints()
    self.scroll.frame:Show()



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

-- Sort arrow indicators (WoW built-in arrow textures)
local ARROW_UP = " |TInterface\\Buttons\\Arrow-Up-Up:12:12|t"
local ARROW_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12|t"

-- Column definitions: key, label, width, sort type
local COLUMNS = {
    { key = "name",    label = "Name",   width = 0.15, sort = "string" },
    { key = "faction", label = "F",      width = 0.05, sort = "string" },
    { key = "zone",    label = "Zone",   width = 0.20, sort = "string" },
    { key = "status",  label = "Status", width = 0.10, sort = "string" },
    { key = "ilvl",    label = "iLvl",   width = 0.10, sort = "number" },
    { key = "rating",  label = "R",      width = 0.1,  sort = "number" },
    { key = "keyLevel", label = "KEY",   width = 0.2,  sort = "number" },
}

function Roster:UpdateRosterList()
    if not self.frame then return end

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
        CenterLabelV(header)

        header:SetCallback("OnClick", function(_, _, button)
            if self.sortColumn == col.key then
                self.sortAscending = not self.sortAscending
            else
                self.sortColumn = col.key
                self.sortAscending = (col.sort == "string")
            end
            self:UpdateRosterList()
        end)

        header:SetCallback("OnEnter", function(widget)
            GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Click to sort by " .. col.label)
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
        local name, _, _, level, _, zone, _, _, isOnline, status, classFileName = GetGuildRosterInfo(i)

        if isOnline then
            local displayName = name:match("([^-]+)") or name
            local fullName = name
            if not string.find(name, "-") then
                fullName = name .. "-" .. playerRealm
            end

            -- Faction
            local factionText = "?"
            if playerFaction == "Alliance" then factionText = "A"
            elseif playerFaction == "Horde" then factionText = "H" end

            -- Status
            local statusRaw = "Online"
            if status == 1 then statusRaw = "AFK"
            elseif status == 2 then statusRaw = "DND" end

            -- iLvl
            local ilvlNum = 0
            if DataHandle then
                local ilvlData = DataHandle:GetIlvlForPlayer(name)
                if ilvlData then ilvlNum = ilvlData.ilvl end
            end

            -- Rating
            local ratingNum = 0
            if VesperGuild.db.global.keystones and VesperGuild.db.global.keystones[name] and VesperGuild.db.global.keystones[name].rating then
                ratingNum = VesperGuild.db.global.keystones[name].rating
            end

            -- Keystone
            local keystoneText = "-"
            local keystoneMapID = nil
            local keyLevel = 0
            if KeystoneSync then
                keystoneText = KeystoneSync:GetKeystoneForPlayer(fullName) or "-"
                if VesperGuild.db.global.keystones and VesperGuild.db.global.keystones[fullName] then
                    keystoneMapID = VesperGuild.db.global.keystones[fullName].mapID
                    keyLevel = VesperGuild.db.global.keystones[fullName].level or 0
                end
            end

            table.insert(members, {
                name = displayName,
                fullName = name,
                classFileName = classFileName,
                faction = factionText,
                zone = zone or "Unknown",
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
        nameLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
        CenterLabelV(nameLabel)
        row:AddChild(nameLabel)

        -- Faction
        local factionColor = "|cffFFFFFF"
        if m.faction == "A" then factionColor = "|cff0070DD"
        elseif m.faction == "H" then factionColor = "|cffA335EE" end

        local factionLabel = AceGUI:Create("Label")
        factionLabel:SetText(factionColor .. m.faction .. "|r")
        factionLabel:SetRelativeWidth(0.05)
        factionLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
        CenterLabelV(factionLabel)
        row:AddChild(factionLabel)

        -- Zone
        local zoneLabel = AceGUI:Create("Label")
        zoneLabel:SetText(m.zone)
        zoneLabel:SetRelativeWidth(0.20)
        zoneLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
        CenterLabelV(zoneLabel)
        row:AddChild(zoneLabel)

        -- Status
        local statusDisplay = m.status
        if m.status == "AFK" then statusDisplay = "|cffFFFF00AFK|r"
        elseif m.status == "DND" then statusDisplay = "|cffFF0000DND|r" end

        local statusLabel = AceGUI:Create("Label")
        statusLabel:SetText(statusDisplay)
        statusLabel:SetRelativeWidth(0.10)
        statusLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
        CenterLabelV(statusLabel)
        row:AddChild(statusLabel)

        -- iLvl
        local ilvlLabel = AceGUI:Create("Label")
        ilvlLabel:SetText(m.ilvl > 0 and tostring(m.ilvl) or "-")
        ilvlLabel:SetRelativeWidth(0.10)
        ilvlLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
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
        ratingLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
        CenterLabelV(ratingLabel)
        row:AddChild(ratingLabel)

        -- Keystone
        local keyLabel = AceGUI:Create("Label")
        keyLabel:SetText(m.keystoneText)
        keyLabel:SetRelativeWidth(0.2)
        keyLabel:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 12, "")
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
            baseColorR, baseColorG, baseColorB = 0.12, 0.24, 0.24
        elseif (i % 2 == 0) then
            baseColorR, baseColorG, baseColorB = 0.17, 0.17, 0.17
        else
            baseColorR, baseColorG, baseColorB = 0.12, 0.12, 0.12
        end

        rowFrame.vesperBg:SetColorTexture(baseColorR, baseColorG, baseColorB, 1)

        -- Row overlay button: left-click = portal cast, right-click = context menu
        local rowBtn = CreateFrame("Button", nil, contentFrame, "InsecureActionButtonTemplate")
        rowBtn:SetPoint("TOPLEFT", row.frame, "TOPLEFT")
        rowBtn:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT")
        rowBtn:SetFrameLevel(row.frame:GetFrameLevel() + 20)
        rowBtn:RegisterForClicks("AnyUp", "AnyDown")

        -- Set up left-click portal cast if player has the spell
        local portalSpellName = nil
        if m.keystoneMapID and DataHandle then
            local dungInfo = DataHandle:GetDungeonByMapID(m.keystoneMapID)
            if dungInfo then
                local spellInfo = C_Spell.GetSpellInfo(dungInfo.spellID)
                local spellName = spellInfo and spellInfo.name
                local hasPortal = C_SpellBook.IsSpellInSpellBook(dungInfo.spellID)
                if spellName and hasPortal then
                    portalSpellName = spellName
                    rowBtn:SetAttribute("type1", "spell")
                    rowBtn:SetAttribute("spell1", spellName)
                end
            end
        end

        -- Right-click context menu (HookScript so attribute-based spell cast still fires)
        local memberFullName = m.fullName
        local memberDisplayName = m.name
        rowBtn:HookScript("OnClick", function(self, button, down)
            if button == "RightButton" and not down and MenuUtil then
                MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                    rootDescription:CreateTitle(memberDisplayName)
                    rootDescription:CreateButton("Whisper", function()
                        ChatFrame_OpenChat("/w " .. memberFullName .. " ")
                    end)
                    rootDescription:CreateButton("Invite", function()
                        C_PartyInfo.InviteUnit(memberFullName)
                    end)
                    rootDescription:CreateButton("Cancel", function() end)
                end)
            end
        end)

        -- Tooltip with best keys for this dungeon
        local tooltipMapID = m.keystoneMapID
        rowBtn:SetScript("OnEnter", function(self)
            -- Highlight row background
            if rowFrame.vesperBg then
                rowFrame.vesperBg:SetColorTexture(0.24, 0.24, 0.24, 1)
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            if portalSpellName then
                GameTooltip:SetText("Left-click: " .. portalSpellName .. "\nRight-click: Menu")
            else
                GameTooltip:SetText("Right-click: Menu")
            end

            if tooltipMapID then
                local dungName = C_ChallengeMode.GetMapUIInfo(tooltipMapID)
                if dungName then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(dungName .. " - Guild Best", 1, 0.82, 0, true)

                    local entries = {}
                    local seen = {}

                    -- Primary: addon sync data (per-member best keys)
                    if DataHandle then
                        local bestKeysDB = DataHandle:GetBestKeysDB()
                        if bestKeysDB then
                            for playerName, data in pairs(bestKeysDB) do
                                local info = data[tooltipMapID]
                                if info and info.level and info.level > 0 then
                                    local shortName = playerName:match("([^-]+)") or playerName
                                    seen[shortName] = true
                                    table.insert(entries, { name = shortName, level = info.level, inTime = info.inTime })
                                end
                            end
                        end
                    end

                    -- Supplement: WoW guild leaderboard (top guild run per dungeon)
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
                        GameTooltip:AddLine("No data", 0.5, 0.5, 0.5)
                    end
                end
            end

            GameTooltip:Show()
        end)
        rowBtn:SetScript("OnLeave", function(self)
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
