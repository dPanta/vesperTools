local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "deDE")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "vesperTools erfolgreich geladen!"
L["SLASH_COMMAND_HELP"] = "vesperTools-Fenster oeffnen"

local defaults = addonTable and addonTable.LocaleDefaults or nil
if defaults then
    for key, value in pairs(defaults) do
        if L[key] == nil then
            L[key] = value
        end
    end
end
