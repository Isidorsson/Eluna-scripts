local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return -- Exit if on server
end

-- Get module references
local GMMenus = _G.GMMenus
if not GMMenus or not GMMenus.SpellSelection then
    print("[ERROR] SpellSelection module not found! Check load order.")
    return
end

local SpellSelection = GMMenus.SpellSelection
local Dialog = SpellSelection.Dialog
local Search = SpellSelection.Search
local Duration = SpellSelection.Duration
local GMConfig = _G.GMConfig

-- Create the spell selection modal dialog
function Dialog.createDialog(playerName, castType)
    local state = SpellSelection.state
    
    -- Store target player name and cast type
    state.targetPlayerNameForSpell = playerName
    state.selectedSpells = {}
    state.selectedDuration = nil -- Reset duration state
    
    -- Initialize modal state using Search module
    state.spellSelectionModal = state.spellSelectionModal or Search.createModalState(castType)
    
    -- Determine button text based on cast type
    local confirmButtonText = "Cast Spell"
    local dialogTitle = "Select Spell for " .. playerName
    
    if castType == "learn" then
        confirmButtonText = "Learn Spell"
        dialogTitle = "Select Spell to Teach " .. playerName
    elseif castType == "buff" then
        confirmButtonText = "Apply Buff"
    elseif castType == "buffWithDuration" then
        confirmButtonText = "Apply Buff"
        dialogTitle = "Select Spell to Apply with Duration - " .. playerName
        state.selectedDuration = 60000 -- Default to 1 minute
    end
    
    local options = {
        title = dialogTitle,
        width = 700,
        height = 600, -- Increased height for pagination controls
        closeOnEscape = true,
        onClose = function()
            -- Notify state machine when modal closes
            SpellSelection.closeModal()
        end,
        buttons = {
            {
                text = "Cancel",
                callback = function()
                    -- State machine will be notified via onClose
                    if state.spellSelectionModal then
                        state.spellSelectionModal:Hide()
                    end
                end
            },
            {
                text = confirmButtonText,
                callback = function()
                    SpellSelection.confirmCastSpell()
                end
            }
        }
    }
    
    local modal = CreateStyledDialog(options)
    modal.castType = castType  -- FIX: Preserve castType for confirmCastSpell()
    state.spellSelectionModal = modal
    
    -- Create custom content area within the dialog
    local content = CreateFrame("Frame", nil, modal)
    content:SetPoint("TOPLEFT", modal, "TOPLEFT", 10, -40)
    content:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -10, 50)
    
    -- Enable mouse and prevent click-through
    content:EnableMouse(true)
    content:SetScript("OnMouseDown", function(self, button)
        -- Stop event propagation
    end)
    
    -- Create search box with real-time search capability
    local searchBox = CreateStyledSearchBox(content, 300, "Search spells...", function(text)
        -- Real-time search with debouncing
        Search.handleRealtimeSpellSearch(text)
    end)
    searchBox:SetPoint("TOP", content, "TOP", 0, -20)
    modal.searchBox = searchBox
    
    -- Add "Show All Spells" button for database browsing
    local searchAllBtn = CreateStyledButton(content, "Browse All", 100, 24)
    searchAllBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    searchAllBtn:SetScript("OnClick", function()
        -- Clear search box and show all spells from database
        if searchBox.editBox then
            searchBox.editBox:SetText("")
        end
        -- Cancel any pending search timer
        Search.handleSearchRequest(modal, "")
    end)
    
    -- Add duration controls for buffWithDuration mode
    local durationControls = nil
    if castType == "buffWithDuration" then
        -- Delegate to Duration module
        durationControls = Duration.createDurationControls(content, state)
        modal.durationControls = durationControls
    end
    
    -- Spell count label
    local spellCountLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellCountLabel:SetPoint("TOP", searchBox, "BOTTOM", 0, -5)
    spellCountLabel:SetText("Showing 0 spells")
    spellCountLabel:SetTextColor(0.7, 0.7, 0.7)
    modal.spellCountLabel = spellCountLabel
    
    -- Create scrollable spell list
    local listContainer = CreateStyledFrame(content, UISTYLE_COLORS.OptionBg)
    local topOffset = castType == "buffWithDuration" and -110 or -80 -- Adjust for duration controls
    listContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, topOffset)
    listContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 50) -- Leave room for pagination
    
    -- Enable mouse to prevent click-through
    listContainer:EnableMouse(true)
    listContainer:SetScript("OnMouseDown", function(self, button)
        -- Stop event propagation
    end)
    
    local scrollContainer, scrollContent, scrollBar, updateScroll = CreateScrollableFrame(
        listContainer,
        listContainer:GetWidth() - 4,
        listContainer:GetHeight() - 4
    )
    scrollContainer:SetPoint("TOPLEFT", 2, -2)
    
    modal.scrollContent = scrollContent
    modal.updateScroll = updateScroll
    modal.spellRows = {}
    
    -- Enable mouse on scroll content to prevent click-through
    scrollContent:EnableMouse(true)
    scrollContent:SetScript("OnMouseDown", function(self, button)
        -- Stop event propagation
    end)
    
    -- Add toggle buttons for spell source (only if not in duration mode, as they're redundant)
    if castType ~= "buffWithDuration" then
        local predefinedBtn = CreateStyledButton(content, "Show Predefined", 100, 20)
        predefinedBtn:SetPoint("BOTTOMLEFT", listContainer, "TOPLEFT", 0, 5)
        predefinedBtn:SetScript("OnClick", function()
            modal.currentOffset = 0
            SpellSelection.loadPredefinedSpells(castType)
        end)
        
        local allSpellsBtn = CreateStyledButton(content, "Show All Spells", 100, 20)
        allSpellsBtn:SetPoint("LEFT", predefinedBtn, "RIGHT", 10, 0)
        allSpellsBtn:SetScript("OnClick", function()
            -- Use Search module for consistent search handling
            Search.handleSearchRequest(modal, "")
        end)
    end
    
    -- Add pagination controls
    Dialog.createPaginationControls(content, modal)
    
    -- Load predefined spells based on type
    SpellSelection.loadPredefinedSpells(castType)
    
    -- Show the modal
    modal:Show()
    
    return modal
end

-- Create pagination controls
function Dialog.createPaginationControls(content, modal)
    local paginationFrame = CreateFrame("Frame", nil, content)
    paginationFrame:SetHeight(40)
    paginationFrame:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 10, 5)
    paginationFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 5)
    
    -- Previous button
    local prevButton = CreateStyledButton(paginationFrame, "< Previous", 80, 24)
    prevButton:SetPoint("LEFT", paginationFrame, "LEFT", 0, 0)
    prevButton:SetScript("OnClick", function()
        local searchText = ""
        if modal.searchBox and modal.searchBox.editBox then
            searchText = modal.searchBox.editBox:GetText() or ""
        end
        Search.handlePreviousPage(modal, searchText)
    end)
    modal.prevButton = prevButton
    
    -- Page info
    local pageInfo = paginationFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageInfo:SetPoint("CENTER", paginationFrame, "CENTER", 0, 0)
    pageInfo:SetText("Page 1")
    modal.pageInfo = pageInfo
    
    -- Next button
    local nextButton = CreateStyledButton(paginationFrame, "Next >", 80, 24)
    nextButton:SetPoint("RIGHT", paginationFrame, "RIGHT", 0, 0)
    nextButton:SetScript("OnClick", function()
        local searchText = ""
        if modal.searchBox and modal.searchBox.editBox then
            searchText = modal.searchBox.editBox:GetText() or ""
        end
        Search.handleNextPage(modal, searchText)
    end)
    modal.nextButton = nextButton
end