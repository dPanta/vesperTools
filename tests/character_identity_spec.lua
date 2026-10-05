-- Standalone regression suite: lua tests/character_identity_spec.lua
-- Optional SavedVariables path replays cleanup in memory without writing it.
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
strtrim = function(s) return s:match('^%s*(.-)%s*$') end
time = function() return 10000 end
local liveGUID, liveName, liveClass = 'Player-1-current', 'Current', 1
UnitGUID = function() return liveGUID end
UnitName = function() return liveName end
UnitClass = function() return 'Warrior', 'WARRIOR', liveClass end
UnitFactionGroup = function() return 'Alliance' end
GetNormalizedRealmName = function() return 'Realm' end
GetRealmName = GetNormalizedRealmName
LibStub = function() return {} end
local modules, events, messages = {}, {}, {}
local db
vesperTools = { L = setmetatable({}, { __index = function(_, k) return k end }), db = {global = {}} }
function vesperTools:NewModule(name)
    local module = {}
    function module:RegisterEvent(event, handler) events[event] = handler end
    modules[name] = module
    return module
end
function vesperTools:GetModule(name) return modules[name] end
function vesperTools:GetBagsDB() return db end
function vesperTools:GetBagsProfile() return db.profile end
function vesperTools:GetCurrentCharacterGUID() return liveGUID end
function vesperTools:GetCurrentCharacterFullName() return liveName .. '-Realm' end
function vesperTools:NormalizePlayerFullName(name) return name end
function vesperTools:SendMessage(name) messages[#messages + 1] = name end
function vesperTools:Print() end
dofile('Modules/CharacterIdentity.lua')
dofile('Modules/BagsStore.lua')
dofile('Modules/KeystoneSync.lua')
assert(loadfile('Modules/Portals.lua'))('vesperTools', { AddonServices = {} })
local identity, bags, portals = modules.CharacterIdentity, modules.BagsStore, modules.Portals
local function reset()
    db = { global = { schemaVersion = 7, charactersByGUID = {},
        bank = {charactersByGUID = {}, warband = { untouched = true }},
        vault = {charactersByGUID = {}}, itemMeta = {} }, profile = {}, profiles = {} }
    messages = {}
    liveGUID, liveName, liveClass = 'Player-1-current', 'Current', 1
    vesperTools.db.global = {accountKeystones = {['Alt-Realm'] = {mapID=161, level=10, rating=2200, timestamp=90}}}
end
local function record(guid, name, seen, classID, count)
    return {guid=guid, fullName=name, lastSeen=seen, classID=classID or 1, faction='Horde',
        carried={bags={}, itemTotals={[100]=count or 1}, categoryTotals={misc=count or 1},
            categoryItems={misc={[100]=count or 1}}}}
end
local old, new = 'Player-1-old', 'Player-1-new'
local function seed()
    db.global.charactersByGUID[old] = record(old, 'Alt-Realm', 10, 1, 7)
    db.global.charactersByGUID[new] = record(new, 'Alt-Realm', 20, 1, 3)
    db.global.charactersByGUID[new].faction = 'Alliance'
    db.global.bank.charactersByGUID[old] = record(old, 'Alt-Realm', 11)
    db.global.bank.charactersByGUID[old].bank = {bags={[6]={size=1}}, lastSeen=9}
    db.global.vault.charactersByGUID[old] = record(old, 'Alt-Realm', 12)
    db.global.vault.charactersByGUID[new] = record(new, 'Alt-Realm', 21)
    db.global.vault.charactersByGUID[new].faction = 'Alliance'
    db.global.vault.charactersByGUID[new].vault = {current = true}
end

reset()
seed()
db.profile.lastViewedCharacterGUID = old
db.profiles.other = {lastViewedBankCharacterGUID=old, lastViewedVaultCharacterGUID=old}
modules.BagsWindow = {selectedCharacterKey=old}
eq(#portals:BuildAccountKeystoneRows(), 2, 'reproduce duplicate key/rating rows')
local preview = identity:ReconcileCharacters(true)
eq(preview.removed, 1, 'preview detects old GUID')
eq(preview.changes[1].winner.guid, new, 'latest observation across stores wins')
eq(db.global.charactersByGUID[old] ~= nil, true, 'preview keeps original')
eq(db.global.characterIdentityArchive, nil, 'preview creates no archive')
eq(#messages, 0, 'preview sends no updates')
local winner = db.global.charactersByGUID[new]
local keySnapshot = vesperTools.db.global.accountKeystones['Alt-Realm']
local result = identity:ReconcileCharacters(false)
eq(result.removed, 1, 'cleanup removes one identity across stores')
eq(db.global.charactersByGUID[old], nil, 'old bags removed')
eq(db.global.bank.charactersByGUID[old], nil, 'old bank removed')
eq(db.global.vault.charactersByGUID[old], nil, 'old vault removed')
eq(db.global.charactersByGUID[new], winner, 'winner snapshot kept intact')
eq(db.global.bank.charactersByGUID[new].bank.lastSeen, 9, 'missing bank snapshot migrated without fake freshness')
eq(db.global.bank.charactersByGUID[new].guid, new, 'migrated snapshot uses current GUID')
eq(db.global.bank.charactersByGUID[new].faction, 'Alliance', 'migrated snapshot uses current faction')
eq(db.global.vault.charactersByGUID[new].vault.current, true, 'current vault preserved')
eq(db.global.accountIndex.itemTotals[100], 3, 'duplicate inventory excluded from totals')
eq(db.global.accountIndex.itemOwners[100][old], nil, 'old ownership removed')
eq(db.global.accountIndex.itemOwners[100][new], 3, 'current ownership retained')
eq(db.global.characterIdentityArchive[old].records.bags.carried.itemTotals[100], 7, 'original bags archived')
eq(db.global.characterIdentityArchive[old].records.bank.guid, old, 'original bank identity archived')
eq(db.global.characterIdentityArchive[old].records.bank.faction, 'Horde', 'original faction archived')
db.global.bank.charactersByGUID[new].bank.lastSeen = 100
eq(db.global.characterIdentityArchive[old].records.bank.bank.lastSeen, 9, 'archive independent of migrated snapshot')
eq(db.global.characterIdentityArchive[old].replacedBy, new, 'archive tracks replacement')
eq(db.profile.lastViewedCharacterGUID, new, 'current profile selection remapped')
eq(db.profiles.other.lastViewedBankCharacterGUID, new, 'inactive profile bank selection remapped')
eq(db.profiles.other.lastViewedVaultCharacterGUID, new, 'inactive profile vault selection remapped')
eq(modules.BagsWindow.selectedCharacterKey, new, 'open window selection remapped')
eq(db.global.bank.warband.untouched, true, 'warband untouched')
eq(vesperTools.db.global.accountKeystones['Alt-Realm'], keySnapshot, 'key/rating snapshot retained')
eq(#portals:BuildAccountKeystoneRows(), 1, 'account panel now has one row')
eq(#messages, 4, 'affected windows notified')
eq(identity:ReconcileCharacters(false).removed, 0, 'cleanup idempotent')
eq(#messages, 4, 'second pass sends no changes')

reset()
seed()
db.global.charactersByGUID[new].lastSeen = 10
db.global.vault.charactersByGUID[new].lastSeen = 12
eq(identity:ReconcileCharacters(true).skipped, 1, 'timestamp tie kept')
reset()
db.global.charactersByGUID[old] = record(old, 'Alt-Realm', nil)
db.global.charactersByGUID[new] = record(new, 'Alt-Realm', 20)
eq(identity:ReconcileCharacters(true).skipped, 1, 'missing old timestamp kept')
reset()
seed()
db.global.charactersByGUID[new].classID = 2
eq(identity:ReconcileCharacters(true).skipped, 1, 'class conflict kept')
reset()
seed()
db.global.charactersByGUID[old].classID = nil
eq(identity:ReconcileCharacters(true).skipped, 1, 'missing class kept')
reset()
seed()
db.global.bank.charactersByGUID[new] = record(new, 'Other-Realm', 100)
eq(identity:ReconcileCharacters(true).skipped, 1, 'GUID associated with different names kept')
reset()
db.global.charactersByGUID[old] = record(old, 'Alt-Realm', 10)
db.global.charactersByGUID[new] = record(new, 'Alt-OtherRealm', 20)
eq(identity:ReconcileCharacters(false).removed, 0, 'same name across realms kept')
reset()
db.global.charactersByGUID[old] = record(old, 'Pantagrüel-Realm', 10)
db.global.charactersByGUID[new] = record(new, 'Pantagruel-Realm', 20)
eq(identity:ReconcileCharacters(false).removed, 0, 'accented names remain distinct')
reset()
db.global.charactersByGUID[old] = record(old, 'Alt-The Realm', 10)
db.global.charactersByGUID[new] = record(new, 'Alt-TheRealm', 20)
eq(identity:ReconcileCharacters(true).removed, 1, 'realm spaces normalized')
reset()
db.global.charactersByGUID[old] = record(old, 'Alt', 10)
db.global.charactersByGUID[new] = record(new, 'Alt', 20)
eq(identity:ReconcileCharacters(false).removed, 0, 'realm never guessed from short names')
reset()
seed()
db.global.charactersByGUID[old].guid = 'Player-1-unrelated'
eq(identity:ReconcileCharacters(true).skipped, 1, 'mismatched record GUID kept')
reset()
seed()
db.global.charactersByGUID[old].lastSeen = math.huge
eq(identity:ReconcileCharacters(true).skipped, 1, 'invalid timestamp kept')
reset()
seed()
db.global.charactersByGUID['Player-1-third'] = record('Player-1-third', 'Alt-Realm', 15)
eq(identity:ReconcileCharacters(false).removed, 2, 'multiple superseded identities archived')
eq(db.global.accountIndex.itemTotals[100], 3, 'multiple duplicates excluded from totals')
reset()
db.global.charactersByGUID['name:Alt-Realm'] = record('name:Alt-Realm', 'Alt-Realm', 10)
db.global.charactersByGUID[new] = record(new, 'Alt-Realm', 20)
eq(identity:ReconcileCharacters(false).removed, 1, 'old name fallback reconciled with real GUID')

reset()
liveName, liveGUID = 'Alt', new
db.global.charactersByGUID[old] = record(old, 'Alt-Realm', 100)
db.global.charactersByGUID[new] = record(new, 'Alt-Realm', 10)
eq(identity:ReconcileCharacters(false).removed, 1, 'live GUID takes precedence over timestamps')
eq(db.global.charactersByGUID[new].lastSeen, 10, 'live winning snapshot retained')
reset()
liveName, liveGUID = 'Alt', new
db.global.charactersByGUID[old] = record(old, 'Alt-Realm', 100)
identity:OnEnable()
eq(events.PLAYER_ENTERING_WORLD, 'ReconcileOnLogin', 'login check registered')
eq(db.global.charactersByGUID[old], nil, 'new live GUID reconciled before first snapshot')
eq(db.global.charactersByGUID[new].carried.itemTotals[100], 1, 'live migration retains stored inventory')
reset()
liveGUID = nil
seed()
eq(identity:ReconcileCharacters(false).removed, 1, 'offline cleanup works without live GUID')

if arg[1] then
    reset()
    local env = {}
    local chunk
    if _VERSION == 'Lua 5.1' then
        chunk = assert(loadfile(arg[1]))
        setfenv(chunk, env)
    else
        chunk = assert(loadfile(arg[1], 't', env))
    end
    chunk()
    db = assert(env.vesperToolsBagsDB, 'missing vesperToolsBagsDB')
    vesperTools.db = assert(env.vesperToolsDB, 'missing vesperToolsDB')
    local before = #portals:BuildAccountKeystoneRows()
    local replay = identity:ReconcileCharacters(false)
    print('SavedVariables replay (memory only): ' .. replay.removed .. ' identities archived; '
        .. replay.skipped .. ' ambiguous groups; account key rows ' .. before .. ' -> ' .. #portals:BuildAccountKeystoneRows())
    for _, change in ipairs(replay.changes) do
        print(change.key .. ': kept ' .. change.winner.guid .. ', archived ' .. table.concat(change.duplicates, ', '))
    end
    eq(identity:ReconcileCharacters(false).removed, 0, 'saved data cleanup idempotent')
end
print('PASS: ' .. checks .. ' character identity regression checks')
