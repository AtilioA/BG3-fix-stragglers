SubscribedEvents = {}

function SubscribedEvents.SubscribeToEvents()
    if Config:getCfg().GENERAL.enabled == true then
        FSDebug(2, "Subscribing to events with JSON config: " .. Ext.Json.Stringify(Config:getCfg(), { Beautify = true }))

        -- Event subscriptions
        Events.Osiris.CastedSpell:Subscribe(EHandlers.OnCastedSpell)

        Ext.Osiris.RegisterListener("TimerFinished", 1, "after", EHandlers.OnTimerFinished)

        Ext.Osiris.RegisterListener("MoveCapabilityChanged", 2, "after", function(character, isEnabled)
            _D(character)
            _D(isEnabled)
        end)

        Ext.Osiris.RegisterListener("HitpointsChanged", 2, "after", function(entity, percentage)
            FSDebug(0, "Entity hitpoints changed: " .. entity .. " percentage: " .. percentage)
        end)

        Ext.Osiris.RegisterListener("HitpointsChanged", 2, "after", EHandlers.OnHitpointsChanged)
        Ext.Osiris.RegisterListener("ApplyDamage", 4, "after", function(object, damage, damageType, source)
            FSDebug(0,
                "Object: " .. object .. " Damage: " .. damage .. " DamageType: " .. damageType .. " Source: " .. source)
        end)
    end
end

return SubscribedEvents
