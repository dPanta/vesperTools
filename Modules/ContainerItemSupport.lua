local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local L = vesperTools.L
local ITEM_CLASS = Enum and Enum.ItemClass or {}
local ENABLE_NATIVE_CONTAINER_OVERLAYS = true
local STACK_SPLIT_FRAME_MIN_LEVEL = 1000
local STACK_SPLIT_FRAME_LEVEL_OFFSET = 80
local STACK_SPLIT_FRAME_STRATA = "TOOLTIP"
local stackSplitFrameLayerHooked = false
local lastStackSplitOwner = nil

local function safeColorForQuality(quality)
    if quality == nil then
        return 0.18, 0.18, 0.18
    end

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r or 0.18, color.g or 0.18, color.b or 0.18
    end

    return 0.18, 0.18, 0.18
end

local function suppressNativeOverlayVisuals(overlay)
    if not overlay then
        return
    end

    overlay:SetAlpha(0)

    local normalTexture = overlay.GetNormalTexture and overlay:GetNormalTexture() or nil
    if normalTexture then
        normalTexture:SetAlpha(0)
        normalTexture:Hide()
    end

    local pushedTexture = overlay.GetPushedTexture and overlay:GetPushedTexture() or nil
    if pushedTexture then
        pushedTexture:SetAlpha(0)
        pushedTexture:Hide()
    end

    local highlightTexture = overlay.GetHighlightTexture and overlay:GetHighlightTexture() or nil
    if highlightTexture then
        highlightTexture:SetAlpha(0)
        highlightTexture:Hide()
    end

    local checkedTexture = overlay.GetCheckedTexture and overlay:GetCheckedTexture() or nil
    if checkedTexture then
        checkedTexture:SetAlpha(0)
        checkedTexture:Hide()
    end

    local regions = { overlay:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
        if region and region.Hide then
            region:Hide()
        end
    end

    local children = { overlay:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.SetAlpha then
            child:SetAlpha(0)
        end
        if child and child.Hide then
            child:Hide()
        end
    end
end

local function canDisplayItemLevel(record)
    if not record or not record.itemID then
        return false
    end

    local classID
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, resolvedClassID = C_Item.GetItemInfoInstant(record.itemID)
        classID = resolvedClassID
    elseif GetItemInfoInstant then
        local _, _, _, _, _, resolvedClassID = GetItemInfoInstant(record.itemID)
        classID = resolvedClassID
    end

    return classID == ITEM_CLASS.Weapon or classID == ITEM_CLASS.Armor
end

local function getItemLevelForRecord(record)
    if not canDisplayItemLevel(record) then
        return nil
    end

    local itemLevel
    if GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(record.hyperlink or record.itemID)
    end
    if (not itemLevel or itemLevel <= 0) and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(record.hyperlink or record.itemID)
    end

    itemLevel = tonumber(itemLevel)
    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    return math.floor(itemLevel + 0.5)
end

local function createBagItemLocation(bagID, slotID)
    if not bagID or not slotID or not ItemLocation or type(ItemLocation.CreateFromBagAndSlot) ~= "function" then
        return nil
    end

    return ItemLocation:CreateFromBagAndSlot(bagID, slotID)
end

local function getContainerItemStackState(bagID, slotID)
    if not C_Container or type(C_Container.GetContainerItemInfo) ~= "function" or not bagID or not slotID then
        return nil, nil
    end

    local info = C_Container.GetContainerItemInfo(bagID, slotID)
    if not info then
        return nil, nil
    end

    return tonumber(info.stackCount), info.isLocked and true or false
end

local function isStackSplitClick(mouseButton)
    return (mouseButton == "LeftButton" or mouseButton == "RightButton")
        and IsModifiedClick
        and IsModifiedClick("SPLITSTACK")
end

local function cursorHasItem()
    if CursorHasItem and CursorHasItem() then
        return true
    end

    return GetCursorInfo and GetCursorInfo() == "item"
end

local function isStackSplitOwnerFrame(value)
    return value
        and type(value) ~= "string"
        and type(value) ~= "number"
        and type(value) ~= "boolean"
        and (type(value.GetFrameLevel) == "function" or type(value.GetParent) == "function")
end

local function normalizeStackSplitOwner(owner)
    if not isStackSplitOwnerFrame(owner) then
        return lastStackSplitOwner
    end

    return owner.ownerItemButton or owner
end

local function resolveStackSplitHookOwner(arg1, arg2, arg3)
    if isStackSplitOwnerFrame(arg3) then
        return arg3
    end
    if isStackSplitOwnerFrame(arg2) then
        return arg2
    end
    if isStackSplitOwnerFrame(arg1) and arg1 ~= StackSplitFrame then
        return arg1
    end

    return lastStackSplitOwner
end

local function raiseStackSplitFrameAboveOwner(owner)
    if not StackSplitFrame then
        return
    end

    owner = normalizeStackSplitOwner(owner)
    lastStackSplitOwner = owner

    if StackSplitFrame.GetParent and StackSplitFrame:GetParent() ~= UIParent then
        StackSplitFrame:SetParent(UIParent)
    end

    if StackSplitFrame.SetFixedFrameStrata then
        StackSplitFrame:SetFixedFrameStrata(false)
    end
    if StackSplitFrame.SetFixedFrameLevel then
        StackSplitFrame:SetFixedFrameLevel(false)
    end

    StackSplitFrame:SetFrameStrata(STACK_SPLIT_FRAME_STRATA)
    if StackSplitFrame.SetToplevel then
        StackSplitFrame:SetToplevel(true)
    end

    local ownerLevel = 0
    local frame = owner
    while frame and frame ~= UIParent do
        if frame.GetFrameLevel then
            ownerLevel = math.max(ownerLevel, frame:GetFrameLevel() or 0)
        end
        frame = frame.GetParent and frame:GetParent() or nil
    end

    StackSplitFrame:SetFrameLevel(math.max(STACK_SPLIT_FRAME_MIN_LEVEL, ownerLevel + STACK_SPLIT_FRAME_LEVEL_OFFSET))
    if StackSplitFrame.Raise then
        StackSplitFrame:Raise()
    end
end

local function deferStackSplitFrameRaise(owner)
    if not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end

    local ownerFrame = normalizeStackSplitOwner(owner)
    C_Timer.After(0, function()
        if StackSplitFrame and StackSplitFrame:IsShown() then
            raiseStackSplitFrameAboveOwner(ownerFrame)
        end
    end)
end

local function hookStackSplitFrameLayering()
    if stackSplitFrameLayerHooked or not StackSplitFrame then
        return
    end

    stackSplitFrameLayerHooked = true
    if hooksecurefunc and type(StackSplitFrame.OpenStackSplitFrame) == "function" then
        hooksecurefunc(StackSplitFrame, "OpenStackSplitFrame", function(arg1, arg2, arg3)
            local owner = resolveStackSplitHookOwner(arg1, arg2, arg3)
            raiseStackSplitFrameAboveOwner(owner)
            deferStackSplitFrameRaise(owner)
        end)
    end

    if StackSplitFrame.HookScript then
        StackSplitFrame:HookScript("OnShow", function(self)
            local owner = lastStackSplitOwner or (self.GetParent and self:GetParent() or nil)
            raiseStackSplitFrameAboveOwner(owner)
            deferStackSplitFrameRaise(owner)
        end)
    end
end

local function defaultPickupItem(_, button)
    local bagID = button and (button.actionBagID or button.bagID) or nil
    local slotID = button and (button.actionSlotID or button.slotID) or nil

    if C_Container and C_Container.PickupContainerItem and bagID and slotID then
        C_Container.PickupContainerItem(bagID, slotID)
        return true
    end

    return false
end

local function splitContainerItemStack(button, split)
    local bagID = button and (button.vgStackSplitBagID or button.actionBagID or button.bagID) or nil
    local slotID = button and (button.vgStackSplitSlotID or button.actionSlotID or button.slotID) or nil
    local splitCount = math.floor((tonumber(split) or 0) + 0.5)
    if not bagID or not slotID or splitCount <= 0 then
        return
    end

    if C_Container and type(C_Container.SplitContainerItem) == "function" then
        C_Container.SplitContainerItem(bagID, slotID, splitCount)
    elseif type(SplitContainerItem) == "function" then
        SplitContainerItem(bagID, slotID, splitCount)
    end
end

local function defaultUseItem(_, button)
    -- UseContainerItem is protected on current retail clients. Calling it from
    -- addon Lua taints item clicks, so item use is handled by Blizzard's
    -- native item button path or the secure fallback on live item buttons.
    return false
end

local function itemHasUseAction(itemRef)
    if itemRef == nil then
        return false
    end

    local spellName
    if C_Item and C_Item.GetItemSpell then
        spellName = C_Item.GetItemSpell(itemRef)
    elseif GetItemSpell then
        spellName = GetItemSpell(itemRef)
    end

    if type(spellName) == "string" then
        return spellName ~= ""
    end

    return spellName ~= nil
end

local function clearSecureItemUse(secureButton, button)
    if secureButton and type(secureButton.SetAttribute) == "function" then
        secureButton:SetAttribute("type", nil)
        secureButton:SetAttribute("item", nil)
        secureButton:SetAttribute("bag", nil)
        secureButton:SetAttribute("slot", nil)
        secureButton:SetAttribute("type2", nil)
        secureButton:SetAttribute("item2", nil)
        secureButton:SetAttribute("bag2", nil)
        secureButton:SetAttribute("slot2", nil)
        secureButton:SetAttribute("macrotext2", nil)
        secureButton.vgSecureUseBagID = nil
        secureButton.vgSecureUseSlotID = nil
        secureButton:EnableMouse(false)
        secureButton:Hide()
    end

    if button then
        button.vgSecureUseConfigured = false
        button.vgSecureUseBagID = nil
        button.vgSecureUseSlotID = nil
    end
end

function vesperTools:CreateContainerItemButton(host, parent, options)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize((options and options.defaultSize) or 38, (options and options.defaultSize) or 38)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local glow = button:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    glow:SetColorTexture(1, 1, 1, 0)
    glow:Hide()
    button.glow = glow

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    if options and options.includeNewItemGlow then
        local newGlow = button:CreateTexture(nil, "OVERLAY")
        newGlow:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        newGlow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        newGlow:SetBlendMode("ADD")
        newGlow:SetAlpha(0.95)
        newGlow:Hide()
        button.newGlow = newGlow

        local newGlowAnim = newGlow:CreateAnimationGroup()
        newGlowAnim:SetLooping("REPEAT")

        local pulseIn = newGlowAnim:CreateAnimation("Alpha")
        pulseIn:SetOrder(1)
        pulseIn:SetFromAlpha(0.55)
        pulseIn:SetToAlpha(1.0)
        pulseIn:SetDuration(0.35)
        pulseIn:SetSmoothing("IN_OUT")

        local pulseOut = newGlowAnim:CreateAnimation("Alpha")
        pulseOut:SetOrder(2)
        pulseOut:SetFromAlpha(1.0)
        pulseOut:SetToAlpha(0.55)
        pulseOut:SetDuration(0.35)
        pulseOut:SetSmoothing("IN_OUT")

        button.newGlowAnim = newGlowAnim
    end

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    vesperTools:ApplyConfiguredFont(count, 11, "OUTLINE")
    button.count = count

    local itemLevel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemLevel:SetPoint("TOPLEFT", 3, -2)
    itemLevel:SetJustifyH("LEFT")
    vesperTools:ApplyConfiguredFont(itemLevel, 9, "OUTLINE")
    itemLevel:Hide()
    button.itemLevel = itemLevel

    -- A SecureActionButton child protects its ancestors even while hidden.
    -- Carried bags use native ItemButtons and must opt out before construction.
    local secureUseButton
    if not options or options.createSecureUseButton ~= false then
        secureUseButton = CreateFrame("Button", nil, button, "SecureActionButtonTemplate")
        secureUseButton:SetAllPoints(button)
        secureUseButton:SetFrameLevel(button:GetFrameLevel() + 10)
        secureUseButton:RegisterForClicks("RightButtonUp", "RightButtonDown")
        secureUseButton:SetAttribute("useOnKeyDown", false)
        secureUseButton:SetAttribute("pressAndHoldAction", false)
        secureUseButton:EnableMouse(false)
        secureUseButton:Hide()
        button.secureUseButton = secureUseButton
    end

    if options and type(options.onEnter) == "function" then
        button:SetScript("OnEnter", function(selfButton)
            options.onEnter(host, selfButton)
        end)
        if secureUseButton then
            secureUseButton:SetScript("OnEnter", function(selfButton)
                options.onEnter(host, selfButton.ownerItemButton or button)
            end)
        end
    end
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    if secureUseButton then
        secureUseButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    if options and type(options.onClick) == "function" then
        button:SetScript("OnClick", function(selfButton, mouseButton)
            if mouseButton == "RightButton" and selfButton.vgSecureUseConfigured and not isStackSplitClick(mouseButton) then
                return
            end
            options.onClick(host, selfButton, mouseButton)
        end)
        if secureUseButton then
            secureUseButton:SetScript("PreClick", function(selfButton, mouseButton)
                if not isStackSplitClick(mouseButton) then
                    return
                end
                if InCombatLockdown and InCombatLockdown() then
                    return
                end

                local ownerButton = selfButton.ownerItemButton or button
                selfButton.vgSplitSuppressedType = selfButton:GetAttribute("type")
                selfButton.vgSplitSuppressedItem = selfButton:GetAttribute("item")
                selfButton.vgSplitSuppressedBag = selfButton:GetAttribute("bag")
                selfButton.vgSplitSuppressedSlot = selfButton:GetAttribute("slot")
                selfButton.vgSplitSuppressedType2 = selfButton:GetAttribute("type2")
                selfButton.vgSplitSuppressedItem2 = selfButton:GetAttribute("item2")
                selfButton.vgSplitSuppressedBag2 = selfButton:GetAttribute("bag2")
                selfButton.vgSplitSuppressedSlot2 = selfButton:GetAttribute("slot2")
                selfButton.vgSplitSuppressedMacrotext2 = selfButton:GetAttribute("macrotext2")
                selfButton.vgSplitSuppressRightClick = true
                selfButton:SetAttribute("type", nil)
                selfButton:SetAttribute("item", nil)
                selfButton:SetAttribute("bag", nil)
                selfButton:SetAttribute("slot", nil)
                selfButton:SetAttribute("type2", nil)
                selfButton:SetAttribute("item2", nil)
                selfButton:SetAttribute("bag2", nil)
                selfButton:SetAttribute("slot2", nil)
                selfButton:SetAttribute("macrotext2", nil)
                options.onClick(host, ownerButton, mouseButton)
            end)
            secureUseButton:SetScript("PostClick", function(selfButton)
                if not selfButton.vgSplitSuppressRightClick then
                    return
                end

                selfButton:SetAttribute("type", selfButton.vgSplitSuppressedType)
                selfButton:SetAttribute("item", selfButton.vgSplitSuppressedItem)
                selfButton:SetAttribute("bag", selfButton.vgSplitSuppressedBag)
                selfButton:SetAttribute("slot", selfButton.vgSplitSuppressedSlot)
                selfButton:SetAttribute("type2", selfButton.vgSplitSuppressedType2)
                selfButton:SetAttribute("item2", selfButton.vgSplitSuppressedItem2)
                selfButton:SetAttribute("bag2", selfButton.vgSplitSuppressedBag2)
                selfButton:SetAttribute("slot2", selfButton.vgSplitSuppressedSlot2)
                selfButton:SetAttribute("macrotext2", selfButton.vgSplitSuppressedMacrotext2)
                selfButton.vgSplitSuppressedType = nil
                selfButton.vgSplitSuppressedItem = nil
                selfButton.vgSplitSuppressedBag = nil
                selfButton.vgSplitSuppressedSlot = nil
                selfButton.vgSplitSuppressedType2 = nil
                selfButton.vgSplitSuppressedItem2 = nil
                selfButton.vgSplitSuppressedBag2 = nil
                selfButton.vgSplitSuppressedSlot2 = nil
                selfButton.vgSplitSuppressedMacrotext2 = nil
                selfButton.vgSplitSuppressRightClick = nil
            end)
        end
    end
    if options and type(options.onDragStart) == "function" then
        button:SetScript("OnDragStart", function(selfButton)
            options.onDragStart(host, selfButton)
        end)
    end
    if options and type(options.onReceiveDrag) == "function" then
        button:SetScript("OnReceiveDrag", function(selfButton)
            options.onReceiveDrag(host, selfButton)
        end)
    end
    button:SetScript("OnHide", function(selfButton)
        if selfButton.hasStackSplit == 1 and StackSplitFrame then
            StackSplitFrame:Hide()
        end
        selfButton.hasStackSplit = nil
    end)

    return button
end

function vesperTools:CreateContainerItemController(host, config)
    hookStackSplitFrameLayering()

    local controller = {}
    controller.host = host
    controller.config = config or {}

    local function isContextInteractive(context)
        if type(controller.config.isContextInteractive) == "function" then
            return controller.config.isContextInteractive(host, context) and true or false
        end

        return context and context.isInteractive and true or false
    end

    function controller:IsButtonInteractive(button)
        return button and button.isInteractive and true or false
    end

    function controller:CanDisplayItemLevel(record)
        return canDisplayItemLevel(record)
    end

    function controller:GetItemLevelForRecord(record)
        return getItemLevelForRecord(record)
    end

    function controller:ConfigureTooltip(button)
        local isInteractive = self:IsButtonInteractive(button)
        local tooltipBagID, tooltipSlotID = nil, nil
        if isInteractive then
            tooltipBagID, tooltipSlotID = self:GetButtonBagSlot(button, true)
        end

        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if isInteractive and tooltipBagID and tooltipSlotID then
            GameTooltip:SetBagItem(tooltipBagID, tooltipSlotID)
        else
            if type(button.hyperlink) == "string" and button.hyperlink ~= "" then
                GameTooltip:SetHyperlink(button.hyperlink)
            else
                GameTooltip:SetText(button.itemName or vesperTools:BuildFallbackItemName(button.itemID), 1, 1, 1)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%s: %s", isInteractive and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"], button.ownerName or UNKNOWN), 0.85, 0.85, 0.85)
        if button.isCombined then
            GameTooltip:AddLine(string.format(L["BAGS_COMBINED_FROM_FMT"], tonumber(button.combinedStacks) or 1), 0.85, 0.85, 0.85)
            GameTooltip:AddLine(string.format(L["BAGS_TOTAL_ITEMS_FMT"], tonumber(button.totalCount) or tonumber(button.stackCount) or 0), 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
    end

    function controller:CanUseCombinedButton(button)
        if not button or not button.isCombined or not self:IsButtonInteractive(button) then
            return false
        end

        if type(self.config.canUseCombinedButton) == "function" then
            return self.config.canUseCombinedButton(host, button) and true or false
        end

        if button.categoryKey == "container" then
            return true
        end

        return itemHasUseAction(button.hyperlink or button.itemID)
    end

    function controller:ShouldUseSecureItemButton(button)
        if type(self.config.shouldUseSecureItemButton) == "function" then
            return self.config.shouldUseSecureItemButton(host, button) and true or false
        end
        if self.config.shouldUseSecureItemButton ~= nil then
            return self.config.shouldUseSecureItemButton and true or false
        end

        return true
    end

    function controller:ConfigureSecureItemUse(button)
        local secureButton = button and button.secureUseButton or nil
        if not secureButton or type(secureButton.SetAttribute) ~= "function" then
            return
        end

        local hasNativeOverlay = self:ShouldUseNativeOverlay(button)
        local bagID, slotID = self:GetButtonBagSlot(button, true)
        local canUse = self:IsButtonInteractive(button)
            and bagID
            and slotID
            and not hasNativeOverlay
            and self:ShouldUseSecureItemButton(button)
            and (not button.isCombined or self:CanUseCombinedButton(button))

        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            if host.pendingSecureItemRefresh ~= nil then
                host.pendingSecureItemRefresh = true
            end
            return
        end

        secureButton.ownerItemButton = button
        secureButton:SetFrameLevel((button:GetFrameLevel() or 0) + 10)

        if hasNativeOverlay then
            clearSecureItemUse(secureButton, button)
            return
        end

        if canUse then
            local itemLocation = string.format("%d %d", bagID, slotID)
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLocation)
            secureButton:SetAttribute("bag", bagID)
            secureButton:SetAttribute("slot", slotID)
            secureButton:SetAttribute("type2", "item")
            secureButton:SetAttribute("item2", itemLocation)
            secureButton:SetAttribute("bag2", bagID)
            secureButton:SetAttribute("slot2", slotID)
            secureButton:SetAttribute("macrotext2", nil)
            secureButton.vgSecureUseBagID = bagID
            secureButton.vgSecureUseSlotID = slotID
            secureButton:EnableMouse(true)
            secureButton:Show()
            button.vgSecureUseConfigured = true
            button.vgSecureUseBagID = bagID
            button.vgSecureUseSlotID = slotID
            return
        end

        clearSecureItemUse(secureButton, button)
    end

    function controller:GetButtonBagSlot(button, allowCombinedUse)
        if not button then
            return nil, nil
        end

        if not button.isCombined and button.bagID and button.slotID then
            return button.bagID, button.slotID
        end

        if not allowCombinedUse or not self:CanUseCombinedButton(button) or type(button.combinedRecords) ~= "table" then
            return nil, nil
        end

        local fallbackBagID, fallbackSlotID = nil, nil
        for i = 1, #button.combinedRecords do
            local record = button.combinedRecords[i]
            local bagID = type(record) == "table" and record.bagID or nil
            local slotID = type(record) == "table" and record.slotID or nil
            if bagID and slotID then
                if not record.isLocked then
                    return bagID, slotID
                end

                if not fallbackBagID then
                    fallbackBagID, fallbackSlotID = bagID, slotID
                end
            end
        end

        return fallbackBagID, fallbackSlotID
    end

    -- Resolve a bag/slot suitable for a deposit from a (possibly combined)
    -- button. Unlike GetButtonBagSlot(true), this never gates on
    -- CanUseCombinedButton: depositing a stack into the bank does not require
    -- the item to have a "use" action, so combined reagent/quest stacks must
    -- still resolve to one of their underlying records.
    function controller:GetButtonDepositBagSlot(button)
        if not button then
            return nil, nil
        end

        if not button.isCombined and button.bagID and button.slotID then
            return button.bagID, button.slotID
        end

        if type(button.combinedRecords) ~= "table" then
            return nil, nil
        end

        local fallbackBagID, fallbackSlotID = nil, nil
        for i = 1, #button.combinedRecords do
            local record = button.combinedRecords[i]
            local bagID = type(record) == "table" and record.bagID or nil
            local slotID = type(record) == "table" and record.slotID or nil
            if bagID and slotID then
                if not record.isLocked then
                    return bagID, slotID
                end

                if not fallbackBagID then
                    fallbackBagID, fallbackSlotID = bagID, slotID
                end
            end
        end

        return fallbackBagID, fallbackSlotID
    end

    function controller:GetButtonModifiedBagSlot(button)
        if not button then
            return nil, nil
        end

        if not button.isCombined and button.bagID and button.slotID then
            return button.bagID, button.slotID
        end

        return self:GetButtonDepositBagSlot(button)
    end

    function controller:GetButtonStackSplitBagSlot(button)
        if not self:IsButtonInteractive(button) then
            return nil, nil, nil
        end

        if not button.isCombined and button.bagID and button.slotID then
            local itemCount, locked = getContainerItemStackState(button.bagID, button.slotID)
            if not locked and itemCount and itemCount > 1 then
                return button.bagID, button.slotID, itemCount
            end
            return nil, nil, nil
        end

        if type(button.combinedRecords) ~= "table" then
            return nil, nil, nil
        end

        for i = 1, #button.combinedRecords do
            local record = button.combinedRecords[i]
            local bagID = type(record) == "table" and record.bagID or nil
            local slotID = type(record) == "table" and record.slotID or nil
            if bagID and slotID then
                local itemCount, locked = getContainerItemStackState(bagID, slotID)
                if not locked and itemCount and itemCount > 1 then
                    return bagID, slotID, itemCount
                end
            end
        end

        return nil, nil, nil
    end

    function controller:GetNativeOverlayBagSlot(button)
        if not button then
            return nil, nil
        end

        if not button.isCombined and button.bagID and button.slotID then
            return button.bagID, button.slotID
        end

        if button.isCombined and self:CanUseCombinedButton(button) then
            return self:GetButtonBagSlot(button, true)
        end

        return nil, nil
    end

    function controller:PickupItem(button)
        if not self:IsButtonInteractive(button) or InCombatLockdown() then
            return false
        end

        local bagID, slotID = self:GetButtonBagSlot(button, false)
        if not bagID or not slotID then
            return false
        end

        button.actionBagID = bagID
        button.actionSlotID = slotID
        local pickupItem = type(self.config.pickupItem) == "function" and self.config.pickupItem or defaultPickupItem
        return pickupItem(host, button) and true or false
    end

    function controller:UseItem(button)
        if not self:IsButtonInteractive(button) or InCombatLockdown() then
            return false
        end

        local bagID, slotID = self:GetButtonBagSlot(button, true)
        if not bagID or not slotID then
            return false
        end

        button.actionBagID = bagID
        button.actionSlotID = slotID
        local useItem = type(self.config.useItem) == "function" and self.config.useItem or defaultUseItem
        return useItem(host, button) and true or false
    end

    function controller:HandleItemDrag(button)
        self:PickupItem(button)
    end

    function controller:TryOpenStackSplitFrame(button, mouseButton)
        if not self:IsButtonInteractive(button) or InCombatLockdown() then
            return false
        end
        if not isStackSplitClick(mouseButton) then
            return false
        end
        if CursorHasItem and CursorHasItem() then
            return false
        end
        if not StackSplitFrame or type(StackSplitFrame.OpenStackSplitFrame) ~= "function" then
            return false
        end
        hookStackSplitFrameLayering()

        local bagID, slotID, itemCount = self:GetButtonStackSplitBagSlot(button)
        if not bagID or not slotID or not itemCount then
            return false
        end

        button.actionBagID = bagID
        button.actionSlotID = slotID
        button.vgStackSplitBagID = bagID
        button.vgStackSplitSlotID = slotID
        button.SplitStack = splitContainerItemStack
        button.hasStackSplit = 1
        StackSplitFrame:OpenStackSplitFrame(itemCount, button, "BOTTOMRIGHT", "TOPRIGHT")
        raiseStackSplitFrameAboveOwner(button)
        deferStackSplitFrameRaise(button)
        return true
    end

    function controller:HandleModifiedItemClick(button, mouseButton)
        if cursorHasItem() then
            return false
        end

        if mouseButton == "RightButton" and self:TryOpenStackSplitFrame(button, mouseButton) then
            return true
        end

        local bagID, slotID = self:GetButtonModifiedBagSlot(button)
        local itemLocation = createBagItemLocation(bagID, slotID)
        if button
            and type(button.hyperlink) == "string"
            and button.hyperlink ~= ""
            and HandleModifiedItemClick
            and HandleModifiedItemClick(button.hyperlink, itemLocation) then
            return true
        end

        return self:TryOpenStackSplitFrame(button, mouseButton)
    end

    function controller:HandleItemClick(button, mouseButton)
        if cursorHasItem() then
            self:PickupItem(button)
            return
        end

        if self:HandleModifiedItemClick(button, mouseButton) then
            return
        end

        if mouseButton == "RightButton"
            and button
            and button.isCombined
            and self:CanUseCombinedButton(button)
            and button.nativeContainerOverlay
            and button.nativeContainerOverlay:IsShown()
        then
            return
        end

        if mouseButton == "RightButton" and button and button.vgSecureUseConfigured then
            return
        end

        if mouseButton == "RightButton" then
            if type(self.config.useItem) == "function" then
                self:UseItem(button)
            end
            return
        end

        self:PickupItem(button)
    end

    function controller:GetOverlayMouseEnabled(button)
        if type(self.config.overlayMouseEnabled) == "function" then
            return self.config.overlayMouseEnabled(host, button) and true or false
        end
        if self.config.overlayMouseEnabled == nil then
            if button and button.isCombined and self:CanUseCombinedButton(button) then
                return true
            end
            if button and button.categoryKey == "container" then
                return false
            end
            return true
        end

        return self.config.overlayMouseEnabled and true or false
    end

    function controller:GetOverlayPassThroughButtons(button)
        if type(self.config.overlayPassThroughButtons) == "function" then
            local buttons = self.config.overlayPassThroughButtons(host, button)
            if type(buttons) == "table" and #buttons > 0 then
                return buttons
            end
        end

        if button and button.isCombined and self:CanUseCombinedButton(button) then
            return { "LeftButton" }
        end

        return { "LeftButton" }
    end

    function controller:ShouldUseNativeOverlay(button)
        if not ENABLE_NATIVE_CONTAINER_OVERLAYS then
            return false
        end

        if not ContainerFrameItemButtonMixin then
            return false
        end

        if type(self.config.shouldUseNativeOverlay) == "function" then
            return self.config.shouldUseNativeOverlay(host, button) and true or false
        end

        local bagID, slotID = self:GetNativeOverlayBagSlot(button)
        return self:IsButtonInteractive(button)
            and bagID
            and slotID
    end

    function controller:ConfigureNativeContainerOverlayInput(overlay, button)
        if overlay then
            overlay.vgPassThroughButtonsSignature = nil
        end
        return true
    end

    function controller:AcquireNativeContainerOverlay(button)
        if not button or button.nativeContainerOverlay or not ContainerFrameItemButtonMixin then
            return button and button.nativeContainerOverlay or nil
        end

        button.IsCombinedBagContainer = button.IsCombinedBagContainer or function()
            return false
        end

        local overlay = CreateFrame("ItemButton", nil, button, "ContainerFrameItemButtonTemplate")
        overlay:SetAllPoints(button)
        overlay:SetFrameLevel(button:GetFrameLevel() + 10)
        overlay:EnableMouse(self:GetOverlayMouseEnabled(button))
        overlay.ownerItemButton = button
        overlay:HookScript("PostClick", function(selfButton, mouseButton)
            if isStackSplitClick(mouseButton) then
                raiseStackSplitFrameAboveOwner(selfButton.ownerItemButton or selfButton)
                deferStackSplitFrameRaise(selfButton.ownerItemButton or selfButton)
            end
        end)
        if not self:ConfigureNativeContainerOverlayInput(overlay, button) then
            overlay.vgPassThroughButtonsSignature = overlay.vgPassThroughButtonsSignature or ""
        end
        suppressNativeOverlayVisuals(overlay)
        overlay:Hide()
        button.nativeContainerOverlay = overlay
        return overlay
    end

    function controller:UpdateNativeContainerOverlay(button)
        local overlay = button.nativeContainerOverlay
        -- Native ItemButtons can be updated in combat. Only defer if a caller
        -- actually attached protected children (e.g. the bank secure fallback).
        if InCombatLockdown() and (button:IsProtected() or (overlay and overlay:IsProtected())) then
            if host.pendingSecureItemRefresh ~= nil then
                host.pendingSecureItemRefresh = true
            end
            return
        end

        local shouldUseNativeOverlay = self:ShouldUseNativeOverlay(button)
        overlay = overlay or (shouldUseNativeOverlay and self:AcquireNativeContainerOverlay(button)) or nil
        if not overlay then
            return
        end

        if not shouldUseNativeOverlay then
            overlay:EnableMouse(false)
            overlay:Hide()
            return
        end

        local bagID, slotID = self:GetNativeOverlayBagSlot(button)
        -- Use Blizzard's attribute-backed setter: assigning bagID directly (or
        -- deriving it from an addon-owned parent) taints native item interaction.
        overlay:SetBagID(bagID)
        overlay:SetID(slotID)
        overlay:UpdateExtended()
        overlay:EnableMouse(self:GetOverlayMouseEnabled(button))
        if not self:ConfigureNativeContainerOverlayInput(overlay, button) then
            return
        end

        overlay:SetAllPoints(button)
        overlay:SetFrameLevel(button:GetFrameLevel() + 10)
        suppressNativeOverlayVisuals(overlay)
        overlay:Show()
    end

    function controller:ConfigureItemButton(button, record, context, viewSettings)
        button.itemID = record.itemID
        button.itemName = record.itemName
        button.itemDescription = record.itemDescription
        button.searchText = record.searchText
        button.categoryKey = record.categoryKey
        button.hyperlink = record.hyperlink
        button.combinedRecords = type(record.combinedRecords) == "table" and record.combinedRecords or nil
        button.isCombined = record.isCombined and true or false
        if button.isCombined then
            button.bagID = nil
            button.slotID = nil
        else
            button.bagID = record.bagID
            button.slotID = record.slotID
        end
        button.actionBagID = nil
        button.actionSlotID = nil
        button.ownerName = context and context.ownerName or nil
        button.isInteractive = isContextInteractive(context)
        button.combinedStacks = tonumber(record.combinedStacks) or 1
        button.totalCount = tonumber(record.stackCount) or 1

        if type(self.config.assignContextToButton) == "function" then
            self.config.assignContextToButton(host, button, context)
        end

        local itemIconSize = viewSettings and viewSettings.itemIconSize or 38
        local countFontSize = math.max(8, math.min(20, tonumber(viewSettings and viewSettings.stackCountFontSize) or 11))
        local itemLevelFontSize = math.max(8, math.min(18, tonumber(viewSettings and viewSettings.itemLevelFontSize) or 9))

        button:SetSize(itemIconSize, itemIconSize)
        vesperTools:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
        vesperTools:ApplyConfiguredFont(button.itemLevel, itemLevelFontSize, "OUTLINE")

        button.icon:SetTexture(record.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.count:SetText(((button.isCombined and button.totalCount > 1) or (tonumber(record.stackCount) or 1) > 1) and tostring(button.totalCount) or "")

        local r, g, b = safeColorForQuality(record.quality)
        if (viewSettings and viewSettings.qualityGlowIntensity or 0) > 0 and record.quality ~= nil then
            local glowIntensity = viewSettings.qualityGlowIntensity
            button:SetBackdropBorderColor(r, g, b, 0.35 + (glowIntensity * 0.65))
            button.glow:SetColorTexture(r, g, b, 0.08 + (glowIntensity * 0.22))
            button.glow:Show()
        else
            button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
            button.glow:Hide()
        end
        button:SetBackdropColor(0.08, 0.08, 0.08, 1)
        self:ConfigureSecureItemUse(button)
        button:SetEnabled(true)
        self:UpdateNativeContainerOverlay(button)

        if viewSettings and viewSettings.showItemLevel then
            local itemLevel = self:GetItemLevelForRecord(record)
            if itemLevel then
                button.itemLevel:SetText(tostring(itemLevel))
                button.itemLevel:SetTextColor(r, g, b, 1)
                button.itemLevel:Show()
            else
                button.itemLevel:SetText("")
                button.itemLevel:Hide()
            end
        else
            button.itemLevel:SetText("")
            button.itemLevel:Hide()
        end

        if type(self.config.afterConfigureButton) == "function" then
            self.config.afterConfigureButton(host, button, record, context, viewSettings, r, g, b)
        end

        button:Show()
    end

    return controller
end
