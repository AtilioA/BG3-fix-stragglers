local VCModuleUUID = "f97b43be-7398-4ea5-8fe2-be7eb3d4b5ca"
if (Ext.Mod.IsModLoaded(VCModuleUUID)) then
  FSPrint(2, "Volition Cabinet has been loaded successfully")
else
  FSWarn(0, "Volition Cabinet has not been loaded. Please make sure it is enabled in your mod manager.")
end
