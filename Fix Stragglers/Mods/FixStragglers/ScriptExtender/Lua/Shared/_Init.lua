setmetatable(Mods.FixStragglers, { __index = Mods.VolitionCabinet })

---Ext.Require files at the path
---@param path string
---@param files string[]
function RequireFiles(path, files)
    for _, file in pairs(files) do
        Ext.Require(string.format("%s%s.lua", path, file))
    end
end

RequireFiles("Shared/", {
    "MetaClass",
    "Helpers/_Init",
    "Classes/_Init",
    "SubscribedEvents",
    "EventHandlers",
})

local MODVERSION = Ext.Mod.GetMod(ModuleUUID).Info.ModVersion

if MODVERSION == nil then
    FSWarn(0, "loaded (version unknown)")
else
    -- Remove the last element (build/revision number) from the MODVERSION table
    table.remove(MODVERSION)

    local versionNumber = table.concat(MODVERSION, ".")
    FSPrint(0, "Fix Stragglers version " .. versionNumber .. " loaded")
end

JumpHandlerInstance = JumpHandler:New()

SubscribedEvents.SubscribeToEvents()
