-- Standalone regression suite: lua tests/bags_bank_spec.lua (from addon root).
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, (label or 'check') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
Enum = {
    ItemClass = { Consumable=0, Container=1, Weapon=2, Gem=3, Armor=4, Reagent=5,
        Tradegoods=7, ItemEnhancement=8, Recipe=9, Miscellaneous=15 },
    ItemConsumableSubclass = { Itemenhancement=6 },
    ItemReagentSubclass = { Keystone=1 },
    BagIndex = { Backpack=0, Bag_1=1, Bag_2=2, Bag_3=3, Bag_4=4, ReagentBag=5,
        CharacterBankTab_1=6, CharacterBankTab_2=7, CharacterBankTab_3=8,
        CharacterBankTab_4=9, CharacterBankTab_5=10, CharacterBankTab_6=11,
        AccountBankTab_1=12, AccountBankTab_2=13, AccountBankTab_3=14,
        AccountBankTab_4=15, AccountBankTab_5=16 },
    BankType = { Character=0, Account=2 },
}
LE_EXPANSION_LEVEL_CURRENT = 11
GetMaxLevelForExpansionLevel = function() return 90 end
strtrim = function(s) return s:match('^%s*(.-)%s*$') end
time = function() return 10000 end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
local callbacks = {}
C_Timer = { After = function(_, f) callbacks[#callbacks + 1] = f end }
local function flush()
    local batch = callbacks
    callbacks = {}
    for _, f in ipairs(batch) do f() end
end
local db = { global = { schemaVersion=7, itemMeta={}, charactersByGUID={} } }
local modules, messages = {}, {}
vesperTools = { L = setmetatable({}, { __index = function(_, k) return k end }) }
function vesperTools:NewModule(name)
    local m = { enabled=true }
    function m:IsEnabled() return self.enabled end
    function m:RegisterEvent() end
    function m:RegisterMessage() end
    modules[name] = m
    return m
end
function vesperTools:GetModule(name) return modules[name] end
function vesperTools:GetBagsDB() return db end
function vesperTools:GetBagsProfile() return {} end
function vesperTools:GetCurrentCharacterGUID() return 'current' end
function vesperTools:NormalizeSearchText(s) return type(s) == 'string' and s:lower() or nil end
function vesperTools:BuildFallbackItemName(id) return 'Item ' .. id end
function vesperTools:GetEquipLocSearchTerms() return '' end
function vesperTools:SendMessage(name, payload)
    messages[#messages + 1] = name
    if name == 'VESPERTOOLS_CONTAINER_ITEM_DATA_READY' then
        modules.BankStore:OnItemDataReady(name, payload)
    end
end
C_Item = { GetItemInfoInstant = function() return nil end }
dofile('Modules/BagsStore.lua')
dofile('Modules/BankStore.lua')
local bags, bank = modules.BagsStore, modules.BankStore
bags:OnInitialize()
bank:OnInitialize()
local cases = {
    { 'old gem reagent', {classID=3, expansionID=1}, {isCraftingReagent=true}, 'enhancements' },
    { 'current gem', {classID=3, expansionID=11}, {}, 'enhancements' },
    { 'permanent enchant', {classID=8, expansionID=11}, {}, 'enhancements' },
    { 'old enchant', {classID=8, expansionID=0}, {}, 'enhancements' },
    { 'temporary weapon enhancement', {classID=0, subClassID=6, expansionID=11}, {}, 'enhancements' },
    { 'enchanting dust', {classID=7, subClassID=12, expansionID=11, isCraftingReagent=true}, {}, 'reagent' },
    { 'potion', {classID=0, subClassID=1, expansionID=11}, {}, 'consumable' },
    { 'enchant recipe', {classID=9, expansionID=11}, {}, 'recipe' },
    { 'localized old-dungeon keystone', {classID=5, subClassID=1, expansionID=6, itemName='Clé mythique'}, {}, 'season' },
    { 'tooltip mentions keystone', {classID=15, expansionID=11, searchText='mythic keystone'}, {}, 'misc' },
    { 'Spark of Tides localized', {classID=7, expansionID=11, itemName='Etincelle'}, {itemID=274476}, 'season' },
    { 'Corrosive Soul', {classID=15, expansionID=11}, {itemID=273000}, 'season' },
    { 'Trovehunter bounty', {classID=0, expansionID=11}, {itemID=274374}, 'season' },
    { 'old bounty', {classID=0, expansionID=10}, {itemID=233071}, 'past_expansions' },
    { 'current legacy dungeon armor', {classID=4, expansionID=6, requiredLevel=90}, {}, 'equipment' },
    { 'old level 80 hero armor', {classID=4, expansionID=10, requiredLevel=80, searchText='upgrade level: hero'}, {}, 'past_expansions' },
    { 'junk from metadata', {classID=15, expansionID=11, quality=0}, {}, 'junk' },
    { 'quest', {classID=15, expansionID=11}, {isQuestItem=true}, 'quest' },
}
for _, case in ipairs(cases) do
    for _, store in ipairs({bags, bank}) do
        eq(store:ResolveCategoryKey(copy(case[2]), case[3], case[3]), case[4], case[1])
    end
end

-- Migration must update offline aggregates without altering stack counts/times.
local gem = {itemID=100, classID=3, expansionID=1, stackCount=7, categoryKey='past_expansions'}
local snapshot = {bags={[0]={size=1, slots={copy(gem)}}}}
db.global.schemaVersion = 6
db.global.charactersByGUID.alt = {carried=copy(snapshot), lastSeen=17}
db.global.bank = {charactersByGUID={alt={bank={bags={[6]={size=1, slots={copy(gem)}}}, lastSeen=18}}},
    warband={bags={[12]={size=1, slots={copy(gem)}}}, lastSeen=19}}
bags:GetGlobalDB()
bank:GetGlobalDB()
eq(db.global.schemaVersion, 7, 'carried migration version')
eq(db.global.charactersByGUID.alt.carried.categoryTotals.enhancements, 7, 'offline carried totals')
eq(db.global.accountIndex.categoryTotals.enhancements, 7, 'offline account totals')
eq(db.global.accountIndex.itemOwners[100].alt, 7, 'ownership survives migration')
eq(db.global.bank.charactersByGUID.alt.bank.categoryTotals.enhancements, 7, 'offline bank totals')
eq(db.global.bank.warband.categoryTotals.enhancements, 7, 'offline warband totals')
eq(db.global.bank.warband.lastSeen, 19, 'migration preserves scan timestamp')
eq(bank:GetCategoryListFromView(db.global.bank.warband)[1].key, 'enhancements', 'bank renders new category')
bags:GetGlobalDB()
bank:GetGlobalDB()
eq(db.global.accountIndex.itemTotals[100], 7, 'migration idempotence')

-- Shared base IDs must not leak scaling/tooltip data between bonus variants.
C_Item.GetItemInfoInstant = function() return nil,nil,nil,'INVTYPE_HEAD',1,4,1 end
C_Item.GetItemInfo = function(ref)
    return 'Helm',ref,4,100,ref == 'current' and 90 or 80,nil,nil,1,'INVTYPE_HEAD',1,0,4,1,1,6,nil,false
end
C_TooltipInfo = {GetBagItem=function(_, slot)
    return {lines={{leftText='Helm'}, {leftText=slot == 1 and 'Current only' or 'Old only'}}}
end}
local current = bags:BuildItemMeta(200, 'current', {}, 0, 1)
local old = bank:BuildItemMeta(200, 'old', {}, 6, 2)
eq(current.requiredLevel, 90, 'current instance level preserved')
eq(old.requiredLevel, 80, 'old instance has own level')
eq(old.itemDescription, 'Old only', 'no tooltip inherited across variants')
eq(current.itemDescription, 'Current only', 'old scan does not mutate returned current meta')
local cached = bags:GetRecordCategoryMeta(db.global, {itemID=200, hyperlink='current', requiredLevel=90, classID=4, expansionID=6})
eq(bags:ResolveCategoryKey(cached, {}, {}), 'equipment', 'migration uses slot variant')

-- Missing data requests deduplicate across bags/banks and commit without bag events.
local requests = 0
C_Item.RequestLoadItemDataByID = function() requests = requests + 1 end
bags:RequestMissingItemData(300, 0)
bags:RequestMissingItemData(300, 1)
bags:RequestMissingItemData(300, 12)
eq(requests, 1, 'one async request across all stores')
bank.bankOpen = true
local bagCommits, bankCommits = 0, 0
local originalBagCommit, originalBankCommit = bags.CommitPendingBagWork, bank.CommitPendingBankWork
bags.CommitPendingBagWork = function(self) bagCommits=bagCommits+1; self:ClearPendingState() end
bank.CommitPendingBankWork = function(self) bankCommits=bankCommits+1; self:ClearPendingState() end
bags:ITEM_DATA_LOAD_RESULT(nil, 300, true)
eq(bags.dirtyBagSet[0], true, 'backpack marked dirty')
eq(bags.dirtyBagSet[1], true, 'second bag marked dirty')
eq(bank.dirtyWarbandBankSet[12], true, 'warband marked dirty')
flush()
eq(bagCommits, 1, 'single carried commit')
eq(bankCommits, 1, 'single bank commit')
bags:RequestMissingItemData(301, 0)
bags:ITEM_DATA_LOAD_RESULT(nil, 301, false)
flush()
eq(bagCommits, 1, 'failed data load does not loop')
bags:RequestMissingItemData(302, 12)
bank:BANKFRAME_CLOSED()
bags:ITEM_DATA_LOAD_RESULT(nil, 302, true)
flush()
eq(bankCommits, 1, 'closed bank not scanned on data completion')

-- An unchanged incremental Warband scan returns false, distinct from failure nil.
bags.CommitPendingBagWork, bank.CommitPendingBankWork = originalBagCommit, originalBankCommit
bank.bankOpen = true
C_Bank = {CanUseBank=function() return true end}
local fullScans = 0
bank.CreateOrUpdateCurrentCharacter = function() return 'current', {bank={bags={}}} end
bank.CommitDirtyView = function() return false end
bank.DoFullWarbandRescan = function() fullScans=fullScans+1; return true end
bank.dirtyWarbandBankSet[12] = true
bank:CommitPendingBankWork()
eq(fullScans, 0, 'unchanged bank does not full-rescan')
bank.CommitDirtyView = function() return nil end
bank.dirtyWarbandBankSet[12] = true
bank:CommitPendingBankWork()
eq(fullScans, 1, 'missing bank snapshot does full-rescan')
C_Bank.CanUseBank = function() error('unavailable') end
eq(bank:CanScanWarband(), false, 'failed bank API never grants live access')
C_Bank.CanUseBank = nil
eq(bank:CanScanWarband(), false, 'missing bank API never grants live access')
C_Bank.CanUseBank = function() return true end
bank:BANK_TAB_SETTINGS_UPDATED(nil, Enum.BankType.Account)
flush()
eq(fullScans, 2, 'tab update commits without BAG_UPDATE_DELAYED')

-- Delta updates preserve other characters and match a full index rebuild.
local altCarried = db.global.charactersByGUID.alt.carried
local before = {itemTotals={[100]=3}, categoryTotals={enhancements=3}, categoryItems={enhancements={[100]=3}}}
local after = {itemTotals={[100]=5}, categoryTotals={enhancements=5}, categoryItems={enhancements={[100]=5}}}
db.global.charactersByGUID.current = {carried=before}
bags:RebuildAccountIndex()
db.global.charactersByGUID.current.carried = after
eq(bags:ApplyCharacterAggregateReplacement('current', before, after), true, 'delta succeeds')
local rebuilt = bags:BuildAccountIndexFromCharacters()
eq(db.global.accountIndex.itemTotals[100], rebuilt.itemTotals[100], 'delta equals rebuilt item totals')
eq(db.global.accountIndex.categoryTotals.enhancements, rebuilt.categoryTotals.enhancements, 'delta equals rebuilt category totals')
eq(db.global.accountIndex.itemOwners[100].alt, altCarried.itemTotals[100], 'delta preserves alt')

-- Exercise an actual dirty carried commit, including index fallback on damage.
local currentCharacter = {carried={bags={[0]={size=1, bagFamily=0, slots={{
    itemID=100, stackCount=3, categoryKey='enhancements', requiredLevel=80,
}}}}}}
local aggregate = bags:BuildAggregatesFromBags(currentCharacter.carried.bags)
for k,v in pairs(aggregate) do currentCharacter.carried[k]=v end
db.global.charactersByGUID.current = currentCharacter
bags:RebuildAccountIndex()
bags.CreateOrUpdateCurrentCharacter = function() return 'current', currentCharacter end
bags.BuildCurrentCurrencySnapshot = function() return {money=0, currencies={}} end
bags.UpdateNewItemTracking = function() end
local nextCount = 5
bags.BuildBagSnapshot = function() return {size=1, bagFamily=0, slots={{
    itemID=100, stackCount=nextCount, categoryKey='enhancements', requiredLevel=90,
}}} end
bags:BAG_UPDATE(nil, 0)
bags:CommitPendingBagWork()
eq(db.global.accountIndex.itemTotals[100], 12, 'real commit preserves seven alt items')
eq(currentCharacter.carried.bags[0].slots[1].requiredLevel, 90, 'real commit saves instance data')
-- A corrupted index must recover from authoritative character snapshots.
db.global.accountIndex.itemTotals[100] = 1
nextCount = 6
bags:BAG_UPDATE(nil, 0)
bags:CommitPendingBagWork()
eq(db.global.accountIndex.itemTotals[100], 13, 'damaged index rebuilt')
for _,store in ipairs({bags,bank}) do
    local a = {size=1, bagFamily=0, slots={{itemID=100, requiredLevel=80}}}
    local b = copy(a)
    b.slots[1].requiredLevel=90
    eq(store:BagSnapshotsEqual(a,b), false, 'metadata-only changes saved')
end

-- Three store broadcasts and a currency event cause one layout pass.
dofile('Modules/BagsWindow.lua')
dofile('Modules/BankWindow.lua')
for _, spec in ipairs({{'BagsWindow','OnBagDataChanged'}, {'BankWindow','OnBankDataChanged'}}) do
    local window = modules[spec[1]]
    local shown, refreshes = true, 0
    window.frame = {IsShown=function() return shown end}
    window.RefreshWindow = function() refreshes=refreshes+1 end
    for _=1,3 do window[spec[2]](window) end
    if window.OnCurrencyDataChanged then window:OnCurrencyDataChanged() end
    eq(refreshes, 0, 'layout deferred')
    flush()
    eq(refreshes, 1, 'broadcasts coalesced')
    window[spec[2]](window)
    shown = false
    flush()
    eq(refreshes, 1, 'hidden window skips queued layout')
end
print('PASS: ' .. checks .. ' bag/bank regression checks')
