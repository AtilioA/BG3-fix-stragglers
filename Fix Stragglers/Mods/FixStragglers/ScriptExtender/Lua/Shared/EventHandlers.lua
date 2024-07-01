EHandlers = {}

function EHandlers.OnCastedSpell(params)
    if params.Spell == "Projectile_Jump" then
        JumpHandlerInstance:HandleJump(params)
    end
end

function EHandlers.OnHitpointsChanged(entity, percentage)
    return JumpHandlerInstance:HandleHitpointsChanged(entity, percentage)
end

Ext.Osiris.RegisterListener("AttackedBy", 7, "after",
    function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
        FSDebug(3,
            "AttackedBy: " ..
            defender ..
            " " ..
            attackerOwner ..
            " " .. attacker2 .. " " .. damageType .. " " .. damageAmount .. " " .. damageCause .. " " .. storyActionID)
    end)

return EHandlers
