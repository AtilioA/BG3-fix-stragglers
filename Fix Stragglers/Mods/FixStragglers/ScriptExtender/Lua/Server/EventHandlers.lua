EHandlers = {}

function EHandlers.OnCastedSpell(params)
    if params.Spell == "Projectile_Jump" then
        JumpHandlerInstance:HandleJump(params)
    end
end

-- function EHandlers.OnHitpointsChanged(entity, percentage)
--     return JumpHandlerInstance:HandleHitpointsChanged(entity, percentage)
-- end

function EHandlers.OnTPYButtonPress(call, payload)
    JumpHandlerInstance:TeleportCompanions()
end

return EHandlers
