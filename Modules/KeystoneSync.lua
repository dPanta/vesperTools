local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local KeystoneSync = VesperGuild:NewModule("KeystoneSync", "AceEvent-3.0", "AceTimer-3.0")
local LibKeystone = LibStub("LibKeystone")

-- KeystoneSync responsibilities:
-- 1) Receive guild keystone payloads from LibKeystone.
-- 2) Normalize/store data in AceDB global keystone table.
-- 3) Provide formatted display text for roster cells.
local cachedRealmName = nil

-- Dungeon abbreviation lookup (TWW Season 3 dungeons)
local DUNGEON_ABBREV = {
    -- The War Within Season 3
    [499] = "PRIORY",               -- Priory of Sacred Flame
    [542] = "ECOJUMP",              -- Eco Dome Almahdani
    [378] = "HALLS",                -- Halls of Atonement
    [525] = "FLOOD",                -- Operation Floodgate
    [503] = "ARA",                  -- Ara-Kara
    [392] = "MRGLGL!",              -- Gambit
    [391] = "STREETS",              -- Ulice hrichu
    [505] = "DAWN",                 -- Dawnbreaker
    -- Add more as needed for current season
}

function KeystoneSync:OnEnable()
    -- Register LibKeystone callback for receiving keystone data
    if LibKeystone then
        -- LibKeystone invokes this callback whenever compatible data arrives.
        LibKeystone.Register(self, function(keyLevel, keyChallengeMapID, playerRating, sender, channel)
            self:OnLibKeystoneReceived(keyLevel, keyChallengeMapID, playerRating, sender, channel)
        end)
    end

    -- Clean up old entries on login
    self:CleanupStaleEntries()
end

function KeystoneSync:DebugDumpKeystones()
    if not VesperGuild.db.global.keystones then
        VesperGuild:Print("Keystone database is empty mon, POPULATE IT!")
        return
    end

    VesperGuild:Print("=== Keystone Database ===")
    local count = 0
    for playerName, data in pairs(VesperGuild.db.global.keystones) do
        local ratingText = data.rating and string.format(" [%d rating]", data.rating) or ""
        VesperGuild:Print(string.format("%s: %s +%d%s (age: %ds)",
            playerName,
            self:GetDungeonAbbrev(data.mapID),
            data.level,
            ratingText,
            time() - data.timestamp))
        count = count + 1
    end
    VesperGuild:Print(string.format("Total: %d keystones", count))
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
    VesperGuild:SendMessage("VESPERGUILD_KEYSTONE_UPDATE", sender)
end

-- Request keystones from guild using LibKeystone
function KeystoneSync:RequestGuildKeystones()
    if not LibKeystone then
        VesperGuild:Print("LibKeystone is not loaded!")
        return false
    end

    if not IsInGuild() then
        VesperGuild:Print("You are not in a guild!")
        return false
    end

    -- Request keystones from guild members
    -- This will trigger all guild members running LibKeystone to respond with their keystone data
    LibKeystone.Request("GUILD")

    VesperGuild:Print("Requesting keystones from guild members...")
    return true
end

function KeystoneSync:StoreKeystone(playerName, mapID, level, rating)
    if not VesperGuild.db.global.keystones then
        VesperGuild.db.global.keystones = {}
    end

    if mapID == 0 or level == 0 then
        -- Remove entry so callers can treat missing row as "no key".
        VesperGuild.db.global.keystones[playerName] = nil
    else
        VesperGuild.db.global.keystones[playerName] = {
            mapID = mapID,
            level = level,
            rating = rating or 0,  -- Store M+ rating, default to 0 if not provided
            timestamp = time()
        }
    end
end

function KeystoneSync:GetKeystoneForPlayer(playerName)
    if not VesperGuild.db.global.keystones then
        return nil
    end
    
    local data = VesperGuild.db.global.keystones[playerName]
    if not data then
        return nil
    end
    
    -- Hard-expire entries older than 48h to avoid showing dead data.
    if not data.timestamp then
        VesperGuild.db.global.keystones[playerName] = nil
        return nil
    end

    local age = time() - data.timestamp
    if age > (48 * 3600) then
        VesperGuild.db.global.keystones[playerName] = nil
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
    
    return "???" -- Unknown dungeon
end

function KeystoneSync:CleanupStaleEntries()
    if not VesperGuild.db.global.keystones then
        return
    end
    
    local now = time()
    local removed = 0
    
    -- In-place cleanup keeps saved data lean and avoids stale roster rows.
    for playerName, data in pairs(VesperGuild.db.global.keystones) do
        if not data.timestamp or (now - data.timestamp) > (48 * 3600) then
            VesperGuild.db.global.keystones[playerName] = nil
            removed = removed + 1
        end
    end
    
    if removed > 0 then
        VesperGuild:Print(string.format("Cleaned up %d stale keystone entries", removed))
    end
end
