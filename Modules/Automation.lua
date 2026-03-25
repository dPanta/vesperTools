local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local Automation = vesperTools:NewModule("Automation", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
local L = vesperTools.L

-- Automation module responsibilities:
-- 1) Guild-wide ilvl + best-key broadcasts (AceComm).
-- 2) Receive and persist guild payloads via DataHandle.
-- 3) Trigger syncs when addon UI opens or when M+ completes.
local ILVL_PREFIX = "VGiLvl"
local BESTKEYS_PREFIX = "VGBestKeys"
local BESTKEYS_REQ_PREFIX = "VGBKReq"
-- Shared cooldown for outgoing broadcasts to avoid chat-throttle spam.
local SYNC_COOLDOWN = 30 -- seconds between broadcasts to avoid spam
-- Incoming "request best keys" spam guard:
-- 1) throttle repeated requests from same sender,
-- 2) coalesce many valid requests into one delayed response broadcast.
local BESTKEYS_REQUEST_COOLDOWN = 15
local BESTKEYS_REQUEST_RESPONSE_DELAY = 2
-- Runtime-only sync throttles and temporary request coalescing state.
local lastIlvlBroadcast = 0
local lastBestKeysBroadcast = 0
local cachedRealmName = nil
local lastBestKeysRequestBySender = {}
local pendingBestKeysRequestResponse = false

local function getChallengeCompletionInfo()
    if C_ChallengeMode and type(C_ChallengeMode.GetChallengeCompletionInfo) == "function" then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if type(info) == "table" then
            return info.mapChallengeModeID, tonumber(info.level), info.time, info.onTime and true or false
        end
    end

    if C_ChallengeMode and type(C_ChallengeMode.GetCompletionInfo) == "function" then
        local mapID, level, duration, onTime = C_ChallengeMode.GetCompletionInfo()
        return mapID, tonumber(level), duration, onTime and true or false
    end

    return nil, nil, nil, false
end

function Automation:OnEnable()
    -- Register all communication channels used by this module.
    -- Register comm prefixes
    self:RegisterComm(ILVL_PREFIX, "OnIlvlReceived")
    self:RegisterComm(BESTKEYS_PREFIX, "OnBestKeysReceived")
    self:RegisterComm(BESTKEYS_REQ_PREFIX, "OnBestKeysRequested")

    -- Use "addon opened" as a practical sync moment when the user expects fresh data.
    self:RegisterMessage("VESPERTOOLS_ADDON_OPENED", "OnAddonOpened")

    -- Listen for M+ completion
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "OnMPlusCompleted")

    -- Warm up Blizzard M+ cache so best-run API is populated before we read it.
    C_MythicPlus.RequestMapInfo()

    self:RegisterChatCommand("vespertest", "TestKeyReminder")

    -- Trim stale SavedVariables entries at startup to keep roster data relevant.
    local DataHandle = vesperTools:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:CleanupStaleIlvl()
        DataHandle:CleanupStaleBestKeys()
    end

    -- Reset runtime-only anti-spam state on module (re)enable.
    lastBestKeysRequestBySender = {}
    pendingBestKeysRequestResponse = false
end

-- Trigger a full guild sync pass when the main addon UI opens.
function Automation:OnAddonOpened()
    -- Full refresh pass: publish local data and request peers to publish theirs.
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

    -- Cooldown gate to avoid sending repeated payloads during quick UI toggles.
    local now = GetTime()
    if (now - lastIlvlBroadcast) < SYNC_COOLDOWN then return end
    lastIlvlBroadcast = now

    local _, ilvl = GetAverageItemLevel()
    -- Keep payload compact and stable for display/sorting.
    ilvl = math.floor(ilvl)

    local _, _, classID = UnitClass("player")

    -- Payload format: "ilvl:classID" (example: "635:11").
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

    -- Parse "ilvl:classID" and ignore malformed payloads gracefully.
    local ilvlStr, classIDStr = strsplit(":", message)
    local ilvl = tonumber(ilvlStr)
    local classID = tonumber(classIDStr)

    if not ilvl then return end

    local DataHandle = vesperTools:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreIlvl(sender, ilvl, classID)
        vesperTools:SendMessage("VESPERTOOLS_ILVL_UPDATE", sender)
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
    -- `parts` holds serialized payload entries, `localBestKeys` is persisted locally.
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
        -- If overtime run has higher level, prefer it for "best level" display.
        if overTimeInfo and overTimeInfo.level and overTimeInfo.level > bestLevel then
            bestLevel = overTimeInfo.level
            bestDuration = overTimeInfo.durationSec
            wasInTime = false
        end
        -- Entry format per dungeon: "mapID:level:duration:inTime(0/1)".
        table.insert(parts, string.format("%d:%d:%d:%d", mapID, bestLevel, bestDuration, wasInTime and 1 or 0))
        if bestLevel > 0 then
            localBestKeys[mapID] = { level = bestLevel, duration = bestDuration, inTime = wasInTime }
        end
    end

    -- Persist own data immediately (guild echo is not guaranteed/timely).
    cachedRealmName = cachedRealmName or GetNormalizedRealmName()
    local playerName = UnitName("player") .. "-" .. cachedRealmName
    local DataHandle = vesperTools:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreBestKeys(playerName, localBestKeys, classID)
    end

    -- Full payload format: "classID;mapID:level:duration:inTime,..."
    local payload = classID .. ";" .. table.concat(parts, ",")
    self:SendCommMessage(BESTKEYS_PREFIX, payload, "GUILD")
end

-- Handle incoming best keys messages from guild members
-- Parse serialized best-key payloads and persist the sender's snapshot.
function Automation:OnBestKeysReceived(prefix, message, distribution, sender)
    if prefix ~= BESTKEYS_PREFIX or distribution ~= "GUILD" then return end

    if not string.find(sender, "-") then
        cachedRealmName = cachedRealmName or GetNormalizedRealmName()
        sender = sender .. "-" .. cachedRealmName
    end

    -- Parse class metadata + per-dungeon entries from serialized payload.
    local classIDStr, dungeonData = strsplit(";", message)
    local classID = tonumber(classIDStr)
    if not dungeonData then return end

    local bestKeys = {}
    for entry in string.gmatch(dungeonData, "[^,]+") do
        -- Each entry is "mapID:level:duration:inTime".
        local mStr, lStr, dStr, iStr = strsplit(":", entry)
        local mapID = tonumber(mStr)
        local level = tonumber(lStr)
        local duration = tonumber(dStr)
        local inTime = iStr == "1"
        if mapID and level and level > 0 then
            bestKeys[mapID] = { level = level, duration = duration, inTime = inTime }
        end
    end

    local DataHandle = vesperTools:GetModule("DataHandle", true)
    if DataHandle then
        DataHandle:StoreBestKeys(sender, bestKeys, classID)
        vesperTools:SendMessage("VESPERTOOLS_BESTKEYS_UPDATE", sender)
    end
end

-- Handle incoming best keys request — respond by broadcasting our own best keys.
-- Requests are throttled per sender and merged into one delayed response.
function Automation:OnBestKeysRequested(prefix, _, distribution, sender)
    if prefix ~= BESTKEYS_REQ_PREFIX or distribution ~= "GUILD" then return end

    local senderName = type(sender) == "string" and sender or ""
    if senderName == "" then
        return
    end

    -- Normalize sender identity so cooldown is stable across clients with/without realm suffix.
    if not string.find(senderName, "-") then
        cachedRealmName = cachedRealmName or GetNormalizedRealmName()
        senderName = senderName .. "-" .. cachedRealmName
    end

    -- Ignore our own request packets; these happen during local sync flows.
    cachedRealmName = cachedRealmName or GetNormalizedRealmName()
    local selfName = UnitName("player") .. "-" .. cachedRealmName
    if senderName == selfName then
        return
    end

    local now = GetTime()
    local lastRequestAt = tonumber(lastBestKeysRequestBySender[senderName]) or 0
    if (now - lastRequestAt) < BESTKEYS_REQUEST_COOLDOWN then
        return
    end
    lastBestKeysRequestBySender[senderName] = now

    -- Keep sender throttle table bounded by pruning stale entries opportunistically.
    for name, ts in pairs(lastBestKeysRequestBySender) do
        if (now - (tonumber(ts) or 0)) > (BESTKEYS_REQUEST_COOLDOWN * 4) then
            lastBestKeysRequestBySender[name] = nil
        end
    end

    -- If a response timer is already pending, the current request is already covered.
    if pendingBestKeysRequestResponse then
        return
    end

    pendingBestKeysRequestResponse = true
    -- Request M+ data load, then respond after a short delay so APIs have time to populate.
    C_MythicPlus.RequestMapInfo()
    C_Timer.After(BESTKEYS_REQUEST_RESPONSE_DELAY, function()
        pendingBestKeysRequestResponse = false
        lastBestKeysBroadcast = 0
        self:BroadcastBestKeys()
    end)
end

-- Request best keys from all online guild members
function Automation:RequestBestKeys()
    if not IsInGuild() then return end
    -- Lightweight "pull" request; peers answer with BESTKEYS_PREFIX payload.
    self:SendCommMessage(BESTKEYS_REQ_PREFIX, "req", "GUILD")
end

-- M+ end reminder (only if timed and current key level <= completed level)
function Automation:OnMPlusCompleted()
    local _, level, _, onTime = getChallengeCompletionInfo()

    if not level then
        return
    end

    -- Only fire if the run was in time
    if not onTime then return end

    -- Only fire if the newly completed run could plausibly replace current key.
    local ownedLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if ownedLevel and ownedLevel > level then return end

    self:ShowKeyReminder()

    -- Force immediate post-run publish by bypassing cooldown.
    lastBestKeysBroadcast = 0
    self:BroadcastBestKeys()
end

-- Show a temporary fullscreen reminder that the run may have upgraded the active key.
function Automation:ShowKeyReminder()
    if not self.keyReminderFrame then
        -- Lazy-create fullscreen overlay once; reuse for later reminders.
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetAllPoints()
        f:SetFrameStrata("FULLSCREEN_DIALOG")

        local text = f:CreateFontString(nil, "OVERLAY")
        text:SetFont("Interface\\AddOns\\vesperTools\\Media\\expressway.ttf", 60, "OUTLINE")
        text:SetPoint("CENTER", 0, 200)
        text:SetText("|cffFFFF00" .. L["KEY_REMINDER_TEXT"] .. "|r")
        f.text = text

        f:Hide()
        self.keyReminderFrame = f
    end

    self.keyReminderFrame:Show()
    -- Auto-hide reminder so it never becomes sticky across combat/scene changes.
    C_Timer.After(10, function()
        if self.keyReminderFrame then
            self.keyReminderFrame:Hide()
        end
    end)
end

-- Manual sync path used by buttons or slash commands.
function Automation:ManualSync()
    -- Reset cooldown gates so manual request always publishes immediately.
    lastIlvlBroadcast = 0
    lastBestKeysBroadcast = 0
    self:BroadcastIlvl()
    self:BroadcastBestKeys()
    self:RequestBestKeys()
    vesperTools:Print(L["SYNC_BROADCASTED_MESSAGE"])
end
