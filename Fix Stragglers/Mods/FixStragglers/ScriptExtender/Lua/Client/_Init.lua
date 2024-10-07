Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "General", function(tabHeader)
    local TPYButton = tabHeader:AddButton(Ext.Loca.GetTranslatedString("hf3a29641e4e14792b1329ecdca098f49ga4c"))
    local TPYDescription = tabHeader:AddText(
        Ext.Loca.GetTranslatedString("hf8e993f425d44a5d97ebdd1efaebb37c6e57"))
    TPYButton.OnClick = function()
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = false }))
    end

    local TPYButtonForce = tabHeader:AddButton(Ext.Loca.GetTranslatedString("h6f2ca1b3df5748cc975fed9f10db594702bb"))
    local TPYForceDescription = tabHeader:AddText(
        Ext.Loca.GetTranslatedString("h4d1b593c4aa64583b70c99dd82383edaa23e"))
    TPYButtonForce.OnClick = function()
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = true }))
    end
end)

Ext.Events.KeyInput:Subscribe(function(e)
    if KeybindingManager:IsKeybindingPressed(e, MCM.Get("key_teleport_party_to_you")) then
        Ext.Net.PostMessageToServer("FS_TeleportPartyToYou", Ext.Json.Stringify({ skipChecks = false }))
    end
end)
