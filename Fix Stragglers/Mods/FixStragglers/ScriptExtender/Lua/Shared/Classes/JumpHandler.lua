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

function JumpHandler:Init()
    self.Jumper = nil
    self.HandlingJump = false
    self.FirstJumpTime = nil
    self.JumpCheckInterval = MCMGet("jump_check_interval")
    self.DistanceThreshold = MCMGet("distance_threshold")
    self.StopThresholdTime = MCMGet("stop_threshold_time")
    self.IgnoreIfJumperTookFallDamage = MCMGet("ignore_if_fall_damage")
    self.EnableApplyFallDamage = MCMGet("apply_fall_damage")
    self.ShouldTeleportCompanions = MCMGet("teleporting_method_enabled")
    self.ShouldBoostJump = {
        enabled = MCMGet("jump_boosting_method_enabled"),
        aggressive = MCMGet("use_aggressive_method")
    }

    -- Update the JumpHandler instance values when the MCM settings are changed
    Ext.RegisterNetListener("MCM_Saved_Setting", function(call, payload)
        local data = Ext.Json.Parse(payload)
        if not data or data.modGUID ~= ModuleUUID or not data.settingId then
            return
        end

        local settingUpdates = {
            ["jump_check_interval"] = function(value)
                FSDebug(0, "Setting jump check interval to " .. value)
                self.JumpCheckInterval = value
            end,
            ["distance_threshold"] = function(value)
                FSDebug(0, "Setting distance threshold to " .. value)
                self.DistanceThreshold = value
            end,
            ["stop_threshold_time"] = function(value)
                FSDebug(0, "Setting stop threshold time to " .. value)
                self.StopThresholdTime = value
            end,
            ["ignore_if_fall_damage"] = function(value)
                FSDebug(0, "Setting ignore if fall damage to " .. value)
                self.IgnoreIfJumperTookFallDamage = value
            end,
            ["apply_fall_damage"] = function(value)
                FSDebug(0, "Setting apply fall damage to " .. value)
                self.EnableApplyFallDamage = value
            end,
            ["teleporting_method_enabled"] = function(value)
                FSDebug(0, "Setting teleporting method enabled to " .. value)
                self.ShouldTeleportCompanions = value
            end,
            ["jump_boosting_method_enabled"] = function(value)
                FSDebug(0, "Setting jump boosting method enabled to " .. value)
                self.ShouldBoostJump.enabled = value
            end,
            ["use_aggressive_method"] = function(value)
                FSDebug(0, "Setting use aggressive jump boosting method to " .. value)
                self.ShouldBoostJump.aggressive = value
            end
        }

        if settingUpdates[data.settingId] then
            settingUpdates[data.settingId](data.value)
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

-- FIXME: only check linked characters
function JumpHandler:CheckDistance()
    local hostPosition = { Osi.GetPosition(self.Jumper) }

    local companions = Osi.DB_Players:Get(nil)
    for i, companion in ipairs(companions) do
        local companionGuid = VCHelpers.Format:Guid(companion[1])
        if companionGuid ~= self.Jumper then
            -- Retrieve companion's position
            local companionPosition = { Osi.GetPosition(companionGuid) }
            -- Calculate distance considering height
            local distance = VCHelpers.Grid:GetDistance(hostPosition, companionPosition, true)

            FSDebug(1,
                "JumpHandler:CheckDistance: Distance to " ..
                VCHelpers.Loca:GetDisplayName(companionGuid) .. " is " .. string.format("%.2fm", distance))

            if distance > self.DistanceThreshold then
                return true
            end
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

--- Handles the jump timer finished event
function JumpHandler:HandleJumpTimerFinished()
    if self.HandlingJump then
        FSDebug(1, "JumpHandler:HandleJumpTimerFinished: Jump timer finished...")

        -- Check if self.StopThresholdTime has passed since the first jump
        if (self:CheckStopThresholdTime()) then
            self.HandlingJump = false
            return
        end

        -- Check if the distance has been crossed
        if (self:CheckDistance()) then
            self.HandlingJump = false
            if self.ShouldTeleportCompanions then
                FSDebug(1, "JumpHandler:CheckDistance: Distance threshold crossed, teleporting party members...")
                VCHelpers.Teleporting:TeleportLinkedPartyMembersToCharacter(self.Jumper)
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

    local companions = Osi.DB_Players:Get(nil)
    for i, companion in pairs(companions) do
        if companion ~= self.Jumper then
            local companionGuid = companion
            local companionCharacter = Ext.Entity.Get(companionGuid)
        end
    end
end

--- Handles the jump event
---@param params VCCastedSpellParams
function JumpHandler:HandleJump(params)
    local Caster, CasterGuid, Spell, SpellType, SpellElement, StoryActionID = params.Caster, params.CasterGuid,
        params.Spell, params.SpellType, params.SpellElement, params.StoryActionID
    FSDebug(2, "JumpHandler:HandleJump called for character: " .. VCHelpers.Loca:GetDisplayName(CasterGuid))
    if not self.HandlingJump and Osi.IsInPartyWith(CasterGuid, GetHostCharacter()) == 1 then
        self.Jumper = CasterGuid
        FSDebug(1, "JumpHandler:HandleJump: Character is in party with host, handling...")
        self.HandlingJump = true

        if (self.ShouldBoostJump.enabled and self.ShouldBoostJump.aggressive) then
            JumpHandler:BoostCompanionsJump()
        end

        self.FirstJumpTime = Ext.Utils.MonotonicTime()
    Ext.Timer.WaitFor(self.JumpCheckInterval * 1000, function()
        JumpHandlerInstance:HandleJumpTimerFinished()
    end)
end

return JumpHandler
