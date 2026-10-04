D.describe("JumpHandler teleport selection", { tags = { "server", "runtime", "teleport" } }, function()
    D.test("Automatic selection excludes camp residents when restricted filtering is off", function(ctx)
        ctx.requireServer()
        local players = Osi.DB_Players:Get(nil)
        if #players < 2 then ctx.skip("At least two players are needed for this selector test") end

        local target = VCHelpers.Format:Guid(players[1][1])
        local campResident
        for index = 2, #players do
            local member = VCHelpers.Format:Guid(players[index][1])
            if Osi.IsControlled(member) == 0 and Osi.IsInCombat(member) == 0 and Osi.IsDead(member) == 0
                and Osi.GetHitpoints(member) > 0 and Osi.IsSummon(member) == 0 then
                campResident = member
                break
            end
        end
        if not campResident then ctx.skip("No eligible companion is available for this selector test") end

        ctx.stub(VCHelpers.Party, "GetOtherPartyMembers", function(_, character)
            ctx.expect(character).toBe(target)
            return { campResident }
        end)
        ctx.stub(VCHelpers.Character, "IsCharacterInCamp", function()
            return true
        end)

        local selector = setmetatable({
            OnlyLinkedCharacters = false,
            IgnoreRestrictedCharacters = false,
            IgnoreOnDialogue = false,
            UseStrengthCheck = false,
        }, { __index = PartyMemberSelector })
        local automaticMembers = selector:FilterPartyMembersFor(target, true)
        local manualMembers = selector:FilterPartyMembersFor(target)

        ctx.expect(automaticMembers).toEqual({})
        ctx.expect(manualMembers).toEqual({ campResident })
    end)

    for _, ignoreSummons in ipairs({ false, true }) do
        D.test("Force candidates include summons with ignore_summons=" .. tostring(ignoreSummons), function(ctx)
            ctx.requireServer()
            local getSetting = MCM.Get
            ctx.stub(MCM, "Get", function(setting, ...)
                if setting == "ignore_summons" then return ignoreSummons end
                return getSetting(setting, ...)
            end)
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
                party[#party + 1] = member
                party[#party + 1] = member
                if member ~= target then
                    expected[member] = true
                end
            end
            -- Overlapping helper and database results must include each summon once.
            for index, row in ipairs(summons) do
                local summon = VCHelpers.Format:Guid(row[1])
                if index > 1 then party[#party + 1] = summon end
                if summon ~= target then expected[summon] = true end
            end
            party[#party + 1] = target
            local originalParty = { table.unpack(party) }
            local partyLookup = ctx.stub(VCHelpers.Party, "GetOtherPartyMembers", function(_, character)
                ctx.expect(character).toBe(target)
                return party
            end)
            local selector = ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function()
                error("Force candidates must bypass other selection filters")
            end)
            local members = JumpHandler:GetForceTeleportMembers("TestTarget_" .. target)
            local actual = {}
            for _, member in ipairs(members) do
                ctx.expect(member).toBe(VCHelpers.Format:Guid(member))
                ctx.expect(actual[member]).toBe(nil)
                actual[member] = true
            end
            ctx.expect(actual).toEqual(expected)
            ctx.expect(party).toEqual(originalParty)
            ctx.expect(partyLookup).toHaveBeenCalledTimes(1)
            ctx.expect(selector).toHaveBeenCalledTimes(0)
        end)
    end

    D.test("Force candidates exclude a summon target and deduplicate live summons", function(ctx)
        ctx.requireServer()
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(setting, ...)
            if setting == "ignore_summons" then return false end
            return getSetting(setting, ...)
        end)
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
        local members = JumpHandler:GetForceTeleportMembers("TestTarget_" .. target)
        local actual = {}
        for _, member in ipairs(members) do
            ctx.expect(actual[member]).toBe(nil)
            actual[member] = true
        end
        ctx.expect(actual).toEqual(expected)
    end)

    for _, method in ipairs({ "TeleportCompanionsToCharacter", "TeleportCompanionsToJumper" }) do
        local entryPoint = method
        D.test(entryPoint .. " force uses VC dispatch and bypasses automatic filters", function(ctx)
            ctx.requireServer()
            local target = VCHelpers.Format:Guid(Osi.GetHostCharacter())
            local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
            local sourceCheck = ctx.stub(handler, "IsValidTeleportSource", function(_, character)
                ctx.expect(character).toBe(target)
                return true
            end)
            local selected = {}
            local candidates = ctx.stub(handler, "GetForceTeleportMembers", function(_, character)
                ctx.expect(character).toBe(target)
                return selected
            end)
            ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function()
                error("Force teleport must bypass the automatic selector")
            end)
            local getSettings = JumpHandler.GetTeleportSettings
            local settings = ctx.stub(handler, "GetTeleportSettings", function(self, forceBypass)
                ctx.expect(forceBypass).toBe(true)
                return getSettings(self, forceBypass)
            end)
            local dispatch = ctx.stub(VCHelpers.Teleporting, "TeleportCharactersToCharacter",
                function(_, character, members, vfx, actualSettings)
                    ctx.expect(character).toBe(target)
                    ctx.expect(members).toBe(selected)
                    ctx.expect(vfx).toBe(nil)
                    ctx.expect(actualSettings).toEqual({ IgnoreDialogue = false, IgnoreRestricted = false })
                end)
            if entryPoint == "TeleportCompanionsToCharacter" then
                handler:TeleportCompanionsToCharacter(target, true)
            else
                handler:TeleportCompanionsToJumper(true)
            end
            ctx.expect(sourceCheck).toHaveBeenCalledTimes(1)
            ctx.expect(candidates).toHaveBeenCalledTimes(1)
            ctx.expect(settings).toHaveBeenCalledTimes(1)
            ctx.expect(dispatch).toHaveBeenCalledTimes(1)
        end)

        D.test(entryPoint .. " automatic dispatch keeps selector output", function(ctx)
            ctx.requireServer()
            local players = Osi.DB_Players:Get(nil)
            if #players == 0 then ctx.skip("No players in the current save") end
            local target = VCHelpers.Format:Guid(players[1][1])
            local selected = {}
            if players[2] then selected[1] = VCHelpers.Format:Guid(players[2][1]) end
            local excludeCampResidents = entryPoint == "TeleportCompanionsToJumper" and true or nil
            local selector = ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function(_, character, excludeCamp)
                ctx.expect(character).toBe(target)
                ctx.expect(excludeCamp).toBe(excludeCampResidents)
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
                function(_, character, members, vfx, actualSettings)
                    ctx.expect(character).toBe(target)
                    ctx.expect(members).toBe(selected)
                    ctx.expect(vfx).toBe(nil)
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

    for _, setting in ipairs({ "mod_enabled", "teleporting_method_enabled" }) do
        local disabledSetting = setting
        D.test("Delayed jump stops when " .. disabledSetting .. " is disabled", function(ctx)
            ctx.requireServer()
            local settings = {
                mod_enabled = true,
                teleporting_method_enabled = true,
            }
            settings[disabledSetting] = false
            local getSetting = MCM.Get
            ctx.stub(MCM, "Get", function(settingId, ...)
                if settings[settingId] ~= nil then return settings[settingId] end
                return getSetting(settingId, ...)
            end)

            local handler = setmetatable({
                HandlingJump = true,
                Jumper = VCHelpers.Format:Guid(Osi.GetHostCharacter()),
                ShouldTeleportCompanions = true,
                JumpCheckGeneration = 0,
            }, { __index = JumpHandler })
            ctx.stub(handler, "CheckStopThresholdTime", function() return false end)
            ctx.stub(handler, "IsValidTeleportSource", function() return true end)
            ctx.stub(handler, "PassesCoreHandlingChecks", function() return true end)
            ctx.stub(handler, "PartyCrossedDistanceThreshold", function() return true end)
            local teleport = ctx.stub(handler, "TeleportCompanionsToJumper", function() end)

            handler:HandleJumpTimerFinished()

            ctx.expect(handler.HandlingJump).toBe(false)
            ctx.expect(teleport).toHaveBeenCalledTimes(0)
        end)
    end

    D.test("Delayed jump stops polling when core eligibility fails before distance threshold", function(ctx)
        ctx.requireServer()
        local settings = {
            mod_enabled = true,
            teleporting_method_enabled = true,
        }
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(settingId, ...)
            if settings[settingId] ~= nil then return settings[settingId] end
            return getSetting(settingId, ...)
        end)

        local handler = setmetatable({
            HandlingJump = true,
            Jumper = VCHelpers.Format:Guid(Osi.GetHostCharacter()),
            ShouldTeleportCompanions = true,
            JumpCheckGeneration = 0,
        }, { __index = JumpHandler })
        ctx.stub(handler, "CheckStopThresholdTime", function() return false end)
        local sourceCheck = ctx.stub(handler, "IsValidTeleportSource", function() return true end)
        local coreCheck = ctx.stub(handler, "PassesCoreHandlingChecks", function() return false end)
        local distanceCheck = ctx.stub(handler, "PartyCrossedDistanceThreshold", function() return false end)
        local scheduleCheck = ctx.stub(handler, "ScheduleJumpCheck", function() end)
        local teleport = ctx.stub(handler, "TeleportCompanionsToJumper", function() end)

        handler:HandleJumpTimerFinished()

        ctx.expect(handler.HandlingJump).toBe(false)
        ctx.expect(sourceCheck).toHaveBeenCalledTimes(1)
        ctx.expect(coreCheck).toHaveBeenCalledTimes(1)
        ctx.expect(distanceCheck).toHaveBeenCalledTimes(0)
        ctx.expect(scheduleCheck).toHaveBeenCalledTimes(0)
        ctx.expect(teleport).toHaveBeenCalledTimes(0)
    end)

    D.test("Distance check uses the current feature setting", function(ctx)
        ctx.requireServer()
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(settingId, ...)
            if settingId == "mod_enabled" then return true end
            if settingId == "teleporting_method_distance_enabled" then return false end
            return getSetting(settingId, ...)
        end)
        local handler = setmetatable({
            ShouldTeleportDistantCompanionsNoJump = true,
            DistanceCheckGeneration = 0,
        }, { __index = JumpHandler })
        local scan = ctx.stub(VCHelpers.Character, "GetDisjointedLinkedCharacterSets", function() return {} end)

        handler:CheckAndTeleportDistantPartyMembers()

        ctx.expect(scan).toHaveBeenCalledTimes(0)
    end)

    D.test("Distance checks keep one chain and can resume after being disabled", function(ctx)
        ctx.requireServer()
        local settings = {
            mod_enabled = true,
            teleporting_method_distance_enabled = true,
        }
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(settingId, ...)
            if settings[settingId] ~= nil then return settings[settingId] end
            return getSetting(settingId, ...)
        end)
        local handler = setmetatable({
            ShouldTeleportDistantCompanionsNoJump = true,
            DistanceCheckGeneration = 0,
        }, { __index = JumpHandler })
        local scanCount = 0
        ctx.stub(VCHelpers.Character, "GetDisjointedLinkedCharacterSets", function()
            scanCount = scanCount + 1
            return {}
        end)

        handler:CheckAndTeleportDistantPartyMembers()
        handler:CheckAndTeleportDistantPartyMembers()
        settings.teleporting_method_distance_enabled = false
        handler:CheckAndTeleportDistantPartyMembers()
        settings.teleporting_method_distance_enabled = true
        handler:CheckAndTeleportDistantPartyMembers()
        settings.teleporting_method_distance_enabled = false
        handler:CheckAndTeleportDistantPartyMembers()

        ctx.expect(scanCount).toBe(2)
    end)
end)
