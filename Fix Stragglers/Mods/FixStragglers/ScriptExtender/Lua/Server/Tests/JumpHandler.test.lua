D.describe("JumpHandler teleport selection", { tags = { "server", "runtime", "teleport" } }, function()
    for _, method in ipairs({ "TeleportCompanionsToCharacter", "TeleportCompanionsToJumper" }) do
        local entryPoint = method

        D.test(entryPoint .. " force includes the target's summons and the full live roster", function(ctx)
            ctx.requireServer()
            local players = Osi.DB_Players:Get(nil)
            if #players == 0 then ctx.skip("No players in the current save") end
            local summons = Osi.DB_PlayerSummons:Get(nil)
            if #summons == 0 then ctx.skip("No player summons in the current save") end
            local owner = Osi.CharacterGetOwner(summons[1][1])
            if not owner then ctx.skip("First player summon has no owner") end
            local target = VCHelpers.Format:Guid(owner)
            local party, expected = {}, {}
            for _, row in ipairs(players) do
                local member = VCHelpers.Format:Guid(row[1])
                if member ~= target then
                    party[#party + 1] = member
                    party[#party + 1] = member
                    expected[member] = true
                end
            end
            for _, row in ipairs(summons) do
                local summon = VCHelpers.Format:Guid(row[1])
                if summon ~= target then expected[summon] = true end
            end
            -- Volition Cabinet returns normalized GUIDs; duplicates and the target must be excluded.
            party[#party + 1] = target
            local originalParty = { table.unpack(party) }
            local partyLookup = ctx.stub(VCHelpers.Party, "GetOtherPartyMembers", function(_, character)
                ctx.expect(character).toBe(target)
                return party
            end)
            local selector = ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function()
                error("Force teleport must bypass the selector")
            end)
            local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
            ctx.stub(handler, "IsValidTeleportSource", function(_, character)
                ctx.expect(character).toBe(target)
                return true
            end)
            local dispatch = ctx.stub(VCHelpers.Teleporting, "TeleportCharactersToCharacter",
                function(_, character, members, radius, settings)
                    ctx.expect(character).toBe(target)
                    ctx.expect(radius).toBe(nil)
                    ctx.expect(settings).toEqual({ IgnoreDialogue = false, IgnoreRestricted = false })
                    local actual = {}
                    for _, member in ipairs(members) do
                        ctx.expect(member).toBe(VCHelpers.Format:Guid(member))
                        ctx.expect(member == target).toBe(false)
                        ctx.expect(actual[member]).toBe(nil)
                        actual[member] = true
                    end
                    ctx.expect(actual).toEqual(expected)
                end)
            if entryPoint == "TeleportCompanionsToCharacter" then
                handler:TeleportCompanionsToCharacter(target, true)
            else
                handler:TeleportCompanionsToJumper(true)
            end
            ctx.expect(party).toEqual(originalParty)
            ctx.expect(partyLookup).toHaveBeenCalledTimes(1)
            ctx.expect(selector).toHaveBeenCalledTimes(0)
            ctx.expect(dispatch).toHaveBeenCalledTimes(1)
        end)

        D.test(entryPoint .. " force excludes a summon target and deduplicates summons", function(ctx)
            ctx.requireServer()
            local summons = Osi.DB_PlayerSummons:Get(nil)
            if #summons == 0 then ctx.skip("No player summons in the current save") end
            local target = VCHelpers.Format:Guid(summons[1][1])
            local party, expected = { target, target }, {}
            for _, row in ipairs(summons) do
                local member = VCHelpers.Format:Guid(row[1])
                if member ~= target then
                    expected[member] = true
                    party[#party + 1] = member
                    party[#party + 1] = member
                end
            end
            ctx.stub(VCHelpers.Party, "GetOtherPartyMembers", function() return party end)
            local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
            ctx.stub(handler, "IsValidTeleportSource", function() return true end)
            local dispatch = ctx.stub(VCHelpers.Teleporting, "TeleportCharactersToCharacter",
                function(_, _, members)
                    local actual = {}
                    for _, member in ipairs(members) do
                        ctx.expect(actual[member]).toBe(nil)
                        actual[member] = true
                    end
                    ctx.expect(actual).toEqual(expected)
                end)
            if entryPoint == "TeleportCompanionsToCharacter" then
                handler:TeleportCompanionsToCharacter("TestTarget_" .. target, true)
            else
                handler.Jumper = "TestTarget_" .. target
                handler:TeleportCompanionsToJumper(true)
            end
            ctx.expect(dispatch).toHaveBeenCalledTimes(1)
        end)

        D.test(entryPoint .. " automatic dispatch keeps selector output", function(ctx)
            ctx.requireServer()
            local players = Osi.DB_Players:Get(nil)
            if #players == 0 then ctx.skip("No players in the current save") end
            local target = VCHelpers.Format:Guid(players[1][1])
            local selected = {}
            if players[2] then selected[1] = VCHelpers.Format:Guid(players[2][1]) end
            local selector = ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function(_, character)
                ctx.expect(character).toBe(target)
                return selected
            end)
            local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
            ctx.stub(handler, "IsValidTeleportSource", function() return true end)
            ctx.stub(handler, "GetForceTeleportMembers", function()
                error("Automatic teleport must use the selector")
            end)
            local bypass = MCM.Get("always_force_teleport")
            local settings = {
                IgnoreDialogue = not bypass and PartyMemberSelector.IgnoreOnDialogue or false,
                IgnoreRestricted = not bypass and PartyMemberSelector.IgnoreRestrictedCharacters or false,
            }
            local dispatch = ctx.stub(VCHelpers.Teleporting, "TeleportCharactersToCharacter",
                function(_, character, members, radius, actualSettings)
                    ctx.expect(character).toBe(target)
                    ctx.expect(members).toBe(selected)
                    ctx.expect(radius).toBe(nil)
                    ctx.expect(actualSettings).toEqual(settings)
                end)
            if entryPoint == "TeleportCompanionsToCharacter" then
                handler:TeleportCompanionsToCharacter(target, false)
            else
                handler:TeleportCompanionsToJumper(false)
            end
            ctx.expect(selector).toHaveBeenCalledTimes(1)
            ctx.expect(dispatch).toHaveBeenCalledTimes(1)
        end)
    end
end)
