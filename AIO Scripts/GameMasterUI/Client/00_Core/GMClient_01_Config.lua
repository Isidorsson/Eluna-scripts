-- GameMaster UI System - Configuration
-- This file contains all configuration constants and settings
-- Load order: 01 (Second)

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return
end

-- Verify namespace exists
local GameMasterSystem = _G.GameMasterSystem
if not GameMasterSystem then
    print("[ERROR] GameMasterSystem namespace not found! Check load order.")
    return
end

local GMConfig = _G.GMConfig

-- Main configuration object
GMConfig.config = {
    debug = false, -- Set to true for debugging model loading (TEMPORARY - set to false in production)
    REQUIRED_GM_LEVEL = 2,
    autoOpenObjectEditor = true, -- Auto-open editor after spawning GameObject
    
    -- GitHub repository for issue reporting
    githubRepo = "Isidorsson/Eluna-scripts", -- Your GitHub repository for issue tracking
    
    -- Legacy properties for backward compatibility
    BG_WIDTH = 900,
    BG_HEIGHT = 650,
    PAGE_SIZE = 15,
    NUM_COLUMNS = 5,
    NUM_ROWS = 3,
    
    -- Responsive sizing
    ui = {
        width = {
            min = 700,
            default = 900,
            max = 1200,
        },
        height = {
            min = 500,
            default = 650,
            max = 900,
        },
        padding = 10,
        spacing = 5,
    },
    
    -- Grid layout
    grid = {
        columns = {
            small = 3,
            medium = 4,
            large = 5,
        },
        rows = 3,
        pageSize = 15,
    },
    
    -- Performance
    performance = {
        modelPoolSize = 15,
        cacheTimeout = 300, -- 5 minutes
        batchSize = 50,
    },
}

-- Responsive helper functions
function GMConfig.config.getResponsiveColumns(width)
    if width < 800 then
        return GMConfig.config.grid.columns.small
    elseif width < 1050 then
        return GMConfig.config.grid.columns.medium
    else
        return GMConfig.config.grid.columns.large
    end
end

function GMConfig.config.getPageSize(width)
    local columns = GMConfig.config.getResponsiveColumns(width)
    return columns * GMConfig.config.grid.rows
end

-- Menu configuration
GMConfig.MENU_CONFIG = {
    SIZE = {
        WIDTH = 150,
        HEIGHT = 200,
    },
    CONFIRM_DIALOG = {
        TIMEOUT = 0,
        PREFERRED_INDEX = 3,
    },
    TYPES = {
        NPC = "npc",
        GAMEOBJECT = "gameobject",
        SPELL = "spell",
        SPELLVISUAL = "spellvisual",
        ITEM = "item",
    },
    DROPDOWN = {
        MAX_DEPTH = 10,
        DEFAULT_LEVEL = 1,
        ITEM = {
            WIDTH = 180,
            MIN_WIDTH = 120,
            PADDING = 20,
            TEXT_OFFSET = 5,
        },
    },
}

-- Sort options for dropdowns
GMConfig.sortOptions = {
    { text = "Ascending", value = "ASC" },
    { text = "Descending", value = "DESC" },
}

-- Menu items for tabs
GMConfig.menuItems = {
    {text = "Creatures", value = 1},
    {text = "Objects", value = 2},
    {text = "Spells", value = 3},
    {text = "Spell Visuals", value = 4},
    {text = "Items", value = 5},
}

-- Card types configuration
GMConfig.CardTypes = {
    NPC = {
        tabIndex = 1,
        dataKey = "npcData",
    },
    GameObject = {
        tabIndex = 2,
        dataKey = "gobData",
    },
    Spell = {
        tabIndex = 3,
        dataKey = "spellData",
    },
    SpellVisual = {
        tabIndex = 4,
        dataKey = "spellVisualData",
    },
    Item = {
        tabIndex = 5,
        dataKey = "itemData",
        categories = {
            Equipment = {
                tabIndex = 100,
                subCategories = {
                    { index = 101, value = 1, name = "Head" },
                    { index = 102, value = 2, name = "Neck" },
                    { index = 103, value = 3, name = "Shoulder" },
                    { index = 104, value = 5, name = "Chest" },
                    { index = 105, value = 6, name = "Waist" },
                    { index = 106, value = 7, name = "Legs" },
                    { index = 107, value = 8, name = "Feet" },
                    { index = 108, value = 9, name = "Wrist" },
                    { index = 109, value = 10, name = "Hands" },
                    { index = 110, value = 11, name = "Finger" },
                    { index = 111, value = 12, name = "Trinket" },
                    { index = 112, value = 16, name = "Back" },
                },
            },
            Weapons = {
                tabIndex = 200,
                subCategories = {
                    { index = 201, value = 13, name = "One-Hand" },
                    { index = 202, value = 17, name = "Two-Hand" },
                    { index = 203, value = 21, name = "Main Hand" },
                    { index = 204, value = 22, name = "Off Hand" },
                    { index = 205, value = 14, name = "Shield" },
                    { index = 206, value = 15, name = "Ranged" },
                    { index = 207, value = 25, name = "Thrown" },
                    { index = 208, value = 26, name = "Ranged Right" },
                    { index = 209, value = 23, name = "Holdable" },
                },
            },
            Misc = {
                tabIndex = 300,
                subCategories = {
                    { index = 301, value = 0, name = "Non-equip" },
                    { index = 302, value = 4, name = "Shirt" },
                    { index = 303, value = 18, name = "Bag" },
                    { index = 304, value = 19, name = "Tabard" },
                    { index = 305, value = 20, name = "Robe" },
                    { index = 306, value = 24, name = "Ammo" },
                    { index = 307, value = 28, name = "Quiver" },
                    { index = 308, value = 29, name = "Relic" },
                    { index = 309, value = -1, name = "All Items" },
                },
            },
        },
    },
    Player = {
        tabIndex = 6,
        dataKey = "playerData",
    },
}

-- Tab types enumeration
GMConfig.TAB_TYPES = {
    CREATURE = 1,
    OBJECT = 2,
    SPELL = 3,
    SPELL_VISUAL = 4,
    ITEM = {
        ALL = 5,
        CATEGORY = 50,
    },
    PLAYER = 6,
    GM_POWERS = 7,
    REPUTATION = 8,
}

-- Model configuration
GMConfig.MODEL_CONFIG = {
    INTERACTION = {
        ROTATION_SPEED = 0.02,
        POSITION_SPEED = 5,
        SCALE_SPEED = 0.1,
        INITIAL_FACING = -0.4,
        MIN_SCALE = 0.1,
        MAX_SCALE = 10,
    },
    ITEM = {
        MIN_Z = -2,
        MAX_Z = 10,
        INITIAL_SCALE = 1.5,
        INITIAL_Z = 0,
    },
}

-- View configuration
GMConfig.VIEW_CONFIG = {
    MODEL_SIZE = 500,
    TITLE_HEIGHT = 40,
    BUTTON_SIZE = 30,
    PADDING = 10,
    BG_ALPHA = 0.9,
}

-- Button tooltips
GMConfig.BUTTON_CONFIG = {
    INFO_TOOLTIP = {
        TITLE = "Model Controls",
        TEXT = "Left-Click + Drag: Rotate\nRight-Click + Drag: Move\nMouse Wheel: Scale",
    },
}

-- Item quality colors (matching WoW standards)
GMConfig.QUALITY_COLORS = {
    [0] = { 0.5, 0.5, 0.5 },    -- Poor (Gray)
    [1] = { 1, 1, 1 },          -- Common (White)
    [2] = { 0.12, 1, 0 },       -- Uncommon (Green)
    [3] = { 0, 0.44, 0.87 },    -- Rare (Blue)
    [4] = { 0.64, 0.21, 0.93 }, -- Epic (Purple)
    [5] = { 1, 0.5, 0 },        -- Legendary (Orange)
    [6] = { 0.89, 0.8, 0.5 },   -- Artifact (Light Gold)
    [7] = { 0, 0.8, 1 },        -- Heirloom (Light Blue)
}

-- Context menu color scheme (unused - colors handled by UIStyle system)
--[[
GMConfig.MENU_COLORS = {
    TITLE = "|cFFFFD700",           -- Gold for titles (Creature ID, Item ID, etc.)
    ACTION = "|cFF00FF00",          -- Green for standard actions (Edit Nearby, Edit Selected)
    TEMPLATE = "|cFFFFD700",        -- Gold for template operations
    DUPLICATE = "|cFF00FFFF",       -- Cyan for duplicate operations
    DANGER = "|cFFFF0000",          -- Red for dangerous operations (Delete)
    DISABLED = "|cFF888888",        -- Gray for disabled/info items
    REFRESH = "|cFF00FFFF",         -- Cyan for refresh options
    RESET = "|r",                   -- Reset color
}
--]]

-- Buff/Aura configuration for player management
GMConfig.BUFF_CONFIG = {
    -- Common stat buffs (verified for 3.3.5)
    STATS = {
        { spellId = 48161, name = "Power Word: Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
        { spellId = 48073, name = "Divine Spirit", icon = "Interface\\Icons\\Spell_Holy_DivineSpirit" },
        { spellId = 48469, name = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { spellId = 48932, name = "Blessing of Might", icon = "Interface\\Icons\\Spell_Holy_FistsOfFury" },
        { spellId = 48936, name = "Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom" },
        { spellId = 25898, name = "Greater Blessing of Kings", icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings" },
        { spellId = 25894, name = "Greater Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom" },
        { spellId = 48170, name = "Prayer of Fortitude", icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude" },
        { spellId = 61316, name = "Dalaran Brilliance", icon = "Interface\\Icons\\Spell_Holy_ArcaneIntellect" },
        { spellId = 43017, name = "Amplify Magic", icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
    },
    
    -- Speed and movement buffs
    MOVEMENT = {
        { spellId = 2983, name = "Sprint", icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
        { spellId = 3714, name = "Path of Frost", icon = "Interface\\Icons\\Spell_DeathKnight_PathOfFrost" },
        { spellId = 546, name = "Water Walking", icon = "Interface\\Icons\\Spell_Frost_WindWalkOn" },
        { spellId = 1706, name = "Levitate", icon = "Interface\\Icons\\Spell_Holy_LayOnHands" },
        { spellId = 33943, name = "Flight Form", icon = "Interface\\Icons\\Ability_Druid_FlightForm" },
        { spellId = 32223, name = "Crusader Aura", icon = "Interface\\Icons\\Spell_Holy_CrusaderAura" },
        { spellId = 54197, name = "Cold Weather Flying", icon = "Interface\\Icons\\Ability_Mount_SnowWhiteDragonMount" },
    },
    
    -- Utility buffs
    UTILITY = {
        { spellId = 1038, name = "Blessing of Salvation", icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation" },
        { spellId = 10060, name = "Power Infusion", icon = "Interface\\Icons\\Spell_Holy_PowerInfusion" },
        { spellId = 29166, name = "Innervate", icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { spellId = 54428, name = "Divine Plea", icon = "Interface\\Icons\\Spell_Holy_Aspiration" },
        { spellId = 64901, name = "Hymn of Hope", icon = "Interface\\Icons\\Spell_Holy_SymbolOfHope" },
        { spellId = 1126, name = "Mark of the Wild", icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { spellId = 20217, name = "Blessing of Kings", icon = "Interface\\Icons\\Spell_Magic_MageArmor" },
    },
    
    -- GM special buffs
    GM_SPECIAL = {
        { spellId = 1784, name = "Stealth (Rogue)", icon = "Interface\\Icons\\Ability_Stealth" },
        { spellId = 1856, name = "Vanish (Improved Stealth)", icon = "Interface\\Icons\\Ability_Vanish" },
        { spellId = 11392, name = "Invisibility (18 sec)", icon = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" },
        { spellId = 9454, name = "GM Freeze", icon = "Interface\\Icons\\Spell_Frost_FreezingBreath" },
        { spellId = 1499, name = "Freezing Trap", icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce" },
        { spellId = 11, name = "Frost Armor", icon = "Interface\\Icons\\Spell_Frost_FrostArmor02" },
        { spellId = 23451, name = "Speed (100% increase)", icon = "Interface\\Icons\\Spell_Holy_BlessingOfAgility" },
    },
    
    -- Healing spells that can be cast
    HEALING = {
        { spellId = 48782, name = "Greater Heal", icon = "Interface\\Icons\\Spell_Holy_Heal" },
        { spellId = 48785, name = "Flash Heal", icon = "Interface\\Icons\\Spell_Holy_FlashHeal" },
        { spellId = 48447, name = "Tranquility", icon = "Interface\\Icons\\Spell_Nature_Tranquility" },
        { spellId = 48068, name = "Renew", icon = "Interface\\Icons\\Spell_Holy_Renew" },
        { spellId = 48113, name = "Prayer of Mending", icon = "Interface\\Icons\\Spell_Holy_PrayerOfMendingtga" },
    },
}

-- Common spell categories for quick access
GMConfig.SPELL_CATEGORIES = {
    { name = "Stats Buffs", spells = GMConfig.BUFF_CONFIG.STATS },
    { name = "Movement", spells = GMConfig.BUFF_CONFIG.MOVEMENT },
    { name = "Utility", spells = GMConfig.BUFF_CONFIG.UTILITY },
    { name = "GM Special", spells = GMConfig.BUFF_CONFIG.GM_SPECIAL },
    { name = "Healing", spells = GMConfig.BUFF_CONFIG.HEALING },
}

-- Configuration loaded