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
    local parsedPayload = Ext.Json.Parse(payload)
    local skipChecks = parsedPayload.skipChecks
    FSDebug(1, "Received request to teleport party to player.")
    JumpHandlerInstance:TeleportCompanions(skipChecks)
end

return EHandlers
