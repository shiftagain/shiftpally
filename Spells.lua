ShiftPally = ShiftPally or {}
local SP = ShiftPally

SP.BLESSINGS = {
    { key = "might",     name = "Blessing of Might",     greater = "Greater Blessing of Might" },
    { key = "wisdom",    name = "Blessing of Wisdom",    greater = "Greater Blessing of Wisdom" },
    { key = "kings",     name = "Blessing of Kings",     greater = "Greater Blessing of Kings" },
    { key = "salvation", name = "Blessing of Salvation",  greater = "Greater Blessing of Salvation" },
    { key = "light",     name = "Blessing of Light",     greater = "Greater Blessing of Light" },
    { key = "sanctuary", name = "Blessing of Sanctuary", greater = "Greater Blessing of Sanctuary" },
}

SP.BLESSING_ICONS = {
    might     = "Interface\\Icons\\Spell_Holy_FistOfJustice",
    wisdom    = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    kings     = "Interface\\Icons\\Spell_Magic_MageArmor",
    salvation = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    light     = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
    sanctuary = "Interface\\Icons\\Spell_Nature_LightningShield",
}

SP.AURAS = {
    "Devotion Aura",
    "Retribution Aura",
    "Concentration Aura",
    "Shadow Resistance Aura",
    "Fire Resistance Aura",
    "Frost Resistance Aura",
    "Sanctity Aura",
    "Crusader Aura",
}

SP.AURA_SPELL_IDS = {
    ["Devotion Aura"]          = 465,
    ["Retribution Aura"]       = 7294,
    ["Concentration Aura"]     = 19746,
    ["Shadow Resistance Aura"] = 19876,
    ["Fire Resistance Aura"]   = 19891,
    ["Frost Resistance Aura"]  = 19888,
    ["Sanctity Aura"]          = 20218,
    ["Crusader Aura"]          = 32223,
}

SP.CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

SP.CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
    ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
    PET = "Pet",
}

local BLESSING_TALENT_MAP = {
    wisdom    = { tab = 1, name = "Improved Blessing of Wisdom" },
    might     = { tab = 3, name = "Improved Blessing of Might" },
    sanctuary = { tab = 2, name = "Improved Blessing of Sanctuary" },
}

local AURA_TALENT_MAP = {
    ["Devotion Aura"]       = { tab = 2, name = "Improved Devotion Aura" },
    ["Concentration Aura"]  = { tab = 1, name = "Improved Concentration Aura" },
    ["Sanctity Aura"]       = { tab = 3, name = "Improved Sanctity Aura" },
}

local function ScanTalentPoints(tabIndex, talentName)
    if not GetTalentInfo then return 0 end
    for i = 1, GetNumTalents(tabIndex) or 0 do
        local name, _, _, _, rank = GetTalentInfo(tabIndex, i)
        if name == talentName then return rank or 0 end
    end
    return 0
end

function SP:ScanSpellbook()
    self.knownBlessings = {}
    self.knownGreater = {}
    self.knownAuras = {}
    self.knownRF = false
    self.spellRanks = {}
    self.talentPoints = {}

    local bookType = BOOKTYPE_SPELL or "spell"
    local getName = GetSpellBookItemName or GetSpellName
    local i = 1
    while true do
        local spellName = getName(i, bookType)
        if not spellName then break end

        local rankNum
        if GetSpellName then
            local _, rankText = GetSpellName(i, bookType)
            if rankText then rankNum = tonumber(rankText:match("(%d+)")) end
        end

        for _, b in ipairs(self.BLESSINGS) do
            if spellName == b.name then
                self.knownBlessings[b.key] = true
                if rankNum then
                    self.spellRanks[b.key] = math.max(self.spellRanks[b.key] or 0, rankNum)
                elseif not self.spellRanks[b.key] then
                    self.spellRanks[b.key] = 1
                end
            end
            if spellName == b.greater then self.knownGreater[b.key] = true end
        end
        for _, a in ipairs(self.AURAS) do
            if spellName == a then
                self.knownAuras[a] = true
                if rankNum then
                    self.spellRanks[a] = math.max(self.spellRanks[a] or 0, rankNum)
                elseif not self.spellRanks[a] then
                    self.spellRanks[a] = 1
                end
            end
        end
        if spellName == "Righteous Fury" then self.knownRF = true end

        i = i + 1
    end

    for key, info in pairs(BLESSING_TALENT_MAP) do
        if self.knownBlessings[key] then
            self.talentPoints[key] = ScanTalentPoints(info.tab, info.name)
        end
    end
    for auraName, info in pairs(AURA_TALENT_MAP) do
        if self.knownAuras[auraName] then
            self.talentPoints[auraName] = ScanTalentPoints(info.tab, info.name)
        end
    end
end

function SP:GetKnownBlessings()
    local out = {}
    for _, b in ipairs(self.BLESSINGS) do
        if self.knownBlessings and self.knownBlessings[b.key] then
            table.insert(out, b)
        end
    end
    return out
end

function SP:GetKnownAuras()
    local out = {}
    for _, a in ipairs(self.AURAS) do
        if self.knownAuras and self.knownAuras[a] then
            table.insert(out, a)
        end
    end
    return out
end

function SP:GetBlessingByKey(key)
    if not key then return nil end
    for _, b in ipairs(self.BLESSINGS) do
        if b.key == key then return b end
    end
    return nil
end

function SP:GetBlessingDisplayName(key)
    if not key then return "None" end
    local b = self:GetBlessingByKey(key)
    if b then return b.name:gsub("Blessing of ", "") end
    return "None"
end

function SP:GetBlessingIcon(key)
    if not key then return nil end
    local b = self:GetBlessingByKey(key)
    if not b then return nil end
    local _, _, icon = GetSpellInfo(b.name)
    return icon or self.BLESSING_ICONS[key]
end

function SP:GetGreaterBlessingIcon(key)
    if not key then return nil end
    local b = self:GetBlessingByKey(key)
    if not b then return nil end
    local _, _, icon = GetSpellInfo(b.greater)
    return icon or self.BLESSING_ICONS[key]
end

function SP:UnitHasBlessing(unit, blessingKey)
    local b = self:GetBlessingByKey(blessingKey)
    if not b then return false end
    local i = 1
    while true do
        local name = UnitBuff(unit, i)
        if not name then return false end
        if name == b.name or name == b.greater then return true end
        i = i + 1
    end
end

function SP:UnitHasGreaterBlessing(unit, blessingKey)
    local b = self:GetBlessingByKey(blessingKey)
    if not b then return false end
    local i = 1
    while true do
        local name = UnitBuff(unit, i)
        if not name then return false end
        if name == b.greater then return true end
        i = i + 1
    end
end

function SP:GetGreaterBlessingTimeLeft(unit, blessingKey)
    local b = self:GetBlessingByKey(blessingKey)
    if not b then return nil end
    local i = 1
    while true do
        local name, _, _, _, duration, expirationTime = UnitBuff(unit, i)
        if not name then return nil end
        if name == b.greater then
            if duration and duration > 0 and expirationTime then
                return expirationTime - GetTime()
            end
            return nil
        end
        i = i + 1
    end
end

function SP:GetBlessingTimeLeft(unit, blessingKey)
    local b = self:GetBlessingByKey(blessingKey)
    if not b then return nil end
    local i = 1
    while true do
        local name, _, _, _, duration, expirationTime = UnitBuff(unit, i)
        if not name then return nil end
        if name == b.name or name == b.greater then
            if duration and duration > 0 and expirationTime then
                return expirationTime - GetTime()
            end
            return nil
        end
        i = i + 1
    end
end

function SP:GetBlessingCaster(unit, blessingKey)
    local b = self:GetBlessingByKey(blessingKey)
    if not b then return nil, nil end
    local i = 1
    while true do
        local name, _, _, _, _, _, _, caster = UnitBuff(unit, i)
        if not name then return nil, nil end
        if name == b.name or name == b.greater then return caster, name end
        i = i + 1
    end
end

function SP:GetAvailableBlessingsForPaladin(paladinName)
    local myName = UnitName("player")
    if not paladinName or paladinName == myName then
        return self:GetKnownBlessings()
    end

    local pd = self.ppState and self.ppState.Paladins[paladinName]
    if not pd or not pd.spells then
        return self.BLESSINGS
    end

    local out = {}
    for blessingID = 1, 6 do
        if pd.spells[blessingID] then
            local key = self.PP.BLESSING_TO_KEY[blessingID]
            if key then
                local b = self:GetBlessingByKey(key)
                if b then
                    table.insert(out, b)
                end
            end
        end
    end
    return out
end

function SP:GetAuraIcon(auraName)
    if not auraName then return nil end
    local _, _, icon = GetSpellInfo(auraName)
    if icon then return icon end
    local spellID = self.AURA_SPELL_IDS[auraName]
    if spellID then
        _, _, icon = GetSpellInfo(spellID)
    end
    return icon
end

function SP:GetAvailableAurasForPaladin(paladinName)
    local myName = UnitName("player")
    if not paladinName or paladinName == myName then
        return self:GetKnownAuras()
    end

    local pd = self.ppState and self.ppState.Paladins[paladinName]
    if not pd or not pd.auras then
        return self.AURAS
    end

    local out = {}
    for auraID = 1, self.PP.MAXAURAS do
        if pd.auras[auraID] then
            local name = self.PP.AURA_ID_TO_NAME[auraID]
            if name then
                table.insert(out, name)
            end
        end
    end
    return out
end

function SP:GetActiveAura()
    local i = 1
    while true do
        local name = UnitBuff("player", i)
        if not name then return nil end
        for _, a in ipairs(self.AURAS) do
            if name == a then return a end
        end
        i = i + 1
    end
end
