-- Run from addon root: lua tests/bags_combat_spec.lua
-- Reuse the store fixtures, then reload window modules to restore real methods.
dofile('tests/bags_bank_spec.lua')
dofile('Modules/BagsWindow.lua')
local window = vesperTools:GetModule('BagsWindow')
local checks, combat = 0, false
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function noop() end
InCombatLockdown = function() return combat end
local protectedCalls = {Hide=true, Show=true, SetPoint=true, SetAllPoints=true, SetSize=true,
    SetFrameLevel=true, SetAttribute=true, SetID=true, EnableMouse=true}
local methods = {}
local function guard(self, method)
    assert(not (combat and self.protected and protectedCalls[method]), 'blocked ' .. method)
end
function methods:IsProtected() return self.protected or false end
function methods:IsShown() return self.shown end
function methods:Show() guard(self,'Show'); self.shown=true end
function methods:Hide() guard(self,'Hide'); self.shown=false end
function methods:SetID(id) guard(self,'SetID'); self.id=id end
function methods:GetID() return self.id end
function methods:GetParent() return self.parent end
function methods:SetFrameLevel(level) guard(self,'SetFrameLevel'); self.level=level end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetAttribute(k,v)
    guard(self,'SetAttribute')
    self.attributes[k]=v
    if k=='bagid' then self.nativeBagID=v end
end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:SetBagID(id) self:SetAttribute('bagid',id) end
function methods:GetBagID() return self.nativeBagID or self.parent:GetID() end
function methods:UpdateExtended() self.extendedUpdated=true end
function methods:EnableMouse(enabled) guard(self,'EnableMouse'); self.mouseEnabled=enabled end
function methods:SetScript(name,f) self.scripts[name]=f end
function methods:GetScript(name) return self.scripts[name] end
function methods:HookScript(name,f) self.hooks[name]=f end
function methods:GetRegions() return end
function methods:GetChildren() return end
function methods:GetNormalTexture() return nil end
function methods:GetPushedTexture() return nil end
function methods:GetHighlightTexture() return nil end
function methods:GetCheckedTexture() return nil end
local newFrame
local function newRegion()
    return setmetatable({}, {__index=function(_,k)
        if k=='CreateAnimationGroup' or k=='CreateAnimation' then return newRegion end
        return noop
    end})
end
function methods:CreateTexture() return newRegion() end
function methods:CreateFontString() return newRegion() end
newFrame = function(parent)
    return setmetatable({parent=parent, shown=false, attributes={}, scripts={}, hooks={}}, {
        __index=function(_,k)
            if methods[k] then return methods[k] end
            if k:match('^Set') or k:match('^Register') or k=='Raise' then
                return function(self) guard(self,k) end
            end
        end,
    })
end
local nativeClick = function(self, mouseButton)
    -- Stand-in for Blizzard's original native handler, never addon UseItem Lua.
    self.clickedBag,self.clickedSlot,self.clickedButton=self:GetBagID(),self:GetID(),mouseButton
end
ContainerFrameItemButtonMixin = {OnClick=nativeClick}
local secureCreated = 0
CreateFrame = function(kind, _, parent, template)
    local frame=newFrame(parent)
    if template=='SecureActionButtonTemplate' then
        assert(not combat, 'secure child created in combat')
        secureCreated=secureCreated+1
        local ancestor=frame
        while ancestor do ancestor.protected=true; ancestor=ancestor.parent end
    elseif kind=='ItemButton' then
        frame.scripts.OnClick=nativeClick
    end
    return frame
end
GameTooltip = {Hide=noop}
vesperTools.ApplyConfiguredFont=noop
C_Item.GetItemSpell=function() return 'Use consumable' end
C_Item.GetItemInfoInstant=function() return nil,nil,nil,'',1,0,1 end
ITEM_QUALITY_COLORS={}
dofile('Modules/ContainerItemSupport.lua')
window:OnInitialize()
window.content=newFrame()
window.HasAnyWritableBankLive=function() return false end
-- Real bag acquisition must opt out even when first opened during combat.
combat=true
local button=window:AcquireItemButton()
eq(secureCreated,0,'no secure descendants in carried bags')
eq(button.secureUseButton,nil,'no hidden secure fallback')
eq(window.content:IsProtected(),false,'bag content remains unprotected')
local controller=window:GetItemInteraction()
local record={itemID=123,itemName='Potion',hyperlink='item:123',bagID=0,slotID=2,
    stackCount=3,categoryKey='consumable',quality=1}
local context={isInteractive=true,isCurrentCharacter=true,characterKey='current'}
-- The skin's New Items glow is irrelevant to the native item interaction test.
controller.config.afterConfigureButton=nil
controller:ConfigureItemButton(button,record,context,{showItemLevel=false})
local overlay=button.nativeContainerOverlay
eq(overlay:IsShown(),true,'native overlay shown when first created in combat')
eq(overlay:GetBagID(),0,'backpack ID zero retained')
eq(overlay:GetID(),2,'native slot initialized in combat')
eq(overlay:GetAttribute('bagid'),0,'native attribute-backed bag ID used')
eq(overlay:GetScript('OnClick'),nativeClick,'original native click handler preserved')
overlay:GetScript('OnClick')(overlay,'RightButton')
eq(overlay.clickedSlot,2,'right click targets live slot')
-- Reusable frames are hidden and reconfigured on every layout (original trace).
window:HideAllReusableFrames()
eq(button:IsShown(),false,'HideAllReusableFrames allowed in combat')
record.bagID,record.slotID,record.stackCount=1,8,2
controller:ConfigureItemButton(button,record,context,{showItemLevel=false})
eq(button:IsShown(),true,'reused item button can show in combat')
eq(overlay:GetBagID(),1,'reused overlay bag target updated')
eq(overlay:GetID(),8,'reused overlay slot target updated')
overlay:GetScript('OnClick')(overlay,'RightButton')
eq(overlay.clickedSlot,8,'right click follows new slot')
-- Switching to a saved alt must disable the old live click target in combat.
controller:ConfigureItemButton(button,record,{isInteractive=false},{showItemLevel=false})
eq(overlay:IsShown(),false,'offline item cannot retain live overlay')
eq(overlay.mouseEnabled,false,'offline item mouse input disabled')
-- Combined consumables resolve to an unlocked constituent, also during combat.
record.isCombined=true
record.combinedRecords={{bagID=0,slotID=2,isLocked=true},{bagID=3,slotID=7}}
controller:ConfigureItemButton(button,record,context,{showItemLevel=false})
eq(overlay:GetBagID(),3,'combined potion resolves unlocked bag')
eq(overlay:GetID(),7,'combined potion resolves unlocked slot')
-- Bank/default callers still have their secure fallback and defer its updates.
combat=false
local bankButton=vesperTools:CreateContainerItemButton({},newFrame(),{onClick=noop,onEnter=noop})
eq(secureCreated,1,'secure fallback preserved for existing default callers')
local host={pendingSecureItemRefresh=false}
local bankController=vesperTools:CreateContainerItemController(host,{})
combat=true
eq(pcall(function() bankButton:Hide() end),false,'fixture reproduces protected-child Hide failure')
bankController:UpdateNativeContainerOverlay(bankButton)
eq(host.pendingSecureItemRefresh,true,'protected caller defers before mutation')
-- Exercise the real show -> refresh -> hide reusable frames path and close/toggle.
window.frame=newFrame()
window.frame.parent=nil
for _,name in ipairs({'CancelNewItemExpiryTimer','ApplyConfiguredFonts','ApplyTitlebarLayout',
    'UpdateBagSlotsButtonVisual','UpdateCombineStacksButtonVisual','UpdateLayoutEditButtonVisual',
    'RefreshGuildLookupPresentation','SelectCurrentCharacterForOpen','HideCharacterMenu','HideBagSlotsMenu'}) do
    window[name]=noop
end
window.GetViewSettings=function() return {} end
window.GetStore=function() return nil end
window:ShowWindow()
eq(window.frame:IsShown(),true,'actual ShowWindow opens during combat')
window:Toggle()
eq(window.frame:IsShown(),false,'actual Toggle closes during combat')
window:Toggle()
eq(window.frame:IsShown(),true,'actual Toggle reopens during combat')
print('PASS: '..checks..' combat bag regression checks')
