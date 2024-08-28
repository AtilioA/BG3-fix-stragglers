---@class PartyMemberSelector: MetaClass
---@field public UseStrengthCheck boolean
---@field public OnlyLinkedCharacters boolean
PartyMemberSelector = _Class:Create("PartyMemberSelector")

function PartyMemberSelector:Init()
    self.UseStrengthCheck = MCMGet("enable_str_check")
    self.OnlyLinkedCharacters = MCMGet("only_linked_characters")

    -- Update the PartyMemberSelector instance values when the MCM settings are changed
    Ext.RegisterNetListener("MCM_Saved_Setting", function(call, payload)
        local data = Ext.Json.Parse(payload)
        if not data or data.modGUID ~= ModuleUUID then return end

        if data.settingId == "enable_str_check" then
            self.UseStrengthCheck = data.value
        elseif data.settingId == "only_linked_characters" then
            self.OnlyLinkedCharacters = data.value
        end
    end)
end

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

function PartyMemberSelector:ShouldIncludeMember(member, characterUUID)
    if member == characterUUID then
        return false
    end

    if not self:PassesStrengthCheck(member, characterUUID) then
        return false
    end

    if Osi.IsInCombat(member) == 1 then
        return false
    end

    if VCHelpers.Lootable:IsLootable(member) then
        return false
    end

    return true
end

function PartyMemberSelector:PassesStrengthCheck(member, characterUUID)
    if not self.UseStrengthCheck then
        return true
    end

    local referenceStrength = VCHelpers.Character:GetAbilityScore(characterUUID, "Strength")
    local memberStrength = VCHelpers.Character:GetAbilityScore(member, "Strength")

    return memberStrength >= referenceStrength
end
