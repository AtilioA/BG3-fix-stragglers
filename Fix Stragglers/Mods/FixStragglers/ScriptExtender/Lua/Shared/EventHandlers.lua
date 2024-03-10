EHandlers = {}

function EHandlers.OnTimerFinished(timer)
  if timer == "FixStragglersJumpTimer" then
    JumpHandlerInstance:HandleJumpTimerFinished()
  end
end

function EHandlers.OnCastedSpell(params)
  if params.Spell == "Projectile_Jump" then
    JumpHandlerInstance:HandleJump(params)
  end
end

return EHandlers
