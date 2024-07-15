---@class JumpHandler: MetaClass
---@field public Jumper string -- GUID of the jumper
---@field public HandlingJump boolean -- Flag to indicate if a jump is being handled
---@field public FirstJumpTime number -- Time of the first jump
---@field public JumpBoostStatuses string[] -- Statuses table to use for boosting jumps
---@field public JumpCheckInterval number -- Interval in seconds for checking distance after jumping
---@field public DistanceThreshold number -- Distance threshold for teleporting party members
---@field public StopThresholdTime number -- Time threshold to stop if more than X seconds passed without crossing the distance threshold
---@field public IgnoreIfJumperTookFallDamage boolean -- Option to enable checking fall damage from jumper
---@field public ShouldTeleportCompanions boolean -- Option to enable teleporting party members
---@field public ShouldTeleportDistantCompanionsNoJump boolean -- Option to enable teleporting distant party members regardless of jump
---@field public DistanceThresholdNoJump number - Distance threshold for teleporting party members regardless of jump
---@field public ShouldBoostJump table -- Options for boosting jump
JumpHandler = _Class:Create("JumpHandler")

local PartyMemberSelector = PartyMemberSelector:New()

function JumpHandler:Init()
    self.Jumper = nil
    self.HandlingJump = false
    self.FirstJumpTime = nil
    self.JumpBoostStatuses = { "FS_JUMPHELPER" }

    -- Define the mapping of MCM settings to JumpHandler attributes
    local settingsMap = {
        jump_check_interval = "JumpCheckInterval",
        distance_threshold = "DistanceThreshold",
        distance_threshold_no_jump = "DistanceThresholdNoJump",
        stop_threshold_time = "StopThresholdTime",
        ignore_if_fall_damage = "IgnoreIfJumperTookFallDamage",
        teleporting_method_enabled = "ShouldTeleportCompanions",
        teleporting_method_distance_enabled = "ShouldTeleportDistantCompanionsNoJump",
        jump_boosting_method_enabled = { "ShouldBoostJump", "enabled" },
    }

    -- Initialize attributes from MCM settings
    for mcmSetting, attribute in pairs(settingsMap) do
        if type(attribute) == "table" then
            if not self[attribute[1]] then self[attribute[1]] = {} end
            self[attribute[1]][attribute[2]] = MCMGet(mcmSetting)
        else
            self[attribute] = MCMGet(mcmSetting)
        end
    end

    -- Update the JumpHandler instance values when the MCM settings are changed
    Ext.RegisterNetListener("MCM_Saved_Setting", function(call, payload)
        local data = Ext.Json.Parse(payload)
        if not data or data.modGUID ~= ModuleUUID or not data.settingId then
            return
        end

        local attribute = settingsMap[data.settingId]
        if attribute then
            if type(attribute) == "table" then
                self[attribute[1]][attribute[2]] = data.value
            else
                self[attribute] = data.value
            end
            FSDebug(1, string.format("Changing JumpHandler '%s' value to '%s'", data.settingId, tostring(data.value)))
        end
    end)
end

function JumpHandler:CheckAndTeleportDistantPartyMembers()
    if not self.ShouldTeleportDistantCompanionsNoJump then return end
    FSDebug(2, "Checking distant party members...")

    local disjointPartySets = VCHelpers.Character:GetDisjointedLinkedCharacterSets()

    for _, set in ipairs(disjointPartySets) do
        local activeCharacter = self:GetActiveCharacterFromSet(set)
        if activeCharacter and self:PassesCoreHandlingChecks(activeCharacter) then
            self:TeleportDistantPartyMembers(activeCharacter)
        end
    end

    -- Schedule the next check
    Ext.Timer.WaitFor(math.random(500, 2000), function()
        JumpHandlerInstance:CheckAndTeleportDistantPartyMembers()
    end)
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
    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(activeCharacter)
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
            VCHelpers.Teleporting:TeleportCharactersToCharacter(activeCharacter, { companion })
        end
    end
end

function JumpHandler:PartyCrossedDistanceThreshold()
    local hostPosition = { Osi.GetPosition(self.Jumper) }
    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)

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

--- Teleports the companions to the jumper.
--- PMSelector will filter out according to user settings and game conditions
---@param skipChecks boolean Skip checks for teleporting party members
function JumpHandler:TeleportCompanionsToJumper(skipChecks)
    if not self.Jumper then
        -- Might not be a good assumption. For multiplayer, we should get the character from the user/peerID. However, I'll leave it like this for now.
        self.Jumper = Osi.GetHostCharacter()
    end

    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)
    if skipChecks then
        filteredParty = VCHelpers.Party:GetOtherPartyMembers(self.Jumper)
    end

    VCHelpers.Teleporting:TeleportCharactersToCharacter(self.Jumper, filteredParty)
end

--- Teleports the companions to the character
--- PMSelector will filter out according to user settings and game conditions
---@param character string GUID of the character to teleport to
function JumpHandler:TeleportCompanionsToCharacter(character, skipChecks)
    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(character)
    if skipChecks then
        filteredParty = VCHelpers.Party:GetOtherPartyMembers(character)
    end

    VCHelpers.Teleporting:TeleportCharactersToCharacter(character, filteredParty)
end

--- Handles the jump timer finished event
function JumpHandler:HandleJumpTimerFinished()
    if not self.HandlingJump then
        return
    end

    FSDebug(1, "JumpHandler:HandleJumpTimerFinished: Jump timer finished...")

    -- Check if self.StopThresholdTime has passed since the first jump
    if self:CheckStopThresholdTime() then
        self.HandlingJump = false
        return
    end

    -- Check if the distance has been crossed
    if self:PartyCrossedDistanceThreshold() then
        self.HandlingJump = false
        if self.ShouldTeleportCompanions then
            FSPrint(1,
                "JumpHandler:PartyCrossedDistanceThreshold: Distance threshold crossed, teleporting party members...")
            self:TeleportCompanionsToJumper()
        end
        return
    end

    Ext.Timer.WaitFor(self.JumpCheckInterval * 1000, function()
        JumpHandlerInstance:HandleJumpTimerFinished()
    end)
end

function JumpHandler:BoostCompanionsJump()
    FSPrint(1, "JumpHandler:BoostCompanionsJump: Boosting companions jump...")

    local companions = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)
    local statusesApplied = self:ApplyStatusesToCompanions(companions)

    -- Store the applied statuses to remove them later if the companion enters combat
    self.BoostedCompanions = statusesApplied
end

function JumpHandler:ApplyStatusesToCompanions(companions)
    local statusesApplied = {}

    for _, companion in pairs(companions) do
        statusesApplied[companion] = self:ApplyStatusesToCompanion(companion)
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
    self.HandlingJump = true

    if self.ShouldBoostJump.enabled then
        JumpHandlerInstance:BoostCompanionsJump()
    end

    self.FirstJumpTime = Ext.Utils.MonotonicTime()
    Ext.Timer.WaitFor(self.JumpCheckInterval * 1000, function()
        JumpHandlerInstance:HandleJumpTimerFinished()
    end)
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
