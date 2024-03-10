FSPrinter = VolitionCabinetPrinter:New { Prefix = "FS", ApplyColor = true, DebugLevel = Config:GetCurrentDebugLevel() }

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
