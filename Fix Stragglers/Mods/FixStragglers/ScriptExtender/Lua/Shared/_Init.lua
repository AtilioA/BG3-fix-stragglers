setmetatable(Mods.FixStragglers, { __index = Mods.VolitionCabinet })

---Ext.Require files at the path
---@param path string
---@param files string[]
function RequireFiles(path, files)
    for _, file in pairs(files) do
        Ext.Require(string.format("%s%s.lua", path, file))
    end
end

-- function LoadStats(modDirectoryName, files)
--     for _, file in ipairs(files) do
--         local fileName = string.format("Public/%s/Stats/Generated/Data/%s.txt", modDirectoryName, file)
--         Ext.Stats.LoadStatsFile("Public/FixStragglers/Stats/Generated/Data/FixStragglers_Status.txt", 1)
--     end
-- end

-- Ext.Events.ResetCompleted:Subscribe(function()
--     Ext.Timer.WaitFor(1000, function()
--         LoadStats("FixStragglers", { "FixStragglers_Status" })
--     end)
-- end)
