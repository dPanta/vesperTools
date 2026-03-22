local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "esMX")
end

if not L then
    return
end

L["ADDON_LOADED_MESSAGE"] = "vesperTools se cargo correctamente."
L["SLASH_COMMAND_HELP"] = "Abrir la ventana de vesperTools"

local defaults = addonTable and addonTable.LocaleDefaults or nil
if defaults then
    for key, value in pairs(defaults) do
        if L[key] == nil then
            L[key] = value
        end
    end
end
