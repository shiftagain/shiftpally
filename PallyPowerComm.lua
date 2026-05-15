local SP = ShiftPally

local PLPWR = "PLPWR"
local MAXCLASSES = 9
local MAXAURAS = 8

-- BlessingID <-> SP blessing key
local BLESSING_TO_KEY = {
    [0] = nil,
    [1] = "wisdom",
    [2] = "might",
    [3] = "kings",
    [4] = "salvation",
    [5] = "light",
    [6] = "sanctuary",
}

local KEY_TO_BLESSING = {
    wisdom = 1,
    might = 2,
    kings = 3,
    salvation = 4,
    light = 5,
    sanctuary = 6,
}

-- ClassID <-> WoW class name (PP ordering, NOT WoW internal IDs)
local CLASS_ID_TO_NAME = {
    [1] = "WARRIOR",
    [2] = "ROGUE",
    [3] = "PRIEST",
    [4] = "DRUID",
    [5] = "PALADIN",
    [6] = "HUNTER",
    [7] = "MAGE",
    [8] = "WARLOCK",
    [9] = "SHAMAN",
}

local NAME_TO_CLASS_ID = {}
for id, name in pairs(CLASS_ID_TO_NAME) do
    NAME_TO_CLASS_ID[name] = id
end

-- AuraID <-> aura spell name
local AURA_ID_TO_NAME = {
    [0] = nil,
    [1] = "Devotion Aura",
    [2] = "Retribution Aura",
    [3] = "Concentration Aura",
    [4] = "Shadow Resistance Aura",
    [5] = "Frost Resistance Aura",
    [6] = "Fire Resistance Aura",
    [7] = "Sanctity Aura",
    [8] = "Crusader Aura",
}

local NAME_TO_AURA_ID = {}
for id, name in pairs(AURA_ID_TO_NAME) do
    if name then NAME_TO_AURA_ID[name] = id end
end

SP.PP = {
    BLESSING_TO_KEY = BLESSING_TO_KEY,
    KEY_TO_BLESSING = KEY_TO_BLESSING,
    CLASS_ID_TO_NAME = CLASS_ID_TO_NAME,
    NAME_TO_CLASS_ID = NAME_TO_CLASS_ID,
    AURA_ID_TO_NAME = AURA_ID_TO_NAME,
    NAME_TO_AURA_ID = NAME_TO_AURA_ID,
    MAXCLASSES = MAXCLASSES,
    MAXAURAS = MAXAURAS,
}

-- ═══════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════

SP.ppState = {
    Assignments = {},
    NormalAssignments = {},
    AuraAssignments = {},
    Paladins = {},
    SyncList = {},
    Leaders = {},
}

local lastSentMessage = nil
local wasInGroup = false
local ppInitialized = false
local rosterBucket = nil
local pendingSync = {}
local pendingBuffer = {}
local syncGeneration = 0

local function SafeTimerAfter(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    else
        local f = CreateFrame("Frame")
        local elapsed = 0
        f:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════
-- Utility
-- ═══════════════════════════════════════════════════════

function SP:NormalizeName(fullName)
    if not fullName then return nil end
    local name, realm = strsplit("-", fullName)
    if realm and realm ~= "" then
        local myRealm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
        if realm ~= myRealm then
            return fullName
        end
    end
    return name
end

function SP:PPIsInGroup()
    if IsInRaid and IsInRaid() then return true end
    if GetNumGroupMembers then return GetNumGroupMembers() > 0 end
    if GetNumPartyMembers then return GetNumPartyMembers() > 0 end
    return false
end

function SP:PPAmILeader()
    if IsInRaid and IsInRaid() then
        local numRaid = (GetNumRaidMembers or GetNumGroupMembers)()
        for i = 1, numRaid do
            local name, rank = GetRaidRosterInfo(i)
            if name and rank and rank > 0 then
                local norm = self:NormalizeName(name)
                if norm == UnitName("player") then return true end
            end
        end
        return false
    end
    if UnitIsGroupLeader then return UnitIsGroupLeader("player") end
    return false
end

function SP:PPIsLeader(name)
    return self.ppState.Leaders[name] == true
end

function SP:PPCanAssign(sender, targetPaladin)
    return targetPaladin == sender
        or self:PPIsLeader(sender)
        or (self.db.allowNonLeaderAssign == true)
end

function SP:PPCanEditPaladin(ppName)
    if self:PPAmILeader() then return true end
    local pd = ppName and self.ppState.Paladins[ppName]
    return pd and pd.freeassign == true
end

function SP:PPCanClear(sender)
    if self:PPIsLeader(sender) then return "all" end
    if self.db.allowNonLeaderAssign then return "self" end
    return nil
end

-- ═══════════════════════════════════════════════════════
-- Transport
-- ═══════════════════════════════════════════════════════

local function RegisterPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PLPWR)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PLPWR)
    end
end

local function GetDistribution()
    if IsInRaid and IsInRaid() then return "RAID" end
    return "PARTY"
end

local function RawSendAddonMessage(prefix, msg, dist, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, msg, dist, target)
    elseif SendAddonMessage then
        SendAddonMessage(prefix, msg, dist, target)
    end
end

function SP:PPSend(msg, target)
    if not msg then return end
    if msg == lastSentMessage then return end
    lastSentMessage = msg

    if target then
        RawSendAddonMessage(PLPWR, msg, "WHISPER", target)
    else
        RawSendAddonMessage(PLPWR, msg, GetDistribution())
    end
end

-- ═══════════════════════════════════════════════════════
-- Encoding (for SendSelf)
-- ═══════════════════════════════════════════════════════

local BLESSING_ORDER = { "wisdom", "might", "kings", "salvation", "light", "sanctuary" }

function SP:EncodeSpellData()
    local result = ""
    for _, key in ipairs(BLESSING_ORDER) do
        if self.knownBlessings and self.knownBlessings[key] then
            local rank = (self.spellRanks and self.spellRanks[key]) or 1
            if rank > 15 then rank = 15 end
            local talent = (self.talentPoints and self.talentPoints[key]) or 0
            if talent > 15 then talent = 15 end
            result = result .. string.format("%x%x", rank, talent)
        else
            result = result .. "nn"
        end
    end
    return result
end

function SP:EncodeAuraData()
    local result = ""
    for i = 1, MAXAURAS do
        local auraName = AURA_ID_TO_NAME[i]
        if auraName and self.knownAuras and self.knownAuras[auraName] then
            local rank = (self.spellRanks and self.spellRanks[auraName]) or 1
            if rank > 15 then rank = 15 end
            local talent = (self.talentPoints and self.talentPoints[auraName]) or 0
            if talent > 15 then talent = 15 end
            result = result .. string.format("%x%x", rank, talent)
        else
            result = result .. "nn"
        end
    end
    return result
end

function SP:EncodeAssignments()
    local result = ""
    for i = 1, MAXCLASSES do
        local className = CLASS_ID_TO_NAME[i]
        local key = self.charDB.classAssignments and self.charDB.classAssignments[className]
        if key then
            local id = KEY_TO_BLESSING[key]
            result = result .. (id and tostring(id) or "n")
        else
            result = result .. "n"
        end
    end
    return result
end

local COOLDOWN_SPELLS = {
    [1] = "Lay on Hands",
    [2] = "Divine Intervention",
}

function SP:ScanCooldowns()
    self.myCooldowns = self.myCooldowns or {}
    for slot, spellName in pairs(COOLDOWN_SPELLS) do
        if GetSpellCooldown then
            local start, duration = GetSpellCooldown(spellName)
            if start and start > 0 and duration and duration > 1.5 then
                self.myCooldowns[slot] = { start = start, duration = duration }
            else
                self.myCooldowns[slot] = nil
            end
        end
    end
end

function SP:EncodeCooldowns()
    self:ScanCooldowns()
    local result = ""
    for slot = 1, 2 do
        local cd = self.myCooldowns and self.myCooldowns[slot]
        if cd then
            local remaining = math.max(0, math.floor(cd.duration - (GetTime() - cd.start)))
            result = result .. ":" .. math.floor(cd.duration) .. ":" .. remaining
        else
            result = result .. ":n:n"
        end
    end
    return result
end

-- ═══════════════════════════════════════════════════════
-- SendSelf Sequence
-- ═══════════════════════════════════════════════════════

function SP:PPSendSelf(target)
    if not self:PPIsInGroup() then return end

    local myName = UnitName("player")
    if not myName then return end

    local sendTarget = nil
    if target then
        if self:PPIsLeader(target) then
            sendTarget = nil
        else
            sendTarget = target
        end
    end

    lastSentMessage = nil

    if self:PPAmILeader() then
        self:PPSend("PPLEADER " .. myName)
    end

    local spellData = self:EncodeSpellData()
    local assignments = self:EncodeAssignments()
    self:PPSend("SELF " .. spellData .. "@" .. assignments, sendTarget)

    local auraData = self:EncodeAuraData()
    local auraAssign = "n"
    if self.charDB.selectedAura then
        local auraID = NAME_TO_AURA_ID[self.charDB.selectedAura]
        if auraID then auraAssign = tostring(auraID) end
    end
    self:PPSend("ASELF " .. auraData .. "@" .. auraAssign, sendTarget)

    local tuples = {}
    if self.charDB.playerBlessings then
        for playerName, blessingKey in pairs(self.charDB.playerBlessings) do
            local blessingID = KEY_TO_BLESSING[blessingKey] or 0
            for _, member in ipairs(self.partyMembers) do
                if member.name == playerName then
                    local classID = NAME_TO_CLASS_ID[member.class]
                    if classID then
                        table.insert(tuples, myName .. " " .. classID .. " " .. playerName .. " " .. blessingID)
                    end
                    break
                end
            end
        end
    end

    for i = 1, #tuples, 5 do
        local batch = {}
        for j = i, math.min(i + 4, #tuples) do
            table.insert(batch, tuples[j])
        end
        self:PPSend("NASSIGN " .. table.concat(batch, "@"), sendTarget)
    end

    local fa = self.db.allowNonLeaderAssign and "YES" or "NO"
    local symbols = GetItemCount and GetItemCount(21177) or 0
    local cooldownStr = self:EncodeCooldowns()
    self:PPSend("FREEASSIGN " .. fa .. " | SYMCOUNT " .. symbols .. " | COOLDOWNS" .. cooldownStr, sendTarget)
end

function SP:PPSendSelfIfInGroup()
    if self:PPIsInGroup() and not self.useFakeData then
        self:PPSendSelf()
    end
end

function SP:PPSendREQ()
    if self:PPIsInGroup() then
        lastSentMessage = nil
        self:PPSend("REQ")
    end
end

-- ═══════════════════════════════════════════════════════
-- Send helpers for UI changes to other paladins
-- ═══════════════════════════════════════════════════════

function SP:PPSendAssign(paladinName, classID, blessingID)
    if not self:PPIsInGroup() then return end
    lastSentMessage = nil
    self:PPSend("ASSIGN " .. paladinName .. " " .. classID .. " " .. blessingID)
    if not self.ppState.Assignments[paladinName] then
        self.ppState.Assignments[paladinName] = {}
    end
    self.ppState.Assignments[paladinName][classID] = blessingID
end

function SP:PPSendNAssign(paladinName, classID, targetName, blessingID)
    if not self:PPIsInGroup() then return end
    lastSentMessage = nil
    self:PPSend("NASSIGN " .. paladinName .. " " .. classID .. " " .. targetName .. " " .. blessingID)
    if not self.ppState.NormalAssignments[paladinName] then
        self.ppState.NormalAssignments[paladinName] = {}
    end
    if not self.ppState.NormalAssignments[paladinName][classID] then
        self.ppState.NormalAssignments[paladinName][classID] = {}
    end
    if blessingID == 0 then
        self.ppState.NormalAssignments[paladinName][classID][targetName] = nil
    else
        self.ppState.NormalAssignments[paladinName][classID][targetName] = blessingID
    end
end

function SP:PPSendAAssign(paladinName, auraID)
    if not self:PPIsInGroup() then return end
    lastSentMessage = nil
    self:PPSend("AASSIGN " .. paladinName .. " " .. auraID)
    self.ppState.AuraAssignments[paladinName] = auraID
end

function SP:PPSendClearMsg(skipAuras)
    if not self:PPIsInGroup() then return end
    lastSentMessage = nil
    self:PPSend(skipAuras and "CLEAR SKIP" or "CLEAR")
end

-- ═══════════════════════════════════════════════════════
-- High-level API for EditPanel
-- ═══════════════════════════════════════════════════════

function SP:PPAssignOtherClass(ppName, className, blessingKey)
    local classID = NAME_TO_CLASS_ID[className]
    if not classID then return end
    local blessingID = blessingKey and KEY_TO_BLESSING[blessingKey] or 0
    self:PPSendAssign(ppName, classID, blessingID)
    if self.editPanel and self.editPanel:IsShown() then
        self:UpdateEditPanel()
    end
end

function SP:PPAssignOtherPlayer(ppName, member, blessingKey)
    local classID = NAME_TO_CLASS_ID[member.class]
    if not classID then return end
    local blessingID = blessingKey and KEY_TO_BLESSING[blessingKey] or 0
    self:PPSendNAssign(ppName, classID, member.name, blessingID)
    if self.editPanel and self.editPanel:IsShown() then
        self:UpdateEditPanel()
    end
end

function SP:PPAssignOtherAura(ppName, auraName)
    local auraID = auraName and NAME_TO_AURA_ID[auraName] or 0
    self:PPSendAAssign(ppName, auraID)
    if self.auraPanel and self.auraPanel:IsShown() then
        self:UpdateAuraPanel()
    end
end

-- ═══════════════════════════════════════════════════════
-- State conversion: PP state -> SP format for UI
-- ═══════════════════════════════════════════════════════

function SP:PPStateToSPData(paladinName)
    local data = {
        classAssignments = {},
        playerBlessings = {},
        selectedAura = nil,
    }

    local assignments = self.ppState.Assignments[paladinName]
    if assignments then
        for classID, blessingID in pairs(assignments) do
            local className = CLASS_ID_TO_NAME[classID]
            local blessingKey = BLESSING_TO_KEY[blessingID]
            if className and blessingKey then
                data.classAssignments[className] = blessingKey
            end
        end
    end

    local normalAssignments = self.ppState.NormalAssignments[paladinName]
    if normalAssignments then
        for classID, players in pairs(normalAssignments) do
            for playerName, blessingID in pairs(players) do
                local blessingKey = BLESSING_TO_KEY[blessingID]
                if blessingKey then
                    data.playerBlessings[playerName] = blessingKey
                end
            end
        end
    end

    local auraID = self.ppState.AuraAssignments[paladinName]
    if auraID and auraID > 0 then
        data.selectedAura = AURA_ID_TO_NAME[auraID]
    end

    return data
end

-- ═══════════════════════════════════════════════════════
-- SyncList management
-- ═══════════════════════════════════════════════════════

local function AddToSyncList(name)
    local list = SP.ppState.SyncList
    for _, n in ipairs(list) do
        if n == name then return end
    end
    table.insert(list, name)
    table.sort(list)
end

-- ═══════════════════════════════════════════════════════
-- Message Handlers
-- ═══════════════════════════════════════════════════════

function SP:HandlePPLEADER(sender, msg)
    local name = msg:match("^PPLEADER (.+)")
    if not name then return end
    name = self:NormalizeName(name)
    if not name then return end
    self:PPUpdateLeaders()
end

function SP:HandleSELF(sender, msg)
    local payload = msg:match("^SELF (.+)")
    if not payload then return end

    local spellData, assignData = strsplit("@", payload)
    if not spellData or not assignData then return end

    pendingSync[sender] = true
    syncGeneration = syncGeneration + 1
    local myGen = syncGeneration
    SafeTimerAfter(0.5, function()
        if syncGeneration ~= myGen then return end
        SP:CommitAllPending()
    end)

    pendingBuffer[sender] = {
        assignments = {},
        normalAssignments = {},
        auraAssignment = 0,
        paladin = {
            spells = {},
            auras = {},
            freeassign = false,
            symbols = 0,
            cooldowns = {},
        },
    }

    local buf = pendingBuffer[sender]
    for i = 1, 6 do
        local pos = (i - 1) * 2 + 1
        local rankChar = spellData:sub(pos, pos)
        local talentChar = spellData:sub(pos + 1, pos + 1)
        if rankChar ~= "n" then
            buf.paladin.spells[i] = {
                rank = tonumber(rankChar, 16) or 1,
                talent = tonumber(talentChar) or 0,
            }
        end
    end

    for i = 1, MAXCLASSES do
        local c = assignData:sub(i, i)
        if c == "n" or c == "" then
            buf.assignments[i] = 0
        else
            buf.assignments[i] = tonumber(c) or 0
        end
    end
end

function SP:HandleASELF(sender, msg)
    local payload = msg:match("^ASELF (.+)")
    if not payload then return end

    local auraData, assignStr = strsplit("@", payload)
    if not auraData then return end

    local buf = pendingBuffer[sender]
    if buf then
        for i = 1, MAXAURAS do
            local pos = (i - 1) * 2 + 1
            local rankChar = auraData:sub(pos, pos)
            local talentChar = auraData:sub(pos + 1, pos + 1)
            if rankChar ~= "n" then
                buf.paladin.auras[i] = {
                    rank = tonumber(rankChar, 16) or 1,
                    talent = tonumber(talentChar) or 0,
                }
            end
        end
        if assignStr and assignStr ~= "n" and assignStr ~= "" then
            buf.auraAssignment = tonumber(assignStr) or 0
        end
    else
        if not self.ppState.Paladins[sender] then return end
        self.ppState.AuraAssignments[sender] = 0
        self.ppState.Paladins[sender].auras = {}
        for i = 1, MAXAURAS do
            local pos = (i - 1) * 2 + 1
            local rankChar = auraData:sub(pos, pos)
            local talentChar = auraData:sub(pos + 1, pos + 1)
            if rankChar ~= "n" then
                self.ppState.Paladins[sender].auras[i] = {
                    rank = tonumber(rankChar, 16) or 1,
                    talent = tonumber(talentChar) or 0,
                }
            end
        end
        if assignStr and assignStr ~= "n" and assignStr ~= "" then
            self.ppState.AuraAssignments[sender] = tonumber(assignStr) or 0
        end
    end
end

function SP:HandleASSIGN(sender, msg)
    local pName, classStr, blessStr = msg:match("^ASSIGN (.+) (%d+) (%d+)")
    if not pName then return end

    pName = self:NormalizeName(pName)
    local classID = tonumber(classStr)
    local blessingID = tonumber(blessStr)
    if not pName or not classID or not blessingID then return end
    if not self:PPCanAssign(sender, pName) then return end

    if not self.ppState.Assignments[pName] then
        self.ppState.Assignments[pName] = {}
    end
    self.ppState.Assignments[pName][classID] = blessingID

    local myName = UnitName("player")
    if pName == myName then
        local className = CLASS_ID_TO_NAME[classID]
        local blessingKey = BLESSING_TO_KEY[blessingID]
        if className then
            if not blessingKey or (self.knownBlessings and self.knownBlessings[blessingKey]) then
                self.charDB.classAssignments[className] = blessingKey
            end
        end
    end
end

function SP:HandlePASSIGN(sender, msg)
    local pName, assignData = msg:match("^PASSIGN ([^@]+)@(.+)")
    if not pName or not assignData then return end

    pName = self:NormalizeName(pName)
    if not pName then return end
    if not self:PPCanAssign(sender, pName) then return end

    if not self.ppState.Assignments[pName] then
        self.ppState.Assignments[pName] = {}
    end

    for i = 1, MAXCLASSES do
        local c = assignData:sub(i, i)
        if c == "n" or c == "" then
            self.ppState.Assignments[pName][i] = 0
        else
            self.ppState.Assignments[pName][i] = tonumber(c) or 0
        end
    end

    local myName = UnitName("player")
    if pName == myName then
        for i = 1, MAXCLASSES do
            local className = CLASS_ID_TO_NAME[i]
            local bid = self.ppState.Assignments[pName][i] or 0
            if className then
                local blessingKey = BLESSING_TO_KEY[bid]
                if not blessingKey or (self.knownBlessings and self.knownBlessings[blessingKey]) then
                    self.charDB.classAssignments[className] = blessingKey
                end
            end
        end
    end
end

function SP:HandleNASSIGN(sender, msg)
    local payload = msg:match("^NASSIGN (.+)")
    if not payload then return end

    local tuples = {}
    for tuple in payload:gmatch("([^@]+)") do
        local pName, classStr, tName, blessStr = tuple:match("(.+) (%d+) (.+) (%d+)")
        if pName then
            table.insert(tuples, {
                paladin = self:NormalizeName(pName),
                classID = tonumber(classStr),
                target = tName,
                blessingID = tonumber(blessStr),
            })
        end
    end

    for _, t in ipairs(tuples) do
        if not self:PPCanAssign(sender, t.paladin) then return end
    end

    local myName = UnitName("player")
    for _, t in ipairs(tuples) do
        if t.paladin and t.classID and t.target and t.blessingID then
            local buf = pendingBuffer[t.paladin]
            if buf then
                if not buf.normalAssignments[t.classID] then
                    buf.normalAssignments[t.classID] = {}
                end
                if t.blessingID == 0 then
                    buf.normalAssignments[t.classID][t.target] = nil
                else
                    buf.normalAssignments[t.classID][t.target] = t.blessingID
                end
            else
                if not self.ppState.NormalAssignments[t.paladin] then
                    self.ppState.NormalAssignments[t.paladin] = {}
                end
                if not self.ppState.NormalAssignments[t.paladin][t.classID] then
                    self.ppState.NormalAssignments[t.paladin][t.classID] = {}
                end
                if t.blessingID == 0 then
                    self.ppState.NormalAssignments[t.paladin][t.classID][t.target] = nil
                else
                    self.ppState.NormalAssignments[t.paladin][t.classID][t.target] = t.blessingID
                end
            end

            if t.paladin == myName then
                local blessingKey = BLESSING_TO_KEY[t.blessingID]
                if t.blessingID == 0 then
                    self.charDB.playerBlessings[t.target] = nil
                elseif blessingKey and self.knownBlessings and self.knownBlessings[blessingKey] then
                    self.charDB.playerBlessings[t.target] = blessingKey
                end
            end
        end
    end
end

function SP:HandleMASSIGN(sender, msg)
    local pName, blessStr = msg:match("^MASSIGN (.+) (%d+)")
    if not pName then return end

    pName = self:NormalizeName(pName)
    local blessingID = tonumber(blessStr)
    if not pName or not blessingID then return end
    if not self:PPCanAssign(sender, pName) then return end

    if not self.ppState.Assignments[pName] then
        self.ppState.Assignments[pName] = {}
    end
    for i = 1, MAXCLASSES do
        self.ppState.Assignments[pName][i] = blessingID
    end

    local myName = UnitName("player")
    if pName == myName then
        local blessingKey = BLESSING_TO_KEY[blessingID]
        if not blessingKey or (self.knownBlessings and self.knownBlessings[blessingKey]) then
            for i = 1, MAXCLASSES do
                local className = CLASS_ID_TO_NAME[i]
                if className then
                    self.charDB.classAssignments[className] = blessingKey
                end
            end
        end
    end
end

function SP:HandleSYMCOUNT(sender, msg)
    local count = msg:match("SYMCOUNT (%d+)")
    local buf = pendingBuffer[sender]
    if buf then
        buf.paladin.symbols = tonumber(count) or 0
    elseif self.ppState.Paladins[sender] then
        self.ppState.Paladins[sender].symbols = tonumber(count) or 0
    end
end

function SP:HandleCOOLDOWNS(sender, msg)
    local cdStr = msg:match("COOLDOWNS(.*)")
    if not cdStr then return end

    local parts = { strsplit(":", cdStr) }
    local slots = {
        { d = parts[2], r = parts[3] },
        { d = parts[4], r = parts[5] },
    }

    local buf = pendingBuffer[sender]
    local target = buf and buf.paladin or self.ppState.Paladins[sender]
    if not target then return end

    if not target.cooldowns then
        target.cooldowns = {}
    end

    for slot = 1, 2 do
        local s = slots[slot]
        if s and s.r and s.r ~= "n" and not target.cooldowns[slot] then
            local duration = tonumber(s.d)
            local remaining = tonumber(s.r)
            if duration and remaining then
                target.cooldowns[slot] = {
                    start = GetTime() - (duration - remaining),
                    duration = duration,
                }
            end
        end
    end
end

function SP:HandleCLEAR(sender, msg)
    local scope = self:PPCanClear(sender)
    if not scope then return end

    local skipAuras = msg:find("SKIP") ~= nil
    local myName = UnitName("player")

    if scope == "all" then
        for _, assignments in pairs(self.ppState.Assignments) do
            for i = 1, MAXCLASSES do
                assignments[i] = 0
            end
        end
        self.ppState.NormalAssignments = {}
        if not skipAuras then
            for pName in pairs(self.ppState.AuraAssignments) do
                self.ppState.AuraAssignments[pName] = 0
            end
        end
        self.charDB.classAssignments = {}
        self.charDB.playerBlessings = {}
        if not skipAuras then self.charDB.selectedAura = nil end
    elseif scope == "self" then
        if self.ppState.Assignments[myName] then
            for i = 1, MAXCLASSES do
                self.ppState.Assignments[myName][i] = 0
            end
        end
        self.ppState.NormalAssignments[myName] = {}
        if not skipAuras then
            self.ppState.AuraAssignments[myName] = 0
        end
        self.charDB.classAssignments = {}
        self.charDB.playerBlessings = {}
        if not skipAuras then self.charDB.selectedAura = nil end
    end
end

function SP:HandleFREEASSIGN(sender, isYes)
    local buf = pendingBuffer[sender]
    if buf then
        buf.paladin.freeassign = isYes
        self:CommitPending(sender)
        pendingSync[sender] = nil
        if not next(pendingSync) then
            self:FlushPPUpdate()
        end
    elseif self.ppState.Paladins[sender] then
        self.ppState.Paladins[sender].freeassign = isYes
    end
end

function SP:CommitPending(sender)
    local buf = pendingBuffer[sender]
    if not buf then return end

    self.ppState.Paladins[sender] = buf.paladin
    self.ppState.Assignments[sender] = buf.assignments
    self.ppState.NormalAssignments[sender] = buf.normalAssignments
    self.ppState.AuraAssignments[sender] = buf.auraAssignment
    AddToSyncList(sender)

    pendingBuffer[sender] = nil
end

function SP:CommitAllPending()
    for sender in pairs(pendingBuffer) do
        self:CommitPending(sender)
    end
    pendingSync = {}
    self:FlushPPUpdate()
end

function SP:HandleAASSIGN(sender, msg)
    local pName, auraStr = msg:match("^AASSIGN (.+) (%d+)")
    if not pName then return end

    pName = self:NormalizeName(pName)
    local auraID = tonumber(auraStr)
    if not pName or not auraID then return end
    if not self:PPCanAssign(sender, pName) then return end

    self.ppState.AuraAssignments[pName] = auraID

    local myName = UnitName("player")
    if pName == myName then
        if auraID > 0 then
            local auraName = AURA_ID_TO_NAME[auraID]
            if auraName and self.knownAuras and self.knownAuras[auraName] then
                self.charDB.selectedAura = auraName
            end
        else
            self.charDB.selectedAura = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- Main Message Parser
-- ═══════════════════════════════════════════════════════

local VALID_DISTRIBUTIONS = {
    PARTY = true,
    RAID = true,
    INSTANCE_CHAT = true,
    WHISPER = true,
}

function SP:ParsePPMessage(prefix, msg, dist, sender)
    if prefix ~= PLPWR then return end
    if not msg or msg == "" then return end
    if not VALID_DISTRIBUTIONS[dist] then return end

    sender = self:NormalizeName(sender)
    if not sender then return end
    local myName = UnitName("player")

    if msg:find("^PPLEADER") then
        self:HandlePPLEADER(sender, msg)
    end

    if sender == myName then return end

    if msg == "REQ" then
        if self:PPIsLeader(sender) then
            self:PPSendSelf()
        else
            self:PPSendSelf(sender)
        end
        return
    end

    if msg:find("^SELF ") then self:HandleSELF(sender, msg) end
    if msg:find("^ASSIGN ") then self:HandleASSIGN(sender, msg) end
    if msg:find("^PASSIGN ") then self:HandlePASSIGN(sender, msg) end
    if msg:find("^NASSIGN ") then self:HandleNASSIGN(sender, msg) end
    if msg:find("^MASSIGN ") then self:HandleMASSIGN(sender, msg) end
    if msg:find("SYMCOUNT") then self:HandleSYMCOUNT(sender, msg) end
    if msg:find("COOLDOWNS") then self:HandleCOOLDOWNS(sender, msg) end
    if msg:find("^CLEAR") then self:HandleCLEAR(sender, msg) end
    if msg:find("FREEASSIGN YES") then self:HandleFREEASSIGN(sender, true) end
    if msg:find("FREEASSIGN NO") then self:HandleFREEASSIGN(sender, false) end
    if msg:find("^ASELF ") then self:HandleASELF(sender, msg) end
    if msg:find("^AASSIGN ") then self:HandleAASSIGN(sender, msg) end

    self:UpdateBuffStatus()
    if not next(pendingSync) then
        self:FlushPPUpdate()
    end
end

function SP:PPSyncInProgress()
    return next(pendingSync) ~= nil
end

function SP:FlushPPUpdate()
    if SP.iconPickerOpen or SP.auraIconPickerOpen then return end
    if self.editPanel and self.editPanel:IsShown() then
        self:UpdateEditPanel()
    end
    if self.auraPanel and self.auraPanel:IsShown() then
        self:UpdateAuraPanel()
    end
end

-- ═══════════════════════════════════════════════════════
-- Group Event Handling
-- ═══════════════════════════════════════════════════════

function SP:PPUpdateLeaders()
    self.ppState.Leaders = {}
    if IsInRaid and IsInRaid() then
        local numRaid = (GetNumRaidMembers or GetNumGroupMembers)()
        for i = 1, numRaid do
            local name, rank = GetRaidRosterInfo(i)
            if name and rank and rank > 0 then
                local norm = self:NormalizeName(name)
                if norm then self.ppState.Leaders[norm] = true end
            end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsGroupLeader and UnitIsGroupLeader(unit) then
                local name = UnitName(unit)
                if name then self.ppState.Leaders[name] = true end
            end
        end
        if UnitIsGroupLeader and UnitIsGroupLeader("player") then
            local name = UnitName("player")
            if name then self.ppState.Leaders[name] = true end
        end
    end
end

function SP:PPOnGroupJoined()
    self.ppState.Paladins = {}
    self.ppState.SyncList = {}
    self.ppState.Assignments = {}
    self.ppState.NormalAssignments = {}
    self.ppState.AuraAssignments = {}
    self.charDB.playerBlessings = {}

    self:ScanSpellbook()
    self:PPUpdateLeaders()

    SafeTimerAfter(2.0, function()
        if SP:PPIsInGroup() then
            SP:PPSendSelf()
            SP:PPSendREQ()
        end
    end)
end

function SP:PPOnGroupLeft()
    self.ppState.Paladins = {}
    self.ppState.SyncList = {}
    self.ppState.Assignments = {}
    self.ppState.NormalAssignments = {}
    self.ppState.AuraAssignments = {}
    self.ppState.Leaders = {}

    self.charDB.playerBlessings = {}
    self:ScanSpellbook()
end

function SP:PPCheckPaladinLeft()
    local rosterNames = {}
    if IsInRaid and IsInRaid() then
        local numRaid = (GetNumRaidMembers or GetNumGroupMembers)()
        for i = 1, numRaid do
            local name = GetRaidRosterInfo(i)
            if name then rosterNames[self:NormalizeName(name)] = true end
        end
    else
        local pn = UnitName("player")
        if pn then rosterNames[pn] = true end
        local numParty
        if GetNumPartyMembers then
            numParty = GetNumPartyMembers()
        else
            numParty = math.max(0, (GetNumGroupMembers() or 1) - 1)
        end
        for i = 1, numParty do
            local name = UnitName("party" .. i)
            if name then rosterNames[name] = true end
        end
    end

    local paladinLeft = false
    for _, name in ipairs(self.ppState.SyncList) do
        if not rosterNames[name] then
            paladinLeft = true
            break
        end
    end

    if paladinLeft then
        SafeTimerAfter(0.5, function()
            SP.ppState.Paladins = {}
            SP.ppState.SyncList = {}
            SP:ScanSpellbook()
            SP:PPUpdateLeaders()
            if SP:PPIsInGroup() then
                SP:PPSendSelf()
                SP:PPSendREQ()
            end
        end)
    end
end

function SP:PPOnRosterUpdate()
    if self.useFakeData then return end

    local inGroup = self:PPIsInGroup()

    if not wasInGroup and inGroup then
        wasInGroup = true
        self:PPOnGroupJoined()
    elseif wasInGroup and not inGroup then
        wasInGroup = false
        self:PPOnGroupLeft()
    elseif inGroup then
        self:PPUpdateLeaders()
        if rosterBucket then return end
        rosterBucket = true
        SafeTimerAfter(1.0, function()
            rosterBucket = nil
            SP:PPCheckPaladinLeft()
        end)
    end
end

function SP:PPOnSpellsChanged()
    if self.useFakeData then return end
    if self:PPIsInGroup() then
        self:PPSendSelf()
    end
end

-- ═══════════════════════════════════════════════════════
-- Init
-- ═══════════════════════════════════════════════════════

function SP:InitPP()
    if ppInitialized then return end
    ppInitialized = true

    RegisterPrefix()
    wasInGroup = self:PPIsInGroup()

    local ppFrame = CreateFrame("Frame")
    ppFrame:RegisterEvent("CHAT_MSG_ADDON")
    ppFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            SP:ParsePPMessage(...)
        end
    end)
end
