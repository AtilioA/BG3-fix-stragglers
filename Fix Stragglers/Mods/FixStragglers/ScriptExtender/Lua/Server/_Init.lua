RequireFiles("Server/", {
    "MetaClass",
    "Helpers/_Init",
    "Classes/_Init",
    "SubscribedEvents",
    "EventHandlers",
})

local MODVERSION = Ext.Mod.GetMod(ModuleUUID).Info.ModVersion
if MODVERSION == nil then
    FSWarn(0, "Volitio's Fix Stragglers loaded (version unknown)")
else
    -- Remove the last element (build/revision number) from the MODVERSION table
    table.remove(MODVERSION)

    local versionNumber = table.concat(MODVERSION, ".")
    FSPrint(0, "Volitio's Fix Stragglers version " .. versionNumber .. " loaded")
end

JumpHandlerInstance = JumpHandler:New()

SubscribedEvents.SubscribeToEvents()
