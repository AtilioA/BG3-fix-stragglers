EHandlers = {}

function EHandlers.OnTimerFinished(timer)
  if timer == "FixStragglersTimer" then
    FSDebug(2, "Timer finished: " .. timer)
  end
end

function EHandlers.OnCastedSpell()
  if spell == "Projectile_Jump" then
    JumpHandlerInstance:HandleJump()
  end
end

return EHandlers
