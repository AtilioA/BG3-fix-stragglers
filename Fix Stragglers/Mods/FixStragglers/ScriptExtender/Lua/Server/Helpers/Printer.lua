FSPrinter = VolitionCabinetPrinter:New { Prefix = "Fix Stragglers", ApplyColor = true, DebugLevel = MCMGet("debug_level") }

-- Update the Printer debug level when the setting is changed, since the value is only used during the object's creation
Ext.ModEvents.BG3MCM['MCM_Setting_Saved']:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end

    if payload.settingId == "debug_level" then
        FSDebug(0, "Setting debug level to " .. payload.value)
        FSPrinter.DebugLevel = payload.value
    end
end)

function FSPrint(debugLevel, ...)
    FSPrinter:SetFontColor(0, 255, 255)
    FSPrinter:Print(debugLevel, ...)
end

function FSTest(debugLevel, ...)
    FSPrinter:SetFontColor(100, 200, 150)
    FSPrinter:PrintTest(debugLevel, ...)
end

function FSDebug(debugLevel, ...)
    FSPrinter:SetFontColor(200, 200, 0)
    FSPrinter:PrintDebug(debugLevel, ...)
end

function FSWarn(debugLevel, ...)
    FSPrinter:SetFontColor(255, 100, 50)
    FSPrinter:PrintWarning(debugLevel, ...)
end

function FSDump(debugLevel, ...)
    FSPrinter:SetFontColor(190, 150, 225)
    FSPrinter:Dump(debugLevel, ...)
end

function FSDumpArray(debugLevel, ...)
    FSPrinter:DumpArray(debugLevel, ...)
end
