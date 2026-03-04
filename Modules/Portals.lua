local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Portals = VesperGuild:NewModule("Portals", "AceConsole-3.0", "AceEvent-3.0")
local FALLBACK_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local TOY_FLYOUT_BUTTON_ICON = "Interface\\Icons\\INV_Misc_Toy_10"
local TOP_UTILITY_BUTTON_SIZE = 52
local TOP_UTILITY_BUTTON_GAP = 10
local TOP_UTILITY_PADDING = 10
local TOP_UTILITY_HEIGHT = 72
local TOY_FLYOUT_BUTTON_GAP = 8
local TOY_FLYOUT_PADDING = 8

-- Curated mage travel catalogs. We still supplement this with spellbook scanning so
-- newly added/seasonal travel spells can appear without hardcoding every edge case.
local MAGE_TELEPORT_SPELL_IDS = {
    3561,   -- Teleport: Stormwind
    3562,   -- Teleport: Ironforge
    3563,   -- Teleport: Undercity
    3565,   -- Teleport: Darnassus
    3566,   -- Teleport: Thunder Bluff
    3567,   -- Teleport: Orgrimmar
    32271,  -- Teleport: Exodar
    32272,  -- Teleport: Silvermoon
    49358,  -- Teleport: Stonard
    49359,  -- Teleport: Theramore
    53140,  -- Teleport: Dalaran (Northrend)
    88342,  -- Teleport: Tol Barad
    120145, -- Ancient Teleport: Dalaran
    132621, -- Teleport: Vale of Eternal Blossoms (Alliance)
    132627, -- Teleport: Vale of Eternal Blossoms (Horde)
    176242, -- Teleport: Warspear
    176248, -- Teleport: Stormshield
    224869, -- Teleport: Dalaran - Broken Isles
    281402, -- Teleport: Boralus
    281404, -- Teleport: Dazar'alor
    344587, -- Teleport: Oribos
    395277, -- Teleport: Valdrakken
    446540, -- Teleport: Dornogal
}

local MAGE_PORTAL_SPELL_IDS = {
    10059,  -- Portal: Stormwind
    11416,  -- Portal: Ironforge
    11417,  -- Portal: Orgrimmar
    11418,  -- Portal: Undercity
    11419,  -- Portal: Darnassus
    11420,  -- Portal: Thunder Bluff
    32266,  -- Portal: Exodar
    32267,  -- Portal: Silvermoon
    33691,  -- Portal: Shattrath
    49360,  -- Portal: Theramore
    49361,  -- Portal: Stonard
    53142,  -- Portal: Dalaran (Northrend)
    88345,  -- Portal: Tol Barad
    120146, -- Ancient Portal: Dalaran
    132620, -- Portal: Vale of Eternal Blossoms (Horde)
    132626, -- Portal: Vale of Eternal Blossoms (Alliance)
    176244, -- Portal: Warspear
    176246, -- Portal: Stormshield
    224871, -- Portal: Dalaran - Broken Isles
    281400, -- Portal: Boralus
    281403, -- Portal: Dazar'alor
    344597, -- Portal: Oribos
    395289, -- Portal: Valdrakken
    446534, -- Portal: Dornogal
}

local function normalizeTextureToken(textureValue)
    if type(textureValue) == "number" then
        if textureValue > 0 then
            return textureValue
        end
        return nil
    end

    if type(textureValue) == "string" then
        if textureValue == "" then
            return nil
        end

        local numeric = tonumber(textureValue)
        if numeric and numeric > 0 then
            return numeric
        end

        if string.find(textureValue, "\\", 1, true) or string.find(textureValue, "/", 1, true) then
            return textureValue
        end
    end

    return nil
end

-- Derive localized travel category token from known sample spells (e.g. "Teleport", "Portal").
local function buildTravelToken(sampleSpellIDs, fallbackToken)
    if not C_Spell or not C_Spell.GetSpellInfo then
        return string.lower(fallbackToken)
    end

    for i = 1, #sampleSpellIDs do
        local spellInfo = C_Spell.GetSpellInfo(sampleSpellIDs[i])
        local spellName = spellInfo and spellInfo.name
        if type(spellName) == "string" and spellName ~= "" then
            local token = spellName:match("^(.-):")
            if type(token) == "string" and token ~= "" then
                return string.lower(token)
            end
            return string.lower(spellName)
        end
    end

    return string.lower(fallbackToken)
end

local TELEPORT_TOKEN = buildTravelToken({ 3561, 3567, 53140 }, "Teleport")
local PORTAL_TOKEN = buildTravelToken({ 10059, 11417, 53142 }, "Portal")

function Portals:OnInitialize()
    -- Tracks deferred secure-button updates blocked by combat lockdown.
    self.pendingUtilityRefresh = false
    self.isMage = false
    self.knownMageTeleportSpells = {}
    self.knownMagePortalSpells = {}
    self.toyFlyoutButtons = {}
    self:RegisterEvent("PLAYER_LOGIN")
end

function Portals:OnEnable()
    self:RegisterMessage("VESPERGUILD_CONFIG_CHANGED", "OnConfigChanged")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("TOYS_UPDATED")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Portals:PLAYER_LOGIN()
    self:RegisterChatCommand("vesperportals", "Toggle")
    self:CreatePortalFrame()
end

-- Refresh hearthstone buttons when bag contents change.
function Portals:BAG_UPDATE_DELAYED()
    self:RefreshHearthstoneButtons()
end

-- Refresh hearthstone buttons when toy ownership state changes.
function Portals:TOYS_UPDATED()
    self:RefreshHearthstoneButtons()
    self:RefreshToyFlyout()
end

-- Refresh mage travel menus/icons when spellbook changes (newly learned spells, etc.).
function Portals:SPELLS_CHANGED()
    self:RefreshMageTravelButtons()
end

-- Combat lockdown can block secure attribute writes; apply queued updates here.
function Portals:PLAYER_REGEN_ENABLED()
    if self.pendingUtilityRefresh then
        self.pendingUtilityRefresh = false
        self:RefreshHearthstoneButtons()
        self:RefreshToyFlyout()
    end
end

-- Apply configured background opacity to all portal-related panels.
function Portals:ApplyBackdropOpacity()
    local portalsOpacity = VesperGuild:GetConfiguredOpacity("portals")
    local bestKeysOpacity = VesperGuild:GetConfiguredOpacity("bestKeys")

    if self.VesperPortalsUI then
        self.VesperPortalsUI:SetBackdropColor(0.07, 0.07, 0.07, portalsOpacity)
    end
    if self.vaultFrame then
        self.vaultFrame:SetBackdropColor(0.07, 0.07, 0.07, portalsOpacity)
    end
    if self.topUtilityFrame then
        self.topUtilityFrame:SetBackdropColor(0.07, 0.07, 0.07, portalsOpacity)
    end
    if self.toyFlyoutFrame then
        self.toyFlyoutFrame:SetBackdropColor(0.07, 0.07, 0.07, portalsOpacity)
    end
    if self.mplusProgFrame then
        self.mplusProgFrame:SetBackdropColor(0.07, 0.07, 0.07, bestKeysOpacity)
    end
end

-- React to global config changes.
-- If portal UI is visible, rebuild best-keys panel to refresh font + opacity.
function Portals:OnConfigChanged()
    self:ApplyBackdropOpacity()
    self:RefreshHearthstoneButtons()
    self:RefreshToyFlyout()
    self:RefreshMageTravelButtons()

    if self.VesperPortalsUI and self.VesperPortalsUI:IsShown() then
        if self.mplusProgFrame then
            self.mplusProgFrame:Hide()
            self.mplusProgFrame:SetParent(nil)
            self.mplusProgFrame = nil
        end

        local curSeason = C_ChallengeMode.GetMapTable()
        if curSeason and #curSeason > 0 then
            self:CreateMPlusProgFrame(curSeason)
        end
    end
end

-- Collect known mage travel spells of the requested kind ("teleport" or "portal").
-- Source strategy:
-- 1) curated spellID catalog (stable and locale-independent)
-- 2) spellbook scan by localized token (captures newly added variants)
function Portals:GetKnownMageTravelSpells(kind)
    local spellIDs = (kind == "portal") and MAGE_PORTAL_SPELL_IDS or MAGE_TELEPORT_SPELL_IDS
    local token = (kind == "portal") and PORTAL_TOKEN or TELEPORT_TOKEN
    local spells = {}
    local seen = {}

    local function tryAddSpell(spellID, explicitName)
        if not spellID or seen[spellID] then
            return
        end

        local known = C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID)
        if not known then
            return
        end

        local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
        local spellName = explicitName or (spellInfo and spellInfo.name)
        if type(spellName) ~= "string" or spellName == "" then
            return
        end

        local icon = normalizeTextureToken(spellInfo and (spellInfo.iconID or spellInfo.originalIconID))
            or FALLBACK_ICON_TEXTURE

        spells[#spells + 1] = {
            spellID = spellID,
            name = spellName,
            icon = icon,
        }
        seen[spellID] = true
    end

    for i = 1, #spellIDs do
        tryAddSpell(spellIDs[i])
    end

    -- Spellbook scan fallback picks up travel spells not yet in the local curated list.
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        local spellBookType = BOOKTYPE_SPELL or "spell"
        local numTabs = GetNumSpellTabs()
        for tab = 1, numTabs do
            local _, _, offset, numSlots = GetSpellTabInfo(tab)
            if offset and numSlots then
                for slot = (offset + 1), (offset + numSlots) do
                    local itemType, spellID = GetSpellBookItemInfo(slot, spellBookType)
                    if itemType == "SPELL" and spellID and not seen[spellID] then
                        local spellName = GetSpellBookItemName and GetSpellBookItemName(slot, spellBookType)
                        if type(spellName) == "string" and spellName ~= "" then
                            local lowerName = string.lower(spellName)
                            if string.find(lowerName, token, 1, true) then
                                tryAddSpell(spellID, spellName)
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(spells, function(a, b)
        return a.name < b.name
    end)

    return spells
end

-- Build a contextual spell menu for mage travel buttons.
function Portals:OpenMageTravelMenu(button, kind)
    if not button then
        return
    end
    if InCombatLockdown() then
        return
    end

    local spells = (kind == "portal") and self.knownMagePortalSpells or self.knownMageTeleportSpells
    if type(spells) ~= "table" or #spells == 0 then
        return
    end

    local menuTitle = (kind == "portal") and "Mage Portals" or "Mage Teleports"
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        MenuUtil.CreateContextMenu(button, function(_, rootDescription)
            rootDescription:CreateTitle(menuTitle)
            for i = 1, #spells do
                local entry = spells[i]
                local icon = entry.icon or FALLBACK_ICON_TEXTURE
                local rowLabel = string.format("|T%s:16:16:0:0|t %s", icon, entry.name)
                rootDescription:CreateButton(rowLabel, function()
                    if C_Spell and C_Spell.CastSpell then
                        C_Spell.CastSpell(entry.spellID)
                    elseif CastSpellByID then
                        CastSpellByID(entry.spellID)
                    elseif CastSpell then
                        CastSpell(entry.name)
                    end
                end)
            end
        end)
        return
    end

    -- Fallback behavior when context menus are unavailable:
    -- cycle through known spells and cast the next one each click.
    local cycleIndexKey = (kind == "portal") and "_magePortalCycleIndex" or "_mageTeleportCycleIndex"
    local nextIndex = ((tonumber(self[cycleIndexKey]) or 0) % #spells) + 1
    self[cycleIndexKey] = nextIndex
    local selectedSpell = spells[nextIndex]

    if C_Spell and C_Spell.CastSpell then
        C_Spell.CastSpell(selectedSpell.spellID)
    elseif CastSpellByID then
        CastSpellByID(selectedSpell.spellID)
    elseif CastSpell then
        CastSpell(selectedSpell.name)
    end
end

-- Return top-utility buttons in their visual order for horizontal layout.
function Portals:GetTopUtilityButtons()
    local ordered = {}
    if self.primaryHearthstoneButton then
        ordered[#ordered + 1] = self.primaryHearthstoneButton
    end
    if self.secondaryHearthstoneButton then
        ordered[#ordered + 1] = self.secondaryHearthstoneButton
    end
    if self.isMage then
        if self.magePortalButton then
            ordered[#ordered + 1] = self.magePortalButton
        end
        if self.mageTeleportButton then
            ordered[#ordered + 1] = self.mageTeleportButton
        end
    end
    -- Keep toys last so mage row order is:
    -- primary, dalaran, portals, teleports, toys.
    if self.toyFlyoutButton then
        ordered[#ordered + 1] = self.toyFlyoutButton
    end
    return ordered
end

-- Size and position top-utility frame dynamically while keeping center alignment.
function Portals:LayoutTopUtilityButtons()
    if not self.topUtilityFrame then
        return
    end

    local buttons = self:GetTopUtilityButtons()
    local count = #buttons
    if count == 0 then
        self.topUtilityFrame:SetSize(TOP_UTILITY_PADDING * 2, TOP_UTILITY_HEIGHT)
        return
    end

    local frameWidth = (TOP_UTILITY_PADDING * 2) + (count * TOP_UTILITY_BUTTON_SIZE) + ((count - 1) * TOP_UTILITY_BUTTON_GAP)
    self.topUtilityFrame:SetSize(frameWidth, TOP_UTILITY_HEIGHT)

    for i = 1, count do
        local button = buttons[i]
        button:ClearAllPoints()
        button:SetPoint(
            "LEFT",
            self.topUtilityFrame,
            "LEFT",
            TOP_UTILITY_PADDING + ((i - 1) * (TOP_UTILITY_BUTTON_SIZE + TOP_UTILITY_BUTTON_GAP)),
            0
        )
    end
end

-- Build the hidden flyout frame that expands upward from the toys utility button.
function Portals:CreateToyFlyoutFrame()
    if self.toyFlyoutFrame or not self.topUtilityFrame then
        return
    end

    self.toyFlyoutFrame = CreateFrame("Frame", "VesperGuildToyFlyoutFrame", self.topUtilityFrame, "BackdropTemplate")
    self.toyFlyoutFrame:SetSize(TOP_UTILITY_BUTTON_SIZE + (TOY_FLYOUT_PADDING * 2), TOP_UTILITY_BUTTON_SIZE + (TOY_FLYOUT_PADDING * 2))
    self.toyFlyoutFrame:SetFrameStrata("MEDIUM")
    self.toyFlyoutFrame:SetFrameLevel((self.topUtilityFrame:GetFrameLevel() or 0) + 2)
    self.toyFlyoutFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.toyFlyoutFrame:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("portals"))
    self.toyFlyoutFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)
    self.toyFlyoutFrame:Hide()

    -- Keep flyout visible while hovered and hide once cursor leaves both anchor and flyout.
    self.toyFlyoutFrame:SetScript("OnEnter", function()
        self:ShowToyFlyout()
    end)
    self.toyFlyoutFrame:SetScript("OnLeave", function()
        self:ScheduleToyFlyoutHideCheck()
    end)
end

-- Hide the toy flyout safely.
function Portals:HideToyFlyout()
    self._toyFlyoutHideToken = (tonumber(self._toyFlyoutHideToken) or 0) + 1
    if self.toyFlyoutFrame then
        self.toyFlyoutFrame:Hide()
    end
end

-- Show toy flyout when available.
function Portals:ShowToyFlyout()
    if not self.toyFlyoutFrame then
        return
    end
    if not self.toyFlyoutButton or not self.toyFlyoutButton._isAvailable then
        return
    end
    self._toyFlyoutHideToken = (tonumber(self._toyFlyoutHideToken) or 0) + 1
    self.toyFlyoutFrame:Show()
end

-- Check whether the cursor is still over toy flyout anchor or flyout content.
function Portals:IsToyFlyoutMouseActive()
    if not self.toyFlyoutButton or not self.toyFlyoutFrame then
        return false
    end
    return MouseIsOver and (MouseIsOver(self.toyFlyoutButton) or MouseIsOver(self.toyFlyoutFrame)) or false
end

-- Delay hide to avoid flicker while moving cursor between button and flyout.
function Portals:ScheduleToyFlyoutHideCheck()
    local token = (tonumber(self._toyFlyoutHideToken) or 0) + 1
    self._toyFlyoutHideToken = token

    if not (C_Timer and C_Timer.After) then
        if not self:IsToyFlyoutMouseActive() then
            self:HideToyFlyout()
        end
        return
    end

    C_Timer.After(0.06, function()
        if self._toyFlyoutHideToken ~= token then
            return
        end
        if not self:IsToyFlyoutMouseActive() then
            self:HideToyFlyout()
        end
    end)
end

-- Toggle helper retained for compatibility with existing callsites.
function Portals:ToggleToyFlyout()
    if not self.toyFlyoutFrame then
        return
    end
    if self.toyFlyoutFrame:IsShown() then
        self:HideToyFlyout()
    else
        self:ShowToyFlyout()
    end
end

-- Create one action button in the toy flyout panel.
function Portals:CreateToyFlyoutActionButton(parent)
    local button = self:CreateTopUtilityButton(parent, "SecureActionButtonTemplate")
    button:SetSize(TOP_UTILITY_BUTTON_SIZE, TOP_UTILITY_BUTTON_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    return button
end

-- Refresh the flyout button icon + flyout toy actions from whitelist and ownership.
function Portals:RefreshToyFlyout()
    if not self.toyFlyoutButton then
        return
    end

    local toys = VesperGuild:GetWhitelistedOwnedToyOptions()
    local hasToys = type(toys) == "table" and #toys > 0

    if hasToys then
        self.toyFlyoutButton.icon:SetTexture(toys[1].icon or TOY_FLYOUT_BUTTON_ICON)
        self.toyFlyoutButton.icon:SetDesaturated(false)
        self.toyFlyoutButton.icon:SetAlpha(1)
        self.toyFlyoutButton._isAvailable = true
        self.toyFlyoutButton._displayName = "Utility Toys"
        self.toyFlyoutButton._tooltipHint = "Mouseover: Open flyout"
        self.toyFlyoutButton._unavailableText = "No Whitelisted Toys"
        self.toyFlyoutButton:EnableMouse(true)
    else
        self.toyFlyoutButton.icon:SetTexture(TOY_FLYOUT_BUTTON_ICON)
        self.toyFlyoutButton.icon:SetDesaturated(true)
        self.toyFlyoutButton.icon:SetAlpha(0.45)
        self.toyFlyoutButton._isAvailable = false
        self.toyFlyoutButton._displayName = "Utility Toys"
        self.toyFlyoutButton._tooltipHint = "Mouseover: Open flyout"
        self.toyFlyoutButton._unavailableText = "No Whitelisted Toys"
        self.toyFlyoutButton:EnableMouse(true)
        self:HideToyFlyout()
    end

    self:CreateToyFlyoutFrame()
    if not self.toyFlyoutFrame then
        return
    end

    self.toyFlyoutFrame:ClearAllPoints()
    self.toyFlyoutFrame:SetPoint("BOTTOM", self.toyFlyoutButton, "TOP", 0, 8)

    if InCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    for i = 1, #self.toyFlyoutButtons do
        self.toyFlyoutButtons[i]:Hide()
    end

    if not hasToys then
        self.toyFlyoutFrame:SetSize(TOP_UTILITY_BUTTON_SIZE + (TOY_FLYOUT_PADDING * 2), TOP_UTILITY_BUTTON_SIZE + (TOY_FLYOUT_PADDING * 2))
        return
    end

    local flyoutHeight = (TOY_FLYOUT_PADDING * 2) + (#toys * TOP_UTILITY_BUTTON_SIZE) + ((#toys - 1) * TOY_FLYOUT_BUTTON_GAP)
    self.toyFlyoutFrame:SetSize(TOP_UTILITY_BUTTON_SIZE + (TOY_FLYOUT_PADDING * 2), flyoutHeight)

    for i = 1, #toys do
        local option = toys[i]
        local button = self.toyFlyoutButtons[i]
        if not button then
            button = self:CreateToyFlyoutActionButton(self.toyFlyoutFrame)
            self.toyFlyoutButtons[i] = button
        end

        button:ClearAllPoints()
        button:SetPoint(
            "BOTTOM",
            self.toyFlyoutFrame,
            "BOTTOM",
            0,
            TOY_FLYOUT_PADDING + ((i - 1) * (TOP_UTILITY_BUTTON_SIZE + TOY_FLYOUT_BUTTON_GAP))
        )

        button.icon:SetTexture(option.icon or FALLBACK_ICON_TEXTURE)
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)

        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", "/use item:" .. tostring(option.itemID))
        button._isAvailable = true
        button._displayName = option.name or ("Toy " .. tostring(option.itemID))
        button._tooltipHint = "Left-click: Use"
        button._unavailableText = "Unavailable"
        button:Show()
    end
end

-- Build one icon-only hearthstone action button in the same visual style as Great Vault.
function Portals:CreateTopUtilityButton(parent, templateName)
    -- Use SecureActionButtonTemplate directly to avoid ActionButton-style scripts
    -- from template stacks that can hide custom icon textures.
    local button
    if type(templateName) == "string" and templateName ~= "" and templateName ~= "Button" then
        button = CreateFrame("Button", nil, parent, templateName)
    else
        button = CreateFrame("Button", nil, parent)
    end
    button:SetSize(TOP_UTILITY_BUTTON_SIZE, TOP_UTILITY_BUTTON_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")

    -- Match portal/great-vault icon framing so the icon is always visible above backdrop.
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    button.bg = bg

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetAllPoints()
    icon:SetTexture(FALLBACK_ICON_TEXTURE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetBlendMode("BLEND")
    icon:Show()
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 0, 0.4)
    button:SetHighlightTexture(highlight)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        if selfButton._isAvailable then
            GameTooltip:SetText(selfButton._displayName or "Utility", 1, 1, 1)
            GameTooltip:AddLine(selfButton._tooltipHint or "Left-click: Use", 0.85, 0.85, 0.85)
        else
            GameTooltip:SetText(selfButton._unavailableText or "Unavailable", 1, 0.4, 0.4)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

-- Build the utility frame shown above portals and create both hearthstone buttons.
function Portals:CreateTopUtilityFrame()
    if self.topUtilityFrame then
        return
    end

    local _, playerClass = UnitClass("player")
    self.isMage = (playerClass == "MAGE")

    self.topUtilityFrame = CreateFrame("Frame", "VesperGuildTopUtilityFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.topUtilityFrame:SetSize(134, TOP_UTILITY_HEIGHT)
    self.topUtilityFrame:SetPoint("BOTTOM", self.VesperPortalsUI, "TOP", 0, 10)
    self.topUtilityFrame:SetFrameStrata("MEDIUM")

    self.topUtilityFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.topUtilityFrame:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("portals"))
    self.topUtilityFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    -- Two hearthstone buttons are always available.
    self.primaryHearthstoneButton = self:CreateTopUtilityButton(self.topUtilityFrame, "SecureActionButtonTemplate")
    self.secondaryHearthstoneButton = self:CreateTopUtilityButton(self.topUtilityFrame, "SecureActionButtonTemplate")

    -- Toy flyout button is available for all classes.
    self.toyFlyoutButton = self:CreateTopUtilityButton(self.topUtilityFrame, "Button")
    self.toyFlyoutButton.icon:SetTexture(TOY_FLYOUT_BUTTON_ICON)
    -- Hovering the anchor opens the flyout; clicks are handled by flyout icons themselves.
    self.toyFlyoutButton:SetScript("OnClick", nil)
    self.toyFlyoutButton:HookScript("OnEnter", function()
        self:ShowToyFlyout()
    end)
    self.toyFlyoutButton:HookScript("OnLeave", function()
        self:ScheduleToyFlyoutHideCheck()
    end)

    -- Mage-specific utility buttons: travel spell pickers.
    if self.isMage then
        self.mageTeleportButton = self:CreateTopUtilityButton(self.topUtilityFrame, "Button")
        self.mageTeleportButton:SetScript("OnClick", function(button, mouseButton)
            if mouseButton == "LeftButton" then
                self:OpenMageTravelMenu(button, "teleport")
            end
        end)

        self.magePortalButton = self:CreateTopUtilityButton(self.topUtilityFrame, "Button")
        self.magePortalButton:SetScript("OnClick", function(button, mouseButton)
            if mouseButton == "LeftButton" then
                self:OpenMageTravelMenu(button, "portal")
            end
        end)
    end

    self:LayoutTopUtilityButtons()
    self:CreateToyFlyoutFrame()
end

-- Apply visual/tooltip state for one mage travel utility button.
function Portals:ApplyMageTravelButtonState(button, spells, titleText, unavailableText, hintText)
    if not button or not button.icon then
        return
    end

    local hasSpells = type(spells) == "table" and #spells > 0
    if hasSpells then
        local icon = spells[1].icon or FALLBACK_ICON_TEXTURE
        button.icon:SetTexture(icon)
        button.icon:SetDrawLayer("ARTWORK", 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.icon:SetBlendMode("BLEND")
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
        button.icon:Show()
        button:EnableMouse(true)

        button._isAvailable = true
        button._displayName = titleText
        button._unavailableText = unavailableText
        button._tooltipHint = hintText
    else
        button.icon:SetTexture(FALLBACK_ICON_TEXTURE)
        button.icon:SetDrawLayer("ARTWORK", 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.icon:SetBlendMode("BLEND")
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.4)
        button.icon:Show()
        button:EnableMouse(false)

        button._isAvailable = false
        button._displayName = titleText
        button._unavailableText = unavailableText
        button._tooltipHint = hintText
    end
end

-- Refresh mage travel buttons from current known spellbook state.
function Portals:RefreshMageTravelButtons()
    if not self.isMage then
        return
    end
    if not self.mageTeleportButton or not self.magePortalButton then
        return
    end

    self.knownMageTeleportSpells = self:GetKnownMageTravelSpells("teleport")
    self.knownMagePortalSpells = self:GetKnownMageTravelSpells("portal")

    self:ApplyMageTravelButtonState(
        self.mageTeleportButton,
        self.knownMageTeleportSpells,
        "Mage Teleports",
        "No Teleport Spells Known",
        "Left-click: Open teleport flyout"
    )
    self:ApplyMageTravelButtonState(
        self.magePortalButton,
        self.knownMagePortalSpells,
        "Mage Portals",
        "No Portal Spells Known",
        "Left-click: Open portal flyout"
    )
end

-- Apply one hearthstone option to one secure button.
-- Called only out of combat because secure attributes are updated here.
function Portals:ApplyHearthstoneOption(button, option)
    if not button or not button.icon then
        return
    end

    if option then
        local icon = normalizeTextureToken(option.icon)

        if not icon and C_Item and C_Item.GetItemIconByID then
            icon = normalizeTextureToken(C_Item.GetItemIconByID(option.itemID))
        end
        if not icon and C_Item and C_Item.GetItemInfoInstant then
            local i1, i2, i3, i4, i5, i6, i7, i8, i9, i10 = C_Item.GetItemInfoInstant(option.itemID)
            icon = normalizeTextureToken(i3)
                or normalizeTextureToken(i5)
                or normalizeTextureToken(i10)
                or icon
        end
        if not icon and C_ToyBox and C_ToyBox.GetToyInfo then
            local t1, t2, t3, t4, t5 = C_ToyBox.GetToyInfo(option.itemID)
            icon = normalizeTextureToken(t3)
                or normalizeTextureToken(t2)
                or normalizeTextureToken(t4)
                or normalizeTextureToken(t5)
                or icon
        end
        if not icon and C_Item and C_Item.GetItemSpell and C_Spell and C_Spell.GetSpellInfo then
            local _, itemSpellID = C_Item.GetItemSpell(option.itemID)
            if itemSpellID then
                local spellInfo = C_Spell.GetSpellInfo(itemSpellID)
                icon = normalizeTextureToken(spellInfo and (spellInfo.iconID or spellInfo.originalIconID)) or icon
            end
        end
        if not icon then
            local i1, i2, i3, i4, i5, i6, i7, i8, i9, i10 = GetItemInfoInstant(option.itemID)
            icon = normalizeTextureToken(i3)
                or normalizeTextureToken(i5)
                or normalizeTextureToken(i10)
                or icon
        end

        button.icon:SetTexture(icon or FALLBACK_ICON_TEXTURE)
        button.icon:SetDrawLayer("ARTWORK", 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.icon:SetBlendMode("BLEND")
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
        button.icon:Show()
        button:EnableMouse(true)

        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", "/use item:" .. tostring(option.itemID))

        button._isAvailable = true
        button._displayName = option.name or ("Item " .. tostring(option.itemID))
        button._tooltipHint = "Left-click: Use"
        button._unavailableText = "No Hearthstones Available"
        button._itemID = option.itemID
    else
        button.icon:SetTexture(FALLBACK_ICON_TEXTURE)
        button.icon:SetDrawLayer("ARTWORK", 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.icon:SetBlendMode("BLEND")
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.4)
        button.icon:Show()
        button:EnableMouse(false)

        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("type1", nil)

        button._isAvailable = false
        button._displayName = "Hearthstone"
        button._tooltipHint = "Left-click: Use"
        button._unavailableText = "No Hearthstones Available"
        button._itemID = nil
    end
end

-- Refresh both top utility hearthstone buttons from current profile + ownership state.
function Portals:RefreshHearthstoneButtons()
    if not self.topUtilityFrame or not self.primaryHearthstoneButton or not self.secondaryHearthstoneButton then
        return
    end

    if InCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    local options = VesperGuild:GetAvailableHearthstoneOptions()
    local optionsByID = {}
    for i = 1, #options do
        optionsByID[options[i].itemID] = options[i]
    end

    local primaryID = VesperGuild:ResolvePrimaryHearthstoneID()
    local secondaryID = VesperGuild:GetSecondaryHearthstoneID(primaryID)

    self:ApplyHearthstoneOption(self.primaryHearthstoneButton, primaryID and optionsByID[primaryID] or nil)
    self:ApplyHearthstoneOption(self.secondaryHearthstoneButton, secondaryID and optionsByID[secondaryID] or nil)
end

function Portals:CreatePortalFrame()
    local _, englishClass = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(englishClass)
    -- Reuse player class color as a consistent accent across all portal panels.
    self.classColor = classColor

    self.VesperPortalsUI = CreateFrame("Frame", "VesperGuildPortalFrame", UIParent, "BackdropTemplate")
    self.VesperPortalsUI:SetSize(300, 160)

    -- Restore saved position or use default
    if VesperGuild.db.profile.portalsPosition then
        local pos = VesperGuild.db.profile.portalsPosition
        self.VesperPortalsUI:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        self.VesperPortalsUI:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
    end

    self.VesperPortalsUI:SetFrameStrata("MEDIUM")
    self.VesperPortalsUI:SetMovable(true)
    self.VesperPortalsUI:EnableMouse(true)
    self.VesperPortalsUI:RegisterForDrag("LeftButton")
    self.VesperPortalsUI:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    self.VesperPortalsUI:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        VesperGuild.db.profile.portalsPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end)
    self.VesperPortalsUI:Hide()
    
     self.VesperPortalsUI:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8x8",
         edgeFile = "Interface\\Buttons\\WHITE8x8",
         edgeSize = 1,
     })
     self.VesperPortalsUI:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("portals")) -- #121212
     self.VesperPortalsUI:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if not DataHandle then
        print("ERROR: DataHandle module not found!")
        return
    end

    local curSeason = C_ChallengeMode.GetMapTable() or {}
    local curSeasonDungs = {}
    -- Keep only maps we have metadata for; unknown mapIDs are skipped safely.
    for _, id in ipairs(curSeason) do
        local dungInfo = DataHandle:GetDungeonByMapID(id)
        if dungInfo then
            table.insert(curSeasonDungs, dungInfo)
        end
    end

    local index = 1
    for _, dungInfo in ipairs(curSeasonDungs) do
            local spellInfo = C_Spell.GetSpellInfo(dungInfo.spellID)
            local spellName = spellInfo and spellInfo.name
            local iconFileID = spellInfo and (spellInfo.iconID or spellInfo.originalIconID)
            local known = C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(dungInfo.spellID)
            local btn = CreateFrame("Button", "PortalButton" .. index, self.VesperPortalsUI, "InsecureActionButtonTemplate")
                btn:SetSize(52, 52)
                
                -- Arrange in 4x2 grid (4 columns, 2 rows)
                local col = (index - 1) % 4
                local row = math.floor((index - 1) / 4)
                btn:SetPoint("TOPLEFT", self.VesperPortalsUI, "TOPLEFT", 20 + col * 70, -20 - row * 70)

            -- Background
            local tex = btn:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints(btn)
                tex:SetColorTexture(0, 0, 0, 0.8)
            
            -- Highlight on mouseover
            local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
			    highlight:SetAllPoints(btn)
			    highlight:SetColorTexture(1, 1, 0, 0.4)
			    btn:SetHighlightTexture(highlight)

            -- Dungeon Icon Overlay
            local icon = btn:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(btn)
                icon:SetTexture(iconFileID or "Interface\\ICONS\\INV_Misc_QuestionMark")
                btn.icon = icon

            -- CD
            btn.cooldownFrame = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
			btn.cooldownFrame:SetAllPoints(btn)

            -- Disable click when portal spell is not learned.
            -- This avoids secure-action errors and matches visual desaturation state.
            if not known then
				icon:SetDesaturated(true)
				icon:SetAlpha(0.5)
				btn:EnableMouse(false)
			else
				icon:SetDesaturated(false)
				icon:SetAlpha(1)
				btn:EnableMouse(true)
			end

            -- Tooltip
            btn.dungeonName = dungInfo.dungeonName
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.dungeonName, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            -- Clickitty Click
            btn:SetAttribute("type1", "spell")
            btn:SetAttribute("spell1", spellName)
            btn:RegisterForClicks("AnyUp", "AnyDown")

            index = index + 1
        end

    self:CreateTopUtilityFrame()
    self:RefreshHearthstoneButtons()
    self:RefreshToyFlyout()
    self:RefreshMageTravelButtons()
    self:CreateVaultFrame()
end

function Portals:CreateVaultFrame()
    self.vaultFrame = CreateFrame("Frame", "VesperGuildVaultFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.vaultFrame:SetSize(72, 72)
    self.vaultFrame:SetPoint("TOP", self.VesperPortalsUI, "BOTTOM", 0, -10)
    self.vaultFrame:SetFrameStrata("MEDIUM")

    self.vaultFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.vaultFrame:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("portals"))
    self.vaultFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local btn = CreateFrame("Button", nil, self.vaultFrame)
    btn:SetSize(52, 52)
    btn:SetPoint("CENTER")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider")

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 0, 0.4)
    btn:SetHighlightTexture(highlight)

    btn:SetScript("OnClick", function()
        if WeeklyRewards_ShowUI then
            WeeklyRewards_ShowUI()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Great Vault", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Portals:CreateMPlusProgFrame(curSeason)
    -- Typography for the Best Keys panel is independently configurable.
    local bestKeysFontSize = VesperGuild:GetConfiguredFontSize("bestKeys", 11, 8, 24)

    local rowHeight = 18
    local headerHeight = 22
    local padding = 10
    local bestColWidth = 40 -- space for "+XX" text
    local timeColWidth = 55 -- space for "mm:ss" text
    local gap = 10 -- gap between columns
    local numDungeons = #curSeason
    local frameHeight = headerHeight + (numDungeons * rowHeight) + (padding * 2)

    -- Measure widest dungeon name to size frame dynamically
    local measure = UIParent:CreateFontString(nil, "OVERLAY")
    VesperGuild:ApplyConfiguredFont(measure, bestKeysFontSize, "")
    local maxNameWidth = 0
    for _, mapID in ipairs(curSeason) do
        local dungName = C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown"
        measure:SetText(dungName)
        local w = measure:GetStringWidth()
        if w > maxNameWidth then maxNameWidth = w end
    end
    measure:Hide()

    local frameWidth = math.ceil(maxNameWidth) + bestColWidth + timeColWidth + (gap * 2) + (padding * 2)

    self.mplusProgFrame = CreateFrame("Frame", "VesperGuildMPlusProgFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.mplusProgFrame:SetSize(frameWidth, frameHeight)
    self.mplusProgFrame:SetPoint("LEFT", self.VesperPortalsUI, "RIGHT", 10, 0)
    self.mplusProgFrame:SetFrameStrata("MEDIUM")

    self.mplusProgFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.mplusProgFrame:SetBackdropColor(0.07, 0.07, 0.07, VesperGuild:GetConfiguredOpacity("bestKeys"))
    self.mplusProgFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local timeColRight = -padding
    local bestColRight = timeColRight - timeColWidth - gap

    -- Header
    local nameHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    VesperGuild:ApplyConfiguredFont(nameHeader, bestKeysFontSize, "")
    nameHeader:SetPoint("TOPLEFT", padding, -padding)
    nameHeader:SetText("|cffFFFFFFDungeon|r")

    local keyHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    VesperGuild:ApplyConfiguredFont(keyHeader, bestKeysFontSize, "")
    keyHeader:SetPoint("TOPRIGHT", bestColRight, -padding)
    keyHeader:SetText("|cffFFFFFFBest|r")

    local timeHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    VesperGuild:ApplyConfiguredFont(timeHeader, bestKeysFontSize, "")
    timeHeader:SetPoint("TOPRIGHT", timeColRight, -padding)
    timeHeader:SetText("|cffFFFFFFTime|r")

    -- Rows
    for i, mapID in ipairs(curSeason) do
        local rowTop = -(padding + headerHeight + (i - 1) * rowHeight)
        local rowCenter = rowTop - (rowHeight / 2)

        -- Zebra stripe background
        if i % 2 == 0 then
            local stripe = self.mplusProgFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
            stripe:SetPoint("TOPLEFT", self.mplusProgFrame, "TOPLEFT", 1, rowTop)
            stripe:SetPoint("TOPRIGHT", self.mplusProgFrame, "TOPRIGHT", -1, rowTop)
            stripe:SetHeight(rowHeight)
            stripe:SetColorTexture(0.17, 0.17, 0.17, 1)
        end

        -- Dungeon name
        local dungName = C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown"
        local nameText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        VesperGuild:ApplyConfiguredFont(nameText, bestKeysFontSize, "")
        nameText:SetPoint("LEFT", self.mplusProgFrame, "TOPLEFT", padding, rowCenter)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(dungName)

        -- Best key level
        local bestLevel = 0
        local bestDuration = 0
        local wasInTime = false
        local inTimeInfo, overTimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
        if inTimeInfo and inTimeInfo.level then
            bestLevel = inTimeInfo.level
            bestDuration = inTimeInfo.durationSec
            wasInTime = true
        end
        -- Prefer higher level even if overtime, since "best" column represents level ceiling.
        if overTimeInfo and overTimeInfo.level and overTimeInfo.level > bestLevel then
            bestLevel = overTimeInfo.level
            bestDuration = overTimeInfo.durationSec
            wasInTime = false
        end

        local levelText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        VesperGuild:ApplyConfiguredFont(levelText, bestKeysFontSize, "")
        levelText:SetPoint("RIGHT", self.mplusProgFrame, "TOPRIGHT", bestColRight, rowCenter)
        levelText:SetJustifyH("RIGHT")

        local timeText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        VesperGuild:ApplyConfiguredFont(timeText, bestKeysFontSize, "")
        timeText:SetPoint("RIGHT", self.mplusProgFrame, "TOPRIGHT", timeColRight, rowCenter)
        timeText:SetJustifyH("RIGHT")

        if bestLevel > 0 then
            local DataHandle = VesperGuild:GetModule("DataHandle", true)
            local color = DataHandle and DataHandle:GetKeyColor(bestLevel) or "|cff9d9d9d"
            levelText:SetText(color .. "+" .. bestLevel .. "|r")

            local mins = math.floor(bestDuration / 60)
            local secs = bestDuration % 60
            local timeStr = string.format("%d:%02d", mins, secs)
            if wasInTime then
                timeText:SetText("|cff81c784" .. timeStr .. "|r") -- Material light green
            else
                timeText:SetText("|cffe57373" .. timeStr .. "|r") -- Material light red
            end
        else
            levelText:SetText("|cff9d9d9d-|r")
            timeText:SetText("|cff9d9d9d-|r")
        end
    end
end

function Portals:Toggle()
    if InCombatLockdown() then
        -- Portal buttons use secure attributes; prevent show/hide rebuilds in combat lockdown.
        print("Can't toggle UI during combat.")
        return
    end

    if not self.VesperPortalsUI then
        print("Portal UI not initialized yet.")
        return
    end

    if self.VesperPortalsUI:IsShown() then
        self:HideToyFlyout()
        self.VesperPortalsUI:Hide()
    else
        -- Rebuild each open so current-season best run data is always fresh.
        if self.mplusProgFrame then
            self.mplusProgFrame:Hide()
            self.mplusProgFrame:SetParent(nil)
            self.mplusProgFrame = nil
        end
        local curSeason = C_ChallengeMode.GetMapTable()
        if curSeason and #curSeason > 0 then
            self:CreateMPlusProgFrame(curSeason)
        end
        self.VesperPortalsUI:Show()
    end
end
