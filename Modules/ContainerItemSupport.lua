local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local L = vesperTools.L
local ITEM_CLASS = Enum and Enum.ItemClass or {}
local ENABLE_NATIVE_CONTAINER_OVERLAYS = true

local function buildFallbackItemName(itemID)
    return string.format(L["ITEM_FALLBACK_FMT"], tostring(itemID))
end

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

local function defaultPickupItem(_, button)
    local bagID = button and (button.actionBagID or button.bagID) or nil
    local slotID = button and (button.actionSlotID or button.slotID) or nil

    if C_Container and C_Container.PickupContainerItem and bagID and slotID then
        C_Container.PickupContainerItem(bagID, slotID)
        return true
    end

    return false
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

    local secureUseButton = CreateFrame("Button", nil, button, "SecureActionButtonTemplate")
    secureUseButton:SetAllPoints(button)
    secureUseButton:SetFrameLevel(button:GetFrameLevel() + 10)
    secureUseButton:RegisterForClicks("RightButtonUp", "RightButtonDown")
    secureUseButton:SetAttribute("useOnKeyDown", false)
    secureUseButton:SetAttribute("pressAndHoldAction", false)
    secureUseButton:EnableMouse(false)
    if type(secureUseButton.SetPassThroughButtons) == "function" then
        if securecallfunction then
            securecallfunction(secureUseButton.SetPassThroughButtons, secureUseButton, "LeftButton")
        else
            secureUseButton:SetPassThroughButtons("LeftButton")
        end
    end
    secureUseButton:Hide()
    button.secureUseButton = secureUseButton

    if options and type(options.onEnter) == "function" then
        button:SetScript("OnEnter", function(selfButton)
            options.onEnter(host, selfButton)
        end)
        secureUseButton:SetScript("OnEnter", function(selfButton)
            options.onEnter(host, selfButton.ownerItemButton or button)
        end)
    end
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    secureUseButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    if options and type(options.onClick) == "function" then
        button:SetScript("OnClick", function(selfButton, mouseButton)
            if mouseButton == "RightButton" and selfButton.vgSecureUseConfigured then
                return
            end
            options.onClick(host, selfButton, mouseButton)
        end)
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

    return button
end

function vesperTools:CreateContainerItemController(host, config)
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
                GameTooltip:SetText(button.itemName or buildFallbackItemName(button.itemID), 1, 1, 1)
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

    function controller:HandleItemClick(button, mouseButton)
        if type(button.hyperlink) == "string"
            and button.hyperlink ~= ""
            and HandleModifiedItemClick
            and HandleModifiedItemClick(button.hyperlink) then
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
        if not overlay or type(overlay.SetPassThroughButtons) ~= "function" then
            return true
        end

        local desiredSignature = ""
        local desiredButtons = self:GetOverlayPassThroughButtons(button)
        if desiredButtons then
            desiredSignature = table.concat(desiredButtons, ",")
        end

        local currentSignature = overlay.vgPassThroughButtonsSignature
        if currentSignature == nil then
            currentSignature = ""
        end

        -- Fresh container overlays already behave like the default "no pass-through"
        -- case, so avoid touching the protected setter unless we actually need to
        -- transition the overlay input state.
        if currentSignature == desiredSignature then
            overlay.vgPassThroughButtonsSignature = desiredSignature
            return true
        end

        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            if host.pendingSecureItemRefresh ~= nil then
                host.pendingSecureItemRefresh = true
            end
            return false
        end

        if securecallfunction then
            if desiredButtons then
                securecallfunction(overlay.SetPassThroughButtons, overlay, unpack(desiredButtons))
            else
                securecallfunction(overlay.SetPassThroughButtons, overlay)
            end
            overlay.vgPassThroughButtonsSignature = desiredSignature
            return true
        end

        if desiredButtons then
            overlay:SetPassThroughButtons(unpack(desiredButtons))
        else
            overlay:SetPassThroughButtons()
        end

        overlay.vgPassThroughButtonsSignature = desiredSignature
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
        if not self:ConfigureNativeContainerOverlayInput(overlay, button) then
            overlay.vgPassThroughButtonsSignature = overlay.vgPassThroughButtonsSignature or ""
        end
        suppressNativeOverlayVisuals(overlay)
        overlay:Hide()
        button.nativeContainerOverlay = overlay
        return overlay
    end

    function controller:UpdateNativeContainerOverlay(button)
        local shouldUseNativeOverlay = self:ShouldUseNativeOverlay(button)
        local overlay = button.nativeContainerOverlay or (shouldUseNativeOverlay and self:AcquireNativeContainerOverlay(button)) or nil
        if not overlay then
            return
        end

        if not shouldUseNativeOverlay then
            if type(InCombatLockdown) == "function" and InCombatLockdown() then
                if host.pendingSecureItemRefresh ~= nil then
                    host.pendingSecureItemRefresh = true
                end
                return
            end

            overlay:EnableMouse(false)
            overlay:Hide()
            return
        end

        overlay:EnableMouse(self:GetOverlayMouseEnabled(button))
        if not self:ConfigureNativeContainerOverlayInput(overlay, button) then
            return
        end

        if shouldUseNativeOverlay then
            local overlayBagID, overlaySlotID = self:GetNativeOverlayBagSlot(button)
            if overlayBagID ~= nil and type(button.SetID) == "function" then
                button:SetID(overlayBagID)
            end
            local currentBagID = overlay.GetBagID and overlay:GetBagID() or nil
            local needsRefresh = not overlay:IsShown()
                or overlay:GetID() ~= overlaySlotID
                or currentBagID ~= overlayBagID

            if needsRefresh then
                if host.pendingSecureItemRefresh ~= nil and InCombatLockdown() then
                    host.pendingSecureItemRefresh = true
                    return
                end
                overlay:SetID(overlaySlotID)
                if type(overlay.UpdateExtended) == "function" then
                    overlay:UpdateExtended()
                end
            end

            overlay:SetAllPoints(button)
            overlay:SetFrameLevel(button:GetFrameLevel() + 10)
            suppressNativeOverlayVisuals(overlay)
            overlay:Show()
            return
        end

        if overlay:IsShown() then
            if host.pendingSecureItemRefresh ~= nil and InCombatLockdown() then
                host.pendingSecureItemRefresh = true
                return
            end
            overlay:Hide()
        end
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
        button.bagID = button.isCombined and nil or record.bagID
        button.slotID = button.isCombined and nil or record.slotID
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
