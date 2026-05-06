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
    self.db.classAssignments = self.db.classAssignments or {}
    self.db.playerBlessings = self.db.playerBlessings or {}
    self.db.selectedAura = self.db.selectedAura
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
    if self.db.showPets == nil then self.db.showPets = false end

    self:ScanSpellbook()
    self:InitPP()
    self:CreateMainBar()
    self:CreateCastButton()
    self:CreateEditPanel()
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
            for i = 1, numRaid do
                local petUnit = "raidpet" .. i
                if UnitExists(petUnit) then
                    local petName = UnitName(petUnit)
                    if petName then
                        table.insert(self.partyMembers, {
                            name = petName, unit = petUnit, class = "PET",
                            isPet = true, ownerName = UnitName("raid" .. i),
                        })
                    end
                end
            end
        else
            for i = 1, 4 do
                local petUnit = "partypet" .. i
                if UnitExists(petUnit) then
                    local petName = UnitName(petUnit)
                    if petName then
                        table.insert(self.partyMembers, {
                            name = petName, unit = petUnit, class = "PET",
                            isPet = true, ownerName = UnitName("party" .. i),
                        })
                    end
                end
            end
        end
        if UnitExists("pet") then
            local petName = UnitName("pet")
            if petName then
                table.insert(self.partyMembers, {
                    name = petName, unit = "pet", class = "PET",
                    isPet = true, ownerName = UnitName("player"),
                })
            end
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
    local key = self.db.playerBlessings[member.name]
    if key then return key end
    return self.db.classAssignments[member.class]
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

    local skipBlessings = self.db.ignoreBlessings

    local allMissing = self:GetAllMissingBuffs()

    if #allMissing > 0 then
        local anyTrulyMissing = false
        if not skipBlessings then
            for _, member in ipairs(self.partyMembers) do
                local key = self:GetPlannedBlessingKey(member)
                if key and not self:UnitHasBlessing(member.unit, key) then
                    anyTrulyMissing = true
                    break
                end
            end
        end
        if not anyTrulyMissing and not self.db.ignoreAura and self.db.selectedAura then
            if self:GetActiveAura() ~= self.db.selectedAura then
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
    if self.outOfRangeCount and self.outOfRangeCount > 0 then
        self:StartRangeChecker()
    else
        self:StopRangeChecker()
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

function SP:GetAllMissingBuffs()
    local missing = {}
    local numParty = GetPartyCount()
    local skipBlessings = self.db.ignoreBlessings

    if not skipBlessings then
        local greaterQueue = {}
        local baseQueue = {}

        local function needsRefresh(unit, key, requireGreater)
            if requireGreater then
                if not self:UnitHasGreaterBlessing(unit, key) then return true end
                local timeLeft = self:GetGreaterBlessingTimeLeft(unit, key)
                local threshold = self.db.earlyGreaterWarning and 900 or 120
                return timeLeft and timeLeft <= threshold
            end
            if not self:UnitHasBlessing(unit, key) then return true end
            local timeLeft = self:GetBlessingTimeLeft(unit, key)
            return timeLeft and timeLeft <= 120
        end

        local checkedClasses = {}
        for _, class in ipairs(self.CLASS_ORDER) do
            local members = self.partyClasses[class]
            if members and not checkedClasses[class] then
                checkedClasses[class] = true

                local blessingGroups = {}
                for _, m in ipairs(members) do
                    local key = self:GetPlannedBlessingKey(m)
                    if key then
                        blessingGroups[key] = blessingGroups[key] or {}
                        table.insert(blessingGroups[key], m)
                    end
                end

                local playerKey = nil
                for key, group in pairs(blessingGroups) do
                    for _, m in ipairs(group) do
                        if m.unit == "player" then playerKey = key; break end
                    end
                    if playerKey then break end
                end

                local numKeys = 0
                for _ in pairs(blessingGroups) do numKeys = numKeys + 1 end
                local hasConflict = numKeys > 1

                local primaryKey, primaryCount = nil, 0
                for _, b in ipairs(self.BLESSINGS) do
                    local group = blessingGroups[b.key]
                    if group and #group > primaryCount then
                        if not (hasConflict and playerKey and b.key == playerKey) then
                            primaryKey = b.key
                            primaryCount = #group
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

                if primaryKey then
                    local canUseGreater = not self.db.useBaseBlessings
                        and self.knownGreater and self.knownGreater[primaryKey]
                        and numParty > 0

                    if canUseGreater then
                        local primaryNeedsRefresh = false
                        local intendedRecipient = nil
                        for _, m in ipairs(blessingGroups[primaryKey]) do
                            if needsRefresh(m.unit, primaryKey, true) then
                                primaryNeedsRefresh = true
                                if m.unit == "player" or (UnitIsVisible and UnitIsVisible(m.unit)) then
                                    intendedRecipient = m
                                    break
                                elseif not intendedRecipient then
                                    intendedRecipient = m
                                end
                            end
                        end

                        if primaryNeedsRefresh then
                            local b = self:GetBlessingByKey(primaryKey)
                            local greaterTarget = nil
                            for _, m in ipairs(blessingGroups[primaryKey]) do
                                if m.unit == "player" then
                                    greaterTarget = m
                                    break
                                end
                            end
                            if not greaterTarget then
                                for _, m in ipairs(blessingGroups[primaryKey]) do
                                    if not IsSpellInRange or IsSpellInRange(b.greater, m.unit) ~= 0 then
                                        greaterTarget = m
                                        break
                                    end
                                end
                            end
                            if not greaterTarget then
                                greaterTarget = blessingGroups[primaryKey][1]
                            end
                            table.insert(greaterQueue, {
                                spell = b.greater,
                                unit = greaterTarget.unit,
                                intendedUnit = intendedRecipient.unit,
                                intendedName = intendedRecipient.name,
                            })
                            for key, group in pairs(blessingGroups) do
                                if key ~= primaryKey then
                                    for _, m in ipairs(group) do
                                        if needsRefresh(m.unit, key) then
                                            local b2 = self:GetBlessingByKey(key)
                                            if b2 then
                                                table.insert(baseQueue, { spell = b2.name, unit = m.unit })
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            for key, group in pairs(blessingGroups) do
                                if key ~= primaryKey then
                                    for _, m in ipairs(group) do
                                        if needsRefresh(m.unit, key) then
                                            local b = self:GetBlessingByKey(key)
                                            if b then
                                                table.insert(baseQueue, { spell = b.name, unit = m.unit })
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    else
                        for key, group in pairs(blessingGroups) do
                            for _, m in ipairs(group) do
                                if needsRefresh(m.unit, key) then
                                    local b = self:GetBlessingByKey(key)
                                    if b then
                                        table.insert(baseQueue, { spell = b.name, unit = m.unit })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        for _, member in ipairs(self.partyMembers) do
            if member.isPet then
                local key = self.db.playerBlessings[member.name]
                if key then
                    local b = self:GetBlessingByKey(key)
                    if b then
                        if not self:UnitHasBlessing(member.unit, key) then
                            table.insert(baseQueue, { spell = b.name, unit = member.unit })
                        else
                            local timeLeft = self:GetBlessingTimeLeft(member.unit, key)
                            if timeLeft and timeLeft <= 120 then
                                table.insert(baseQueue, { spell = b.name, unit = member.unit })
                            end
                        end
                    end
                end
            end
        end

        for _, entry in ipairs(greaterQueue) do
            table.insert(missing, entry)
        end
        for _, entry in ipairs(baseQueue) do
            table.insert(missing, entry)
        end
    end

    if not self.db.ignoreAura and self.db.selectedAura and self:GetActiveAura() ~= self.db.selectedAura then
        table.insert(missing, { spell = self.db.selectedAura, unit = "player" })
    end

    if self:ShouldUseRighteousFury() and not self:HasRighteousFury() then
        table.insert(missing, { spell = "Righteous Fury", unit = "player" })
    end

    if self:ShouldUseRighteousFury() and self:HasRighteousFury() then
        local rfTimeLeft = self:GetRFTimeLeft()
        if rfTimeLeft and rfTimeLeft <= 120 then
            table.insert(missing, { spell = "Righteous Fury", unit = "player" })
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
        elseif IsSpellInRange and IsSpellInRange(entry.spell, entry.unit) ~= 1 then
            isOOR = true
        end

        if not isOOR and entry.intendedUnit and entry.intendedUnit ~= entry.unit then
            if UnitIsVisible and not UnitIsVisible(entry.intendedUnit) then
                isOOR = true
            elseif IsSpellInRange and IsSpellInRange(entry.spell, entry.intendedUnit) ~= 1 then
                isOOR = true
            end
        end

        if isOOR then
            table.insert(outOfRange, entry)
            local name = entry.intendedName or UnitName(entry.intendedUnit or entry.unit)
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
        self.nextBuffIntendedName = allMissing[1].intendedName
    else
        self.nextBuffSpell = nil
        self.nextBuffUnit = nil
        self.nextBuffIntendedName = nil
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
            if self.nextBuffIntendedName and self.nextBuffIntendedName ~= castTarget then
                GameTooltip:AddLine("Target: " .. self.nextBuffIntendedName .. " (cast on: " .. castTarget .. ")", 0.8, 0.8, 0.8)
            else
                GameTooltip:AddLine("Target: " .. castTarget, 0.8, 0.8, 0.8)
            end
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

function SP:SetClassAssignment(class, blessingKey)
    self.db.classAssignments[class] = blessingKey
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:SetPlayerBlessing(playerName, blessingKey)
    self.db.playerBlessings[playerName] = blessingKey
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:SetAura(auraName)
    self.db.selectedAura = auraName
    self:PPSendSelfIfInGroup()
    self:UpdateBuffStatus()
    if self.editPanel and self.editPanel:IsShown() then self:UpdateEditPanel() end
end

function SP:ClearAll()
    self.db.classAssignments = {}
    self.db.playerBlessings = {}
    self.db.selectedAura = nil

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

function SP:SalvAll()
    local playerName = UnitName("player")
    local myRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    for _, member in ipairs(self.partyMembers) do
        if not member.isPet then
            local isSelf = (member.name == playerName)
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(member.unit)
            if isSelf then
                self.db.playerBlessings[member.name] = (myRole == "TANK") and "sanctuary" or "wisdom"
            elseif role == "TANK" then
                self.db.playerBlessings[member.name] = "light"
            elseif myRole == "TANK" and role == "HEALER" then
                self.db.playerBlessings[member.name] = "wisdom"
            else
                self.db.playerBlessings[member.name] = "salvation"
            end
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
        if not member.isPet then
            local isSelf = (member.name == playerName)
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(member.unit)
            if isSelf then
                self.db.playerBlessings[member.name] = (myRole == "TANK") and "sanctuary" or "wisdom"
            elseif role == "TANK" then
                self.db.playerBlessings[member.name] = "light"
            else
                self.db.playerBlessings[member.name] = self.db.classAssignments[member.class]
            end
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
            isPet = true, ownerName = "Beastmode",
        })
    end

    for _, m in ipairs(fakeMembers) do
        table.insert(self.partyMembers, m)
        self.partyClasses[m.class] = self.partyClasses[m.class] or {}
        table.insert(self.partyClasses[m.class], m)
    end

    self.db.classAssignments = {
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

    self.db.playerBlessings = {
        ["Tankenstein"] = "light",
        ["Healsworth"]  = "wisdom",
        ["Frostbite"]   = "kings",
    }

    self.db.showOtherPaladins = true
    self.db.selectedAura = "Devotion Aura"
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
