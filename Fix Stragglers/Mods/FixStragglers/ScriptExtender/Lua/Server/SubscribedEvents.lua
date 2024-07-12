SubscribedEvents = {}

function SubscribedEvents:SubscribeToEvents()
    local function conditionalWrapper(handler)
        return function(...)
            if MCMGet("mod_enabled") then
                handler(...)
            else
                FSPrint(1, "Event handling is disabled.")
            end
        end
    end

    FSDebug(2,
        "Subscribing to events with JSON config: " ..
        Ext.Json.Stringify(Mods.BG3MCM.MCMAPI:GetAllModSettings(ModuleUUID), { Beautify = true }))

    -- Event subscriptions
    Events.Osiris.CastedSpell:Subscribe(conditionalWrapper(EHandlers.OnCastedSpell))

    Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, causee, applyStoryActionID)
        JumpHandlerInstance:RemoveJumpBoostingStatus(status, object)
    end)

    Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(object, combatGuid)
        JumpHandlerInstance:RemoveAllJumpBoostingStatusesFromCompanion(object)
    end)

    Ext.Osiris.RegisterListener("GainedControl", 1, "after", function(target)
        JumpHandlerInstance:RemoveAllJumpBoostingStatusesFromCompanion(target)
    end)

    Ext.RegisterNetListener("FS_TeleportPartyToYou", EHandlers.OnTPYButtonPress)

    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
        -- Timer to check for distant party members, regardless of jump
        JumpHandlerInstance:CheckAndTeleportDistantPartyMembers()
    end)

    Ext.Events.ResetCompleted:Subscribe(conditionalWrapper(function()
        JumpHandlerInstance:CheckAndTeleportDistantPartyMembers()
    end))

    -- Ext.Osiris.RegisterListener("MoveCapabilityChanged", 2, "after", function(character, isEnabled)
    -- end)
    -- Ext.Osiris.RegisterListener("ApplyDamage", 4, "after", function(object, damage, damageType, source)
    --     FSDebug(0,
    --         "Object: " .. object .. " Damage: " .. damage .. " DamageType: " .. damageType .. " Source: " .. source)
    -- end)
end

return SubscribedEvents
