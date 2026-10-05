D.describe("JumpHandler teleport selection", { tags = { "server", "runtime", "teleport" } }, function()
    --- Normalizes a template-prefixed GUID the way JumpHandler does.
    ---@param guid string|nil
    ---@return string|nil
    local function normalize(guid)
        return VCHelpers.Format:Guid(guid)
    end

    --- Returns the normalized host and the unique normalized party members, excluding the host.
    ---@return string, string[]
    local function loadParty()
        local target = normalize(Osi.GetHostCharacter())
        local members = {}
        local seen = {}
        for _, row in ipairs(Osi.DB_Players:Get(nil)) do
            local guid = normalize(row[1])
            if guid and guid ~= target and not seen[guid] then
                seen[guid] = true
                table.insert(members, guid)
            end
        end
        return target, members
    end

    --- Returns one active (alive, free, out of combat) party summon.
    ---@return string|nil
    local function findActiveSummon()
        for _, row in ipairs(Osi.DB_PlayerSummons:Get(nil)) do
            local summon = normalize(row[1])
            if Osi.IsControlled(summon) == 0 and Osi.IsInCombat(summon) == 0 and Osi.IsDead(summon) == 0
                and Osi.GetHitpoints(summon) > 0 then
                return summon
            end
        end
    end

    --- Returns one party summon that is not linked to the party line.
    ---@return string|nil
    local function findBlockedSummon()
        for _, row in ipairs(Osi.DB_PlayerSummons:Get(nil)) do
            local summon = normalize(row[1])
            local entity = Ext.Entity.Get(summon)
            if entity and entity.BlockFollow ~= nil then
                return summon
            end
        end
    end

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
            return { "TestMember_" .. campResident, campResident, "TestTarget_" .. target }
        end)
        ctx.stub(VCHelpers.Character, "IsCharacterInCamp", function()
            return true
        end)
        -- Keep summons out of this test: it only checks camp filtering.
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(setting, ...)
            if setting == "ignore_summons" then return true end
            return getSetting(setting, ...)
        end)

        local selector = setmetatable({
            OnlyLinkedCharacters = false,
            IgnoreRestrictedCharacters = false,
            IgnoreOnDialogue = false,
            UseStrengthCheck = false,
        }, { __index = PartyMemberSelector })
        local automaticMembers = selector:FilterPartyMembersFor("TestTarget_" .. target, true)
        local manualMembers = selector:FilterPartyMembersFor("TestTarget_" .. target)

        ctx.expect(automaticMembers).toEqual({})
        ctx.expect(manualMembers).toEqual({ campResident })
    end)

    D.test("Selector excludes summons that are not linked to the party line", function(ctx)
        ctx.requireServer()
        local target = normalize(Osi.GetHostCharacter())
        local blocked = findBlockedSummon()
        if not blocked then ctx.skip("No unlinked summon in the current save") end

        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(setting, ...)
            if setting == "ignore_summons" then return false end
            return getSetting(setting, ...)
        end)
        local selector = setmetatable({
            OnlyLinkedCharacters = true,
            IgnoreRestrictedCharacters = false,
            IgnoreOnDialogue = false,
            UseStrengthCheck = false,
        }, { __index = PartyMemberSelector })

        ctx.expect(selector:ShouldIncludeMember(blocked, target)).toBe(false)
    end)

    D.test("Selector includes summons when the link restriction is off", function(ctx)
        ctx.requireServer()
        local target = normalize(Osi.GetHostCharacter())
        local summon = findActiveSummon()
        if not summon then ctx.skip("No active summon in the current save") end

        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(setting, ...)
            if setting == "ignore_summons" then return false end
            return getSetting(setting, ...)
        end)
        local selector = setmetatable({
            OnlyLinkedCharacters = false,
            IgnoreRestrictedCharacters = false,
            IgnoreOnDialogue = false,
            UseStrengthCheck = false,
        }, { __index = PartyMemberSelector })

        ctx.expect(selector:ShouldIncludeMember(summon, target)).toBe(true)

        local filtered = selector:FilterPartyMembersFor(target)
        local included = false
        for _, member in ipairs(filtered) do
            if member == summon then included = true end
        end
        ctx.expect(included).toBe(true)
    end)

    D.test("Force candidates include every party member and every party summon", function(ctx)
        ctx.requireServer()
        local target, members = loadParty()
        if #members < 2 then ctx.skip("At least two party members are needed for this test") end
        local summons = {}
        for _, row in ipairs(Osi.DB_PlayerSummons:Get(nil)) do
            local summon = normalize(row[1])
            if summon and summon ~= target then summons[#summons + 1] = summon end
        end
        if #summons == 0 then ctx.skip("No summons in the current save") end

        local companions = {}
        for _, member in ipairs(members) do
            if member ~= target then companions[#companions + 1] = member end
        end
        if #companions < 2 then ctx.skip("At least two companions are needed for this test") end
        local companionA, companionB = companions[1], companions[2]
        -- DB_Players stub: the target and duplicates prove exclusion and deduplication.
        ctx.stub(VCHelpers.Party, "GetOtherPartyMembers", function(_, character)
            ctx.expect(normalize(character)).toBe(target)
            return { "TestTarget_" .. target, "TestMember_" .. companionA, companionA, companionB }
        end)
        -- View stub: linked characters join the force teleport as well.
        ctx.stub(VCHelpers.Character, "GetCharactersLinkedWith", function(_, character)
            ctx.expect(normalize(character)).toBe(target)
            return { "TestMember_" .. companionA, "TestTarget_" .. target }
        end)

        local forceMembers = JumpHandler:GetForceTeleportMembers("TestTarget_" .. target)

        local expected = { [companionA] = true, [companionB] = true }
        for _, summon in ipairs(summons) do
            expected[summon] = true
        end
        local actual = {}
        for _, member in ipairs(forceMembers) do
            ctx.expect(actual[member]).toBe(nil)
            actual[member] = true
        end
        ctx.expect(actual).toEqual(expected)
        ctx.expect(actual[target]).toBe(nil)
    end)

    for _, entryPoint in ipairs({ "TeleportCompanionsToCharacter", "TeleportCompanionsToJumper" }) do
        local method = entryPoint
        D.test(method .. " force bypasses settings and dispatches through JumpHandler teleport", function(ctx)
            ctx.requireServer()
            local target = normalize(Osi.GetHostCharacter())
            local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
            ctx.stub(handler, "IsValidTeleportSource", function(_, character)
                ctx.expect(character).toBe(target)
                return true
            end)
            local selected = {}
            ctx.stub(handler, "GetForceTeleportMembers", function(_, character)
                ctx.expect(character).toBe(target)
                return selected
            end)
            ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function()
                error("Force teleport must bypass the automatic selector")
            end)
            local getSetting = MCM.Get
            ctx.stub(MCM, "Get", function(setting, ...)
                if setting == "always_force_teleport" then return false end
                return getSetting(setting, ...)
            end)

            local dispatch = ctx.stub(handler, "TeleportCharactersToCharacter",
                function(_, character, characters, settings)
                    ctx.expect(character).toBe(target)
                    ctx.expect(characters).toBe(selected)
                    ctx.expect(settings).toEqual({ IgnoreDialogue = false, IgnoreRestricted = false })
                end)

            if method == "TeleportCompanionsToCharacter" then
                handler:TeleportCompanionsToCharacter(target, true)
            else
                handler:TeleportCompanionsToJumper(true)
            end

            ctx.expect(dispatch).toHaveBeenCalledTimes(1)
        end)

        D.test(method .. " automatic keeps selector output and dispatches through JumpHandler teleport",
            function(ctx)
                ctx.requireServer()
                local target, members = loadParty()
                if #members == 0 then ctx.skip("No players in the current save") end

                local selected = { members[1] }
                local excludeCampResidents = method == "TeleportCompanionsToJumper" and true or nil
                local selector = ctx.stub(PartyMemberSelector, "FilterPartyMembersFor",
                    function(_, character, excludeCamp)
                        ctx.expect(character).toBe(target)
                        ctx.expect(excludeCamp).toBe(excludeCampResidents)
                        return selected
                    end)
                local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
                ctx.stub(handler, "IsValidTeleportSource", function(_, character)
                    ctx.expect(character).toBe(target)
                    return true
                end)
                ctx.stub(handler, "GetForceTeleportMembers", function()
                    error("Automatic teleport must use the selector")
                end)
                local getSetting = MCM.Get
                ctx.stub(MCM, "Get", function(setting, ...)
                    if setting == "always_force_teleport" then return false end
                    if setting == "ignore_on_dialogue" then return true end
                    if setting == "ignore_restricted_characters" then return true end
                    return getSetting(setting, ...)
                end)

                local dispatch = ctx.stub(handler, "TeleportCharactersToCharacter",
                    function(_, character, characters, settings)
                        ctx.expect(character).toBe(target)
                        ctx.expect(characters).toBe(selected)
                        ctx.expect(settings).toEqual({ IgnoreDialogue = true, IgnoreRestricted = true })
                    end)

                if method == "TeleportCompanionsToCharacter" then
                    handler:TeleportCompanionsToCharacter(target, false)
                else
                    handler:TeleportCompanionsToJumper(false)
                end

                ctx.expect(selector).toHaveBeenCalledTimes(1)
                ctx.expect(dispatch).toHaveBeenCalledTimes(1)
            end)
    end

    D.test("Distant party teleport keeps selector output and dispatches with settings", function(ctx)
        ctx.requireServer()
        local target, members = loadParty()
        if #members == 0 then ctx.skip("No players in the current save") end

        local selected = { members[1] }
        local selector = ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function(_, character, excludeCamp)
            ctx.expect(character).toBe(target)
            ctx.expect(excludeCamp).toBe(true)
            return selected
        end)
        local handler = setmetatable({ DistanceThresholdNoJump = 1 }, { __index = JumpHandler })
        ctx.stub(handler, "IsValidTeleportSource", function(_, character)
            ctx.expect(character).toBe(target)
            return true
        end)
        ctx.stub(VCHelpers.Grid, "GetDistance", function() return 10 end)
        ctx.stub(VCHelpers.Loca, "GetDisplayName", function(_, character) return tostring(character) end)
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(setting, ...)
            if setting == "always_force_teleport" then return false end
            if setting == "ignore_on_dialogue" then return true end
            if setting == "ignore_restricted_characters" then return true end
            return getSetting(setting, ...)
        end)

        local dispatch = ctx.stub(handler, "TeleportCharactersToCharacter",
            function(_, character, characters, settings)
                ctx.expect(character).toBe(target)
                ctx.expect(characters).toEqual(selected)
                ctx.expect(settings).toEqual({ IgnoreDialogue = true, IgnoreRestricted = true })
            end)

        handler:TeleportDistantPartyMembers(target)

        ctx.expect(selector).toHaveBeenCalledTimes(1)
        ctx.expect(dispatch).toHaveBeenCalledTimes(1)
    end)

    D.test("TeleportCharactersToCharacter checks the target before reading a position", function(ctx)
        ctx.requireServer()
        local target, members = loadParty()
        if #members == 0 then ctx.skip("No players in the current save") end

        local settings = { IgnoreDialogue = false, IgnoreRestricted = false }
        local check = ctx.stub(VCHelpers.Teleporting, "CanCharacterTeleport", function(_, character, actualSettings)
            ctx.expect(character).toBe(target)
            ctx.expect(actualSettings).toBe(settings)
            return false, "blocked"
        end)
        local handler = setmetatable({}, { __index = JumpHandler })

        handler:TeleportCharactersToCharacter(target, { members[1] }, settings)

        ctx.expect(check).toHaveBeenCalledTimes(1)
    end)

    D.test("TeleportCharactersToCharacter checks every member with the given settings", function(ctx)
        ctx.requireServer()
        local target, members = loadParty()
        if #members < 2 then ctx.skip("At least two party members are needed for this test") end

        local settings = { IgnoreDialogue = false, IgnoreRestricted = false }
        local checked = {}
        ctx.stub(VCHelpers.Teleporting, "CanCharacterTeleport", function(_, character, actualSettings)
            ctx.expect(actualSettings).toBe(settings)
            table.insert(checked, character)
            if character == target then return true end
            return false, "member blocked"
        end)
        local handler = setmetatable({}, { __index = JumpHandler })

        handler:TeleportCharactersToCharacter(target, { members[1], members[2] }, settings)

        ctx.expect(checked).toEqual({ target, members[1], members[2] })
    end)

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
        local sourceCheck = ctx.stub(handler, "IsValidTeleportSource", function() return false end)
        local coreCheck = ctx.stub(handler, "PassesCoreHandlingChecks", function() return false end)
        local distanceCheck = ctx.stub(handler, "PartyCrossedDistanceThreshold", function() return false end)
        local scheduleCheck = ctx.stub(handler, "ScheduleJumpCheck", function() end)
        local teleport = ctx.stub(handler, "TeleportCompanionsToJumper", function() end)

        handler:HandleJumpTimerFinished()

        ctx.expect(handler.HandlingJump).toBe(false)
        ctx.expect(sourceCheck).toHaveBeenCalledTimes(0)
        ctx.expect(coreCheck).toHaveBeenCalledTimes(1)
        ctx.expect(distanceCheck).toHaveBeenCalledTimes(0)
        ctx.expect(scheduleCheck).toHaveBeenCalledTimes(0)
        ctx.expect(teleport).toHaveBeenCalledTimes(0)
    end)

    D.test("Repeated jump boosts preserve statuses needed for combat cleanup", function(ctx)
        ctx.requireServer()
        local target, members = loadParty()
        if #members < 2 then ctx.skip("At least two companions are needed for this test") end
        local selected = { members[1], members[2] }
        ctx.stub(PartyMemberSelector, "FilterPartyMembersFor", function() return selected end)
        local handler = setmetatable({ Jumper = target }, { __index = JumpHandler })
        local alreadyBoosted = {}
        ctx.stub(handler, "ApplyStatusesToCompanion", function(_, companion)
            if alreadyBoosted[companion] then return {} end
            alreadyBoosted[companion] = true
            return { "FS_JUMPHELPER" }
        end)

        handler:BoostCompanionsJump()
        selected = { members[1] }
        handler:BoostCompanionsJump()

        ctx.expect(handler.BoostedCompanions).toEqual({
            [members[1]] = { "FS_JUMPHELPER" },
            [members[2]] = { "FS_JUMPHELPER" },
        })
    end)

    D.test("Jump boosting does not start teleport polling when jump teleport is disabled", function(ctx)
        ctx.requireServer()
        local target = normalize(Osi.GetHostCharacter())
        local getSetting = MCM.Get
        ctx.stub(MCM, "Get", function(setting, ...)
            if setting == "teleporting_method_enabled" then return false end
            return getSetting(setting, ...)
        end)
        local handler = setmetatable({
            HandlingJump = false,
            ShouldBoostJump = { enabled = true },
        }, { __index = JumpHandler })
        ctx.stub(handler, "ShouldHandleJump", function() return true end)
        local boost = ctx.stub(JumpHandler, "BoostCompanionsJump", function() end)
        local schedule = ctx.stub(handler, "ScheduleJumpCheck", function() end)

        handler:HandleJump({ CasterGuid = target })

        ctx.expect(handler.HandlingJump).toBe(false)
        ctx.expect(boost).toHaveBeenCalledTimes(1)
        ctx.expect(schedule).toHaveBeenCalledTimes(0)
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
