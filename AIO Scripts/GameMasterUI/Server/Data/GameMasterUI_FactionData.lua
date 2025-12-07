-- GameMaster UI System - Faction Data
-- Contains all faction IDs organized by expansion for reputation management
-- Data sourced from WoW 3.3.5 Faction.dbc

local FactionData = {}

-- Reputation standing thresholds
FactionData.STANDING = {
    HATED = { name = "Hated", min = -42000, max = -6001, color = {0.8, 0, 0} },
    HOSTILE = { name = "Hostile", min = -6000, max = -3001, color = {1, 0, 0} },
    UNFRIENDLY = { name = "Unfriendly", min = -3000, max = -1, color = {1, 0.5, 0} },
    NEUTRAL = { name = "Neutral", min = 0, max = 2999, color = {1, 1, 0} },
    FRIENDLY = { name = "Friendly", min = 3000, max = 8999, color = {0, 1, 0} },
    HONORED = { name = "Honored", min = 9000, max = 20999, color = {0, 1, 0.5} },
    REVERED = { name = "Revered", min = 21000, max = 41999, color = {0, 0.5, 1} },
    EXALTED = { name = "Exalted", min = 42000, max = 42999, color = {0.5, 0, 1} }
}

-- Standing presets for quick-set buttons (set to start of each standing)
FactionData.STANDING_PRESETS = {
    { name = "Hated", value = -42000 },
    { name = "Hostile", value = -6000 },
    { name = "Unfriendly", value = -3000 },
    { name = "Neutral", value = 0 },
    { name = "Friendly", value = 3000 },
    { name = "Honored", value = 9000 },
    { name = "Revered", value = 21000 },
    { name = "Exalted", value = 42000 }
}

-- Get standing name from reputation value
function FactionData.GetStandingFromValue(value)
    if value >= 42000 then return "Exalted", FactionData.STANDING.EXALTED
    elseif value >= 21000 then return "Revered", FactionData.STANDING.REVERED
    elseif value >= 9000 then return "Honored", FactionData.STANDING.HONORED
    elseif value >= 3000 then return "Friendly", FactionData.STANDING.FRIENDLY
    elseif value >= 0 then return "Neutral", FactionData.STANDING.NEUTRAL
    elseif value >= -3000 then return "Unfriendly", FactionData.STANDING.UNFRIENDLY
    elseif value >= -6000 then return "Hostile", FactionData.STANDING.HOSTILE
    else return "Hated", FactionData.STANDING.HATED
    end
end

-- All factions organized by expansion
FactionData.categories = {
    {
        name = "Classic",
        factions = {
            -- Alliance Cities
            { id = 72, name = "Stormwind" },
            { id = 47, name = "Ironforge" },
            { id = 69, name = "Darnassus" },
            { id = 54, name = "Gnomeregan Exiles" },

            -- Horde Cities
            { id = 76, name = "Orgrimmar" },
            { id = 68, name = "Undercity" },
            { id = 81, name = "Thunder Bluff" },
            { id = 530, name = "Darkspear Trolls" },

            -- Classic Neutral Factions
            { id = 529, name = "Argent Dawn" },
            { id = 87, name = "Bloodsail Buccaneers" },
            { id = 21, name = "Booty Bay" },
            { id = 910, name = "Brood of Nozdormu" },
            { id = 609, name = "Cenarion Circle" },
            { id = 909, name = "Darkmoon Faire" },
            { id = 270, name = "Everlook" },
            { id = 577, name = "Gadgetzan" },
            { id = 369, name = "Gadgetzan" },
            { id = 749, name = "Hydraxian Waterlords" },
            { id = 989, name = "Keepers of Time" },
            { id = 349, name = "Ravenholdt" },
            { id = 809, name = "Shen'dralar" },
            { id = 70, name = "Syndicate" },
            { id = 59, name = "Thorium Brotherhood" },
            { id = 576, name = "Timbermaw Hold" },
            { id = 92, name = "Gelkis Clan Centaur" },
            { id = 93, name = "Magram Clan Centaur" },
            { id = 270, name = "Zandalar Tribe" },

            -- Classic Alliance Factions
            { id = 730, name = "Stormpike Guard" },
            { id = 890, name = "Silverwing Sentinels" },
            { id = 509, name = "The League of Arathor" },

            -- Classic Horde Factions
            { id = 729, name = "Frostwolf Clan" },
            { id = 889, name = "Warsong Outriders" },
            { id = 510, name = "The Defilers" },

            -- Steamwheedle Cartel
            { id = 169, name = "Steamwheedle Cartel" },
            { id = 470, name = "Ratchet" },

            -- Classic Misc
            { id = 589, name = "Wintersaber Trainers" },
            { id = 349, name = "Ravenholdt" },
        }
    },
    {
        name = "The Burning Crusade",
        factions = {
            -- TBC Cities
            { id = 930, name = "Exodar" },
            { id = 911, name = "Silvermoon City" },

            -- Outland Factions
            { id = 932, name = "The Aldor" },
            { id = 934, name = "The Scryers" },
            { id = 935, name = "The Sha'tar" },
            { id = 1011, name = "Lower City" },
            { id = 933, name = "The Consortium" },
            { id = 942, name = "Cenarion Expedition" },
            { id = 970, name = "Sporeggar" },
            { id = 978, name = "Kurenai" },
            { id = 941, name = "The Mag'har" },
            { id = 1015, name = "Netherwing" },
            { id = 1038, name = "Ogri'la" },
            { id = 1031, name = "Sha'tari Skyguard" },

            -- TBC Raid Factions
            { id = 990, name = "The Scale of the Sands" },
            { id = 1012, name = "Ashtongue Deathsworn" },
            { id = 967, name = "The Violet Eye" },

            -- TBC PvP Factions
            { id = 946, name = "Honor Hold" },
            { id = 947, name = "Thrallmar" },

            -- Shattrath City
            { id = 1077, name = "Shattered Sun Offensive" },
        }
    },
    {
        name = "Wrath of the Lich King",
        factions = {
            -- WotLK Alliance Factions
            { id = 1037, name = "Alliance Vanguard" },
            { id = 1050, name = "Valiance Expedition" },
            { id = 1068, name = "Explorers' League" },
            { id = 1126, name = "The Frostborn" },
            { id = 1094, name = "The Silver Covenant" },

            -- WotLK Horde Factions
            { id = 1052, name = "Horde Expedition" },
            { id = 1067, name = "The Hand of Vengeance" },
            { id = 1064, name = "The Taunka" },
            { id = 1085, name = "Warsong Offensive" },
            { id = 1124, name = "The Sunreavers" },

            -- WotLK Neutral Factions
            { id = 1090, name = "Kirin Tor" },
            { id = 1091, name = "The Wyrmrest Accord" },
            { id = 1098, name = "Knights of the Ebon Blade" },
            { id = 1106, name = "Argent Crusade" },
            { id = 1073, name = "The Kalu'ak" },
            { id = 1119, name = "The Sons of Hodir" },
            { id = 1104, name = "Frenzyheart Tribe" },
            { id = 1105, name = "The Oracles" },

            -- WotLK Raid Factions
            { id = 1156, name = "The Ashen Verdict" },

            -- WotLK PvP Factions
            { id = 1172, name = "Wintergrasp - Alliance" },
            { id = 1174, name = "Wintergrasp - Horde" },
        }
    },
    {
        name = "All Factions",
        factions = {} -- Will be populated below
    }
}

-- Build lookup table by faction ID
FactionData.byId = {}
for _, category in ipairs(FactionData.categories) do
    if category.name ~= "All Factions" then
        for _, faction in ipairs(category.factions) do
            FactionData.byId[faction.id] = {
                id = faction.id,
                name = faction.name,
                category = category.name
            }
        end
    end
end

-- Populate "All Factions" category
local allFactions = {}
for id, faction in pairs(FactionData.byId) do
    table.insert(allFactions, { id = faction.id, name = faction.name })
end
table.sort(allFactions, function(a, b) return a.name < b.name end)
FactionData.categories[4].factions = allFactions

-- Get faction by ID
function FactionData.GetFaction(factionId)
    return FactionData.byId[factionId]
end

-- Get factions by category name
function FactionData.GetFactionsByCategory(categoryName)
    for _, category in ipairs(FactionData.categories) do
        if category.name == categoryName then
            return category.factions
        end
    end
    return {}
end

-- Get all category names
function FactionData.GetCategoryNames()
    local names = {}
    for _, category in ipairs(FactionData.categories) do
        table.insert(names, category.name)
    end
    return names
end

-- Serialize faction data for client transfer
function FactionData.SerializeForClient()
    return {
        categories = FactionData.categories,
        standingPresets = FactionData.STANDING_PRESETS
    }
end

return FactionData
