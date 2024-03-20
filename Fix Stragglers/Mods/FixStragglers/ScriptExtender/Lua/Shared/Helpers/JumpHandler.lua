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
  self.Jumper = nil
  self.HandlingJump = false
  self.FirstJumpTime = nil
  self.JumpCheckInterval = Config:getCfg().FEATURES.teleporting_method.jump_check_interval
  self.DistanceThreshold = Config:getCfg().FEATURES.teleporting_method.distance_threshold
  self.StopThresholdTime = Config:getCfg().FEATURES.teleporting_method.stop_threshold_time
  self.EnableFallDamageCheck = Config:getCfg().FEATURES.teleporting_method.enable_fall_damage_check
  self.ShouldTeleportCompanions = Config:getCfg().FEATURES.teleporting_method.enabled
  self.ShouldBoostJump = {
    enabled = Config:getCfg().FEATURES.jump_boosting_method.enabled,
    aggressive = Config:getCfg()
        .FEATURES.jump_boosting_method.use_aggressive_method
  }
end

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
  end

  Osi.TimerLaunch("FixStragglersJumpTimer", self.JumpCheckInterval * 1000)
end

--- TODO: Boosts the jump of the companions
function JumpHandler:BoostCompanionsJump()
  FSDebug(1, "JumpHandler:BoostCompanionsJump: Boosting companions jump...")

  local companions = Osi.DB_Players:Get(nil)
  for i, companion in pairs(companions) do
    _D(companion[1])
    if companion[1] ~= self.Jumper then
      local companionGuid = companion[1]
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
    Osi.TimerLaunch("FixStragglersJumpTimer", self.JumpCheckInterval * 1000)
  end
end

return JumpHandler
