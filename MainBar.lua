local SP = ShiftPally

local BACKDROP_BAR = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local BACKDROP_BTN = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

function SP:CreateMainBar()
    local bar = CreateFrame("Frame", "ShiftPallyMainBar", UIParent, "BackdropTemplate")
    bar:SetSize(156, 34)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    bar:SetBackdrop(BACKDROP_BAR)
    bar:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bar:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        SP.db.mainBarPos = { point = point, relPoint = relPoint, x = x, y = y }
        SP:RepositionPanels()
    end)

    if self.db and self.db.mainBarPos then
        local p = self.db.mainBarPos
        bar:ClearAllPoints()
        bar:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    end

    -- Indicator light (also serves as drag handle)
    local indicator = CreateFrame("Frame", nil, bar)
    indicator:SetSize(16, 16)
    indicator:SetPoint("LEFT", bar, "LEFT", 8, 0)
    indicator:EnableMouse(true)
    indicator:RegisterForDrag("LeftButton")
    indicator:SetScript("OnDragStart", function()
        bar:StartMoving()
    end)
    indicator:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        local point, _, relPoint, x, y = bar:GetPoint()
        SP.db.mainBarPos = { point = point, relPoint = relPoint, x = x, y = y }
        SP:RepositionPanels()
    end)
    local indicatorTex = indicator:CreateTexture(nil, "ARTWORK")
    indicatorTex:SetAllPoints()
    indicatorTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    indicatorTex:SetVertexColor(0, 1, 0)
    self.indicatorTex = indicatorTex

    -- Indicator border
    local indicatorBorder = indicator:CreateTexture(nil, "BORDER")
    indicatorBorder:SetPoint("TOPLEFT", -1, 1)
    indicatorBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    indicatorBorder:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    indicatorBorder:SetVertexColor(0, 0, 0)

    -- Buff button visual overlay
    local buffOverlay = CreateFrame("Frame", "ShiftPallyBuffOverlay", bar, "BackdropTemplate")
    buffOverlay:SetSize(56, 22)
    buffOverlay:SetPoint("LEFT", indicator, "RIGHT", 6, 0)
    buffOverlay:SetBackdrop(BACKDROP_BTN)
    buffOverlay:SetBackdropColor(0.15, 0.15, 0.2, 1)
    buffOverlay:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    buffOverlay:EnableMouse(false)
    buffOverlay:SetFrameLevel(bar:GetFrameLevel() + 5)

    local buffText = buffOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buffText:SetPoint("CENTER")
    buffText:SetText("Buff")
    self.buffOverlay = buffOverlay
    self.buffButtonText = buffText

    -- Edit button
    local editBtn = CreateFrame("Button", nil, bar, "BackdropTemplate")
    editBtn:SetSize(50, 22)
    editBtn:SetPoint("LEFT", buffOverlay, "RIGHT", 4, 0)
    editBtn:SetBackdrop(BACKDROP_BTN)
    editBtn:SetBackdropColor(0.15, 0.15, 0.2, 1)
    editBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)

    local editText = editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editText:SetPoint("CENTER")
    editText:SetText("Edit")

    editBtn:SetScript("OnClick", function()
        if SP.editPanel:IsShown() then
            SP.editPanel:Hide()
        else
            SP:ScanSpellbook()
            SP:ScanCooldowns()
            SP:UpdateEditPanel()
            SP.editPanel:Show()
            if SP.auraPanel then SP.auraPanel:Show() end
            if SP:PPIsInGroup() and not SP.useFakeData then
                SP:PPSendSelf()
                SP:PPSendREQ()
            end
        end
    end)
    editBtn:SetScript("OnEnter", function(btn) btn:SetBackdropColor(0.25, 0.25, 0.3, 1) end)
    editBtn:SetScript("OnLeave", function(btn) btn:SetBackdropColor(0.15, 0.15, 0.2, 1) end)
    self.mainBar = bar
end

function SP:CreateCastButton()
    local bar = self.mainBar
    local overlay = self.buffOverlay

    local btn = CreateFrame("Button", "ShiftPallyCastButton", bar, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    btn:SetAllPoints(overlay)
    btn:RegisterForClicks("LeftButtonDown")
    btn:EnableMouse(true)
    btn:SetFrameLevel(bar:GetFrameLevel() + 3)

    SecureHandlerWrapScript(btn, "PostClick", btn, [[
        local idx = self:GetAttribute("sp-idx") or 1
        local count = self:GetAttribute("sp-count") or 0
        idx = idx + 1
        if idx > count then
            self:SetAttribute("type", nil)
            self:SetAttribute("sp-idx", idx)
            return
        end
        self:SetAttribute("sp-idx", idx)
        self:SetAttribute("spell", self:GetAttribute("sp-" .. idx .. "-spell"))
        self:SetAttribute("unit", self:GetAttribute("sp-" .. idx .. "-unit"))
    ]], "")

    btn:SetScript("OnEnter", function()
        overlay:SetBackdropColor(0.25, 0.25, 0.3, 1)
        local buttonStale = InCombatLockdown() and SP.nextBuffSpell
            and SP.castButton and SP.castButton:GetAttribute("type") == nil
        GameTooltip:SetOwner(overlay, "ANCHOR_RIGHT")
        GameTooltip:AddLine("ShiftPally", 1, 1, 1)
        if buttonStale then
            GameTooltip:AddLine("Button updates after combat", 0.5, 0.5, 0.5)
        elseif SP.hasActionableBuffs then
            GameTooltip:AddLine("Cast: " .. SP.nextBuffSpell, 0, 1, 0)
            local castTarget = UnitName(SP.nextBuffUnit or "") or SP.nextBuffUnit or ""
            if SP.nextBuffIntendedName and SP.nextBuffIntendedName ~= castTarget then
                GameTooltip:AddLine("Target: " .. SP.nextBuffIntendedName .. " (cast on: " .. castTarget .. ")", 0.8, 0.8, 0.8)
            else
                GameTooltip:AddLine("Target: " .. castTarget, 0.8, 0.8, 0.8)
            end
        elseif not SP.nextBuffSpell then
            GameTooltip:AddLine("All buffs active!", 0, 1, 0)
        end
        if SP.outOfRangeNames and #SP.outOfRangeNames > 0 then
            local n = #SP.outOfRangeNames
            local names = table.concat(SP.outOfRangeNames, ", ")
            GameTooltip:AddLine(n .. " out of range: " .. names, 0.9, 0.2, 0.2, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        overlay:SetBackdropColor(0.15, 0.15, 0.2, 1)
        GameTooltip:Hide()
    end)

    self.castButton = btn
end

function SP:UpdateIndicator()
    if not self.indicatorTex then return end
    if not self.allBuffsActive then
        self.indicatorTex:SetVertexColor(0.9, 0, 0)
    elseif self.buffsExpiringSoon then
        self.indicatorTex:SetVertexColor(0.9, 0.9, 0)
    else
        self.indicatorTex:SetVertexColor(0, 0.9, 0)
    end
end
