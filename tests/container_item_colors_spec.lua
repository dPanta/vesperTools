-- Run from addon root: lua tests/container_item_colors_spec.lua
-- Reuse the UI/combat fixtures and exercise the shared bag/bank controller.
dofile('tests/bags_combat_spec.lua')
local checks = 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function colorText(r, g, b)
    return string.format('%.2f,%.2f,%.2f', r, g, b)
end
local controller = vesperTools:CreateContainerItemController({}, {
    shouldUseNativeOverlay=function() return false end,
})
local upgradeInfo, queriedLink
C_Item.GetItemUpgradeInfo = function(link)
    queriedLink = link
    return upgradeInfo
end
ColorManager = {GetColorDataForBagItemQuality=function(quality)
    if quality == 1 then return {r=0.6,g=0.6,b=0.6} end
    if quality == 4 then return {r=0.64,g=0.21,b=0.93} end
end}
ITEM_QUALITY_COLORS[3] = {r=0,g=0.44,b=0.87}
local record = {itemID=100, hyperlink='item:100:hero', classID=4, quality=4, stackCount=1}
local function color() return colorText(controller:GetItemColorForRecord(record)) end
for _, case in ipairs({
    {'Explorer', '0.62,0.62,0.62'},
    {'Adventurer', '1.00,1.00,1.00'},
    {'Veteran', '0.12,1.00,0.00'},
    {'Champion', '0.00,0.44,0.87'},
    {'Hero', '1.00,0.30,1.00'},
    {'Myth', '1.00,0.50,0.00'},
}) do
    upgradeInfo = {trackString=case[1], currentLevel=6, maxLevel=6}
    eq(color(), case[2], case[1] .. ' capped track')
end
upgradeInfo = {trackString='Héros'}
eq(color(), '1.00,0.30,1.00', 'localized French Hero')
upgradeInfo = {trackString='神話'}
eq(color(), '1.00,0.50,0.00', 'localized traditional Chinese Myth')
upgradeInfo = {trackString='Myth'}
record.hyperlink='item:100:myth'
record.bagID,record.slotID=0,1
eq(color(), '1.00,0.50,0.00', 'same base ID different track')
eq(queriedLink, record.hyperlink, 'saved records use full link rather than live slot or base ID')
record.classID=2
eq(color(), '1.00,0.50,0.00', 'weapons use track color')
record.classID=0
eq(color(), '0.64,0.21,0.93', 'non-equipment keeps rarity color')
record.classID=4
upgradeInfo={trackString='Unknown future track'}
eq(color(), '0.64,0.21,0.93', 'unknown track keeps rarity')
upgradeInfo=nil
eq(color(), '0.64,0.21,0.93', 'untracked gear keeps rarity')
record.quality=1
eq(color(), '0.60,0.60,0.60', 'Blizzard bag color accessor used')
record.quality=3
eq(color(), '0.00,0.44,0.87', 'rarity table fallback if no bag color')
record.quality=4
record.hyperlink=nil
queriedLink=nil
eq(color(), '0.64,0.21,0.93', 'missing link keeps rarity')
eq(queriedLink,nil,'missing link does not resolve an ambiguous base ID')
local function bonusLink(count, bonuses)
    return 'item:100:0:0:0:0:0:0:0:90:0:0:0:' .. count .. ':' .. bonuses
end
record.hyperlink=bonusLink(1,'13835')
eq(color(), '1.00,0.30,1.00', 'crafted Hero crest')
record.hyperlink=bonusLink(2,'999:13836')
eq(color(), '1.00,0.50,0.00', 'crafted Myth crest after another bonus')
record.hyperlink=bonusLink(1,'999:13836')
eq(color(), '0.64,0.21,0.93', 'tail numbers are not crest bonuses')
record.hyperlink='item:100:13836'
eq(color(), '0.64,0.21,0.93', 'enchant field is not a crest bonus')
local savedUpgradeAPI=C_Item.GetItemUpgradeInfo
C_Item.GetItemUpgradeInfo=nil
record.hyperlink='item:100:myth'
eq(color(), '0.64,0.21,0.93', 'missing API keeps rarity')
C_Item.GetItemUpgradeInfo=savedUpgradeAPI

-- The selected color must reach border, glow and item level without changing
-- the stored rarity or affecting the previous crafting-quality overlays.
local button=vesperTools:CreateContainerItemButton({},nil,{createSecureUseButton=false})
function button:SetBackdropBorderColor(r,g,b) self.borderColor=colorText(r,g,b) end
function button.glow:SetColorTexture(r,g,b) self.color=colorText(r,g,b) end
function button.itemLevel:SetTextColor(r,g,b) self.color=colorText(r,g,b) end
C_Item.GetDetailedItemLevelInfo=function() return 318 end
upgradeInfo={trackString='Myth'}
controller:ConfigureItemButton(button,record,{isInteractive=false},
    {showItemLevel=true,qualityGlowIntensity=0.65})
eq(button.borderColor,'1.00,0.50,0.00','Myth border')
eq(button.glow.color,'1.00,0.50,0.00','Myth glow')
eq(button.itemLevel.color,'1.00,0.50,0.00','Myth item level')
eq(record.quality,4,'display color preserves stored epic rarity')
upgradeInfo={trackString='Hero'}
controller:ConfigureItemButton(button,record,{isInteractive=false},
    {showItemLevel=true,qualityGlowIntensity=0.65})
eq(button.borderColor,'1.00,0.30,1.00','reused button gets Hero border')
eq(button.itemLevel.color,'1.00,0.30,1.00','reused button gets Hero item level')
print('PASS: ' .. checks .. ' container item color checks')
