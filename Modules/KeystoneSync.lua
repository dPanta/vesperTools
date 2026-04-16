local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local KeystoneSync = vesperTools:NewModule("KeystoneSync", "AceEvent-3.0")
local LibKeystone = LibStub("LibKeystone")
local L = vesperTools.L

-- KeystoneSync responsibilities:
-- 1) Receive guild keystone payloads from LibKeystone.
-- 2) Normalize/store data in AceDB global keystone table.
-- 3) Provide formatted display text for roster cells.
local cachedRealmName = nil

-- Dungeon abbreviation lookup for the current Midnight Season 1 rotation.
local DUNGEON_ABBREV = {
    [161] = "SR",                   -- Skyreach
    [239] = "SEAT",                 -- Seat of the Triumvirate
    [402] = "AA",                   -- Algeth'ar Academy
    [556] = "POS",                  -- Pit of Saron
    [557] = "WS",                   -- Windrunner Spire
    [558] = "MGT",                  -- Magisters' Terrace
    [559] = "NPX",                  -- Nexus-Point Xenas
    [560] = "MAIS",                 -- Maisara Caverns
}

local function getOwnedKeystoneLevel()
    if not C_MythicPlus or type(C_MythicPlus.GetOwnedKeystoneLevel) ~= "function" then
        return nil
    end

    local rawLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    local level = tonumber(rawLevel)
    if level and level > 0 then
        return math.floor(level + 0.5)
    end

    return nil
end

local function getOwnedKeystoneMapID()
    if not C_MythicPlus then
        return nil
    end

    if type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function" then
        local rawMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local mapID = tonumber(rawMapID)
        if mapID and mapID > 0 then
            return math.floor(mapID + 0.5)
        end
    end

    if type(C_MythicPlus.GetOwnedKeystoneMapID) == "function" then
        local rawMapID = C_MythicPlus.GetOwnedKeystoneMapID()
        local mapID = tonumber(rawMapID)
        if mapID and mapID > 0 then
            return math.floor(mapID + 0.5)
        end
    end

    return nil
end

function KeystoneSync:OnEnable()
    -- Register LibKeystone callback for receiving keystone data
    if LibKeystone then
        -- LibKeystone invokes this callback whenever compatible data arrives.
        LibKeystone.Register(self, function(keyLevel, keyChallengeMapID, playerRating, sender, channel)
            self:OnLibKeystoneReceived(keyLevel, keyChallengeMapID, playerRating, sender, channel)
        end)
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")

    -- Clean up old entries on login
    self:CleanupStaleEntries()
    self:UpdateCurrentCharacterKeystoneSnapshot()
end

function KeystoneSync:DebugDumpKeystones()
    if not vesperTools.db.global.keystones then
        vesperTools:Print(L["KEYSTONE_DATABASE_EMPTY"])
        return
    end

    vesperTools:Print(L["KEYSTONE_DATABASE_HEADER"])
    local count = 0
    for playerName, data in pairs(vesperTools.db.global.keystones) do
        local ratingText = data.rating and string.format(L["KEYSTONE_RATING_FMT"], data.rating) or ""
        vesperTools:Print(string.format(L["KEYSTONE_DATABASE_ENTRY_FMT"],
            playerName,
            self:GetDungeonAbbrev(data.mapID),
            data.level,
            ratingText,
            time() - data.timestamp))
        count = count + 1
    end
    vesperTools:Print(string.format(L["KEYSTONE_DATABASE_TOTAL_FMT"], count))
end

function KeystoneSync:OnDisable()
    -- Unregister from LibKeystone
    if LibKeystone then
        LibKeystone.Unregister(self)
    end

    self:UnregisterAllEvents()
end

-- LibKeystone callback handler
function KeystoneSync:OnLibKeystoneReceived(keyLevel, keyChallengeMapID, playerRating, sender, channel)
    -- Only process guild messages (you can add PARTY if needed)
    if channel ~= "GUILD" then
        return
    end

    -- Normalize sender name (add realm if missing)
    if not string.find(sender, "-") then
        cachedRealmName = cachedRealmName or GetNormalizedRealmName()
        sender = sender .. "-" .. cachedRealmName
    end

    -- LibKeystone uses -1 for hidden/unavailable values; treat as "no key".
    if keyLevel == -1 or keyChallengeMapID == -1 then
        self:StoreKeystone(sender, 0, 0, playerRating)
    else
        self:StoreKeystone(sender, keyChallengeMapID, keyLevel, playerRating)
    end

    -- Notify UI listeners to repaint displayed key info.
    vesperTools:SendMessage("VESPERTOOLS_KEYSTONE_UPDATE", sender)
end

-- Request keystones from guild using LibKeystone
function KeystoneSync:RequestGuildKeystones()
    if not LibKeystone then
        vesperTools:Print(L["LIBKEYSTONE_NOT_LOADED"])
        return false
    end

    if not IsInGuild() then
        vesperTools:Print(L["PLAYER_NOT_IN_GUILD"])
        return false
    end

    -- Request keystones from guild members
    -- This will trigger all guild members running LibKeystone to respond with their keystone data
    LibKeystone.Request("GUILD")

    vesperTools:Print(L["REQUESTING_KEYSTONES"])
    return true
end

-- Persist one player's active guild key snapshot into the shared DB.
function KeystoneSync:StoreKeystone(playerName, mapID, level, rating)
    if not vesperTools.db.global.keystones then
        vesperTools.db.global.keystones = {}
    end

    if mapID == 0 or level == 0 then
        -- Remove entry so callers can treat missing row as "no key".
        vesperTools.db.global.keystones[playerName] = nil
    else
        vesperTools.db.global.keystones[playerName] = {
            mapID = mapID,
            level = level,
            rating = rating or 0,  -- Store M+ rating, default to 0 if not provided
            timestamp = time()
        }
    end
end

function KeystoneSync:GetAccountKeystoneDB()
    vesperTools.db.global.accountKeystones = vesperTools.db.global.accountKeystones or {}
    return vesperTools.db.global.accountKeystones
end

function KeystoneSync:StoreAccountKeystone(playerName, mapID, level)
    local normalizedName = vesperTools:NormalizePlayerFullName(playerName)
    if not normalizedName then
        return false
    end

    local db = self:GetAccountKeystoneDB()
    local numericMapID = tonumber(mapID)
    local numericLevel = tonumber(level)

    if not numericMapID or numericMapID <= 0 or not numericLevel or numericLevel <= 0 then
        if db[normalizedName] ~= nil then
            db[normalizedName] = nil
            vesperTools:SendMessage("VESPERTOOLS_ACCOUNT_KEYSTONE_UPDATED", normalizedName)
            return true
        end
        return false
    end

    numericMapID = math.floor(numericMapID + 0.5)
    numericLevel = math.floor(numericLevel + 0.5)

    local existing = db[normalizedName]
    if existing
        and existing.mapID == numericMapID
        and existing.level == numericLevel
    then
        existing.timestamp = time()
        return false
    end

    db[normalizedName] = {
        mapID = numericMapID,
        level = numericLevel,
        timestamp = time(),
    }

    vesperTools:SendMessage("VESPERTOOLS_ACCOUNT_KEYSTONE_UPDATED", normalizedName)
    return true
end

function KeystoneSync:GetStoredAccountKeystone(playerName)
    local db = self:GetAccountKeystoneDB()
    local normalizedName = vesperTools:NormalizePlayerFullName(playerName)
    if normalizedName and db[normalizedName] then
        return db[normalizedName]
    end

    local bagsStore = vesperTools:GetModule("BagsStore", true)
    if not bagsStore or type(bagsStore.ResolveCharacterBagSnapshot) ~= "function" then
        return nil
    end

    local _, snapshot = bagsStore:ResolveCharacterBagSnapshot(playerName)
    if type(snapshot) ~= "table" then
        return nil
    end

    local candidates = {}
    local seen = {}
    local function addCandidate(name)
        local normalizedCandidate = vesperTools:NormalizePlayerFullName(name)
        if not normalizedCandidate or seen[normalizedCandidate] then
            return
        end

        seen[normalizedCandidate] = true
        candidates[#candidates + 1] = normalizedCandidate
    end

    addCandidate(snapshot.fullName)
    if type(snapshot.name) == "string" and snapshot.name ~= "" then
        local realm = type(snapshot.realm) == "string" and strtrim(snapshot.realm) or ""
        if realm ~= "" then
            addCandidate(string.format("%s-%s", snapshot.name, realm))
        end
        addCandidate(snapshot.name)
    end

    for index = 1, #candidates do
        local stored = db[candidates[index]]
        if stored then
            return stored
        end
    end

    return nil
end

function KeystoneSync:UpdateCurrentCharacterKeystoneSnapshot()
    local playerName = vesperTools:GetCurrentCharacterFullName()
    local level = getOwnedKeystoneLevel()
    local mapID = getOwnedKeystoneMapID()

    if not level or level <= 0 or not mapID or mapID <= 0 then
        return self:StoreAccountKeystone(playerName, 0, 0)
    end

    return self:StoreAccountKeystone(playerName, mapID, level)
end

function KeystoneSync:PLAYER_ENTERING_WORLD()
    self:UpdateCurrentCharacterKeystoneSnapshot()
end

function KeystoneSync:BAG_UPDATE_DELAYED()
    self:UpdateCurrentCharacterKeystoneSnapshot()
end

function KeystoneSync:CHALLENGE_MODE_COMPLETED()
    if C_Timer and C_Timer.After then
        C_Timer.After(1.0, function()
            self:UpdateCurrentCharacterKeystoneSnapshot()
        end)
        return
    end

    self:UpdateCurrentCharacterKeystoneSnapshot()
end

function KeystoneSync:GetKeystoneForPlayer(playerName)
    if not vesperTools.db.global.keystones then
        return nil
    end
    
    local data = vesperTools.db.global.keystones[playerName]
    if not data then
        return nil
    end
    
    -- Hard-expire entries older than 48h to avoid showing dead data.
    if not data.timestamp then
        vesperTools.db.global.keystones[playerName] = nil
        return nil
    end

    local age = time() - data.timestamp
    if age > (48 * 3600) then
        vesperTools.db.global.keystones[playerName] = nil
        return nil
    end
    
    -- Soft-stale marker used only for display hint in roster cell.
    local isStale = age > (2 * 3600)
    
    local abbrev = self:GetDungeonAbbrev(data.mapID)
    local display = string.format("%s +%d", abbrev, data.level)
    
    if isStale then
        display = display .. " ⏰"
    end
    
    return display
end

-- Convert seasonal mapIDs into compact roster labels.
function KeystoneSync:GetDungeonAbbrev(mapID)
    -- Prefer explicit curated abbreviations for consistency.
    if DUNGEON_ABBREV[mapID] then
        return DUNGEON_ABBREV[mapID]
    end
    
    -- Fallback: derive abbreviation from dungeon name initials.
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        -- Try to create abbreviation from first letters
        local abbrev = ""
        for word in string.gmatch(name, "%S+") do
            abbrev = abbrev .. string.sub(word, 1, 1):upper()
        end
        return abbrev
    end
    
    return L["KEYSTONE_UNKNOWN_ABBREV"] -- Unknown dungeon
end

-- Drop stale keystone entries so offline characters do not linger forever.
function KeystoneSync:CleanupStaleEntries()
    if not vesperTools.db.global.keystones then
        return
    end
    
    local now = time()
    local removed = 0
    
    -- In-place cleanup keeps saved data lean and avoids stale roster rows.
    for playerName, data in pairs(vesperTools.db.global.keystones) do
        if not data.timestamp or (now - data.timestamp) > (48 * 3600) then
            vesperTools.db.global.keystones[playerName] = nil
            removed = removed + 1
        end
    end
    
    if removed > 0 then
        vesperTools:Print(string.format(L["CLEANED_STALE_KEYSTONE_ENTRIES_FMT"], removed))
    end
end
