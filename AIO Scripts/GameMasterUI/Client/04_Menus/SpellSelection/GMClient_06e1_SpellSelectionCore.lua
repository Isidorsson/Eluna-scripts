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

-- Spell Selection Modal Module
local SpellSelection = {}
GMMenus.SpellSelection = SpellSelection

-- Export submodules for internal use
SpellSelection.Search = {}
SpellSelection.Dialog = {}
SpellSelection.Rows = {}
SpellSelection.ContextMenu = {}
SpellSelection.Duration = {}

-- Local state (shared across submodules)
SpellSelection.state = {
    spellSelectionModal = nil,
    selectedSpells = {},
    targetPlayerNameForSpell = nil,
    currentSpellData = {},
    selectedDuration = nil
}

-- State Machine Integration Functions

-- Open spell selection modal (goes through state machine)
function SpellSelection.openModal(playerName, castType)
    -- If state machine not available, try direct modal creation
    if not StateMachine then
        if _G.GM_DEBUG then
            print("[SpellSelection] No state machine - opening modal directly")
        end
        if SpellSelection.createDialog then
            SpellSelection.createDialog(playerName, castType)
            return true
        end
        return false
    end

    -- If already in SPELL_SELECTION state, handle it gracefully
    if StateMachine.getCurrentState() == StateMachine.STATES.SPELL_SELECTION then
        local modal = SpellSelection.state.spellSelectionModal
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
            SpellSelection.state.spellSelectionModal = nil
            SpellSelection.state.selectedSpells = {}
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
            print("[SpellSelection] Cannot open through state machine - using fallback")
        end
        if SpellSelection.createDialog then
            SpellSelection.createDialog(playerName, castType)
            return true
        end
        return false
    end

    -- Store cast type for later use
    SpellSelection.state.castType = castType
    SpellSelection.state.targetPlayerNameForSpell = playerName

    -- Create the actual modal dialog first
    if SpellSelection.createDialog then
        SpellSelection.createDialog(playerName, castType)
    else
        if _G.GM_DEBUG then
            print("[SpellSelection] No createDialog method available")
        end
        return false
    end

    -- Transition to spell selection state
    return StateMachine.openSpellSelection(playerName, castType)
end

-- Close spell selection modal (goes through state machine)
function SpellSelection.closeModal()
    if StateMachine then
        return StateMachine.closeModal()
    end
    return false
end

-- Check if spell modal should be active based on state
function SpellSelection.isActive()
    return StateMachine and StateMachine.getCurrentState() == StateMachine.STATES.SPELL_SELECTION
end

-- Main entry point - Create the spell selection dialog
function SpellSelection.createDialog(playerName, castType)
    -- Delegate to Dialog module
    return SpellSelection.Dialog.createDialog(playerName, castType)
end

-- Load predefined spells
function SpellSelection.loadPredefinedSpells(castType)
    local spells = {}
    
    -- Normalize cast type for predefined spells (buffWithDuration uses same spells as buff)
    local normalizedType = castType == "buffWithDuration" and "buff" or castType
    
    -- Add all spell categories
    for _, category in ipairs(GMConfig.SPELL_CATEGORIES) do
        for _, spell in ipairs(category.spells) do
            table.insert(spells, {
                spellId = spell.spellId,
                name = spell.name,
                icon = spell.icon,
                category = category.name
            })
        end
    end
    
    local modal = SpellSelection.state.spellSelectionModal
    if modal then
        -- Reset pagination for predefined spells
        modal.currentOffset = 0
        modal.hasMoreData = false
        modal.totalSpells = #spells
        
        -- Hide pagination controls for predefined spells
        if modal.prevButton then
            modal.prevButton:Hide()
        end
        if modal.nextButton then
            modal.nextButton:Hide()
        end
        if modal.pageInfo then
            modal.pageInfo:Hide()
        end
    end
    
    -- Update display
    SpellSelection.updateSpellList(spells)
end

-- Update spell list display
function SpellSelection.updateSpellList(spells)
    local modal = SpellSelection.state.spellSelectionModal
    if not modal then return end
    
    -- Clear existing rows
    for _, row in ipairs(modal.spellRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(modal.spellRows or {})
    modal.spellRows = {}
    
    -- Update count
    if modal.spellCountLabel then
        modal.spellCountLabel:SetText("Showing " .. #spells .. " spells")
    end
    
    -- Create spell rows using Rows module
    SpellSelection.state.currentSpellData = spells
    for i, spellData in ipairs(spells) do
        local row = SpellSelection.Rows.createSpellRow(modal.scrollContent, spellData, i)
        table.insert(modal.spellRows, row)
    end
    
    -- Update scroll content height
    if modal.scrollContent and modal.updateScroll then
        modal.scrollContent:SetHeight(math.max(400, #spells * 35 + 10))
        modal.updateScroll()
    end
end

-- Filter spells by search text
function SpellSelection.filterSpells(searchText)
    local modal = SpellSelection.state.spellSelectionModal
    if not modal then return end
    
    if not searchText or searchText == "" then
        SpellSelection.loadPredefinedSpells(modal.castType)
        return
    end
    
    searchText = searchText:lower()
    local filteredSpells = {}
    
    -- Search through all spell categories
    for _, category in ipairs(GMConfig.SPELL_CATEGORIES) do
        for _, spell in ipairs(category.spells) do
            if spell.name:lower():find(searchText, 1, true) or tostring(spell.spellId):find(searchText, 1, true) then
                table.insert(filteredSpells, {
                    spellId = spell.spellId,
                    name = spell.name,
                    icon = spell.icon,
                    category = category.name
                })
            end
        end
    end
    
    -- Hide pagination for filtered predefined spells
    if modal.prevButton then
        modal.prevButton:Hide()
    end
    if modal.nextButton then
        modal.nextButton:Hide()
    end
    if modal.pageInfo then
        modal.pageInfo:Hide()
    end
    
    SpellSelection.updateSpellList(filteredSpells)
end

-- Confirm spell cast
function SpellSelection.confirmCastSpell()
    -- Only proceed if we're in the right state
    if not SpellSelection.isActive() then
        if _G.GM_DEBUG then
            print("[SpellSelection] Cannot confirm spell cast - not in spell selection state")
        end
        return
    end

    local state = SpellSelection.state
    if #state.selectedSpells == 0 then
        CreateStyledToast("No spell selected", 2, 0.5)
        return
    end

    local spell = state.selectedSpells[1]
    local modal = state.spellSelectionModal
    local castType = modal and modal.castType

    if castType == "buffWithDuration" then
        -- Apply buff with selected duration
        local duration = state.selectedDuration or 60000 -- Default to 1 minute if not set
        AIO.Handle("GameMasterSystem", "playerApplyAuraWithDuration", state.targetPlayerNameForSpell, spell.spellId, duration)
        local durationText = duration == -1 and "permanent" or string.format("%d seconds", duration / 1000)
        CreateStyledToast(string.format("Applied %s (%s) to %s", spell.name, durationText, state.targetPlayerNameForSpell), 2, 0.5)
    elseif castType == "buff" then
        AIO.Handle("GameMasterSystem", "applyBuffToPlayer", state.targetPlayerNameForSpell, spell.spellId)
        CreateStyledToast(string.format("Applied %s to %s", spell.name, state.targetPlayerNameForSpell), 2, 0.5)
    elseif castType == "self" then
        AIO.Handle("GameMasterSystem", "makePlayerCastOnSelf", state.targetPlayerNameForSpell, spell.spellId)
        CreateStyledToast(string.format("%s casting %s on self", state.targetPlayerNameForSpell, spell.name), 2, 0.5)
    elseif castType == "target" then
        AIO.Handle("GameMasterSystem", "makePlayerCastOnTarget", state.targetPlayerNameForSpell, spell.spellId)
        CreateStyledToast(string.format("%s casting %s on target", state.targetPlayerNameForSpell, spell.name), 2, 0.5)
    elseif castType == "onplayer" then
        AIO.Handle("GameMasterSystem", "castSpellOnPlayer", state.targetPlayerNameForSpell, spell.spellId)
        CreateStyledToast(string.format("Cast %s on %s", spell.name, state.targetPlayerNameForSpell), 2, 0.5)
    elseif castType == "learn" then
        -- Handle learning spell
        AIO.Handle("GameMasterSystem", "playerSpellLearn", state.targetPlayerNameForSpell, spell.spellId)
        CreateStyledToast(string.format("Teaching %s to %s...", spell.name, state.targetPlayerNameForSpell), 2, 0.5)
    end

    -- Close modal through state machine
    SpellSelection.closeModal()
end

-- Handle spell search results from server
function SpellSelection.updateSpellSearchResults(spells, offset, pageSize, hasMoreData, totalCount)
    -- Finish loading operation if we're in loading state
    if StateMachine and StateMachine.isLoading() then
        StateMachine.finishLoading("spellSearch")
    end

    -- Only update if we're in the right state
    if not SpellSelection.isActive() then
        if _G.GM_DEBUG then
            print("[SpellSelection] Received spells but not in spell selection state")
        end
        return
    end

    local modal = SpellSelection.state.spellSelectionModal
    if not modal or not modal:IsVisible() then
        return
    end
    
    -- Update modal state using Search module
    SpellSelection.Search.updateModalState(modal, offset, pageSize, hasMoreData, totalCount)
    
    -- Reset search feedback text color and show results count
    if modal.spellCountLabel then
        modal.spellCountLabel:SetTextColor(0.7, 0.7, 0.7) -- Reset to normal gray
        local searchText = ""
        if modal.searchBox and modal.searchBox.editBox then
            searchText = modal.searchBox.editBox:GetText() or ""
        end
        if searchText ~= "" then
            modal.spellCountLabel:SetText("Database search: " .. #spells .. " results")
        else
            modal.spellCountLabel:SetText("Browsing all spells: " .. #spells .. " results")
        end
    end
    
    -- Show pagination controls for database results
    if modal.prevButton then
        modal.prevButton:Show()
    end
    if modal.nextButton then
        modal.nextButton:Show()
    end
    if modal.pageInfo then
        modal.pageInfo:Show()
    end
    
    -- Update pagination controls
    SpellSelection.updatePaginationControls()
    
    -- Update the spell list with server results
    SpellSelection.updateSpellList(spells)
end

-- Update pagination controls visibility and text
function SpellSelection.updatePaginationControls()
    local modal = SpellSelection.state.spellSelectionModal
    if not modal then return end
    
    -- Update previous button (WoW 3.3.5 uses Enable/Disable)
    if modal.prevButton then
        if modal.currentOffset > 0 then
            modal.prevButton:Enable()
        else
            modal.prevButton:Disable()
        end
    end
    
    -- Update next button (WoW 3.3.5 uses Enable/Disable)
    if modal.nextButton then
        if modal.hasMoreData then
            modal.nextButton:Enable()
        else
            modal.nextButton:Disable()
        end
    end
    
    -- Update page info using Search module
    if modal.pageInfo then
        local paginationInfo = SpellSelection.Search.getPaginationInfo(modal)
        
        if paginationInfo.totalSpells > 0 then
            modal.pageInfo:SetText(string.format("Showing %d-%d of %d", 
                paginationInfo.startNum, paginationInfo.endNum, paginationInfo.totalSpells))
        else
            modal.pageInfo:SetText("Page " .. paginationInfo.currentPage)
        end
    end
end

-- Export the main functions
GMMenus.createSpellSelectionDialog = function(playerName, castType)
    return SpellSelection.createDialog(playerName, castType)
end

GMMenus.updateSpellSearchResults = function(spells, offset, pageSize, hasMoreData, totalCount)
    if SpellSelection.updateSpellSearchResults then
        SpellSelection.updateSpellSearchResults(spells, offset, pageSize, hasMoreData, totalCount)
    end
end