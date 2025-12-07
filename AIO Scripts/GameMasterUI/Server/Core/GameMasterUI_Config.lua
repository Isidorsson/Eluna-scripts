-- Load constants module
local Constants = require("GameMasterUI.Server.Core.GameMasterUI_Constants")

-- Auto-detect the core using Eluna API
local function detectCore()
    local coreName = GetCoreName()
    if coreName then
        return coreName
    else
        return "TrinityCore"
    end
end

-- Auto-configure database names based on detected core
local function getDefaultDatabaseNames(coreName)
    if coreName == "AzerothCore" then
        return {
            world = "acore_world",
            characters = "acore_characters",
            auth = "acore_auth"
        }
    else
        -- TrinityCore and unknown cores use default names
        return {
            world = "world",
            characters = "characters",
            auth = "auth"
        }
    end
end

-- Detect core and get default database names
local detectedCore = detectCore()
local defaultDatabaseNames = getDefaultDatabaseNames(detectedCore)

local config = {
    -- =====================================================
    -- Core Settings
    -- =====================================================

    -- Core detection information
    core = {
        name = detectedCore,
        autoDetected = true
    },

    -- =====================================================
    -- Feature Configuration
    -- =====================================================

    -- Enable debug logging (prints detailed information to console)
    debug = false,

    -- GM level required to use GameMasterUI (default: 2)
    REQUIRED_GM_LEVEL = 2,

    -- Default number of results per page in search/list views
    defaultPageSize = 100,

    -- Remove player from world when opening GameMasterUI
    -- (prevents interference while managing server)
    removeFromWorld = true,

    -- =====================================================
    -- Logging Configuration
    -- =====================================================

    -- Log level constants (used throughout the addon)
    LOG_LEVEL = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4
    },

    -- =====================================================
    -- Database Configuration
    -- =====================================================

    database = {
        -- Database names configuration
        -- Simply specify your database names here - the addon will handle the rest
        --
        -- AUTO-DETECTION:
        -- The system automatically detects your core and sets appropriate defaults:
        -- - TrinityCore: world, characters, auth
        -- - AzerothCore: acore_world, acore_characters, acore_auth
        --
        -- MANUAL OVERRIDE:
        -- Edit the values below to match your database names.
        -- Just replace with your actual database name - no dots or prefixes needed!
        --
        -- EXAMPLES:
        -- Standard TrinityCore:
        --   world = "world"
        --   characters = "characters"
        --   auth = "auth"
        --
        -- Standard AzerothCore:
        --   world = "acore_world"
        --   characters = "acore_characters"
        --   auth = "acore_auth"
        --
        -- Custom production server:
        --   world = "prod_world_335"
        --   characters = "prod_characters"
        --   auth = "prod_auth"
        --
        -- Custom naming:
        --   world = "myserver_world"
        --   characters = "myserver_chars"
        --   auth = "myserver_accounts"
        --
        names = defaultDatabaseNames,

        -- Optional tables that won't cause errors if missing
        -- DBC-imported tables: gameobjectdisplayinfo, spellvisual, spellvisualkit, spellvisualeffectname
        optionalTables = {
            "gameobjectdisplayinfo",
            "spellvisual",
            "spellvisualkit",
            "spellvisualeffectname",
            "creature_template_model",
            "creature_equip_template",
            "creature_template_addon",
            "gameobject_template_addon",
            "item_enchantment_template",
            "item_loot_template"
        },

        -- Required tables that will show warnings if missing
        requiredTables = {
            "creature_template",
            "gameobject_template",
            "item_template",
            "spell"
        },

        -- Fallback behavior when tables are missing
        fallbackOnMissingTable = true,

        -- Check table existence on startup (recommended)
        checkTablesOnStartup = true,

        -- Cache table existence checks for performance
        cacheTableChecks = true,

        -- Async query configuration
        -- Enable asynchronous database queries for better performance
        -- When enabled, uses WorldDBQueryAsync, CharDBQueryAsync, AuthDBQueryAsync
        -- When disabled, falls back to synchronous queries (WorldDBQuery, etc.)
        enableAsync = true,

        -- Async query timeout in milliseconds (for future use)
        asyncTimeout = 30000,
    },
}

-- =====================================================
-- Module Export
-- =====================================================

-- Add references to constants for backward compatibility
-- These are WoW game constants and should not be modified by users
config.npcTypes = Constants.NPC_TYPES
config.gameObjectTypes = Constants.GAMEOBJECT_TYPES

-- Export the configuration
return config
