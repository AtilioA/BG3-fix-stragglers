Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "General", function(tabHeader)
    local TPYButton = tabHeader:AddButton("Teleport party to you NOW")
    local TPYDescription = tabHeader:AddText("Teleport party members to your location according to your settings.")
    TPYButton.OnClick = function()
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", "")
    end
end)

local function handleKeyInput(e)
    if KeybindingManager:IsKeybindingPressed(e, MCMGet("key_teleport_party_to_you")) then
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", "")
    end
end

Ext.Events.KeyInput:Subscribe(handleKeyInput)
