EHandlers = {}

function EHandlers.OnCastedSpell(params)
    if params.Spell == "Projectile_Jump" then
        JumpHandlerInstance:HandleJump(params)
    end
end

function EHandlers.OnTPYButtonPress(call, payload, peerID)
    if not peerID then
        FSWarn(0, "Invalid peerID, aborting teleport.")
        return
    end

    if not payload then
        FSWarn(0, "Invalid payload, aborting teleport.")
        return
    end

    local parsedPayload = Ext.Json.Parse(payload)
    if not parsedPayload then
        FSWarn(0, "Invalid parsed payload, aborting teleport.")
        return
    end

    local skipChecks = parsedPayload.skipChecks

    local userID = VCHelpers.Net:PeerToUserID(peerID)
    local userCharacter = VCHelpers.Net:GetUserCharacterUUID(userID)
    if not userCharacter then
        FSWarn(0, "Could not find user character, aborting teleport.")
        return
    end

    FSDebug(1,
        "Received request to teleport party to player with user ID: " ..
        userID .. " (character: " .. userCharacter .. ")")

    return JumpHandlerInstance:TeleportCompanionsToCharacter(userCharacter, skipChecks)
end
