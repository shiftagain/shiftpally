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

local function IsGroupMemberPaladin(name)
    if IsInRaid and IsInRaid() then
        local numRaid = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, numRaid do
            if UnitName("raid" .. i) == name then
                local _, class = UnitClass("raid" .. i)
                return class == "PALADIN"
            end
        end
    else
        for i = 1, 4 do
            if UnitName("party" .. i) == name then
                local _, class = UnitClass("party" .. i)
                return class == "PALADIN"
            end
        end
    end
    return false
end

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
                if name ~= myName and IsGroupMemberPaladin(name) then
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
        if SP.settingsPanel then SP.settingsPanel:Hide() end
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
    self:CreateSettingsPanel()
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
    self:RepositionPanels()

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
-- Settings Button (replaces inline settings)
-- ═══════════════════════════════════════════

function SP:RenderSettings(content, y)
    y = y - 8
    local hdr = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", content, "TOPLEFT", LM, y)
    hdr:SetText("|cFFFFD100Always-On Display|r")
    y = y - 16

    MakeCheckbox(content, LM, y, "Individual View UI", SP.db.individualViewUI, function(self)
        SP.db.individualViewUI = self:GetChecked() and true or false
        if SP.db.individualViewUI then SP.db.classViewUI = false end
        SP:UpdateEditPanel()
        SP:UpdateDisplay()
    end)
    y = y - 22

    MakeCheckbox(content, LM, y, "Class View UI", SP.db.classViewUI, function(self)
        SP.db.classViewUI = self:GetChecked() and true or false
        if SP.db.classViewUI then SP.db.individualViewUI = false end
        SP:UpdateEditPanel()
        SP:UpdateDisplay()
    end)
    y = y - 34

    local btnW = 120
    local gap = 6
    local totalW = btnW * 2 + gap
    local startX = LM + (CW - totalW) / 2

    local clearBtn = MakeButton(content, startX, y, btnW, 22)
    clearBtn.text:SetText("|cFFFF4444Clear All Buffs|r")
    clearBtn.text:SetJustifyH("CENTER")
    clearBtn:SetScript("OnClick", function() SP:ClearAll() end)

    local settingsBtn = MakeButton(content, startX + btnW + gap, y, btnW, 22)
    settingsBtn.text:SetText("Open Settings")
    settingsBtn.text:SetJustifyH("CENTER")
    settingsBtn:SetScript("OnClick", function()
        if SP.settingsPanel:IsShown() then
            SP.settingsPanel:Hide()
        else
            SP:UpdateSettingsPanel()
            SP.settingsPanel:Show()
        end
    end)
    y = y - 30

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

-- ═══════════════════════════════════════════
-- Panel Positioning
-- ═══════════════════════════════════════════

function SP:GetPanelSide()
    if not self.mainBar then return "LEFT" end
    local cx = self.mainBar:GetCenter()
    local screenW = GetScreenWidth()
    if cx and screenW and cx < screenW / 2 then
        return "RIGHT"
    end
    return "LEFT"
end

function SP:RepositionPanels()
    local side = self:GetPanelSide()

    if self.editPanel then
        self.editPanel:ClearAllPoints()
        if side == "RIGHT" then
            self.editPanel:SetPoint("TOPLEFT", self.mainBar, "TOPRIGHT", 5, 10)
        else
            self.editPanel:SetPoint("TOPRIGHT", self.mainBar, "TOPLEFT", -5, 10)
        end
    end

    if self.auraPanel then
        self.auraPanel:ClearAllPoints()
        if side == "RIGHT" then
            self.auraPanel:SetPoint("TOPLEFT", self.editPanel, "TOPRIGHT", 5, 0)
        else
            self.auraPanel:SetPoint("TOPRIGHT", self.editPanel, "TOPLEFT", -5, 0)
        end
    end

    if self.settingsPanel then
        self.settingsPanel:ClearAllPoints()
        if side == "RIGHT" then
            self.settingsPanel:SetPoint("TOPLEFT", self.auraPanel, "BOTTOMLEFT", 0, -5)
        else
            self.settingsPanel:SetPoint("TOPRIGHT", self.auraPanel, "BOTTOMRIGHT", 0, -5)
        end
    end
end

-- ═══════════════════════════════════════════
-- Settings Panel
-- ═══════════════════════════════════════════

function SP:CreateSettingsPanel()
    local panel = CreateFrame("Frame", "ShiftPallySettingsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(280, 400)
    panel:SetBackdrop(BACKDROP_PANEL)
    panel:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    panel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cFFFFD100Settings|r")

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

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 0, -28)
    content:SetPoint("BOTTOMRIGHT")
    panel.content = content

    self.settingsPanel = panel
end

local function RenderSettingsGroupHeader(content, y, text)
    y = y - 8
    local hdr = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
    hdr:SetText("|cFFFFD100" .. text .. "|r")
    y = y - 16
    return y
end

function SP:UpdateSettingsPanel()
    if not self.settingsPanel then return end

    local content = self.settingsPanel.content
    ClearContent(content)

    local y = -2
    local lm = 12

    y = RenderSettingsGroupHeader(content, y, "Buff Tracking")

    MakeCheckbox(content, lm, y, "Ignore Aura", SP.db.ignoreAura, function(self)
        SP.db.ignoreAura = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, lm, y, "Ignore Blessings", SP.db.ignoreBlessings, function(self)
        SP.db.ignoreBlessings = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, lm, y, "Use single-target blessings", SP.db.useBaseBlessings, function(self)
        SP.db.useBaseBlessings = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end, "Cast Blessing of X instead of Greater Blessing of X.")
    y = y - 22

    MakeCheckbox(content, lm, y, "Early warning (15 min)", SP.db.earlyGreaterWarning, function(self)
        SP.db.earlyGreaterWarning = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end, "Warn 15 minutes before greater blessings expire instead of the default 2 minutes.")
    y = y - 22

    MakeCheckbox(content, lm, y, "Show pets", SP.db.showPets, function(self)
        SP.db.showPets = self:GetChecked() and true or false
        SP:ScanParty()
        SP:UpdateBuffStatus()
        SP:UpdateEditPanel()
    end, "Show hunter and warlock pets for single-target blessing assignments.")
    y = y - 28

    y = RenderSettingsGroupHeader(content, y, "Righteous Fury")

    MakeCheckbox(content, lm, y, "RF when not in party", SP.db.rfSolo, function(self)
        SP.db.rfSolo = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    MakeCheckbox(content, lm, y, "RF when role is Tank", SP.db.rfTank, function(self)
        SP.db.rfTank = self:GetChecked() and true or false
        SP:UpdateBuffStatus()
    end)
    y = y - 22

    y = RenderSettingsGroupHeader(content, y, "Multi-Paladin")

    MakeCheckbox(content, lm, y, "Show other paladins", SP.db.showOtherPaladins, function(self)
        SP.db.showOtherPaladins = self:GetChecked() and true or false
        SP:UpdateEditPanel()
    end)
    y = y - 22

    MakeCheckbox(content, lm, y, "Allow non-leaders to assign", SP.db.allowNonLeaderAssign, function(self)
        SP.db.allowNonLeaderAssign = self:GetChecked() and true or false
    end, "Allow non-leader paladins to assign your buffs. Leaders can always assign.")
    y = y - 22

    MakeCheckbox(content, lm, y, "Edit other paladins' buffs", SP.db.editOtherPaladins, function(self)
        SP.db.editOtherPaladins = self:GetChecked() and true or false
        SP:UpdateAuraPanel()
    end, "Requires leader or other paladin to have freeuse set in PallyPower.")
    y = y - 28

    local noteFS = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteFS:SetPoint("TOPLEFT", content, "TOPLEFT", lm, y)
    noteFS:SetWidth(256)
    noteFS:SetJustifyH("LEFT")
    noteFS:SetText("Buff button loads all missing buffs when you enter combat. If a buff drops mid-fight, the indicator updates but the button can't change until combat ends (WoW restriction).")
    y = y - noteFS:GetStringHeight() - 8

    self.settingsPanel:SetHeight(28 + math.abs(y) + 6)
end

-- ═══════════════════════════════════════════
-- Always-On Display
-- ═══════════════════════════════════════════

local DISPLAY_COLORS = {
    good     = { 0, 0.55, 0, 0.7 },
    expiring = { 0.75, 0.75, 0, 0.7 },
    missing  = { 0.55, 0, 0, 0.7 },
    none     = { 0.15, 0.15, 0.15, 0.5 },
}

function SP:CreateDisplayFrame()
    local frame = CreateFrame("Frame", "ShiftPallyDisplayFrame", self.mainBar)
    frame:SetPoint("TOP", self.mainBar, "BOTTOM", 0, -2)
    frame:SetSize(156, 10)
    frame:EnableMouse(false)
    frame:Hide()

    self.displayFrame = frame
    self.displayRows = {}
end

function SP:GetOrCreateDisplayRow(index)
    if self.displayRows[index] then return self.displayRows[index] end

    local row = CreateFrame("Frame", nil, self.displayFrame, "BackdropTemplate")
    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 6,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    row:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.8)
    row:EnableMouse(true)

    local castBtn = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
    castBtn:SetAllPoints()
    castBtn:RegisterForClicks("LeftButtonDown")
    castBtn:SetFrameLevel(row:GetFrameLevel() + 1)
    castBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.castBtn = castBtn

    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.classIcon = classIcon

    local blessingIcon = row:CreateTexture(nil, "ARTWORK")
    blessingIcon:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.blessingIcon = blessingIcon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", classIcon, "RIGHT", 3, 0)
    nameText:SetPoint("RIGHT", blessingIcon, "LEFT", -3, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    self.displayRows[index] = row
    return row
end

function SP:GetMemberBuffStatus(member)
    local p = self.buffPlan and self.buffPlan[member.name]
    if not p then return "none" end
    return p.status
end

function SP:UpdateDisplay()
    if not self.displayFrame then return end

    for _, row in pairs(self.displayRows) do
        row:Hide()
        if not InCombatLockdown() and row.castBtn then
            row.castBtn:SetAttribute("type", nil)
        end
    end

    if not self.db.classViewUI and not self.db.individualViewUI then
        self.displayFrame:Hide()
        return
    end

    local rowCount = 0

    if self.db.classViewUI then
        rowCount = self:RenderClassDisplay()
    elseif self.db.individualViewUI then
        rowCount = self:RenderIndividualDisplay()
    end

    if rowCount > 0 then
        local n = #self.partyMembers
        local rowH = self.db.classViewUI and 26
            or (n > 10 and math.max(18, 28 - math.floor(n / 5)) or 28)
        self.displayFrame:SetHeight(rowCount * rowH + 4)
        self.displayFrame:Show()
    else
        self.displayFrame:Hide()
    end
end

function SP:RenderClassDisplay()
    self.displayFrame:SetWidth(176)
    local rowH = 26
    local iconSz = 20
    local rowIndex = 0

    for _, class in ipairs(self.CLASS_ORDER) do
        local members = self.partyClasses[class]
        if members and #members > 0 then
            rowIndex = rowIndex + 1
            local row = self:GetOrCreateDisplayRow(rowIndex)
            row:SetSize(176, rowH)
            row:SetPoint("TOPLEFT", self.displayFrame, "TOPLEFT", 0, -((rowIndex - 1) * rowH + 2))

            local blessingKey = self.charDB.classAssignments[class]
            local numGood, numTotal = 0, #members
            local hasMissing, hasExpiring = false, false
            local hasAnyAssignment = blessingKey ~= nil
            for _, m in ipairs(members) do
                if not hasAnyAssignment and self:GetPlannedBlessingKey(m) then
                    hasAnyAssignment = true
                end
                local s = self:GetMemberBuffStatus(m)
                if s == "missing" then hasMissing = true
                elseif s == "expiring" then hasExpiring = true
                else numGood = numGood + 1 end
            end

            local status
            if not hasAnyAssignment then status = "none"
            elseif hasMissing then status = "missing"
            elseif hasExpiring then status = "expiring"
            else status = "good" end

            local c = DISPLAY_COLORS[status]
            row:SetBackdropColor(c[1], c[2], c[3], c[4])

            row.classIcon:SetSize(iconSz, iconSz)
            row.classIcon:SetTexture(CLASS_ATLAS)
            local coords = CLASS_ICON_TCOORDS[class]
            if coords then row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
            row.classIcon:Show()

            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            row.nameText:SetText(SP.CLASS_NAMES[class] or class)
            if cc then row.nameText:SetTextColor(cc.r, cc.g, cc.b)
            else row.nameText:SetTextColor(0.8, 0.8, 0.8) end
            row.nameText:Show()

            if blessingKey then
                row.blessingIcon:SetSize(iconSz, iconSz)
                row.blessingIcon:SetTexture(SP:GetBlessingIcon(blessingKey))
                row.blessingIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.blessingIcon:Show()
            else
                row.blessingIcon:Hide()
            end

            if not InCombatLockdown() then
                local function findNeedyMember(targetStatus)
                    for _, m in ipairs(members) do
                        local p = SP.buffPlan and SP.buffPlan[m.name]
                        if p and p.status == targetStatus then
                            if m.unit == "player" then return m end
                            if not (UnitIsVisible and not UnitIsVisible(m.unit)) then
                                if not IsSpellInRange or not p.spell or IsSpellInRange(p.spell, m.unit) ~= 0 then
                                    return m
                                end
                            end
                        end
                    end
                    for _, m in ipairs(members) do
                        local p = SP.buffPlan and SP.buffPlan[m.name]
                        if p and p.status == targetStatus then return m end
                    end
                    return nil
                end

                local target = findNeedyMember("missing")
                    or findNeedyMember("expiring")
                if not target then
                    for _, m in ipairs(members) do
                        local p = SP.buffPlan and SP.buffPlan[m.name]
                        if p and p.spell then target = m; break end
                    end
                end

                if target then
                    local p = SP.buffPlan and SP.buffPlan[target.name]
                    if p and p.spell then
                        row.castBtn:SetAttribute("type", "spell")
                        row.castBtn:SetAttribute("spell", p.spell)
                        row.castBtn:SetAttribute("unit", target.unit)
                    else
                        row.castBtn:SetAttribute("type", nil)
                    end
                else
                    row.castBtn:SetAttribute("type", nil)
                end
            end

            local bName = blessingKey and SP:GetBlessingDisplayName(blessingKey) or "None"
            local cName = SP.CLASS_NAMES[class] or class
            local nG, nT = numGood, numTotal
            local tipMembers = members
            local tipTarget = row.castBtn:GetAttribute("unit")
            local tipTargetName = tipTarget and (UnitName(tipTarget) or tipTarget)
            row.castBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if cc then GameTooltip:AddLine(cName, cc.r, cc.g, cc.b)
                else GameTooltip:AddLine(cName, 1, 1, 1) end
                GameTooltip:AddLine("Assigned: " .. bName, 0.8, 0.8, 0.8)
                if tipTargetName then
                    GameTooltip:AddLine("Target: " .. tipTargetName, 0.5, 0.5, 0.5)
                end
                local minTime = nil
                for _, m in ipairs(tipMembers) do
                    local mKey = SP:GetPlannedBlessingKey(m)
                    if mKey then
                        local t = SP:GetBlessingTimeLeft(m.unit, mKey)
                        if t and (not minTime or t < minTime) then minTime = t end
                    end
                end
                if minTime then
                    local mins = math.floor(minTime / 60)
                    local secs = math.floor(minTime % 60)
                    GameTooltip:AddDoubleLine(nG .. "/" .. nT .. " buffed", string.format("%d:%02d remaining", mins, secs), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine(nG .. "/" .. nT .. " buffed", 0.6, 0.6, 0.6)
                end
                local oorCount = 0
                for _, m in ipairs(tipMembers) do
                    if m.unit ~= "player" then
                        local isOOR = UnitIsVisible and not UnitIsVisible(m.unit)
                        if not isOOR and IsSpellInRange then
                            local mp = SP.buffPlan and SP.buffPlan[m.name]
                            if mp and mp.spell then
                                if IsSpellInRange(mp.spell, m.unit) == 0 then
                                    isOOR = true
                                end
                            end
                        end
                        if isOOR then oorCount = oorCount + 1 end
                    end
                end
                if oorCount > 0 then
                    GameTooltip:AddLine(oorCount .. " out of range", 0.9, 0.2, 0.2)
                end
                if InCombatLockdown() then
                    for _, m in ipairs(tipMembers) do
                        local s = SP:GetMemberBuffStatus(m)
                        if s == "missing" or s == "expiring" then
                            GameTooltip:AddLine("Updates after combat", 0.5, 0.5, 0.5)
                            break
                        end
                    end
                end
                GameTooltip:Show()
            end)

            row:Show()
        end
    end

    return rowIndex
end

function SP:RenderIndividualDisplay()
    local numMembers = #self.partyMembers
    local compact = numMembers > 10
    local rowH, iconSz, numCols, colW
    if compact then
        rowH = math.max(18, 28 - math.floor(numMembers / 5))
        iconSz = rowH >= 24 and 18 or rowH >= 20 and 16 or 14
        numCols = 3
        colW = 80
    else
        rowH = 28
        iconSz = 22
        numCols = 1
        colW = 176
    end

    self.displayFrame:SetWidth(numCols * colW)

    local cellIndex = 0

    for i, member in ipairs(self.partyMembers) do
        cellIndex = cellIndex + 1
        local row = self:GetOrCreateDisplayRow(cellIndex)

        local col = (i - 1) % numCols
        local visualRow = math.floor((i - 1) / numCols)
        row:SetSize(colW, rowH)
        row:SetPoint("TOPLEFT", self.displayFrame, "TOPLEFT", col * colW, -(visualRow * rowH + 2))

        local key = self:GetPlannedBlessingKey(member)
        local blessingStatus = self:GetMemberBuffStatus(member)
        local isPlayer = (member.unit == "player")

        local rfNeeded, rfStatus, auraNeeded, auraName
        if isPlayer then
            if SP:ShouldUseRighteousFury() then
                rfNeeded = true
                if not SP:HasRighteousFury() then
                    rfStatus = "missing"
                else
                    local rfTime = SP:GetRFTimeLeft()
                    local threshold = SP.db.earlyGreaterWarning and 900 or 120
                    rfStatus = (rfTime and rfTime <= threshold) and "expiring" or "good"
                end
            end
            if not SP.db.ignoreAura and SP.charDB.selectedAura then
                auraNeeded = true
                auraName = SP.charDB.selectedAura
            end
        end

        local status = blessingStatus
        if isPlayer then
            if blessingStatus == "missing" or (rfNeeded and rfStatus == "missing")
                or (auraNeeded and SP:GetActiveAura() ~= auraName) then
                status = "missing"
            elseif blessingStatus == "expiring" or (rfNeeded and rfStatus == "expiring") then
                status = "expiring"
            end
        end

        local c = DISPLAY_COLORS[status]
        row:SetBackdropColor(c[1], c[2], c[3], c[4])

        row.classIcon:SetSize(iconSz, iconSz)
        if member.isPet then
            row.classIcon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTraining")
            row.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            row.classIcon:SetTexture(CLASS_ATLAS)
            local coords = CLASS_ICON_TCOORDS[member.class]
            if coords then row.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
        end
        row.classIcon:Show()

        local displayName = compact and member.name:sub(1, 5) or member.name
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
        row.nameText:SetText(displayName)
        if cc then row.nameText:SetTextColor(cc.r, cc.g, cc.b)
        else row.nameText:SetTextColor(0.8, 0.8, 0.8) end
        row.nameText:Show()

        local p = SP.buffPlan and SP.buffPlan[member.name]

        if key then
            local icon = (p and p.isGreater) and SP:GetGreaterBlessingIcon(key) or SP:GetBlessingIcon(key)
            row.blessingIcon:SetSize(iconSz, iconSz)
            row.blessingIcon:SetTexture(icon)
            row.blessingIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.blessingIcon:Show()
        else
            row.blessingIcon:Hide()
        end

        if not InCombatLockdown() then
            local castSpell, castUnit = nil, nil
            local memberSpell = p and p.spell
            if isPlayer then
                if key and blessingStatus == "missing" then
                    castSpell = memberSpell
                    castUnit = "player"
                elseif rfNeeded and rfStatus == "missing" then
                    castSpell = "Righteous Fury"
                    castUnit = "player"
                elseif auraNeeded and SP:GetActiveAura() ~= auraName then
                    castSpell = auraName
                    castUnit = "player"
                elseif key and blessingStatus == "expiring" then
                    castSpell = memberSpell
                    castUnit = "player"
                elseif rfNeeded and rfStatus == "expiring" then
                    castSpell = "Righteous Fury"
                    castUnit = "player"
                elseif key then
                    castSpell = memberSpell
                    castUnit = "player"
                end
            elseif key then
                castSpell = memberSpell
                castUnit = member.unit
            end
            if castSpell then
                row.castBtn:SetAttribute("type", "spell")
                row.castBtn:SetAttribute("spell", castSpell)
                row.castBtn:SetAttribute("unit", castUnit)
            else
                row.castBtn:SetAttribute("type", nil)
            end
        end

        local bName = key and SP:GetBlessingDisplayName(key) or "None"
        local mName = member.isPet and member.ownerName
            and (member.name .. " (" .. member.ownerName .. ")") or member.name
        local bSText = blessingStatus == "good" and "Active"
            or blessingStatus == "expiring" and "Expiring"
            or blessingStatus == "missing" and "Missing"
            or "No assignment"
        local tipUnit, tipKey = member.unit, key
        local tipRF, tipAura, tipAuraName = rfNeeded, auraNeeded, auraName
        row.castBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if cc then GameTooltip:AddLine(mName, cc.r, cc.g, cc.b)
            else GameTooltip:AddLine(mName, 1, 1, 1) end
            GameTooltip:AddLine(bName, 0.8, 0.8, 0.8)
            local timeLeft = tipKey and SP:GetBlessingTimeLeft(tipUnit, tipKey)
            if timeLeft then
                local mins = math.floor(timeLeft / 60)
                local secs = math.floor(timeLeft % 60)
                GameTooltip:AddDoubleLine(bSText, string.format("%d:%02d remaining", mins, secs), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine(bSText, 0.6, 0.6, 0.6)
            end
            if tipUnit ~= "player" then
                if UnitIsVisible and not UnitIsVisible(tipUnit) then
                    GameTooltip:AddLine("Out of range", 0.9, 0.2, 0.2)
                elseif tipKey and IsSpellInRange then
                    local b = SP:GetBlessingByKey(tipKey)
                    local spell = b and (b.greater or b.name)
                    if spell and IsSpellInRange(spell, tipUnit) == 0 then
                        GameTooltip:AddLine("Out of range", 0.9, 0.2, 0.2)
                    end
                end
            end
            if tipRF then
                local rfTime = SP:GetRFTimeLeft()
                if rfTime then
                    local mins = math.floor(rfTime / 60)
                    local secs = math.floor(rfTime % 60)
                    GameTooltip:AddDoubleLine("RF: Active", string.format("%d:%02d remaining", mins, secs), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
                elseif SP:HasRighteousFury() then
                    GameTooltip:AddLine("RF: Active", 0.6, 0.6, 0.6)
                else
                    GameTooltip:AddLine("RF: Missing", 0.9, 0.2, 0.2)
                end
            end
            if tipAura then
                local active = SP:GetActiveAura()
                if active == tipAuraName then
                    GameTooltip:AddLine("Aura: " .. tipAuraName, 0.6, 0.6, 0.6)
                elseif active then
                    GameTooltip:AddLine("Aura: " .. active .. " (need " .. tipAuraName .. ")", 0.9, 0.2, 0.2)
                else
                    GameTooltip:AddLine("Aura: Missing (" .. tipAuraName .. ")", 0.9, 0.2, 0.2)
                end
            end
            if InCombatLockdown() then
                local stale = false
                if tipKey then
                    local tipP = SP.buffPlan and SP.buffPlan[UnitName(tipUnit) or ""]
                    if tipP and (tipP.status == "missing" or tipP.status == "expiring") then
                        stale = true
                    end
                end
                if not stale and tipRF then
                    if not SP:HasRighteousFury() then
                        stale = true
                    else
                        local t = SP:GetRFTimeLeft()
                        local threshold = SP.db.earlyGreaterWarning and 900 or 120
                        if t and t <= threshold then stale = true end
                    end
                end
                if not stale and tipAura and SP:GetActiveAura() ~= tipAuraName then
                    stale = true
                end
                if stale then
                    GameTooltip:AddLine("Updates after combat", 0.5, 0.5, 0.5)
                end
            end
            GameTooltip:Show()
        end)

        row:Show()
    end

    return math.ceil(numMembers / numCols)
end
