local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local Automation = VesperGuild:NewModule("Automation", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

local ILVL_PREFIX = "VGiLvl"
local BESTKEYS_PREFIX = "VGBestKeys"
local BESTKEYS_REQ_PREFIX = "VGBKReq"
local SYNC_COOLDOWN = 30 -- seconds between broadcasts to avoid spam
local lastIlvlBroadcast = 0
local lastBestKeysBroadcast = 0
local cachedRealmName = nil

function Automation:OnEnable()
    -- Register comm prefixes
    self:RegisterComm(ILVL_PREFIX, "OnIlvlReceived")
    self:RegisterComm(BESTKEYS_PREFIX, "OnBestKeysReceived")
    self:RegisterComm(BESTKEYS_REQ_PREFIX, "OnBestKeysRequested")

    -- Listen for addon open to trigger syncs
    self:RegisterMessage("VESPERGUILD_ADDON_OPENED", "OnAddonOpened")

    -- Listen for M+ completion
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnMPlusCompleted")

    -- Pre-load M+ data so GetSeasonBestForMap works when we need it
    C_MythicPlus.RequestMapInfo()

    self:RegisterChatCommand("vespertest", "TestKeyReminder")

    -- Clean up stale entries
    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:CleanupStaleIlvl()
        DataHandle:CleanupStaleBestKeys()
    end
end

function Automation:OnAddonOpened()
    self:BroadcastIlvl()
    self:BroadcastBestKeys()
    self:RequestBestKeys()
end

function Automation:TestKeyReminder()
    self:ShowKeyReminder()
end

-- Broadcast player's ilvl to guild as addon message
function Automation:BroadcastIlvl()
    if not IsInGuild() then return end

    -- Cooldown check
    local now = GetTime()
    if (now - lastIlvlBroadcast) < SYNC_COOLDOWN then return end
    lastIlvlBroadcast = now

    local _, ilvl = GetAverageItemLevel()
    ilvl = math.floor(ilvl)

    local _, _, classID = UnitClass("player")

    local payload = string.format("%d:%d", ilvl, classID)
    self:SendCommMessage(ILVL_PREFIX, payload, "GUILD")
end

-- Handle incoming ilvl messages from guild members
function Automation:OnIlvlReceived(prefix, message, distribution, sender)
    if prefix ~= ILVL_PREFIX then return end
    if distribution ~= "GUILD" then return end

    -- Normalize sender (add realm if missing)
    if not string.find(sender, "-") then
        cachedRealmName = cachedRealmName or GetNormalizedRealmName()
        sender = sender .. "-" .. cachedRealmName
    end

    local ilvlStr, classIDStr = strsplit(":", message)
    local ilvl = tonumber(ilvlStr)
    local classID = tonumber(classIDStr)

    if not ilvl then return end

    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreIlvl(sender, ilvl, classID)
        VesperGuild:SendMessage("VESPERGUILD_ILVL_UPDATE", sender)
    end
end

-- Broadcast player's best M+ keys to guild
function Automation:BroadcastBestKeys()
    if not IsInGuild() then return end

    local now = GetTime()
    if (now - lastBestKeysBroadcast) < SYNC_COOLDOWN then return end
    lastBestKeysBroadcast = now

    local curSeason = C_ChallengeMode.GetMapTable()
    if not curSeason or #curSeason == 0 then return end

    local _, _, classID = UnitClass("player")
    local parts = {}
    local localBestKeys = {}
    for _, mapID in ipairs(curSeason) do
        local inTimeInfo, overTimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
        local bestLevel, bestDuration, wasInTime = 0, 0, false
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
        table.insert(parts, string.format("%d:%d:%d:%d", mapID, bestLevel, bestDuration, wasInTime and 1 or 0))
        if bestLevel > 0 then
            localBestKeys[mapID] = { level = bestLevel, duration = bestDuration, inTime = wasInTime }
        end
    end

    -- Store locally so we don't depend on the comm echo
    cachedRealmName = cachedRealmName or GetNormalizedRealmName()
    local playerName = UnitName("player") .. "-" .. cachedRealmName
    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreBestKeys(playerName, localBestKeys, classID)
    end

    local payload = classID .. ";" .. table.concat(parts, ",")
    self:SendCommMessage(BESTKEYS_PREFIX, payload, "GUILD")
end

-- Handle incoming best keys messages from guild members
function Automation:OnBestKeysReceived(prefix, message, distribution, sender)
    if prefix ~= BESTKEYS_PREFIX or distribution ~= "GUILD" then return end

    if not string.find(sender, "-") then
        cachedRealmName = cachedRealmName or GetNormalizedRealmName()
        sender = sender .. "-" .. cachedRealmName
    end

    local classIDStr, dungeonData = strsplit(";", message)
    local classID = tonumber(classIDStr)
    if not dungeonData then return end

    local bestKeys = {}
    for entry in string.gmatch(dungeonData, "[^,]+") do
        local mStr, lStr, dStr, iStr = strsplit(":", entry)
        local mapID = tonumber(mStr)
        local level = tonumber(lStr)
        local duration = tonumber(dStr)
        local inTime = iStr == "1"
        if mapID and level and level > 0 then
            bestKeys[mapID] = { level = level, duration = duration, inTime = inTime }
        end
    end

    local DataHandle = VesperGuild:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreBestKeys(sender, bestKeys, classID)
        VesperGuild:SendMessage("VESPERGUILD_BESTKEYS_UPDATE", sender)
    end
end

-- Handle incoming best keys request — respond by broadcasting our own best keys
function Automation:OnBestKeysRequested(prefix, message, distribution, sender)
    if prefix ~= BESTKEYS_REQ_PREFIX or distribution ~= "GUILD" then return end
    -- Request M+ data load, then respond after a short delay so the API has time to populate
    C_MythicPlus.RequestMapInfo()
    C_Timer.After(2, function()
        lastBestKeysBroadcast = 0
        self:BroadcastBestKeys()
    end)
end

-- Request best keys from all online guild members
function Automation:RequestBestKeys()
    if not IsInGuild() then return end
    self:SendCommMessage(BESTKEYS_REQ_PREFIX, "req", "GUILD")
end

-- M+ end reminder (only if timed and current key level <= completed level)
function Automation:OnMPlusCompleted()
    local _, level, _, onTime = C_ChallengeMode.GetCompletionInfo()

    -- Only fire if the run was in time
    if not onTime then return end

    -- Only fire if current keystone level is lower or equal to the completed key
    local ownedLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if ownedLevel and ownedLevel > level then return end

    self:ShowKeyReminder()

    -- Broadcast updated best keys after completing a dungeon
    lastBestKeysBroadcast = 0
    self:BroadcastBestKeys()
end

function Automation:ShowKeyReminder()
    if not self.keyReminderFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints()
        f:SetFrameStrata("FULLSCREEN_DIALOG")

        local text = f:CreateFontString(nil, "OVERLAY")
        text:SetFont("Interface\\AddOns\\VesperGuild\\Media\\Expressway.ttf", 60, "OUTLINE")
        text:SetPoint("CENTER", 0, 200)
        text:SetText("|cffFFFF00DID YOU WANT TO CHANGE KEYS?|r")
        f.text = text

        f:Hide()
        self.keyReminderFrame = f
    end

    self.keyReminderFrame:Show()
    C_Timer.After(10, function()
        if self.keyReminderFrame then
            self.keyReminderFrame:Hide()
        end
    end)
end

-- Manual sync (call from a button or slash command)
function Automation:ManualSync()
    lastIlvlBroadcast = 0
    lastBestKeysBroadcast = 0
    self:BroadcastIlvl()
    self:BroadcastBestKeys()
    self:RequestBestKeys()
    VesperGuild:Print("Sync broadcasted to guild.")
end
