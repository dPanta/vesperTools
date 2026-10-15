-- Run from addon root: lua5.1 tests/hearthstone_options_spec.lua
-- Exercise the real core with the legacy item-count global absent on Retail.
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
LibStub = function(name)
    if name == 'AceAddon-3.0' then
        return {NewAddon=function() return {} end}
    end
end
GetItemInfo = function(itemID) return 'Item ' .. itemID end
GetItemInfoInstant = function() return nil, nil, nil, nil, 134400 end
PlayerHasToy = function(itemID) return itemID == 64488 end
assert(loadfile('vesperTools.lua'))('vesperTools', {AddonServices={}})

local count, calls = 1, 0
local function getItemCount(itemID, includeBank, includeUses, includeReagentBank)
    calls = calls + 1
    eq(itemID, 6948, 'only physical hearthstone needs an item count')
    eq(includeBank, true, 'bank searched')
    eq(includeUses, false, 'count items rather than charges')
    eq(includeReagentBank, true, 'reagent bank searched')
    return count
end
GetItemCount = nil
C_Item = {GetItemCount=getItemCount}
local options = vesperTools:GetAvailableHearthstoneOptions()
eq(calls, 1, 'modern API queried with legacy global absent')
eq(#options, 2, 'owned physical hearthstone and toy included')
eq(options[1].itemID, 6948, 'physical hearthstone keeps catalog order')
eq(options[1].isToy, false, 'physical hearthstone classification')
eq(options[1].name, 'Item 6948', 'display metadata preserved')
eq(options[2].itemID, 64488, 'owned toy retained')
eq(options[2].isToy, true, 'toy classification')

GetItemCount = function() error('modern API must take precedence') end
eq(#vesperTools:GetAvailableHearthstoneOptions(), 2, 'modern API preferred when both exist')
count = 0
options = vesperTools:GetAvailableHearthstoneOptions()
eq(#options, 1, 'unowned physical hearthstone omitted')
eq(options[1].itemID, 64488, 'toys independent of physical hearthstone ownership')
count = nil
eq(#vesperTools:GetAvailableHearthstoneOptions(), 1, 'nil count handled')

count = 1
C_Item = {}
GetItemCount = getItemCount
eq(#vesperTools:GetAvailableHearthstoneOptions(), 2, 'legacy fallback with modern method absent')
C_Item = nil
eq(#vesperTools:GetAvailableHearthstoneOptions(), 2, 'legacy fallback with namespace absent')
GetItemCount = nil
options = vesperTools:GetAvailableHearthstoneOptions()
eq(#options, 1, 'missing count APIs do not prevent toy listing')
eq(options[1].itemID, 64488, 'owned toy survives missing count APIs')
print('PASS: ' .. checks .. ' hearthstone option regression checks')
