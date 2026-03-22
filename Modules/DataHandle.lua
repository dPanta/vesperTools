local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local DataHandle = vesperTools:NewModule("DataHandle")

-- DataHandle responsibilities:
-- 1) Static dungeon metadata lookup (mapID -> portal spell/name).
-- 2) Shared color helpers for key level and rating text.
-- 3) Persistent data accessors for ilvl sync + best-key sync stores.
-- Local database for dungeon information
local dungListDB = nil

-- Canonical dungeon catalog used by portal and roster modules.
-- Note: some dungeons intentionally appear twice with different portal spell IDs.
local dungList = {
        -- Mists of Pandaria (MoP)
        { exp = "MoP", mapID = 2, spellID = 131204, dungeonName = "Temple of the Jade Serpent" },
        
        -- Cataclysm (Cat)
        { exp = "Cat", mapID = 438, spellID = 410080, dungeonName = "The Vortex Pinnacle" },
        { exp = "Cat", mapID = 456, spellID = 424142, dungeonName = "Throne of the Tides" },
        { exp = "Cat", mapID = 507, spellID = 445424, dungeonName = "Grim Batol" },
        
        -- Warlords of Draenor (WoD)
        { exp = "WoD", mapID = 165, spellID = 159899, dungeonName = "Shadowmoon Burial Grounds" },
        { exp = "WoD", mapID = 168, spellID = 159901, dungeonName = "The Everbloom" },
        { exp = "WoD", mapID = 206, spellID = 410078, dungeonName = "Neltharion's Lair" },
        
        -- Legion (Leg)
        { exp = "Leg", mapID = 199, spellID = 424153, dungeonName = "Black Rook Hold" },
        { exp = "Leg", mapID = 200, spellID = 393764, dungeonName = "Halls of Valor" },
        { exp = "Leg", mapID = 210, spellID = 393766, dungeonName = "Court of Stars" },
        { exp = "Leg", mapID = 198, spellID = 424163, dungeonName = "Darkheart Thicket" },
        
        -- Battle for Azeroth (BfA)
        { exp = "BfA", mapID = 244, spellID = 424187, dungeonName = "Atal'Dazar" },
        { exp = "BfA", mapID = 245, spellID = 410071, dungeonName = "Freehold" },
        { exp = "BfA", mapID = 247, spellID = 467553, dungeonName = "The MOTHERLODE!!" },
        { exp = "BfA", mapID = 247, spellID = 467555, dungeonName = "The MOTHERLODE!!" },
        { exp = "BfA", mapID = 248, spellID = 424167, dungeonName = "Waycrest Manor" },
        { exp = "BfA", mapID = 251, spellID = 410074, dungeonName = "The Underrot" },
        { exp = "BfA", mapID = 353, spellID = 464256, dungeonName = "Siege of Boralus" },
        { exp = "BfA", mapID = 353, spellID = 445418, dungeonName = "Siege of Boralus" },
        { exp = "BfA", mapID = 369, spellID = 373274, dungeonName = "Operation: Mechagon - Junkyard" },
        { exp = "BfA", mapID = 370, spellID = 373274, dungeonName = "Operation: Mechagon - Workshop" },
        
        -- Shadowlands (SL)
        { exp = "SL", mapID = 378, spellID = 354465, dungeonName = "Halls of Atonement" },
        { exp = "SL", mapID = 375, spellID = 354464, dungeonName = "Mists of Tirna Scithe" },
        { exp = "SL", mapID = 382, spellID = 354467, dungeonName = "Theater of Pain" },
        { exp = "SL", mapID = 376, spellID = 354462, dungeonName = "The Necrotic Wake" },
        { exp = "SL", mapID = 391, spellID = 367416, dungeonName = "Tazavesh, Streets of Wonder" },
        { exp = "SL", mapID = 392, spellID = 367416, dungeonName = "Tazavesh, Soleah's Gambit" },
        
        -- Dragonflight (DF)
        { exp = "DF", mapID = 399, spellID = 393256, dungeonName = "Ruby Life Pools" },
        { exp = "DF", mapID = 400, spellID = 393262, dungeonName = "The Nokhud Offensive" },
        { exp = "DF", mapID = 401, spellID = 393279, dungeonName = "The Azure Vault" },
        { exp = "DF", mapID = 402, spellID = 393273, dungeonName = "Algeth'ar Academy" },
        { exp = "DF", mapID = 403, spellID = 393222, dungeonName = "Uldaman: Legacy of Tyr" },
        { exp = "DF", mapID = 404, spellID = 393276, dungeonName = "Neltharus" },
        { exp = "DF", mapID = 405, spellID = 393267, dungeonName = "Brackenhide Hollow" },
        { exp = "DF", mapID = 406, spellID = 393283, dungeonName = "Halls of Infusion" },
        { exp = "DF", mapID = 463, spellID = 424197, dungeonName = "Dawn of the Infinite: Galakrond's Fall" },
        { exp = "DF", mapID = 464, spellID = 424197, dungeonName = "Dawn of the Infinite: Murozond's Rise" },
        
        -- The War Within (TWW)
        { exp = "TWW", mapID = 499, spellID = 445444, dungeonName = "Priory of the Sacred Flame" },
        { exp = "TWW", mapID = 500, spellID = 445443, dungeonName = "The Rookery" },
        { exp = "TWW", mapID = 501, spellID = 445269, dungeonName = "The Stonevault" },
        { exp = "TWW", mapID = 502, spellID = 445416, dungeonName = "City of Threads" },
        { exp = "TWW", mapID = 503, spellID = 445417, dungeonName = "Ara-Kara, City of Echoes" },
        { exp = "TWW", mapID = 504, spellID = 445441, dungeonName = "Darkflame Cleft" },
        { exp = "TWW", mapID = 505, spellID = 445414, dungeonName = "The Dawnbreaker" },
        { exp = "TWW", mapID = 506, spellID = 445440, dungeonName = "Cinderbrew Meadery" },
        { exp = "TWW", mapID = 525, spellID = 1216786, dungeonName = "Operation: Floodgate" },
        { exp = "TWW", mapID = 542, spellID = 1237215, dungeonName = "Eco-Dome Al'dani" },
        
        -- Midnight (Mid) - Season 1 portal catalog
        { exp = "Mid", mapID = 161, spellID = 1254557, dungeonName = "Skyreach" },
        { exp = "Mid", mapID = 239, spellID = 1254551, dungeonName = "Seat of the Triumvirate" },
        { exp = "Mid", mapID = 556, spellID = 1254555, dungeonName = "Pit of Saron" },
        { exp = "Mid", mapID = 557, spellID = 1254400, dungeonName = "Windrunner Spire" },
        { exp = "Mid", mapID = 558, spellID = 1254572, dungeonName = "Magisters' Terrace" },
        { exp = "Mid", mapID = 559, spellID = 1254563, dungeonName = "Nexus-Point Xenas" },
        { exp = "Mid", mapID = 560, spellID = 1254559, dungeonName = "Maisara Caverns" },
    }

function DataHandle:OnInitialize()
    -- Initialize the local database
    dungListDB = {}

    -- Build mapID index for O(1) lookup in runtime UI code.
    for _, dungInfo in ipairs(dungList) do
        -- Keep list shape to preserve multiple entries for same mapID if needed.
        if not dungListDB[dungInfo.mapID] then
            dungListDB[dungInfo.mapID] = {}
        end
        table.insert(dungListDB[dungInfo.mapID], dungInfo)
    end
end

function DataHandle:OnEnable()
    -- Module is enabled
end

function DataHandle:GetDungeonList()
    return dungList
end

function DataHandle:GetDungeonByMapID(mapID)
    if dungListDB and dungListDB[mapID] then
        -- Return first configured record as default for consumers expecting one entry.
        return dungListDB[mapID][1] -- Return first match
    end
    return nil
end

function DataHandle:GetSpellIDByMapID(mapID)
    local dungInfo = self:GetDungeonByMapID(mapID)
    return dungInfo and dungInfo.spellID or nil
end

function DataHandle:GetMissingDungeonsForMapIDs(mapIDs)
    local missing = {}
    if type(mapIDs) ~= "table" then
        return missing
    end

    for i = 1, #mapIDs do
        local mapID = tonumber(mapIDs[i])
        if mapID and not self:GetDungeonByMapID(mapID) then
            missing[#missing + 1] = mapID
        end
    end

    return missing
end

function DataHandle:GetDB()
    return dungListDB
end

-- M+ key level coloring (Blizzard API, auto-updates each season)
function DataHandle:GetKeyColor(level)
    local color = C_ChallengeMode.GetKeystoneLevelRarityColor(level)
    if color then
        -- Convert float color components [0..1] to integer hex for "|cffRRGGBB".
        local r = math.floor((color.r or 0) * 255 + 0.5)
        local g = math.floor((color.g or 0) * 255 + 0.5)
        local b = math.floor((color.b or 0) * 255 + 0.5)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cff9d9d9d"
end

-- M+ rating coloring (Blizzard API, auto-updates each season)
function DataHandle:GetRatingColor(rating)
    local color = C_ChallengeMode.GetDungeonScoreRarityColor(rating)
    if color then
        -- Convert float color components [0..1] to integer hex for "|cffRRGGBB".
        local r = math.floor((color.r or 0) * 255 + 0.5)
        local g = math.floor((color.g or 0) * 255 + 0.5)
        local b = math.floor((color.b or 0) * 255 + 0.5)
        return string.format("|cff%02x%02x%02x", r, g, b)
    end
    return "|cff9d9d9d"
end

-- ilvl Sync DB accessors (persistent via AceDB global)
function DataHandle:GetIlvlDB()
    return vesperTools.db.global.ilvlSync
end

function DataHandle:StoreIlvl(playerName, ilvl, classID)
    if not vesperTools.db.global.ilvlSync then
        vesperTools.db.global.ilvlSync = {}
    end
    -- Timestamp supports stale-data cleanup and optional freshness UI.
    vesperTools.db.global.ilvlSync[playerName] = {
        ilvl = ilvl,
        classID = classID,
        timestamp = time(),
    }
end

function DataHandle:GetIlvlForPlayer(playerName)
    local db = vesperTools.db.global.ilvlSync
    if not db or not db[playerName] then
        return nil
    end
    return db[playerName]
end

function DataHandle:CleanupStaleIlvl(maxAge)
    local db = vesperTools.db.global.ilvlSync
    if not db then return end
    maxAge = maxAge or (7 * 24 * 3600) -- default 7 days
    local now = time()
    -- In-place prune to keep SavedVariables bounded over long play sessions.
    for name, data in pairs(db) do
        if not data.timestamp or (now - data.timestamp) > maxAge then
            db[name] = nil
        end
    end
end

-- Best Keys Sync DB accessors (persistent via AceDB global)
function DataHandle:GetBestKeysDB()
    return vesperTools.db.global.bestKeys
end

function DataHandle:StoreBestKeys(playerName, bestKeysData, classID)
    if not vesperTools.db.global.bestKeys then
        vesperTools.db.global.bestKeys = {}
    end
    -- Store metadata on the same object to simplify downstream display logic.
    bestKeysData.timestamp = time()
    bestKeysData.classID = classID
    vesperTools.db.global.bestKeys[playerName] = bestKeysData
end

function DataHandle:GetBestKeysForPlayer(playerName)
    local db = vesperTools.db.global.bestKeys
    if not db or not db[playerName] then
        return nil
    end
    return db[playerName]
end

function DataHandle:CleanupStaleBestKeys(maxAge)
    local db = vesperTools.db.global.bestKeys
    if not db then return end
    maxAge = maxAge or (7 * 24 * 3600) -- default 7 days
    local now = time()
    -- Remove outdated rows so guild-best tooltips prioritize recent season data.
    for name, data in pairs(db) do
        if data.timestamp and (now - data.timestamp) > maxAge then
            db[name] = nil
        end
    end
end
