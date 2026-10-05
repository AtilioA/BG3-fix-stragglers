-- Run with Lua 5.1 from the mod source directory; engine doubles stay outside BG3.
local calls = {}
local checked = {}
local settings = { IgnoreDialogue = false, IgnoreRestricted = false }
local environment = setmetatable({
    _Class = { Create = function() return {} end },
    PartyMemberSelector = { New = function() return {} end },
    VCHelpers = {
        Teleporting = {
            CanCharacterTeleport = function(_, character, actualSettings)
                assert(actualSettings == settings, "Teleport settings changed")
                checked[#checked + 1] = character
                return character ~= "blocked"
            end,
        },
        Loca = { GetDisplayName = function(_, character) return character end },
    },
    Osi = {
        GetPosition = function(character)
            assert(character == "target", "Position read before target validation")
            return 1.5, 2.5, 3.5
        end,
        TeleportToPosition = function(...) calls[#calls + 1] = { ... } end,
    },
    FSDebug = function() end,
}, { __index = _G })

local chunk = assert(loadfile("Mods/FixStragglers/ScriptExtender/Lua/Server/Classes/JumpHandler.lua"))
setfenv(chunk, environment)()
local handler = environment.JumpHandler

handler:TeleportCharactersToCharacter("blocked", { "member" }, settings)
assert(#calls == 0 and #checked == 1, "Blocked target dispatched a teleport")

checked = {}
handler:TeleportCharactersToCharacter("target", { "blocked", "member" }, settings)
assert(table.concat(checked, ",") == "target,blocked,member", "Member checks were skipped")
assert(#calls == 1, "Blocked member dispatched a teleport")
local expected = { "member", 1.5, 2.5, 3.5, "FSTeleportToPosition_member", 0, 0, 0, 0, 1 }
for index, value in ipairs(expected) do
    assert(calls[1][index] == value, "Incorrect teleport argument " .. index)
end
assert(#calls[1] == #expected, "Incorrect teleport argument count")
print("Teleport dispatch: target/member checks and explicit movement flags passed")
