FSPrinter = VolitionCabinetPrinter:New { Prefix = "Fix Stragglers", ApplyColor = true, DebugLevel = MCMGet("debug_level") }

-- Update the Printer debug level when the setting is changed, since the value is only used during the object's creation
Ext.RegisterNetListener("MCM_Saved_Setting", function(call, payload)
    local data = Ext.Json.Parse(payload)
    if not data or data.modGUID ~= ModuleUUID or not data.settingId then
        return
    end

    if data.settingId == "debug_level" then
        FSDebug(0, "Setting debug level to " .. data.value)
        FSPrinter.DebugLevel = data.value
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
