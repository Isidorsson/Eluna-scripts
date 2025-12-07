local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return -- Exit if on server
end

-- Verify namespace exists
local GameMasterSystem = _G.GameMasterSystem
if not GameMasterSystem then
    print("[ERROR] GameMasterSystem namespace not found! Check load order.")
    return
end

-- Get module references
local GMConfig = _G.GMConfig
local GMUtils = _G.GMUtils

-- Get or create Player Inventory System
local PlayerInventory = _G.PlayerInventory or {}
_G.PlayerInventory = PlayerInventory
GameMasterSystem.PlayerInventory = PlayerInventory

-- ================================================================================
-- EARLY STUB FUNCTIONS
-- These provide immediate availability to prevent nil errors in dependent files
-- They will be replaced by real implementations when context menu modules load
-- ================================================================================

-- Provide stub for closeContextMenu to prevent nil errors
if not PlayerInventory.closeContextMenu then
    PlayerInventory.closeContextMenu = function()
        -- Stub implementation - will be replaced when real module loads
        if PlayerInventory.currentContextMenu then
            if PlayerInventory.currentContextMenu.Hide then
                PlayerInventory.currentContextMenu:Hide()
            end
            PlayerInventory.currentContextMenu = nil
        end
    end
end

-- Provide stub for showItemContextMenu
if not PlayerInventory.showItemContextMenu then
    PlayerInventory.showItemContextMenu = function(slot, itemData, isEquipment)
        -- Stub - will be replaced when real module loads
        -- This prevents errors but doesn't show a menu
        if GMConfig and GMConfig.config and GMConfig.config.debug then
            print("[PlayerInventory] Context menu stub called - real implementation not yet loaded")
        end
    end
end

-- Provide stub for showEmptySlotContextMenu
if not PlayerInventory.showEmptySlotContextMenu then
    PlayerInventory.showEmptySlotContextMenu = function(slot, isEquipment)
        -- Stub - will be replaced when real module loads
        -- This prevents errors but doesn't show a menu
    end
end

-- Store actual bag sizes received from server
PlayerInventory.bagSizes = {}
PlayerInventory.currentPlayerName = nil
PlayerInventory.showAllBags = true  -- Show all equipped bags even if empty
PlayerInventory.includeBank = false  -- Initially hide bank bags

-- Collapse state tracking
PlayerInventory.collapsedBags = {}  -- Track which bags are collapsed

-- Cache tracking
PlayerInventory.cacheMissedItems = {}  -- Track items not in client cache
PlayerInventory.cacheRetryAttempts = {}  -- Track retry attempts per item

-- Dynamic bag mapping from server
PlayerInventory.dynamicBagMapping = {}

-- Function to normalize bag IDs (no longer uses hardcoded mapping)
function PlayerInventory.normalizeBagId(bagId)
    -- If we have dynamic mapping from server, use it
    if PlayerInventory.dynamicBagMapping and PlayerInventory.dynamicBagMapping[bagId] then
        -- Return the bag ID as-is since we now know what it represents
        return bagId
    end
    
    -- Fallback for special bags
    if bagId == 0 or bagId == 255 then
        return bagId  -- Backpack and equipment don't need remapping
    end
    
    -- For unknown bags, return as-is
    return bagId
end

-- Configuration
PlayerInventory.INVENTORY_CONFIG = {
    MODAL_WIDTH = 900,
    MODAL_HEIGHT = 650,
    SLOT_SIZE = 40,
    SLOT_SPACING = 6,
    PADDING = 15,
    TITLE_HEIGHT = 35,
    TAB_HEIGHT = 30,
    EQUIPMENT_SLOTS = {
        [0] = "Head",
        [1] = "Neck",
        [2] = "Shoulder",
        [3] = "Shirt",
        [4] = "Chest",
        [5] = "Belt",
        [6] = "Legs",
        [7] = "Feet",
        [8] = "Wrists",
        [9] = "Hands",
        [10] = "Ring 1",
        [11] = "Ring 2",
        [12] = "Trinket 1",
        [13] = "Trinket 2",
        [14] = "Back",
        [15] = "Main Hand",
        [16] = "Off Hand",
        [17] = "Ranged",
        [18] = "Tabard"
    }
}

-- Enchantment name lookup table
-- Comprehensive enchantment names for WoW 3.3.5
-- This will be populated from server data if available
PlayerInventory.ENCHANT_NAMES = {
    -- Weapon Enchants - Top Tier
    [3788] = "Accuracy",
    [3789] = "Berserking",
    [3790] = "Black Magic",
    [3869] = "Blade Ward",
    [3870] = "Blood Draining",
    [3241] = "Lifeward",
    [3239] = "Icebreaker",
    [3273] = "Deathfrost",
    [3225] = "Executioner",
    [2673] = "Mongoose",
    [3827] = "Massacre",
    [3828] = "Greater Savagery",
    [3834] = "Mighty Spellpower",
    [3846] = "Major Spellpower",
    [3854] = "Greater Spellpower",
    [3833] = "Superior Potency",
    [3844] = "Exceptional Spirit",
    [2674] = "Spellsurge",
    [2675] = "Battlemaster",
    [2672] = "Soulfrost",
    [2671] = "Sunfire",
    [1900] = "Crusader",
    [1894] = "Icy Chill",
    [1899] = "Unholy Weapon",
    [1898] = "Lifestealing",
    [1897] = "Fiery Weapon",
    
    -- DK Runes
    [3368] = "Rune of the Fallen Crusader",
    [3366] = "Rune of Lichbane",
    [3365] = "Rune of Swordshattering",
    [3594] = "Rune of Swordbreaking",
    [3367] = "Rune of Spellshattering",
    [3595] = "Rune of Spellbreaking",
    [3370] = "Rune of Razorice",
    [3369] = "Rune of Cinderglacier",
    [3847] = "Rune of the Stoneskin Gargoyle",
    [3883] = "Rune of the Nerubian Carapace",
    
    -- Chest Enchants
    [3832] = "Powerful Stats",
    [3297] = "Super Health",
    [3245] = "Exceptional Resilience",
    [3252] = "Super Stats",
    [3253] = "Mighty Health",
    [1953] = "Greater Defense",
    [3236] = "Mighty Health",
    [3233] = "Exceptional Mana",
    
    -- Boot Enchants
    [3232] = "Tuskarr's Vitality",
    [3826] = "Icewalker",
    [3244] = "Greater Vitality",
    [3824] = "Greater Assault",
    [1597] = "Greater Fortitude",
    [983] = "Superior Agility",
    [3606] = "Nitro Boosts",
    
    -- Glove Enchants
    [3222] = "Greater Agility",
    [3231] = "Expertise",
    [3238] = "Gatherer",
    [3246] = "Exceptional Armor",
    [3253] = "Armsman",
    [3234] = "Precision",
    [3829] = "Greater Assault",
    [3604] = "Hyperspeed Accelerators",
    [3603] = "Hand-Mounted Pyro Rocket",
    [3860] = "Reticulated Armor Webbing",
    
    -- Cloak Enchants
    [3831] = "Greater Speed",
    [3243] = "Spell Piercing",
    [3256] = "Shadow Armor",
    [3296] = "Superior Dodge",
    [3294] = "Superior Defense",
    [3825] = "Speed",
    [3728] = "Flexweave Underlay",
    [3859] = "Springy Arachnoweave",
    [1099] = "Major Agility",
    [3230] = "Titanweave",
    
    -- Bracer Enchants
    [3850] = "Major Stamina",
    [2332] = "Superior Spellpower",
    [3845] = "Greater Assault",
    [2326] = "Major Spirit",
    [1147] = "Greater Spirit",
    [2650] = "Spellpower",
    [3002] = "Greater Spellpower",
    
    -- Fur Lining (LW)
    [3757] = "Fur Lining - Attack Power",
    [3758] = "Fur Lining - Stamina",
    [3759] = "Fur Lining - Spell Power",
    [3760] = "Fur Lining - Fire Resist",
    [3761] = "Fur Lining - Frost Resist",
    [3762] = "Fur Lining - Shadow Resist",
    [3763] = "Fur Lining - Nature Resist",
    [3756] = "Fur Lining - Arcane Resist",
    
    -- Shield Enchants
    [3849] = "Titanium Plating",
    [1952] = "Major Intellect",
    [3229] = "Resilience",
    [2655] = "Greater Stamina",
    
    -- Leg Armor
    [3853] = "Earthen Leg Armor",
    [3325] = "Frosthide Leg Armor",
    [3326] = "Icescale Leg Armor",
    [3822] = "Nerubian Leg Armor",
    [3823] = "Wyrmscale Leg Armor",
    [3719] = "Azure Spellthread",
    [3720] = "Shining Spellthread",
    [3721] = "Brilliant Spellthread",
    [3872] = "Sapphire Spellthread",
    
    -- Ranged
    [3607] = "Superior Scouting",
    [3608] = "Heartseeker Scope",
    [3843] = "Sun Scope",
    [2724] = "Stabilized Eternium Scope",
    [2723] = "Khorium Scope",
    [2722] = "Adamantite Scope",
    [2523] = "Biznicks 247x128 Accurascope",
    [663] = "Sniper Scope",
    [664] = "Scope (+7 Damage)",
    
    -- Random Suffix Enchantments (using high ID range 50000+)
    -- Classic Suffixes
    [50005] = "of the Monkey",
    [50006] = "of the Eagle",
    [50007] = "of the Bear",
    [50008] = "of the Whale",
    [50009] = "of the Owl",
    [50010] = "of the Gorilla",
    [50011] = "of the Falcon",
    [50012] = "of the Boar",
    [50013] = "of the Wolf",
    [50014] = "of the Tiger",
    [50015] = "of Spirit",
    [50016] = "of Stamina",
    [50017] = "of Strength",
    [50018] = "of Agility",
    [50019] = "of Intellect",
    [50020] = "of Power",
    
    -- Spell Power Suffixes
    [50021] = "of Spell Power",
    [50022] = "of Spell Power",
    [50023] = "of Spell Power",
    [50024] = "of Spell Power",
    [50025] = "of Spell Power",
    [50026] = "of Spell Power",
    
    -- Defense and Avoidance
    [50027] = "of Defense",
    [50028] = "of Regeneration",
    [50029] = "of Eluding",
    [50030] = "of Concentration",
    
    -- Resistance Suffixes
    [50031] = "of Arcane Protection",
    [50032] = "of Fire Protection",
    [50033] = "of Frost Protection",
    [50034] = "of Nature Protection",
    [50035] = "of Shadow Protection",
    
    -- Complex Combinations
    [50036] = "of the Sorcerer",
    [50037] = "of the Physician",
    [50038] = "of the Prophet",
    [50039] = "of the Invoker",
    [50040] = "of the Bandit",
    [50041] = "of the Beast",
    [50042] = "of the Hierophant",
    [50043] = "of the Soldier",
    [50044] = "of the Elder",
    [50045] = "of the Champion",
    [50047] = "of Blocking",
    
    -- Hunt/Shadow/Wild themes
    [50049] = "of the Grove",
    [50050] = "of the Hunt",
    [50051] = "of the Mind",
    [50052] = "of the Crusade",
    [50053] = "of the Vision",
    [50054] = "of the Ancestor",
    [50055] = "of the Nightmare",
    [50056] = "of the Battle",
    [50057] = "of the Shadow",
    [50058] = "of the Sun",
    [50059] = "of the Moon",
    [50060] = "of the Wild",
    
    -- Resistance variants
    [50061] = "of Spell Power",
    [50062] = "of Strength",
    [50063] = "of Agility",
    [50064] = "of Power",
    [50065] = "of Magic",
    
    -- Knight/Seer variants
    [50066] = "of the Knight",
    [50067] = "of the Seer",
    
    -- Level 60 variants
    [50068] = "of the Bear",
    [50069] = "of the Eagle",
    [50070] = "of the Ancestor",
    [50071] = "of the Bandit",
    [50072] = "of the Battle",
    [50073] = "of the Elder",
    [50074] = "of the Beast",
    [50075] = "of the Champion",
    [50076] = "of the Grove",
    [50077] = "of the Knight",
    [50078] = "of the Monkey",
    [50079] = "of the Moon",
    [50080] = "of the Wild",
    [50081] = "of the Whale",
    [50082] = "of the Vision",
    [50083] = "of the Sun",
    [50084] = "of Stamina",
    [50085] = "of the Sorcerer",
    [50086] = "of the Soldier",
    [50087] = "of the Shadow",
    
    -- WotLK additions
    [50088] = "of the Foreseer",
    [50089] = "of the Thief",
    [50090] = "of the Necromancer",
    [50091] = "of the Marksman",
    [50092] = "of the Squire",
    [50093] = "of Restoration",
    
    -- Speed suffix
    [50099] = "of Speed",
}

-- Core state management
PlayerInventory.currentModal = nil
PlayerInventory.currentContextMenu = nil
PlayerInventory.currentPlayerName = nil
PlayerInventory.originalInventoryData = nil
PlayerInventory.originalEquipmentData = nil
PlayerInventory.originalBankData = nil  -- Separate storage for bank items
PlayerInventory.pendingEnchantment = nil
PlayerInventory.searchFilter = nil
PlayerInventory.bankSearchFilter = nil  -- Separate search filter for bank
PlayerInventory.selectedSpellForBatch = nil

-- Batch enchantment queue
PlayerInventory.enchantmentQueue = {}
PlayerInventory.isProcessingQueue = false

-- Helper function to get item quality color
function PlayerInventory.getItemQualityColor(quality)
    local colors = {
        [0] = UISTYLE_COLORS.Poor,     -- Poor (Grey)
        [1] = UISTYLE_COLORS.Common,   -- Common (White)
        [2] = UISTYLE_COLORS.Uncommon, -- Uncommon (Green)
        [3] = UISTYLE_COLORS.Rare,     -- Rare (Blue)
        [4] = UISTYLE_COLORS.Epic,     -- Epic (Purple)
        [5] = UISTYLE_COLORS.Legendary -- Legendary (Orange)
    }
    return colors[quality] or UISTYLE_COLORS.Common
end

-- Count cache-missed items
function PlayerInventory.getCacheMissedCount()
    local count = 0
    for _, _ in pairs(PlayerInventory.cacheMissedItems or {}) do
        count = count + 1
    end
    return count
end

-- Update cache status display with improved visuals
function PlayerInventory.updateCacheStatus()
    if not PlayerInventory.currentModal or not PlayerInventory.currentModal.cacheStatusBar then
        return
    end
    
    local cacheCount = PlayerInventory.getCacheMissedCount()
    
    if cacheCount > 0 then
        -- Show and animate the cache status bar
        PlayerInventory.currentModal.cacheStatusBar:Show()
        
        -- Create pulse animation if not exists
        if not PlayerInventory.currentModal.cacheStatusBar.pulseAnim then
            local pulseAnim = PlayerInventory.currentModal.cacheStatusBar:CreateAnimationGroup()
            local pulse = pulseAnim:CreateAnimation("Alpha")
            pulse:SetFromAlpha(0.8)
            pulse:SetToAlpha(1.0)
            pulse:SetDuration(1.0)
            pulse:SetSmoothing("IN_OUT")
            pulseAnim:SetLooping("BOUNCE")
            PlayerInventory.currentModal.cacheStatusBar.pulseAnim = pulseAnim
        end
        PlayerInventory.currentModal.cacheStatusBar.pulseAnim:Play()
        
        if PlayerInventory.currentModal.cacheStatusText then
            PlayerInventory.currentModal.cacheStatusText:SetText(
                string.format("%d item%s not cached - Link in chat or click refresh", 
                    cacheCount, cacheCount == 1 and "" or "s")
            )
        end
        
        -- Make refresh button visible
        if PlayerInventory.currentModal.refreshCacheBtn then
            PlayerInventory.currentModal.refreshCacheBtn:Show()
        end
    else
        -- Hide the bar when all items are cached
        if PlayerInventory.currentModal.cacheStatusBar.pulseAnim then
            PlayerInventory.currentModal.cacheStatusBar.pulseAnim:Stop()
        end
        PlayerInventory.currentModal.cacheStatusBar:Hide()
    end
end

-- Retry loading cache-missed items with visual feedback
function PlayerInventory.retryCacheMissedItems()
    if not PlayerInventory.originalInventoryData then
        if CreateStyledToast then
            CreateStyledToast("No items need caching", 2, 0.5)
        end
        return
    end
    
    -- Show animation on refresh button
    if PlayerInventory.currentModal and PlayerInventory.currentModal.refreshCacheBtn then
        local btn = PlayerInventory.currentModal.refreshCacheBtn
        -- Create spin effect
        if not btn.spinAnim then
            btn.spinAnim = btn:CreateAnimationGroup()
            local spin = btn.spinAnim:CreateAnimation("Rotation")
            spin:SetDegrees(360)
            spin:SetDuration(1.0)
            btn.spinAnim:SetLooping("REPEAT")
        end
        btn.spinAnim:Play()
        
        -- Stop animation after 2 seconds using frame timer
        local stopTimer = CreateFrame("Frame")
        local elapsed = 0
        stopTimer:SetScript("OnUpdate", function(frame, delta)
            elapsed = elapsed + delta
            if elapsed >= 2 then
                frame:SetScript("OnUpdate", nil)
                if btn.spinAnim then
                    btn.spinAnim:Stop()
                end
            end
        end)
    end
    
    local retriedCount = 0
    local successCount = 0
    
    -- Clear the cache missed items list and rebuild it
    local oldCacheMissed = PlayerInventory.cacheMissedItems
    PlayerInventory.cacheMissedItems = {}
    
    -- Try to reload each item
    for itemId, _ in pairs(oldCacheMissed) do
        retriedCount = retriedCount + 1
        
        -- Attempt to get item info again
        local itemName = GetItemInfo(itemId)
        if itemName then
            -- Item is now cached!
            successCount = successCount + 1
            if GMConfig.config.debug then
                print(string.format("[PlayerInventory] Item %d (%s) is now cached!", itemId, itemName))
            end
        else
            -- Still not cached
            PlayerInventory.cacheMissedItems[itemId] = true
        end
    end
    
    -- Refresh the display if we had any successes
    if successCount > 0 then
        if PlayerInventory.currentModal and PlayerInventory.currentModal.invPanel then
            -- Update each slot that was successfully cached
            if PlayerInventory.originalInventoryData then
                for _, itemData in ipairs(PlayerInventory.originalInventoryData) do
                    if itemData.entry and oldCacheMissed[itemData.entry] and not PlayerInventory.cacheMissedItems[itemData.entry] then
                        -- This item was successfully cached, update its slot
                        local slotKey = string.format("%d:%d", itemData.bag or 0, itemData.slot or 0)
                        local slot = PlayerInventory.currentModal.invPanel.slotMap[slotKey]
                        if slot then
                            slot:UpdateSlot(itemData)
                        end
                    end
                end
            end
        end
        
        -- Show success toast
        if CreateStyledToast then
            CreateStyledToast(string.format("Cached %d item%s successfully", 
                successCount, successCount == 1 and "" or "s"), 3, 0.5)
        else
            print(string.format("|cff00ff00Successfully cached %d of %d items|r", successCount, retriedCount))
        end
    elseif retriedCount > 0 then
        -- Show warning toast
        if CreateStyledToast then
            CreateStyledToast("No new items cached. Link items in chat first", 3, 0.5)
        else
            print(string.format("|cffffcc00Unable to cache items. Try linking them in chat.|r"))
        end
    end
    
    -- Update cache status display
    PlayerInventory.updateCacheStatus()
end

-- Helper to clean up enchantment animations
function PlayerInventory.cleanupEnchantAnimation(slot)
    if slot.enchantAnimation then
        slot.enchantAnimation:SetScript("OnUpdate", nil)
        slot.enchantAnimation = nil
    end
    if slot.enchantGlow then
        slot.enchantGlow:Hide()
    end
    if slot.enchantBorder then
        slot.enchantBorder:Hide()
    end
    if slot.enchantGlowFrame then
        slot.enchantGlowFrame:Hide()
    end
end

-- Helper function to get user-friendly bag names
function PlayerInventory.getBagDisplayName(bagId)
    -- Check dynamic mapping first
    if PlayerInventory.dynamicBagMapping and PlayerInventory.dynamicBagMapping[bagId] then
        local bagInfo = PlayerInventory.dynamicBagMapping[bagId]
        return bagInfo.name or ("Bag " .. bagId)
    end
    
    -- Fallback for special bags
    if bagId == 0 then
        return "Backpack"
    elseif bagId == -1 then
        return "Bank (Main)"
    elseif bagId == 255 then
        return "Equipment"
    else
        -- For unmapped bags, show the ID for debugging
        return "Bag (ID: " .. bagId .. ")"
    end
end

-- Helper function to determine bag type
function PlayerInventory.getBagType(bagId)
    -- Check dynamic mapping first
    if PlayerInventory.dynamicBagMapping and PlayerInventory.dynamicBagMapping[bagId] then
        local bagInfo = PlayerInventory.dynamicBagMapping[bagId]
        return bagInfo.type or "unknown"
    end
    
    -- Fallback for special bags
    if bagId == 0 then
        return "backpack"
    elseif bagId == -1 then
        return "bank_main"
    elseif bagId == 255 then
        return "equipment"
    else
        return "unknown"
    end
end

-- Check if a bag should be shown in inventory view
function PlayerInventory.shouldShowBag(bagId, includeBank)
    -- Special handling for virtual bank bag
    if bagId == -1 then
        return includeBank == true  -- Only show main bank in bank view
    end
    
    -- Backpack should only show in inventory view, never in bank view
    if bagId == 0 then
        return not includeBank  -- Show backpack only in inventory view, not bank view
    end
    
    local bagType = PlayerInventory.getBagType(bagId)
    if bagType == "bank" or bagType == "bank_main" then
        return includeBank == true  -- Only show bank bags if explicitly requested
    elseif bagType == "equipment" then
        return false  -- Don't show equipment bag in inventory view
    elseif bagType == "regular" or bagType == "backpack" then
        return not includeBank  -- Show regular bags only in inventory view
    else
        -- For unknown bags, show them based on context
        return not includeBank  -- Show unknown bags in inventory view by default
    end
end

-- Check if an item/bag is a bank item
function PlayerInventory.isBankItem(bagId, slotId)
    -- Check dynamic mapping first
    if PlayerInventory.dynamicBagMapping and PlayerInventory.dynamicBagMapping[bagId] then
        local bagInfo = PlayerInventory.dynamicBagMapping[bagId]
        -- Check if this is a bank bag
        if bagInfo.type == "bank" then
            return true
        end
    end
    
    -- IMPORTANT: Main bank slots are in bag 0, slots 39-66 (28 bank slots)
    if bagId == 0 and slotId and slotId >= 39 and slotId <= 66 then
        return true
    end
    
    -- Legacy check for standard bank bag IDs (64-75) 
    -- Some servers might still use these
    if bagId >= 64 and bagId <= 75 then
        return true
    end
    
    return false
end

-- Separate inventory data into regular inventory and bank items
function PlayerInventory.separateInventoryData(allData)
    local inventoryItems = {}
    local bankItems = {}
    
    if not allData then
        return inventoryItems, bankItems
    end
    
    for _, item in ipairs(allData) do
        if PlayerInventory.isBankItem(item.bag, item.slot) then
            table.insert(bankItems, item)
        else
            table.insert(inventoryItems, item)
        end
    end
    
    return inventoryItems, bankItems
end

-- Show player inventory modal (main entry point)
function PlayerInventory.showInventoryModal(playerName)
    if GMConfig.config.debug then
        print("[PlayerInventory] Requesting inventory for player:", playerName)
    end

    -- Check state machine availability and use it for coordination
    local StateMachine = _G.GMStateMachine
    if StateMachine then
        -- If already in INVENTORY state, handle it gracefully
        if StateMachine.getCurrentState() == StateMachine.STATES.INVENTORY then
            local modal = PlayerInventory.currentModal
            if modal and modal:IsVisible() then
                -- Modal already open, bring to front
                modal:Raise()
                return
            else
                -- State desync: state says open but modal not visible
                -- Force close without triggering callbacks to clean up state
                if modal then
                    modal:Hide()
                end
                -- Clear state reference
                PlayerInventory.currentModal = nil
                -- Close state machine state
                StateMachine.closeModal()
                -- Don't continue - let user click again
                if CreateStyledToast then
                    CreateStyledToast("Modal closed - please try again", 2, 0.5)
                end
                return
            end
        end

        if not StateMachine.canOpenModal() then
            if GMConfig.config.debug then
                print("[PlayerInventory] Cannot open through state machine - system busy")
            end
            -- Fallback to direct creation if state machine is busy
            PlayerInventory.createInventoryModalDirectly(playerName)
            return
        end

        -- Use state machine for coordinated opening
        if not StateMachine.openInventory(playerName) then
            if GMConfig.config.debug then
                print("[PlayerInventory] State machine transition failed - using fallback")
            end
            PlayerInventory.createInventoryModalDirectly(playerName)
            return
        end
    end

    -- Store the player name for later use
    PlayerInventory.currentPlayerName = playerName

    -- Create loading modal (check if function exists due to load order)
    if PlayerInventory.createInventoryModalWithLoading then
        PlayerInventory.createInventoryModalWithLoading(playerName)
    else
        -- Function not yet loaded, just request data
        if GMConfig.config.debug then
            print("[PlayerInventory] Modal creation function not yet loaded, requesting data only")
        end
    end

    -- Request data from server
    AIO.Handle("GameMasterSystem", "getPlayerInventory", playerName)
end

-- Fallback function for direct modal creation without state machine
function PlayerInventory.createInventoryModalDirectly(playerName)
    if GMConfig.config.debug then
        print("[PlayerInventory] Creating modal directly (fallback mode)")
    end

    -- Store the player name for later use
    PlayerInventory.currentPlayerName = playerName

    -- Create loading modal (check if function exists due to load order)
    if PlayerInventory.createInventoryModalWithLoading then
        PlayerInventory.createInventoryModalWithLoading(playerName)
    else
        -- Function not yet loaded, just request data
        if GMConfig.config.debug then
            print("[PlayerInventory] Modal creation function not yet loaded, requesting data only")
        end
    end

    -- Request data from server
    AIO.Handle("GameMasterSystem", "getPlayerInventory", playerName)
end

-- Manual refresh function for inventory data
function PlayerInventory.manualRefresh()
    if not PlayerInventory.currentPlayerName then
        if GMConfig.config.debug then
            print("[PlayerInventory] No player name stored, cannot refresh")
        end
        return
    end
    
    if GMConfig.config.debug then
        print("[PlayerInventory] Manual refresh requested for:", PlayerInventory.currentPlayerName)
    end
    
    -- Show toast notification
    if CreateStyledToast then
        CreateStyledToast("Refreshing inventory...", 2, 0.5)
    end
    
    -- Request fresh data from server
    AIO.Handle("GameMasterSystem", "getPlayerInventory", PlayerInventory.currentPlayerName)
    
    -- Show success toast after delay using frame timer
    local successTimer = CreateFrame("Frame")
    local elapsed = 0
    successTimer:SetScript("OnUpdate", function(frame, delta)
        elapsed = elapsed + delta
        if elapsed >= 1.5 then
            frame:SetScript("OnUpdate", nil)
            if CreateStyledToast then
                CreateStyledToast("Inventory refreshed!", 2, 0.5)
            end
        end
    end)
end

-- Register core handlers with existing GameMasterSystem namespace
-- receiveInventoryData is registered in GMClient_07g_InventoryModal.lua where it's defined
GameMasterSystem.refreshInventoryDisplay = function(...) return PlayerInventory.refreshInventoryDisplay(...) end
GameMasterSystem.updateSpecificInventoryItem = function(player, bag, slot, newItemData) 
    return PlayerInventory.updateSpecificInventoryItem(bag, slot, newItemData) 
end
GameMasterSystem.updateSpecificEquipmentSlot = function(player, slotId, newItemData) 
    if GMConfig.config.debug then
        print(string.format("[InventoryCore] Forwarding updateSpecificEquipmentSlot: slotId=%s (type: %s), newItemData type: %s", 
            tostring(slotId), type(slotId), type(newItemData)))
    end
    return PlayerInventory.updateSpecificEquipmentSlot(slotId, newItemData) 
end

-- Handler for inventory item updates (add/remove/modify)
function PlayerInventory.handleInventoryUpdate(player, updateType, itemData, bagId, slotId)
    if GMConfig.config.debug then
        print(string.format("[PlayerInventory] Inventory update: %s, bag %d, slot %d", 
            updateType, bagId or -1, slotId or -1))
    end
    
    -- Only process if we have a modal open for this player
    if not PlayerInventory.currentModal or not PlayerInventory.originalInventoryData then
        return
    end
    
    -- Normalize bag ID
    if bagId then
        bagId = PlayerInventory.normalizeBagId(bagId)
    end
    
    if updateType == "add" then
        -- Add new item to inventory data
        if itemData then
            itemData.bag = bagId
            itemData.slot = slotId
            table.insert(PlayerInventory.originalInventoryData, itemData)
            
            -- Update display immediately
            if PlayerInventory.currentModal and PlayerInventory.currentModal.invPanel then
                PlayerInventory.updateInventoryDisplay(
                    PlayerInventory.currentModal.invPanel,
                    PlayerInventory.originalInventoryData
                )
            end
            
            -- Show toast notification
            if CreateStyledToast then
                CreateStyledToast(string.format("Added: %s", itemData.name or "Item"), 2, 0.5)
            end
        end
        
    elseif updateType == "remove" then
        -- Remove item from inventory data
        for i = #PlayerInventory.originalInventoryData, 1, -1 do
            local item = PlayerInventory.originalInventoryData[i]
            if item.bag == bagId and item.slot == slotId then
                local removedItem = table.remove(PlayerInventory.originalInventoryData, i)
                
                -- Update display immediately
                if PlayerInventory.currentModal and PlayerInventory.currentModal.invPanel then
                    PlayerInventory.updateInventoryDisplay(
                        PlayerInventory.currentModal.invPanel,
                        PlayerInventory.originalInventoryData
                    )
                end
                
                -- Show toast notification
                if CreateStyledToast then
                    CreateStyledToast(string.format("Removed: %s", removedItem.name or "Item"), 2, 0.5)
                end
                break
            end
        end
        
    elseif updateType == "modify" then
        -- Update existing item (stack size change, enchant, etc.)
        for i, item in ipairs(PlayerInventory.originalInventoryData) do
            if item.bag == bagId and item.slot == slotId then
                -- Update item data
                if itemData then
                    for k, v in pairs(itemData) do
                        item[k] = v
                    end
                end
                
                -- Update specific slot display
                if PlayerInventory.currentModal and PlayerInventory.currentModal.invPanel then
                    local slotKey = string.format("%d:%d", bagId, slotId)
                    local slot = PlayerInventory.currentModal.invPanel.slotMap[slotKey]
                    if slot then
                        slot:UpdateSlot(item)
                    end
                end
                
                -- Show toast notification
                if CreateStyledToast then
                    CreateStyledToast(string.format("Updated: %s", item.name or "Item"), 2, 0.5)
                end
                break
            end
        end
        
    elseif updateType == "refresh" then
        -- Full refresh requested
        PlayerInventory.refreshInventoryDisplay(player, false)
    end
end

-- Register the update handler
GameMasterSystem.handleInventoryUpdate = function(...) return PlayerInventory.handleInventoryUpdate(...) end

-- Enchantment data handlers
GameMasterSystem.receiveEnchantmentData = function(player, enchants)
    if GMConfig.config.debug then
        print("[PlayerInventory] Received enchantment data with " .. #enchants .. " enchants")
    end
    PlayerInventory.serverEnchantmentData = enchants
end

GameMasterSystem.receiveDatabaseEnchantments = function(player, enchants)
    if GMConfig.config.debug then
        print("[PlayerInventory] Received database enchantments with " .. #enchants .. " enchants")
    end
    PlayerInventory.databaseEnchantmentData = enchants
    -- Update the ENCHANT_NAMES table with database data
    for _, enchant in ipairs(enchants) do
        if enchant.id and enchant.name then
            PlayerInventory.ENCHANT_NAMES[enchant.id] = enchant.name
        end
    end
end

GameMasterSystem.receivePopularEnchantments = function(player, itemEntry, enchants)
    if GMConfig.config.debug then
        print("[PlayerInventory] Received popular enchants for item " .. itemEntry .. " with " .. #enchants .. " enchants")
    end
    -- Could trigger a UI update here if needed
end

-- Hook into chat messages to catch server error broadcasts
local originalChatFrame_OnEvent = ChatFrame1:GetScript("OnEvent")
ChatFrame1:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_SYSTEM" then
        local message = ...
        -- Check if this is an inventory-related error message
        if message and (string.find(message, "Target slot is already occupied") or
                       string.find(message, "Inventory might be full") or
                       string.find(message, "Failed to")) then
            -- Call our error handler
            if PlayerInventory.handleInventoryError then
                PlayerInventory.handleInventoryError(message)
            end
        end
    end
    -- Call the original handler
    if originalChatFrame_OnEvent then
        originalChatFrame_OnEvent(self, event, ...)
    end
end)

-- Debug message
if GMConfig.config.debug then
    print("[PlayerInventory] Core module loaded with error handling")
end