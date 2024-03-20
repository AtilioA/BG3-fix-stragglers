Config = VCHelpers.Config:New({
  folderName = "FixStragglers",
  configFilePath = "fix_stragglers_config.json",
  defaultConfig = {
    GENERAL = {
      enabled = true, -- Toggle the mod on/off
    },
    FEATURES = {
      enable_str_check = false, -- If enabled, only the party members with STR equal or higher than the jumper will be handled

      teleporting_method = {
        enabled = true,
        jump_check_interval = 5,         -- Interval in seconds for checking distance after jumping
        distance_threshold = 25,         -- Distance threshold for teleporting party members (TODO: remove the distance traveled by the jump: UsingSpellAtPosition - CastSpell)
        stop_threshold_time = 30,        -- Time threshold to stop if more than X seconds passed without crossing the distance threshold
        enable_fall_damage_check = true, -- Option to enable fall damage from teleported characters
      },
      jump_boosting_method = {
        enabled = true,               -- Option to enable aggressive method (boosts the jump distance right away)
        use_aggressive_method = true, -- Option to enable aggressive method (boosts the jump distance right away)
      }
    },
    DEBUG = {
      level = 0 -- 0 = no debug, 1 = minimal, 2 = verbose debug logs
    }
  },
  onConfigReloaded = {}
})

Config:UpdateCurrentConfig()

Config:AddConfigReloadedCallback(function(configInstance)
  FSPrinter.DebugLevel = configInstance:GetCurrentDebugLevel()
  FSPrint(0, "Config reloaded: " .. Ext.Json.Stringify(configInstance:getCfg(), { Beautify = true }))
end)
Config:RegisterReloadConfigCommand("fs")
