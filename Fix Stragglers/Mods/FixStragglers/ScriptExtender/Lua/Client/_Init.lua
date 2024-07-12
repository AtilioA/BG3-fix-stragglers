Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "General", function(tabHeader)
    local TPYButton = tabHeader:AddButton("Teleport party to you NOW")
    local TPYDescription = tabHeader:AddText("Teleport party members to the location of your character according to your settings.")
    TPYButton.OnClick = function()
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = false }))
    end

    local TPYButtonForce = tabHeader:AddButton("Teleport party to you NOW (Force)")
    local TPYForceDescription = tabHeader:AddText(
        "Teleport party members to the location of your character regardless of your settings (combat, etc).")
    TPYButtonForce.OnClick = function()
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = true }))
    end
end)

Ext.Events.KeyInput:Subscribe(function(e)
    if KeybindingManager:IsKeybindingPressed(e, MCMGet("key_teleport_party_to_you")) then
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = false }))
    end
end)
