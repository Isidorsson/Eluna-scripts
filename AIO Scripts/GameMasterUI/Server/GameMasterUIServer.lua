if GetStateMapId and GetStateMapId() ~= -1 then
    return
end

--[[
    GameMaster UI Server - Main Entry Point
    
    This is the main server file that loads all modules and initializes the GameMaster UI system.
    
    Module Structure:

    - Server
        - GameMasterUIServer.lua (this file) - Main entry point
    /Core/
        - GameMasterUI_Config.lua - Configuration and constants
        - GameMasterUI_Utils.lua - Utility functions (includes shared data tables)
        - GameMasterUI_Init.lua - Initialization and events
    - Server/Database/
        - GameMasterUI_Database.lua - Database queries
    - Server/Handlers/Entity/
        - GameMasterUI_EntityHandlers.lua - Entity spawn/delete handlers
        - GameMasterUI_ItemHandlers.lua - Item-related handlers
        - GameMasterUI_NPCHandlers.lua - NPC-related handlers
    - Server/Handlers/Player/
        - GameMasterUI_PlayerHandlers.lua - Core player management (959 lines)
        - GameMasterUI_PlayerSpellHandlers.lua - Spell management (968 lines)
        - GameMasterUI_PlayerInventoryHandlers.lua - Inventory management (847 lines)
        - GameMasterUI_PlayerMailHandlers.lua - Mail sending (191 lines)
        - GameMasterUI_PlayerBuffHandlers.lua - Buff/aura management (310 lines)
        - GameMasterUI_BanHandlers.lua - Ban management (457 lines)
]]--

-- Add the server directory to the package path
local scriptPath = debug.getinfo(1, "S").source:sub(2)
local scriptDir = scriptPath:match("(.*/)") or ""
package.path = package.path .. ";" .. scriptDir .. "?.lua"

-- Load AIO framework
local AIO = AIO or require("AIO")

-- Load modules in dependency order
local Config = require("GameMasterUI.Server.Core.GameMasterUI_Config")
local Utils = require("GameMasterUI.Server.Core.GameMasterUI_Utils")
local DatabaseHelper = require("GameMasterUI.Server.Core.GameMasterUI_DatabaseHelper")
local DatabaseErrorHelper = require("GameMasterUI.Server.Core.GameMasterUI_DatabaseErrorHelper")
local Database = require("GameMasterUI.Server.Database.GameMasterUI_Database")
local EntityHandlers = require("GameMasterUI.Server.Handlers.Entity.GameMasterUI_EntityHandlers")

-- Initialize DatabaseHelper and DatabaseErrorHelper
DatabaseHelper.Initialize(Config)
DatabaseErrorHelper.Initialize(Config, DatabaseHelper, Utils)

-- Initialize AIO handlers namespace
local GameMasterSystem = AIO.AddHandlers("GameMasterSystem", {})

-- Load handler modules that will populate GameMasterSystem
local ItemHandlers = require("GameMasterUI.Server.Handlers.Entity.GameMasterUI_ItemHandlers")
local NPCHandlers = require("GameMasterUI.Server.Handlers.Entity.GameMasterUI_NPCHandlers")

-- Load player-related handler modules
local PlayerHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_PlayerHandlers")
local PlayerSpellHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_PlayerSpellHandlers")
local PlayerInventoryHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_PlayerInventoryHandlers")
local PlayerMailHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_PlayerMailHandlers")
local PlayerBuffHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_PlayerBuffHandlers")
local BanHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_BanHandlers")

-- Load GM Powers handler module
local GMPowersHandlers = require("GameMasterUI.Server.Handlers.GMPowers.GameMasterUI_GMPowersHandlers")

-- Load Reputation handler module
local ReputationHandlers = require("GameMasterUI.Server.Handlers.Player.GameMasterUI_ReputationHandlers")

-- Load Teleport handler module
local TeleportHandlers = require("GameMasterUI.Server.Handlers.Teleport.GameMasterUI_TeleportHandlers")

-- Load ObjectEditor handler module
local ObjectEditorHandlers = require("GameMasterUI.Server.Handlers.Entity.GameMasterUI_ObjectEditorHandlers")

-- Load Template handler module
local TemplateHandlers = require("GameMasterUI.Server.Handlers.Template.GameMasterUI_TemplateHandlers")

-- Set up the handlers
ItemHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)
NPCHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Register player-related handlers
PlayerHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, EntityHandlers, DatabaseHelper)
PlayerSpellHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)
PlayerInventoryHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper, PlayerHandlers)
PlayerMailHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)
PlayerBuffHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)
BanHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Register GM Powers handlers
GMPowersHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Register Reputation handlers
ReputationHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Register Teleport handlers
TeleportHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper, DatabaseErrorHelper)

-- Register ObjectEditor handlers
ObjectEditorHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Register Template handlers
TemplateHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Register Report handlers (optional - for logging report attempts)
local ReportHandlers = require("GameMasterUI.Server.Handlers.GameMasterUI_ReportHandlers")
ReportHandlers.RegisterHandlers(GameMasterSystem, Config, Utils, Database, DatabaseHelper)

-- Initialize Unified Search Manager
local QueryUtils = require("GameMasterUI.Server.Utils.QueryUtils")
local SearchManagerInit = require("GameMasterUI.Server.Core.GameMasterUI_SearchManagerInit")
SearchManagerInit.Initialize(GameMasterSystem, Config, Utils, DatabaseHelper, QueryUtils)

-- Set cross-references between player sub-modules
if PlayerHandlers.SetSubModules then
    PlayerHandlers.SetSubModules(PlayerSpellHandlers, PlayerInventoryHandlers, PlayerMailHandlers, PlayerBuffHandlers)
end

-- Set cross-references between handlers after all are loaded
if ItemHandlers.SetPlayerHandlers then
    ItemHandlers.SetPlayerHandlers(PlayerHandlers)
end

-- Additional core handlers
function GameMasterSystem.handleGMLevel(player)
    local gmRank = player:GetGMRank()
    AIO.Handle(player, "GameMasterSystem", "receiveGmLevel", gmRank)
end

function GameMasterSystem.getCoreName(player)
    local coreName = GetCoreName()
    AIO.Handle(player, "GameMasterSystem", "receiveCoreName", coreName)
end

function GameMasterSystem.getTarget(player)
    local target = player:GetSelection()
    local isSelf = false

    if not target then
        Utils.sendMessage(player, "info", "No valid target selected. Defaulting to yourself.")
        target = player
        isSelf = true
    else
        Utils.sendMessage(player, "info", "Target selected: " .. target:GetName())
    end

    return target, isSelf
end

-- Entity action handler wrappers
function GameMasterSystem.spawnNpcEntity(player, entry)
    EntityHandlers.spawnNpcEntity(player, entry)
end

function GameMasterSystem.deleteNpcEntity(player, entry)
    EntityHandlers.deleteNpcEntity(player, entry)
end

function GameMasterSystem.morphNpcEntity(player, entry)
    EntityHandlers.morphNpcEntity(player, entry)
end

function GameMasterSystem.demorphNpcEntity(player)
    EntityHandlers.demorphNpcEntity(player)
end

function GameMasterSystem.spawnGameObject(player, entry)
    EntityHandlers.spawnGameObject(player, entry)
end

function GameMasterSystem.deleteGameObjectEntity(player, entry)
    EntityHandlers.deleteGameObjectEntity(player, entry)
end

function GameMasterSystem.spawnAndDeleteNpcEntity(player, entry)
    EntityHandlers.spawnAndDeleteNpcEntity(player, entry)
end

function GameMasterSystem.spawnAndDeleteGameObjectEntity(player, entry)
    EntityHandlers.spawnAndDeleteGameObjectEntity(player, entry)
end

function GameMasterSystem.duplicateNpcEntity(player, entry)
    return EntityHandlers.duplicateNpcEntity(player, entry)
end

function GameMasterSystem.duplicateGameObjectEntity(player, entry)
    return EntityHandlers.duplicateGameObjectEntity(player, entry)
end

function GameMasterSystem.duplicateItemEntity(player, entry)
    return EntityHandlers.duplicateItemEntity(player, entry)
end

-- Load initialization module (registers events)
local Init = require("GameMasterUI.Server.Core.GameMasterUI_Init")

-- Export the GameMasterSystem for potential external use
return GameMasterSystem