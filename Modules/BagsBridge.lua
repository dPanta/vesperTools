local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local BagsBridge = vesperTools:NewModule("BagsBridge", "AceEvent-3.0")

local BAG_BINDINGS = {
    "TOGGLEBACKPACK",
    "TOGGLEREAGENTBAG",
    "TOGGLEBAG1",
    "TOGGLEBAG2",
    "TOGGLEBAG3",
    "TOGGLEBAG4",
    "OPENALLBAGS",
}

local BAG_HOOK_SPECS = {
    { name = "ToggleAllBags", action = "toggle" },
    { name = "OpenAllBags", action = "show" },
    { name = "ToggleBackpack", action = "toggle" },
    { name = "OpenBackpack", action = "show" },
    { name = "ToggleBag", action = "toggle", expectsBagID = true },
    { name = "OpenBag", action = "show", expectsBagID = true },
}

function vesperTools_ToggleBags()
    local addon = vesperTools or (LibStub and LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("vesperTools", true))
    if not addon then
        return
    end

    local bridge = addon:GetModule("BagsBridge", true)
    if bridge and type(bridge.ToggleReplacementWindow) == "function" then
        bridge:ToggleReplacementWindow("binding")
    end
end

_G.BINDING_NAME_VESPERTOOLS_TOGGLEBAGS = "Toggle vesperTools Bags"

function BagsBridge:OnInitialize()
    self.deferredActions = {}
    self.bindingFrame = CreateFrame("Frame", "vesperToolsBagsBindingFrame", UIParent)
    self.bindingFrame:Hide()
    self.bankProxyFrame = CreateFrame("Frame", "vesperToolsBankProxyFrame", UIParent)
    self.bankProxyFrame:Hide()
    self.installedHooks = {}
    self.hookedButtons = {}
    self.pendingBagAction = nil
    self.pendingBagActionScheduled = false
    self.pendingBindingRefresh = false
    self.bankFrameOriginalState = nil
    self.bankFrameSuppressed = false
    self.activeBankInteractionType = nil
    self.bankSessionOpenedBags = false
end

function BagsBridge:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("BANKFRAME_OPENED")
    self:RegisterEvent("BANKFRAME_CLOSED")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
    self:InstallHooks()
    self:RefreshReplacementState()
end

function BagsBridge:GetProfile()
    return vesperTools:GetBagsProfile()
end

function BagsBridge:IsBackpackReplacementEnabled()
    local profile = self:GetProfile()
    return profile and profile.replaceBackpack and true or false
end

function BagsBridge:IsCharacterBankReplacementEnabled()
    local profile = self:GetProfile()
    return profile and profile.replaceCharacterBank and true or false
end

function BagsBridge:IsAccountBankReplacementEnabled()
    local profile = self:GetProfile()
    return profile and profile.replaceAccountBank and true or false
end

function BagsBridge:IsBankReplacementEnabled()
    return self:IsCharacterBankReplacementEnabled() or self:IsAccountBankReplacementEnabled()
end

function BagsBridge:RunOutOfCombat(callback)
    if type(callback) ~= "function" then
        return
    end

    if not InCombatLockdown() then
        callback()
        return
    end

    self.deferredActions[#self.deferredActions + 1] = callback
end

function BagsBridge:InstallHooks()
    for i = 1, #BAG_HOOK_SPECS do
        local spec = BAG_HOOK_SPECS[i]
        if not self.installedHooks[spec.name] and type(_G[spec.name]) == "function" then
            local action = spec.action
            local expectsBagID = spec.expectsBagID
            hooksecurefunc(spec.name, function(...)
                local bagID = expectsBagID and select(1, ...) or nil
                self:HandleBlizzardBagHook(action, bagID)
            end)
            self.installedHooks[spec.name] = true
        end
    end
end

function BagsBridge:InstallButtonHooks()
    local buttons = {
        MainMenuBarBackpackButton,
        _G["CharacterBag0Slot"],
        _G["CharacterBag1Slot"],
        _G["CharacterBag2Slot"],
        _G["CharacterBag3Slot"],
        _G["CharacterReagentBag0Slot"],
    }

    for i = 1, #buttons do
        local button = buttons[i]
        if button and not self.hookedButtons[button] then
            button:HookScript("OnClick", function()
                if self:IsBackpackReplacementEnabled() then
                    self:QueueReplacementAction("toggle")
                end
            end)
            self.hookedButtons[button] = true
        end
    end
end

function BagsBridge:IsTrackedBackpackBagID(bagID)
    if type(bagID) ~= "number" then
        return false
    end

    local store = vesperTools:GetModule("BagsStore", true)
    if not store or type(store.IsTrackedBagID) ~= "function" then
        return false
    end

    return store:IsTrackedBagID(bagID)
end

function BagsBridge:HideBlizzardBags()
    if type(CloseAllBags) == "function" then
        CloseAllBags()
        return
    end

    if type(CloseBag) ~= "function" then
        return
    end

    local store = vesperTools:GetModule("BagsStore", true)
    if not store or type(store.GetTrackedBagIDs) ~= "function" then
        return
    end

    local bagIDs = store:GetTrackedBagIDs()
    for i = 1, #bagIDs do
        CloseBag(bagIDs[i])
    end
end

function BagsBridge:ShowReplacementWindow()
    if not self:IsBackpackReplacementEnabled() then
        return
    end

    local BagsWindow = vesperTools:GetModule("BagsWindow", true)
    if not BagsWindow then
        return
    end

    self:HideBlizzardBags()
    BagsWindow:ShowWindow()
end

function BagsBridge:ToggleReplacementWindow(source)
    if not self:IsBackpackReplacementEnabled() then
        return
    end

    local BagsWindow = vesperTools:GetModule("BagsWindow", true)
    if not BagsWindow then
        return
    end

    self:HideBlizzardBags()
    BagsWindow:Toggle()
end

function BagsBridge:QueueReplacementAction(action)
    if not self:IsBackpackReplacementEnabled() then
        return
    end

    if action == "toggle" or self.pendingBagAction == "toggle" then
        self.pendingBagAction = "toggle"
    else
        self.pendingBagAction = "show"
    end

    if self.pendingBagActionScheduled then
        return
    end

    self.pendingBagActionScheduled = true
    C_Timer.After(0, function()
        self.pendingBagActionScheduled = false

        if not self:IsEnabled() then
            self.pendingBagAction = nil
            return
        end

        local pendingAction = self.pendingBagAction
        self.pendingBagAction = nil

        if pendingAction == "toggle" then
            self:ToggleReplacementWindow("hook")
        elseif pendingAction == "show" then
            self:ShowReplacementWindow()
        end
    end)
end

function BagsBridge:HandleBlizzardBagHook(action, bagID)
    if not self:IsBackpackReplacementEnabled() then
        return
    end

    if bagID ~= nil and not self:IsTrackedBackpackBagID(bagID) then
        return
    end

    self:QueueReplacementAction(action)
end

function BagsBridge:RefreshBindingOverrides()
    if not self.bindingFrame then
        return
    end

    if InCombatLockdown() then
        self.pendingBindingRefresh = true
        return
    end

    self.pendingBindingRefresh = false
    ClearOverrideBindings(self.bindingFrame)

    if not self:IsBackpackReplacementEnabled() then
        return
    end

    for i = 1, #BAG_BINDINGS do
        local keys = { GetBindingKey(BAG_BINDINGS[i]) }
        for keyIndex = 1, #keys do
            local key = keys[keyIndex]
            if type(key) == "string" and key ~= "" then
                SetOverrideBinding(self.bindingFrame, true, key, "VESPERTOOLS_TOGGLEBAGS")
            end
        end
    end
end

function BagsBridge:CacheOriginalBankFrameState()
    if self.bankFrameOriginalState or not BankFrame then
        return
    end

    self.bankFrameOriginalState = {
        parent = BankFrame:GetParent(),
        onHide = BankFrame:GetScript("OnHide"),
        onShow = BankFrame:GetScript("OnShow"),
        onEvent = BankFrame:GetScript("OnEvent"),
    }
end

function BagsBridge:SuppressBankFrame()
    if not BankFrame or self.bankFrameSuppressed then
        return
    end

    self:CacheOriginalBankFrameState()
    BankFrame:SetScript("OnHide", nil)
    BankFrame:SetScript("OnShow", nil)
    BankFrame:SetScript("OnEvent", nil)
    BankFrame:SetParent(self.bankProxyFrame or UIParent)
    self.bankFrameSuppressed = true
end

function BagsBridge:RestoreBankFrame()
    if not BankFrame or not self.bankFrameSuppressed then
        return
    end

    local original = self.bankFrameOriginalState or {}
    BankFrame:SetParent(original.parent or UIParent)
    BankFrame:SetScript("OnHide", original.onHide)
    BankFrame:SetScript("OnShow", original.onShow)
    BankFrame:SetScript("OnEvent", original.onEvent)
    self.bankFrameSuppressed = false
end

function BagsBridge:ApplyBankFrameReplacementState()
    self:RunOutOfCombat(function()
        if self:IsBankReplacementEnabled() then
            self:SuppressBankFrame()
        else
            self:RestoreBankFrame()
        end
    end)
end

function BagsBridge:ShowBankReplacementWindow()
    self:ShowBankReplacementWindowForView(nil)
end

function BagsBridge:ShowBankReplacementWindowForView(preferredViewKey)
    if not self:IsBankReplacementEnabled() then
        return
    end

    self:ApplyBankFrameReplacementState()

    local BankWindow = vesperTools:GetModule("BankWindow", true)
    if not BankWindow or type(BankWindow.ShowWindow) ~= "function" then
        return
    end

    C_Timer.After(0, function()
        if self:IsEnabled() and self:IsBankReplacementEnabled() then
            BankWindow:ShowWindow(preferredViewKey)
        end
    end)
end

function BagsBridge:HideBankReplacementWindow()
    local BankWindow = vesperTools:GetModule("BankWindow", true)
    if not BankWindow or not BankWindow.frame then
        return
    end

    BankWindow.frame:Hide()
end

function BagsBridge:CloseBankReplacementWindow()
    if C_Bank and C_Bank.CloseBankFrame then
        C_Bank.CloseBankFrame()
        return
    end

    if CloseBankFrame then
        CloseBankFrame()
        return
    end

    self:HideBankReplacementWindow()
end

function BagsBridge:RefreshReplacementState()
    self:InstallHooks()
    self:InstallButtonHooks()
    self:RefreshBindingOverrides()
    self:ApplyBankFrameReplacementState()
end

function BagsBridge:PLAYER_LOGIN()
    self:RefreshReplacementState()
end

function BagsBridge:OnConfigChanged()
    self:RefreshReplacementState()
end

function BagsBridge:PLAYER_REGEN_ENABLED()
    if self.pendingBindingRefresh then
        self:RefreshBindingOverrides()
    end

    if #self.deferredActions == 0 then
        return
    end

    local pending = self.deferredActions
    self.deferredActions = {}
    for i = 1, #pending do
        local callback = pending[i]
        if type(callback) == "function" then
            callback()
        end
    end
end

function BagsBridge:UPDATE_BINDINGS()
    self:RefreshBindingOverrides()
end

function BagsBridge:IsBankInteractionType(interactionType)
    if not Enum or not Enum.PlayerInteractionType then
        return false
    end

    return interactionType == Enum.PlayerInteractionType.Banker
        or interactionType == Enum.PlayerInteractionType.AccountBanker
end

function BagsBridge:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(_, interactionType)
    if self:IsBankInteractionType(interactionType) then
        self.activeBankInteractionType = interactionType
    end
end

function BagsBridge:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(_, interactionType)
    if self:IsBankInteractionType(interactionType) and self.activeBankInteractionType == interactionType then
        self.activeBankInteractionType = nil
        C_Timer.After(0, function()
            if self:IsEnabled() and not self:IsAnyWritableBankLive() then
                self:HandleBankSessionClosed()
            end
        end)
    end
end

function BagsBridge:GetLiveBankStore()
    return vesperTools:GetModule("BankStore", true)
end

function BagsBridge:IsAnyWritableBankLive()
    local store = self:GetLiveBankStore()
    if not store then
        return false
    end

    local characterIsLive = type(store.IsCharacterBankLive) == "function" and store:IsCharacterBankLive() or false
    local warbandIsLive = type(store.IsWarbandBankLive) == "function" and store:IsWarbandBankLive() or false
    return characterIsLive or warbandIsLive
end

function BagsBridge:ResolvePreferredBankViewKey()
    local store = self:GetLiveBankStore()
    if not store then
        return nil
    end

    local characterIsLive = type(store.IsCharacterBankLive) == "function" and store:IsCharacterBankLive() or false
    local warbandIsLive = type(store.IsWarbandBankLive) == "function" and store:IsWarbandBankLive() or false
    local interactionType = self.activeBankInteractionType

    if Enum and Enum.PlayerInteractionType and interactionType == Enum.PlayerInteractionType.AccountBanker and warbandIsLive then
        return "warband"
    end

    if Enum and Enum.PlayerInteractionType and interactionType == Enum.PlayerInteractionType.Banker and characterIsLive then
        return "character"
    end

    if warbandIsLive and not characterIsLive then
        return "warband"
    end

    if characterIsLive then
        return "character"
    end

    if warbandIsLive then
        return "warband"
    end

    return nil
end

function BagsBridge:ShowBagsForLiveBankSession()
    if not self:IsAnyWritableBankLive() then
        return
    end

    local BagsWindow = vesperTools:GetModule("BagsWindow", true)
    if not BagsWindow or type(BagsWindow.ShowWindow) ~= "function" then
        return
    end

    local wasShown = BagsWindow.frame and BagsWindow.frame:IsShown() and true or false
    if not wasShown then
        BagsWindow:ShowWindow()
    end

    self.bankSessionOpenedBags = not wasShown
end

function BagsBridge:HideBagsOpenedForBankSession()
    if not self.bankSessionOpenedBags then
        return
    end

    self.bankSessionOpenedBags = false

    local BagsWindow = vesperTools:GetModule("BagsWindow", true)
    if not BagsWindow or not BagsWindow.frame or not BagsWindow.frame:IsShown() then
        return
    end

    BagsWindow.frame:Hide()
end

function BagsBridge:HandleBankSessionClosed()
    self.activeBankInteractionType = nil
    self:HideBankReplacementWindow()
    self:HideBagsOpenedForBankSession()
end

function BagsBridge:HandleBankSessionOpened()
    self.bankSessionOpenedBags = false

    C_Timer.After(0, function()
        if not self:IsEnabled() or not self:IsAnyWritableBankLive() then
            return
        end

        local preferredViewKey = self:ResolvePreferredBankViewKey()
        if self:IsBankReplacementEnabled() then
            self:ShowBankReplacementWindowForView(preferredViewKey)
        end
        self:ShowBagsForLiveBankSession()
    end)
end

function BagsBridge:BANKFRAME_OPENED()
    self:HandleBankSessionOpened()
end

function BagsBridge:BANKFRAME_CLOSED()
    self:HandleBankSessionClosed()
end

function BagsBridge:ADDON_LOADED(_, addonName)
    if addonName == "Blizzard_BankUI" then
        self:ApplyBankFrameReplacementState()
    end
end
