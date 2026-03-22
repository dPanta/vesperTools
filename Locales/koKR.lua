local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "koKR")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "vesperTools가 정상적으로 로드되었습니다!"
L["SLASH_COMMAND_HELP"] = "vesperTools 창 열기"

local defaults = addonTable and addonTable.LocaleDefaults or nil
if defaults then
    for key, value in pairs(defaults) do
        if L[key] == nil then
            L[key] = value
        end
    end
end
