local DatabaseHelper = require("GameMasterUI.Server.Core.GameMasterUI_DatabaseHelper")

local queries = {
	TrinityCore = {
		loadCreatureDisplays = function()
			return [[
                SELECT `entry`, `name`, `subname`, `IconName`, `type_flags`, `type`, `family`, `rank`, `KillCredit1`, `KillCredit2`, `HealthModifier`, `ManaModifier`, `RacialLeader`, `MovementType`, `modelId1`, `modelId2`, `modelId3`, `modelId4`
                FROM `creature_template`
            ]]
		end,
		loadItemForPacket = function(itemEntry)
			return string.format(
				[[SELECT entry, class, subclass, name, displayid, Quality, Flags, FlagsExtra, 
				BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace,
				ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank,
				requiredspell, requiredhonorrank, RequiredCityRank,
				RequiredReputationFaction, RequiredReputationRank,
				maxcount, stackable, ContainerSlots,
				stat_type1, stat_value1, stat_type2, stat_value2,
				stat_type3, stat_value3, stat_type4, stat_value4,
				stat_type5, stat_value5, stat_type6, stat_value6,
				stat_type7, stat_value7, stat_type8, stat_value8,
				stat_type9, stat_value9, stat_type10, stat_value10,
				ScalingStatDistribution, ScalingStatValue,
				dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2,
				armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res,
				delay, ammo_type, RangedModRange,
				spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1,
				spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2,
				spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3,
				spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4,
				spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5,
				bonding, COALESCE(description, '') as description, PageText, LanguageID, PageMaterial,
				startquest, lockid, Material, sheath, RandomProperty, RandomSuffix,
				block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory,
				socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3,
				socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier,
				duration, ItemLimitCategory, HolidayId
				FROM item_template WHERE entry = %d;]],
				itemEntry
			)
		end,
		npcData = function(sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT entry, modelid1, modelid2, modelid3, modelid4, name, subname, type
                FROM creature_template
                WHERE modelid1 != 0 OR modelid2 != 0 OR modelid3 != 0 OR modelid4 != 0
                ORDER BY entry %s
                LIMIT %d OFFSET %d;
            ]],
				sortOrder,
				pageSize,
				offset
			)
		end,
		npcCount = function()
			return [[
                SELECT COUNT(*) 
                FROM creature_template
                WHERE modelid1 != 0 OR modelid2 != 0 OR modelid3 != 0 OR modelid4 != 0;
            ]]
		end,
		gobData = function(sortOrder, pageSize, offset)
			-- Check if gameobjectdisplayinfo table exists
			local hasDisplayInfo = DatabaseHelper.IsOptionalTableAvailable("gameobjectdisplayinfo", "world")
			
			if hasDisplayInfo then
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, m.ModelName
                FROM gameobject_template g
                LEFT JOIN gameobjectdisplayinfo m ON g.displayid = m.ID
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					sortOrder,
					pageSize,
					offset
				)
			else
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, 'N/A' as ModelName
                FROM gameobject_template g
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					sortOrder,
					pageSize,
					offset
				)
			end
		end,
		gobCount = function()
			-- Use simple count without join to avoid issues
			return [[
                SELECT COUNT(*) 
                FROM gameobject_template;
            ]]
		end,
		spellCount = function()
			return [[
                SELECT COUNT(*) 
                FROM spell;
            ]]
		end,
		spellData = function(sortOrder, pageSize, offset)
			return string.format(
				[[
            SELECT s.id, s.spellName0, s.spellDescription0, s.spellToolTip0, s.spellVisual1, s.spellVisual2,
                   s.EffectMiscValue1, s.EffectMiscValue2, s.EffectMiscValue3,
                   s.Effect1, s.Effect2, s.Effect3, s.schoolMask,
                   COALESCE(
                       cast1_base.FilePath, cast1_world.FilePath, cast1_special.FilePath,
                       impact1_base.FilePath, impact1_world.FilePath, impact1_special.FilePath,
                       state1_base.FilePath, state1_world.FilePath, state1_special.FilePath,
                       ''
                   ) as visualFilePath1,
                   COALESCE(
                       cast2_base.FilePath, cast2_world.FilePath, cast2_special.FilePath,
                       impact2_base.FilePath, impact2_world.FilePath, impact2_special.FilePath,
                       state2_base.FilePath, state2_world.FilePath, state2_special.FilePath,
                       ''
                   ) as visualFilePath2
            FROM spell s
            LEFT JOIN spellvisual sv1 ON s.SpellVisual1 = sv1.ID
            LEFT JOIN spellvisualkit cast1 ON sv1.CastKit = cast1.ID
            LEFT JOIN spellvisualeffectname cast1_base ON cast1.BaseEffect = cast1_base.ID
            LEFT JOIN spellvisualeffectname cast1_world ON cast1.WorldEffect = cast1_world.ID
            LEFT JOIN spellvisualeffectname cast1_special ON cast1.SpecialEffect1 = cast1_special.ID
            LEFT JOIN spellvisualkit impact1 ON sv1.ImpactKit = impact1.ID
            LEFT JOIN spellvisualeffectname impact1_base ON impact1.BaseEffect = impact1_base.ID
            LEFT JOIN spellvisualeffectname impact1_world ON impact1.WorldEffect = impact1_world.ID
            LEFT JOIN spellvisualeffectname impact1_special ON impact1.SpecialEffect1 = impact1_special.ID
            LEFT JOIN spellvisualkit state1 ON sv1.StateKit = state1.ID
            LEFT JOIN spellvisualeffectname state1_base ON state1.BaseEffect = state1_base.ID
            LEFT JOIN spellvisualeffectname state1_world ON state1.WorldEffect = state1_world.ID
            LEFT JOIN spellvisualeffectname state1_special ON state1.SpecialEffect1 = state1_special.ID
            LEFT JOIN spellvisual sv2 ON s.SpellVisual2 = sv2.ID
            LEFT JOIN spellvisualkit cast2 ON sv2.CastKit = cast2.ID
            LEFT JOIN spellvisualeffectname cast2_base ON cast2.BaseEffect = cast2_base.ID
            LEFT JOIN spellvisualeffectname cast2_world ON cast2.WorldEffect = cast2_world.ID
            LEFT JOIN spellvisualeffectname cast2_special ON cast2.SpecialEffect1 = cast2_special.ID
            LEFT JOIN spellvisualkit impact2 ON sv2.ImpactKit = impact2.ID
            LEFT JOIN spellvisualeffectname impact2_base ON impact2.BaseEffect = impact2_base.ID
            LEFT JOIN spellvisualeffectname impact2_world ON impact2.WorldEffect = impact2_world.ID
            LEFT JOIN spellvisualeffectname impact2_special ON impact2.SpecialEffect1 = impact2_special.ID
            LEFT JOIN spellvisualkit state2 ON sv2.StateKit = state2.ID
            LEFT JOIN spellvisualeffectname state2_base ON state2.BaseEffect = state2_base.ID
            LEFT JOIN spellvisualeffectname state2_world ON state2.WorldEffect = state2_world.ID
            LEFT JOIN spellvisualeffectname state2_special ON state2.SpecialEffect1 = state2_special.ID
            ORDER BY s.id %s
            LIMIT %d OFFSET %d;
            ]],
				sortOrder,
				pageSize,
				offset
			)
		end,
		searchNpcData = function(query, typeId, sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT entry, modelid1, modelid2, modelid3, modelid4, name, subname, type
                FROM creature_template
                WHERE name LIKE '%%%s%%' OR subname LIKE '%%%s%%' OR entry LIKE '%%%s%%' %s
                ORDER BY entry %s
                LIMIT %d OFFSET %d;
            ]],
				query,
				query,
				query,
				typeId and string.format("OR type = %d", typeId) or "",
				sortOrder,
				pageSize,
				offset * pageSize
			)
		end,
		searchGobData = function(query, typeId, sortOrder, pageSize, offset)
			-- Check if gameobjectdisplayinfo table exists
			local hasDisplayInfo = DatabaseHelper.IsOptionalTableAvailable("gameobjectdisplayinfo", "world")
			
			if hasDisplayInfo then
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, g.type, m.ModelName
                FROM gameobject_template g
                LEFT JOIN gameobjectdisplayinfo m ON g.displayid = m.ID
                WHERE g.name LIKE '%%%s%%' OR g.entry LIKE '%%%s%%' %s
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					query,
					query,
					typeId and string.format("OR g.type = %d", typeId) or "",
					sortOrder,
					pageSize,
					offset * pageSize
				)
			else
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, g.type, 'N/A' as ModelName
                FROM gameobject_template g
                WHERE g.name LIKE '%%%s%%' OR g.entry LIKE '%%%s%%' %s
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					query,
					query,
					typeId and string.format("OR g.type = %d", typeId) or "",
					sortOrder,
					pageSize,
					offset * pageSize
				)
			end
		end,
		searchSpellData = function(query, sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT s.id, s.spellName0, s.spellDescription0, s.spellToolTip0, s.spellVisual1, s.spellVisual2,
                       s.EffectMiscValue1, s.EffectMiscValue2, s.EffectMiscValue3,
                       s.Effect1, s.Effect2, s.Effect3, s.schoolMask,
                       COALESCE(
                           cast1_base.FilePath, cast1_world.FilePath, cast1_special.FilePath,
                           impact1_base.FilePath, impact1_world.FilePath, impact1_special.FilePath,
                           state1_base.FilePath, state1_world.FilePath, state1_special.FilePath,
                           ''
                       ) as visualFilePath1,
                       COALESCE(
                           cast2_base.FilePath, cast2_world.FilePath, cast2_special.FilePath,
                           impact2_base.FilePath, impact2_world.FilePath, impact2_special.FilePath,
                           state2_base.FilePath, state2_world.FilePath, state2_special.FilePath,
                           ''
                       ) as visualFilePath2
                FROM spell s
                LEFT JOIN spellvisual sv1 ON s.SpellVisual1 = sv1.ID
                LEFT JOIN spellvisualkit cast1 ON sv1.CastKit = cast1.ID
                LEFT JOIN spellvisualeffectname cast1_base ON cast1.BaseEffect = cast1_base.ID
                LEFT JOIN spellvisualeffectname cast1_world ON cast1.WorldEffect = cast1_world.ID
                LEFT JOIN spellvisualeffectname cast1_special ON cast1.SpecialEffect1 = cast1_special.ID
                LEFT JOIN spellvisualkit impact1 ON sv1.ImpactKit = impact1.ID
                LEFT JOIN spellvisualeffectname impact1_base ON impact1.BaseEffect = impact1_base.ID
                LEFT JOIN spellvisualeffectname impact1_world ON impact1.WorldEffect = impact1_world.ID
                LEFT JOIN spellvisualeffectname impact1_special ON impact1.SpecialEffect1 = impact1_special.ID
                LEFT JOIN spellvisualkit state1 ON sv1.StateKit = state1.ID
                LEFT JOIN spellvisualeffectname state1_base ON state1.BaseEffect = state1_base.ID
                LEFT JOIN spellvisualeffectname state1_world ON state1.WorldEffect = state1_world.ID
                LEFT JOIN spellvisualeffectname state1_special ON state1.SpecialEffect1 = state1_special.ID
                LEFT JOIN spellvisual sv2 ON s.SpellVisual2 = sv2.ID
                LEFT JOIN spellvisualkit cast2 ON sv2.CastKit = cast2.ID
                LEFT JOIN spellvisualeffectname cast2_base ON cast2.BaseEffect = cast2_base.ID
                LEFT JOIN spellvisualeffectname cast2_world ON cast2.WorldEffect = cast2_world.ID
                LEFT JOIN spellvisualeffectname cast2_special ON cast2.SpecialEffect1 = cast2_special.ID
                LEFT JOIN spellvisualkit impact2 ON sv2.ImpactKit = impact2.ID
                LEFT JOIN spellvisualeffectname impact2_base ON impact2.BaseEffect = impact2_base.ID
                LEFT JOIN spellvisualeffectname impact2_world ON impact2.WorldEffect = impact2_world.ID
                LEFT JOIN spellvisualeffectname impact2_special ON impact2.SpecialEffect1 = impact2_special.ID
                LEFT JOIN spellvisualkit state2 ON sv2.StateKit = state2.ID
                LEFT JOIN spellvisualeffectname state2_base ON state2.BaseEffect = state2_base.ID
                LEFT JOIN spellvisualeffectname state2_world ON state2.WorldEffect = state2_world.ID
                LEFT JOIN spellvisualeffectname state2_special ON state2.SpecialEffect1 = state2_special.ID
                WHERE s.spellName0 LIKE '%%%s%%' OR s.id LIKE '%%%s%%'
                ORDER BY s.id %s
                LIMIT %d OFFSET %d;
            ]],
				query,
				query,
				sortOrder,
				pageSize,
				offset * pageSize
			)
		end,
		spellVisualCount = function()
			return [[
                SELECT COUNT(*) 
                FROM spellvisualeffectname;
            ]]
		end,

		spellVisualData = function(sortOrder, pageSize, offset)
			return string.format(
				[[
            SELECT ID, Name, FilePath, AreaEffectSize, Scale, MinAllowedScale, MaxAllowedScale
            FROM spellvisualeffectname
            ORDER BY ID %s
            LIMIT %d OFFSET %d;
            ]],
				sortOrder,
				pageSize,
				offset
			)
		end,
		searchSpellVisualData = function(query, sortOrder, pageSize, offset)
			return string.format(
				[[
            SELECT ID, Name, FilePath, AreaEffectSize, Scale, MinAllowedScale, MaxAllowedScale
            FROM spellvisualeffectname
            WHERE Name LIKE '%%%s%%' OR ID LIKE '%%%s%%'
            ORDER BY ID %s
            LIMIT %d OFFSET %d;
            ]],
				query,
				query,
				sortOrder,
				pageSize,
				offset * pageSize
			)
		end,
		itemCount = function(inventoryType)
			if inventoryType and inventoryType >= 0 then
				return string.format([[
                    SELECT COUNT(*) 
                    FROM item_template
                    WHERE InventoryType = %d;
                ]], inventoryType)
			else
				return [[
                    SELECT COUNT(*) 
                    FROM item_template;
                ]]
			end
		end,
		itemData = function(sortOrder, pageSize, offset, inventoryType)
			local whereClause = ""
			if inventoryType then
				whereClause = string.format("WHERE InventoryType = %d", inventoryType)
			end

			return string.format(
				[[SELECT entry, name, COALESCE(description, ''), displayid, Quality, InventoryType, ItemLevel, class, subclass
				FROM item_template
				%s
				ORDER BY entry %s
				LIMIT %d OFFSET %d;]],
				whereClause,
				sortOrder,
				pageSize,
				offset
			)
		end,

		searchItemData = function(query, sortOrder, pageSize, offset, inventoryType)
			local whereClause = [[WHERE (name LIKE '%%%s%%' OR entry LIKE '%%%s%%')]]
			if inventoryType then
				whereClause = whereClause .. string.format(" AND InventoryType = %d", inventoryType)
			end

			return string.format(
				[[SELECT entry, name, COALESCE(description, ''), displayid, Quality, InventoryType, ItemLevel, class, subclass
				FROM item_template
				%s
				ORDER BY entry %s
				LIMIT %d OFFSET %d;]],
				string.format(whereClause, query, query),
				sortOrder,
				pageSize,
				offset
			)
		end,
	},
	AzerothCore = {
		loadCreatureDisplays = function()
			return [[
                SELECT ct.`entry`, ct.`name`, ct.`subname`, ct.`IconName`, ct.`type_flags`, ct.`type`, ct.`family`, ct.`rank`, ct.`KillCredit1`, ct.`KillCredit2`, ct.`HealthModifier`, ct.`ManaModifier`, ct.`RacialLeader`, ct.`MovementType`, ctm.`CreatureDisplayID`
                FROM `creature_template` ct
                LEFT JOIN `creature_template_model` ctm ON ct.`entry` = ctm.`CreatureID`
            ]]
		end,
		loadItemForPacket = function(itemEntry)
			return string.format(
				[[SELECT entry, class, subclass, name, displayid, Quality, Flags, FlagsExtra, 
				BuyPrice, SellPrice, InventoryType, AllowableClass, AllowableRace,
				ItemLevel, RequiredLevel, RequiredSkill, RequiredSkillRank,
				requiredspell, requiredhonorrank, RequiredCityRank,
				RequiredReputationFaction, RequiredReputationRank,
				maxcount, stackable, ContainerSlots,
				stat_type1, stat_value1, stat_type2, stat_value2,
				stat_type3, stat_value3, stat_type4, stat_value4,
				stat_type5, stat_value5, stat_type6, stat_value6,
				stat_type7, stat_value7, stat_type8, stat_value8,
				stat_type9, stat_value9, stat_type10, stat_value10,
				ScalingStatDistribution, ScalingStatValue,
				dmg_min1, dmg_max1, dmg_type1, dmg_min2, dmg_max2, dmg_type2,
				armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res,
				delay, ammo_type, RangedModRange,
				spellid_1, spelltrigger_1, spellcharges_1, spellppmRate_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1,
				spellid_2, spelltrigger_2, spellcharges_2, spellppmRate_2, spellcooldown_2, spellcategory_2, spellcategorycooldown_2,
				spellid_3, spelltrigger_3, spellcharges_3, spellppmRate_3, spellcooldown_3, spellcategory_3, spellcategorycooldown_3,
				spellid_4, spelltrigger_4, spellcharges_4, spellppmRate_4, spellcooldown_4, spellcategory_4, spellcategorycooldown_4,
				spellid_5, spelltrigger_5, spellcharges_5, spellppmRate_5, spellcooldown_5, spellcategory_5, spellcategorycooldown_5,
				bonding, COALESCE(description, '') as description, PageText, LanguageID, PageMaterial,
				startquest, lockid, Material, sheath, RandomProperty, RandomSuffix,
				block, itemset, MaxDurability, area, Map, BagFamily, TotemCategory,
				socketColor_1, socketContent_1, socketColor_2, socketContent_2, socketColor_3, socketContent_3,
				socketBonus, GemProperties, RequiredDisenchantSkill, ArmorDamageModifier,
				duration, ItemLimitCategory, HolidayId
				FROM item_template WHERE entry = %d;]],
				itemEntry
			)
		end,
		npcData = function(sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT ct.entry, ctm.CreatureDisplayID, ct.name, ct.subname, ct.type
                FROM creature_template ct
                LEFT JOIN creature_template_model ctm ON ct.entry = ctm.CreatureID
                ORDER BY ct.entry %s
                LIMIT %d OFFSET %d;
            ]],
				sortOrder,
				pageSize,
				offset
			)
		end,
		gobData = function(sortOrder, pageSize, offset)
			-- Check if gameobjectdisplayinfo table exists
			local hasDisplayInfo = DatabaseHelper.IsOptionalTableAvailable("gameobjectdisplayinfo", "world")
			
			if hasDisplayInfo then
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, m.ModelName
                FROM gameobject_template g
                LEFT JOIN gameobjectdisplayinfo m ON g.displayid = m.ID
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					sortOrder,
					pageSize,
					offset
				)
			else
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, 'N/A' as ModelName
                FROM gameobject_template g
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					sortOrder,
					pageSize,
					offset
				)
			end
		end,
		gobCount = function()
			-- Use simple count without join to avoid issues
			return [[
                SELECT COUNT(*) 
                FROM gameobject_template;
            ]]
		end,
		spellCount = function()
			return [[
                SELECT COUNT(*) 
                FROM spell;
            ]]
		end,
		spellData = function(sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT s.id, s.spellName0, s.spellDescription0, s.spellToolTip0, s.spellVisual1, s.spellVisual2,
                       s.EffectMiscValue1, s.EffectMiscValue2, s.EffectMiscValue3,
                       s.Effect1, s.Effect2, s.Effect3, s.schoolMask,
                       COALESCE(
                           cast1_base.FilePath, cast1_world.FilePath, cast1_special.FilePath,
                           impact1_base.FilePath, impact1_world.FilePath, impact1_special.FilePath,
                           state1_base.FilePath, state1_world.FilePath, state1_special.FilePath,
                           ''
                       ) as visualFilePath1,
                       COALESCE(
                           cast2_base.FilePath, cast2_world.FilePath, cast2_special.FilePath,
                           impact2_base.FilePath, impact2_world.FilePath, impact2_special.FilePath,
                           state2_base.FilePath, state2_world.FilePath, state2_special.FilePath,
                           ''
                       ) as visualFilePath2
                FROM spell s
                LEFT JOIN spellvisual sv1 ON s.SpellVisual1 = sv1.ID
                LEFT JOIN spellvisualkit cast1 ON sv1.CastKit = cast1.ID
                LEFT JOIN spellvisualeffectname cast1_base ON cast1.BaseEffect = cast1_base.ID
                LEFT JOIN spellvisualeffectname cast1_world ON cast1.WorldEffect = cast1_world.ID
                LEFT JOIN spellvisualeffectname cast1_special ON cast1.SpecialEffect1 = cast1_special.ID
                LEFT JOIN spellvisualkit impact1 ON sv1.ImpactKit = impact1.ID
                LEFT JOIN spellvisualeffectname impact1_base ON impact1.BaseEffect = impact1_base.ID
                LEFT JOIN spellvisualeffectname impact1_world ON impact1.WorldEffect = impact1_world.ID
                LEFT JOIN spellvisualeffectname impact1_special ON impact1.SpecialEffect1 = impact1_special.ID
                LEFT JOIN spellvisualkit state1 ON sv1.StateKit = state1.ID
                LEFT JOIN spellvisualeffectname state1_base ON state1.BaseEffect = state1_base.ID
                LEFT JOIN spellvisualeffectname state1_world ON state1.WorldEffect = state1_world.ID
                LEFT JOIN spellvisualeffectname state1_special ON state1.SpecialEffect1 = state1_special.ID
                LEFT JOIN spellvisual sv2 ON s.SpellVisual2 = sv2.ID
                LEFT JOIN spellvisualkit cast2 ON sv2.CastKit = cast2.ID
                LEFT JOIN spellvisualeffectname cast2_base ON cast2.BaseEffect = cast2_base.ID
                LEFT JOIN spellvisualeffectname cast2_world ON cast2.WorldEffect = cast2_world.ID
                LEFT JOIN spellvisualeffectname cast2_special ON cast2.SpecialEffect1 = cast2_special.ID
                LEFT JOIN spellvisualkit impact2 ON sv2.ImpactKit = impact2.ID
                LEFT JOIN spellvisualeffectname impact2_base ON impact2.BaseEffect = impact2_base.ID
                LEFT JOIN spellvisualeffectname impact2_world ON impact2.WorldEffect = impact2_world.ID
                LEFT JOIN spellvisualeffectname impact2_special ON impact2.SpecialEffect1 = impact2_special.ID
                LEFT JOIN spellvisualkit state2 ON sv2.StateKit = state2.ID
                LEFT JOIN spellvisualeffectname state2_base ON state2.BaseEffect = state2_base.ID
                LEFT JOIN spellvisualeffectname state2_world ON state2.WorldEffect = state2_world.ID
                LEFT JOIN spellvisualeffectname state2_special ON state2.SpecialEffect1 = state2_special.ID
                ORDER BY s.id %s
                LIMIT %d OFFSET %d;
            ]],
				sortOrder,
				pageSize,
				offset
			)
		end,
		searchNpcData = function(query, typeId, sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT ct.entry, ctm.CreatureDisplayID, ct.name, ct.subname, ct.type
                FROM creature_template ct
                LEFT JOIN creature_template_model ctm ON ct.entry = ctm.CreatureID
                WHERE ct.name LIKE '%%%s%%' OR ct.subname LIKE '%%%s%%' OR ct.entry LIKE '%%%s%%' %s
                ORDER BY ct.entry %s
                LIMIT %d OFFSET %d;
            ]],
				query,
				query,
				query,
				typeId and string.format("OR ct.type = %d", typeId) or "",
				sortOrder,
				pageSize,
				offset
			)
		end,
		searchGobData = function(query, typeId, sortOrder, pageSize, offset)
			-- Check if gameobjectdisplayinfo table exists
			local hasDisplayInfo = DatabaseHelper.IsOptionalTableAvailable("gameobjectdisplayinfo", "world")
			
			if hasDisplayInfo then
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, g.type, m.ModelName
                FROM gameobject_template g
                LEFT JOIN gameobjectdisplayinfo m ON g.displayid = m.ID
                WHERE g.name LIKE '%%%s%%' OR g.entry LIKE '%%%s%%' %s
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					query,
					query,
					typeId and string.format("OR g.type = %d", typeId) or "",
					sortOrder,
					pageSize,
					offset * pageSize
				)
			else
				return string.format(
					[[
                SELECT g.entry, g.displayid, g.name, g.type, 'N/A' as ModelName
                FROM gameobject_template g
                WHERE g.name LIKE '%%%s%%' OR g.entry LIKE '%%%s%%' %s
                ORDER BY g.entry %s
                LIMIT %d OFFSET %d;
                ]],
					query,
					query,
					typeId and string.format("OR g.type = %d", typeId) or "",
					sortOrder,
					pageSize,
					offset * pageSize
				)
			end
		end,
		searchSpellData = function(query, sortOrder, pageSize, offset)
			return string.format(
				[[
                SELECT s.id, s.spellName0, s.spellDescription0, s.spellToolTip0, s.spellVisual1, s.spellVisual2,
                       s.EffectMiscValue1, s.EffectMiscValue2, s.EffectMiscValue3,
                       s.Effect1, s.Effect2, s.Effect3, s.schoolMask,
                       COALESCE(
                           cast1_base.FilePath, cast1_world.FilePath, cast1_special.FilePath,
                           impact1_base.FilePath, impact1_world.FilePath, impact1_special.FilePath,
                           state1_base.FilePath, state1_world.FilePath, state1_special.FilePath,
                           ''
                       ) as visualFilePath1,
                       COALESCE(
                           cast2_base.FilePath, cast2_world.FilePath, cast2_special.FilePath,
                           impact2_base.FilePath, impact2_world.FilePath, impact2_special.FilePath,
                           state2_base.FilePath, state2_world.FilePath, state2_special.FilePath,
                           ''
                       ) as visualFilePath2
                FROM spell s
                LEFT JOIN spellvisual sv1 ON s.SpellVisual1 = sv1.ID
                LEFT JOIN spellvisualkit cast1 ON sv1.CastKit = cast1.ID
                LEFT JOIN spellvisualeffectname cast1_base ON cast1.BaseEffect = cast1_base.ID
                LEFT JOIN spellvisualeffectname cast1_world ON cast1.WorldEffect = cast1_world.ID
                LEFT JOIN spellvisualeffectname cast1_special ON cast1.SpecialEffect1 = cast1_special.ID
                LEFT JOIN spellvisualkit impact1 ON sv1.ImpactKit = impact1.ID
                LEFT JOIN spellvisualeffectname impact1_base ON impact1.BaseEffect = impact1_base.ID
                LEFT JOIN spellvisualeffectname impact1_world ON impact1.WorldEffect = impact1_world.ID
                LEFT JOIN spellvisualeffectname impact1_special ON impact1.SpecialEffect1 = impact1_special.ID
                LEFT JOIN spellvisualkit state1 ON sv1.StateKit = state1.ID
                LEFT JOIN spellvisualeffectname state1_base ON state1.BaseEffect = state1_base.ID
                LEFT JOIN spellvisualeffectname state1_world ON state1.WorldEffect = state1_world.ID
                LEFT JOIN spellvisualeffectname state1_special ON state1.SpecialEffect1 = state1_special.ID
                LEFT JOIN spellvisual sv2 ON s.SpellVisual2 = sv2.ID
                LEFT JOIN spellvisualkit cast2 ON sv2.CastKit = cast2.ID
                LEFT JOIN spellvisualeffectname cast2_base ON cast2.BaseEffect = cast2_base.ID
                LEFT JOIN spellvisualeffectname cast2_world ON cast2.WorldEffect = cast2_world.ID
                LEFT JOIN spellvisualeffectname cast2_special ON cast2.SpecialEffect1 = cast2_special.ID
                LEFT JOIN spellvisualkit impact2 ON sv2.ImpactKit = impact2.ID
                LEFT JOIN spellvisualeffectname impact2_base ON impact2.BaseEffect = impact2_base.ID
                LEFT JOIN spellvisualeffectname impact2_world ON impact2.WorldEffect = impact2_world.ID
                LEFT JOIN spellvisualeffectname impact2_special ON impact2.SpecialEffect1 = impact2_special.ID
                LEFT JOIN spellvisualkit state2 ON sv2.StateKit = state2.ID
                LEFT JOIN spellvisualeffectname state2_base ON state2.BaseEffect = state2_base.ID
                LEFT JOIN spellvisualeffectname state2_world ON state2.WorldEffect = state2_world.ID
                LEFT JOIN spellvisualeffectname state2_special ON state2.SpecialEffect1 = state2_special.ID
                WHERE s.spellName0 LIKE '%%%s%%' OR s.id LIKE '%%%s%%'
                ORDER BY s.id %s
                LIMIT %d OFFSET %d;
            ]],
				query,
				query,
				sortOrder,
				pageSize,
				offset * pageSize
			)
		end,
		itemCount = function(inventoryType)
			if inventoryType and inventoryType >= 0 then
				return string.format([[
                    SELECT COUNT(*) 
                    FROM item_template
                    WHERE InventoryType = %d;
                ]], inventoryType)
			else
				return [[
                    SELECT COUNT(*) 
                    FROM item_template;
                ]]
			end
		end,
		itemData = function(sortOrder, pageSize, offset, inventoryType)
			local whereClause = ""
			if inventoryType then
				whereClause = string.format("WHERE InventoryType = %d", inventoryType)
			end

			return string.format(
				[[
                SELECT entry, name, COALESCE(description, ''), displayid, Quality, InventoryType, ItemLevel, class, subclass
                FROM item_template
                %s
                ORDER BY entry %s
                LIMIT %d OFFSET %d;
            ]],
				whereClause,
				sortOrder,
				pageSize,
				offset
			)
		end,

		searchItemData = function(query, sortOrder, pageSize, offset, inventoryType)
			local whereClause = [[WHERE (name LIKE '%%%s%%' OR entry LIKE '%%%s%%')]]
			if inventoryType then
				whereClause = whereClause .. string.format(" AND InventoryType = %d", inventoryType)
			end

			return string.format(
				[[
                SELECT entry, name, COALESCE(description, ''), displayid, Quality, InventoryType, ItemLevel, class, subclass
                FROM item_template
                %s
                ORDER BY entry %s
                LIMIT %d OFFSET %d;
            ]],
				string.format(whereClause, query, query),
				sortOrder,
				pageSize,
				offset * pageSize
			)
		end,

		spellVisualCount = function()
			return [[
                SELECT COUNT(*)
                FROM spellvisualeffectname;
            ]]
		end,

		spellVisualData = function(sortOrder, pageSize, offset)
			return string.format(
				[[
            SELECT ID, Name, FilePath, AreaEffectSize, Scale, MinAllowedScale, MaxAllowedScale
            FROM spellvisualeffectname
            ORDER BY ID %s
            LIMIT %d OFFSET %d;
            ]],
				sortOrder,
				pageSize,
				offset
			)
		end,

		searchSpellVisualData = function(query, sortOrder, pageSize, offset)
			return string.format(
				[[
            SELECT ID, Name, FilePath, AreaEffectSize, Scale, MinAllowedScale, MaxAllowedScale
            FROM spellvisualeffectname
            WHERE Name LIKE '%%%s%%' OR ID LIKE '%%%s%%'
            ORDER BY ID %s
            LIMIT %d OFFSET %d;
            ]],
				query,
				query,
				sortOrder,
				pageSize,
				offset * pageSize
			)
		end,
	},
}
-- Function to get the appropriate query based on the core name
local function getQuery(coreName, queryType)
    return queries[coreName] and queries[coreName][queryType] or nil
end

-- Table name mappings for different query types
local queryTableMappings = {
    -- NPC queries
    loadCreatureDisplays = {"creature_template", "creature_template_model"},
    npcData = {"creature_template", "creature_template_model"},
    
    -- Item queries
    loadItemForPacket = {"item_template"},
    npcCount = {"creature_template"},
    searchNpcData = {"creature_template", "creature_template_model"},
    
    -- GameObject queries
    gobData = {"gameobject_template", "gameobjectdisplayinfo"},
    gobCount = {"gameobject_template"},
    searchGobData = {"gameobject_template", "gameobjectdisplayinfo"},
    
    -- Spell queries
    spellCount = {"spell"},
    spellData = {"spell", "spellvisual", "spellvisualkit", "spellvisualeffectname"},
    searchSpellData = {"spell", "spellvisual", "spellvisualkit", "spellvisualeffectname"},
    spellVisualCount = {"spellvisualeffectname"},
    spellVisualData = {"spellvisualeffectname"},
    searchSpellVisualData = {"spellvisualeffectname"},
    
    -- Item queries
    itemCount = {"item_template"},
    itemData = {"item_template"},
    searchItemData = {"item_template"},
}

-- Safe query execution functions
local function executeSafeQuery(queryFunc, databaseType, queryType)
    databaseType = databaseType or "world"

    local success, result = pcall(function()
        local query = queryFunc()
        if not query then
            return nil
        end

        -- Add database prefix support if configured
        if DatabaseHelper then
            -- Get the tables used in this query type
            local tables = queryTableMappings[queryType] or {}
            local modifiedQuery, error = DatabaseHelper.BuildSafeQuery(query, tables, databaseType)
            if not modifiedQuery then
                return nil, error
            end
            query = modifiedQuery
        end

        return DatabaseHelper.SafeQuery(query, databaseType)
    end)

    if success then
        return result
    else
        if DatabaseHelper and DatabaseHelper.debug then
            print(string.format("[GameMasterUI] Query execution failed: %s", tostring(result)))
        end
        return nil
    end
end

-- Async version of safe query execution
local function executeSafeQueryAsync(queryFunc, callback, databaseType, queryType)
    databaseType = databaseType or "world"

    local success, error = pcall(function()
        local query = queryFunc()
        if not query then
            callback(nil, "Query function returned nil")
            return
        end

        -- Add database prefix support if configured
        if DatabaseHelper then
            -- Get the tables used in this query type
            local tables = queryTableMappings[queryType] or {}
            DatabaseHelper.BuildSafeQueryAsync(query, tables, callback, databaseType)
        else
            -- Fallback to direct async query if no DatabaseHelper
            DatabaseHelper.SafeQueryAsync(query, callback, databaseType)
        end
    end)

    if not success then
        if DatabaseHelper and DatabaseHelper.debug then
            print(string.format("[GameMasterUI] Async query setup failed: %s", tostring(error)))
        end
        callback(nil, tostring(error))
    end
end

-- Initialize database helper when module loads
local function initialize()
    if DatabaseHelper and DatabaseHelper.Initialize then
        -- Config will be injected by the main system
        -- This is just a placeholder - actual initialization happens in Init.lua
    end
end

return {
    queries = queries,
    getQuery = getQuery,
    executeSafeQuery = executeSafeQuery,
    executeSafeQueryAsync = executeSafeQueryAsync,
    queryTableMappings = queryTableMappings,
    initialize = initialize,
}
