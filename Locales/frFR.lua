local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "frFR")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "vesperTools charge avec succes !"
L["SLASH_COMMAND_HELP"] = "Ouvrir la fenetre vesperTools"

local defaults = addonTable and addonTable.LocaleDefaults or nil
if defaults then
    for key, value in pairs(defaults) do
        if L[key] == nil then
            L[key] = value
        end
    end
end
