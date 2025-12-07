local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return -- Exit if on server
end

-- Get module references
local GMMenus = _G.GMMenus
if not GMMenus then
    print("[ERROR] GMMenus not found! Check load order.")
    return
end

local GMConfig = _G.GMConfig
local GMUtils = _G.GMUtils

-- Item Modal Module
local ItemModal = {}
GMMenus.ItemSelection = GMMenus.ItemSelection or {}
local ItemSelection = GMMenus.ItemSelection

-- Use centralized icon helper from GMUtils
local GetItemIconSafe = GMUtils.GetItemIconSafe

-- Create the item selection modal dialog
function ItemModal.createDialog(playerName)
    -- Store target player name
    ItemSelection.state.targetPlayerName = playerName
    ItemSelection.state.selectedItems = {}

    -- Create modal dialog
    local options = {
        title = "Select Items for " .. playerName,
        width = 860,  -- Increased to accommodate 10 columns
        height = 600,
        closeOnEscape = true,
        onClose = function()
            -- Notify state machine when modal closes
            ItemSelection.closeModal()
        end,
        buttons = {
            {
                text = "Cancel",
                callback = function()
                    -- State machine will be notified via onClose
                    if ItemSelection.state.itemSelectionModal then
                        ItemSelection.state.itemSelectionModal:Hide()
                    end
                end
            },
            {
                text = "Give Items",
                callback = function()
                    ItemSelection.confirmGiveItems()
                end
            }
        }
    }

    local modal = CreateStyledDialog(options)

    -- Initialize filters on modal
    modal.currentCategory = "all"
    modal.qualityFilters = {0, 1, 2, 3, 4, 5}

    -- Store in state
    ItemSelection.state.itemSelectionModal = modal
    
    -- Create custom content area within the dialog
    local content = CreateFrame("Frame", nil, modal)
    content:SetPoint("TOPLEFT", modal, "TOPLEFT", 10, -40)
    content:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -10, 50)
    
    -- Create search box at top
    local searchBox = CreateStyledSearchBox(content, 300, "Search items...", function(text)
        ItemSelection.filterItems(text)
    end)
    searchBox:SetPoint("TOP", content, "TOP", 0, -40)
    modal.searchBox = searchBox
    
    -- Item count label
    local itemCountLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemCountLabel:SetPoint("TOP", searchBox, "BOTTOM", 0, -5)
    itemCountLabel:SetText("Showing 0 items")
    itemCountLabel:SetTextColor(0.7, 0.7, 0.7)
    modal.itemCountLabel = itemCountLabel
    
    -- Create filter controls
    ItemModal.createFilterControls(content, modal)
    
    -- Create scrollable item grid
    ItemModal.createItemGrid(content, modal)
    
    -- Create quantity controls at bottom
    ItemModal.createQuantityControls(content, modal)

    -- Request initial item data
    ItemSelection.requestItemsForModal()

    -- Show the modal
    modal:Show()

    return modal
end

function ItemModal.createFilterControls(content, modal)
    -- Create category dropdown
    local categoryLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -95)
    categoryLabel:SetText("Category:")
    categoryLabel:SetTextColor(0.8, 0.8, 0.8)
    
    local categoryItems = {
        { text = "All Items", value = "all" },
        { text = "Weapons", value = "weapon" },
        { text = "Armor", value = "armor" },
        { text = "Consumables", value = "consumable" },
        { text = "Trade Goods", value = "trade" },
        { text = "Quest Items", value = "quest" },
        { text = "Gems", value = "gem" },
        { text = "Miscellaneous", value = "misc" }
    }
    
    local categoryDropdown = CreateFullyStyledDropdown(
        content,
        150,
        categoryItems,
        "All Items",
        function(value)
            ItemSelection.filterByCategory(value)
        end
    )
    categoryDropdown:SetPoint("LEFT", categoryLabel, "RIGHT", 10, 0)
    modal.categoryDropdown = categoryDropdown
    
    -- Create quality filter toggles
    local qualityLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("LEFT", categoryDropdown, "RIGHT", 30, 0)
    qualityLabel:SetText("Quality:")
    qualityLabel:SetTextColor(0.8, 0.8, 0.8)
    
    local qualityToggles = {}
    local qualityTypes = {
        { name = "Poor", color = UISTYLE_COLORS.Poor },
        { name = "Common", color = UISTYLE_COLORS.Common },
        { name = "Uncommon", color = UISTYLE_COLORS.Uncommon },
        { name = "Rare", color = UISTYLE_COLORS.Rare },
        { name = "Epic", color = UISTYLE_COLORS.Epic },
        { name = "Legendary", color = UISTYLE_COLORS.Legendary }
    }
    
    local xOffset = 0
    for i, quality in ipairs(qualityTypes) do
        local toggle = CreateQualityToggle(content, quality.color, 16)
        toggle:SetPoint("LEFT", qualityLabel, "RIGHT", 10 + xOffset, 0)
        toggle:SetChecked(true)
        toggle:SetScript("OnClick", function(self)
            -- Toggle the state first
            self:SetChecked(not self:GetChecked())
            -- Then update the filter
            ItemSelection.updateQualityFilter()
        end)
        toggle.qualityIndex = i - 1  -- WoW quality indices start at 0
        -- Add tooltip
        toggle:SetTooltip(quality.name, "Click to toggle " .. quality.name .. " quality items")
        qualityToggles[i] = toggle
        xOffset = xOffset + 20
    end
    modal.qualityToggles = qualityToggles
end

function ItemModal.createItemGrid(content, modal)
    local gridContainer = CreateStyledFrame(content, UISTYLE_COLORS.OptionBg)
    gridContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -135)
    gridContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 100)
    
    local scrollContainer, scrollContent, scrollBar, updateScroll = CreateScrollableFrame(
        gridContainer,
        gridContainer:GetWidth() - 4,
        gridContainer:GetHeight() - 4
    )
    scrollContainer:SetPoint("TOPLEFT", 2, -2)
    
    modal.scrollContent = scrollContent
    modal.updateScroll = updateScroll
    modal.itemCards = {}
end

function ItemModal.createQuantityControls(content, modal)
    local quantityFrame = CreateStyledFrame(content, UISTYLE_COLORS.SectionBg)
    quantityFrame:SetHeight(80)
    quantityFrame:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 10, 10)
    quantityFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)
    
    -- Selected items display
    local selectedLabel = quantityFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedLabel:SetPoint("TOPLEFT", quantityFrame, "TOPLEFT", 10, -10)
    selectedLabel:SetText("Selected: 0 items")
    modal.selectedLabel = selectedLabel
    
    -- Unselect All button
    local unselectAllBtn = CreateStyledButton(quantityFrame, "Unselect All", 80, 20)
    unselectAllBtn:SetPoint("LEFT", selectedLabel, "RIGHT", 20, 0)
    unselectAllBtn:SetScript("OnClick", function()
        ItemSelection.unselectAllItems()
    end)
    modal.unselectAllBtn = unselectAllBtn
    
    -- Select All button
    local selectAllBtn = CreateStyledButton(quantityFrame, "Select All", 70, 20)
    selectAllBtn:SetPoint("LEFT", unselectAllBtn, "RIGHT", 10, 0)
    selectAllBtn:SetScript("OnClick", function()
        ItemSelection.selectAllItems()
    end)
    modal.selectAllBtn = selectAllBtn
    
    -- Quantity controls
    local qtyLabel = quantityFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyLabel:SetPoint("TOPLEFT", quantityFrame, "TOPLEFT", 10, -35)
    qtyLabel:SetText("Quantity:")
    
    -- Quick quantity buttons
    local qtyButtons = { 1, 5, 10, 20, 50 }
    local btnXOffset = 0
    for _, qty in ipairs(qtyButtons) do
        local btn = CreateStyledButton(quantityFrame, tostring(qty), 40, 24)
        btn:SetPoint("LEFT", qtyLabel, "RIGHT", 10 + btnXOffset, 0)
        btn:SetScript("OnClick", function()
            if modal.quantitySlider and modal.quantitySlider.slider then
                modal.quantitySlider.slider:SetValue(qty)
            end
            modal.currentQuantity = qty
        end)
        btnXOffset = btnXOffset + 45
    end
    
    -- Max stack button
    local maxBtn = CreateStyledButton(quantityFrame, "Max", 50, 24)
    maxBtn:SetPoint("LEFT", qtyLabel, "RIGHT", 10 + btnXOffset, 0)
    maxBtn:SetScript("OnClick", function()
        -- Set to max stack of selected item
        if modal.selectedItem then
            local maxStack = math.min(modal.selectedItem.maxStack or 100, 100)
            if modal.quantitySlider and modal.quantitySlider.slider then
                modal.quantitySlider.slider:SetValue(maxStack)
            end
            modal.currentQuantity = maxStack
        else
            -- Default to max slider value if no item selected
            if modal.quantitySlider and modal.quantitySlider.slider then
                modal.quantitySlider.slider:SetValue(100)
            end
            modal.currentQuantity = 100
        end
    end)
    
    -- Quantity slider
    local quantitySlider = CreateStyledSliderWithRange(
        quantityFrame,
        200,
        20,
        1,
        100,
        1,
        1,
        ""
    )
    quantitySlider:SetPoint("LEFT", maxBtn, "RIGHT", 20, 0)
    modal.quantitySlider = quantitySlider
    modal.currentQuantity = 1
    
    -- Add onChange handler
    quantitySlider:SetOnValueChanged(function(value)
        modal.currentQuantity = value
    end)
end

-- Export functions to ItemSelection
ItemSelection.createDialog = ItemModal.createDialog
ItemSelection.Modal = ItemSelection.Modal or {}
ItemSelection.Modal.createDialog = ItemModal.createDialog
ItemSelection.GetItemIconSafe = GMUtils.GetItemIconSafe

-- Item modal module loaded