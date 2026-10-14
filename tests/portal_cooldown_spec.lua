-- Run from addon root: lua5.1 tests/portal_cooldown_spec.lua
-- Model the 12.1.5 protected setter: an attempted call counts as a blocked
-- action even when pcall catches the error. Exercise the real refresh path.
local checks, blocked, writes = 0, 0, 0
local function eq(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function noop() end
local now, protected = 100, false
GetTime = function() return now end
UnitClass = function() return 'Mage', 'MAGE', 8 end
local info = {startTime=90, duration=30, isEnabled=true, modRate=1}
C_Spell = {GetSpellCooldown=function() return info end}
local secret = {}
issecretvalue = function(value) return value == secret end

local portals
vesperTools = {L={}}
function vesperTools:NewModule()
    portals = {}
    return portals
end
assert(loadfile('Modules/Portals.lua'))('vesperTools', {AddonServices={}})
portals.UpdateCooldownTextFont = noop
local cooldown = {
    IsProtected=function() return protected end,
    SetCooldown=function(self, start, duration, modRate)
        if protected then
            blocked = blocked + 1
            error('12.1.5 blocked protected cooldown setter')
        end
        writes = writes + 1
        self.start, self.duration, self.modRate = start, duration, modRate
    end,
    Show=function(self) self.shown=true end,
    Hide=function(self) self.shown=false end,
}
local text = {
    SetText=function(self, value) self.value=value end,
    SetTextColor=noop,
    Show=function(self) self.shown=true end,
    Hide=function(self) self.shown=false end,
}
local button = {_cooldownSourceType='spell', _cooldownSourceID=3561,
    cooldownFrame=cooldown, cooldownText=text}

eq(portals:RefreshButtonCooldown(button, now), true, 'unprotected cooldown remains active')
eq(writes, 1, 'ordinary widget receives setter')
eq(cooldown.start, 90, 'start preserved')
eq(cooldown.duration, 30, 'duration preserved')
eq(cooldown.modRate, 1, 'rate preserved')
eq(text.value, '20', 'numeric countdown rendered')

protected = true
eq(portals:RefreshButtonCooldown(button, now), true, 'protected widget retains numeric countdown')
eq(writes, 1, 'protected refresh does not write cooldown')
eq(blocked, 0, 'protected setter never attempted through pcall')
eq(text.value, '20', 'protected countdown remains accurate')
eq(portals:ClearButtonCooldown(button), false, 'protected cooldown clears addon state')
eq(blocked, 0, 'clear also avoids protected setter')
eq(button._cooldownStart, nil, 'cached start cleared')
eq(text.value, '', 'expired numeric text cleared')
eq(text.shown, false, 'expired numeric text hidden')

protected = false
portals:RefreshButtonCooldown(button, now)
now = 121
eq(portals:UpdateButtonCooldownText(button, now), false, 'expired cooldown stops updating')
eq(cooldown.duration, 0, 'ordinary widget reset on expiry')
eq(cooldown.shown, false, 'expired swirl hidden')

info = {startTime=90, duration=30, isEnabled=true, modRate=2}
now = 100
portals:RefreshButtonCooldown(button, now)
eq(text.value, '10', 'modified cooldown rate retained')
info = {startTime=90, duration=1.5, isEnabled=true}
eq(portals:RefreshButtonCooldown(button, now), false, 'global cooldown excluded')
info = {startTime=secret, duration=secret, isEnabled=secret, modRate=secret}
eq(portals:RefreshButtonCooldown(button, now), false, 'secret cooldown data is not inspected')
eq(blocked, 0, 'no blocked setters in any path')
print('PASS: ' .. checks .. ' portal cooldown regression checks')
