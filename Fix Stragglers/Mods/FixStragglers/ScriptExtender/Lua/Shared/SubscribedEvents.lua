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

    FSPrint(2,
        "Subscribing to events with JSON config: " ..
        Ext.Json.Stringify(Mods.BG3MCM.MCMAPI:GetAllModSettings(ModuleUUID), { Beautify = true }))

    -- Event subscriptions
    Events.Osiris.CastedSpell:Subscribe(conditionalWrapper(EHandlers.OnCastedSpell))

    Ext.Osiris.RegisterListener("TimerFinished", 1, "after", conditionalWrapper(EHandlers.OnTimerFinished))

    Ext.Osiris.RegisterListener("HitpointsChanged", 2, "after", conditionalWrapper(EHandlers.OnHitpointsChanged))

    Ext.Osiris.RegisterListener("MoveCapabilityChanged", 2, "after", function(character, isEnabled)
        _D(character)
        _D(isEnabled)
    end)

    -- Ext.Osiris.RegisterListener("HitpointsChanged", 2, "after", function(entity, percentage)
    --     FSDebug(0, "Entity hitpoints changed: " .. entity .. " percentage: " .. percentage)
    -- end)
    Ext.Osiris.RegisterListener("ApplyDamage", 4, "after", function(object, damage, damageType, source)
        FSDebug(0,
            "Object: " .. object .. " Damage: " .. damage .. " DamageType: " .. damageType .. " Source: " .. source)
    end)
end

return SubscribedEvents
