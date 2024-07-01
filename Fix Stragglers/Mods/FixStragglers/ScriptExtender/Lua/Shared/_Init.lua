setmetatable(Mods.FixStragglers, { __index = Mods.VolitionCabinet })

local deps = {
    VCModuleUUID = "f97b43be-7398-4ea5-8fe2-be7eb3d4b5ca",
    MCMModuleUUID = "755a8a72-407f-4f0d-9a33-274ac0f0b53d"
}

local function getModName(uuid)
    if not uuid then return "Unknown Mod" end

    local mod = Ext.Mod.GetMod(uuid)
    return mod and mod.Info and mod.Info.Name or "Unknown Mod"
end
local currentModName = getModName(ModuleUUID)

if not Ext.Mod.IsModLoaded(deps.VCModuleUUID) then
    Ext.Utils.PrintError(
        string.format("%s requires %s, which is missing. PLEASE MAKE SURE IT IS ENABLED IN YOUR MOD MANAGER.",
        currentModName, getModName(deps.VCModuleUUID)))
end

if not Ext.Mod.IsModLoaded(deps.MCMModuleUUID) then
    Ext.Utils.PrintError(
        string.format("%s requires %s, which is missing. PLEASE MAKE SURE IT IS ENABLED IN YOUR MOD MANAGER.",
        currentModName, getModName(deps.MCMModuleUUID)))
end

function MCMGet(settingID)
    return Mods.BG3MCM.MCMAPI:GetSettingValue(settingID, ModuleUUID)
end

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
