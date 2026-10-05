-- Run from addon root: lua5.1 tests/toy_flyout_spec.lua
-- Exercise real hover handlers and delayed callbacks with the legacy global absent.
local checks, now, combat = 0, 0, false
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function noop() end
local timers = {}
C_Timer = {After=function(delay, callback)
    timers[#timers + 1] = {due=now + delay, callback=callback}
end}
local function advance(seconds)
    local finish = now + seconds
    while true do
        local nextIndex
        for i, timer in ipairs(timers) do
            if timer.due <= finish and (not nextIndex or timer.due < timers[nextIndex].due) then nextIndex=i end
        end
        if not nextIndex then break end
        local timer = table.remove(timers, nextIndex)
        now = timer.due
        timer.callback()
    end
    now = finish
end
MouseIsOver = nil
InCombatLockdown = function() return combat end
UnitClass = function() return 'Warrior', 'WARRIOR', 1 end
local focus
local frameMethods = {}
function frameMethods:SetSize(w, h) self.width, self.height = w, h end
function frameMethods:GetWidth() return self.width end
function frameMethods:GetHeight() return self.height end
function frameMethods:GetLeft() return 200 end
function frameMethods:GetBottom() return 200 end
function frameMethods:GetTop() return 200 + self.height end
function frameMethods:GetRight() return 200 + self.width end
function frameMethods:GetFrameLevel() return 1 end
function frameMethods:IsShown() return self.shown end
function frameMethods:Show() assert(not combat, 'protected Show in combat'); self.shown=true end
function frameMethods:Hide() assert(not combat, 'protected Hide in combat'); self.shown=false end
function frameMethods:EnableMouse(enabled) self.mouseEnabled=enabled end
function frameMethods:IsMouseOver()
    local region = focus
    while region do
        if region == self then return true end
        region = region.parent
    end
    return false
end
function frameMethods:SetScript(name, handler) self.scripts[name]=handler end
function frameMethods:HookScript(name, handler)
    self.hooks[name] = self.hooks[name] or {}
    self.hooks[name][#self.hooks[name]+1] = handler
end
function frameMethods:Fire(name)
    if self.scripts[name] then self.scripts[name](self) end
    for _, hook in ipairs(self.hooks[name] or {}) do hook(self) end
end
local region = setmetatable({}, {__index=function() return noop end})
function frameMethods:CreateTexture() return region end
local frameMeta = {__index=function(_, name)
    if frameMethods[name] then return frameMethods[name] end
    if name:match('^Set') or name:match('^Register') or name == 'ClearAllPoints' then return noop end
    return nil
end}
CreateFrame = function(kind, _, parent)
    return setmetatable({parent=parent, shown=true, width=100, height=100,
        mouseEnabled=kind == 'Button', scripts={}, hooks={}}, frameMeta)
end
UIParent = CreateFrame('Frame')
UIParent:SetSize(1920, 1080)
local tooltipShown = false
GameTooltip = {SetOwner=noop, SetText=noop, AddLine=noop,
    Show=function() tooltipShown=true end, Hide=function() tooltipShown=false end}
local portals
vesperTools = {L=setmetatable({}, {__index=function(_, k) return k end})}
function vesperTools:NewModule()
    portals = {RegisterEvent=noop}
    return portals
end
function vesperTools:GetConfiguredTopUtilityButtonSize() return 24 end
function vesperTools:GetConfiguredOpacity() return 0.9 end
vesperTools.ApplyAddonWindowLayer, vesperTools.ApplyRoundedWindowBackdrop = noop, noop
assert(loadfile(arg[1] or 'Modules/Portals.lua'))('vesperTools', {AddonServices={}})
portals:OnInitialize()
portals.EnsureCooldownOverlay = noop
portals.classColor = {r=1, g=1, b=1}
portals.VesperPortalsUI = CreateFrame('Frame')
portals:CreateTopUtilityFrame()
local anchor, panel = portals.toyFlyoutButton, portals.toyFlyoutFrame
anchor._isAvailable = true
local toy = portals:CreateToyFlyoutActionButton(panel)
local otherToy = portals:CreateToyFlyoutActionButton(panel)
local function move(target)
    local previous = focus
    focus = target
    if previous and previous.mouseEnabled then previous:Fire('OnLeave') end
    if target and target.mouseEnabled then target:Fire('OnEnter') end
end

move(anchor)
eq(panel:IsShown(), true, 'anchor hover opens menu')
move(nil)
advance(0.25)
eq(panel:IsShown(), true, 'menu survives crossing gap')
move(toy)
advance(1)
eq(panel:IsShown(), true, 'toy hover takes over keepalive after original timeout')
eq(tooltipShown, true, 'toy tooltip retained')
advance(10)
eq(panel:IsShown(), true, 'stationary toy hover keeps menu open indefinitely')
move(otherToy)
advance(1)
eq(panel:IsShown(), true, 'moving between toys retains menu')
move(panel)
advance(10)
eq(panel:IsShown(), true, 'panel padding keeps menu open indefinitely')
move(nil)
advance(0.49)
eq(panel:IsShown(), true, 'leaving menu retains gap grace period')
advance(0.02)
eq(panel:IsShown(), false, 'menu closes after leaving both regions')

move(anchor)
move(nil)
advance(0.1)
move(panel)
advance(1)
eq(panel:IsShown(), true, 'panel entry cancels pending anchor close')
move(nil)
advance(0.1)
move(anchor)
advance(1)
eq(panel:IsShown(), true, 'return to anchor cancels pending panel close')
move(nil)
advance(0.1)
move(toy)
advance(0.1)
move(nil)
advance(0.35)
eq(panel:IsShown(), true, 'old close callback cannot cut short newer grace period')
advance(0.16)
eq(panel:IsShown(), false, 'latest leave eventually closes menu')

-- Verify the timeout also trusts the native geometric check if no enter event
-- arrives (for example while layout moves beneath the cursor).
move(anchor)
move(nil)
focus = toy
advance(1)
eq(panel:IsShown(), true, 'native mouse check sees child hover without legacy global or enter event')
focus = nil
portals:ScheduleToyFlyoutHideCheck()
advance(1)
eq(panel:IsShown(), false, 'native check reports actual departure')

move(anchor)
combat = true
move(toy)
advance(1)
eq(panel:IsShown(), true, 'hover in combat avoids protected frame mutation')
move(nil)
advance(1)
eq(portals.pendingUtilityRefresh, true, 'combat leave defers protected hide')
combat = false
portals:HideToyFlyout()
eq(panel:IsShown(), false, 'deferred close can complete after combat')
print('PASS: ' .. checks .. ' toy flyout regression checks')
