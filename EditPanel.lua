local SP = ShiftPally

local BACKDROP_PANEL = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local BACKDROP_ROW = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local BACKDROP_BTN = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local BACKDROP_ICON_PICKER = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local CLASS_ATLAS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local CLASS_ICON_TCOORDS = {
    WARRIOR  = { 0, 0.25, 0, 0.25 },
    MAGE     = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE    = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID    = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER   = { 0, 0.25, 0.25, 0.5 },
    SHAMAN   = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST   = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK  = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN  = { 0, 0.25, 0.5, 0.75 },
}

SP.FAKE_OTHER_PALADINS = {
    {
        name = "Healbot",
        classAssignments = {
            WARRIOR = "wisdom", PALADIN = "wisdom", HUNTER = "wisdom",
            ROGUE = "wisdom", PRIEST = "wisdom", SHAMAN = "wisdom",
            MAGE = "wisdom", WARLOCK = "wisdom", DRUID = "wisdom",
        },
        playerBlessings = {
            ["Tankenstein"] = "kings",
            ["Healsworth"] = "light",
            ["Frostbite"] = "salvation",
        },
        selectedAura = "Concentration Aura",
    },
    {
        name = "Retpal",
        classAssignments = {
            WARRIOR = "might", PALADIN = "might", HUNTER = "might",
            ROGUE = "might", PRIEST = "might", SHAMAN = "might",
            MAGE = "might", WARLOCK = "might", DRUID = "might",
        },
        playerBlessings = {
            ["Tankenstein"] = "salvation",
            ["Healsworth"] = "sanctuary",
            ["Frostbite"] = "kings",
        },
        selectedAura = "Retribution Aura",
    },
}

local LM = 12
local CW = 294
local BASE_CW = 294
local COL_W = 50
local ROW_H = 34
local PANEL_PADDING = 26

local function GetColStartX(numCols)
    return LM + CW - numCols * COL_W - 4
end

local function ComputeContentWidth(numCols)
    if numCols <= 3 then return BASE_CW end
    return BASE_CW + (numCols - 3) * 35
end

local TAB_DEFS = {
    { key = "class", label = "Class" },
    { key = "individual", label = "Individual" },
    { key = "overrides", label = "Overrides" },
}

-- ═══════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════

local menuFrame

local function GetMenuFrame()
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "ShiftPallyMenu", UIParent, "UIDropDownMenuTemplate")
    end
    return menuFrame
end

local clickCatcher

local function ShowClickCatcher()
    if not clickCatcher then
        clickCatcher = CreateFrame("Button", nil, UIParent)
        clickCatcher:SetAllPoints(UIParent)
        clickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        clickCatcher:SetFrameLevel(0)
        clickCatcher:RegisterForClicks("AnyUp")
        clickCatcher:SetScript("OnClick", function(self)
            CloseDropDownMenus()
            self:Hide()
        end)
        if DropDownList1 then
            DropDownList1:HookScript("OnHide", function()
                if clickCatcher then clickCatcher:Hide() end
            end)
        end
    end
    clickCatcher:Show()
end

local function SafeEasyMenu(menuList, mf, anchor, x, y, displayMode)
    UIDropDownMenu_Initialize(mf, function(self, level)
        for _, item in ipairs(menuList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.func = item.func
            info.checked = item.checked
            info.isTitle = item.isTitle
            info.disabled = item.disabled
            info.notCheckable = item.notCheckable
            UIDropDownMenu_AddButton(info)
        end
    end, displayMode)
    ToggleDropDownMenu(1, nil, mf, anchor, x, y)
    ShowClickCatcher()
end

local function MakeButton(parent, x, y, w, h)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetBackdrop(BACKDROP_BTN)
    btn:SetBackdropColor(0.2, 0.2, 0.25, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 5, 0)
    fs:SetPoint("RIGHT", -5, 0)
    fs:SetJustifyH("LEFT")
    btn.text = fs
    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.35, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.25, 1) end)
    return btn
end

local function MakeDropdownButton(parent, x, y, w, h)
    local btn = MakeButton(parent, x, y, w, h)
    btn.text:SetPoint("RIGHT", -16, 0)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(10, 10)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    return btn
end

local function MakeCheckbox(parent, x, y, label, checked, onClick, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetChecked(checked)
    cb:SetScript("OnClick", onClick)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return cb
end

-- ═══════════════════════════════════════════
-- Pagination
-- ═══════════════════════════════════════════

local ROWS_PER_PAGE = 7

local function GetPageSlice(items, page)
    local totalPages = math.max(1, math.ceil(#items / ROWS_PER_PAGE))
    page = math.max(1, math.min(page, totalPages))
    local startIdx = (page - 1) * ROWS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ROWS_PER_PAGE - 1, #items)
    return startIdx, endIdx, page, totalPages
end

local function RenderPaginationControls(content, y, page, totalPages, totalItems)
    if totalPages <= 1 then return y end

    y = y - 4
    local startIdx = (page - 1) * ROWS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ROWS_PER_PAGE - 1, totalItems)

    local labelText = "Showing " .. startIdx .. "-" .. endIdx .. " of " .. totalItems
    local btnW = 30
    local gap = 6
    local pageFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageFS:SetText(labelText)
    local labelW = pageFS:GetStringWidth()
    local totalW = btnW + gap + labelW + gap + btnW
    local startX = LM + (CW - totalW) / 2

    local prevBtn = MakeButton(content, startX, y, btnW, 20)
    prevBtn.text:SetText("<")
    prevBtn.text:SetJustifyH("CENTER")
    if page <= 1 then
        prevBtn:SetAlpha(0.3)
        prevBtn:Disable()
    else
        prevBtn:SetScript("OnClick", function()
            SP.currentPage = page - 1
            SP:UpdateEditPanel()
        end)
    end

    pageFS:SetPoint("TOPLEFT", content, "TOPLEFT", startX + btnW + gap, y - 4)
    pageFS:SetTextColor(0.6, 0.6, 0.6)

    local nextBtn = MakeButton(content, startX + btnW + gap + labelW + gap, y, btnW, 20)
    nextBtn.text:SetText(">")
    nextBtn.text:SetJustifyH("CENTER")
    if page >= totalPages then
        nextBtn:SetAlpha(0.3)
        nextBtn:Disable()
    else
        nextBtn:SetScript("OnClick", function()
            SP.currentPage = page + 1
            SP:UpdateEditPanel()
        end)
    end

    y = y - 24
    return y
end

-- ═══════════════════════════════════════════
-- Paladin Column Helpers
-- ═══════════════════════════════════════════

local function GetPaladinColumns()
    local cols = {}
    if SP.db.showOtherPaladins then
        if SP.useFakeData then
            for _, fake in ipairs(SP.FAKE_OTHER_PALADINS) do
                table.insert(cols, { name = fake.name, isSelf = false, data = fake })
            end
        else
            local myName = UnitName("player") or "You"
            for _, name in ipairs(SP.ppState.SyncList) do
                if name ~= myName then
                    table.insert(cols, {
                        name = name,
                        isSelf = false,
                        data = SP:PPStateToSPData(name),
                        ppName = name,
                    })
                end
            end
        end
    end
    local playerName = UnitName("player") or "You"
    table.insert(cols, { name = playerName, isSelf = true, data = SP.charDB })
    return cols
end

local function GetEffectiveBlessing(pData, member)
    if pData.playerBlessings and pData.playerBlessings[member.name] then
        return pData.playerBlessings[member.name]
    end
    if pData.classAssignments then
        return pData.classAssignments[member.class]
    end
    return nil
end

local function IsPlayerOverride(member)
    local key = SP.charDB.playerBlessings[member.name]
    if not key then return false end
    return key ~= SP.charDB.classAssignments[member.class]
end

local function IsPaladinOverride(pData, member)
    local key = pData.playerBlessings and pData.playerBlessings[member.name]
    if not key then return false end
    return key ~= (pData.classAssignments and pData.classAssignments[member.class])
end

-- ═══════════════════════════════════════════
-- Icon Picker
-- ═══════════════════════════════════════════

local iconPicker

local function HideIconPicker()
    if iconPicker then iconPicker:Hide() end
    SP.iconPickerOpen = false
end

local function ShowIconPicker(anchor, currentKey, onSelect, blessings)
    if not iconPicker then
        iconPicker = CreateFrame("Frame", "ShiftPallyIconPicker", UIParent, "BackdropTemplate")
        iconPicker:SetBackdrop(BACKDROP_ICON_PICKER)
        iconPicker:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
        iconPicker:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
        iconPicker:SetFrameStrata("FULLSCREEN_DIALOG")
        iconPicker:SetClampedToScreen(true)
        iconPicker:EnableMouse(true)
        iconPicker.buttons = {}
    end

    for _, btn in ipairs(iconPicker.buttons) do btn:Hide() end

    blessings = blessings or SP:GetKnownBlessings()
    local allItems = {}
    for _, b in ipairs(blessings) do table.insert(allItems, b) end
    table.insert(allItems, { key = nil, name = "None", isNone = true })

    local iconSize = 30
    local spacing = 5
    local cols = 3
    local rows = math.ceil(#allItems / cols)
    local inset = 8
    local w = cols * iconSize + (cols - 1) * spacing + inset * 2
    local h = rows * iconSize + (rows - 1) * spacing + inset * 2

    iconPicker:SetSize(w, h)
    iconPicker:ClearAllPoints()
    iconPicker:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)
    iconPicker.anchor = anchor

    for i, item in ipairs(allItems) do
        local btn = iconPicker.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, iconPicker)
            btn:SetSize(iconSize, iconSize)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            bg:SetVertexColor(0.12, 0.12, 0.16, 1)
            btn.bg = bg
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            btn.icon = tex
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            hl:SetVertexColor(1, 1, 1, 0.15)
            iconPicker.buttons[i] = btn
        end

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", iconPicker, "TOPLEFT",
            inset + col * (iconSize + spacing),
            -(inset + row * (iconSize + spacing)))

        if item.isNone then
            btn.icon:SetTexture(nil)
            if not btn.noneText then
                local nt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nt:SetPoint("CENTER")
                nt:SetText("None")
                nt:SetTextColor(0.75, 0.75, 0.75)
                btn.noneText = nt
            end
            btn.noneText:Show()
        else
            local _, _, icon = GetSpellInfo(item.name)
            btn.icon:SetTexture(icon or SP.BLESSING_ICONS[item.key])
            btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            if btn.noneText then btn.noneText:Hide() end
        end

        btn.bg:SetVertexColor(0.12, 0.12, 0.16, 1)
        local itemKey = item.key
        local itemName = item.name
        btn:SetScript("OnClick", function()
            onSelect(itemKey)
            HideIconPicker()
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(itemName:gsub("Blessing of ", ""))
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Show()
    end

    iconPicker:Show()
    SP.iconPickerOpen = true
end

-- ═══════════════════════════════════════════
-- Aura Icon Picker
-- ═══════════════════════════════════════════

local auraIconPicker

local function HideAuraIconPicker()
    if auraIconPicker then auraIconPicker:Hide() end
    SP.auraIconPickerOpen = false
end

local function ShowAuraIconPicker(anchor, currentAura, onSelect, auras)
    if not auraIconPicker then
        auraIconPicker = CreateFrame("Frame", "ShiftPallyAuraIconPicker", UIParent, "BackdropTemplate")
        auraIconPicker:SetBackdrop(BACKDROP_ICON_PICKER)
        auraIconPicker:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
        auraIconPicker:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
        auraIconPicker:SetFrameStrata("FULLSCREEN_DIALOG")
        auraIconPicker:SetClampedToScreen(true)
        auraIconPicker:EnableMouse(true)
        auraIconPicker.buttons = {}
    end

    for _, btn in ipairs(auraIconPicker.buttons) do btn:Hide() end

    auras = auras or SP:GetKnownAuras()
    local allItems = {}
    for _, a in ipairs(auras) do table.insert(allItems, { name = a }) end
    table.insert(allItems, { name = "None", isNone = true })

    local iconSize = 30
    local spacing = 5
    local cols = 3
    local rows = math.ceil(#allItems / cols)
    local inset = 8
    local w = cols * iconSize + (cols - 1) * spacing + inset * 2
    local h = rows * iconSize + (rows - 1) * spacing + inset * 2

    auraIconPicker:SetSize(w, h)
    auraIconPicker:ClearAllPoints()
    auraIconPicker:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)
    auraIconPicker.anchor = anchor

    for i, item in ipairs(allItems) do
        local btn = auraIconPicker.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, auraIconPicker)
            btn:SetSize(iconSize, iconSize)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            bg:SetVertexColor(0.12, 0.12, 0.16, 1)
            btn.bg = bg
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            btn.icon = tex
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            hl:SetVertexColor(1, 1, 1, 0.15)
            auraIconPicker.buttons[i] = btn
        end

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", auraIconPicker, "TOPLEFT",
            inset + col * (iconSize + spacing),
            -(inset + row * (iconSize + spacing)))

        if item.isNone then
            btn.icon:SetTexture(nil)
            if not btn.noneText then
                local nt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nt:SetPoint("CENTER")
                nt:SetText("None")
                nt:SetTextColor(0.75, 0.75, 0.75)
                btn.noneText = nt
            end
            btn.noneText:Show()
        else
            btn.icon:SetTexture(SP:GetAuraIcon(item.name))
            btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            if btn.noneText then btn.noneText:Hide() end
        end

        btn.bg:SetVertexColor(0.12, 0.12, 0.16, 1)
        local itemName = item.name
        local isNone = item.isNone
        btn:SetScript("OnClick", function()
            onSelect(isNone and nil or itemName)
            HideAuraIconPicker()
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(itemName:gsub(" Aura$", ""))
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Show()
    end

    auraIconPicker:Show()
    SP.auraIconPickerOpen = true
end

-- ═══════════════════════════════════════════
-- Content Management
-- ═══════════════════════════════════════════

local function ClearContent(contentFrame)
    local children = { contentFrame:GetChildren() }
    for _, child in ipairs(children) do child:Hide() end
    local regions = { contentFrame:GetRegions() }
    for _, region in ipairs(regions) do region:Hide() end
end

-- ═══════════════════════════════════════════
-- Blessing Cell
-- ═══════════════════════════════════════════

local function CreateBlessingCell(row, colIndex, numCols, blessingKey, isSelf, onSelect, greenBorder, colLabel, greaterIcon, overriddenKey, paladinName)
    local colStartX = GetColStartX(numCols)
    local x = colStartX - LM + (colIndex - 1) * COL_W + (COL_W - 30) / 2

    local iconBtn = CreateFrame("Button", nil, row)
    iconBtn:SetSize(30, 30)
    iconBtn:SetPoint("LEFT", row, "LEFT", x, 0)

    local border = iconBtn:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    if greenBorder then
        border:SetVertexColor(0, 0.8, 0, 0.9)
    else
        border:SetVertexColor(0.3, 0.3, 0.35, 1)
    end

    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", 2, -2)
    iconTex:SetPoint("BOTTOMRIGHT", -2, 2)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if blessingKey then
        local icon = greaterIcon and SP:GetGreaterBlessingIcon(blessingKey) or SP:GetBlessingIcon(blessingKey)
        iconTex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
        iconTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    end

    if onSelect then
        local hl = iconBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.3)

        iconBtn:SetScript("OnClick", function(btn)
            if iconPicker and iconPicker:IsShown() and iconPicker.anchor == btn then
                HideIconPicker()
            else
                HideIconPicker()
                local available = SP:GetAvailableBlessingsForPaladin(paladinName)
                ShowIconPicker(btn, blessingKey, onSelect, available)
            end
        end)
        iconBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if blessingKey then
                GameTooltip:AddLine(SP:GetBlessingDisplayName(blessingKey), 1, 1, 1)
            else
                GameTooltip:AddLine("No blessing assigned", 1, 0.3, 0.3)
            end
            if overriddenKey then
                GameTooltip:AddLine("Overrides " .. SP:GetBlessingDisplayName(overriddenKey), 0.9, 0.6, 0.2)
            end
            GameTooltip:AddLine("Click to change", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        iconBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if blessingKey then
                GameTooltip:AddLine(SP:GetBlessingDisplayName(blessingKey), 1, 1, 1)
            else
                GameTooltip:AddLine("None", 0.5, 0.5, 0.5)
            end
            if overriddenKey then
                GameTooltip:AddLine("Overrides " .. SP:GetBlessingDisplayName(overriddenKey), 0.9, 0.6, 0.2)
            end
            GameTooltip:AddLine("Assigned by " .. (colLabel or "other"), 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    return iconBtn
end

-- ═══════════════════════════════════════════
-- Create Edit Panel
-- ═══════════════════════════════════════════

function SP:CreateEditPanel()
    local panel = CreateFrame("Frame", "ShiftPallyEditPanel", UIParent, "BackdropTemplate")
    panel:SetSize(320, 400)
    panel:SetPoint("TOPRIGHT", self.mainBar, "TOPLEFT", -5, 10)
    panel:SetBackdrop(BACKDROP_PANEL)
    panel:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()

    tinsert(UISpecialFrames, "ShiftPallyEditPanel")

    panel:SetScript("OnHide", function()
        HideIconPicker()
        HideAuraIconPicker()
        if SP.auraPanel then SP.auraPanel:Hide() end
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cFFFFD100ShiftPally|r TBC Classic")

    local closeBtn = CreateFrame("Button", nil, panel)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -6)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    closeText:SetTextColor(0.8, 0.6, 0)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.2, 0.2) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(0.8, 0.6, 0) end)

    local tabButtons = {}
    local tabW = 80
    local tabH = 22
    local tabGap = 4
    local totalTabW = #TAB_DEFS * tabW + (#TAB_DEFS - 1) * tabGap
    local tabStartX = (320 - totalTabW) / 2
    for i, def in ipairs(TAB_DEFS) do
        local tab = CreateFrame("Button", nil, panel, "BackdropTemplate")
        tab:SetSize(tabW, tabH)
        tab:SetPoint("TOPLEFT", panel, "TOPLEFT", tabStartX + (i - 1) * (tabW + tabGap), -28)
        tab:SetBackdrop(BACKDROP_BTN)
        tab.viewKey = def.key
        local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tabText:SetPoint("CENTER")
        tabText:SetText(def.label)
        tab.text = tabText
        tab:SetScript("OnClick", function()
            SP.currentView = def.key
            SP.currentPage = 1
            SP:UpdateEditPanel()
        end)
        tab:SetScript("OnEnter", function(self)
            if self.viewKey ~= SP.currentView then
                self:SetBackdropColor(0.2, 0.2, 0.28, 1)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if self.viewKey ~= SP.currentView then
                self:SetBackdropColor(0.12, 0.12, 0.18, 1)
            end
        end)
        table.insert(tabButtons, tab)
    end
    panel.tabButtons = tabButtons

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 0, -54)
    content:SetPoint("BOTTOMRIGHT")
    panel.content = content

    self.editPanel = panel
    self.currentView = self.currentView or "class"

    self:CreateAuraPanel()
end

-- ═══════════════════════════════════════════
-- Tab Highlights
-- ═══════════════════════════════════════════

function SP:UpdateTabHighlights()
    if not self.editPanel or not self.editPanel.tabButtons then return end
    for _, tab in ipairs(self.editPanel.tabButtons) do
        if tab.viewKey == self.currentView then
            tab:SetBackdropColor(0.25, 0.25, 0.35, 1)
            tab:SetBackdropBorderColor(0.5, 0.5, 0.6, 1)
            tab.text:SetTextColor(1, 0.82, 0)
        else
            tab:SetBackdropColor(0.12, 0.12, 0.18, 1)
            tab:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
            tab.text:SetTextColor(0.6, 0.6, 0.6)
        end
    end
end

-- ═══════════════════════════════════════════
-- Update Edit Panel (Dispatcher)
-- ═══════════════════════════════════════════

function SP:UpdateEditPanel()
    if not self.editPanel then return end
    HideIconPicker()
    HideAuraIconPicker()

    local cols = GetPaladinColumns()
    CW = ComputeContentWidth(#cols)
    local panelW = CW + PANEL_PADDING
    self.editPanel:SetWidth(panelW)

    if self.editPanel.tabButtons then
        local tabW, tabGap = 80, 4
        local totalTabW = #TAB_DEFS * tabW + (#TAB_DEFS - 1) * tabGap
        local tabStartX = (panelW - totalTabW) / 2
        for i, tab in ipairs(self.editPanel.tabButtons) do
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", self.editPanel, "TOPLEFT", tabStartX + (i - 1) * (tabW + tabGap), -28)
        end
    end

    local content = self.editPanel.content
    ClearContent(content)
    self:UpdateTabHighlights()

    local y = -2

    if self.currentView == "class" then
        y = self:RenderClassView(content, y)
    elseif self.currentView == "individual" then
        y = self:RenderIndividualView(content, y)
    elseif self.currentView == "overrides" then
        y = self:RenderOverridesView(content, y)
    end

    y = self:RenderSettings(content, y)

    self.editPanel:SetHeight(54 + math.abs(y) + 6)

    if self.auraPanel then
        self:UpdateAuraPanel()
    end
end

-- ═══════════════════════════════════════════
-- Column Headers
-- ═══════════════════════════════════════════

function SP:RenderColumnHeaders(content, y, cols)
    local colStartX = GetColStartX(#cols)
    for i, col in ipairs(cols) do
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", colStartX + (i - 1) * COL_W, y)
        fs:SetWidth(COL_W)
        fs:SetJustifyH("CENTER")
        if col.isSelf then
            fs:SetTextColor(1, 0.82, 0)
            fs:SetText("You")
        else
            fs:SetTextColor(0.6, 0.6, 0.6)
            fs:SetText(col.name)
        end
    end
    return y - 16
end

-- ═══════════════════════════════════════════
-- Class View
-- ═══════════════════════════════════════════

function SP:RenderClassView(content, y)
    local cols = GetPaladinColumns()
    y = self:RenderColumnHeaders(content, y, cols)

    local page = self.currentPage or 1
    local startIdx, endIdx, totalPages
    startIdx, endIdx, page, totalPages = GetPageSlice(self.CLASS_ORDER, page)
    self.currentPage = page

    for idx = startIdx, endIdx do
        local class = self.CLASS_ORDER[idx]
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(CW, ROW_H)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", LM, y)
        row:SetBackdrop(BACKDROP_ROW)
        row:SetBackdropColor(0.08, 0.08, 0.12, 0.8)
        row:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

        local classIcon = row:CreateTexture(nil, "ARTWORK")
        classIcon:SetSize(26, 26)
        classIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
        classIcon:SetTexture(CLASS_ATLAS)
        local coords = CLASS_ICON_TCOORDS[class]
        if coords then classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end

        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        local colStartX = GetColStartX(#cols)
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
        nameFS:SetWidth(colStartX - LM - 40)
        nameFS:SetJustifyH("LEFT")
        if cc then nameFS:SetTextColor(cc.r, cc.g, cc.b) end
        nameFS:SetText(SP.CLASS_NAMES[class] or class)

        for i, col in ipairs(cols) do
            local blessingKey = col.data.classAssignments and col.data.classAssignments[class]
            local classRef = class
            local onSelect = nil
            if col.isSelf then
                onSelect = function(key) SP:SetClassAssignment(classRef, key) end
            elseif SP.db.editOtherPaladins and SP:PPCanEditPaladin(col.ppName) then
                if col.ppName then
                    local ppName = col.ppName
                    onSelect = function(key) SP:PPAssignOtherClass(ppName, classRef, key) end
                else
                    local colData = col.data
                    onSelect = function(key)
                        if not colData.classAssignments then colData.classAssignments = {} end
                        colData.classAssignments[classRef] = key
                        SP:UpdateEditPanel()
                    end
                end
            end
            CreateBlessingCell(row, i, #cols, blessingKey, col.isSelf, onSelect, false, col.name, true, nil, col.ppName)
        end

        y = y - ROW_H - 4
    end

    if totalPages > 1 then
        y = y - (ROWS_PER_PAGE - (endIdx - startIdx + 1)) * (ROW_H + 4)
    end

    y = RenderPaginationControls(content, y, page, totalPages, #self.CLASS_ORDER)

    return y
end

-- ═══════════════════════════════════════════
-- Individual View
-- ═══════════════════════════════════════════

function SP:RenderIndividualView(content, y)
    local cols = GetPaladinColumns()
    y = self:RenderColumnHeaders(content, y, cols)

    local page = self.currentPage or 1
    local startIdx, endIdx, totalPages
    startIdx, endIdx, page, totalPages = GetPageSlice(self.partyMembers, page)
    self.currentPage = page

    for idx = startIdx, endIdx do
        local member = self.partyMembers[idx]
        y = self:RenderMemberRow(content, member, y, cols, false)
    end

    if totalPages > 1 then
        y = y - (ROWS_PER_PAGE - (endIdx - startIdx + 1)) * (ROW_H + 4)
    end

    y = RenderPaginationControls(content, y, page, totalPages, #self.partyMembers)

    local salvW, classW, btnGap = 110, 115, 6
    local btnStartX = LM + (CW - salvW - btnGap - classW) / 2

    local salvBtn = MakeButton(content, btnStartX, y - 4, salvW, 22)
    salvBtn.text:SetText("Salv Defaults")
    salvBtn.text:SetJustifyH("CENTER")
    salvBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.35, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Salv Defaults", 1, 1, 1)
        GameTooltip:AddLine("Salvation on everyone, except: Tanks get Light, you get Wisdom. If your role is Tank: you get Sanctuary, Healers get Wisdom.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    salvBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.25, 1)
        GameTooltip:Hide()
    end)
    salvBtn:SetScript("OnClick", function() SP:SalvAll() end)

    local classBtn = MakeButton(content, btnStartX + salvW + btnGap, y - 4, classW, 22)
    classBtn.text:SetText("Class Defaults")
    classBtn.text:SetJustifyH("CENTER")
    classBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.35, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Class Defaults", 1, 1, 1)
        GameTooltip:AddLine("Sets yourself to Wisdom, Tanks to Light, and all others to their class default.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    classBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.25, 1)
        GameTooltip:Hide()
    end)
    classBtn:SetScript("OnClick", function() SP:ApplyDefaults() end)

    y = y - 30
    return y
end

-- ═══════════════════════════════════════════
-- Member Row (Individual + Overrides views)
-- ═══════════════════════════════════════════

function SP:RenderMemberRow(content, member, y, cols, overridesOnly)
    local m = member
    local isOverride = IsPlayerOverride(m)
    local showSelfCell = not overridesOnly or isOverride

    local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
    row:SetSize(CW, ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", LM, y)
    row:SetBackdrop(BACKDROP_ROW)

    if overridesOnly and not showSelfCell then
        row:SetBackdropColor(0.06, 0.06, 0.08, 0.5)
        row:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.5)
    else
        row:SetBackdropColor(0.08, 0.08, 0.12, 0.8)
        row:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
    end

    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(28, 28)
    classIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
    if m.isPet then
        classIcon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTraining")
        classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        classIcon:SetTexture(CLASS_ATLAS)
        local coords = CLASS_ICON_TCOORDS[m.class]
        if coords then classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
    end

    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    local colStartX = GetColStartX(#cols)
    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
    nameFS:SetWidth(colStartX - LM - 40)
    nameFS:SetJustifyH("LEFT")
    if m.isPet then
        nameFS:SetTextColor(0.6, 0.9, 0.6)
        local display = m.name
        if m.ownerName then display = display .. " |cFF888888(" .. m.ownerName .. ")|r" end
        nameFS:SetText(display)
    else
        if cc then nameFS:SetTextColor(cc.r, cc.g, cc.b) end
        nameFS:SetText(m.name)
    end

    if overridesOnly and not showSelfCell then
        nameFS:SetAlpha(0.4)
        classIcon:SetAlpha(0.4)
    end

    for i, col in ipairs(cols) do
        if col.isSelf then
            if showSelfCell then
                local effectiveKey = self:GetPlannedBlessingKey(m)
                local memberRef = m
                local onSelect = function(key) SP:SetPlayerBlessing(memberRef.name, key) end

                if not effectiveKey and not overridesOnly and not m.isPet then
                    row:SetBackdropColor(0.25, 0.06, 0.06, 0.8)
                    row:SetBackdropBorderColor(0.5, 0.15, 0.15, 1)
                end

                local classDefault = isOverride and SP.charDB.classAssignments[m.class] or nil
                CreateBlessingCell(row, i, #cols, effectiveKey, true, onSelect, isOverride and not overridesOnly, col.name, not isOverride, classDefault, nil)
            end
        else
            if not overridesOnly or showSelfCell then
                local effectiveKey = GetEffectiveBlessing(col.data, m)
                local otherOnSelect = nil
                if SP.db.editOtherPaladins and SP:PPCanEditPaladin(col.ppName) then
                    if col.ppName then
                        local ppName = col.ppName
                        local memberRef = m
                        otherOnSelect = function(key) SP:PPAssignOtherPlayer(ppName, memberRef, key) end
                    else
                        local colData = col.data
                        local memberRef = m
                        otherOnSelect = function(key)
                            if not colData.playerBlessings then colData.playerBlessings = {} end
                            colData.playerBlessings[memberRef.name] = key
                            SP:UpdateEditPanel()
                        end
                    end
                end
                local otherIsOverride = IsPaladinOverride(col.data, m)
                local otherClassDefault = otherIsOverride and col.data.classAssignments and col.data.classAssignments[m.class] or nil
                CreateBlessingCell(row, i, #cols, effectiveKey, false, otherOnSelect, otherIsOverride and not overridesOnly, col.name, not otherIsOverride, otherClassDefault, col.ppName)
            end
        end
    end

    return y - ROW_H - 4
end

-- ═══════════════════════════════════════════
-- Overrides View
-- ═══════════════════════════════════════════

function SP:RenderOverridesView(content, y)
    local cols = GetPaladinColumns()
    y = self:RenderColumnHeaders(content, y, cols)

    local hasAny = false
    for _, member in ipairs(self.partyMembers) do
        if IsPlayerOverride(member) then hasAny = true end
    end

    local page = self.currentPage or 1
    local startIdx, endIdx, totalPages
    startIdx, endIdx, page, totalPages = GetPageSlice(self.partyMembers, page)
    self.currentPage = page

    for idx = startIdx, endIdx do
        local member = self.partyMembers[idx]
        y = self:RenderMemberRow(content, member, y, cols, true)
    end

    if totalPages > 1 then
        y = y - (ROWS_PER_PAGE - (endIdx - startIdx + 1)) * (ROW_H + 4)
    end

    y = RenderPaginationControls(content, y, page, totalPages, #self.partyMembers)

    if not hasAny then
        local note = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", content, "TOPLEFT", LM, y - 4)
        note:SetWidth(CW)
        note:SetJustifyH("LEFT")
        note:SetText("No overrides. Use the Individual view to set per-player blessings that differ from class defaults.")
        y = y - 30
    end

    return y
end

-- ═══════════════════════════════════════════
-- Settings Section
-- ═══════════════════════════════════════════

function SP:RenderSettings(content, y)
    y = y - 6

    local hdr = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", content, "TOPLEFT", LM, y)
    hdr:SetText("|cFF888888Settings|r")
    y = y - 20

    MakeCheckbox(content, LM, y, "Righteous Fury when not in party", SP.db.rfSolo, function(self)
        SP.db.rfSolo = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Righteous Fury when role is Tank", SP.db.rfTank, function(self)
        SP.db.rfTank = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Ignore Aura", SP.db.ignoreAura, function(self)
        SP.db.ignoreAura = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Ignore Blessings", SP.db.ignoreBlessings, function(self)
        SP.db.ignoreBlessings = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Use single-target blessings instead of greater", SP.db.useBaseBlessings, function(self)
        SP.db.useBaseBlessings = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Early warning for greater blessings (15 min)", SP.db.earlyGreaterWarning, function(self)
        SP.db.earlyGreaterWarning = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end, "Default is 2 minutes. Greater blessings cost a reagent, so earlier warning gives time to batch refreshes.")
    y = y - 28

    MakeCheckbox(content, LM, y, "Show other paladins", SP.db.showOtherPaladins, function(self)
        SP.db.showOtherPaladins = self:GetChecked() and true or false
        SP:UpdateEditPanel()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Show pets", SP.db.showPets, function(self)
        SP.db.showPets = self:GetChecked() and true or false
        SP:ScanParty()
        SP:UpdateBuffStatus()
        SP:UpdateEditPanel()
    end, "Show hunter and warlock pets in Individual and Overrides tabs for single-target blessing assignments. Pets already receive Greater Blessings through their class mapping (hunter pets = Warrior, etc).")
    y = y - 22

    MakeCheckbox(content, LM, y, "Allow non-leaders to assign my buffs", SP.db.allowNonLeaderAssign, function(self)
        SP.db.allowNonLeaderAssign = self:GetChecked() and true or false
    end, "Leaders can always assign buffs.")
    y = y - 22

    MakeCheckbox(content, LM, y, "Enable editing other paladins' buffs", SP.db.editOtherPaladins, function(self)
        SP.db.editOtherPaladins = self:GetChecked() and true or false
        SP:UpdateAuraPanel()
    end, "Requires leader or other paladin to have freeuse set in PallyPower.")
    y = y - 28

    local clearBtn = MakeButton(content, LM, y, 120, 22)
    clearBtn.text:SetText("|cFFFF4444Clear All Buffs|r")
    clearBtn.text:SetJustifyH("CENTER")
    clearBtn:SetScript("OnClick", function() SP:ClearAll() end)
    y = y - 30

    local noteFS = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteFS:SetPoint("TOPLEFT", content, "TOPLEFT", LM, y)
    noteFS:SetWidth(CW)
    noteFS:SetJustifyH("LEFT")
    noteFS:SetText("Buff button loads all missing buffs when you enter combat. If a buff drops mid-fight, the indicator updates but the button can't change until combat ends (WoW restriction).")
    y = y - noteFS:GetStringHeight() - 8

    return y
end

-- ═══════════════════════════════════════════
-- Aura Panel
-- ═══════════════════════════════════════════

function SP:CreateAuraPanel()
    local panel = CreateFrame("Frame", "ShiftPallyAuraPanel", UIParent, "BackdropTemplate")
    panel:SetSize(180, 100)
    panel:SetPoint("TOPRIGHT", self.editPanel, "TOPLEFT", -5, 0)
    panel:SetBackdrop(BACKDROP_PANEL)
    panel:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cFFFFD100Auras|r")

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 0, -28)
    content:SetPoint("BOTTOMRIGHT")
    panel.content = content

    self.auraPanel = panel
end

function SP:UpdateAuraPanel()
    if not self.auraPanel then return end
    HideAuraIconPicker()

    local content = self.auraPanel.content
    ClearContent(content)

    local y = -4
    local lm = 10
    local cols = GetPaladinColumns()

    for _, col in ipairs(cols) do
        local nameFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("TOPLEFT", content, "TOPLEFT", lm, y)
        if col.isSelf then
            nameFS:SetTextColor(1, 0.82, 0)
            nameFS:SetText("You")
        else
            nameFS:SetTextColor(0.6, 0.6, 0.6)
            nameFS:SetText(col.name)
        end
        y = y - 16

        local auraName = col.data.selectedAura

        local iconBtn = CreateFrame("Button", nil, content)
        iconBtn:SetSize(30, 30)
        iconBtn:SetPoint("TOPLEFT", content, "TOPLEFT", lm, y)

        local border = iconBtn:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        border:SetVertexColor(0.3, 0.3, 0.35, 1)

        local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", 2, -2)
        iconTex:SetPoint("BOTTOMRIGHT", -2, 2)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        if auraName then
            iconTex:SetTexture(SP:GetAuraIcon(auraName) or "Interface\\Icons\\INV_Misc_QuestionMark")
        else
            iconTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        end

        local hl = iconBtn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.3)

        if col.isSelf then
            iconBtn:SetScript("OnClick", function(btn)
                if auraIconPicker and auraIconPicker:IsShown() and auraIconPicker.anchor == btn then
                    HideAuraIconPicker()
                else
                    HideAuraIconPicker()
                    ShowAuraIconPicker(btn, SP.charDB.selectedAura, function(aura)
                        SP:SetAura(aura)
                    end)
                end
            end)
            iconBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(auraName and auraName:gsub(" Aura$", "") or "None", 1, 1, 1)
                GameTooltip:AddLine("Click to change", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        elseif SP.db.editOtherPaladins and SP:PPCanEditPaladin(col.ppName) then
            if col.ppName then
                local ppName = col.ppName
                iconBtn:SetScript("OnClick", function(btn)
                    if auraIconPicker and auraIconPicker:IsShown() and auraIconPicker.anchor == btn then
                        HideAuraIconPicker()
                    else
                        HideAuraIconPicker()
                        local available = SP:GetAvailableAurasForPaladin(ppName)
                        ShowAuraIconPicker(btn, auraName, function(aura)
                            SP:PPAssignOtherAura(ppName, aura)
                        end, available)
                    end
                end)
            else
                local colData = col.data
                iconBtn:SetScript("OnClick", function(btn)
                    if auraIconPicker and auraIconPicker:IsShown() and auraIconPicker.anchor == btn then
                        HideAuraIconPicker()
                    else
                        HideAuraIconPicker()
                        ShowAuraIconPicker(btn, colData.selectedAura, function(aura)
                            colData.selectedAura = aura
                            SP:UpdateAuraPanel()
                        end)
                    end
                end)
            end
            iconBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(auraName and auraName:gsub(" Aura$", "") or "None", 1, 1, 1)
                GameTooltip:AddLine("Click to change", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            iconBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(auraName and auraName:gsub(" Aura$", "") or "None", 1, 1, 1)
                GameTooltip:AddLine("Assigned by " .. col.name, 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
        if auraName then
            label:SetTextColor(0.8, 0.8, 0.8)
            label:SetText(auraName:gsub(" Aura$", ""))
        else
            label:SetTextColor(0.5, 0.5, 0.5)
            label:SetText("None")
        end

        y = y - 36
    end

    self.auraPanel:SetHeight(28 + math.abs(y) + 6)
end
