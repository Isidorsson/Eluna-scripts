--[[
    GameMaster UI - Reputation Handlers

    This module handles reputation management including:
    - Getting player reputation for factions
    - Setting player reputation values
    - Sending faction data to client
    - Getting online players for target selection
]]--

local ReputationHandlers = {}

-- Dependencies will be injected
local GameMasterSystem, Config, Utils, Database, DatabaseHelper

-- Load faction data
local FactionData = require("GameMasterUI.Server.Data.GameMasterUI_FactionData")

-- Get a target player by GUID (or self if nil/0)
local function GetTargetPlayer(player, targetGuid)
    if not targetGuid or targetGuid == 0 then
        return player
    end

    -- Find player by GUID
    local targetPlayer = GetPlayerByGUID(targetGuid)
    if not targetPlayer then
        return nil, "Target player not found or offline"
    end

    return targetPlayer
end

-- Get a target player by name (or self if "Self" or empty)
local function GetTargetPlayerByName(player, targetName)
    if not targetName or targetName == "" or targetName == "Self" or targetName:lower() == "self" then
        return player
    end

    -- Find player by name
    local targetPlayer = GetPlayerByName(targetName)
    if not targetPlayer then
        return nil, "Player '" .. targetName .. "' not found or offline"
    end

    return targetPlayer
end

-- Get reputation data for a specific faction
function ReputationHandlers.getPlayerReputation(player, targetGuid, factionId)
    -- Validate GM rank
    if player:GetGMRank() < Config.MIN_GM_RANK then
        AIO.Handle(player, "GameMasterSystem", "reputationError", "Insufficient GM rank")
        return
    end

    local targetPlayer, error = GetTargetPlayer(player, targetGuid)
    if not targetPlayer then
        AIO.Handle(player, "GameMasterSystem", "reputationError", error)
        return
    end

    local currentRep = targetPlayer:GetReputation(factionId)
    local rank = targetPlayer:GetReputationRank(factionId)
    local factionInfo = FactionData.GetFaction(factionId)
    local standingName, standingData = FactionData.GetStandingFromValue(currentRep)

    AIO.Handle(player, "GameMasterSystem", "receivePlayerReputation", {
        targetGuid = targetPlayer:GetGUIDLow(),
        targetName = targetPlayer:GetName(),
        factionId = factionId,
        factionName = factionInfo and factionInfo.name or "Unknown",
        currentRep = currentRep,
        rank = rank,
        standingName = standingName,
        standingMin = standingData.min,
        standingMax = standingData.max
    })
end

-- Get reputation data for a specific faction (by player name)
function ReputationHandlers.getPlayerReputationByName(player, targetName, factionId)
    -- Validate GM rank
    if player:GetGMRank() < Config.MIN_GM_RANK then
        AIO.Handle(player, "GameMasterSystem", "reputationError", "Insufficient GM rank")
        return
    end

    local targetPlayer, error = GetTargetPlayerByName(player, targetName)
    if not targetPlayer then
        AIO.Handle(player, "GameMasterSystem", "reputationError", error)
        return
    end

    local currentRep = targetPlayer:GetReputation(factionId)
    local rank = targetPlayer:GetReputationRank(factionId)
    local factionInfo = FactionData.GetFaction(factionId)
    local standingName, standingData = FactionData.GetStandingFromValue(currentRep)

    AIO.Handle(player, "GameMasterSystem", "receivePlayerReputation", {
        targetName = targetPlayer:GetName(),
        factionId = factionId,
        factionName = factionInfo and factionInfo.name or "Unknown",
        currentRep = currentRep,
        rank = rank,
        standingName = standingName,
        standingMin = standingData.min,
        standingMax = standingData.max
    })
end

-- Set reputation for a specific faction (by player name)
function ReputationHandlers.setPlayerReputationByName(player, targetName, factionId, newValue)
    -- Wrap in pcall to catch any errors
    local success, errorMsg = pcall(function()
        print("[REP DEBUG] setPlayerReputationByName called: target=" .. tostring(targetName) .. ", faction=" .. tostring(factionId) .. ", value=" .. tostring(newValue))

        -- Validate GM rank
        if player:GetGMRank() < Config.MIN_GM_RANK then
            AIO.Handle(player, "GameMasterSystem", "reputationError", "Insufficient GM rank (need " .. Config.MIN_GM_RANK .. ", have " .. player:GetGMRank() .. ")")
            return
        end

        local targetPlayer, err = GetTargetPlayerByName(player, targetName)
        if not targetPlayer then
            print("[REP DEBUG] Target not found: " .. tostring(err))
            AIO.Handle(player, "GameMasterSystem", "reputationError", err)
            return
        end

        print("[REP DEBUG] Target found: " .. targetPlayer:GetName())

        -- Clamp value to valid range
        newValue = math.max(-42000, math.min(42999, newValue))

        -- Set the reputation
        print("[REP DEBUG] Setting reputation for faction " .. factionId .. " to " .. newValue)
        targetPlayer:SetReputation(factionId, newValue)

        -- Get updated values
        local currentRep = targetPlayer:GetReputation(factionId)
        local rank = targetPlayer:GetReputationRank(factionId)
        local factionInfo = FactionData.GetFaction(factionId)
        local standingName, standingData = FactionData.GetStandingFromValue(currentRep)

        print("[REP DEBUG] After set: currentRep=" .. tostring(currentRep) .. ", standing=" .. tostring(standingName))

        -- Log the action
        if Config.LOG_GM_ACTIONS and Utils and Utils.debug then
            Utils.debug("INFO", string.format(
                "[Reputation] %s set %s's reputation with %s (ID: %d) to %d (%s)",
                player:GetName(),
                targetPlayer:GetName(),
                factionInfo and factionInfo.name or "Unknown",
                factionId,
                newValue,
                standingName
            ))
        end

        -- Send confirmation back
        AIO.Handle(player, "GameMasterSystem", "reputationUpdateConfirmed", {
            success = true,
            targetName = targetPlayer:GetName(),
            factionId = factionId,
            factionName = factionInfo and factionInfo.name or "Unknown",
            currentRep = currentRep,
            rank = rank,
            standingName = standingName,
            standingMin = standingData.min,
            standingMax = standingData.max,
            message = string.format("Set %s to %s with %s",
                targetPlayer:GetName(), standingName,
                factionInfo and factionInfo.name or "Unknown")
        })
    end)

    if not success then
        print("[REP ERROR] " .. tostring(errorMsg))
        AIO.Handle(player, "GameMasterSystem", "reputationError", "Server error: " .. tostring(errorMsg))
    end
end

-- Set reputation for a specific faction
function ReputationHandlers.setPlayerReputation(player, targetGuid, factionId, newValue)
    -- Validate GM rank
    if player:GetGMRank() < Config.MIN_GM_RANK then
        AIO.Handle(player, "GameMasterSystem", "reputationError", "Insufficient GM rank")
        return
    end

    local targetPlayer, error = GetTargetPlayer(player, targetGuid)
    if not targetPlayer then
        AIO.Handle(player, "GameMasterSystem", "reputationError", error)
        return
    end

    -- Clamp value to valid range
    newValue = math.max(-42000, math.min(42999, newValue))

    -- Set the reputation
    targetPlayer:SetReputation(factionId, newValue)

    -- Get updated values
    local currentRep = targetPlayer:GetReputation(factionId)
    local rank = targetPlayer:GetReputationRank(factionId)
    local factionInfo = FactionData.GetFaction(factionId)
    local standingName, standingData = FactionData.GetStandingFromValue(currentRep)

    -- Log the action
    if Config.LOG_GM_ACTIONS then
        Utils.debug("INFO", string.format(
            "[Reputation] %s set %s's reputation with %s (ID: %d) to %d (%s)",
            player:GetName(),
            targetPlayer:GetName(),
            factionInfo and factionInfo.name or "Unknown",
            factionId,
            newValue,
            standingName
        ))
    end

    -- Send confirmation back
    AIO.Handle(player, "GameMasterSystem", "reputationUpdateConfirmed", {
        success = true,
        targetGuid = targetPlayer:GetGUIDLow(),
        targetName = targetPlayer:GetName(),
        factionId = factionId,
        factionName = factionInfo and factionInfo.name or "Unknown",
        currentRep = currentRep,
        rank = rank,
        standingName = standingName,
        standingMin = standingData.min,
        standingMax = standingData.max,
        message = string.format("Set %s to %s with %s",
            targetPlayer:GetName(), standingName,
            factionInfo and factionInfo.name or "Unknown")
    })
end

-- Get all faction data for client
function ReputationHandlers.getReputationData(player)
    -- Validate GM rank
    if player:GetGMRank() < Config.MIN_GM_RANK then
        return
    end

    -- Send serialized faction data to client
    local data = FactionData.SerializeForClient()
    AIO.Handle(player, "GameMasterSystem", "receiveReputationData", data)
end

-- Register handlers
function ReputationHandlers.RegisterHandlers(gmSystem, config, utils, database, dbHelper)
    -- Store dependencies
    GameMasterSystem = gmSystem
    Config = config
    Utils = utils
    Database = database
    DatabaseHelper = dbHelper

    -- Set minimum GM rank if not defined
    if not Config.MIN_GM_RANK then
        Config.MIN_GM_RANK = 2
    end

    -- Set logging flag if not defined
    if Config.LOG_GM_ACTIONS == nil then
        Config.LOG_GM_ACTIONS = true
    end

    -- Register AIO handlers
    GameMasterSystem.getPlayerReputation = ReputationHandlers.getPlayerReputation
    GameMasterSystem.setPlayerReputation = ReputationHandlers.setPlayerReputation
    GameMasterSystem.getReputationData = ReputationHandlers.getReputationData
    GameMasterSystem.getPlayerReputationByName = ReputationHandlers.getPlayerReputationByName
    GameMasterSystem.setPlayerReputationByName = ReputationHandlers.setPlayerReputationByName
end

return ReputationHandlers
