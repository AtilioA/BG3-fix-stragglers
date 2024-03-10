---@class JumpHandler: MetaClass
---@field public JumpCheckInterval number -- Interval in seconds for checking distance after jumping
---@field public DistanceThreshold number -- Distance threshold for teleporting party members
---@field public StopThresholdTime number -- Time threshold to stop if more than X seconds passed without crossing the distance threshold
---@field public EnableFallDamageCheck boolean -- Option to enable fall damage from teleported characters
JumpHandler = _Class:Create("JumpHandler")

function JumpHandler:Init()
  self.JumpCheckInterval = Config:getCfg().FEATURES.teleporting_method.jump_check_interval
  self.DistanceThreshold = Config:getCfg().FEATURES.teleporting_method.distance_threshold
  self.StopThresholdTime = Config:getCfg().FEATURES.teleporting_method.stop_threshold_time
  self.EnableFallDamageCheck = Config:getCfg().FEATURES.teleporting_method.enable_fall_damage_check
end

function JumpHandler:HandleJump(character)
  -- implementation for handling the jump dynamics
end

return JumpHandler
