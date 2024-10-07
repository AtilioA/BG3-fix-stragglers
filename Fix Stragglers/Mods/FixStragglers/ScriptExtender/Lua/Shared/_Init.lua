setmetatable(Mods.FixStragglers, { __index = Mods.VolitionCabinet })

---Ext.Require files at the path
---@param path string
---@param files string[]
function RequireFiles(path, files)
    for _, file in pairs(files) do
        Ext.Require(string.format("%s%s.lua", path, file))
    end
end

local function updateLoca()
    for _, file in ipairs({ "FS_English.loca" }) do
        local fileName = string.format("Localization/English/%s.xml", file)
        local contents = Ext.IO.LoadFile(fileName, "data")

        if not contents then
            return
        end

        for line in string.gmatch(contents, "([^\r\n]+)\r*\n") do
            local handle, value = string.match(line, '<content contentuid="(%w+)".->(.+)</content>')
            if handle ~= nil and value ~= nil then
                value = value:gsub("&[lg]t;", {
                    ['&lt;'] = "<",
                    ['&gt;'] = ">"
                })
                Ext.Loca.UpdateTranslatedString(handle, value)
            end
        end
    end
end

if Ext.Debug.IsDeveloperMode() then
    updateLoca()
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
