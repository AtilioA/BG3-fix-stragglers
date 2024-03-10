---@class JumpHandler: MetaClass
---@field public HandlingJump boolean -- Flag to indicate if a jump is being handled
---@field public FirstJumpTime number -- Time of the first jump
---@field public JumpCheckInterval number -- Interval in seconds for checking distance after jumping
---@field public DistanceThreshold number -- Distance threshold for teleporting party members
---@field public StopThresholdTime number -- Time threshold to stop if more than X seconds passed without crossing the distance threshold
---@field public EnableFallDamageCheck boolean -- Option to enable fall damage from teleported characters
---@field public ShouldTeleportCompanions boolean -- Option to enable teleporting party members
---@field public ShouldBoostJump table -- Options for boosting jump
JumpHandler = _Class:Create("JumpHandler")

function JumpHandler:Init()
  self.HandlingJump = false
  self.FirstJumpTime = nil
  self.JumpCheckInterval = Config:getCfg().FEATURES.teleporting_method.jump_check_interval
  self.DistanceThreshold = Config:getCfg().FEATURES.teleporting_method.distance_threshold
  self.StopThresholdTime = Config:getCfg().FEATURES.teleporting_method.stop_threshold_time
  self.EnableFallDamageCheck = Config:getCfg().FEATURES.teleporting_method.enable_fall_damage_check
  self.ShouldTeleportCompanions = Config:getCfg().FEATURES.teleporting_method.enabled
  self.ShouldBoostJump = {enabled = Config:getCfg().FEATURES.jump_boosting_method.enabled, aggressive = Config:getCfg().FEATURES.jump_boosting_method.use_aggressive_method}
end

function JumpHandler:CheckStopThresholdTime(currentTime)
  local timePassed = currentTime - self.FirstJumpTime
  if timePassed > self.StopThresholdTime * 1000 then
    FSDebug(1, "JumpHandler:CheckStopThresholdTime: Stopping jump handling, time threshold reached...")
    return true
  end

  return false
end

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
        Teleporting:TeleportPartyMembers()
      end
      return
    end
  end
end

--- Handles the jump event
---@param params VCCastedSpellParams
function JumpHandler:HandleJump(params)
  local Caster, CasterGuid, Spell, SpellType, SpellElement, StoryActionID = params.Caster, params.CasterGuid, params.Spell, params.SpellType, params.SpellElement, params.StoryActionID
  FSDebug(2, "JumpHandler:HandleJump called for character: " .. Caster.ServerCharacter.Template.Name)
  if not self.HandlingJump and Osi.IsInPartyWith(Caster, GetHostCharacter()) == 1 then
    FSDebug(1, "JumpHandler:HandleJump: Character is in party with host, handling...")
    self.HandlingJump = true

    if (self.ShouldBoostJump.enabled and self.ShouldBoostJump.aggressive) then
      JumpHandler:BoostCompanionsJump()
    end

    self.FirstJumpTime = Ext.Utils.MonotonicTime()
    Osi.TimerLaunch("JumpTimer", self.JumpCheckInterval * 1000)
  end

end

return JumpHandler
