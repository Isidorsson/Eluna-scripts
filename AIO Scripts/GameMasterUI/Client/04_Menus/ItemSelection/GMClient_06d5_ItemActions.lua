local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return -- Exit if on server
end

-- Get module references
local GMMenus = _G.GMMenus
if not GMMenus or not GMMenus.ItemSelection then
    print("[ERROR] ItemSelection module not found! Check load order.")
    return
end

local ItemSelection = GMMenus.ItemSelection
local Actions = ItemSelection.Actions

-- Select/deselect item card
function Actions.selectItemCard(card, itemData)
    local state = ItemSelection.state
    local modal = state.itemSelectionModal
    if not modal then return end
    
    if modal.isMultiSelect then
        -- Multi-select mode - don't clear previous selections
        if card.isSelected then
            -- Deselect
            card.isSelected = false
            card.selectionOverlay:Hide()
            state.selectedItems[itemData.entry] = nil
        else
            -- Check max items
            local count = 0
            for _ in pairs(state.selectedItems) do
                count = count + 1
            end
            
            if count < (modal.maxItems or 12) then
                -- Select
                card.isSelected = true
                card.selectionOverlay:Show()
                state.selectedItems[itemData.entry] = {
                    entry = itemData.entry,
                    name = itemData.name,
                    icon = ItemSelection.GetItemIconSafe(itemData.entry),
                    quality = itemData.quality,
                    maxStack = itemData.maxStack or 20
                }
            else
                CreateStyledToast("Maximum items selected!", 2, 0.5)
            end
        end
        
        -- Update selected count
        local count = 0
        for _ in pairs(state.selectedItems) do
            count = count + 1
        end
        
        if modal.selectedLabel then
            modal.selectedLabel:SetText("Selected: " .. count .. " / " .. (modal.maxItems or 12))
        end
    else
        -- Single select mode
        if card.isSelected then
            -- Deselect
            card.isSelected = false
            card.selectionOverlay:Hide()
            state.selectedItems[itemData.entry] = nil
        else
            -- Select
            card.isSelected = true
            card.selectionOverlay:Show()
            state.selectedItems[itemData.entry] = {
                entry = itemData.entry,
                name = itemData.name,
                icon = ItemSelection.GetItemIconSafe(itemData.entry),
                quality = itemData.quality,
                maxStack = itemData.maxStack or 20
            }
            
            -- Update selected item for quantity controls
            modal.selectedItem = state.selectedItems[itemData.entry]
            
            -- Update max stack for slider
            local maxStack = math.min(itemData.maxStack or 100, 100)
            if modal.quantitySlider and modal.quantitySlider.slider then
                modal.quantitySlider.slider:SetMinMaxValues(1, maxStack)
            end
        end
        
        -- Update selected count
        local count = 0
        for _ in pairs(state.selectedItems) do
            count = count + 1
        end
        if modal.selectedLabel then
            modal.selectedLabel:SetText("Selected: " .. count .. " items")
        end
    end
end

-- Update modal with item data
function Actions.updateModalItems(items)
    local state = ItemSelection.state
    local modal = state.itemSelectionModal
    if not modal then return end

    -- Clear existing cards
    if modal.itemCards then
        for _, card in ipairs(modal.itemCards) do
            card:Hide()
            card:SetParent(nil)
        end
        wipe(modal.itemCards)
    else
        modal.itemCards = {}
    end
    
    -- Update item count display
    if modal.itemCountLabel then
        modal.itemCountLabel:SetText("Showing " .. #items .. " items")
    end
    
    -- Create new cards
    state.currentItemData = items
    for i, itemData in ipairs(items) do
        local card = ItemSelection.createModalItemCard(modal.scrollContent, itemData, i)
        table.insert(modal.itemCards, card)
    end
    
    -- Update scroll content height
    if modal.scrollContent and modal.updateScroll then
        local rows = math.ceil(#items / 10)
        modal.scrollContent:SetHeight(math.max(400, rows * 70 + 20))
        modal.updateScroll()
    end
end

-- Unselect all items
function Actions.unselectAllItems()
    local state = ItemSelection.state
    local modal = state.itemSelectionModal
    if not modal then return end
    
    -- Clear selected items
    wipe(state.selectedItems)
    
    -- Update all card visual states
    if modal.itemCards then
        for _, card in ipairs(modal.itemCards) do
            if card.isSelected then
                card.isSelected = false
                card.selectionOverlay:Hide()
            end
        end
    end
    
    -- Update selected count
    if modal.selectedLabel then
        modal.selectedLabel:SetText("Selected: 0 items")
    end
    
    -- Clear selected item for quantity controls
    modal.selectedItem = nil
end

-- Select all visible items
function Actions.selectAllItems()
    local state = ItemSelection.state
    local modal = state.itemSelectionModal
    if not modal then return end
    
    -- Clear first to start fresh
    wipe(state.selectedItems)
    
    -- Select all visible cards
    if modal.itemCards and state.currentItemData then
        for i, card in ipairs(modal.itemCards) do
            if card:IsVisible() and state.currentItemData[i] then
                local itemData = state.currentItemData[i]
                card.isSelected = true
                card.selectionOverlay:Show()
                state.selectedItems[itemData.entry] = {
                    entry = itemData.entry,
                    name = itemData.name,
                    icon = ItemSelection.GetItemIconSafe(itemData.entry),
                    quality = itemData.quality,
                    maxStack = itemData.maxStack or 20
                }
            end
        end
    end
    
    -- Update selected count
    local count = 0
    for _ in pairs(state.selectedItems) do
        count = count + 1
    end
    if modal.selectedLabel then
        modal.selectedLabel:SetText("Selected: " .. count .. " items")
    end
    
    -- Set first item as selected for quantity controls
    for _, itemData in pairs(state.selectedItems) do
        modal.selectedItem = itemData
        break
    end
end

-- Confirm giving items
function Actions.confirmGiveItems()
    local state = ItemSelection.state
    local modal = state.itemSelectionModal
    if not modal then return end
    
    local quantity = modal.currentQuantity or 1
    
    for itemId, itemData in pairs(state.selectedItems) do
        AIO.Handle("GameMasterSystem", "givePlayerItem", state.targetPlayerName, itemId, quantity)
    end
    
    -- Show success message
    print(string.format("Gave %d items to %s", quantity, state.targetPlayerName))

    -- Modal will be closed by state machine transition to IDLE
end