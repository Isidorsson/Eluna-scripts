local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return -- Exit if on server
end

-- Get the shared namespace
local GameMasterSystem = _G.GameMasterSystem
if not GameMasterSystem then
    print("[ERROR] GameMasterSystem namespace not found! Check load order.")
    return
end

-- Get module references
local GMMenus = _G.GMMenus
if not GMMenus then
    print("[ERROR] GMMenus not found! Check load order.")
    return
end

local GMConfig = _G.GMConfig
local GMUtils = _G.GMUtils
local StateMachine = _G.GMStateMachine

-- Item Selection Coordinator Module
local ItemSelection = {}
GMMenus.ItemSelection = ItemSelection

-- Export submodules for internal use
ItemSelection.Modal = {}
ItemSelection.Cards = {}
ItemSelection.Filters = {}
ItemSelection.Actions = {}
ItemSelection.Mail = {}

-- Local state (shared by all submodules)
ItemSelection.state = {
    itemSelectionModal = nil,
    selectedItems = {},
    targetPlayerName = nil,
    currentItemData = {}
}

-- Helper function to get safe item icon (used by multiple modules)
function ItemSelection.GetItemIconSafe(itemId)
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- State Machine Integration Functions

-- Open item selection modal (goes through state machine)
function ItemSelection.openModal(playerName, mode)
    -- If state machine not available, try direct modal creation
    if not StateMachine then
        if _G.GM_DEBUG then
            print("[ItemSelection] No state machine - opening modal directly")
        end
        if ItemSelection.createDialog then
            ItemSelection.createDialog(playerName)
            return true
        end
        return false
    end

    -- If already in ITEM_SELECTION state, handle it gracefully
    if StateMachine.getCurrentState() == StateMachine.STATES.ITEM_SELECTION then
        local modal = ItemSelection.state.itemSelectionModal
        if modal and modal:IsVisible() then
            -- Modal already open, bring to front
            modal:Raise()
            return true
        else
            -- State desync: state says open but modal not visible
            -- Force close without triggering callbacks to clean up state
            if modal then
                -- Temporarily disable onClose to prevent recursive calls
                if modal.overlay then
                    modal.overlay:SetScript("OnMouseDown", nil)
                end
                modal:Hide()
            end
            -- Clear state references
            ItemSelection.state.itemSelectionModal = nil
            ItemSelection.state.selectedItems = {}
            -- Close state machine state
            StateMachine.closeModal()
            -- Don't continue - let user click again
            if CreateStyledToast then
                CreateStyledToast("Modal closed - please try again", 2, 0.5)
            end
            return false
        end
    end

    -- If can't open modal through state machine, try fallback
    if not StateMachine.canOpenModal() then
        if _G.GM_DEBUG then
            print("[ItemSelection] Cannot open through state machine - using fallback")
        end
        if ItemSelection.createDialog then
            ItemSelection.createDialog(playerName)
            return true
        end
        return false
    end

    -- Store mode for later use
    ItemSelection.state.mode = mode
    ItemSelection.state.targetPlayerName = playerName

    -- Create the actual modal dialog first
    if ItemSelection.Modal and ItemSelection.Modal.createDialog then
        ItemSelection.Modal.createDialog(playerName)
    else
        -- Fallback to legacy method
        if ItemSelection.createDialog then
            ItemSelection.createDialog(playerName)
        else
            if _G.GM_DEBUG then
                print("[ItemSelection] No createDialog method available")
            end
            return false
        end
    end

    -- Transition to item selection state
    return StateMachine.openItemSelection(playerName)
end

-- Close item selection modal (goes through state machine)
function ItemSelection.closeModal()
    if StateMachine then
        return StateMachine.closeModal()
    end
    return false
end

-- Check if item modal should be active based on state
function ItemSelection.isActive()
    return StateMachine and StateMachine.getCurrentState() == StateMachine.STATES.ITEM_SELECTION
end

-- Main exported functions

-- Request items from server
function ItemSelection.requestItemsForModal()
    local modal = ItemSelection.state.itemSelectionModal
    if not modal then
        if _G.GM_DEBUG then
            print("[ItemSelection] Cannot request items - modal not found")
        end
        return
    end

    local searchText = ""
    if modal.searchBox and modal.searchBox.editBox then
        searchText = modal.searchBox.editBox:GetText() or ""
    end
    local category = modal.currentCategory or "all"
    local qualities = modal.qualityFilters or {0, 1, 2, 3, 4, 5}

    -- Convert qualities array to comma-separated string for AIO
    local qualitiesStr = table.concat(qualities, ",")

    -- Transition to loading state
    if StateMachine and StateMachine.startLoading then
        StateMachine.startLoading("itemRequest")
    end

    AIO.Handle("GameMasterSystem", "requestModalItems", searchText, category, qualitiesStr)
end

-- Update modal with item data
function ItemSelection.updateModalItems(items)
    -- Finish loading operation
    if StateMachine and StateMachine.isLoading() then
        StateMachine.finishLoading("itemRequest")
    end

    -- Check if modal exists instead of state
    if not ItemSelection.state.itemSelectionModal then
        if _G.GM_DEBUG then
            print("[ItemSelection] Received items but modal not found")
        end
        return
    end

    -- Delegate to Actions module
    if ItemSelection.Actions.updateModalItems then
        ItemSelection.Actions.updateModalItems(items)
    end
end

-- Filter items by search text
function ItemSelection.filterItems(searchText)
    -- Delegate to Filters module
    if ItemSelection.Filters.filterItems then
        ItemSelection.Filters.filterItems(searchText)
    end
end

-- Filter by category
function ItemSelection.filterByCategory(category)
    -- Delegate to Filters module
    if ItemSelection.Filters.filterByCategory then
        ItemSelection.Filters.filterByCategory(category)
    end
end

-- Update quality filter
function ItemSelection.updateQualityFilter()
    -- Delegate to Filters module
    if ItemSelection.Filters.updateQualityFilter then
        ItemSelection.Filters.updateQualityFilter()
    end
end

-- Select/deselect item card
function ItemSelection.selectItemCard(card, itemData)
    -- Delegate to Actions module
    if ItemSelection.Actions.selectItemCard then
        ItemSelection.Actions.selectItemCard(card, itemData)
    end
end

-- Unselect all items
function ItemSelection.unselectAllItems()
    -- Delegate to Actions module
    if ItemSelection.Actions.unselectAllItems then
        ItemSelection.Actions.unselectAllItems()
    end
end

-- Select all visible items
function ItemSelection.selectAllItems()
    -- Delegate to Actions module
    if ItemSelection.Actions.selectAllItems then
        ItemSelection.Actions.selectAllItems()
    end
end

-- Confirm giving items
function ItemSelection.confirmGiveItems()
    -- Only proceed if we're in the right state
    if not ItemSelection.isActive() then
        if _G.GM_DEBUG then
            print("[ItemSelection] Cannot confirm items - not in item selection state")
        end
        return
    end

    -- Delegate to Actions module
    if ItemSelection.Actions.confirmGiveItems then
        ItemSelection.Actions.confirmGiveItems()
    end

    -- Close the modal through state machine
    ItemSelection.closeModal()
end

-- Single selection for mail
function ItemSelection.selectItemCardForMail(card, itemData)
    -- Delegate to Mail module
    if ItemSelection.Mail.selectItemCardForMail then
        ItemSelection.Mail.selectItemCardForMail(card, itemData)
    end
end

-- Confirm attach items for mail
function ItemSelection.confirmAttachItems()
    -- Only proceed if we're in the right state
    if not ItemSelection.isActive() then
        if _G.GM_DEBUG then
            print("[ItemSelection] Cannot confirm attach items - not in item selection state")
        end
        return
    end

    -- Delegate to Mail module
    if ItemSelection.Mail.confirmAttachItems then
        ItemSelection.Mail.confirmAttachItems()
    end

    -- Close the modal through state machine
    ItemSelection.closeModal()
end

-- Confirm selected item for mail attachment
function ItemSelection.confirmSelectItem()
    -- Only proceed if we're in the right state
    if not ItemSelection.isActive() then
        if _G.GM_DEBUG then
            print("[ItemSelection] Cannot confirm select item - not in item selection state")
        end
        return
    end

    -- Delegate to Mail module
    if ItemSelection.Mail.confirmSelectItem then
        ItemSelection.Mail.confirmSelectItem()
    end

    -- Close the modal through state machine
    ItemSelection.closeModal()
end

-- Export update function for server responses
GMMenus.updateModalItems = function(items)
    if ItemSelection.updateModalItems then
        ItemSelection.updateModalItems(items)
    end
end