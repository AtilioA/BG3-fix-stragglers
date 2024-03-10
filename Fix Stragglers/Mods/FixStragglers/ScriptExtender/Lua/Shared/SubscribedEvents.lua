SubscribedEvents = {}

function SubscribedEvents.SubscribeToEvents()
  if Config:getCfg().GENERAL.enabled == true then
    FSDebug(2, "Subscribing to events with JSON config: " .. Ext.Json.Stringify(Config:getCfg(), { Beautify = true }))

    -- Event subscriptions
    Events.Osiris.CastedSpell.Subscribe(EHandlers.OnCastedSpell)

    Ext.Osiris.RegisterListener("TimerFinished", 1, "after", EHandlers.OnTimerFinished)
  end
end

return SubscribedEvents
