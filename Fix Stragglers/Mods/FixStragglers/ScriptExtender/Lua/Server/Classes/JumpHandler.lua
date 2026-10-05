---@class JumpHandler: MetaClass
---@field public Jumper string -- GUID of the jumper
---@field public HandlingJump boolean -- Flag to indicate if a jump is being handled
---@field public FirstJumpTime number -- Time of the first jump
---@field public JumpBoostStatuses string[] -- Statuses table to use for boosting jumps
---@field public JumpCheckInterval number -- Interval in seconds for checking distance after jumping
---@field public DistanceThreshold number -- Distance threshold for teleporting party members
---@field public StopThresholdTime number -- Time threshold to stop if more than X seconds passed without crossing the distance threshold
---@field public IgnoreIfJumperTookFallDamage boolean -- Option to enable checking fall damage from jumper
---@field public DistanceThresholdNoJump number - Distance threshold for teleporting party members regardless of jump
---@field public ShouldBoostJump table -- Options for boosting jump
---@field public BoostedCompanions table<Guid, string[]>|nil
---@field public JumpCheckTimer TimerId|nil
---@field public JumpCheckGeneration integer
---@field public DistanceCheckTimer TimerId|nil
---@field public DistanceCheckGeneration integer
JumpHandler = _Class:Create("JumpHandler")

local PartyMemberSelector = PartyMemberSelector:New()

function JumpHandler:Init()
    self.Jumper = nil
    self.HandlingJump = false
    self.FirstJumpTime = nil
    self.JumpBoostStatuses = { "FS_JUMPHELPER" }
    self.JumpCheckGeneration = 0
    self.DistanceCheckGeneration = 0

    -- Define the mapping of MCM settings to JumpHandler attributes
    local settingsMap = {
        jump_check_interval = "JumpCheckInterval",
        distance_threshold = "DistanceThreshold",
        distance_threshold_no_jump = "DistanceThresholdNoJump",
        stop_threshold_time = "StopThresholdTime",
        ignore_if_fall_damage = "IgnoreIfJumperTookFallDamage",
        jump_boosting_method_enabled = { "ShouldBoostJump", "enabled" },
    }

    -- Initialize attributes from MCM settings
    for mcmSetting, attribute in pairs(settingsMap) do
        if type(attribute) == "table" then
            if not self[attribute[1]] then self[attribute[1]] = {} end
            self[attribute[1]][attribute[2]] = MCM.Get(mcmSetting)
        else
            self[attribute] = MCM.Get(mcmSetting)
        end
    end

    -- Update the JumpHandler instance values when the MCM settings are changed
    Ext.ModEvents.BG3MCM['MCM_Setting_Saved']:Subscribe(function(payload)
        if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
            return
        end

        local attribute = settingsMap[payload.settingId]
        if attribute then
            if type(attribute) == "table" then
                self[attribute[1]][attribute[2]] = payload.value
            else
                self[attribute] = payload.value
            end
            FSDebug(1,
                string.format("Changing JumpHandler '%s' value to '%s'", payload.settingId, tostring(payload.value)))
        end

        if payload.settingId == "mod_enabled" or payload.settingId == "teleporting_method_enabled" then
            if not MCM.Get("mod_enabled") or not MCM.Get("teleporting_method_enabled") then
                self:CancelJumpCheck()
            end
        end

        if payload.settingId == "mod_enabled" or payload.settingId == "teleporting_method_distance_enabled" then
            if MCM.Get("mod_enabled") and MCM.Get("teleporting_method_distance_enabled") then
                self:CheckAndTeleportDistantPartyMembers()
            else
                self:CancelDistanceCheck()
            end
        end
    end)

    PartyMemberSelector:Init()
end

--- Generates the settings table for VCHelpers
---@param forceBypass boolean|nil If true, bypasses all checks
---@return table
function JumpHandler:GetTeleportSettings(forceBypass)
    if forceBypass or MCM.Get("always_force_teleport") then
        return { IgnoreDialogue = false, IgnoreRestricted = false }
    end

    return {
        IgnoreDialogue = MCM.Get("ignore_on_dialogue"),
        IgnoreRestricted = MCM.Get("ignore_restricted_characters"),
    }
end

function JumpHandler:CheckAndTeleportDistantPartyMembers()
    if not MCM.Get("mod_enabled") or not MCM.Get("teleporting_method_distance_enabled") then
        self:CancelDistanceCheck()
        return
    end

    if self.DistanceCheckTimer then return end

    FSDebug(2, "Checking distant party members...")

    local disjointPartySets = VCHelpers.Character:GetDisjointedLinkedCharacterSets()

    for _, set in ipairs(disjointPartySets) do
        local activeCharacter = self:GetActiveCharacterFromSet(set)
        if activeCharacter and self:PassesCoreHandlingChecks(activeCharacter) then
            self:TeleportDistantPartyMembers(activeCharacter)
        end
    end

    -- Schedule the next check
    self.DistanceCheckGeneration = self.DistanceCheckGeneration + 1
    local generation = self.DistanceCheckGeneration
    self.DistanceCheckTimer = Ext.Timer.WaitFor(math.random(600, 2000), function()
        if generation ~= self.DistanceCheckGeneration then return end
        self.DistanceCheckTimer = nil
        if not MCM.Get("mod_enabled") or not MCM.Get("teleporting_method_distance_enabled") then return end

        xpcall(function()
            self:CheckAndTeleportDistantPartyMembers()
        end, function(err)
            FSWarn(1, "Error in CheckAndTeleportDistantPartyMembers: " .. err)
        end)
    end)
end

--- Cancels the pending distance-based check, if any.
---@return nil
function JumpHandler:CancelDistanceCheck()
    self.DistanceCheckGeneration = self.DistanceCheckGeneration + 1
    if self.DistanceCheckTimer then
        Ext.Timer.Cancel(self.DistanceCheckTimer)
        self.DistanceCheckTimer = nil
    end
end

function JumpHandler:GetActiveCharacterFromSet(set)
    for _, character in ipairs(set) do
        if Osi.IsControlled(character) == 1 then
            return character
        end
    end
    return nil
end

function JumpHandler:TeleportDistantPartyMembers(activeCharacter)
    if not self:IsValidTeleportSource(activeCharacter) then return end

    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(activeCharacter, true)
    for _, companion in ipairs(filteredParty) do
        local companionPosition = { Osi.GetPosition(companion) }
        local activePosition = { Osi.GetPosition(activeCharacter) }
        local distance = VCHelpers.Grid:GetDistance(activePosition, companionPosition, true)

        FSPrint(2,
            "JumpHandler:CheckAndTeleportDistantPartyMembers: Distance to " ..
            VCHelpers.Loca:GetDisplayName(companion) .. " is " .. string.format("%.2fm", distance))
        if distance > self.DistanceThresholdNoJump then
            FSPrint(1,
                "JumpHandler:CheckAndTeleportDistantPartyMembers: Teleporting " ..
                VCHelpers.Loca:GetDisplayName(companion) ..
                " to " .. VCHelpers.Loca:GetDisplayName(activeCharacter))
            self:TeleportCharactersToCharacter(activeCharacter, { companion }, self:GetTeleportSettings())
        end
    end
end

function JumpHandler:PartyCrossedDistanceThreshold()
    local hostPosition = { Osi.GetPosition(self.Jumper) }
    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(self.Jumper, true)

    for i, companion in ipairs(filteredParty) do
        local companionPosition = { Osi.GetPosition(companion) }
        local distance = VCHelpers.Grid:GetDistance(hostPosition, companionPosition, true)

        -- FSDebug(1, "JumpHandler:PartyCrossedDistanceThreshold: Distance to " ..
        -- VCHelpers.Loca:GetDisplayName(companion) .. " is " .. string.format("%.2fm", distance))

        if distance > self.DistanceThreshold then
            return true
        end
    end

    return false
end

--- Checks if the time threshold has been reached
function JumpHandler:CheckStopThresholdTime()
    local timePassed = Ext.Utils.MonotonicTime() - self.FirstJumpTime
    if timePassed > self.StopThresholdTime * 1000 then
        FSDebug(1, "JumpHandler:CheckStopThresholdTime: Time threshold reached, stopping jump handling...")
        return true
    end

    return false
end

--- Checks if a character is currently in a valid position to be a teleport source/target
---@param character string
---@return boolean
function JumpHandler:IsValidTeleportSource(character)
    if not MCM.Get("avoid_dangerous_terrain") then return true end
    if not character then return false end

    local pos = { Osi.GetPosition(character) }
    local hasPosition = pos ~= nil and pos[1] ~= nil and pos[2] ~= nil and pos[3] ~= nil
    if not hasPosition then return false end

    local validPos = { Osi.FindValidPosition(pos[1], pos[2], pos[3], 0, character, 1) }
    local hasValidPos = validPos ~= nil and validPos[1] ~= nil and validPos[2] ~= nil and validPos[3] ~= nil

    if not hasValidPos then return false end

    local distanceToValid = VCHelpers.Grid:GetDistance(pos, validPos, true)

    if distanceToValid > 1 then
        FSDebug(1, "JumpHandler:IsValidTeleportSource: Bad position for " .. VCHelpers.Loca:GetDisplayName(character))
        return false
    end

    return true
end

--- Collects party members, summons, and linked followers, excluding the target.
---@param character Guid
---@return Guid[]
function JumpHandler:GetForceTeleportMembers(character)
    character = VCHelpers.Format:Guid(character)
    local members = {}
    local included = { [character] = true }
    ---@param member Guid
    ---@return nil
    local function addMember(member)
        member = VCHelpers.Format:Guid(member)
        if not included[member] then
            included[member] = true
            table.insert(members, member)
        end
    end

    -- Force teleport helps the whole party, regardless of grouping or settings.
    for _, member in ipairs(VCHelpers.Party:GetOtherPartyMembers(character)) do
        addMember(member)
    end

    -- DB_Players omits summons. Force teleport brings them all, even summons that are not linked to the party.
    for _, row in ipairs(Osi.DB_PlayerSummons:Get(nil)) do
        addMember(row[1])
    end

    -- Viewparty-linked characters cover followers that DB_Players and DB_PlayerSummons omit.
    for _, member in ipairs(VCHelpers.Character:GetCharactersLinkedWith(character)) do
        addMember(member)
    end

    return members
end

--- Teleports the given characters to the target without implicit summon movement.
---@param targetCharacter Guid
---@param characters Guid[]
---@param settings table|nil
---@return nil
function JumpHandler:TeleportCharactersToCharacter(targetCharacter, characters, settings)
    if not targetCharacter or #characters == 0 then return end

    local canTeleport, reason = VCHelpers.Teleporting:CanCharacterTeleport(targetCharacter, settings)
    if not canTeleport then
        FSDebug(1,
            "Skipping teleport to " .. VCHelpers.Loca:GetDisplayName(targetCharacter) .. ": " .. (reason or "Unknown reason"))
        return
    end

    local x, y, z = Osi.GetPosition(targetCharacter)
    if not x or not y or not z then
        FSDebug(1, "Skipping teleport to " .. VCHelpers.Loca:GetDisplayName(targetCharacter) .. ": position not found.")
        return
    end

    for _, member in ipairs(characters) do
        local memberCanTeleport, memberReason = VCHelpers.Teleporting:CanCharacterTeleport(member, settings)
        if memberCanTeleport then
            -- Disable implicit following so only the selected characters move.
            Osi.TeleportToPosition(member, x, y, z, "FSTeleportToPosition_" .. member, 0, 0, 0, 0, 1)
        else
            FSDebug(1,
                "Skipping teleport for " ..
                VCHelpers.Loca:GetDisplayName(member) .. ": " .. (memberReason or "Unknown reason"))
        end
    end
end

--- Teleports the companions to the jumper.
--- PMSelector filters automatic teleports; force teleport includes all party members and summons.
---@param skipChecks boolean Skip checks for teleporting party members
function JumpHandler:TeleportCompanionsToJumper(skipChecks)
    if not self.Jumper then
        -- Might not be a good assumption. For multiplayer, we should get the character from the user/peerID. However, I'll leave it like this for now.
        self.Jumper = Osi.GetHostCharacter()
    end

    if not self:IsValidTeleportSource(self.Jumper) then return end

    local filteredParty
    if skipChecks then
        filteredParty = self:GetForceTeleportMembers(self.Jumper)
    else
        filteredParty = PartyMemberSelector:FilterPartyMembersFor(self.Jumper, true)
    end

    self:TeleportCharactersToCharacter(self.Jumper, filteredParty, self:GetTeleportSettings(skipChecks))
end

--- Teleports companions to the character, including party summons in force mode.
---@param character Guid GUID of the character to teleport to
---@param skipChecks boolean|nil
---@return nil
function JumpHandler:TeleportCompanionsToCharacter(character, skipChecks)
    if not self:IsValidTeleportSource(character) then
        FSDebug(2, "JumpHandler:TeleportCompanionsToCharacter: Invalid teleport source: " .. character)
        return
    end

    local filteredParty
    if skipChecks then
        filteredParty = self:GetForceTeleportMembers(character)
    else
        filteredParty = PartyMemberSelector:FilterPartyMembersFor(character)
    end

    self:TeleportCharactersToCharacter(character, filteredParty, self:GetTeleportSettings(skipChecks))
end

--- Handles the jump timer finished event
function JumpHandler:HandleJumpTimerFinished()
    if not self.HandlingJump then
        return
    end

    if not MCM.Get("mod_enabled") or not MCM.Get("teleporting_method_enabled") then
        self:CancelJumpCheck()
        return
    end

    FSDebug(1, "JumpHandler:HandleJumpTimerFinished: Jump timer finished...")

    -- Check if self.StopThresholdTime has passed since the first jump
    if self:CheckStopThresholdTime() then
        self:CancelJumpCheck()
        return
    end

    -- Camp, combat, and control changes stop polling even when the terrain is unsafe.
    if not self:PassesCoreHandlingChecks(self.Jumper) then
        self:CancelJumpCheck()
        return
    end

    if not self:IsValidTeleportSource(self.Jumper) then
        FSDebug(2, "JumpHandler:HandleJumpTimerFinished: Jumper in invalid position; delaying re-check...")
        self:ScheduleJumpCheck()
        return
    end

    -- Check if the distance has been crossed
    if self:PartyCrossedDistanceThreshold() then
        self.HandlingJump = false
        FSPrint(1,
            "JumpHandler:PartyCrossedDistanceThreshold: Distance threshold crossed, teleporting party members...")
        self:TeleportCompanionsToJumper()
        return
    end

    self:ScheduleJumpCheck()
end

--- Cancels the pending jump check and stops handling the current jump.
---@return nil
function JumpHandler:CancelJumpCheck()
    self.JumpCheckGeneration = self.JumpCheckGeneration + 1
    if self.JumpCheckTimer then
        Ext.Timer.Cancel(self.JumpCheckTimer)
        self.JumpCheckTimer = nil
    end
    self.HandlingJump = false
end

--- Schedules a jump check that ignores callbacks invalidated by a setting change.
---@return nil
function JumpHandler:ScheduleJumpCheck()
    self.JumpCheckGeneration = self.JumpCheckGeneration + 1
    local generation = self.JumpCheckGeneration
    self.JumpCheckTimer = Ext.Timer.WaitFor(self.JumpCheckInterval * 1000, function()
        if generation ~= self.JumpCheckGeneration then return end
        self.JumpCheckTimer = nil
        self:HandleJumpTimerFinished()
    end)
end

function JumpHandler:BoostCompanionsJump()
    FSPrint(1, "JumpHandler:BoostCompanionsJump: Boosting companions jump...")

    local companions = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)
    local statusesApplied = self:ApplyStatusesToCompanions(companions)

    -- Store the applied statuses to remove them later if the companion enters combat
    self.BoostedCompanions = statusesApplied
end

--- Applies boosts and retains active boost records for combat cleanup.
---@param companions Guid[]
---@return table<Guid, string[]>
function JumpHandler:ApplyStatusesToCompanions(companions)
    local statusesApplied = self.BoostedCompanions or {}

    for _, companion in pairs(companions) do
        -- A repeat jump can leave an existing boost active; keep it tracked for cleanup.
        local applied = self:ApplyStatusesToCompanion(companion)
        statusesApplied[companion] = statusesApplied[companion] or {}
        for _, status in ipairs(applied) do
            table.insert(statusesApplied[companion], status)
        end
    end

    return statusesApplied
end

function JumpHandler:ApplyStatusesToCompanion(companion)
    local appliedStatuses = {}

    for _, status in ipairs(self.JumpBoostStatuses) do
        if self:ShouldApplyJumpBoostingStatus(companion, status) then
            Osi.ApplyStatus(companion, status, 12, 100, companion)
            table.insert(appliedStatuses, status)
        end
    end

    return appliedStatuses
end

function JumpHandler:ShouldApplyJumpBoostingStatus(companion, status)
    return Osi.HasActiveStatus(companion, status) == 0 and Osi.IsInCombat(companion) == 0
end

function JumpHandler:RemoveJumpBoostingStatus(status, companion)
    if not JumpHandlerInstance.BoostedCompanions then return end

    local companionUUID = VCHelpers.Format:Guid(companion)
    if not JumpHandlerInstance.BoostedCompanions[companionUUID] then return end

    for i, appliedStatus in ipairs(JumpHandlerInstance.BoostedCompanions[companionUUID]) do
        if appliedStatus == status then
            table.remove(JumpHandlerInstance.BoostedCompanions[companionUUID], i)
            break
        end
    end
end

function JumpHandler:RemoveAllJumpBoostingStatusesFromCompanion(companion)
    local companionUUID = VCHelpers.Format:Guid(companion)
    if JumpHandlerInstance.BoostedCompanions and JumpHandlerInstance.BoostedCompanions[companionUUID] then
        for _, status in ipairs(JumpHandlerInstance.BoostedCompanions[companionUUID]) do
            Osi.RemoveStatus(companionUUID, status)
        end
        JumpHandlerInstance.BoostedCompanions[companionUUID] = nil
    end
end

--- Checks if the jump event should be handled
---@param params VCCastedSpellParams
function JumpHandler:ShouldHandleJump(params)
    local CasterGuid = params.CasterGuid

    if not CasterGuid then
        FSDebug(2, "JumpHandler:ShouldHandleJump: Character is not valid, not handling jump...")
        return false
    end

    if not self:PassesCoreHandlingChecks(CasterGuid) then
        return false
    end

    if not self:PassesJumpRelatedChecks(CasterGuid) then
        return false
    end

    return true
end

--- Miscellaneous checks related to the jump event
---@param teleportCausee string
function JumpHandler:PassesCoreHandlingChecks(teleportCausee)
    if Osi.IsControlled(teleportCausee) ~= 1 then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is not controlled, not passing core check...")
        return false
    end

    if Osi.IsSummon(teleportCausee) == 1 then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is a summon, not passing core check...")
        return false
    end

    if Osi.IsDead(teleportCausee) == 1 then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is dead, not passing core check...")
        return false
    end

    if Osi.GetHitpoints(teleportCausee) <= 0 then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character has 0 hitpoints, not passing core check...")
        return false
    end

    if Osi.IsInCombat(teleportCausee) ~= 0 then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is in combat, not passing core check...")
        return false
    end

    if Osi.IsInPartyWith(teleportCausee, Osi.GetHostCharacter()) ~= 1 then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is not in party with host, not passing core check...")
        return false
    end

    if VCHelpers.Character:IsCharacterInCamp(teleportCausee) then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is in camp, not passing core check...")
        return false
    end

    if PartyMemberSelector.IgnoreOnDialogue and PartyMemberSelector:IsInDialogue(teleportCausee) then
        FSDebug(2, "JumpHandler:PassesCoreHandlingChecks: Character is in dialogue, not passing core check...")
        return false
    end

    if PartyMemberSelector.IgnoreRestrictedCharacters and PartyMemberSelector:IsRestricted(teleportCausee) then
        FSDebug(2,
            "JumpHandler:PassesCoreHandlingChecks: Character is in a restricted area/state, not passing core check...")
        return false
    end

    return true
end

--- Checks specifically related to the jump event
---@param CasterGuid string
function JumpHandler:PassesJumpRelatedChecks(CasterGuid)
    if self.HandlingJump then
        FSDebug(2, "JumpHandler:PassesJumpRelatedChecks: A jump is already being handled, not handling jump...")
        return false
    end

    if self.IgnoreIfJumperTookFallDamage and self:ProxyCheckFallDamage(CasterGuid) then
        FSDebug(2, "JumpHandler:JumpRelatedChecks: Character potentially took fall damage, not handling jump...")
        return false
    end

    return true
end

--- Handles the jump event
---@param params VCCastedSpellParams
function JumpHandler:HandleJump(params)
    local Caster, CasterGuid, Spell, SpellType, SpellElement, StoryActionID = params.Caster, params.CasterGuid,
        params.Spell, params.SpellType, params.SpellElement, params.StoryActionID

    FSDebug(2, "JumpHandler:HandleJump called for character: " .. VCHelpers.Loca:GetDisplayName(CasterGuid))

    if not self:ShouldHandleJump(params) then
        return
    end

    self.Jumper = CasterGuid
    FSPrint(2, "JumpHandler:HandleJump: Handling jump...")
    if self.ShouldBoostJump.enabled then
        self:BoostCompanionsJump()
    end

    if not MCM.Get("teleporting_method_enabled") then return end

    self.HandlingJump = true
    self.FirstJumpTime = Ext.Utils.MonotonicTime()
    self:ScheduleJumpCheck()
end

-- Since checking for fall damage is tricky given the current API, we'll use an approximation
-- This will check if the jumper is considerably lower than other party members at the time of landing the jump
-- This does not account for the actual fall damage taken by the jumper, and will fail to consider certain scenarios
-- However, this is a good approximation and it is not anything serious or game-breaking in any case.
---@param jumper string GUID of the jumper
function JumpHandler:ProxyCheckFallDamage(jumper)
    local fallThreshold = 3
    -- Check if character is considerably lower than other party members
    -- For checks, use 3 meters as the threshold (y value)
    local jumperPos = { Osi.GetPosition(jumper) }
    if not jumperPos then
        return false
    end
    local jumperPosition = {
        x = jumperPos[1],
        y = jumperPos[2],
        z = jumperPos[3]
    }

    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(jumper)
    -- Iterate all party members and check if they are considerably higher than the jumper. If any of them are, return true
    for i, companion in ipairs(filteredParty) do
        local companionPos = { Osi.GetPosition(companion) }
        if not companionPos then
            return false
        end
        local companionPosition = {
            x = companionPos[1],
            y = companionPos[2],
            z = companionPos[3]
        }

        if companionPosition.y > jumperPosition.y + fallThreshold then
            return true
        end
    end

    return false
end

-- function JumpHandler:HandleFallDamage(jumper, damageAmount)
--     local function applyFallDamageToCompanions(filteredParty)
--         for i, companion in ipairs(filteredParty) do
--             -- Check for feather fall ("FEATHER_FALL")
--             if Osi.HasActiveStatus(companion, "FEATHER_FALL") == 0 and Osi.HasActiveStatus(companion, "LEVITATE") == 0 then
--                 FSDebug(2,
--                     "JumpHandler:HandleFallDamage: Applying fall damage to " .. VCHelpers.Loca:GetDisplayName(companion))
--                 if companion ~= self.Jumper then
--                     Osi.ApplyDamage(companion, damageAmount, "FallDamage", self.Jumper)
--                 end
--             end
--         end
--     end

--     -- The jumper has taken fall damage
--     if self.IgnoreIfJumperTookFallDamage then
--         -- Don't teleport if the jumper took fall damage
--         FSDebug(1, "JumpHandler:HandleFallDamage: Jumper took fall damage, stopping jump handling...")
--         self.HandlingJump = false
--         return
--     elseif self.EnableApplyFallDamage then
--         FSDebug(1, "JumpHandler:HandleFallDamage: Applying fall damage to companions...")
--         -- Apply fall damage to teleported characters
--         -- NOTE: this is not actually calculating the fall damage, but is a good enough approximation
--         local filteredParty = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)
--         applyFallDamageToCompanions(filteredParty)
--     end
-- end
