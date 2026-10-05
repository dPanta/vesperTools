local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local CharacterIdentity = vesperTools:NewModule("CharacterIdentity", "AceEvent-3.0")

-- Character services can leave multiple GUIDs for the same name/realm. Reconcile
-- the shared character list, rather than hiding duplicate rows in the key panel.
local function nameKey(fullName)
    if type(fullName) ~= "string" then return nil end
    local name, realm = strtrim(fullName):match("^([^-]+)%-(.+)$")
    if not name or strtrim(name) == "" then return nil end
    realm = realm:gsub("%s+", "")
    if realm == "" then return nil end
    return string.lower(strtrim(name) .. "-" .. realm)
end

local function recordNameKey(record)
    local fullNameKey = nameKey(record.fullName)
    local fieldsKey
    if type(record.name) == "string" and type(record.realm) == "string" then
        fieldsKey = nameKey(record.name .. "-" .. record.realm)
    end
    if fullNameKey and fieldsKey and fullNameKey ~= fieldsKey then return nil end
    return fullNameKey or fieldsKey
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function getStores(global)
    return {
        { name = "bags", records = global.charactersByGUID },
        { name = "bank", records = global.bank and global.bank.charactersByGUID },
        { name = "vault", records = global.vault and global.vault.charactersByGUID },
    }
end

local function getLiveIdentity()
    local guid = UnitGUID("player")
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    local _, _, classID = UnitClass("player")
    if type(guid) ~= "string" or not guid:match("^Player%-")
        or type(name) ~= "string" or type(realm) ~= "string"
        or not classID then
        return nil
    end
    local fullName = name .. "-" .. realm
    local key = nameKey(fullName)
    if not key then return nil end
    return key, {
        guid = guid, name = name, realm = realm, fullName = fullName,
        classID = classID, faction = UnitFactionGroup("player"),
    }
end

-- Dry runs and cleanup use the same plan. Missing/tied timestamps, conflicting
-- classes, and GUIDs associated with multiple names are deliberately left alone.
function CharacterIdentity:BuildCleanupPlan(global)
    local groups, namesByGUID = {}, {}
    for _, store in ipairs(getStores(global)) do
        if type(store.records) == "table" then
            for guid, record in pairs(store.records) do
                local key = type(record) == "table" and recordNameKey(record) or nil
                if key and type(guid) == "string" then
                    groups[key] = groups[key] or {}
                    local group = groups[key]
                    local identity = group[guid] or { guid = guid, lastSeen = 0 }
                    group[guid] = identity
                    namesByGUID[guid] = namesByGUID[guid] or {}
                    namesByGUID[guid][key] = true
                    local classID = tonumber(record.classID)
                    if not classID or classID <= 0
                        or (record.guid and record.guid ~= guid)
                        or (identity.classID and identity.classID ~= classID) then
                        identity.conflict = true
                    end
                    identity.classID = classID
                    local seen = tonumber(record.lastSeen) or 0
                    if seen ~= seen or seen == math.huge or seen == -math.huge then
                        identity.conflict = true
                        seen = 0
                    end
                    if not identity.record or seen > identity.lastSeen then
                        identity.lastSeen = seen
                        identity.record = record
                    end
                end
            end
        end
    end

    local liveKey, live = getLiveIdentity()
    if live and groups[liveKey] then
        local identity = groups[liveKey][live.guid] or { guid = live.guid, lastSeen = 0 }
        if identity.classID and identity.classID ~= live.classID then identity.conflict = true end
        identity.classID = live.classID
        identity.record = live
        groups[liveKey][live.guid] = identity
        namesByGUID[live.guid] = namesByGUID[live.guid] or {}
        namesByGUID[live.guid][liveKey] = true
    end

    local plan, skipped = {}, 0
    for key, group in pairs(groups) do
        local count, classID, ambiguous, winner = 0, nil, false, nil
        for guid, identity in pairs(group) do
            count = count + 1
            if identity.conflict or not identity.classID
                or (classID and classID ~= identity.classID) then
                ambiguous = true
            end
            classID = identity.classID
            for otherName in pairs(namesByGUID[guid]) do
                if otherName ~= key then ambiguous = true end
            end
            if not winner or identity.lastSeen > winner.lastSeen then winner = identity end
        end
        if count > 1 then
            if live and key == liveKey then
                winner = group[live.guid]
            else
                for _, identity in pairs(group) do
                    if identity.lastSeen <= 0
                        or (identity ~= winner and identity.lastSeen == winner.lastSeen) then
                        ambiguous = true
                    end
                end
                if not winner.guid:match("^Player%-") then ambiguous = true end
            end
            if ambiguous then
                skipped = skipped + 1
            else
                local duplicates = {}
                for guid in pairs(group) do
                    if guid ~= winner.guid then duplicates[#duplicates + 1] = guid end
                end
                table.sort(duplicates)
                plan[#plan + 1] = { key = key, winner = winner, duplicates = duplicates }
            end
        end
    end
    table.sort(plan, function(a, b) return a.key < b.key end)
    return plan, skipped
end

function CharacterIdentity:ReconcileCharacters(dryRun)
    local db = vesperTools:GetBagsDB()
    if not db or not db.global then return { removed = 0, skipped = 0, changes = {} } end
    local global = db.global
    local plan, skipped = self:BuildCleanupPlan(global)
    local result = { removed = 0, skipped = skipped, changes = plan }
    for _, change in ipairs(plan) do result.removed = result.removed + #change.duplicates end
    if dryRun or result.removed == 0 then return result end

    -- Archive complete original records before changing the active stores. Never
    -- merge inventory counts or overwrite a snapshot belonging to the winning GUID.
    global.characterIdentityArchive = global.characterIdentityArchive or {}
    local replacements = {}
    for _, change in ipairs(plan) do
        local winner = change.winner
        for _, guid in ipairs(change.duplicates) do
            local archive = global.characterIdentityArchive[guid] or { records = {} }
            archive.replacedBy = winner.guid
            archive.archivedAt = time()
            global.characterIdentityArchive[guid] = archive
            replacements[guid] = winner.guid
        end
        for _, store in ipairs(getStores(global)) do
            if type(store.records) == "table" then
                local fallback
                for _, guid in ipairs(change.duplicates) do
                    local record = store.records[guid]
                    if record then
                        global.characterIdentityArchive[guid].records[store.name] = copy(record)
                        if not fallback or (tonumber(record.lastSeen) or 0) > (tonumber(fallback.lastSeen) or 0) then
                            fallback = record
                        end
                    end
                end
                if not store.records[winner.guid] and fallback then
                    local record = copy(fallback)
                    for _, field in ipairs({ "name", "realm", "fullName", "classID", "faction" }) do
                        record[field] = winner.record[field]
                    end
                    record.guid = winner.guid
                    store.records[winner.guid] = record
                end
                for _, guid in ipairs(change.duplicates) do store.records[guid] = nil end
            end
        end
    end

    -- Saved selections can live in any AceDB profile, not just the current one.
    local function updateProfile(profile)
        if type(profile) ~= "table" then return end
        for _, field in ipairs({ "lastViewedCharacterGUID", "lastViewedBankCharacterGUID", "lastViewedVaultCharacterGUID" }) do
            profile[field] = replacements[profile[field]] or profile[field]
        end
    end
    updateProfile(db.profile)
    for _, profile in pairs(db.profiles or {}) do updateProfile(profile) end
    for _, name in ipairs({ "BagsWindow", "BankWindow", "VaultWindow" }) do
        local window = vesperTools:GetModule(name, true)
        if window then
            window.selectedCharacterKey = replacements[window.selectedCharacterKey] or window.selectedCharacterKey
        end
    end

    local bags = vesperTools:GetModule("BagsStore", true)
    if bags then bags:RebuildAccountIndex() end
    vesperTools:SendMessage("VESPERTOOLS_BAGS_INDEX_UPDATED")
    vesperTools:SendMessage("VESPERTOOLS_BANK_CHARACTER_UPDATED")
    vesperTools:SendMessage("VESPERTOOLS_VAULT_CHARACTER_UPDATED")
    vesperTools:SendMessage("VESPERTOOLS_ACCOUNT_KEYSTONE_UPDATED")
    return result
end

function CharacterIdentity:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ReconcileOnLogin")
    self:ReconcileOnLogin()
end

function CharacterIdentity:ReconcileOnLogin()
    self:ReconcileCharacters(false)
end

function CharacterIdentity:ReportCleanup(dryRun)
    local result = self:ReconcileCharacters(dryRun)
    vesperTools:Print(string.format(
        dryRun and "Alt check: %d duplicate identities can be archived; %d ambiguous groups left unchanged."
            or "Alt cleanup: %d duplicate identities archived; %d ambiguous groups left unchanged.",
        result.removed, result.skipped))
    for _, change in ipairs(result.changes) do
        vesperTools:Print(string.format("%s: keep %s; %s %s", change.winner.record.fullName or change.key,
            change.winner.guid, dryRun and "archive" or "archived", table.concat(change.duplicates, ", ")))
    end
end
