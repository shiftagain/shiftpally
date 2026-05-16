local SP = ShiftPally

SP.useFakeData = false

local eventFrame = CreateFrame("Frame")
SP.eventFrame = eventFrame
SP.partyMembers = {}
SP.partyClasses = {}
SP.myActiveBlessings = {}
SP.allBuffsActive = true
SP.nextBuffSpell = nil
SP.nextBuffUnit = nil

local function IsInRaidGroup()
    if IsInRaid then return IsInRaid() end
    if GetNumRaidMembers then return GetNumRaidMembers() > 0 end
    return false
end

local function GetPartyCount()
    if IsInRaidGroup() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or (GetNumRaidMembers and GetNumRaidMembers() or 0)
        return n > 0 and (n - 1) or 0
    end
    if GetNumPartyMembers then return GetNumPartyMembers() end
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    return n > 0 and (n - 1) or 0
end

function SP:Init()
    if not ShiftPallyDB then ShiftPallyDB = {} end
    self.db = ShiftPallyDB
    if not ShiftPallyCharDB then ShiftPallyCharDB = {} end
    self.charDB = ShiftPallyCharDB
    if not self.charDB.classAssignments and ShiftPallyDB.classAssignments then
        self.charDB.classAssignments = ShiftPallyDB.classAssignments
        self.charDB.playerBlessings = ShiftPallyDB.playerBlessings
        self.charDB.selectedAura = ShiftPallyDB.selectedAura
    end
    self.charDB.classAssignments = self.charDB.classAssignments or {}
    self.charDB.playerBlessings = self.charDB.playerBlessings or {}
    self.charDB.selectedAura = self.charDB.selectedAura
    self.db.mainBarPos = self.db.mainBarPos
    if self.db.rfSolo == nil then self.db.rfSolo = true end
    if self.db.rfTank == nil then self.db.rfTank = true end
    if self.db.ignoreAura == nil then self.db.ignoreAura = false end
    if self.db.ignoreBlessingSolo ~= nil then
        self.db.ignoreBlessings = self.db.ignoreBlessingSolo
        self.db.ignoreBlessingSolo = nil
    end
    if self.db.ignoreBlessings == nil then self.db.ignoreBlessings = false end
    if self.db.useBaseBlessings == nil then self.db.useBaseBlessings = false end
    if self.db.showOtherPaladins == nil then self.db.showOtherPaladins = true end
    if self.db.allowNonLeaderAssign == nil then self.db.allowNonLeaderAssign = true end
    if self.db.editOtherPaladins == nil then self.db.editOtherPaladins = true end
    if self.db.earlyGreaterWarning == nil then self.db.earlyGreaterWarning = false end
    if self.db.showPets == nil then self.db.showPets = true end
    if self.db.individualViewUI == nil then self.db.individualViewUI = false end
    if self.db.classViewUI == nil then self.db.classViewUI = false end

    self:ScanSpellbook()
    self:InitPP()
    self:CreateMainBar()
    self:CreateCastButton()
    self:CreateEditPanel()
    self:CreateDisplayFrame()
    self:ScanParty()
    if self.useFakeData then self:LoadFakeData() end
    self:UpdateBuffStatus()

    print("|cFF00FF00ShiftPally|r loaded. /sp to toggle.")
end

function SP:ScanParty()
    if self.useFakeData then return end
    self.partyMembers = {}
    self.partyClasses = {}

    if IsInRaidGroup() then
        local numRaid = GetNumGroupMembers and GetNumGroupMembers() or (GetNumRaidMembers and GetNumRaidMembers() or 0)
        for i = 1, numRaid do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local name = UnitName(unit)
                local _, class = UnitClass(unit)
                if name and class then
                    local m = { name = name, unit = unit, class = class }
                    table.insert(self.partyMembers, m)
                    self.partyClasses[class] = self.partyClasses[class] or {}
                    table.insert(self.partyClasses[class], m)
                end
            end
        end
    else
        local numParty = GetPartyCount()
        for i = 1, numParty do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                local _, class = UnitClass(unit)
                if name and class then
                    local m = { name = name, unit = unit, class = class }
                    table.insert(self.partyMembers, m)
                    self.partyClasses[class] = self.partyClasses[class] or {}
                    table.insert(self.partyClasses[class], m)
                end
            end
        end
    end

    local name = UnitName("player")
    local _, class = UnitClass("player")
    if name and class then
        local m = { name = name, unit = "player", class = class }
        table.insert(self.partyMembers, 1, m)
        self.partyClasses[class] = self.partyClasses[class] or {}
        table.insert(self.partyClasses[class], m)
    end

    if self.db.showPets then
        if IsInRaidGroup() then
            local numRaid = GetNumGroupMembers and GetNumGroupMembers() or (GetNumRaidMembers and GetNumRaidMembers() or 0)
            -- Single-target blessings can only be cast on pets in the player's subgroup
            local playerSubgroup = nil
            for i = 1, numRaid do
                if UnitIsUnit("raid" .. i, "player") then
                    local _, _, subgroup = GetRaidRosterInfo(i)
                    playerSubgroup = subgroup
                    break
                end
            end
            for i = 1, numRaid do
                local petUnit = "raidpet" .. i
                if UnitExists(petUnit) then
                    local _, _, ownerSubgroup = GetRaidRosterInfo(i)
                    if ownerSubgroup == playerSubgroup then
                        local petName = UnitName(petUnit)
                        if petName then
                            local ownerUnit = "raid" .. i
                            local _, ownerClass = UnitClass(ownerUnit)
                            table.insert(self.partyMembers, {
                                name = petName, unit = petUnit, class = "PET",
                                isPet = true, ownerName = UnitName(ownerUnit), ownerClass = ownerClass,
                            })
                        end
                    end
                end
            end
        else
            for i = 1, 4 do
                local petUnit = "partypet" .. i
                if UnitExists(petUnit) then
                    local petName = UnitName(petUnit)
                    if petName then
                        local ownerUnit = "party" .. i
                        local _, ownerClass = UnitClass(ownerUnit)
                        table.insert(self.partyMembers, {
                            name = petName, unit = petUnit, class = "PET",
                            isPet = true, ownerName = UnitName(ownerUnit), ownerClass = ownerClass,
                        })
                    end
                end
            end
        end
        if UnitExists("pet") then
            local petName = UnitName("pet")
            if petName then
                local _, playerClass = UnitClass("player")
                table.insert(self.partyMembers, {
                    name = petName, unit = "pet", class = "PET",
                    isPet = true, ownerName = UnitName("player"), ownerClass = playerClass,
                })
            end
        end
    end

    for _, member in ipairs(self.partyMembers) do
        if member.isPet and not self.charDB.playerBlessings[member.name] then
            self.charDB.playerBlessings[member.name] = self:GetPetDefaultBlessing(member)
        end
    end

    self:InitTracking()
    if self.editPanel and self.editPanel:IsShown() and not self:PPSyncInProgress() then
        self:UpdateEditPanel()
    end
end

function SP:InitTracking()
    self.myActiveBlessings = {}
    for _, member in ipairs(self.partyMembers) do
        for _, blessing in ipairs(self.BLESSINGS) do
            local caster = self:GetBlessingCaster(member.unit, blessing.key)
            if caster == "player" then
                self.myActiveBlessings[member.name .. ":" .. blessing.key] = true
            end
        end
    end
end

function SP:GetPlannedBlessingKey(member)
    local key = self.charDB.playerBlessings[member.name]
    if key then return key end
    return self.charDB.classAssignments[member.class]
end

function SP:HasRighteousFury()
    local i = 1
    while true do
        local name = UnitBuff("player", i)
        if not name then return false end
        if name == "Righteous Fury" then return true end
        i = i + 1
    end
end

function SP:GetRFTimeLeft()
    local i = 1
    while true do
        local name, _, _, _, duration, expirationTime = UnitBuff("player", i)
        if not name then return nil end
        if name == "Righteous Fury" then
            if duration and duration > 0 and expirationTime then
                return expirationTime - GetTime()
            end
            return nil
        end
        i = i + 1
    end
end

function SP:UnitHasPhaseShift(unit)
    local i = 1
    while true do
        local name = UnitBuff(unit, i)
        if not name then return false end
        if name == "Phase Shift" then return true end
        i = i + 1
    end
end

function SP:ShouldUseRighteousFury()
    if not self.knownRF then return false end
    local numParty = GetPartyCount()
    if numParty == 0 and self.db.rfSolo then
        return true
    end
    if numParty > 0 and self.db.rfTank then
        if UnitGroupRolesAssigned then
            local role = UnitGroupRolesAssigned("player")
            if role == "TANK" then return true end
        end
    end
    return false
end

function SP:UpdateBuffStatus()
    self.allBuffsActive = true
    self.buffsExpiringSoon = false

    self:ComputeBuffPlan()

    local skipBlessings = self.db.ignoreBlessings
    local allMissing = self:GetAllMissingBuffs()

    if #allMissing > 0 then
        local anyTrulyMissing = false
        if not skipBlessings then
            for _, p in pairs(self.buffPlan) do
                if p.status == "missing" then
                    anyTrulyMissing = true
                    break
                end
            end
        end
        if not anyTrulyMissing and not self.db.ignoreAura and self.charDB.selectedAura then
            if self:GetActiveAura() ~= self.charDB.selectedAura then
                anyTrulyMissing = true
            end
        end
        if not anyTrulyMissing and self:ShouldUseRighteousFury() and not self:HasRighteousFury() then
            anyTrulyMissing = true
        end

        if anyTrulyMissing then
            self.allBuffsActive = false
        else
            self.buffsExpiringSoon = true
        end
    end

    self:UpdateIndicator()
    self:UpdateCastButton(allMissing)
    self:UpdateDisplay()
    if self.outOfRangeCount and self.outOfRangeCount > 0 then
        self:StartRangeChecker()
    else
        self:StopRangeChecker()
    end

    self.expiryTimerGen = (self.expiryTimerGen or 0) + 1
    local expiryDelay = self.nextExpiryTime
    if self:ShouldUseRighteousFury() and self:HasRighteousFury() then
        local rfTime = self:GetRFTimeLeft()
        if rfTime then
            local rfThreshold = self.db.earlyGreaterWarning and 900 or 120
            local rfDelta = rfTime - rfThreshold
            if rfDelta > 0 and (not expiryDelay or rfDelta < expiryDelay) then
                expiryDelay = rfDelta
            end
        end
    end
    if expiryDelay then
        local gen = self.expiryTimerGen
        C_Timer.After(expiryDelay + 0.5, function()
            if gen == SP.expiryTimerGen then
                SP:UpdateBuffStatus()
            end
        end)
    end
end

local rangeFrame = CreateFrame("Frame")
local rangeElapsed = 0

function SP:StartRangeChecker()
    if self.rangeCheckerActive then return end
    self.rangeCheckerActive = true
    rangeElapsed = 0
    rangeFrame:SetScript("OnUpdate", function(_, dt)
        rangeElapsed = rangeElapsed + dt
        if rangeElapsed >= 0.5 then
            rangeElapsed = 0
            SP:UpdateBuffStatus()
        end
    end)
end

function SP:StopRangeChecker()
    if not self.rangeCheckerActive then return end
    self.rangeCheckerActive = false
    rangeFrame:SetScript("OnUpdate", nil)
end

function SP:GetBlessingSpellName(key)
    local b = self:GetBlessingByKey(key)
    if not b then return nil end
    if not self.db.useBaseBlessings and self.knownGreater and self.knownGreater[key] then
        return b.greater
    end
    return b.name
end

function SP:ComputeBuffPlan()
    local plan = {}
    local numParty = GetPartyCount()

    local classPrimaryKey = {}

    for _, class in ipairs(self.CLASS_ORDER) do
        local members = self.partyClasses[class]
        if members then
            local blessingGroups = {}
            for _, m in ipairs(members) do
                local key = self:GetPlannedBlessingKey(m)
                if key then
                    blessingGroups[key] = blessingGroups[key] or {}
                    table.insert(blessingGroups[key], m)
                end
            end

            local numKeys = 0
            for _ in pairs(blessingGroups) do numKeys = numKeys + 1 end

            if not self.db.useBaseBlessings and numParty > 0 and numKeys > 0 then
                local hasConflict = numKeys > 1

                local playerKey = nil
                for key, group in pairs(blessingGroups) do
                    for _, m in ipairs(group) do
                        if m.unit == "player" then playerKey = key; break end
                    end
                    if playerKey then break end
                end

                local hasTankOutsideSalv = false
                if hasConflict and blessingGroups["salvation"] then
                    for key, group in pairs(blessingGroups) do
                        if key ~= "salvation" then
                            for _, m in ipairs(group) do
                                local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(m.unit)
                                if role == "TANK" then
                                    hasTankOutsideSalv = true
                                    break
                                end
                            end
                        end
                        if hasTankOutsideSalv then break end
                    end
                end

                local primaryKey, primaryCount = nil, 0
                for _, b in ipairs(self.BLESSINGS) do
                    local group = blessingGroups[b.key]
                    if group and #group > primaryCount then
                        if not (hasConflict and playerKey and b.key == playerKey) then
                            if not (hasTankOutsideSalv and b.key == "salvation") then
                                primaryKey = b.key
                                primaryCount = #group
                            end
                        end
                    end
                end
                if not primaryKey then
                    for _, b in ipairs(self.BLESSINGS) do
                        local group = blessingGroups[b.key]
                        if group and #group > primaryCount then
                            primaryKey = b.key
                            primaryCount = #group
                        end
                    end
                end

                if primaryKey and self.knownGreater and self.knownGreater[primaryKey] then
                    classPrimaryKey[class] = primaryKey
                end
            end
        end
    end

    for _, member in ipairs(self.partyMembers) do
        local key = self:GetPlannedBlessingKey(member)
        if not key then
            plan[member.name] = { status = "none", unit = member.unit }
        else
            local b = self:GetBlessingByKey(key)
            if not b then
                plan[member.name] = { status = "none", unit = member.unit }
            else
                local isGreater = not member.isPet and key == classPrimaryKey[member.class]
                local spell = isGreater and b.greater or b.name

                local status = "good"
                if member.isPet and self:UnitHasPhaseShift(member.unit) then
                    -- phase-shifted pets always count as good
                elseif isGreater then
                    if not self:UnitHasGreaterBlessing(member.unit, key) then
                        status = "missing"
                    else
                        local timeLeft = self:GetGreaterBlessingTimeLeft(member.unit, key)
                        local threshold = self.db.earlyGreaterWarning and 900 or 120
                        if timeLeft and timeLeft <= threshold then
                            status = "expiring"
                        end
                    end
                else
                    if not self:UnitHasBlessing(member.unit, key) then
                        status = "missing"
                    else
                        local timeLeft = self:GetBlessingTimeLeft(member.unit, key)
                        if timeLeft and timeLeft <= 120 then
                            status = "expiring"
                        end
                    end
                end

                plan[member.name] = {
                    key = key,
                    spell = spell,
                    unit = member.unit,
                    isGreater = isGreater,
                    status = status,
                }
            end
        end
    end

    local nextExpiry = nil
    for _, member in ipairs(self.partyMembers) do
        local p = plan[member.name]
        if p and p.status == "good" and p.key then
            local timeLeft
            if p.isGreater then
                timeLeft = self:GetGreaterBlessingTimeLeft(member.unit, p.key)
            else
                timeLeft = self:GetBlessingTimeLeft(member.unit, p.key)
            end
            if timeLeft then
                local threshold = (p.isGreater and self.db.earlyGreaterWarning) and 900 or 120
                local delta = timeLeft - threshold
                if delta > 0 and (not nextExpiry or delta < nextExpiry) then
                    nextExpiry = delta
                end
            end
        end
    end
    self.nextExpiryTime = nextExpiry

    self.buffPlan = plan
end

function SP:GetAllMissingBuffs()
    local missing = {}
    local plan = self.buffPlan or {}
    local skipBlessings = self.db.ignoreBlessings

    if not skipBlessings then
        local greaterQueue = {}
        local baseQueue = {}

        local greaterClassDone = {}
        for _, class in ipairs(self.CLASS_ORDER) do
            local members = self.partyClasses[class]
            if members and not greaterClassDone[class] then
                greaterClassDone[class] = true
                local needsRefresh = {}
                for _, m in ipairs(members) do
                    local p = plan[m.name]
                    if p and p.isGreater and (p.status == "missing" or p.status == "expiring") then
                        table.insert(needsRefresh, m)
                    end
                end
                if #needsRefresh > 0 then
                    local spell = plan[needsRefresh[1].name].spell
                    local target = nil
                    for _, m in ipairs(needsRefresh) do
                        if m.unit == "player" then target = m; break end
                    end
                    if not target then
                        for _, m in ipairs(needsRefresh) do
                            if not IsSpellInRange or IsSpellInRange(spell, m.unit) ~= 0 then
                                target = m; break
                            end
                        end
                    end
                    if not target then target = needsRefresh[1] end
                    table.insert(greaterQueue, { spell = spell, unit = target.unit })
                end
            end
        end

        for _, member in ipairs(self.partyMembers) do
            local p = plan[member.name]
            if p and not p.isGreater and (p.status == "missing" or p.status == "expiring") then
                table.insert(baseQueue, { spell = p.spell, unit = member.unit })
            end
        end

        for _, entry in ipairs(greaterQueue) do
            table.insert(missing, entry)
        end
        for _, entry in ipairs(baseQueue) do
            table.insert(missing, entry)
        end
    end

    if not self.db.ignoreAura and self.charDB.selectedAura and self:GetActiveAura() ~= self.charDB.selectedAura then
        table.insert(missing, { spell = self.charDB.selectedAura, unit = "player" })
    end

    if self:ShouldUseRighteousFury() then
        if not self:HasRighteousFury() then
            table.insert(missing, { spell = "Righteous Fury", unit = "player" })
        else
            local rfTimeLeft = self:GetRFTimeLeft()
            local rfThreshold = self.db.earlyGreaterWarning and 900 or 120
            if rfTimeLeft and rfTimeLeft <= rfThreshold then
                table.insert(missing, { spell = "Righteous Fury", unit = "player" })
            end
        end
    end

    local inRange = {}
    local outOfRange = {}
    local oorNameSet = {}
    local oorNames = {}
    for _, entry in ipairs(missing) do
        local isOOR = false

        if entry.unit == "player" then
            -- cast target is self, always in cast range
        elseif UnitIsVisible and not UnitIsVisible(entry.unit) then
            isOOR = true
        elseif IsSpellInRange and IsSpellInRange(entry.spell, entry.unit) == 0 then
            isOOR = true
        end

        if isOOR then
            table.insert(outOfRange, entry)
            local name = UnitName(entry.unit)
            if name and not oorNameSet[name] then
                oorNameSet[name] = true
                table.insert(oorNames, name)
            end
        else
            table.insert(inRange, entry)
        end
    end
    self.outOfRangeCount = #outOfRange
    self.outOfRangeNames = oorNames

    local sorted = {}
    for _, e in ipairs(inRange) do table.insert(sorted, e) end
    for _, e in ipairs(outOfRange) do table.insert(sorted, e) end
    return sorted
end

function SP:UpdateCastButton(allMissing)
    allMissing = allMissing or self:GetAllMissingBuffs()
    if #allMissing > 0 then
        self.nextBuffSpell = allMissing[1].spell
        self.nextBuffUnit = allMissing[1].unit
    else
        self.nextBuffSpell = nil
        self.nextBuffUnit = nil
    end

    if self.castButton then
        if not InCombatLockdown() then
            local btn = self.castButton
            local oldCount = btn:GetAttribute("sp-count") or 0
            for i = 1, oldCount do
                btn:SetAttribute("sp-" .. i .. "-spell", nil)
                btn:SetAttribute("sp-" .. i .. "-unit", nil)
            end
            local actionableCount = #allMissing - (self.outOfRangeCount or 0)
            for i = 1, actionableCount do
                btn:SetAttribute("sp-" .. i .. "-spell", allMissing[i].spell)
                btn:SetAttribute("sp-" .. i .. "-unit", allMissing[i].unit)
            end
            btn:SetAttribute("sp-count", actionableCount)
            btn:SetAttribute("sp-idx", 1)
            if actionableCount > 0 then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", allMissing[1].spell)
                btn:SetAttribute("unit", allMissing[1].unit)
            else
                btn:SetAttribute("type", nil)
            end
            self.hasActionableBuffs = actionableCount > 0
        else
            self.castButtonDirty = true
        end
    end

    if self.buffButtonText then
        if self.hasActionableBuffs then
            self.buffButtonText:SetTextColor(1, 1, 1)
        else
            self.buffButtonText:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    if self.buffOverlay and GameTooltip:IsOwned(self.buffOverlay) then
        local buttonStale = InCombatLockdown() and self.nextBuffSpell
            and self.castButton and self.castButton:GetAttribute("type") == nil
        GameTooltip:ClearLines()
        GameTooltip:AddLine("ShiftPally", 1, 1, 1)
        if buttonStale then
            GameTooltip:AddLine("Button updates after combat", 0.5, 0.5, 0.5)
        elseif self.hasActionableBuffs then
            GameTooltip:AddLine("Cast: " .. self.nextBuffSpell, 0, 1, 0)
            local castTarget = UnitName(self.nextBuffUnit or "") or self.nextBuffUnit or ""
            GameTooltip:AddLine("Target: " .. castTarget, 0.8, 0.8, 0.8)
        elseif not self.nextBuffSpell then
            GameTooltip:AddLine("All buffs active!", 0, 1, 0)
        end
        if self.outOfRangeNames and #self.outOfRangeNames > 0 then
            local n = #self.outOfRangeNames
            local names = table.concat(self.outOfRangeNames, ", ")
            GameTooltip:AddLine(n .. " out of range: " .. names, 0.9, 0.2, 0.2, true)
        end
        GameTooltip:Show()
    end
end

function SP:CheckOverridesForUnit(unit)
    local unitName = UnitName(unit)
    if not unitName then return end

    for _, blessing in ipairs(self.BLESSINGS) do
        local caster, buffName = self:GetBlessingCaster(unit, blessing.key)
        local trackKey = unitName .. ":" .. blessing.key

        if caster == "player" then
            self.myActiveBlessings[trackKey] = true
        elseif caster and self.myActiveBlessings[trackKey] then
            local casterName = UnitName(caster) or "Unknown"
            print("|cFFFF6600[ShiftPally]|r " .. casterName .. " overrode your " .. (buffName or blessing.name) .. " on " .. unitName)
            self.myActiveBlessings[trackKey] = nil
        elseif not caster then
            self.myActiveBlessings[trackKey] = nil
        end
    end
end

-- Assignment functions

function SP:CleanupStaleAssignments()
    if not self.knownBlessings or not next(self.knownBlessings) then return end
    for class, key in pairs(self.charDB.classAssignments) do
        if not self.knownBlessings[key] then
            self.charDB.classAssignments[class] = nil
        end
    end
    for name, key in pairs(self.charDB.playerBlessings) do
        if not self.knownBlessings[key] then
            self.charDB.playerBlessings[name] = nil
        end
    end
    if self.charDB.selectedAura and not (self.knownAuras and self.knownAuras[self.charDB.selectedAura]) then
        self.charDB.selectedAura = nil
    end
end

function SP:SetClassAssignment(class, blessingKey)
    if blessingKey and not (self.knownBlessings and self.knownBlessings[blessingKey]) then return end
    self.charDB.classAssignments[class] = blessingKey
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:SetPlayerBlessing(playerName, blessingKey)
    if blessingKey and not (self.knownBlessings and self.knownBlessings[blessingKey]) then return end
    self.charDB.playerBlessings[playerName] = blessingKey
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:SetAura(auraName)
    if auraName and not (self.knownAuras and self.knownAuras[auraName]) then return end
    self.charDB.selectedAura = auraName
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:ClearAll()
    self.charDB.classAssignments = {}
    self.charDB.playerBlessings = {}
    self.charDB.selectedAura = nil

    if self:PPIsInGroup() and not self.useFakeData then
        self:PPSendClearMsg(false)
        if self:PPAmILeader() then
            for _, assignments in pairs(self.ppState.Assignments) do
                for i = 1, SP.PP.MAXCLASSES do
                    assignments[i] = 0
                end
            end
            self.ppState.NormalAssignments = {}
            for pName in pairs(self.ppState.AuraAssignments) do
                self.ppState.AuraAssignments[pName] = 0
            end
        end
        self:PPSendSelf()
    end

    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:GetPetDefaultBlessing(member)
    if member.ownerClass == "HUNTER" then
        if self.knownBlessings and self.knownBlessings["might"] then return "might" end
        if self.knownBlessings and self.knownBlessings["kings"] then return "kings" end
    else
        if self.knownBlessings and self.knownBlessings["kings"] then return "kings" end
    end
    return nil
end

function SP:SalvAll()
    local playerName = UnitName("player")
    local myRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    for _, member in ipairs(self.partyMembers) do
        if member.isPet then
            self.charDB.playerBlessings[member.name] = self:GetPetDefaultBlessing(member)
        else
            local isSelf = (member.name == playerName)
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(member.unit)
            local key
            if isSelf then
                key = (myRole == "TANK") and "sanctuary" or "wisdom"
            elseif role == "TANK" then
                key = "light"
            elseif myRole == "TANK" and role == "HEALER" then
                key = "wisdom"
            else
                key = "salvation"
            end
            self.charDB.playerBlessings[member.name] = (self.knownBlessings and self.knownBlessings[key]) and key or nil
        end
    end
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:ApplyDefaults()
    local playerName = UnitName("player")
    local myRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    for _, member in ipairs(self.partyMembers) do
        if member.isPet then
            self.charDB.playerBlessings[member.name] = self:GetPetDefaultBlessing(member)
        else
            local isSelf = (member.name == playerName)
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(member.unit)
            local key
            if isSelf then
                key = (myRole == "TANK") and "sanctuary" or "wisdom"
            elseif role == "TANK" then
                key = "light"
            else
                key = self.charDB.classAssignments[member.class]
            end
            self.charDB.playerBlessings[member.name] = (self.knownBlessings and self.knownBlessings[key]) and key or nil
        end
    end
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

-- Events

local PARTY_EVENT = "PARTY_MEMBERS_CHANGED"
local spellsBucket = nil
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(function() eventFrame:RegisterEvent(PARTY_EVENT) end)
pcall(function() eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE") end)
pcall(function() eventFrame:RegisterEvent("RAID_ROSTER_UPDATE") end)
pcall(function() eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED") end)
pcall(function() eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED") end)
pcall(function() eventFrame:RegisterEvent("UNIT_PET") end)

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and arg1 == "ShiftPally" then
        SP:Init()
    elseif event == PARTY_EVENT or event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
        SP:ScanParty()
        SP:PPOnRosterUpdate()
        SP:UpdateBuffStatus()
    elseif event == "UNIT_AURA" then
        if arg1 == "player" or arg1 == "pet" or (arg1 and (arg1:match("^party%d$") or arg1:match("^raid%d+$") or arg1:match("^partypet%d$") or arg1:match("^raidpet%d+$"))) then
            SP:CheckOverridesForUnit(arg1)
            SP:UpdateBuffStatus()
        end
    elseif event == "SPELLS_CHANGED" then
        if not spellsBucket then
            spellsBucket = true
            C_Timer.After(1.0, function()
                spellsBucket = nil
                SP:ScanSpellbook()
                SP:PPOnSpellsChanged()
                SP:UpdateBuffStatus()
            end)
        end
    elseif event == "PLAYER_ROLES_ASSIGNED" then
        C_Timer.After(2.0, function()
            SP:PPUpdateLeaders()
            if SP:PPAmILeader() and SP:PPIsInGroup() and not SP.useFakeData then
                SP:PPSendSelf()
            end
        end)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellName = arg2
        if spellName == "Lay on Hands" or spellName == "Divine Intervention" then
            C_Timer.After(2.0, function()
                SP:ScanCooldowns()
                if SP:PPIsInGroup() and not SP.useFakeData then
                    SP:PPSendSelf()
                end
            end)
        end
    elseif event == "UNIT_PET" then
        if SP.db.showPets then
            SP:ScanParty()
            SP:UpdateBuffStatus()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if SP.castButtonDirty then
            SP.castButtonDirty = false
        end
        SP:UpdateCastButton()
    end
end)

-- TEMP: Fake data for UI testing. Remove when done.

function SP:LoadFakeData()
    local playerName = UnitName("player") or "Testpally"

    self.knownBlessings = {
        might = true, wisdom = true, kings = true,
        salvation = true, light = true, sanctuary = true,
    }
    self.knownGreater = {
        might = true, wisdom = true, kings = true,
        salvation = true, light = true, sanctuary = true,
    }
    self.knownAuras = {
        ["Devotion Aura"] = true,
        ["Retribution Aura"] = true,
        ["Concentration Aura"] = true,
        ["Shadow Resistance Aura"] = true,
        ["Fire Resistance Aura"] = true,
        ["Frost Resistance Aura"] = true,
        ["Sanctity Aura"] = true,
        ["Crusader Aura"] = true,
    }
    self.knownRF = true

    self.partyMembers = {}
    self.partyClasses = {}

    local fakeMembers = {
        { name = playerName,    unit = "player", class = "PALADIN" },
        { name = "Tankenstein",  unit = "party1", class = "WARRIOR" },
        { name = "Smashface",    unit = "party2", class = "WARRIOR" },
        { name = "Healsworth",   unit = "party3", class = "PRIEST" },
        { name = "Frostbite",    unit = "party4", class = "MAGE" },
        { name = "Stabsworth",   unit = "party5", class = "ROGUE" },
        { name = "Beastmode",    unit = "party6", class = "HUNTER" },
        { name = "Shadowburn",   unit = "party7", class = "WARLOCK" },
        { name = "Bearform",     unit = "party8", class = "DRUID" },
        { name = "Thunderzap",   unit = "party9", class = "SHAMAN" },
    }

    if self.db.showPets then
        table.insert(fakeMembers, {
            name = "Fluffy", unit = "partypet6", class = "PET",
            isPet = true, ownerName = "Beastmode", ownerClass = "HUNTER",
        })
        table.insert(fakeMembers, {
            name = "Jhaambi", unit = "partypet7", class = "PET",
            isPet = true, ownerName = "Shadowburn", ownerClass = "WARLOCK",
        })
    end

    for _, m in ipairs(fakeMembers) do
        table.insert(self.partyMembers, m)
        self.partyClasses[m.class] = self.partyClasses[m.class] or {}
        table.insert(self.partyClasses[m.class], m)
    end

    self.charDB.classAssignments = {
        WARRIOR = "might",
        PALADIN = "wisdom",
        PRIEST  = "salvation",
        MAGE    = "salvation",
        ROGUE   = "might",
        HUNTER  = "salvation",
        WARLOCK = "salvation",
        DRUID   = "kings",
        SHAMAN  = "wisdom",
    }

    self.charDB.playerBlessings = {
        ["Tankenstein"] = "light",
        ["Healsworth"]  = "wisdom",
        ["Frostbite"]   = "kings",
    }

    self.db.showOtherPaladins = true
    self.charDB.selectedAura = "Devotion Aura"
end

-- Slash commands

SLASH_SHIFTPALLY1 = "/sp"
SLASH_SHIFTPALLY2 = "/shiftpally"
SlashCmdList["SHIFTPALLY"] = function()
    if SP.mainBar then
        if SP.mainBar:IsShown() then
            SP.mainBar:Hide()
        else
            SP.mainBar:Show()
        end
    end
end
