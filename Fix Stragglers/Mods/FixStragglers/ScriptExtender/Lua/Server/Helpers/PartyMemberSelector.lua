---@class PartyMemberSelector: MetaClass
---@field public UseStrengthCheck boolean
---@field public OnlyLinkedCharacters boolean
PartyMemberSelector = _Class:Create("PartyMemberSelector")

function PartyMemberSelector:Init()
    self.UseStrengthCheck = MCMGet("enable_str_check")
    self.OnlyLinkedCharacters = MCMGet("only_linked_characters")

    -- Update the PartyMemberSelector instance values when the MCM settings are changed
    Ext.ModEvents.BG3MCM['MCM_Setting_Saved']:Subscribe(function(payload)
        if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then return end

        if payload.settingId == "enable_str_check" then
            self.UseStrengthCheck = payload.value
        elseif payload.settingId == "only_linked_characters" then
            self.OnlyLinkedCharacters = payload.value
        end
    end)
end

--- Filters the party members for the given characterUUID.
--- @param characterUUID Guid
--- @return table finalMembers The filtered list of party members
function PartyMemberSelector:FilterPartyMembersFor(characterUUID)
    local otherPartyMembers = VCHelpers.Party:GetOtherPartyMembers(characterUUID)
    local partyWithoutCharacter = {}

    -- Remove characterUUID from otherPartyMembers
    for i, member in ipairs(otherPartyMembers) do
        if member ~= characterUUID then
            table.insert(partyWithoutCharacter, member)
        end
    end

    local membersToCheck = partyWithoutCharacter
    if self.OnlyLinkedCharacters then
        membersToCheck = VCHelpers.Character:GetCharactersLinkedWith(characterUUID)
    end

    local finalMembers = {}
    for _, member in ipairs(membersToCheck) do
        if self:ShouldIncludeMember(member, characterUUID) then
            table.insert(finalMembers, member)
        end
    end

    return finalMembers
end

--- Checks if the given member should be included in the list of party members to consider.
--- @param member Guid
--- @param characterUUID Guid
--- @return boolean
function PartyMemberSelector:ShouldIncludeMember(member, characterUUID)
    if member == characterUUID then
        FSDebug(2, "Excluding member: " .. member .. " because it is the same as characterUUID: " .. characterUUID)
        return false
    end

    if not self:PassesStrengthCheck(member, characterUUID) then
        FSDebug(2, "Excluding member: " .. member .. " due to failed strength check.")
        return false
    end

    if Osi.IsInCombat(member) == 1 then
        FSDebug(2, "Excluding member: " .. member .. " because they are in combat.")
        return false
    end

    if VCHelpers.Lootable:IsLootable(member) then
        FSDebug(2, "Excluding member: " .. member .. " because they are lootable.")
        return false
    end

    if Osi.IsDead(member) == 1 then
        FSDebug(2, "Excluding member: " .. member .. " because they are dead.")
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
