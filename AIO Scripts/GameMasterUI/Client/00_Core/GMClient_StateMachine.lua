local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return
end

-- Get the shared namespace
local GameMasterSystem = _G.GameMasterSystem
if not GameMasterSystem then
    return
end

-- State Machine Module for GameMaster UI System
local StateMachine = {}
_G.GMStateMachine = StateMachine

-- Define all possible states
StateMachine.STATES = {
    INITIALIZING = "INITIALIZING",     -- System starting up, fetching initial data
    IDLE = "IDLE",                     -- Ready state, no modals open
    ITEM_SELECTION = "ITEM_SELECTION", -- Item selection modal active
    SPELL_SELECTION = "SPELL_SELECTION", -- Spell selection modal active
    DIALOG_OPEN = "DIALOG_OPEN",       -- Other dialog active (gold, ban, etc.)
    INVENTORY = "INVENTORY",           -- Player inventory modal active
    EDITOR_ITEM = "EDITOR_ITEM",       -- Item template editor active
    EDITOR_CREATURE = "EDITOR_CREATURE", -- Creature template editor active
    EDITOR_GAMEOBJECT = "EDITOR_GAMEOBJECT", -- GameObject template editor active
    OBJECT_EDITOR = "OBJECT_EDITOR",   -- Object editor active (spawn editing)
    ENTITY_SELECTION = "ENTITY_SELECTION", -- Entity selection dialog active
    MAIL_DIALOG = "MAIL_DIALOG",       -- Mail dialog active
    REPORT_DIALOG = "REPORT_DIALOG",   -- Report dialog active
    TELEPORT = "TELEPORT",             -- Teleport system active
    LOADING = "LOADING",               -- Fetching data from server
    ERROR = "ERROR"                    -- Error state
}

-- Current state
StateMachine.currentState = StateMachine.STATES.INITIALIZING

-- State history for debugging
StateMachine.stateHistory = {}

-- Timeout configuration (in seconds)
StateMachine.timeouts = {
    [StateMachine.STATES.INITIALIZING] = 30,    -- 30 seconds to initialize
    [StateMachine.STATES.LOADING] = 15,         -- 15 seconds for loading operations
    [StateMachine.STATES.ERROR] = 60,           -- 60 seconds in error state before auto-recovery
    -- Modal states get longer timeouts since user might be actively using them
    [StateMachine.STATES.ITEM_SELECTION] = 600,     -- 10 minutes
    [StateMachine.STATES.SPELL_SELECTION] = 600,    -- 10 minutes
    [StateMachine.STATES.INVENTORY] = 900,          -- 15 minutes
    [StateMachine.STATES.EDITOR_ITEM] = 1800,       -- 30 minutes
    [StateMachine.STATES.EDITOR_CREATURE] = 1800,   -- 30 minutes
    [StateMachine.STATES.EDITOR_GAMEOBJECT] = 1800, -- 30 minutes
    [StateMachine.STATES.OBJECT_EDITOR] = 1800,     -- 30 minutes
    [StateMachine.STATES.ENTITY_SELECTION] = 300,   -- 5 minutes
    [StateMachine.STATES.MAIL_DIALOG] = 600,        -- 10 minutes
    [StateMachine.STATES.REPORT_DIALOG] = 600,      -- 10 minutes
    [StateMachine.STATES.TELEPORT] = 300,           -- 5 minutes
    [StateMachine.STATES.DIALOG_OPEN] = 300         -- 5 minutes
}

-- State context data
StateMachine.context = {
    activeModal = nil,
    modalType = nil,
    targetPlayer = nil,
    lastError = nil,
    loadingOperations = {},
    -- Persistence data
    persistenceId = nil,
    lastSaved = 0,
    -- Timeout detection
    stateEnterTime = 0,
    timeoutWarned = false,
    recoveryAttempts = 0
}

-- State transition definitions
StateMachine.transitions = {
    [StateMachine.STATES.INITIALIZING] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.IDLE] = {
        [StateMachine.STATES.ITEM_SELECTION] = true,
        [StateMachine.STATES.SPELL_SELECTION] = true,
        [StateMachine.STATES.DIALOG_OPEN] = true,
        [StateMachine.STATES.INVENTORY] = true,
        [StateMachine.STATES.EDITOR_ITEM] = true,
        [StateMachine.STATES.EDITOR_CREATURE] = true,
        [StateMachine.STATES.EDITOR_GAMEOBJECT] = true,
        [StateMachine.STATES.OBJECT_EDITOR] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true,
        [StateMachine.STATES.MAIL_DIALOG] = true,
        [StateMachine.STATES.REPORT_DIALOG] = true,
        [StateMachine.STATES.TELEPORT] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.ITEM_SELECTION] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.SPELL_SELECTION] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.DIALOG_OPEN] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.INVENTORY] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.EDITOR_ITEM] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true, -- Can open entity picker
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.EDITOR_CREATURE] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true, -- Can open entity picker
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.EDITOR_GAMEOBJECT] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true, -- Can open entity picker
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.OBJECT_EDITOR] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true, -- Can open entity picker
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.ENTITY_SELECTION] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.EDITOR_ITEM] = true, -- Return to editor
        [StateMachine.STATES.EDITOR_CREATURE] = true,
        [StateMachine.STATES.EDITOR_GAMEOBJECT] = true,
        [StateMachine.STATES.OBJECT_EDITOR] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.MAIL_DIALOG] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.REPORT_DIALOG] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.TELEPORT] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.LOADING] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.LOADING] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.ITEM_SELECTION] = true,
        [StateMachine.STATES.SPELL_SELECTION] = true,
        [StateMachine.STATES.DIALOG_OPEN] = true,
        [StateMachine.STATES.INVENTORY] = true,
        [StateMachine.STATES.EDITOR_ITEM] = true,
        [StateMachine.STATES.EDITOR_CREATURE] = true,
        [StateMachine.STATES.EDITOR_GAMEOBJECT] = true,
        [StateMachine.STATES.OBJECT_EDITOR] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true,
        [StateMachine.STATES.MAIL_DIALOG] = true,
        [StateMachine.STATES.REPORT_DIALOG] = true,
        [StateMachine.STATES.TELEPORT] = true,
        [StateMachine.STATES.ERROR] = true
    },
    [StateMachine.STATES.ERROR] = {
        [StateMachine.STATES.IDLE] = true,
        [StateMachine.STATES.INITIALIZING] = true
    }
}

-- State entry callbacks
StateMachine.onEnter = {
    [StateMachine.STATES.INITIALIZING] = function()
        -- Clear any existing modals
        StateMachine.clearAllModals()
        -- Start initialization process
        local GMData = _G.GMData
        if GMData then
            GMData.isGmLevelFetched = false
            GMData.isCoreNameFetched = false
        end
    end,

    [StateMachine.STATES.IDLE] = function()
        -- Ensure all modals are closed
        StateMachine.clearAllModals()
        StateMachine.context.activeModal = nil
        StateMachine.context.modalType = nil
    end,

    [StateMachine.STATES.ITEM_SELECTION] = function()
        -- Ensure only item modal can be active
        StateMachine.clearOtherModals("item")
        StateMachine.context.modalType = "item"
    end,

    [StateMachine.STATES.SPELL_SELECTION] = function()
        -- Ensure only spell modal can be active
        StateMachine.clearOtherModals("spell")
        StateMachine.context.modalType = "spell"
    end,

    [StateMachine.STATES.DIALOG_OPEN] = function()
        -- Dialog is open, prevent other modals
        StateMachine.clearOtherModals("dialog")
        StateMachine.context.modalType = "dialog"
    end,

    [StateMachine.STATES.INVENTORY] = function()
        -- Inventory modal active, clear others
        StateMachine.clearOtherModals("inventory")
        StateMachine.context.modalType = "inventory"
    end,

    [StateMachine.STATES.EDITOR_ITEM] = function()
        -- Item editor active, clear others
        StateMachine.clearOtherModals("editor_item")
        StateMachine.context.modalType = "editor_item"

        -- Actually open the item template editor
        local editTarget = StateMachine.context.editTarget
        local isDuplicate = StateMachine.context.isDuplicate or false
        if editTarget and _G.ItemTemplateEditor then
            _G.ItemTemplateEditor.Open(editTarget, isDuplicate)
        end
    end,

    [StateMachine.STATES.EDITOR_CREATURE] = function()
        -- Creature editor active, clear others
        StateMachine.clearOtherModals("editor_creature")
        StateMachine.context.modalType = "editor_creature"

        -- Actually open the creature template editor
        local editTarget = StateMachine.context.editTarget
        if editTarget and _G.CreatureTemplateEditor then
            _G.CreatureTemplateEditor.Open(editTarget, false)
        end
    end,

    [StateMachine.STATES.EDITOR_GAMEOBJECT] = function()
        -- GameObject editor active, clear others
        StateMachine.clearOtherModals("editor_gameobject")
        StateMachine.context.modalType = "editor_gameobject"

        -- Actually open the gameobject template editor
        local editTarget = StateMachine.context.editTarget
        if editTarget and _G.GameObjectTemplateEditor then
            _G.GameObjectTemplateEditor.Open(editTarget, false)
        end
    end,

    [StateMachine.STATES.OBJECT_EDITOR] = function()
        -- Object editor active, clear others
        StateMachine.clearOtherModals("object_editor")
        StateMachine.context.modalType = "object_editor"

        -- Actually open the object editor
        local objectType = StateMachine.context.objectType
        local objectGuid = StateMachine.context.objectGuid
        if objectType and objectGuid and _G.ObjectEditor then
            local objectData = {
                type = objectType,
                guid = objectGuid
            }
            _G.ObjectEditor.OpenEditor(objectData)
        end
    end,

    [StateMachine.STATES.ENTITY_SELECTION] = function()
        -- Entity selection active, clear others
        StateMachine.clearOtherModals("entity_selection")
        StateMachine.context.modalType = "entity_selection"

        -- Actually open the entity selection dialog
        if _G.EntitySelectionDialog then
            _G.EntitySelectionDialog.Open()
        end
    end,

    [StateMachine.STATES.MAIL_DIALOG] = function()
        -- Mail dialog active, clear others
        StateMachine.clearOtherModals("mail_dialog")
        StateMachine.context.modalType = "mail_dialog"

        -- Actually open the mail dialog
        local targetPlayer = StateMachine.context.targetPlayer
        local mailData = StateMachine.context.mailData
        if targetPlayer and _G.GameMasterSystem and _G.GameMasterSystem.OpenMailDialog then
            _G.GameMasterSystem.OpenMailDialog(targetPlayer, mailData)
        end
    end,

    [StateMachine.STATES.REPORT_DIALOG] = function()
        -- Report dialog active, clear others
        StateMachine.clearOtherModals("report_dialog")
        StateMachine.context.modalType = "report_dialog"

        -- Actually open the report dialog
        if _G.GMReportDialog and _G.GMReportDialog.Show then
            _G.GMReportDialog.Show()
        end
    end,

    [StateMachine.STATES.TELEPORT] = function()
        -- Teleport system active, clear others
        StateMachine.clearOtherModals("teleport")
        StateMachine.context.modalType = "teleport"

        -- Actually open the teleport dialog
        local targetPlayer = StateMachine.context.targetPlayer
        if _G.GameMasterSystem and _G.GameMasterSystem.ShowTeleportList then
            _G.GameMasterSystem.ShowTeleportList(targetPlayer)
        end
    end,

    [StateMachine.STATES.LOADING] = function()
        -- Add loading indicator if needed
    end,

    [StateMachine.STATES.ERROR] = function()
        local error = StateMachine.context.lastError
        if error and _G.GM_DEBUG then
            print("[StateMachine] Error state:", error)
        end
    end
}

-- State exit callbacks
StateMachine.onExit = {
    [StateMachine.STATES.INITIALIZING] = function()
        -- Initialization complete
    end,

    [StateMachine.STATES.LOADING] = function()
        -- Clear loading operations
        wipe(StateMachine.context.loadingOperations)
    end,

    [StateMachine.STATES.ERROR] = function()
        -- Clear error context
        StateMachine.context.lastError = nil
    end
}

-- Helper function to clear modals based on type
function StateMachine.clearOtherModals(keepType)
    local GMMenus = _G.GMMenus
    if not GMMenus then return end

    -- Clear item modal if not keeping it
    if keepType ~= "item" and GMMenus.ItemSelection and GMMenus.ItemSelection.state then
        local itemModal = GMMenus.ItemSelection.state.itemSelectionModal
        if itemModal and itemModal:IsVisible() then
            itemModal:Hide()
        end
    end

    -- Clear spell modal if not keeping it
    if keepType ~= "spell" and GMMenus.SpellSelection and GMMenus.SpellSelection.state then
        local spellModal = GMMenus.SpellSelection.state.spellSelectionModal
        if spellModal and spellModal:IsVisible() then
            spellModal:Hide()
        end
    end

    -- Clear inventory modal if not keeping it
    if keepType ~= "inventory" then
        local PlayerInventory = _G.PlayerInventory
        if PlayerInventory and PlayerInventory.currentModal then
            if PlayerInventory.currentModal:IsVisible() then
                PlayerInventory.currentModal:Hide()
                PlayerInventory.currentModal = nil
            end
        end
    end

    -- Clear template editors if not keeping them
    if keepType ~= "editor_item" then
        local ItemTemplateEditor = _G.ItemTemplateEditor
        if ItemTemplateEditor and ItemTemplateEditor.frame and ItemTemplateEditor.frame:IsVisible() then
            ItemTemplateEditor.frame:Hide()
            ItemTemplateEditor.isOpen = false
        end
    end

    if keepType ~= "editor_creature" then
        local CreatureTemplateEditor = _G.CreatureTemplateEditor
        if CreatureTemplateEditor and CreatureTemplateEditor.frame and CreatureTemplateEditor.frame:IsVisible() then
            CreatureTemplateEditor.frame:Hide()
            if CreatureTemplateEditor.isOpen ~= nil then
                CreatureTemplateEditor.isOpen = false
            end
        end
    end

    if keepType ~= "editor_gameobject" then
        local GameObjectTemplateEditor = _G.GameObjectTemplateEditor
        if GameObjectTemplateEditor and GameObjectTemplateEditor.frame and GameObjectTemplateEditor.frame:IsVisible() then
            GameObjectTemplateEditor.frame:Hide()
            if GameObjectTemplateEditor.isOpen ~= nil then
                GameObjectTemplateEditor.isOpen = false
            end
        end
    end

    -- Clear object editor if not keeping it
    if keepType ~= "object_editor" then
        local ObjectEditor = _G.ObjectEditor
        if ObjectEditor and ObjectEditor.dialog and ObjectEditor.dialog:IsVisible() then
            ObjectEditor.dialog:Hide()
        end
    end

    -- Clear entity selection dialog if not keeping it
    if keepType ~= "entity_selection" then
        local EntitySelectionDialog = _G.EntitySelectionDialog
        if EntitySelectionDialog and EntitySelectionDialog.dialog and EntitySelectionDialog.dialog:IsVisible() then
            EntitySelectionDialog.dialog:Hide()
        end
    end

    -- Clear mail dialog if not keeping it
    if keepType ~= "mail_dialog" then
        local GMData = _G.GMData
        if GMData and GMData.frames and GMData.frames.currentMailFrame and GMData.frames.currentMailFrame:IsVisible() then
            GMData.frames.currentMailFrame:Hide()
            GMData.frames.currentMailFrame = nil
        end
    end

    -- Clear report dialog if not keeping it
    if keepType ~= "report_dialog" then
        local GMReportDialog = _G.GMReportDialog
        if GMReportDialog and GMReportDialog.Hide then
            GMReportDialog.Hide()
        end
    end

    -- Clear teleport dialog if not keeping it
    if keepType ~= "teleport" then
        local GameMasterSystem = _G.GameMasterSystem
        if GameMasterSystem and GameMasterSystem.CloseTeleportList then
            GameMasterSystem.CloseTeleportList()
        end
    end
end

function StateMachine.clearAllModals()
    StateMachine.clearOtherModals(nil)
end

-- Main state transition function
function StateMachine.transitionTo(newState, context)
    local currentState = StateMachine.currentState

    -- Check if transition is valid
    if not StateMachine.transitions[currentState] or not StateMachine.transitions[currentState][newState] then
        local errorMsg = string.format("Invalid state transition from %s to %s", currentState, newState)

        -- ALWAYS print error details to console (not just in debug mode)
        print("[StateMachine ERROR] " .. errorMsg)

        -- Print available transitions from current state for debugging
        if StateMachine.transitions[currentState] then
            local available = {}
            for state, _ in pairs(StateMachine.transitions[currentState]) do
                table.insert(available, state)
            end
            print("[StateMachine] Available transitions from " .. currentState .. ": " .. table.concat(available, ", "))
        else
            print("[StateMachine] No valid transitions defined for state: " .. currentState)
        end

        -- Print context if provided
        if context then
            print("[StateMachine] Context: activeModal=" .. tostring(context.activeModal) .. ", targetPlayer=" .. tostring(context.targetPlayer))
        end

        -- Record failed transition for debugging
        table.insert(StateMachine.stateHistory, {
            from = currentState,
            to = newState,
            timestamp = GetTime(),
            error = errorMsg,
            context = context
        })

        -- Show informative toast with actual state names
        local shortCurrentState = currentState:gsub("_", " ")
        local shortNewState = newState:gsub("_", " ")
        CreateStyledToast(string.format("Cannot open %s while in %s state", shortNewState, shortCurrentState), 4, 0.5)

        return false, errorMsg
    end

    -- Call exit callback for current state (with error handling)
    if StateMachine.onExit[currentState] then
        local success, errorMsg = pcall(StateMachine.onExit[currentState])
        if not success then
            local exitError = string.format("Exit callback failed for state %s: %s", currentState, errorMsg or "unknown error")
            -- ALWAYS print exit errors
            print("[StateMachine ERROR] " .. exitError)
            -- Continue with transition but log the error
            StateMachine.context.lastExitError = exitError
        end
    end

    -- Update context if provided
    if context then
        for key, value in pairs(context) do
            StateMachine.context[key] = value
        end
    end

    -- Record state change
    table.insert(StateMachine.stateHistory, {
        from = currentState,
        to = newState,
        timestamp = GetTime(),
        context = context
    })

    -- Keep history manageable
    if #StateMachine.stateHistory > 50 then
        table.remove(StateMachine.stateHistory, 1)
    end

    -- Update current state
    StateMachine.currentState = newState
    StateMachine.context.stateEnterTime = GetTime()
    StateMachine.context.timeoutWarned = false

    -- Call entry callback for new state (with comprehensive error handling)
    if StateMachine.onEnter[newState] then
        local success, errorMsg = pcall(StateMachine.onEnter[newState])
        if not success then
            local enterError = string.format("Enter callback failed for state %s: %s", newState, errorMsg or "unknown error")
            -- ALWAYS print enter errors
            print("[StateMachine ERROR] " .. enterError)

            -- Critical failure handling - attempt recovery
            StateMachine.context.lastEnterError = enterError
            StateMachine.context.recoveryAttempts = (StateMachine.context.recoveryAttempts or 0) + 1

            -- If entering a modal state failed, try to fall back to IDLE
            if StateMachine.isModalOpen() and StateMachine.context.recoveryAttempts < 3 then
                print("[StateMachine] Modal state entry failed, attempting recovery to IDLE")
                -- Recursive call with recovery (clear context to avoid infinite loop)
                local originalRecoveryAttempts = StateMachine.context.recoveryAttempts
                StateMachine.context.recoveryAttempts = 0
                local recoverySuccess = StateMachine.transitionTo(StateMachine.STATES.IDLE)
                StateMachine.context.recoveryAttempts = originalRecoveryAttempts

                if recoverySuccess then
                    CreateStyledToast("Modal failed to open, returned to main view", 3, 0.5)
                    return false, enterError -- Return false to indicate original transition failed
                end
            end

            -- If recovery also failed or we're in a critical state, show error but continue
            if newState == StateMachine.STATES.ERROR or StateMachine.context.recoveryAttempts >= 3 then
                CreateStyledToast("System error occurred - functionality may be limited", 4, 0.5)
            end
        end
    end

    -- Clear recovery attempts on successful transition
    if StateMachine.context.recoveryAttempts then
        StateMachine.context.recoveryAttempts = 0
    end

    -- Silent transitions in production mode
    if _G.GM_DEBUG then
        print(string.format("[StateMachine] Transitioned from %s to %s", currentState, newState))
    end

    -- Auto-save state for persistence (throttled to avoid spam)
    local currentTime = GetTime()
    if currentTime - (StateMachine.context.lastSaved or 0) > 5 then -- Save at most every 5 seconds
        StateMachine.saveState()
    end

    return true
end

-- Convenience functions for common transitions
function StateMachine.initialize()
    return StateMachine.transitionTo(StateMachine.STATES.IDLE)
end

function StateMachine.openItemSelection(playerName)
    return StateMachine.transitionTo(StateMachine.STATES.ITEM_SELECTION, {
        targetPlayer = playerName,
        activeModal = "item"
    })
end

function StateMachine.openSpellSelection(playerName, castType)
    return StateMachine.transitionTo(StateMachine.STATES.SPELL_SELECTION, {
        targetPlayer = playerName,
        activeModal = "spell",
        castType = castType
    })
end

function StateMachine.openDialog(dialogType)
    return StateMachine.transitionTo(StateMachine.STATES.DIALOG_OPEN, {
        activeModal = "dialog",
        dialogType = dialogType
    })
end

function StateMachine.closeModal()
    -- Don't try to close if already in IDLE or transitioning
    if StateMachine.currentState == StateMachine.STATES.IDLE then
        return true -- Already closed
    end

    -- Clear persisted state when returning to IDLE
    StateMachine.clearPersistedState()
    return StateMachine.transitionTo(StateMachine.STATES.IDLE)
end

function StateMachine.startLoading(operation)
    local operations = StateMachine.context.loadingOperations
    table.insert(operations, operation)
    return StateMachine.transitionTo(StateMachine.STATES.LOADING)
end

function StateMachine.finishLoading(operation)
    local operations = StateMachine.context.loadingOperations
    for i, op in ipairs(operations) do
        if op == operation then
            table.remove(operations, i)
            break
        end
    end

    -- If no more loading operations, return to previous state
    if #operations == 0 then
        -- Determine where to return based on context
        if StateMachine.context.activeModal == "item" then
            return StateMachine.transitionTo(StateMachine.STATES.ITEM_SELECTION)
        elseif StateMachine.context.activeModal == "spell" then
            return StateMachine.transitionTo(StateMachine.STATES.SPELL_SELECTION)
        elseif StateMachine.context.activeModal == "dialog" then
            return StateMachine.transitionTo(StateMachine.STATES.DIALOG_OPEN)
        elseif StateMachine.context.activeModal == "inventory" then
            return StateMachine.transitionTo(StateMachine.STATES.INVENTORY)
        elseif StateMachine.context.activeModal == "editor_item" then
            return StateMachine.transitionTo(StateMachine.STATES.EDITOR_ITEM)
        elseif StateMachine.context.activeModal == "editor_creature" then
            return StateMachine.transitionTo(StateMachine.STATES.EDITOR_CREATURE)
        elseif StateMachine.context.activeModal == "editor_gameobject" then
            return StateMachine.transitionTo(StateMachine.STATES.EDITOR_GAMEOBJECT)
        elseif StateMachine.context.activeModal == "object_editor" then
            return StateMachine.transitionTo(StateMachine.STATES.OBJECT_EDITOR)
        elseif StateMachine.context.activeModal == "entity_selection" then
            return StateMachine.transitionTo(StateMachine.STATES.ENTITY_SELECTION)
        elseif StateMachine.context.activeModal == "mail_dialog" then
            return StateMachine.transitionTo(StateMachine.STATES.MAIL_DIALOG)
        elseif StateMachine.context.activeModal == "report_dialog" then
            return StateMachine.transitionTo(StateMachine.STATES.REPORT_DIALOG)
        elseif StateMachine.context.activeModal == "teleport" then
            return StateMachine.transitionTo(StateMachine.STATES.TELEPORT)
        else
            return StateMachine.transitionTo(StateMachine.STATES.IDLE)
        end
    end

    return true
end

function StateMachine.openInventory(playerName)
    return StateMachine.transitionTo(StateMachine.STATES.INVENTORY, {
        targetPlayer = playerName,
        activeModal = "inventory"
    })
end

function StateMachine.openItemEditor(itemEntry, isDuplicate)
    return StateMachine.transitionTo(StateMachine.STATES.EDITOR_ITEM, {
        activeModal = "editor_item",
        editTarget = itemEntry,
        isDuplicate = isDuplicate or false
    })
end

function StateMachine.openCreatureEditor(creatureEntry)
    return StateMachine.transitionTo(StateMachine.STATES.EDITOR_CREATURE, {
        activeModal = "editor_creature",
        editTarget = creatureEntry
    })
end

function StateMachine.openGameObjectEditor(gameObjectEntry)
    return StateMachine.transitionTo(StateMachine.STATES.EDITOR_GAMEOBJECT, {
        activeModal = "editor_gameobject",
        editTarget = gameObjectEntry
    })
end

function StateMachine.openObjectEditor(objectType, objectGuid)
    return StateMachine.transitionTo(StateMachine.STATES.OBJECT_EDITOR, {
        activeModal = "object_editor",
        objectType = objectType,
        objectGuid = objectGuid
    })
end

function StateMachine.openEntitySelection(editorType, callback)
    return StateMachine.transitionTo(StateMachine.STATES.ENTITY_SELECTION, {
        activeModal = "entity_selection",
        editorType = editorType,
        selectionCallback = callback
    })
end

function StateMachine.openMailDialog(playerName, mailData)
    return StateMachine.transitionTo(StateMachine.STATES.MAIL_DIALOG, {
        targetPlayer = playerName,
        activeModal = "mail_dialog",
        mailData = mailData
    })
end

function StateMachine.openReportDialog(reportType, reportData)
    return StateMachine.transitionTo(StateMachine.STATES.REPORT_DIALOG, {
        activeModal = "report_dialog",
        reportType = reportType,
        reportData = reportData
    })
end

function StateMachine.openTeleport(playerName)
    return StateMachine.transitionTo(StateMachine.STATES.TELEPORT, {
        targetPlayer = playerName,
        activeModal = "teleport"
    })
end

function StateMachine.error(errorMessage)
    return StateMachine.transitionTo(StateMachine.STATES.ERROR, {
        lastError = errorMessage
    })
end

-- State query functions
function StateMachine.getCurrentState()
    return StateMachine.currentState
end

function StateMachine.isIdle()
    return StateMachine.currentState == StateMachine.STATES.IDLE
end

function StateMachine.isModalOpen()
    return StateMachine.currentState == StateMachine.STATES.ITEM_SELECTION or
           StateMachine.currentState == StateMachine.STATES.SPELL_SELECTION or
           StateMachine.currentState == StateMachine.STATES.DIALOG_OPEN or
           StateMachine.currentState == StateMachine.STATES.INVENTORY or
           StateMachine.currentState == StateMachine.STATES.EDITOR_ITEM or
           StateMachine.currentState == StateMachine.STATES.EDITOR_CREATURE or
           StateMachine.currentState == StateMachine.STATES.EDITOR_GAMEOBJECT or
           StateMachine.currentState == StateMachine.STATES.OBJECT_EDITOR or
           StateMachine.currentState == StateMachine.STATES.ENTITY_SELECTION or
           StateMachine.currentState == StateMachine.STATES.MAIL_DIALOG or
           StateMachine.currentState == StateMachine.STATES.REPORT_DIALOG or
           StateMachine.currentState == StateMachine.STATES.TELEPORT
end

function StateMachine.isLoading()
    return StateMachine.currentState == StateMachine.STATES.LOADING
end

function StateMachine.canOpenModal()
    return StateMachine.currentState == StateMachine.STATES.IDLE
end

-- Debug functions
function StateMachine.getStateHistory()
    return StateMachine.stateHistory
end

function StateMachine.printStateHistory()
    print("=== State Machine History (last " .. #StateMachine.stateHistory .. " transitions) ===")
    for i, entry in ipairs(StateMachine.stateHistory) do
        local timeStr = string.format("%.2fs", entry.timestamp)
        if entry.error then
            print(string.format("[%d] %s -> %s (%s) ERROR: %s", i, entry.from, entry.to, timeStr, entry.error))
        else
            print(string.format("[%d] %s -> %s (%s)", i, entry.from, entry.to, timeStr))
        end
    end
    print("=== Current State: " .. StateMachine.currentState .. " ===")
end

function StateMachine.getContext()
    return StateMachine.context
end

-- Get error information for debugging
function StateMachine.getErrorInfo()
    local errors = {}

    if StateMachine.context.lastError then
        table.insert(errors, {
            type = "state_error",
            message = StateMachine.context.lastError,
            timestamp = StateMachine.context.stateEnterTime
        })
    end

    if StateMachine.context.lastExitError then
        table.insert(errors, {
            type = "exit_error",
            message = StateMachine.context.lastExitError,
            timestamp = GetTime()
        })
    end

    if StateMachine.context.lastEnterError then
        table.insert(errors, {
            type = "enter_error",
            message = StateMachine.context.lastEnterError,
            timestamp = GetTime()
        })
    end

    -- Get failed transitions from history
    for i = math.max(1, #StateMachine.stateHistory - 10), #StateMachine.stateHistory do
        local entry = StateMachine.stateHistory[i]
        if entry and entry.error then
            table.insert(errors, {
                type = "transition_error",
                message = entry.error,
                from = entry.from,
                to = entry.to,
                timestamp = entry.timestamp
            })
        end
    end

    return errors
end

-- State persistence functions
function StateMachine.saveState()
    if not StateMachine.context then
        return false
    end

    local persistenceData = {
        currentState = StateMachine.currentState,
        context = {
            activeModal = StateMachine.context.activeModal,
            modalType = StateMachine.context.modalType,
            targetPlayer = StateMachine.context.targetPlayer,
            editTarget = StateMachine.context.editTarget,
            objectType = StateMachine.context.objectType,
            objectGuid = StateMachine.context.objectGuid,
            editorType = StateMachine.context.editorType,
            castType = StateMachine.context.castType,
            dialogType = StateMachine.context.dialogType,
            reportType = StateMachine.context.reportType
        },
        timestamp = GetTime(),
        sessionId = StateMachine.context.persistenceId or StateMachine.generateSessionId()
    }

    -- Store in character-specific saved variables
    if not GMStateMachinePersistence then
        GMStateMachinePersistence = {}
    end

    GMStateMachinePersistence.lastState = persistenceData
    StateMachine.context.lastSaved = GetTime()

    if _G.GM_DEBUG then
        print("[StateMachine] State saved:", persistenceData.currentState)
    end

    return true
end

function StateMachine.restoreState()
    if not GMStateMachinePersistence or not GMStateMachinePersistence.lastState then
        if _G.GM_DEBUG then
            print("[StateMachine] No saved state found")
        end
        return false
    end

    local savedData = GMStateMachinePersistence.lastState
    local currentTime = GetTime()

    -- Only restore if saved within last 30 minutes (1800 seconds)
    if currentTime - savedData.timestamp > 1800 then
        if _G.GM_DEBUG then
            print("[StateMachine] Saved state too old, not restoring")
        end
        GMStateMachinePersistence.lastState = nil
        return false
    end

    -- Only restore modal states, not transient states like LOADING or ERROR
    local restorableStates = {
        [StateMachine.STATES.ITEM_SELECTION] = true,
        [StateMachine.STATES.SPELL_SELECTION] = true,
        [StateMachine.STATES.INVENTORY] = true,
        [StateMachine.STATES.EDITOR_ITEM] = true,
        [StateMachine.STATES.EDITOR_CREATURE] = true,
        [StateMachine.STATES.EDITOR_GAMEOBJECT] = true,
        [StateMachine.STATES.OBJECT_EDITOR] = true,
        [StateMachine.STATES.ENTITY_SELECTION] = true,
        [StateMachine.STATES.MAIL_DIALOG] = true,
        [StateMachine.STATES.REPORT_DIALOG] = true,
        [StateMachine.STATES.TELEPORT] = true
    }

    if not restorableStates[savedData.currentState] then
        if _G.GM_DEBUG then
            print("[StateMachine] Saved state not restorable:", savedData.currentState)
        end
        return false
    end

    -- Restore context
    for key, value in pairs(savedData.context) do
        StateMachine.context[key] = value
    end
    StateMachine.context.persistenceId = savedData.sessionId

    -- Restore state
    local success = StateMachine.transitionTo(savedData.currentState, savedData.context)

    if success and _G.GM_DEBUG then
        print("[StateMachine] State restored:", savedData.currentState)
    end

    return success
end

function StateMachine.generateSessionId()
    return "session_" .. math.floor(GetTime() * 1000) .. "_" .. math.random(1000, 9999)
end

function StateMachine.clearPersistedState()
    if GMStateMachinePersistence then
        GMStateMachinePersistence.lastState = nil
    end
    if _G.GM_DEBUG then
        print("[StateMachine] Persisted state cleared")
    end
end

-- Timeout detection and recovery functions
function StateMachine.checkForTimeout()
    local currentTime = GetTime()
    local currentState = StateMachine.currentState
    local stateEnterTime = StateMachine.context.stateEnterTime or currentTime
    local timeInState = currentTime - stateEnterTime

    -- Get timeout for current state
    local timeout = StateMachine.timeouts[currentState]
    if not timeout then
        return false -- No timeout configured for this state
    end

    -- Check if we've exceeded the timeout
    if timeInState > timeout then
        if _G.GM_DEBUG then
            print(string.format("[StateMachine] Timeout detected: %s for %.1f seconds (limit: %.1f)",
                currentState, timeInState, timeout))
        end

        StateMachine.handleTimeout(currentState, timeInState)
        return true
    end

    -- Warn at 75% of timeout
    local warnThreshold = timeout * 0.75
    if timeInState > warnThreshold and not StateMachine.context.timeoutWarned then
        StateMachine.context.timeoutWarned = true
        if _G.GM_DEBUG then
            print(string.format("[StateMachine] Timeout warning: %s for %.1f seconds (limit: %.1f)",
                currentState, timeInState, timeout))
        end
    end

    return false
end

function StateMachine.handleTimeout(state, timeInState)
    StateMachine.context.recoveryAttempts = (StateMachine.context.recoveryAttempts or 0) + 1

    -- Log the timeout
    if _G.GM_DEBUG then
        print(string.format("[StateMachine] Handling timeout for state %s (attempt #%d)",
            state, StateMachine.context.recoveryAttempts))
    end

    -- Recovery strategies based on state type
    local recovered = false

    if state == StateMachine.STATES.INITIALIZING then
        -- Force initialization complete
        local GMData = _G.GMData
        if GMData then
            GMData.PlayerGMLevel = GMData.PlayerGMLevel or 3
            GMData.CoreName = GMData.CoreName or "Timeout-Recovered"
            GMData.isGmLevelFetched = true
            GMData.isCoreNameFetched = true
        end
        recovered = StateMachine.initialize()

    elseif state == StateMachine.STATES.LOADING then
        -- Clear loading operations and return to previous state or IDLE
        wipe(StateMachine.context.loadingOperations)
        if StateMachine.context.activeModal then
            -- Try to return to the modal state
            if StateMachine.context.activeModal == "item" then
                recovered = StateMachine.transitionTo(StateMachine.STATES.ITEM_SELECTION)
            elseif StateMachine.context.activeModal == "spell" then
                recovered = StateMachine.transitionTo(StateMachine.STATES.SPELL_SELECTION)
            elseif StateMachine.context.activeModal == "inventory" then
                recovered = StateMachine.transitionTo(StateMachine.STATES.INVENTORY)
            else
                recovered = StateMachine.transitionTo(StateMachine.STATES.IDLE)
            end
        else
            recovered = StateMachine.transitionTo(StateMachine.STATES.IDLE)
        end

    elseif state == StateMachine.STATES.ERROR then
        -- Clear error and return to IDLE
        StateMachine.context.lastError = nil
        recovered = StateMachine.transitionTo(StateMachine.STATES.IDLE)

    else
        -- For modal states, check if the modal is actually visible
        local modalVisible = StateMachine.checkModalVisibility(state)
        if not modalVisible then
            -- Modal not visible, safe to return to IDLE
            recovered = StateMachine.transitionTo(StateMachine.STATES.IDLE)
        else
            -- Modal is visible, extend timeout (user might be using it)
            StateMachine.context.stateEnterTime = GetTime() - (StateMachine.timeouts[state] * 0.5)
            StateMachine.context.timeoutWarned = false
            recovered = true
            if _G.GM_DEBUG then
                print("[StateMachine] Modal still visible, extending timeout")
            end
        end
    end

    if recovered then
        StateMachine.context.recoveryAttempts = 0
        if _G.GM_DEBUG then
            print("[StateMachine] Recovery successful")
        end
    else
        -- Recovery failed, try fallback
        if StateMachine.context.recoveryAttempts < 3 then
            -- Try again later
            if _G.GM_DEBUG then
                print("[StateMachine] Recovery failed, will retry")
            end
        else
            -- Force to IDLE as last resort
            print("[StateMachine] Multiple recovery attempts failed, forcing to IDLE")
            StateMachine.currentState = StateMachine.STATES.IDLE
            StateMachine.clearAllModals()
            StateMachine.context.recoveryAttempts = 0
        end
    end
end

function StateMachine.checkModalVisibility(state)
    -- Check if modals associated with the state are actually visible
    local GMMenus = _G.GMMenus
    local PlayerInventory = _G.PlayerInventory

    if state == StateMachine.STATES.ITEM_SELECTION then
        return GMMenus and GMMenus.ItemSelection and GMMenus.ItemSelection.state and
               GMMenus.ItemSelection.state.itemSelectionModal and
               GMMenus.ItemSelection.state.itemSelectionModal:IsVisible()
    elseif state == StateMachine.STATES.SPELL_SELECTION then
        return GMMenus and GMMenus.SpellSelection and GMMenus.SpellSelection.state and
               GMMenus.SpellSelection.state.spellSelectionModal and
               GMMenus.SpellSelection.state.spellSelectionModal:IsVisible()
    elseif state == StateMachine.STATES.INVENTORY then
        return PlayerInventory and PlayerInventory.currentModal and
               PlayerInventory.currentModal:IsVisible()
    elseif state == StateMachine.STATES.EDITOR_ITEM then
        local ItemTemplateEditor = _G.ItemTemplateEditor
        return ItemTemplateEditor and ItemTemplateEditor.frame and
               ItemTemplateEditor.frame:IsVisible()
    elseif state == StateMachine.STATES.EDITOR_CREATURE then
        local CreatureTemplateEditor = _G.CreatureTemplateEditor
        return CreatureTemplateEditor and CreatureTemplateEditor.frame and
               CreatureTemplateEditor.frame:IsVisible()
    elseif state == StateMachine.STATES.EDITOR_GAMEOBJECT then
        local GameObjectTemplateEditor = _G.GameObjectTemplateEditor
        return GameObjectTemplateEditor and GameObjectTemplateEditor.frame and
               GameObjectTemplateEditor.frame:IsVisible()
    elseif state == StateMachine.STATES.OBJECT_EDITOR then
        local ObjectEditor = _G.ObjectEditor
        return ObjectEditor and ObjectEditor.dialog and ObjectEditor.dialog:IsVisible()
    elseif state == StateMachine.STATES.ENTITY_SELECTION then
        local EntitySelectionDialog = _G.EntitySelectionDialog
        return EntitySelectionDialog and EntitySelectionDialog.dialog and
               EntitySelectionDialog.dialog:IsVisible()
    end

    -- Default: assume not visible if we can't determine
    return false
end

-- Initialize state machine
StateMachine.currentState = StateMachine.STATES.INITIALIZING

-- Export to GameMasterSystem
GameMasterSystem.StateMachine = StateMachine

-- Start timeout monitoring system
local timeoutMonitor = CreateFrame("Frame")
local monitorElapsed = 0
timeoutMonitor:SetScript("OnUpdate", function(self, elapsed)
    monitorElapsed = monitorElapsed + elapsed
    if monitorElapsed >= 5.0 then -- Check every 5 seconds
        monitorElapsed = 0
        StateMachine.checkForTimeout()
    end
end)

-- Attempt to restore state after a short delay (allow other systems to load)
local restoreFrame = CreateFrame("Frame")
local restoreElapsed = 0
restoreFrame:SetScript("OnUpdate", function(self, elapsed)
    restoreElapsed = restoreElapsed + elapsed
    if restoreElapsed >= 3.0 then -- Wait 3 seconds for systems to initialize
        self:SetScript("OnUpdate", nil)

        -- Only attempt restore if we're still in INITIALIZING state
        if StateMachine.currentState == StateMachine.STATES.INITIALIZING then
            local restored = StateMachine.restoreState()
            if not restored then
                -- No state to restore, initialize normally
                StateMachine.initialize()
            end
        end
    end
end)