local _, addonTable = ...
local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local Portals = vesperTools:NewModule("Portals", "AceEvent-3.0")
local L = vesperTools.L
local AddonServices = addonTable.AddonServices
-- Portals owns the seasonal portal frame and the top utility button cluster.
-- It also tracks cooldown text, mage travel menus, and hearthstone/toy flyouts.
local FALLBACK_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local TOY_FLYOUT_BUTTON_ICON = "Interface\\Icons\\INV_Misc_Toy_10"
local TOP_UTILITY_BUTTON_GAP = 10
local TOP_UTILITY_PADDING = 10
local TOP_UTILITY_FRAME_VERTICAL_PADDING = 20
local TOY_FLYOUT_BUTTON_GAP = 8
local TOY_FLYOUT_PADDING = 8
local TOY_FLYOUT_COLUMN_GAP = 8
local TOY_FLYOUT_ANCHOR_Y_OFFSET = 13
local TOY_FLYOUT_SCREEN_MARGIN = 10
-- Long enough to cross the gap between the anchor button and the flyout.
local TOY_FLYOUT_HIDE_DELAY = 0.5
local COOLDOWN_TEXT_UPDATE_INTERVAL = 0.1
-- Coalesce window for SPELLS_CHANGED bursts (talents/spec/login fire many in a row).
local SPELLS_CHANGED_COALESCE_DELAY = 0.15
local DUNGEON_PORTAL_REBUILD_COALESCE_DELAY = 0.25
-- Periodic sanity sweep so a missed event (TOYS_UPDATED, SPELLS_CHANGED, ...) can't
-- leave the UI permanently stale. 5 minutes is gentle on CPU and good enough for
-- catching dropped state transitions without the user noticing latency.
local SANITY_SWEEP_INTERVAL = 300

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
    32272,  -- Teleport: Silvermoon (Burning Crusade)
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
    1259190, -- Teleport: Silvermoon City (Midnight)
}

local MAGE_PORTAL_SPELL_IDS = {
    10059,  -- Portal: Stormwind
    11416,  -- Portal: Ironforge
    11417,  -- Portal: Orgrimmar
    11418,  -- Portal: Undercity
    11419,  -- Portal: Darnassus
    11420,  -- Portal: Thunder Bluff
    32266,  -- Portal: Exodar
    32267,  -- Portal: Silvermoon (Burning Crusade)
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
    1259194, -- Portal: Silvermoon City (Midnight)
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
    if not vesperTools or type(vesperTools.GetSpellInfoSafe) ~= "function" then
        return string.lower(fallbackToken)
    end

    for i = 1, #sampleSpellIDs do
        local spellInfo = vesperTools:GetSpellInfoSafe(sampleSpellIDs[i])
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

local function formatCooldownRemaining(seconds)
    local remaining = tonumber(seconds) or 0
    if remaining <= 0 then
        return ""
    end
    if remaining >= 86400 then
        return string.format("%dd", math.floor((remaining / 86400) + 0.5))
    end
    if remaining >= 3600 then
        return string.format("%dh", math.floor((remaining / 3600) + 0.5))
    end
    if remaining >= 60 then
        return string.format("%dm", math.floor((remaining / 60) + 0.5))
    end
    if remaining >= 10 then
        return tostring(math.floor(remaining + 0.5))
    end
    return string.format("%.1f", remaining)
end

local function getPlayerMythicPlusRating(summary)
    if type(summary) == "table" and type(summary.currentSeasonScore) == "number" then
        return math.max(0, math.floor(summary.currentSeasonScore + 0.5))
    end

    return 0
end

local function callAPI(apiFunc, ...)
    if type(apiFunc) ~= "function" then
        return false
    end

    return pcall(apiFunc, ...)
end

local function isSecretValue(value)
    local isSecret = _G and _G.issecretvalue
    return type(isSecret) == "function" and isSecret(value)
end

local function getPublicNumber(value)
    if isSecretValue(value) then
        return nil
    end

    return tonumber(value)
end

local function getPublicCooldownEnabled(value, fallback)
    if isSecretValue(value) then
        return nil
    end

    if value == nil then
        return fallback or 0
    end
    if value == true then
        return 1
    end
    if value == false then
        return 0
    end

    local numericValue = tonumber(value)
    if numericValue then
        return numericValue ~= 0 and 1 or 0
    end

    return value and 1 or 0
end

local function getDurationObjectNumber(durationObject, methodName)
    if durationObject == nil or type(methodName) ~= "string" then
        return nil
    end

    local method = durationObject[methodName]
    if type(method) ~= "function" then
        return nil
    end

    local ok, value = pcall(method, durationObject)
    if not ok then
        return nil
    end

    return getPublicNumber(value)
end

local function isInCombatLockdown()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getChallengeModeMapTableSafe()
    local ok, mapTable = callAPI(C_ChallengeMode and C_ChallengeMode.GetMapTable)
    if ok and type(mapTable) == "table" then
        return mapTable
    end
    return {}
end

local function getChallengeModeMapNameSafe(mapID)
    local ok, dungeonName = callAPI(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, mapID)
    if ok and type(dungeonName) == "string" and dungeonName ~= "" then
        return dungeonName
    end
    return nil
end

local function getSeasonBestForMapSafe(mapID)
    local ok, inTimeInfo, overTimeInfo = callAPI(C_MythicPlus and C_MythicPlus.GetSeasonBestForMap, mapID)
    if ok then
        return inTimeInfo, overTimeInfo
    end
    return nil, nil
end

local function getDungeonCatalogEntries(dataHandle, mapID, dungeonName)
    if not dataHandle then
        return nil, dungeonName
    end

    if type(dataHandle.GetDungeonsByMapID) == "function" then
        local entries = dataHandle:GetDungeonsByMapID(mapID)
        if type(entries) == "table" and #entries > 0 then
            return entries, dungeonName
        end
    end

    local resolvedDungeonName = dungeonName or getChallengeModeMapNameSafe(mapID)
    if resolvedDungeonName and type(dataHandle.GetDungeonsByDungeonName) == "function" then
        local entries = dataHandle:GetDungeonsByDungeonName(resolvedDungeonName)
        if type(entries) == "table" and #entries > 0 then
            return entries, resolvedDungeonName
        end
    end

    return nil, resolvedDungeonName
end

local function buildCurrentSeasonDungeonRecord(dataHandle, mapID)
    local entries, dungeonName = getDungeonCatalogEntries(dataHandle, mapID)
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end

    local entry = entries[1]
    if type(entry) ~= "table" then
        return nil
    end

    return {
        exp = entry.exp,
        mapID = mapID,
        catalogMapID = entry.mapID,
        spellID = entry.spellID,
        dungeonName = dungeonName or entry.dungeonName,
    }
end

local function getMageTravelSelectionKey(kind)
    return kind == "portal" and "_selectedMagePortalSpellID" or "_selectedMageTeleportSpellID"
end

local function getSavedMageTravelSelectionKey(kind)
    return kind == "portal" and "lastMagePortalSpellID" or "lastMageTeleportSpellID"
end

local function findMageTravelSpell(spells, spellID)
    local numericSpellID = tonumber(spellID)
    if not numericSpellID or type(spells) ~= "table" then
        return nil
    end

    for i = 1, #spells do
        local entry = spells[i]
        if entry and tonumber(entry.spellID) == numericSpellID then
            return entry
        end
    end

    return nil
end

-- Lifecycle and event wiring.
function Portals:OnInitialize()
    -- Tracks deferred secure-button updates blocked by combat lockdown.
    self.pendingUtilityRefresh = false
    self.pendingDungeonPortalRefresh = false
    self.pendingDungeonPortalCacheRebuild = false
    self.isMage = false
    self.knownMageTeleportSpells = {}
    self.knownMagePortalSpells = {}
    self.portalButtons = {}
    self.portalButtonPool = {}
    self.toyFlyoutButtons = {}
    self.cooldownButtons = {}
    self.cooldownUpdateElapsed = 0
    self.spellsChangedRefreshTimer = nil
    self.dungeonPortalRebuildTimer = nil
    self.dungeonPortalRebuildDueTime = nil
    self.sanitySweepTicker = nil
    self:RegisterEvent("PLAYER_LOGIN")
end

-- Read configured top utility icon size (hearthstones/toys) with stable fallback.
function Portals:GetTopUtilityButtonSize()
    return vesperTools:GetConfiguredTopUtilityButtonSize()
end

-- Keep utility panel height proportional to icon size while preserving current spacing.
function Portals:GetTopUtilityFrameHeight(buttonSize)
    return math.floor((tonumber(buttonSize) or self:GetTopUtilityButtonSize()) + TOP_UTILITY_FRAME_VERTICAL_PADDING)
end

function Portals:OnEnable()
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
    self:RegisterMessage("VESPERTOOLS_ACCOUNT_KEYSTONE_UPDATED", "OnAccountKeystoneChanged")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self:RegisterEvent("TOYS_UPDATED")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    self:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
end

function Portals:PLAYER_LOGIN()
    AddonServices:RegisterChatCommand(self, "vesperportals", "Toggle")
    AddonServices:RegisterChatCommand(self, "vesperportalspells", "DebugDumpDungeonPortalSpells")
    self:CreatePortalFrame()
    -- Late-binding window: season/portal data sometimes settles after PLAYER_LOGIN.
    -- This must rebuild, not just refresh, because the initial map table can be
    -- incomplete and missing buttons cannot be repainted into existence.
    self:ScheduleSpellsChangedRefresh()
    self:ScheduleDungeonPortalRebuild(1.50)
    self:StartSanitySweepTicker()
end

function Portals:PLAYER_ENTERING_WORLD()
    self:ScheduleDungeonPortalRebuild(0.75)
end

function Portals:CHALLENGE_MODE_MAPS_UPDATE()
    self:ScheduleDungeonPortalRebuild(0)
end

function Portals:MYTHIC_PLUS_CURRENT_AFFIX_UPDATE()
    self:ScheduleDungeonPortalRebuild(DUNGEON_PORTAL_REBUILD_COALESCE_DELAY)
end

-- Refresh hearthstone buttons when bag contents change.
function Portals:BAG_UPDATE_DELAYED()
    self:RefreshHearthstoneButtons()
    self:RefreshActionCooldowns()
end

function Portals:BAG_UPDATE_COOLDOWN()
    self:RefreshActionCooldowns()
end

-- Refresh hearthstone buttons when toy ownership state changes.
function Portals:TOYS_UPDATED()
    -- New/removed toys can shift which IDs match the auto-discovered hearthstone
    -- catalog, so drop the cached merge before we re-query options.
    if vesperTools and type(vesperTools.InvalidateHearthstoneCatalog) == "function" then
        vesperTools:InvalidateHearthstoneCatalog()
    end
    self:RefreshHearthstoneButtons()
    self:RefreshToyFlyout()
    self:RefreshActionCooldowns()
end

-- Coalesce SPELLS_CHANGED bursts. Login (talents, spec load, late spellbook
-- population) and respec both fire the event many times back-to-back; without
-- this we'd run the full spellbook waterfall once per fire.
function Portals:SPELLS_CHANGED()
    self:ScheduleSpellsChangedRefresh()
end

function Portals:SPELL_UPDATE_COOLDOWN()
    self:RefreshActionCooldowns()
end

-- Keep each mage travel quick-cast button pointed at the most recently completed
-- spell, including casts made from the spellbook or another action bar.
function Portals:UNIT_SPELLCAST_SUCCEEDED(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not self.isMage then
        return
    end

    local numericSpellID = getPublicNumber(spellID)
    if not numericSpellID then
        return
    end

    if findMageTravelSpell(self.knownMagePortalSpells, numericSpellID) then
        self:SelectMageTravelSpell("portal", numericSpellID)
    elseif findMageTravelSpell(self.knownMageTeleportSpells, numericSpellID) then
        self:SelectMageTravelSpell("teleport", numericSpellID)
    end
end

-- Combat lockdown can block secure attribute writes; apply queued updates here.
function Portals:PLAYER_REGEN_ENABLED()
    if self.pendingDungeonPortalCacheRebuild then
        self.pendingDungeonPortalCacheRebuild = false
        self.pendingDungeonPortalRefresh = false
        self:RebuildDungeonPortalButtons()
    elseif self.pendingDungeonPortalRefresh then
        self.pendingDungeonPortalRefresh = false
        self:RefreshDungeonPortalButtons()
    end

    if self.pendingUtilityRefresh then
        self.pendingUtilityRefresh = false
        self:LayoutTopUtilityButtons()
        self:RefreshHearthstoneButtons()
        self:RefreshToyFlyout()
        self:RefreshMageTravelButtons()
        self:RefreshActionCooldowns()
    end
end

-- Apply configured background opacity to all portal-related panels.
-- Shared styling and config refresh.
function Portals:ApplyBackdropOpacity()
    local portalsOpacity = vesperTools:GetConfiguredOpacity("portals")
    local bestKeysOpacity = vesperTools:GetConfiguredOpacity("bestKeys")

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
    if self.accountKeystoneFrame then
        self.accountKeystoneFrame:SetBackdropColor(0.07, 0.07, 0.07, bestKeysOpacity)
    end
end

-- React to global config changes.
-- If portal UI is visible, rebuild best-keys panel to refresh font + opacity.
function Portals:OnConfigChanged()
    self:ApplyBackdropOpacity()
    self:LayoutTopUtilityButtons()
    self:RefreshHearthstoneButtons()
    self:RefreshToyFlyout()
    self:RefreshMageTravelButtons()
    self:RefreshCooldownTextFonts()
    self:RefreshActionCooldowns()

    if self.VesperPortalsUI and self.VesperPortalsUI:IsShown() then
        self:RebuildProgressFrames()
    end
end

function Portals:OnAccountKeystoneChanged()
    if self.VesperPortalsUI and self.VesperPortalsUI:IsShown() then
        self:RebuildProgressFrames()
    end
end

-- Collect known mage travel spells of the requested kind ("teleport" or "portal").
-- Source strategy:
-- 1) curated spellID catalog (stable and locale-independent)
-- 2) spellbook scan by localized token (captures newly added variants)
-- Mage travel helpers.
function Portals:GetKnownMageTravelSpells(kind)
    local spellIDs = (kind == "portal") and MAGE_PORTAL_SPELL_IDS or MAGE_TELEPORT_SPELL_IDS
    local token = (kind == "portal") and PORTAL_TOKEN or TELEPORT_TOKEN
    local spells = {}
    local seen = {}

    local function tryAddSpell(spellID, explicitName)
        if not spellID or seen[spellID] then
            return
        end

        local known = vesperTools:IsSpellKnownForPlayer(spellID)
        if not known then
            return
        end

        local spellInfo = vesperTools:GetSpellInfoSafe(spellID)
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
    if vesperTools and type(vesperTools.ForEachPlayerSpellBookItem) == "function" then
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or nil
        local flyoutType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout or nil
        vesperTools:ForEachPlayerSpellBookItem(function(itemInfo)
            local itemType = itemInfo and itemInfo.itemType or nil
            local spellID = itemInfo and (itemInfo.spellID or itemInfo.actionID) or nil
            local isTravelSpellEntry = spellType == nil or itemType == nil
                or itemType == spellType or (flyoutType ~= nil and itemType == flyoutType)
            if spellID and not seen[spellID] and isTravelSpellEntry then
                local spellInfo = vesperTools:GetSpellInfoSafe(spellID)
                local spellName = spellInfo and spellInfo.name
                if type(spellName) == "string" and spellName ~= "" then
                    local lowerName = string.lower(spellName)
                    if string.find(lowerName, token, 1, true) then
                        tryAddSpell(spellID, spellName)
                    end
                end
            end
            return nil
        end)
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

    local menuTitle = (kind == "portal") and L["MAGE_PORTALS"] or L["MAGE_TELEPORTS"]
    local selectionKey = getMageTravelSelectionKey(kind)
    local selectedSpellID = self[selectionKey]
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        MenuUtil.CreateContextMenu(button, function(_, rootDescription)
            rootDescription:CreateTitle(menuTitle)
            for i = 1, #spells do
                local entry = spells[i]
                local icon = entry.icon or FALLBACK_ICON_TEXTURE
                local selectedPrefix = tonumber(entry.spellID) == tonumber(selectedSpellID) and "* " or ""
                local rowLabel = string.format("%s|T%s:16:16:0:0|t %s", selectedPrefix, icon, entry.name)
                rootDescription:CreateButton(rowLabel, function()
                    self:SelectMageTravelSpell(kind, entry.spellID)
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
    self:SelectMageTravelSpell(kind, selectedSpell and selectedSpell.spellID)
end

-- Return top-utility buttons in their visual order for horizontal layout.
-- Top utility layout and cooldown tracking.
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

    if InCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    local buttonSize = self:GetTopUtilityButtonSize()
    local frameHeight = self:GetTopUtilityFrameHeight(buttonSize)
    local buttons = self:GetTopUtilityButtons()
    local count = #buttons
    if count == 0 then
        self.topUtilityFrame:SetSize(TOP_UTILITY_PADDING * 2, frameHeight)
        return
    end

    local frameWidth = (TOP_UTILITY_PADDING * 2) + (count * buttonSize) + ((count - 1) * TOP_UTILITY_BUTTON_GAP)
    self.topUtilityFrame:SetSize(frameWidth, frameHeight)

    for i = 1, count do
        local button = buttons[i]
        button:SetSize(buttonSize, buttonSize)
        button:ClearAllPoints()
        button:SetPoint(
            "LEFT",
            self.topUtilityFrame,
            "LEFT",
            TOP_UTILITY_PADDING + ((i - 1) * (buttonSize + TOP_UTILITY_BUTTON_GAP)),
            0
        )
        self:UpdateCooldownTextFont(button)
    end
end

-- Track one action button so cooldown visuals can be refreshed centrally.
function Portals:RegisterCooldownButton(button)
    if not button or button._vesperCooldownRegistered then
        return
    end

    self.cooldownButtons = self.cooldownButtons or {}
    self.cooldownButtons[#self.cooldownButtons + 1] = button
    button._vesperCooldownRegistered = true
end

-- Keep cooldown text sized to the underlying icon.
function Portals:UpdateCooldownTextFont(button)
    if not button or not button.cooldownText then
        return
    end

    if button.cooldownFrame then
        button.cooldownFrame:SetFrameLevel((button:GetFrameLevel() or 0) + 2)
    end
    if button.cooldownTextFrame then
        button.cooldownTextFrame:SetFrameLevel((button:GetFrameLevel() or 0) + 3)
    end

    local buttonSize = tonumber(button:GetWidth()) or tonumber(button:GetHeight()) or 52
    local fontSize = math.max(10, math.floor((buttonSize * 0.32) + 0.5))
    vesperTools:ApplyConfiguredFont(button.cooldownText, fontSize, "OUTLINE")
    button.cooldownText:SetShadowColor(0, 0, 0, 1)
    button.cooldownText:SetShadowOffset(1, -1)
end

-- Reapply the selected addon font to every tracked cooldown label, even if currently hidden.
function Portals:RefreshCooldownTextFonts()
    local buttons = self.cooldownButtons or {}
    for i = 1, #buttons do
        local button = buttons[i]
        if button and button.cooldownText then
            self:UpdateCooldownTextFont(button)
        end
    end
end

function Portals:GetItemCooldownInfo(itemID)
    local numericID = tonumber(itemID)
    if not numericID or numericID <= 0 then
        return 0, 0, 0
    end

    if C_Item and C_Item.GetItemCooldown then
        local ok, start, duration, enable = callAPI(C_Item.GetItemCooldown, numericID)
        if ok then
            local publicStart = getPublicNumber(start) or 0
            local publicDuration = getPublicNumber(duration) or 0
            local publicEnabled = getPublicCooldownEnabled(enable, 0) or 0
            return publicStart, publicDuration, publicEnabled
        end
        return 0, 0, 0
    end

    if GetItemCooldown then
        local ok, start, duration, enable = callAPI(GetItemCooldown, numericID)
        if ok then
            local publicStart = getPublicNumber(start) or 0
            local publicDuration = getPublicNumber(duration) or 0
            local publicEnabled = getPublicCooldownEnabled(enable, 0) or 0
            return publicStart, publicDuration, publicEnabled
        end
        return 0, 0, 0
    end

    return 0, 0, 0
end

-- RANDOM DISCO has no fixed item icon, so resolve a real hearthstone item to query shared cooldown state.
function Portals:GetRandomDiscoCooldownItemID(button)
    local preferredID = button and tonumber(button._randomDiscoItemID) or nil
    local options = vesperTools:GetPrimaryHearthstoneOptions()
    if #options == 0 then
        options = vesperTools:GetAvailableHearthstoneOptions()
    end
    if #options == 0 then
        return preferredID
    end

    local fallbackID = preferredID
    local activePreferredID = nil
    local activeFallbackID = nil

    for i = 1, #options do
        local itemID = tonumber(options[i].itemID)
        if itemID and itemID > 0 then
            if not fallbackID then
                fallbackID = itemID
            end

            local start, duration, enabled = self:GetItemCooldownInfo(itemID)
            if enabled ~= 0 and duration > 1.5 and start > 0 then
                if preferredID and itemID == preferredID then
                    activePreferredID = itemID
                elseif not activeFallbackID then
                    activeFallbackID = itemID
                end
            end
        end
    end

    return activePreferredID or activeFallbackID or fallbackID
end

-- Reset one button back to an idle no-cooldown state.
function Portals:ClearButtonCooldown(button)
    if not button then
        return false
    end

    button._cooldownStart = nil
    button._cooldownDuration = nil
    button._cooldownModRate = nil

    if button.cooldownFrame then
        pcall(button.cooldownFrame.SetCooldown, button.cooldownFrame, 0, 0, 1)
        button.cooldownFrame:Hide()
    end

    if button.cooldownText then
        button.cooldownText:SetText("")
        button.cooldownText:Hide()
    end

    return false
end

-- Create spiral + numeric countdown visuals once for any portal-related action button.
function Portals:EnsureCooldownOverlay(button)
    if not button then
        return
    end

    if not button.cooldownFrame then
        button.cooldownFrame = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldownFrame:SetAllPoints(button)
    end

    if button.cooldownFrame.SetDrawBling then
        button.cooldownFrame:SetDrawBling(false)
    end
    if button.cooldownFrame.SetDrawEdge then
        button.cooldownFrame:SetDrawEdge(false)
    end
    if button.cooldownFrame.SetHideCountdownNumbers then
        button.cooldownFrame:SetHideCountdownNumbers(true)
    end
    if button.cooldownFrame.SetSwipeColor then
        button.cooldownFrame:SetSwipeColor(0, 0, 0, 0.75)
    end
    button.cooldownFrame:Hide()

    if not button.cooldownTextFrame then
        button.cooldownTextFrame = CreateFrame("Frame", nil, button)
        button.cooldownTextFrame:SetAllPoints(button)
        button.cooldownTextFrame:EnableMouse(false)
    end

    if not button.cooldownText then
        button.cooldownText = button.cooldownTextFrame:CreateFontString(nil, "OVERLAY")
        button.cooldownText:SetPoint("CENTER", button.cooldownTextFrame, "CENTER", 0, 0)
        button.cooldownText:SetJustifyH("CENTER")
        button.cooldownText:SetJustifyV("MIDDLE")
        button.cooldownText:Hide()
    end

    self:UpdateCooldownTextFont(button)
    self:RegisterCooldownButton(button)
    self:ClearButtonCooldown(button)
end

-- Assign the source queried for this button's cooldown visuals.
function Portals:SetButtonCooldownSource(button, sourceType, sourceID)
    if not button then
        return
    end

    local normalizedType = (sourceType == "spell" or sourceType == "item") and sourceType or nil
    local normalizedID = tonumber(sourceID)

    button._cooldownSourceType = normalizedType
    button._cooldownSourceID = (normalizedType and normalizedID and normalizedID > 0) and normalizedID or nil

    if not button._cooldownSourceType or not button._cooldownSourceID then
        self:ClearButtonCooldown(button)
    end
end

-- Resolve the active cooldown tuple for one tracked button.
function Portals:GetButtonCooldownInfo(button)
    if not button then
        return 0, 0, 0, 1
    end

    local sourceType = button._cooldownSourceType
    local sourceID = tonumber(button._cooldownSourceID)
    if not sourceType or not sourceID or sourceID <= 0 then
        return 0, 0, 0, 1
    end

    if sourceType == "spell" then
        -- Prefer the table API because DurationObject:IsZero() may return a secret
        -- boolean on Midnight and cannot be tested in Lua.
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, info = callAPI(C_Spell.GetSpellCooldown, sourceID)
            if ok and type(info) == "table" then
                local start = getPublicNumber(info.startTime)
                local duration = getPublicNumber(info.duration)
                local enabled = getPublicCooldownEnabled(info.isEnabled, 0)
                local modRate = getPublicNumber(info.modRate) or 1
                if start and duration and enabled ~= nil then
                    return start, duration, enabled, modRate
                end
            end
        end
        -- Mainline 11.1+: DurationObject fallback. Never branch on IsZero().
        if C_Spell and C_Spell.GetSpellCooldownDuration then
            local ok, dur = callAPI(C_Spell.GetSpellCooldownDuration, sourceID, true)
            if ok and dur ~= nil then
                local start = getDurationObjectNumber(dur, "GetStartTime")
                local duration = getDurationObjectNumber(dur, "GetTotalDuration")
                if start and duration then
                    return start, duration, 1, 1
                end
            end
            return 0, 0, 0, 1
        end
        -- Legacy global (pre-11.x)
        if GetSpellCooldown then
            local ok, start, duration, enabled, modRate = callAPI(GetSpellCooldown, sourceID)
            if ok then
                return getPublicNumber(start) or 0,
                    getPublicNumber(duration) or 0,
                    getPublicCooldownEnabled(enabled, 0) or 0,
                    getPublicNumber(modRate) or 1
            end
        end
    elseif sourceType == "item" then
        local start, duration, enabled = self:GetItemCooldownInfo(sourceID)
        return start, duration, enabled, 1
    end

    return 0, 0, 0, 1
end

-- Update the numeric countdown text for one active cooldown.
function Portals:UpdateButtonCooldownText(button, now)
    if not button or not button.cooldownText then
        return false
    end

    local start = tonumber(button._cooldownStart)
    local duration = tonumber(button._cooldownDuration)
    if not start or not duration or duration <= 0 then
        return self:ClearButtonCooldown(button)
    end

    local modRate = tonumber(button._cooldownModRate) or 1
    if modRate <= 0 then
        modRate = 1
    end

    local remaining = ((start + duration) - (now or GetTime())) / modRate
    if remaining <= 0.05 then
        return self:ClearButtonCooldown(button)
    end

    local label = formatCooldownRemaining(remaining)
    if label == "" then
        button.cooldownText:SetText("")
        button.cooldownText:Hide()
        return true
    end

    local r, g, b = 1, 1, 1
    if remaining < 10 then
        r, g, b = 1, 0.35, 0.35
    elseif remaining < 60 then
        r, g, b = 1, 0.82, 0.25
    end

    button.cooldownText:SetTextColor(r, g, b, 1)
    button.cooldownText:SetText(label)
    button.cooldownText:Show()
    return true
end

-- Query fresh spell/item cooldown data and drive the swirl for one tracked button.
function Portals:RefreshButtonCooldown(button, now)
    if not button or not button.cooldownFrame then
        return false
    end

    self:UpdateCooldownTextFont(button)

    local start, duration, enabled, modRate = self:GetButtonCooldownInfo(button)
    if enabled == 0 or duration <= 1.5 or start <= 0 then
        return self:ClearButtonCooldown(button)
    end

    button._cooldownStart = start
    button._cooldownDuration = duration
    button._cooldownModRate = (tonumber(modRate) and tonumber(modRate) > 0) and tonumber(modRate) or 1
    button.cooldownFrame:Show()

    local ok = pcall(button.cooldownFrame.SetCooldown, button.cooldownFrame, start, duration, button._cooldownModRate)
    if not ok then
        pcall(button.cooldownFrame.SetCooldown, button.cooldownFrame, start, duration)
    end

    return self:UpdateButtonCooldownText(button, now)
end

-- Periodically update numeric cooldown text while at least one action is on cooldown.
function Portals:OnCooldownUpdate(elapsed)
    if not self.VesperPortalsUI or not self.VesperPortalsUI:IsShown() then
        return
    end

    self.cooldownUpdateElapsed = (tonumber(self.cooldownUpdateElapsed) or 0) + (tonumber(elapsed) or 0)
    if self.cooldownUpdateElapsed < COOLDOWN_TEXT_UPDATE_INTERVAL then
        return
    end
    self.cooldownUpdateElapsed = 0

    local hasActiveCooldown = false
    local now = GetTime()
    for i = 1, #(self.cooldownButtons or {}) do
        local button = self.cooldownButtons[i]
        if button and button:IsShown() and button._cooldownStart then
            if self:UpdateButtonCooldownText(button, now) then
                hasActiveCooldown = true
            end
        end
    end

    if not hasActiveCooldown then
        self.VesperPortalsUI:SetScript("OnUpdate", nil)
    end
end

-- Refresh all tracked portal/utility button cooldowns from current game state.
function Portals:RefreshActionCooldowns()
    local buttons = self.cooldownButtons
    if type(buttons) ~= "table" or #buttons == 0 then
        return
    end

    local hasActiveCooldown = false
    local now = GetTime()
    for i = 1, #buttons do
        local button = buttons[i]
        if button and button.cooldownFrame then
            if button:IsShown() then
                if self:RefreshButtonCooldown(button, now) then
                    hasActiveCooldown = true
                end
            else
                if button.cooldownText then
                    button.cooldownText:Hide()
                end
            end
        end
    end

    if self.VesperPortalsUI and self.VesperPortalsUI:IsShown() and hasActiveCooldown then
        self.cooldownUpdateElapsed = 0
        self.VesperPortalsUI:SetScript("OnUpdate", function(_, elapsed)
            self:OnCooldownUpdate(elapsed)
        end)
    elseif self.VesperPortalsUI then
        self.VesperPortalsUI:SetScript("OnUpdate", nil)
    end
end

function Portals:ScheduleDungeonPortalRebuild(delaySeconds)
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        self:RebuildDungeonPortalButtons()
        return
    end

    local delay = math.max(0, tonumber(delaySeconds) or 0)
    local now = type(GetTime) == "function" and GetTime() or 0
    local dueTime = now + delay
    if self.dungeonPortalRebuildTimer then
        if self.dungeonPortalRebuildDueTime and self.dungeonPortalRebuildDueTime <= dueTime then
            return
        end
        if type(self.dungeonPortalRebuildTimer.Cancel) == "function" then
            self.dungeonPortalRebuildTimer:Cancel()
        end
        self.dungeonPortalRebuildTimer = nil
        self.dungeonPortalRebuildDueTime = nil
    end

    self.dungeonPortalRebuildDueTime = dueTime
    self.dungeonPortalRebuildTimer = C_Timer.NewTimer(delay, function()
        self.dungeonPortalRebuildTimer = nil
        self.dungeonPortalRebuildDueTime = nil
        if self and type(self.RebuildDungeonPortalButtons) == "function" then
            self:RebuildDungeonPortalButtons()
        end
    end)
end

-- Single-shot debounce for SPELLS_CHANGED bursts. Drops dozens of redundant
-- spellbook scans during login/spec switches into one refresh per quiet window.
function Portals:ScheduleSpellsChangedRefresh()
    if self.spellsChangedRefreshTimer then
        return
    end
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
        -- No timer service: degrade to immediate refresh.
        self:RefreshDungeonPortalButtons()
        self:RefreshMageTravelButtons()
        self:RefreshActionCooldowns()
        return
    end

    self.spellsChangedRefreshTimer = C_Timer.NewTimer(SPELLS_CHANGED_COALESCE_DELAY, function()
        self.spellsChangedRefreshTimer = nil
        if not self then
            return
        end
        self:RefreshDungeonPortalButtons()
        self:RefreshMageTravelButtons()
        self:RefreshActionCooldowns()
    end)
end

-- Periodic safety net for any state transition we'd otherwise miss because the
-- corresponding event didn't fire (TOYS_UPDATED dropped, Blizzard sometimes
-- delivering SPELLS_CHANGED late on zone change, etc.). Cheap by design: just
-- replays the same refresh paths the events use. Skipped during combat;
-- PLAYER_REGEN_ENABLED already drains pending refreshes on its own.
function Portals:StartSanitySweepTicker()
    if self.sanitySweepTicker then
        return
    end
    if not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end

    self.sanitySweepTicker = C_Timer.NewTicker(SANITY_SWEEP_INTERVAL, function()
        if not self then
            return
        end
        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            return
        end
        if vesperTools and type(vesperTools.InvalidateHearthstoneCatalog) == "function" then
            vesperTools:InvalidateHearthstoneCatalog()
        end
        self:RefreshDungeonPortalButtons()
        self:RefreshMageTravelButtons()
        self:RefreshHearthstoneButtons()
        self:RefreshToyFlyout()
        self:RefreshActionCooldowns()
    end)
end

function Portals:ResetDungeonPortalButton(button)
    if not button then
        return false
    end

    if isInCombatLockdown() then
        self.pendingDungeonPortalCacheRebuild = true
        return false
    end

    button.portalMapID = nil
    button.portalSpellID = nil
    button.portalSpellName = nil
    button.dungeonName = nil
    button.portalUnlocked = nil
    button:EnableMouse(false)
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)
    self:SetButtonCooldownSource(button, nil, nil)
    self:ClearButtonCooldown(button)
    button:Hide()
    return true
end

function Portals:ClearDungeonPortalCache()
    if isInCombatLockdown() then
        self.pendingDungeonPortalCacheRebuild = true
        return false
    end

    self.portalButtonPool = self.portalButtonPool or {}
    for index = 1, #(self.portalButtons or {}) do
        local button = self.portalButtons[index]
        if button and not self.portalButtonPool[index] then
            self.portalButtonPool[index] = button
        end
    end

    for index = 1, #self.portalButtonPool do
        self:ResetDungeonPortalButton(self.portalButtonPool[index])
    end

    self.portalButtons = {}
    self:RefreshActionCooldowns()
    return true
end

function Portals:AcquireDungeonPortalButton(index)
    if isInCombatLockdown() then
        self.pendingDungeonPortalCacheRebuild = true
        return nil
    end

    self.portalButtonPool = self.portalButtonPool or {}
    local button = self.portalButtonPool[index]
    if button then
        return button
    end

    -- Prefixed so we don't compete with any other addon's globals named
    -- PortalButton<n>. Fallback to a nameless frame if even our prefixed name
    -- happens to be taken (only realistic if someone reuses our prefix).
    local buttonName = "vesperToolsPortalButton" .. tostring(index)
    if _G[buttonName] then
        buttonName = nil
    end

    button = CreateFrame(
        "Button",
        buttonName,
        self.VesperPortalsUI,
        "InsecureActionButtonTemplate"
    )
    button:SetSize(52, 52)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    background:SetColorTexture(0, 0, 0, 0.8)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 0, 0.4)
    button:SetHighlightTexture(highlight)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    button.icon = icon

    self:EnsureCooldownOverlay(button)
    button:RegisterForClicks("AnyUp", "AnyDown")
    self.portalButtonPool[index] = button
    return button
end

function Portals:GetCurrentSeasonDungeonRecords(dataHandle, shouldWarnMissing)
    local curSeason = getChallengeModeMapTableSafe()
    if type(curSeason) ~= "table" then
        curSeason = {}
    end

    if shouldWarnMissing then
        self:WarnMissingSeasonDungeonMetadata(curSeason, dataHandle)
    end

    local curSeasonDungs = {}
    if not dataHandle then
        return curSeasonDungs, curSeason
    end

    for _, id in ipairs(curSeason) do
        local lookupID = tonumber(id) or id
        local dungInfo = buildCurrentSeasonDungeonRecord(dataHandle, lookupID)
        if dungInfo then
            curSeasonDungs[#curSeasonDungs + 1] = dungInfo
        end
    end

    return curSeasonDungs, curSeason
end

function Portals:GetPortalButtonMapSignature()
    local buttons = self.portalButtons
    if type(buttons) ~= "table" or #buttons == 0 then
        return nil
    end

    local parts = {}
    for index = 1, #buttons do
        local mapID = buttons[index] and tonumber(buttons[index].portalMapID) or nil
        if mapID then
            parts[#parts + 1] = tostring(mapID)
        end
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, ",")
end

function Portals:GetCurrentSeasonDungeonMapSignature(dataHandle)
    if not dataHandle or type(dataHandle.GetDungeonsByMapID) ~= "function" then
        return nil
    end

    local curSeason = getChallengeModeMapTableSafe()
    if type(curSeason) ~= "table" or #curSeason == 0 then
        return nil
    end

    local parts = {}
    for _, id in ipairs(curSeason) do
        local lookupID = tonumber(id) or id
        local entries = getDungeonCatalogEntries(dataHandle, lookupID)
        if type(entries) == "table" and #entries > 0 then
            parts[#parts + 1] = tostring(lookupID)
        end
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, ",")
end

function Portals:ShouldRebuildDungeonPortalButtons()
    local dataHandle = vesperTools:GetModule("DataHandle", true)
    if not dataHandle then
        return false
    end

    local desiredSignature = self:GetCurrentSeasonDungeonMapSignature(dataHandle)
    if not desiredSignature then
        return false
    end

    return self:GetPortalButtonMapSignature() ~= desiredSignature
end

function Portals:ResolveDungeonPortalState(mapID, options)
    local normalizedMapID = tonumber(mapID) or mapID
    if not normalizedMapID then
        return nil
    end

    options = type(options) == "table" and options or {}
    local dataHandle = vesperTools:GetModule("DataHandle", true)
    local entries, resolvedDungeonName = getDungeonCatalogEntries(dataHandle, normalizedMapID, options.dungeonName)
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end

    local spellOptions = {
        allowSessionCache = options.allowSessionCache == true,
        rememberSession = options.rememberSession == true,
        sessionScope = "dungeonPortal",
    }

    local fallbackState = nil
    for i = 1, #entries do
        local entry = entries[i]
        local spellID = entry and tonumber(entry.spellID) or nil
        if spellID then
            local spellInfo = vesperTools:GetSpellInfoSafe(spellID)
            local state = {
                mapID = normalizedMapID,
                catalogMapID = entry.mapID,
                dungeonName = resolvedDungeonName or entry.dungeonName,
                spellID = spellID,
                spellName = spellInfo and spellInfo.name or nil,
                icon = normalizeTextureToken(spellInfo and (spellInfo.iconID or spellInfo.originalIconID))
                    or FALLBACK_ICON_TEXTURE,
                known = false,
                source = "none",
                entries = entries,
            }

            if not fallbackState then
                fallbackState = state
            end

            local known, source = vesperTools:GetPlayerSpellKnownState(spellID, spellOptions)
            if known then
                state.known = true
                state.source = source or "unknown"
                return state
            end
            state.source = source or "none"
        end
    end

    return fallbackState
end

function Portals:RebuildDungeonPortalButtons()
    if isInCombatLockdown() then
        self.pendingDungeonPortalCacheRebuild = true
        return false
    end

    if not self.VesperPortalsUI then
        return false
    end

    local DataHandle = vesperTools:GetModule("DataHandle", true)
    if not DataHandle then
        vesperTools:Print(L["PORTALS_DATAHANDLE_MODULE_NOT_FOUND"])
        return false
    end

    local curSeasonDungs, curSeason = self:GetCurrentSeasonDungeonRecords(DataHandle, true)
    if type(curSeason) ~= "table" or #curSeason == 0 then
        return false
    end

    if not self:ClearDungeonPortalCache() then
        return false
    end

    for index, dungInfo in ipairs(curSeasonDungs) do
        local resolved = self:ResolveDungeonPortalState(dungInfo.mapID, {
            allowSessionCache = true,
            rememberSession = true,
            dungeonName = dungInfo.dungeonName,
        })
        local spellInfo = not resolved and vesperTools:GetSpellInfoSafe(dungInfo.spellID) or nil
        local spellName = resolved and resolved.spellName or (spellInfo and spellInfo.name)
        local iconFileID = resolved and resolved.icon
            or normalizeTextureToken(spellInfo and (spellInfo.iconID or spellInfo.originalIconID))
            or FALLBACK_ICON_TEXTURE
        local button = self:AcquireDungeonPortalButton(index)
        if not button then
            return false
        end
        local col = (index - 1) % 4
        local row = math.floor((index - 1) / 4)

        button:SetParent(self.VesperPortalsUI)
        button:SetSize(52, 52)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.VesperPortalsUI, "TOPLEFT", 20 + col * 70, -20 - row * 70)

        if button.icon then
            button.icon:SetTexture(iconFileID or "Interface\\ICONS\\INV_Misc_QuestionMark")
            button.icon:SetDesaturated(false)
            button.icon:SetAlpha(1)
        end

        button.dungeonName = (resolved and resolved.dungeonName) or dungInfo.dungeonName
        button.portalMapID = dungInfo.mapID
        button.portalSpellID = (resolved and resolved.spellID) or dungInfo.spellID
        button.portalSpellName = spellName
        self.portalButtons[#self.portalButtons + 1] = button
        button:SetScript("OnEnter", function(portalButton)
            GameTooltip:SetOwner(portalButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(portalButton.dungeonName, 1, 1, 1)
            if portalButton.portalUnlocked == false then
                GameTooltip:AddLine(L["PORTAL_NOT_UNLOCKED_YET"], 1, 0.2, 0.2)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:Show()
    end

    return self:RefreshDungeonPortalButtons({ skipRebuildCheck = true })
end

function Portals:ApplyDungeonPortalButtonState(button)
    if not button then
        return false
    end

    if isInCombatLockdown() then
        self.pendingDungeonPortalRefresh = true
        return false
    end

    local mapID = tonumber(button.portalMapID)
    local resolved = nil
    if mapID then
        resolved = self:ResolveDungeonPortalState(mapID, {
            allowSessionCache = true,
            rememberSession = true,
            dungeonName = button.dungeonName,
        })
        if resolved and tonumber(resolved.spellID) then
            button.portalSpellID = resolved.spellID
            button.portalSpellName = resolved.spellName
            button.dungeonName = resolved.dungeonName or button.dungeonName
        end
    end

    local spellID = tonumber(button.portalSpellID)
    if not spellID then
        button.portalUnlocked = false
        button:EnableMouse(true)
        self:SetButtonCooldownSource(button, nil, nil)
        return false
    end

    local spellInfo = nil
    if not resolved then
        spellInfo = vesperTools:GetSpellInfoSafe(spellID)
    end
    local spellName = (spellInfo and spellInfo.name) or button.portalSpellName
    local iconFileID = resolved and resolved.icon
        or normalizeTextureToken(spellInfo and (spellInfo.iconID or spellInfo.originalIconID))
    -- The known check stands on its own. Previously it was gated behind
    -- spellName, which meant any GetSpellInfo cache miss (common right after
    -- login) reported owned portals as locked.
    local known
    if resolved then
        known = resolved.known and true or false
    else
        known = vesperTools:IsSpellKnownForPlayer(spellID, {
            allowSessionCache = true,
            rememberSession = true,
            sessionScope = "dungeonPortal",
        })
    end
    -- Secure cast attribute still needs a name; if we don't have one yet, the
    -- button stays visually-known but click-disabled until the next refresh.
    local castName = spellName

    button.portalSpellName = spellName
    button.portalUnlocked = known
    button:EnableMouse(true)
    if button.icon then
        if iconFileID then
            button.icon:SetTexture(iconFileID)
        end
        button.icon:SetDesaturated(not known)
        button.icon:SetAlpha(known and 1 or 0.5)
    end

    if known and castName then
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", castName)
        self:SetButtonCooldownSource(button, "spell", spellID)
    else
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
        self:SetButtonCooldownSource(button, nil, nil)
    end

    return known
end

function Portals:RefreshDungeonPortalButtons(options)
    options = type(options) == "table" and options or {}

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        if not options.skipRebuildCheck and self:ShouldRebuildDungeonPortalButtons() then
            self.pendingDungeonPortalCacheRebuild = true
        else
            self.pendingDungeonPortalRefresh = true
        end
        return false
    end

    if not options.skipRebuildCheck and self:ShouldRebuildDungeonPortalButtons() then
        return self:RebuildDungeonPortalButtons()
    end

    local buttons = self.portalButtons
    if type(buttons) ~= "table" or #buttons == 0 then
        return false
    end

    local knownCount = 0
    for index = 1, #buttons do
        if self:ApplyDungeonPortalButtonState(buttons[index]) then
            knownCount = knownCount + 1
        end
    end

    self:RefreshActionCooldowns()
    vesperTools:SendMessage("VESPERTOOLS_PORTAL_SPELLS_REFRESHED", knownCount, #buttons)
    return true, knownCount, #buttons
end

function Portals:ForceRefreshPortalAvailability(options)
    local refreshed
    if type(options) == "table" and options.clearCache then
        refreshed = self:RebuildDungeonPortalButtons()
    else
        refreshed = self:RefreshDungeonPortalButtons()
    end
    self:RefreshMageTravelButtons()
    self:RefreshActionCooldowns()
    return refreshed
end

function Portals:DebugDumpDungeonPortalSpells()
    local dataHandle = vesperTools:GetModule("DataHandle", true)
    if not dataHandle then
        vesperTools:Print(L["PORTALS_DATAHANDLE_MODULE_NOT_FOUND"])
        return
    end

    local curSeason = getChallengeModeMapTableSafe()
    if #curSeason == 0 then
        vesperTools:Print("No current-season dungeon portal map table is available.")
        return
    end

    vesperTools:Print("Current character dungeon portal spell check (raw probes; debug does not update session cache):")

    for index = 1, #curSeason do
        local mapID = tonumber(curSeason[index]) or curSeason[index]
        local entries, currentDungeonName = getDungeonCatalogEntries(dataHandle, mapID)
        if type(entries) == "table" and #entries > 0 then
            -- Iterate every catalog entry for this mapID so users with
            -- multi-variant dungeons (e.g. Skyreach Midnight + Warlords) can
            -- see which alternate spellIDs were tried and which API path
            -- detected each one. The per-mapID summary line below mirrors
            -- what the live UI uses.
            local dungeonLabel = currentDungeonName or entries[1].dungeonName or tostring(mapID)
            for _, dungInfo in ipairs(entries) do
                local spellInfo = vesperTools:GetSpellInfoSafe(dungInfo.spellID)
                local spellName = (spellInfo and spellInfo.name) or tostring(dungInfo.spellID)
                local known, source = vesperTools:GetPlayerSpellKnownState(dungInfo.spellID, {
                    allowSessionCache = false,
                    rememberSession = false,
                    sessionScope = "dungeonPortal",
                })
                local cachedSource = vesperTools:GetSessionKnownSpellSource(dungInfo.spellID, "dungeonPortal")
                vesperTools:Print(string.format(
                    "  %s (%d): %s [%d] = %s via %s%s",
                    dungInfo.dungeonName or dungeonLabel,
                    mapID,
                    spellName,
                    dungInfo.spellID,
                    known and "known" or "missing",
                    source or "unknown",
                    cachedSource and ("; cached " .. cachedSource) or ""
                ))
            end

            local resolved = self:ResolveDungeonPortalState(mapID, {
                allowSessionCache = true,
                rememberSession = false,
                dungeonName = dungeonLabel,
            })
            vesperTools:Print(string.format(
                "%s (%d): UI uses %s",
                dungeonLabel,
                mapID,
                (resolved and resolved.known) and ("spellID " .. tostring(resolved.spellID)) or "no known variant"
            ))
        end
    end
end

-- Build the hidden flyout frame that expands upward from the toys utility button.
-- Toy flyout creation and layout.
function Portals:CreateToyFlyoutFrame()
    if self.toyFlyoutFrame or not self.topUtilityFrame then
        return
    end

    local buttonSize = self:GetTopUtilityButtonSize()
    self.toyFlyoutFrame = CreateFrame("Frame", "vesperToolsToyFlyoutFrame", self.topUtilityFrame, "BackdropTemplate")
    self.toyFlyoutFrame:EnableMouse(true)
    self.toyFlyoutFrame:SetSize(buttonSize + (TOY_FLYOUT_PADDING * 2), buttonSize + (TOY_FLYOUT_PADDING * 2))
    vesperTools:ApplyAddonWindowLayer(self.toyFlyoutFrame, (self.topUtilityFrame:GetFrameLevel() or 0) + 2)
    vesperTools:ApplyRoundedWindowBackdrop(self.toyFlyoutFrame)
    self.toyFlyoutFrame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("portals"))
    if self.classColor then
        self.toyFlyoutFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)
    end
    self.toyFlyoutFrame:Hide()

    -- Keep flyout visible while hovered and hide once cursor leaves both anchor and flyout.
    self.toyFlyoutFrame:SetScript("OnEnter", function()
        self:ShowToyFlyout()
    end)
    self.toyFlyoutFrame:SetScript("OnLeave", function()
        self:ScheduleToyFlyoutHideCheck()
    end)
end

-- Return screen-safe toy flyout layout so tall lists wrap into columns before going off-screen.
function Portals:GetToyFlyoutLayout(toyCount, buttonSize)
    local resolvedButtonSize = tonumber(buttonSize) or self:GetTopUtilityButtonSize()
    local totalToys = math.max(0, math.floor(tonumber(toyCount) or 0))
    if totalToys <= 0 then
        return {
            rowsPerColumn = 1,
            columns = 1,
            width = resolvedButtonSize + (TOY_FLYOUT_PADDING * 2),
            height = resolvedButtonSize + (TOY_FLYOUT_PADDING * 2),
        }
    end

    local uiTop = UIParent and (UIParent:GetTop() or UIParent:GetHeight()) or 0
    local buttonTop = self.toyFlyoutButton and self.toyFlyoutButton:GetTop()
    local availableHeight = nil
    if uiTop and buttonTop then
        availableHeight = uiTop - buttonTop - TOY_FLYOUT_ANCHOR_Y_OFFSET - TOY_FLYOUT_SCREEN_MARGIN
    end

    local rowStride = resolvedButtonSize + TOY_FLYOUT_BUTTON_GAP
    local minHeight = (TOY_FLYOUT_PADDING * 2) + resolvedButtonSize
    local rowsPerColumn
    if availableHeight and availableHeight > 0 then
        rowsPerColumn = math.floor((availableHeight - (TOY_FLYOUT_PADDING * 2) + TOY_FLYOUT_BUTTON_GAP) / rowStride)
    end
    rowsPerColumn = math.max(1, math.floor(tonumber(rowsPerColumn) or totalToys))

    local columns = math.max(1, math.ceil(totalToys / rowsPerColumn))
    local tallestColumnRows = math.min(totalToys, rowsPerColumn)
    local width = (TOY_FLYOUT_PADDING * 2)
        + (columns * resolvedButtonSize)
        + ((columns - 1) * TOY_FLYOUT_COLUMN_GAP)
    local height = (TOY_FLYOUT_PADDING * 2)
        + (tallestColumnRows * resolvedButtonSize)
        + ((tallestColumnRows - 1) * TOY_FLYOUT_BUTTON_GAP)

    if height < minHeight then
        height = minHeight
    end

    return {
        rowsPerColumn = rowsPerColumn,
        columns = columns,
        width = width,
        height = height,
    }
end

-- Anchor the flyout above the toy button, then clamp it back onto the visible screen if needed.
function Portals:PositionToyFlyoutFrame(width, height)
    if not self.toyFlyoutFrame or not self.toyFlyoutButton then
        return
    end

    local resolvedWidth = math.max(0, tonumber(width) or 0)
    local resolvedHeight = math.max(0, tonumber(height) or 0)

    local uiLeft = UIParent and (UIParent:GetLeft() or 0) or 0
    local uiBottom = UIParent and (UIParent:GetBottom() or 0) or 0
    local uiRight = UIParent and (UIParent:GetRight() or (uiLeft + (UIParent:GetWidth() or 0))) or resolvedWidth
    local uiTop = UIParent and (UIParent:GetTop() or (uiBottom + (UIParent:GetHeight() or 0))) or resolvedHeight

    local buttonLeft = self.toyFlyoutButton:GetLeft()
    local buttonWidth = self.toyFlyoutButton:GetWidth() or 0
    local desiredLeft = buttonLeft
        and (buttonLeft + (buttonWidth / 2) - (resolvedWidth / 2))
        or uiLeft
    local desiredBottom = (self.toyFlyoutButton:GetTop() or uiBottom) + TOY_FLYOUT_ANCHOR_Y_OFFSET

    local minLeft = uiLeft + TOY_FLYOUT_SCREEN_MARGIN
    local minBottom = uiBottom + TOY_FLYOUT_SCREEN_MARGIN
    local maxRight = uiRight - TOY_FLYOUT_SCREEN_MARGIN
    local maxTop = uiTop - TOY_FLYOUT_SCREEN_MARGIN

    if desiredLeft + resolvedWidth > maxRight then
        desiredLeft = maxRight - resolvedWidth
    end
    if desiredLeft < minLeft then
        desiredLeft = minLeft
    end

    if desiredBottom + resolvedHeight > maxTop then
        desiredBottom = maxTop - resolvedHeight
    end
    if desiredBottom < minBottom then
        desiredBottom = minBottom
    end

    self.toyFlyoutFrame:ClearAllPoints()
    self.toyFlyoutFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", desiredLeft, desiredBottom)
end

-- Hide the toy flyout safely.
function Portals:HideToyFlyout()
    if isInCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

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
    if isInCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end
    if not self.toyFlyoutButton or not self.toyFlyoutButton._isAvailable then
        return
    end
    self._toyFlyoutHideToken = (tonumber(self._toyFlyoutHideToken) or 0) + 1
    self:PositionToyFlyoutFrame(self.toyFlyoutFrame:GetWidth(), self.toyFlyoutFrame:GetHeight())
    self.toyFlyoutFrame:Show()
end

-- Check whether the cursor is still over toy flyout anchor or flyout content.
function Portals:IsToyFlyoutMouseActive()
    if not self.toyFlyoutButton or not self.toyFlyoutFrame then
        return false
    end
    -- Use the native region API so hover detection works without the old global.
    -- The panel rectangle also covers padding and gaps between toy buttons.
    return (self.toyFlyoutButton:IsShown() and self.toyFlyoutButton:IsMouseOver())
        or (self.toyFlyoutFrame:IsShown() and self.toyFlyoutFrame:IsMouseOver())
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

    C_Timer.After(TOY_FLYOUT_HIDE_DELAY, function()
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
    local buttonSize = self:GetTopUtilityButtonSize()
    button:SetSize(buttonSize, buttonSize)
    button:RegisterForClicks("AnyUp", "AnyDown")
    -- Child buttons receive hover events instead of the panel beneath them.
    -- Retain their tooltip handlers while taking over the pending hide timer.
    button:HookScript("OnEnter", function()
        self:ShowToyFlyout()
    end)
    button:HookScript("OnLeave", function()
        self:ScheduleToyFlyoutHideCheck()
    end)
    return button
end

-- Refresh the flyout button icon + flyout toy actions from whitelist and ownership.
function Portals:RefreshToyFlyout()
    if not self.toyFlyoutButton then
        return
    end

    local toys = vesperTools:GetWhitelistedOwnedToyOptions()
    local hasToys = type(toys) == "table" and #toys > 0
    local buttonSize = self:GetTopUtilityButtonSize()

    if hasToys then
        self.toyFlyoutButton.icon:SetTexture(toys[1].icon or TOY_FLYOUT_BUTTON_ICON)
        self.toyFlyoutButton.icon:SetDesaturated(false)
        self.toyFlyoutButton.icon:SetAlpha(1)
        self.toyFlyoutButton._isAvailable = true
        self.toyFlyoutButton._displayName = L["UTILITY_TOYS"]
        self.toyFlyoutButton._tooltipHint = L["UTILITY_TOYS_HINT"]
        self.toyFlyoutButton._unavailableText = L["NO_WHITELISTED_TOYS"]
        self.toyFlyoutButton:EnableMouse(true)
    else
        self.toyFlyoutButton.icon:SetTexture(TOY_FLYOUT_BUTTON_ICON)
        self.toyFlyoutButton.icon:SetDesaturated(true)
        self.toyFlyoutButton.icon:SetAlpha(0.45)
        self.toyFlyoutButton._isAvailable = false
        self.toyFlyoutButton._displayName = L["UTILITY_TOYS"]
        self.toyFlyoutButton._tooltipHint = L["UTILITY_TOYS_HINT"]
        self.toyFlyoutButton._unavailableText = L["NO_WHITELISTED_TOYS"]
        self.toyFlyoutButton:EnableMouse(true)
        self:HideToyFlyout()
    end

    self:CreateToyFlyoutFrame()
    if not self.toyFlyoutFrame then
        return
    end

    if InCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    for i = 1, #self.toyFlyoutButtons do
        self.toyFlyoutButtons[i]:SetSize(buttonSize, buttonSize)
        self:UpdateCooldownTextFont(self.toyFlyoutButtons[i])
        self:SetButtonCooldownSource(self.toyFlyoutButtons[i], nil, nil)
        self.toyFlyoutButtons[i]:Hide()
    end

    if not hasToys then
        local emptySize = buttonSize + (TOY_FLYOUT_PADDING * 2)
        self.toyFlyoutFrame:SetSize(emptySize, emptySize)
        self:PositionToyFlyoutFrame(emptySize, emptySize)
        return
    end

    local layout = self:GetToyFlyoutLayout(#toys, buttonSize)
    self.toyFlyoutFrame:SetSize(layout.width, layout.height)
    self:PositionToyFlyoutFrame(layout.width, layout.height)

    for i = 1, #toys do
        local option = toys[i]
        local button = self.toyFlyoutButtons[i]
        if not button then
            button = self:CreateToyFlyoutActionButton(self.toyFlyoutFrame)
            self.toyFlyoutButtons[i] = button
        end

        local zeroIndex = i - 1
        local column = math.floor(zeroIndex / layout.rowsPerColumn)
        local row = zeroIndex % layout.rowsPerColumn

        button:ClearAllPoints()
        button:SetPoint(
            "BOTTOMLEFT",
            self.toyFlyoutFrame,
            "BOTTOMLEFT",
            TOY_FLYOUT_PADDING + (column * (buttonSize + TOY_FLYOUT_COLUMN_GAP)),
            TOY_FLYOUT_PADDING + (row * (buttonSize + TOY_FLYOUT_BUTTON_GAP))
        )

        button.icon:SetTexture(option.icon or FALLBACK_ICON_TEXTURE)
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)

        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", "/use item:" .. tostring(option.itemID))
        button._isAvailable = true
        button._displayName = option.name or string.format(L["ITEM_FALLBACK_FMT"], tostring(option.itemID))
        button._tooltipHint = L["UTILITY_TOOLTIP_USE"]
        button._unavailableText = L["UTILITY_TOOLTIP_UNAVAILABLE"]
        self:SetButtonCooldownSource(button, "item", option.itemID)
        button:Show()
    end

    self:RefreshActionCooldowns()
end

-- Build one icon-only hearthstone action button in the same visual style as Great Vault.
-- Utility buttons and hearthstone action wiring.
function Portals:CreateTopUtilityButton(parent, templateName)
    -- Use SecureActionButtonTemplate directly to avoid ActionButton-style scripts
    -- from template stacks that can hide custom icon textures.
    local button
    if type(templateName) == "string" and templateName ~= "" and templateName ~= "Button" then
        button = CreateFrame("Button", nil, parent, templateName)
    else
        button = CreateFrame("Button", nil, parent)
    end
    local buttonSize = self:GetTopUtilityButtonSize()
    button:SetSize(buttonSize, buttonSize)
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
    self:EnsureCooldownOverlay(button)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        if selfButton._isAvailable then
            GameTooltip:SetText(selfButton._displayName or L["UTILITY_FALLBACK"], 1, 1, 1)
            GameTooltip:AddLine(selfButton._tooltipHint or L["UTILITY_TOOLTIP_USE"], 0.85, 0.85, 0.85)
        else
            GameTooltip:SetText(selfButton._unavailableText or L["UTILITY_TOOLTIP_UNAVAILABLE"], 1, 0.4, 0.4)
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

    local buttonSize = self:GetTopUtilityButtonSize()
    local frameHeight = self:GetTopUtilityFrameHeight(buttonSize)
    self.topUtilityFrame = CreateFrame("Frame", "vesperToolsTopUtilityFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.topUtilityFrame:SetSize((TOP_UTILITY_PADDING * 2) + (2 * buttonSize) + TOP_UTILITY_BUTTON_GAP, frameHeight)
    self.topUtilityFrame:SetPoint("BOTTOM", self.VesperPortalsUI, "TOP", 0, 10)
    vesperTools:ApplyAddonWindowLayer(self.topUtilityFrame)

    vesperTools:ApplyRoundedWindowBackdrop(self.topUtilityFrame)
    self.topUtilityFrame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("portals"))
    self.topUtilityFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    -- Two hearthstone buttons are always available.
    self.primaryHearthstoneButton = self:CreateTopUtilityButton(self.topUtilityFrame, "SecureActionButtonTemplate")
    self.primaryHearthstoneButton:SetScript("PreClick", function(button)
        self:PreparePrimaryHearthstoneClick(button)
    end)
    self.primaryHearthstoneButton:SetScript("PostClick", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                self:RefreshActionCooldowns()
            end)
        else
            self:RefreshActionCooldowns()
        end
    end)
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

    -- Mage-specific utility buttons: left-click casts selected spell, right-click chooses.
    if self.isMage then
        self.mageTeleportButton = self:CreateTopUtilityButton(self.topUtilityFrame, "SecureActionButtonTemplate")
        self.mageTeleportButton:HookScript("OnClick", function(button, mouseButton)
            if mouseButton == "RightButton" then
                self:OpenMageTravelMenu(button, "teleport")
            end
        end)

        self.magePortalButton = self:CreateTopUtilityButton(self.topUtilityFrame, "SecureActionButtonTemplate")
        self.magePortalButton:HookScript("OnClick", function(button, mouseButton)
            if mouseButton == "RightButton" then
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

    if isInCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    local hasSpells = type(spells) == "table" and #spells > 0
    if hasSpells then
        local selectionKey = button._mageTravelSelectionKey
        local selectedSpell = findMageTravelSpell(spells, selectionKey and self[selectionKey]) or spells[1]
        local icon = selectedSpell.icon or FALLBACK_ICON_TEXTURE
        button.icon:SetTexture(icon)
        button.icon:SetDrawLayer("ARTWORK", 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.icon:SetBlendMode("BLEND")
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
        button.icon:Show()
        button:EnableMouse(true)

        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", selectedSpell.name)
        button:SetAttribute("type2", nil)
        button:SetAttribute("spell2", nil)

        button._isAvailable = true
        button._displayName = selectedSpell.name or titleText
        button._unavailableText = unavailableText
        button._tooltipHint = hintText
        button._mageTravelSpellID = selectedSpell.spellID
        self:SetButtonCooldownSource(button, "spell", selectedSpell.spellID)
    else
        button.icon:SetTexture(FALLBACK_ICON_TEXTURE)
        button.icon:SetDrawLayer("ARTWORK", 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        button.icon:SetBlendMode("BLEND")
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.4)
        button.icon:Show()
        button:EnableMouse(false)

        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
        button:SetAttribute("type2", nil)
        button:SetAttribute("spell2", nil)

        button._isAvailable = false
        button._displayName = titleText
        button._unavailableText = unavailableText
        button._tooltipHint = hintText
        button._mageTravelSpellID = nil
        self:SetButtonCooldownSource(button, nil, nil)
    end
end

function Portals:SelectMageTravelSpell(kind, spellID)
    local selectionKey = getMageTravelSelectionKey(kind)
    local numericSpellID = tonumber(spellID)
    self[selectionKey] = numericSpellID

    local characterSettings = vesperTools:GetCharacterPortalSettings()
    if characterSettings then
        characterSettings[getSavedMageTravelSelectionKey(kind)] = numericSpellID
    end

    if InCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    self:RefreshMageTravelButtons()
    self:RefreshActionCooldowns()
end

-- Refresh mage travel buttons from current known spellbook state.
function Portals:RefreshMageTravelButtons()
    if not self.isMage then
        return
    end
    if not self.mageTeleportButton or not self.magePortalButton then
        return
    end

    if InCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    self.knownMageTeleportSpells = self:GetKnownMageTravelSpells("teleport")
    self.knownMagePortalSpells = self:GetKnownMageTravelSpells("portal")

    local characterSettings = vesperTools:GetCharacterPortalSettings()
    if characterSettings then
        local teleportSelectionKey = getMageTravelSelectionKey("teleport")
        local portalSelectionKey = getMageTravelSelectionKey("portal")
        if self[teleportSelectionKey] == nil then
            self[teleportSelectionKey] = tonumber(characterSettings[getSavedMageTravelSelectionKey("teleport")])
        end
        if self[portalSelectionKey] == nil then
            self[portalSelectionKey] = tonumber(characterSettings[getSavedMageTravelSelectionKey("portal")])
        end
    end

    self.mageTeleportButton._mageTravelSelectionKey = getMageTravelSelectionKey("teleport")
    self.magePortalButton._mageTravelSelectionKey = getMageTravelSelectionKey("portal")

    self:ApplyMageTravelButtonState(
        self.mageTeleportButton,
        self.knownMageTeleportSpells,
        L["MAGE_TELEPORTS"],
        L["NO_TELEPORT_SPELLS_KNOWN"],
        L["MAGE_TRAVEL_TOOLTIP"]
    )
    self:ApplyMageTravelButtonState(
        self.magePortalButton,
        self.knownMagePortalSpells,
        L["MAGE_PORTALS"],
        L["NO_PORTAL_SPELLS_KNOWN"],
        L["MAGE_TRAVEL_TOOLTIP"]
    )
end

-- Prepare a fresh hearthstone choice immediately before a RANDOM DISCO click fires.
function Portals:PreparePrimaryHearthstoneClick(button)
    if not button or not button._isRandomDisco then
        return
    end

    if InCombatLockdown() then
        return
    end

    local option = vesperTools:GetRandomPrimaryHearthstoneOption()
    if not option then
        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("type1", nil)
        button._randomDiscoItemID = nil
        self:SetButtonCooldownSource(button, nil, nil)
        return
    end

    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", "/use item:" .. tostring(option.itemID))
    button._randomDiscoItemID = option.itemID
    self:SetButtonCooldownSource(button, "item", option.itemID)
end

-- Apply one hearthstone option to one secure button.
-- Called only out of combat because secure attributes are updated here.
function Portals:ApplyHearthstoneOption(button, option)
    if not button or not button.icon then
        return
    end

    if isInCombatLockdown() then
        self.pendingUtilityRefresh = true
        return
    end

    if option then
        if option.isRandomDisco then
            button.icon:SetTexture(option.icon or FALLBACK_ICON_TEXTURE)
            button.icon:SetDrawLayer("ARTWORK", 1)
            button.icon:SetVertexColor(1, 1, 1, 1)
            button.icon:SetBlendMode("BLEND")
            button.icon:SetDesaturated(false)
            button.icon:SetAlpha(1)
            button.icon:Show()
            button:EnableMouse(true)

            button:SetAttribute("type1", "macro")
            if button._randomDiscoItemID then
                button:SetAttribute("macrotext1", "/use item:" .. tostring(button._randomDiscoItemID))
            else
                button:SetAttribute("macrotext1", nil)
            end

            local cooldownItemID = self:GetRandomDiscoCooldownItemID(button)
            if cooldownItemID then
                self:SetButtonCooldownSource(button, "item", cooldownItemID)
            else
                self:SetButtonCooldownSource(button, nil, nil)
            end

            button._isRandomDisco = true
            button._isAvailable = true
            button._displayName = option.name or L["HEARTHSTONE"]
            button._tooltipHint = L["UTILITY_TOOLTIP_RANDOM_HEARTHSTONE"]
            button._unavailableText = L["NO_HEARTHSTONES_AVAILABLE"]
            button._itemID = option.itemID
            return
        end

        local icon = normalizeTextureToken(option.icon)

        if not icon and C_Item and C_Item.GetItemIconByID then
            icon = normalizeTextureToken(C_Item.GetItemIconByID(option.itemID))
        end
        if not icon and C_Item and C_Item.GetItemInfoInstant then
            local _, _, itemIconA, _, itemIconB, _, _, _, _, itemIconC = C_Item.GetItemInfoInstant(option.itemID)
            icon = normalizeTextureToken(itemIconA)
                or normalizeTextureToken(itemIconB)
                or normalizeTextureToken(itemIconC)
                or icon
        end
        if not icon and C_ToyBox and C_ToyBox.GetToyInfo then
            local _, toyIconA, toyIconB, toyIconC, toyIconD = C_ToyBox.GetToyInfo(option.itemID)
            icon = normalizeTextureToken(toyIconB)
                or normalizeTextureToken(toyIconA)
                or normalizeTextureToken(toyIconC)
                or normalizeTextureToken(toyIconD)
                or icon
        end
        if not icon and C_Item and C_Item.GetItemSpell then
            local okSpell, _, itemSpellID = pcall(C_Item.GetItemSpell, option.itemID)
            itemSpellID = okSpell and itemSpellID or nil
            if itemSpellID then
                local spellInfo = vesperTools:GetSpellInfoSafe(itemSpellID)
                icon = normalizeTextureToken(spellInfo and (spellInfo.iconID or spellInfo.originalIconID)) or icon
            end
        end
        if not icon then
            local _, _, itemIconA, _, itemIconB, _, _, _, _, itemIconC = GetItemInfoInstant(option.itemID)
            icon = normalizeTextureToken(itemIconA)
                or normalizeTextureToken(itemIconB)
                or normalizeTextureToken(itemIconC)
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

        button._isRandomDisco = false
        button._randomDiscoItemID = nil
        button._isAvailable = true
        button._displayName = option.name or string.format(L["ITEM_FALLBACK_FMT"], tostring(option.itemID))
        button._tooltipHint = L["UTILITY_TOOLTIP_USE"]
        button._unavailableText = L["NO_HEARTHSTONES_AVAILABLE"]
        button._itemID = option.itemID
        self:SetButtonCooldownSource(button, "item", option.itemID)
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

        button._isRandomDisco = false
        button._randomDiscoItemID = nil
        button._isAvailable = false
        button._displayName = L["HEARTHSTONE"]
        button._tooltipHint = L["UTILITY_TOOLTIP_USE"]
        button._unavailableText = L["NO_HEARTHSTONES_AVAILABLE"]
        button._itemID = nil
        self:SetButtonCooldownSource(button, nil, nil)
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

    local options = vesperTools:GetAvailableHearthstoneOptions()
    local optionsByID = {}
    for i = 1, #options do
        optionsByID[options[i].itemID] = options[i]
    end

    local primaryID = vesperTools:ResolvePrimaryHearthstoneID()
    local secondaryID = vesperTools:GetSecondaryHearthstoneID(primaryID)

    local primaryOption = nil
    if primaryID and vesperTools:IsRandomDiscoHearthstoneSelection(primaryID) then
        primaryOption = vesperTools:GetRandomDiscoHearthstoneOption()
    elseif primaryID then
        primaryOption = optionsByID[primaryID]
    end

    self:ApplyHearthstoneOption(self.primaryHearthstoneButton, primaryOption)
    self:ApplyHearthstoneOption(self.secondaryHearthstoneButton, secondaryID and optionsByID[secondaryID] or nil)
    self:RefreshActionCooldowns()
end

function Portals:WarnMissingSeasonDungeonMetadata(curSeason, dataHandle)
    if not dataHandle or type(dataHandle.GetMissingDungeonsForMapIDs) ~= "function" then
        return
    end

    local missingMapIDs = dataHandle:GetMissingDungeonsForMapIDs(curSeason)
    if #missingMapIDs == 0 then
        return
    end

    self.reportedMissingSeasonDungeonMapIDs = self.reportedMissingSeasonDungeonMapIDs or {}

    local unresolved = {}
    for i = 1, #missingMapIDs do
        local mapID = missingMapIDs[i]
        local entries = getDungeonCatalogEntries(dataHandle, mapID)
        if type(entries) ~= "table" and not self.reportedMissingSeasonDungeonMapIDs[mapID] then
            local dungeonName = getChallengeModeMapNameSafe(mapID) or L["UNKNOWN_DUNGEON"]
            unresolved[#unresolved + 1] = string.format("%s (%d)", dungeonName, mapID)
            self.reportedMissingSeasonDungeonMapIDs[mapID] = true
        end
    end

    if #unresolved > 0 then
        vesperTools:Print(string.format(L["PORTALS_MISSING_SEASON_DUNGEONS_FMT"], table.concat(unresolved, ", ")))
    end
end

-- Main portal and vault frames.
function Portals:CreatePortalFrame()
    local _, englishClass = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(englishClass)
    -- Reuse player class color as a consistent accent across all portal panels.
    self.classColor = classColor

    self.VesperPortalsUI = CreateFrame("Frame", "vesperToolsPortalFrame", UIParent, "BackdropTemplate")
    self.VesperPortalsUI:SetSize(300, 160)

    -- Restore saved position or use default
    if vesperTools.db.profile.portalsPosition then
        local pos = vesperTools.db.profile.portalsPosition
        self.VesperPortalsUI:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        self.VesperPortalsUI:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
    end

    vesperTools:ApplyAddonWindowLayer(self.VesperPortalsUI)
    self.VesperPortalsUI:SetMovable(true)
    self.VesperPortalsUI:EnableMouse(true)
    self.VesperPortalsUI:RegisterForDrag("LeftButton")
    self.VesperPortalsUI:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    self.VesperPortalsUI:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        vesperTools.db.profile.portalsPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end)
    self.VesperPortalsUI:Hide()
    vesperTools:RegisterEscapeFrame(self.VesperPortalsUI, function()
        self:HandleCloseRequest()
    end)

    vesperTools:ApplyRoundedWindowBackdrop(self.VesperPortalsUI)
    self.VesperPortalsUI:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("portals")) -- #121212
    self.VesperPortalsUI:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

    local DataHandle = vesperTools:GetModule("DataHandle", true)
    if not DataHandle then
        vesperTools:Print(L["PORTALS_DATAHANDLE_MODULE_NOT_FOUND"])
        return
    end

    self:RebuildDungeonPortalButtons()

    self:CreateTopUtilityFrame()
    self:RefreshHearthstoneButtons()
    self:RefreshToyFlyout()
    self:RefreshMageTravelButtons()
    self:CreateVaultFrame()
    self:RefreshActionCooldowns()
end

function Portals:CreateVaultFrame()
    self.vaultFrame = CreateFrame("Frame", "vesperToolsVaultFrame", self.VesperPortalsUI, "BackdropTemplate")
    self.vaultFrame:SetSize(72, 72)
    self.vaultFrame:SetPoint("TOP", self.VesperPortalsUI, "BOTTOM", 0, -10)
    vesperTools:ApplyAddonWindowLayer(self.vaultFrame)

    vesperTools:ApplyRoundedWindowBackdrop(self.vaultFrame)
    self.vaultFrame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("portals"))
    self.vaultFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local btn = CreateFrame("Button", nil, self.vaultFrame)
    btn:SetSize(52, 52)
    btn:SetPoint("CENTER")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider")

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 0, 0.4)
    btn:SetHighlightTexture(highlight)

    btn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if UIParentLoadAddOn and not WeeklyRewards_ShowUI then
                UIParentLoadAddOn("Blizzard_WeeklyRewards")
            end
            if WeeklyRewards_ShowUI then
                WeeklyRewards_ShowUI()
            end

            local VaultStore = vesperTools:GetModule("VaultStore", true)
            if VaultStore and type(VaultStore.QueueCapture) == "function" then
                VaultStore:QueueCapture(0.15)
            end
            return
        end

        local VaultWindow = vesperTools:GetModule("VaultWindow", true)
        if VaultWindow and type(VaultWindow.Toggle) == "function" then
            VaultWindow:Toggle()
            return
        end

        if UIParentLoadAddOn and not WeeklyRewards_ShowUI then
            UIParentLoadAddOn("Blizzard_WeeklyRewards")
        end
        if WeeklyRewards_ShowUI then
            WeeklyRewards_ShowUI()
        end
    end)

    btn:SetScript("OnEnter", function(vaultButton)
        GameTooltip:SetOwner(vaultButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["GREAT_VAULT"], 1, 1, 1)
        GameTooltip:AddLine(L["VAULT_PORTAL_TOOLTIP_VIEW"], 0.85, 0.85, 0.85)
        GameTooltip:AddLine(L["VAULT_PORTAL_TOOLTIP_LIVE"], 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Portals:DestroyProgressFrames()
    if self.accountKeystoneFrame then
        self.accountKeystoneFrame:Hide()
        self.accountKeystoneFrame:SetParent(nil)
        self.accountKeystoneFrame = nil
    end

    if self.mplusProgFrame then
        self.mplusProgFrame:Hide()
        self.mplusProgFrame:SetParent(nil)
        self.mplusProgFrame = nil
    end
end

local function getClassColorByID(classID)
    local numericClassID = tonumber(classID)
    if not numericClassID then
        return nil
    end

    local classFile
    if C_CreatureInfo and type(C_CreatureInfo.GetClassInfo) == "function" then
        local classInfo = C_CreatureInfo.GetClassInfo(numericClassID)
        if type(classInfo) == "table" then
            classFile = classInfo.classFile or classInfo.classFileName or classInfo.classFilename
        end
    end

    if not classFile and type(GetClassInfo) == "function" then
        local _, englishClass = GetClassInfo(numericClassID)
        classFile = englishClass
    end

    if not classFile then
        return nil
    end

    return C_ClassColor.GetClassColor(classFile)
end

function Portals:BuildAccountKeystoneRows()
    local bagsStore = vesperTools:GetModule("BagsStore", true)
    local keystoneSync = vesperTools:GetModule("KeystoneSync", true)
    local dataHandle = vesperTools:GetModule("DataHandle", true)
    local characters = bagsStore and type(bagsStore.GetDisplayCharacters) == "function"
        and bagsStore:GetDisplayCharacters()
        or {}

    if #characters == 0 then
        characters = {
            {
                fullName = vesperTools:GetCurrentCharacterFullName(),
                isCurrent = true,
            },
        }
    end

    local rows = {}
    for index = 1, #characters do
        local character = characters[index]
        local fullName = character and character.fullName or nil
        if type(fullName) == "string" and fullName ~= "" then
            local keyData = keystoneSync and type(keystoneSync.GetStoredAccountKeystone) == "function"
                and keystoneSync:GetStoredAccountKeystone(fullName)
                or nil

            if type(keyData) == "table" and tonumber(keyData.level) and tonumber(keyData.mapID) then
                local level = math.max(0, math.floor((tonumber(keyData.level) or 0) + 0.5))
                local mapID = math.max(0, math.floor((tonumber(keyData.mapID) or 0) + 0.5))
                if level > 0 and mapID > 0 then
                    local displayName = (Ambiguate and Ambiguate(fullName, "guild")) or fullName
                    local colorCode = dataHandle and type(dataHandle.GetKeyColor) == "function"
                        and dataHandle:GetKeyColor(level)
                        or "|cffffffff"
                    local abbrev = keystoneSync and type(keystoneSync.GetDungeonAbbrev) == "function"
                        and keystoneSync:GetDungeonAbbrev(mapID)
                        or L["KEYSTONE_UNKNOWN_ABBREV"]
                    local rating = math.max(0, math.floor((tonumber(keyData.rating) or 0) + 0.5))
                    if rating == 0 and keystoneSync and type(keystoneSync.GetStoredKeystoneData) == "function" then
                        local storedKeyData = keystoneSync:GetStoredKeystoneData(fullName)
                        rating = math.max(0, math.floor((tonumber(storedKeyData and storedKeyData.rating) or 0) + 0.5))
                    end
                    local ratingColor = dataHandle and type(dataHandle.GetRatingColor) == "function"
                        and dataHandle:GetRatingColor(rating)
                        or "|cff9d9d9d"

                    rows[#rows + 1] = {
                        displayName = displayName,
                        classID = character.classID,
                        ratingText = rating > 0 and string.format("%s%d|r", ratingColor, rating) or "|cff9d9d9d-|r",
                        keyText = string.format("%s%s +%d|r", colorCode, abbrev, level),
                    }
                end
            end
        end
    end

    return rows
end

function Portals:CreateAccountKeystoneFrame()
    local rows = self:BuildAccountKeystoneRows()
    if #rows == 0 then
        return
    end

    local bestKeysFontSize = vesperTools:GetConfiguredFontSize("bestKeys", 11, 8, 24)
    local rowHeight = 18
    local headerHeight = 22
    local padding = 10
    local keyColWidth = 80
    local ratingColWidth = 48
    local gap = 10
    local frameHeight = headerHeight + (#rows * rowHeight) + (padding * 2)

    local measure = UIParent:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(measure, bestKeysFontSize, "")
    local maxNameWidth = 0
    for index = 1, #rows do
        measure:SetText(rows[index].displayName or "")
        maxNameWidth = math.max(maxNameWidth, measure:GetStringWidth() or 0)
    end
    measure:Hide()

    local frameWidth = math.max(
        220,
        math.ceil(maxNameWidth) + ratingColWidth + keyColWidth + (gap * 2) + (padding * 2)
    )
    self.accountKeystoneFrame = CreateFrame("Frame", nil, self.VesperPortalsUI, "BackdropTemplate")
    self.accountKeystoneFrame:SetSize(frameWidth, frameHeight)
    if self.mplusProgFrame then
        self.accountKeystoneFrame:SetPoint("TOP", self.mplusProgFrame, "BOTTOM", 0, -10)
    else
        self.accountKeystoneFrame:SetPoint("LEFT", self.VesperPortalsUI, "RIGHT", 10, 0)
    end
    vesperTools:ApplyAddonWindowLayer(self.accountKeystoneFrame)
    vesperTools:ApplyRoundedWindowBackdrop(self.accountKeystoneFrame)
    self.accountKeystoneFrame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("bestKeys"))
    self.accountKeystoneFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local keyColRight = -padding
    local ratingColRight = keyColRight - keyColWidth - gap

    local nameHeader = self.accountKeystoneFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(nameHeader, bestKeysFontSize, "")
    nameHeader:SetPoint("TOPLEFT", padding, -padding)
    nameHeader:SetText("|cffFFFFFF" .. L["BEST_KEYS_HEADER_NAME"] .. "|r")

    local keyHeader = self.accountKeystoneFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(keyHeader, bestKeysFontSize, "")
    keyHeader:SetPoint("TOPRIGHT", keyColRight, -padding)
    keyHeader:SetText("|cffFFFFFF" .. L["BEST_KEYS_HEADER_KEY"] .. "|r")

    local ratingHeader = self.accountKeystoneFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(ratingHeader, bestKeysFontSize, "")
    ratingHeader:SetPoint("TOPRIGHT", ratingColRight, -padding)
    ratingHeader:SetText("|cffFFFFFF" .. L["ROSTER_COLUMN_RATING"] .. "|r")

    for index = 1, #rows do
        local rowTop = -(padding + headerHeight + (index - 1) * rowHeight)
        local rowCenter = rowTop - (rowHeight / 2)

        if index % 2 == 0 then
            local stripe = self.accountKeystoneFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
            stripe:SetPoint("TOPLEFT", self.accountKeystoneFrame, "TOPLEFT", 1, rowTop)
            stripe:SetPoint("TOPRIGHT", self.accountKeystoneFrame, "TOPRIGHT", -1, rowTop)
            stripe:SetHeight(rowHeight)
            stripe:SetColorTexture(0.17, 0.17, 0.17, 1)
        end

        local nameText = self.accountKeystoneFrame:CreateFontString(nil, "OVERLAY")
        vesperTools:ApplyConfiguredFont(nameText, bestKeysFontSize, "")
        nameText:SetPoint("LEFT", self.accountKeystoneFrame, "TOPLEFT", padding, rowCenter)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(rows[index].displayName or "")
        local classColor = getClassColorByID(rows[index].classID)
        if classColor then
            nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            nameText:SetTextColor(1, 1, 1)
        end

        local keyText = self.accountKeystoneFrame:CreateFontString(nil, "OVERLAY")
        vesperTools:ApplyConfiguredFont(keyText, bestKeysFontSize, "")
        keyText:SetPoint("RIGHT", self.accountKeystoneFrame, "TOPRIGHT", keyColRight, rowCenter)
        keyText:SetJustifyH("RIGHT")
        keyText:SetText(rows[index].keyText or "|cff9d9d9d-|r")

        local ratingText = self.accountKeystoneFrame:CreateFontString(nil, "OVERLAY")
        vesperTools:ApplyConfiguredFont(ratingText, bestKeysFontSize, "")
        ratingText:SetPoint("RIGHT", self.accountKeystoneFrame, "TOPRIGHT", ratingColRight, rowCenter)
        ratingText:SetJustifyH("RIGHT")
        ratingText:SetText(rows[index].ratingText or "|cff9d9d9d-|r")
    end
end

function Portals:RebuildProgressFrames()
    self:DestroyProgressFrames()

    local keystoneSync = vesperTools:GetModule("KeystoneSync", true)
    if keystoneSync and type(keystoneSync.UpdateCurrentCharacterKeystoneSnapshot) == "function" then
        keystoneSync:UpdateCurrentCharacterKeystoneSnapshot()
    end

    local curSeason = getChallengeModeMapTableSafe()
    if curSeason and #curSeason > 0 then
        self:CreateMPlusProgFrame(curSeason)
    end
    self:CreateAccountKeystoneFrame()
end

function Portals:CreateMPlusProgFrame(curSeason)
    -- Typography for the Best Keys panel is independently configurable.
    local bestKeysFontSize = vesperTools:GetConfiguredFontSize("bestKeys", 11, 8, 24)

    local rowHeight = 18
    local headerHeight = 22
    local ratingRowHeight = 20
    local padding = 10
    local bestColWidth = 40 -- space for "+XX" text
    local timeColWidth = 55 -- space for "mm:ss" text
    local gap = 10 -- gap between columns
    local numDungeons = #curSeason
    local frameHeight = ratingRowHeight + headerHeight + (numDungeons * rowHeight) + (padding * 2)
    local DataHandle = vesperTools:GetModule("DataHandle", true)
    local ratingSummary = DataHandle and DataHandle:GetPlayerMythicPlusRatingSummary() or nil
    local bestRatingRunByMap = DataHandle and DataHandle:GetBestRatingRunsByMap(ratingSummary) or {}
    local currentRating = getPlayerMythicPlusRating(ratingSummary)
    local currentRatingColor = DataHandle and DataHandle:GetRatingColor(currentRating) or "|cff9d9d9d"
    local currentRatingText = string.format(L["BEST_KEYS_CURRENT_RATING_FMT"], currentRatingColor .. currentRating .. "|r")

    -- Measure widest dungeon name to size frame dynamically
    local measure = UIParent:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(measure, bestKeysFontSize, "")
    local maxNameWidth = 0
    for _, mapID in ipairs(curSeason) do
        local dungName = getChallengeModeMapNameSafe(mapID) or L["UNKNOWN_DUNGEON"]
        measure:SetText(dungName)
        local w = measure:GetStringWidth()
        if w > maxNameWidth then maxNameWidth = w end
    end
    measure:SetText(currentRatingText)
    local ratingTextWidth = measure:GetStringWidth()
    measure:Hide()

    local frameWidth = math.max(
        math.ceil(maxNameWidth) + bestColWidth + timeColWidth + (gap * 2) + (padding * 2),
        math.ceil(ratingTextWidth) + (padding * 2)
    )

    self.mplusProgFrame = CreateFrame("Frame", nil, self.VesperPortalsUI, "BackdropTemplate")
    self.mplusProgFrame:SetSize(frameWidth, frameHeight)
    self.mplusProgFrame:SetPoint("LEFT", self.VesperPortalsUI, "RIGHT", 10, 0)
    -- Swallow mouse input so windows underneath (e.g. bags) never show their
    -- tooltips while hovering this panel.
    self.mplusProgFrame:EnableMouse(true)
    vesperTools:ApplyAddonWindowLayer(self.mplusProgFrame)

    vesperTools:ApplyRoundedWindowBackdrop(self.mplusProgFrame)
    self.mplusProgFrame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("bestKeys"))
    self.mplusProgFrame:SetBackdropBorderColor(self.classColor.r, self.classColor.g, self.classColor.b, 1)

    local timeColRight = -padding
    local bestColRight = timeColRight - timeColWidth - gap

    local ratingText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(ratingText, bestKeysFontSize, "")
    ratingText:SetPoint("BOTTOM", self.mplusProgFrame, "BOTTOM", 0, padding)
    ratingText:SetWidth(frameWidth - (padding * 2))
    ratingText:SetJustifyH("CENTER")
    ratingText:SetText(currentRatingText)

    -- Header
    local nameHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(nameHeader, bestKeysFontSize, "")
    nameHeader:SetPoint("TOPLEFT", padding, -padding)
    nameHeader:SetText("|cffFFFFFF" .. L["BEST_KEYS_HEADER_DUNGEON"] .. "|r")

    local keyHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(keyHeader, bestKeysFontSize, "")
    keyHeader:SetPoint("TOPRIGHT", bestColRight, -padding)
    keyHeader:SetText("|cffFFFFFF" .. L["BEST_KEYS_HEADER_BEST"] .. "|r")

    local timeHeader = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
    vesperTools:ApplyConfiguredFont(timeHeader, bestKeysFontSize, "")
    timeHeader:SetPoint("TOPRIGHT", timeColRight, -padding)
    timeHeader:SetText("|cffFFFFFF" .. L["BEST_KEYS_HEADER_TIME"] .. "|r")

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
        local dungName = getChallengeModeMapNameSafe(mapID) or L["UNKNOWN_DUNGEON"]
        local nameText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        vesperTools:ApplyConfiguredFont(nameText, bestKeysFontSize, "")
        nameText:SetPoint("LEFT", self.mplusProgFrame, "TOPLEFT", padding, rowCenter)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(dungName)

        -- Best key level
        local bestLevel = 0
        local bestDuration = 0
        local wasInTime = false
        -- Rating summary runs reflect the per-dungeon score contributor; season bests can prefer a higher depleted key.
        local ratingRun = bestRatingRunByMap[mapID]
        if ratingRun then
            bestLevel = ratingRun.level
            bestDuration = ratingRun.duration
            wasInTime = ratingRun.inTime
        else
            local inTimeInfo, overTimeInfo = getSeasonBestForMapSafe(mapID)
            if inTimeInfo and inTimeInfo.level then
                bestLevel = inTimeInfo.level
                bestDuration = inTimeInfo.durationSec
                wasInTime = true
            end
            if overTimeInfo and overTimeInfo.level and overTimeInfo.level > bestLevel then
                bestLevel = overTimeInfo.level
                bestDuration = overTimeInfo.durationSec
                wasInTime = false
            end
        end

        local levelText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        vesperTools:ApplyConfiguredFont(levelText, bestKeysFontSize, "")
        levelText:SetPoint("RIGHT", self.mplusProgFrame, "TOPRIGHT", bestColRight, rowCenter)
        levelText:SetJustifyH("RIGHT")

        local timeText = self.mplusProgFrame:CreateFontString(nil, "OVERLAY")
        vesperTools:ApplyConfiguredFont(timeText, bestKeysFontSize, "")
        timeText:SetPoint("RIGHT", self.mplusProgFrame, "TOPRIGHT", timeColRight, rowCenter)
        timeText:SetJustifyH("RIGHT")

        if bestLevel > 0 then
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

        -- Invisible hover target for the per-dungeon best-runs tooltip.
        local rowHover = CreateFrame("Frame", nil, self.mplusProgFrame)
        rowHover:SetPoint("TOPLEFT", self.mplusProgFrame, "TOPLEFT", 1, rowTop)
        rowHover:SetPoint("TOPRIGHT", self.mplusProgFrame, "TOPRIGHT", -1, rowTop)
        rowHover:SetHeight(rowHeight)
        rowHover:EnableMouse(true)
        rowHover:SetScript("OnEnter", function(hoverFrame)
            self:ShowBestRunsTooltip(hoverFrame, mapID, dungName)
        end)
        rowHover:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end

function Portals:ShowBestRunsTooltip(anchor, mapID, dungeonName)
    local DataHandle = vesperTools:GetModule("DataHandle", true)
    local runs = DataHandle and DataHandle:GetSeasonBestRunsForMap(mapID, 5) or {}

    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:SetText(dungeonName, 1, 1, 1)

    if #runs == 0 then
        GameTooltip:AddLine(L["BEST_KEYS_TOOLTIP_NO_RUNS"], 0.62, 0.62, 0.62)
    else
        for index = 1, #runs do
            local run = runs[index]
            local keyColor = DataHandle:GetKeyColor(run.level) or "|cff9d9d9d"
            local leftText = keyColor .. "+" .. run.level .. "|r"

            local rightParts = {}
            if run.duration and run.duration > 0 then
                local mins = math.floor(run.duration / 60)
                local secs = run.duration % 60
                local timeColor = run.inTime and "|cff81c784" or "|cffe57373"
                rightParts[#rightParts + 1] = string.format("%s%d:%02d|r", timeColor, mins, secs)
            end
            if run.completedAt then
                rightParts[#rightParts + 1] = "|cff9d9d9d" .. date("%b %d", run.completedAt) .. "|r"
            end

            local rightText = #rightParts > 0 and table.concat(rightParts, "  ") or "|cff9d9d9d-|r"
            GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 1, 1, 1)
        end
    end

    GameTooltip:Show()
end

function Portals:HandleCloseRequest()
    if not self.VesperPortalsUI or not self.VesperPortalsUI:IsShown() then
        return
    end

    if InCombatLockdown() then
        -- Portal buttons use secure attributes; prevent show/hide rebuilds in combat lockdown.
        vesperTools:Print(L["PORTALS_TOGGLE_IN_COMBAT"])
        return
    end

    self:HideToyFlyout()
    self.VesperPortalsUI:Hide()
end

function Portals:Toggle()
    if InCombatLockdown() then
        -- Portal buttons use secure attributes; prevent show/hide rebuilds in combat lockdown.
        vesperTools:Print(L["PORTALS_TOGGLE_IN_COMBAT"])
        return
    end

    if not self.VesperPortalsUI then
        vesperTools:Print(L["PORTALS_UI_NOT_INITIALIZED"])
        return
    end

    if self.VesperPortalsUI:IsShown() then
        self:HandleCloseRequest()
    else
        -- Rebuild each open so current-season best run and account key data stay fresh.
        self:RefreshDungeonPortalButtons()
        self:RebuildProgressFrames()
        self.VesperPortalsUI:Show()
        self.VesperPortalsUI:Raise()
        self:RefreshActionCooldowns()
    end
end
