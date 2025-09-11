---@param skipChecks boolean
---@return nil
local function FS_SendTeleportPartyToYou(skipChecks)
    if not Ext or not Ext.Net or not Ext.Json then
        FSError("Ext, Ext.Net or Ext.Json are not available.")
        return
    end

    if type(skipChecks) ~= "boolean" then
        skipChecks = MCM.Get("always_force_teleport")
    end

    Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = skipChecks }))
end

-- Register event button callbacks
if MCM.EventButton and MCM.EventButton.RegisterCallback then
    MCM.EventButton.RegisterCallback("btn_teleport_party_to_you", function()
        FS_SendTeleportPartyToYou(false)
    end)
    MCM.EventButton.RegisterCallback("btn_teleport_party_to_you_force", function()
        FS_SendTeleportPartyToYou(true)
    end)
end

-- Register keybinding callback
if MCM.Keybinding and MCM.Keybinding.SetCallback then
    MCM.Keybinding.SetCallback('key_teleport_party_to_you', function()
        FS_SendTeleportPartyToYou(nil)
    end)
end
