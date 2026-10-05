---@class PartyMemberSelector: MetaClass
---@field public UseStrengthCheck boolean
---@field public OnlyLinkedCharacters boolean
---@field public IgnoreRestrictedCharacters boolean
---@field public IgnoreOnDialogue boolean
PartyMemberSelector = _Class:Create("PartyMemberSelector")

function PartyMemberSelector:Init()
    self.UseStrengthCheck = MCM.Get("enable_str_check")
    self.OnlyLinkedCharacters = MCM.Get("only_linked_characters")
    self.IgnoreRestrictedCharacters = MCM.Get("ignore_restricted_characters")
    self.IgnoreOnDialogue = MCM.Get("ignore_on_dialogue")

    -- Update the PartyMemberSelector instance values when the MCM settings are changed
    Ext.ModEvents.BG3MCM['MCM_Setting_Saved']:Subscribe(function(payload)
        if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then return end

        if payload.settingId == "enable_str_check" then
            self.UseStrengthCheck = payload.value
        elseif payload.settingId == "only_linked_characters" then
            self.OnlyLinkedCharacters = payload.value
        elseif payload.settingId == "ignore_restricted_characters" then
            self.IgnoreRestrictedCharacters = payload.value
        elseif payload.settingId == "ignore_on_dialogue" then
            self.IgnoreOnDialogue = payload.value
        end
    end)
end

--- Filters the party members for the given characterUUID.
--- @param characterUUID Guid
--- @param excludeCampResidents boolean|nil Whether to exclude camp residents.
--- @return Guid[] finalMembers The filtered list of party members
function PartyMemberSelector:FilterPartyMembersFor(characterUUID, excludeCampResidents)
    characterUUID = VCHelpers.Format:Guid(characterUUID)
    local membersToCheck
    if self.OnlyLinkedCharacters then
        membersToCheck = VCHelpers.Character:GetCharactersLinkedWith(characterUUID)
    else
        membersToCheck = VCHelpers.Party:GetOtherPartyMembers(characterUUID)
        -- DB_Players omits summons; add every party summon so the summon setting can decide.
        for _, row in ipairs(Osi.DB_PlayerSummons:Get(nil)) do
            table.insert(membersToCheck, row[1])
        end
    end

    local finalMembers = {}
    local included = { [characterUUID] = true }
    for _, member in ipairs(membersToCheck) do
        member = VCHelpers.Format:Guid(member)
        if not included[member] and self:ShouldIncludeMember(member, characterUUID, excludeCampResidents) then
            included[member] = true
            table.insert(finalMembers, member)
        end
    end

    return finalMembers
end

--- Checks if the given member should be included in the list of party members to consider.
--- @param member Guid
--- @param characterUUID Guid
--- @param excludeCampResidents boolean|nil Whether to exclude camp residents.
--- @return boolean
function PartyMemberSelector:ShouldIncludeMember(member, characterUUID, excludeCampResidents)
    if member == characterUUID then
        FSDebug(2,
            "Excluding member: " ..
            VCHelpers.Loca:GetDisplayName(member) .. " because it is the same as characterUUID: " .. characterUUID)
        return false
    end

    if excludeCampResidents and VCHelpers.Character:IsCharacterInCamp(member) then
        FSDebug(2, "Excluding member because they are in camp.")
        return false
    end

    if Osi.IsControlled(member) ~= 0 then
        FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " because they are controlled.")
        return false
    end

    if not self:PassesStrengthCheck(member, characterUUID) then
        FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " due to failed strength check.")
        return false
    end

    if Osi.IsInCombat(member) == 1 then
        FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " because they are in combat.")
        return false
    end

    -- if VCHelpers.Lootable:IsLootable(member) then
    --     FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " because they are lootable.")
    --     return false
    -- end

    if Osi.IsDead(member) == 1 then
        FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " because they are dead.")
        return false
    end

    if Osi.GetHitpoints(member) <= 0 then
        FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " because they have 0 hitpoints.")
        return false
    end

    -- With Only grouped enabled, exclude summons with the game's BlockFollow component.
    if self.OnlyLinkedCharacters and Osi.IsSummon(member) == 1 then
        local entity = Ext.Entity.Get(member)
        if entity and entity.BlockFollow ~= nil then
            FSDebug(2,
                "Excluding member: " ..
                VCHelpers.Loca:GetDisplayName(member) .. " because following is blocked.")
            return false
        end
    end

    if MCM.Get("ignore_summons") and Osi.IsSummon(member) == 1 then
        FSDebug(2,
            "Excluding member: " ..
            VCHelpers.Loca:GetDisplayName(member) .. " because they are a summon AND 'ignore summons' is enabled.")
        return false
    end

    if self.IgnoreOnDialogue and self:IsInDialogue(member) then
        FSDebug(2, "Excluding member: " .. VCHelpers.Loca:GetDisplayName(member) .. " because they are in dialogue.")
        return false
    end

    if self.IgnoreRestrictedCharacters and self:IsRestricted(member) then
        FSDebug(2,
            "Excluding member: " ..
            VCHelpers.Loca:GetDisplayName(member) ..
            " due to being in a restricted area/state (danger zone or fast-travel/movement block).")
        return false
    end

    return true
end

--- Checks if the given member passes the strength check.
--- @param member Guid
--- @param characterUUID Guid
--- @return boolean
function PartyMemberSelector:PassesStrengthCheck(member, characterUUID)
    if not self.UseStrengthCheck then
        return true
    end

    local referenceStrength = VCHelpers.Character:GetAbilityScore(characterUUID, "Strength")
    local memberStrength = VCHelpers.Character:GetAbilityScore(member, "Strength")

    return memberStrength >= referenceStrength
end

--- Checks if a character is in a restricted state (danger zone/fast travel block).
---@param characterUUID Guid
---@return boolean
function PartyMemberSelector:IsRestricted(characterUUID)
    if not characterUUID then return false end
    return next(Osi.DB_InDangerZone:Get(characterUUID, nil)) ~= nil
        or next(Osi.DB_FastTravelBlock_BlockedZone_StatusSet:Get(characterUUID)) ~= nil
        or next(Osi.DB_FastTravelBlock_CantMove_StatusSet:Get(characterUUID)) ~= nil
        or next(Osi.DB_FastTravelBlock_Arrested_StatusSet:Get(characterUUID)) ~= nil
        or next(Osi.DB_FastTravelBlock_CampNightMode_StatusSet:Get(characterUUID)) ~= nil
        or next(Osi.DB_FastTravelBlock_FugitiveInPrison_StatusSet:Get(characterUUID, nil)) ~= nil
end

--- Checks if a character is in dialogue, safely.
---@param characterUUID Guid
---@return boolean
function PartyMemberSelector:IsInDialogue(characterUUID)
    if not characterUUID then return false end
    local entity = Ext.Entity.Get(characterUUID)
    local success, inDialog = xpcall(function()
        return entity and entity.ServerCharacter and entity.ServerCharacter.Flags.InDialog
    end, function(err)
        FSDebug(1, "Error checking dialogue: " .. tostring(err))
        return false
    end)
    return success and inDialog == true
end
