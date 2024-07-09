---@class JumpHandler: MetaClass
---@field public HandlingJump boolean -- Flag to indicate if a jump is being handled
---@field public FirstJumpTime number -- Time of the first jump
---@field public JumpCheckInterval number -- Interval in seconds for checking distance after jumping
---@field public DistanceThreshold number -- Distance threshold for teleporting party members
---@field public StopThresholdTime number -- Time threshold to stop if more than X seconds passed without crossing the distance threshold
---@field public IgnoreIfJumperTookFallDamage boolean -- Option to enable checking fall damage from jumper
---@field public EnableApplyFallDamage boolean -- Option to enable applying fall damage to teleported characters
---@field public ShouldTeleportCompanions boolean -- Option to enable teleporting party members
---@field public ShouldBoostJump table -- Options for boosting jump
JumpHandler = _Class:Create("JumpHandler")

local PartyMemberSelector = PartyMemberSelector:New()

function JumpHandler:Init()
    self.Jumper = nil
    self.HandlingJump = false
    self.FirstJumpTime = nil

    -- Define the mapping of MCM settings to JumpHandler attributes
    local settingsMap = {
        jump_check_interval = "JumpCheckInterval",
        distance_threshold = "DistanceThreshold",
        stop_threshold_time = "StopThresholdTime",
        ignore_if_fall_damage = "IgnoreIfJumperTookFallDamage",
        apply_fall_damage = "EnableApplyFallDamage",
        teleporting_method_enabled = "ShouldTeleportCompanions",
        jump_boosting_method_enabled = { "ShouldBoostJump", "enabled" },
        use_aggressive_method = { "ShouldBoostJump", "aggressive" },
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

-- function JumpHandler:HandleHitpointsChanged(entity, percentage)
--     FSWarn(1, "JumpHandler:HandleHitpointsChanged: Entered function")
--     local entityGuid = VCHelpers.Format:Guid(entity)
--     if entityGuid == self.Jumper then
--         FSWarn(1, "JumpHandler:HandleHitpointsChanged: Jumper's hitpoints changed, checking for fall damage...")

--         if self.IgnoreIfJumperTookFallDamage then
--             FSWarn(2, "JumpHandler:HandleHitpointsChanged: Fall damage check enabled, getting linked characters")
--             local otherPartyMembers = VCHelpers.Character:GetCharactersLinkedWith(self.Jumper)
--             for i, companion in ipairs(otherPartyMembers) do
--                 -- FSWarn(3, "JumpHandler:HandleHitpointsChanged: Checking companion " .. companion[1])
--                 if companion ~= self.Jumper then
--                     local damageToJumper = Osi.GetHitpoints(self.Jumper) * percentage / 100
--                     FSWarn(2,
--                         "JumpHandler:HandleHitpointsChanged: Applying " ..
--                         damageToJumper .. " fall damage to " .. VCHelpers.Loca:GetDisplayName(companion))
--                     Osi.ApplyDamage(companion, damageToJumper, self.Jumper)
--                 end
--             end
--         end
--     end
--     FSWarn(1, "JumpHandler:HandleHitpointsChanged: Exiting function")
-- end

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
function JumpHandler:TeleportCompanions()
    local filteredParty = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)
    VCHelpers.Teleporting:TeleportCharactersToCharacter(self.Jumper, filteredParty)
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
            FSDebug(1,
                "JumpHandler:PartyCrossedDistanceThreshold: Distance threshold crossed, teleporting party members...")
                self:TeleportCompanions()
        end
        return
    end

    Ext.Timer.WaitFor(self.JumpCheckInterval * 1000, function()
        JumpHandlerInstance:HandleJumpTimerFinished()
    end)
end

--- TODO: Boosts the jump of the companions
function JumpHandler:BoostCompanionsJump()
    FSDebug(1, "JumpHandler:BoostCompanionsJump: Boosting companions jump...")

    local companions = PartyMemberSelector:FilterPartyMembersFor(self.Jumper)
    for i, companion in pairs(companions) do
        Osi.ApplyStatus(companion, "POTION_OF_STRENGTH_HILL_GIANT", 6, 100, "100")
        Osi.ApplyStatus(companion, "LONG_JUMP", 6, 100, "100")
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

    if self.HandlingJump then
        FSDebug(2, "JumpHandler:ShouldHandleJump: A jump is already being handled, not handling jump...")
        return false
    end

    if Osi.IsControlled(CasterGuid) ~= 1 then
        FSDebug(2, "JumpHandler:ShouldHandleJump: Character is not controlled, not handling jump...")
        return false
    end

    if Osi.IsInCombat(CasterGuid) ~= 0 then
        FSDebug(2, "JumpHandler:ShouldHandleJump: Character is in combat, not handling jump...")
        return false
    end

    if Osi.IsInPartyWith(CasterGuid, GetHostCharacter()) ~= 1 then
        FSDebug(2, "JumpHandler:ShouldHandleJump: Character is not in party with host, not handling jump...")
        return false
    end

    if VCHelpers.Character:IsCharacterInCamp(CasterGuid) then
        FSDebug(2, "JumpHandler:ShouldHandleJump: Character is in camp, not handling jump...")
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
    FSDebug(1, "JumpHandler:HandleJump: Handling jump...")
    self.HandlingJump = true

    if self.ShouldBoostJump.enabled and self.ShouldBoostJump.aggressive then
        JumpHandlerInstance:BoostCompanionsJump()
    end

    self.FirstJumpTime = Ext.Utils.MonotonicTime()
    Ext.Timer.WaitFor(self.JumpCheckInterval * 1000, function()
        JumpHandlerInstance:HandleJumpTimerFinished()
    end)
end
