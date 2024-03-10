EHandlers = {}

function EHandlers.OnTimerFinished(timer)
  if timer == "FixStragglersTimer" then
    FSDebug(2, "Timer finished: " .. timer)
  end
end

function EHandlers.OnCastedSpell(params)
  if params.Spell == "Projectile_Jump" then
    JumpHandlerInstance:HandleJump(params)
  end
end

return EHandlers
