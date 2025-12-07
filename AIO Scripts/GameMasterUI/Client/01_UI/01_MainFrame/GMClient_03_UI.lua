-- GameMaster UI System - UI Creation
-- This file handles all UI creation using UIStyleLibrary functions
-- Load order: 03 (Fourth)

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

local GMData = _G.GMData
local GMConfig = _G.GMConfig
local GMUI = _G.GMUI
local HotkeyManager = _G.GMHotkeyManager

-- Create the main frame using UIStyleLibrary
function GMUI.createMainFrame()
    -- Create styled frame
    local frame = CreateStyledFrame(UIParent, UISTYLE_COLORS.DarkGrey)
    frame:SetSize(GMConfig.config.BG_WIDTH, GMConfig.config.BG_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("MEDIUM")
    
    -- Make frame draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Add to special frames for ESC key support
    tinsert(UISpecialFrames, frame:GetName() or "GameMasterMainFrame")
    
    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("Staff System")
    title:SetTextColor(1, 1, 1)
    
    -- Report button in title bar (left of refresh)
    local titleReportBtn = CreateStyledButton(frame, "!", 24, 24)
    titleReportBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -59, -5)
    titleReportBtn:SetScript("OnClick", function(self)
        -- Simple visual feedback - change color temporarily
        self.text:SetTextColor(1, 0.5, 0)  -- Orange during click
        
        -- Use OnUpdate to restore color after a short time (WoW 3.3.5 compatible)
        local elapsed = 0
        titleReportBtn:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.3 then
                self.text:SetTextColor(1, 1, 1)  -- Back to white
                self:SetScript("OnUpdate", nil)  -- Remove the OnUpdate handler
            end
        end)
        
        -- Open report dialog
        if GMReportDialog then
            GMReportDialog.Show()
        end
    end)
    titleReportBtn:SetTooltip("Report Issue", "Report a bug or suggest improvement")
    
    -- Refresh button in title bar (like inventory display)
    local titleRefreshBtn = CreateStyledButton(frame, "R", 24, 24)
    titleRefreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -5)
    titleRefreshBtn:SetScript("OnClick", function(self)
        -- Simple visual feedback - change color temporarily
        self.text:SetTextColor(0, 1, 0)  -- Green during refresh
        
        -- Use OnUpdate to restore color after a short time (WoW 3.3.5 compatible)
        local elapsed = 0
        titleRefreshBtn:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.5 then
                self.text:SetTextColor(1, 1, 1)  -- Back to white
                self:SetScript("OnUpdate", nil)  -- Remove the OnUpdate handler
            end
        end)
        
        -- Handle refresh logic directly
        if GMData.activeTab then
            -- Special handling for Player Management tab
            if GMData.activeTab == 6 then
                if GMCards and GMCards.PlayerList and GMCards.PlayerList.RequestPlayerData then
                    GMCards.PlayerList.RequestPlayerData()
                else
                    AIO.Handle("GameMasterSystem", "refreshPlayerData")
                end
            else
                -- Other tabs - just re-request current data
                GMUI.requestDataForTab(GMData.activeTab)
            end
        end
    end)
    titleRefreshBtn:SetTooltip("Refresh (Ctrl+R)", "Reload current data from server")
    
    -- Close button using UIStyleLibrary
    local closeButton = CreateStyledButton(frame, "X", 24, 24)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Enable keyboard input for hotkey handling
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(self, key)
        -- Try HotkeyManager first
        if HotkeyManager and HotkeyManager.handleKeyPress(key) then
            return -- Handled by HotkeyManager
        end

        -- Handle ESCAPE directly (not managed by HotkeyManager)
        if key == "ESCAPE" then
            self:Hide()
        end
        -- In 3.3.5, we don't have SetPropagateKeyboardInput
        -- Keys naturally propagate unless we explicitly handle them
    end)

    -- Register Ctrl+R handler with HotkeyManager
    if HotkeyManager then
        HotkeyManager.register({
            key = "R",
            modifiers = {ctrl = true, alt = false, shift = false},
            context = "main_frame",
            priority = 0, -- Lowest priority (modals take precedence)
            handler = function()
                -- Check if any modal dialogs are open using state machine
                local StateMachine = _G.GMStateMachine
                if StateMachine and StateMachine.isModalOpen() then
                    return -- Let modal handle it
                end

                -- Trigger title refresh button click for visual feedback
                if titleRefreshBtn then
                    titleRefreshBtn:Click()
                end
                print("[GameMasterUI] Refreshing data (Ctrl+R pressed)")
            end
        })

        -- Register Ctrl+F handler with HotkeyManager
        HotkeyManager.register({
            key = "F",
            modifiers = {ctrl = true, alt = false, shift = false},
            context = "main_frame",
            priority = 0, -- Lowest priority (modals take precedence)
            handler = function()
                -- Check if any modal dialogs are open using state machine
                local StateMachine = _G.GMStateMachine
                if StateMachine and StateMachine.isModalOpen() then
                    return -- Let modal handle it
                end

                GMUI.focusSearchBox()
            end
        })
    end
    
    -- Store references
    GMData.frames.mainFrame = frame
    GMData.frames.titleRefreshBtn = titleRefreshBtn
    GMData.frames.titleReportBtn = titleReportBtn
    
    return frame
end

-- Create content container system
function GMUI.createContentContainer(parent)
    -- Create category indicator first (positioned above content area)
    local categoryIndicator = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryIndicator:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -55)
    categoryIndicator:SetTextColor(0.8, 0.8, 0.8)
    categoryIndicator:Hide() -- Hidden by default
    
    -- Create main content area using styled frame
    local contentArea = CreateStyledFrame(parent, UISTYLE_COLORS.OptionBg)
    -- Adjust height: 80px top (dropdowns + category) + 50px bottom for pagination = 130px total
    contentArea:SetSize(parent:GetWidth() - 20, parent:GetHeight() - 125)
    contentArea:SetPoint("TOP", parent, "TOP", 0, -75) -- Position below dropdowns and category
    
    -- Enable mouse wheel for page navigation with throttling
    contentArea:EnableMouseWheel(true)
    
    -- Initialize throttling variables
    if not GMData.mouseWheelThrottle then
        GMData.mouseWheelThrottle = {
            lastScroll = 0,
            throttleDelay = 0.05, -- 50ms between scroll actions (faster scrolling)
            pendingDirection = nil
        }
    end
    
    contentArea:SetScript("OnMouseWheel", function(self, delta)
        local now = GetTime()
        local throttle = GMData.mouseWheelThrottle
        
        -- Store the scroll direction
        throttle.pendingDirection = delta > 0 and "up" or "down"
        
        -- Check if we're still in throttle period
        if now - throttle.lastScroll < throttle.throttleDelay then
            return -- Ignore this scroll event
        end
        
        -- Update last scroll time
        throttle.lastScroll = now
        local direction = throttle.pendingDirection
        
        -- Get current tab state
        local state = GMUtils.GetTabState(GMData.activeTab)
        
        if direction == "up" then
            -- Scroll up = Previous page
            local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
            if currentOffset > 0 then
                local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
                state.currentOffset = math.max(0, currentOffset - pageSize)
                GMData.currentOffset = state.currentOffset
                GMUI.requestDataForTab(GMData.activeTab)
            end
        else
            -- Scroll down = Next page
            if state.hasMoreData then
                local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
                local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
                state.currentOffset = currentOffset + pageSize
                GMData.currentOffset = state.currentOffset
                GMUI.requestDataForTab(GMData.activeTab)
            end
        end
        
        -- Clear pending direction
        throttle.pendingDirection = nil
    end)
    
    -- Initialize dynamic content frames storage
    GMData.dynamicContentFrames = {}
    
    -- Store references
    GMData.frames.contentArea = contentArea
    GMData.frames.categoryIndicator = categoryIndicator
    
    return contentArea
end

-- Create search functionality
function GMUI.createSearchBox(parent)
    local searchBox = CreateStyledSearchBox(parent, 200, "Search...", function(text)
        -- Handle search
        GMData.currentSearchQuery = text
        
        -- Reset pagination for current tab when searching
        GMUtils.ResetTabState(GMData.activeTab)
        local state = GMUtils.GetTabState(GMData.activeTab)
        state.searchQuery = text
        GMData.currentOffset = 0
        
        -- Request data for current tab with search query
        if GMData.activeTab then
            GMUI.requestDataForTab(GMData.activeTab)
        end
    end)
    
    searchBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -85, -40)  -- Positioned to accommodate teleport button
    
    GMData.frames.searchBox = searchBox
    return searchBox
end

-- Clear search functionality
function GMUI.clearSearch()
    GMData.currentSearchQuery = ""
    
    -- Reset pagination for current tab
    GMUtils.ResetTabState(GMData.activeTab)
    GMData.currentOffset = 0
    
    -- Update search box UI
    if GMData.frames.searchBox and GMData.frames.searchBox.editBox then
        GMData.frames.searchBox.editBox:SetText("")
        GMData.frames.searchBox.editBox:ClearFocus()
    end
    
    -- Request fresh data for current tab
    if GMData.activeTab then
        GMUI.requestDataForTab(GMData.activeTab)
    end
end

-- Focus search box functionality (Ctrl+F)
function GMUI.focusSearchBox()
    -- Safety check: ensure search box exists
    if GMData.frames.searchBox and GMData.frames.searchBox.editBox then
        -- Focus the search box
        GMData.frames.searchBox.editBox:SetFocus()
        -- Optional: Select all text for easy replacement
        GMData.frames.searchBox.editBox:HighlightText()
    end
end

-- Create sort dropdown
function GMUI.createSortDropdown(parent)
    -- Wait for category dropdown to be created
    if not GMData.frames.categoryDropdown then
        -- Warning: Category dropdown not found, creating sort dropdown anyway
    end
    
    -- Create label for sort dropdown
    local sortLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if GMData.frames.categoryDropdown then
        sortLabel:SetPoint("LEFT", GMData.frames.categoryDropdown, "RIGHT", 20, 0)
    else
        sortLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 170, -15)
    end
    sortLabel:SetText("Sort:")
    sortLabel:SetTextColor(0.8, 0.8, 0.8)
    
    -- Helper function to get display text for sort order
    local function getSortDisplayText(sortOrder)
        return (sortOrder == "DESC") and "Descending" or "Ascending"
    end
    
    -- Create sort dropdown items
    local sortDropdown -- Forward declaration
    local sortItems = {
        {
            text = "Ascending",
            value = "ASC",
            func = function()
                GMData.sortOrder = "ASC"
                if sortDropdown then
                    sortDropdown.text:SetText("Ascending")
                end
                if GameMasterSystem.refreshData then
                    GameMasterSystem.refreshData()
                end
            end
        },
        {
            text = "Descending", 
            value = "DESC",
            func = function()
                GMData.sortOrder = "DESC"
                if sortDropdown then
                    sortDropdown.text:SetText("Descending")
                end
                if GameMasterSystem.refreshData then
                    GameMasterSystem.refreshData()
                end
            end
        }
    }
    
    -- Create fully styled dropdown
    local sortMenuFrame
    sortDropdown, sortMenuFrame = CreateFullyStyledDropdown(
        parent,
        120,
        sortItems,
        getSortDisplayText(GMData.sortOrder),
        function(value, item)
            -- Additional handling if needed
            if GMConfig.config.debug then
                -- Debug: Sort order changed
            end
        end
    )
    
    -- Position the dropdown next to the label
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", 10, 0)
    
    GMData.frames.sortDropdown = sortDropdown
    GMData.frames.sortMenuFrame = sortMenuFrame
    GMData.frames.sortLabel = sortLabel
    
    return sortDropdown, sortMenuFrame
end

-- Create pagination controls
function GMUI.createPaginationControls(parent)
    -- Create pagination container
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(parent:GetWidth() - 20, 40)
    container:SetPoint("BOTTOM", parent, "BOTTOM", 0, 5)
    
    -- Calculate total width needed for all controls
    -- Buttons: << (35) + < (35) + Page container (150) + > (35) + >> (35) = 290
    -- Plus spacing: 4 gaps * 10 pixels = 40
    local totalControlsWidth = 330
    local centerX = (container:GetWidth() - totalControlsWidth) / 2
    
    -- First page button (<<)
    local firstButton = CreateStyledButton(container, "<<", 35, 25)
    firstButton:SetPoint("LEFT", container, "LEFT", centerX, 0)
    firstButton:SetScript("OnClick", function()
        local state = GMUtils.GetTabState(GMData.activeTab)
        local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
        if currentOffset > 0 then
            state.currentOffset = 0
            GMData.currentOffset = 0
            GMUI.requestDataForTab(GMData.activeTab)
        end
    end)
    
    -- Previous button (<)
    local prevButton = CreateStyledButton(container, "<", 35, 25)
    prevButton:SetPoint("LEFT", firstButton, "RIGHT", 10, 0)
    prevButton:SetScript("OnClick", function()
        local state = GMUtils.GetTabState(GMData.activeTab)
        local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
        if currentOffset > 0 then
            local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
            state.currentOffset = math.max(0, currentOffset - pageSize)
            GMData.currentOffset = state.currentOffset
            GMUI.requestDataForTab(GMData.activeTab)
        end
    end)
    
    -- Page input container
    local pageContainer = CreateFrame("Frame", nil, container)
    pageContainer:SetSize(150, 25)
    pageContainer:SetPoint("LEFT", prevButton, "RIGHT", 10, 0)
    
    -- Page label (changed to white/gray)
    local pageLabel = pageContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pageLabel:SetPoint("LEFT", pageContainer, "LEFT", 0, 0)
    pageLabel:SetText("Page:")
    pageLabel:SetTextColor(0.8, 0.8, 0.8)
    
    -- Page input box
    local pageInput = CreateFrame("EditBox", nil, pageContainer)
    pageInput:SetSize(40, 20)
    pageInput:SetPoint("LEFT", pageLabel, "RIGHT", 5, 0)
    pageInput:SetFontObject("GameFontHighlight")
    pageInput:SetAutoFocus(false)
    pageInput:SetMaxLetters(4)
    pageInput:SetNumeric(true)
    
    -- Style the input
    local inputBg = pageInput:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints()
    inputBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    inputBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    
    -- Total pages display (changed to white/gray)
    local totalPages = pageContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    totalPages:SetPoint("LEFT", pageInput, "RIGHT", 5, 0)
    totalPages:SetText("/ 1")
    totalPages:SetTextColor(0.8, 0.8, 0.8)
    
    -- Go button
    local goButton = CreateStyledButton(pageContainer, "Go", 30, 20)
    goButton:SetPoint("LEFT", totalPages, "RIGHT", 5, 0)
    goButton:SetScript("OnClick", function()
        local pageNum = tonumber(pageInput:GetText())
        if pageNum and GMUtils.GoToPage(GMData.activeTab, pageNum) then
            GMUI.requestDataForTab(GMData.activeTab)
            pageInput:ClearFocus()
        end
    end)
    
    pageInput:SetScript("OnEnterPressed", function()
        goButton:Click()
    end)
    
    -- Next button (>)
    local nextButton = CreateStyledButton(container, ">", 35, 25)
    nextButton:SetPoint("LEFT", pageContainer, "RIGHT", 10, 0)
    nextButton:SetScript("OnClick", function()
        local state = GMUtils.GetTabState(GMData.activeTab)
        if state.hasMoreData then
            local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
            local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
            state.currentOffset = currentOffset + pageSize
            GMData.currentOffset = state.currentOffset
            GMUI.requestDataForTab(GMData.activeTab)
        end
    end)
    
    -- Last page button (>>)
    local lastButton = CreateStyledButton(container, ">>", 35, 25)
    lastButton:SetPoint("LEFT", nextButton, "RIGHT", 10, 0)
    lastButton:SetScript("OnClick", function()
        local state = GMUtils.GetTabState(GMData.activeTab)
        local totalPages = tonumber(GMUtils.safeGetValue(state.totalPages)) or 1
        local totalCount = tonumber(GMUtils.safeGetValue(state.totalCount)) or 0
        if totalPages > 1 and totalCount > 0 then
            local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
            local newOffset = (totalPages - 1) * pageSize
            state.currentOffset = newOffset
            GMData.currentOffset = newOffset
            GMUI.requestDataForTab(GMData.activeTab)
        end
    end)
    
    -- Pagination info display (above controls with more spacing)
    local paginationInfo = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    paginationInfo:SetPoint("BOTTOM", container, "TOP", 0, 12)
    paginationInfo:SetTextColor(0.7, 0.7, 0.7)
    
    -- Store references
    GMData.frames.firstButton = firstButton
    GMData.frames.prevButton = prevButton
    GMData.frames.nextButton = nextButton
    GMData.frames.lastButton = lastButton
    GMData.frames.pageInput = pageInput
    GMData.frames.totalPagesText = totalPages
    GMData.frames.paginationInfo = paginationInfo
    GMData.frames.paginationContainer = container
    
    return container
end


-- Create category dropdown menu
function GMUI.createCategoryDropdown(parent)
    -- Build nested menu structure for styled dropdown
    local dropdownItems = GMUI.buildDropdownItems()
    
    -- Create fully styled dropdown with nested menu support
    local dropdown, menuFrame = CreateFullyStyledDropdown(
        parent,
        150,
        dropdownItems,
        "Select Category",
        function(value, item)
            -- Handle selection if needed
            if GMConfig.config.debug then
                -- Debug: Dropdown selection
            end
        end
    )
    
    -- Position the dropdown
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -15)
    
    GMData.frames.categoryDropdown = dropdown
    GMData.frames.categoryMenu = menuFrame
    return dropdown, menuFrame
end

-- Initialize dropdown menu content
function GMUI.initializeDropdownMenu(frame, level, menuList)
    if not frame then return end
    
    level = level or 1
    local info = UIDropDownMenu_CreateInfo()
    
    if level == 1 then
        -- Main menu items
        local menuItems = GMUI.getMainMenuItems()
        for _, item in ipairs(menuItems) do
            wipe(info)
            info.text = item.text
            info.func = item.func
            info.notCheckable = true
            
            if item.hasArrow then
                info.hasArrow = true
                info.menuList = item.menuList
            end
            
            UIDropDownMenu_AddButton(info, level)
        end
    elseif level == 2 then
        -- Submenu items
        if menuList == "spell" then
            GMUI.addSpellSubmenu(info, level)
        elseif menuList == "items" then
            GMUI.addItemsSubmenu(info, level)
        elseif menuList == "categories" then
            -- Item categories submenu
            wipe(info)
            info.text = "Equipment"
            info.hasArrow = true
            info.menuList = "equipment"
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            wipe(info)
            info.text = "Weapons"
            info.hasArrow = true
            info.menuList = "weapons"
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            wipe(info)
            info.text = "Misc"
            info.hasArrow = true
            info.menuList = "misc"
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    elseif level == 3 then
        -- Third level menus
        if menuList == "equipment" then
            GMUI.addEquipmentSubmenu(info, level)
        elseif menuList == "weapons" then
            GMUI.addWeaponsSubmenu(info, level)
        elseif menuList == "misc" then
            GMUI.addMiscSubmenu(info, level)
        end
    end
end

-- Build dropdown items for styled dropdown
function GMUI.buildDropdownItems()
    local items = {}
    
    -- Build all items first
    local allItems = {
        -- Creatures
        {
            text = "Creatures",
            value = "creatures",
            func = function()
                GMUI.switchToTab(1)
            end
        },
        -- GM Powers
        {
            text = "GM Powers",
            value = "gmpowers",
            func = function()
                GMUI.switchToTab(7)
            end
        },
        -- Items submenu
        {
            text = "Items",
            hasArrow = true,
            menuList = (function()
                local itemsMenu = {
                    {
                        text = "Search All Items",
                        value = "allitems",
                        notCheckable = true,
                        func = function()
                            GMUI.switchToTab(5)
                        end
                    }
                }
                -- Add category menus directly to items menu
                local categories = GMUI.buildItemCategoriesMenu()
                for _, category in ipairs(categories) do
                    table.insert(itemsMenu, category)
                end
                return itemsMenu
            end)()
        },
        -- Objects
        {
            text = "Objects", 
            value = "objects",
            func = function()
                GMUI.switchToTab(2)
            end
        },
        -- Player Management
        {
            text = "Player Management",
            value = "players",
            func = function()
                GMUI.switchToTab(6)
            end
        },
        -- Reputation
        {
            text = "Reputation",
            value = "reputation",
            func = function()
                GMUI.switchToTab(8)
            end
        },
        -- Spells submenu
        {
            text = "Spells",
            hasArrow = true,
            menuList = {
                {
                    text = "Spells",
                    value = "spells",
                    func = function()
                        GMUI.switchToTab(3)
                    end
                },
                {
                    text = "Spell Visuals",
                    value = "spellvisuals",
                    func = function()
                        GMUI.switchToTab(4)
                    end
                }
            }
        }
    }
    
    -- Sort alphabetically by text (with safe comparison)
    table.sort(allItems, function(a, b)
        -- Use safe string comparison to handle potential table values
        if GMUtils and GMUtils.safeCompareStrings then
            return GMUtils.safeCompareStrings(a.text, b.text)
        else
            -- Fallback to basic comparison with type checking
            local textA = type(a.text) == "table" and tostring(a.text[1] or a.text.value or "") or tostring(a.text or "")
            local textB = type(b.text) == "table" and tostring(b.text[1] or b.text.value or "") or tostring(b.text or "")
            return textA < textB
        end
    end)
    
    -- Add sorted items to final list
    for _, item in ipairs(allItems) do
        table.insert(items, item)
    end
    
    return items
end

-- Build item categories menu
function GMUI.buildItemCategoriesMenu()
    local categories = {}
    
    if GMConfig.CardTypes and GMConfig.CardTypes.Item and GMConfig.CardTypes.Item.categories then
        -- Equipment category
        local equipment = GMConfig.CardTypes.Item.categories.Equipment
        if equipment and equipment.subCategories then
            local equipmentItems = {}
            for _, subCategory in ipairs(equipment.subCategories) do
                table.insert(equipmentItems, {
                    text = subCategory.name,
                    value = subCategory.value,
                    notCheckable = true,
                    func = function()
                        GMUI.switchToTab(subCategory.index)
                    end
                })
            end
            
            table.insert(categories, {
                text = "Equipment",
                hasArrow = true,
                menuList = equipmentItems
            })
        end
        
        -- Weapons category
        local weapons = GMConfig.CardTypes.Item.categories.Weapons
        if weapons and weapons.subCategories then
            local weaponItems = {}
            for _, subCategory in ipairs(weapons.subCategories) do
                table.insert(weaponItems, {
                    text = subCategory.name,
                    value = subCategory.value,
                    notCheckable = true,
                    func = function()
                        GMUI.switchToTab(subCategory.index)
                    end
                })
            end
            
            table.insert(categories, {
                text = "Weapons",
                hasArrow = true,
                menuList = weaponItems
            })
        end
        
        -- Misc category
        local misc = GMConfig.CardTypes.Item.categories.Misc
        if misc and misc.subCategories then
            local miscItems = {}
            for _, subCategory in ipairs(misc.subCategories) do
                table.insert(miscItems, {
                    text = subCategory.name,
                    value = subCategory.value,
                    notCheckable = true,
                    func = function()
                        GMUI.switchToTab(subCategory.index)
                    end
                })
            end
            
            table.insert(categories, {
                text = "Misc",
                hasArrow = true,
                menuList = miscItems
            })
        end
    end
    
    return categories
end

-- Get main menu items (kept for backward compatibility)
function GMUI.getMainMenuItems()
    return {
        {
            text = "Creatures",
            func = function()
                GMUI.switchToTab(1)
                CloseDropDownMenus()
            end,
        },
        {
            text = "Objects",
            func = function()
                GMUI.switchToTab(2)
                CloseDropDownMenus()
            end,
        },
        {
            text = "Spells",
            hasArrow = true,
            menuList = "spell",
        },
        {
            text = "Items",
            hasArrow = true,
            menuList = "items",
        },
        {
            text = "Player Management",
            func = function()
                GMUI.switchToTab(6)
                CloseDropDownMenus()
            end,
        },
    }
end

-- Add spell submenu
function GMUI.addSpellSubmenu(info, level)
    wipe(info)
    info.text = "Spells"
    info.func = function()
        GMUI.switchToTab(3)
        CloseDropDownMenus()
    end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    wipe(info)
    info.text = "Spell Visuals"
    info.func = function()
        GMUI.switchToTab(4)
        CloseDropDownMenus()
    end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
end

-- Add items submenu
function GMUI.addItemsSubmenu(info, level)
    wipe(info)
    info.text = "Search All Items"
    info.func = function()
        GMUI.switchToTab(5)
        CloseDropDownMenus()
    end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    
    wipe(info)
    info.text = "Item Categories"
    info.hasArrow = true
    info.notCheckable = true
    info.menuList = "categories"
    UIDropDownMenu_AddButton(info, level)
end

-- Add equipment submenu
function GMUI.addEquipmentSubmenu(info, level)
    if GMConfig.CardTypes and GMConfig.CardTypes.Item and GMConfig.CardTypes.Item.categories then
        local equipment = GMConfig.CardTypes.Item.categories.Equipment
        if equipment and equipment.subCategories then
            for _, subCategory in ipairs(equipment.subCategories) do
                wipe(info)
                info.text = subCategory.name
                info.func = function()
                    GMUI.switchToTab(subCategory.index)
                    CloseDropDownMenus()
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
end

-- Add weapons submenu
function GMUI.addWeaponsSubmenu(info, level)
    if GMConfig.CardTypes and GMConfig.CardTypes.Item and GMConfig.CardTypes.Item.categories then
        local weapons = GMConfig.CardTypes.Item.categories.Weapons
        if weapons and weapons.subCategories then
            for _, subCategory in ipairs(weapons.subCategories) do
                wipe(info)
                info.text = subCategory.name
                info.func = function()
                    GMUI.switchToTab(subCategory.index)
                    CloseDropDownMenus()
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
end

-- Add misc submenu
function GMUI.addMiscSubmenu(info, level)
    if GMConfig.CardTypes and GMConfig.CardTypes.Item and GMConfig.CardTypes.Item.categories then
        local misc = GMConfig.CardTypes.Item.categories.Misc
        if misc and misc.subCategories then
            for _, subCategory in ipairs(misc.subCategories) do
                wipe(info)
                info.text = subCategory.name
                info.func = function()
                    GMUI.switchToTab(subCategory.index)
                    CloseDropDownMenus()
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
end



-- Show kofi frame

-- Initialize complete UI
function GMUI.initializeUI()
    -- Create main frame
    local mainFrame = GMUI.createMainFrame()
    
    -- Create content container instead of tab system
    local contentArea = GMUI.createContentContainer(mainFrame)
    
    -- Create category dropdown first
    GMUI.createCategoryDropdown(mainFrame)
    
    -- Create sort dropdown (positioned next to category dropdown)
    GMUI.createSortDropdown(mainFrame)
    
    -- Create search box
    GMUI.createSearchBox(mainFrame)
    
    -- Create teleport button (positioned to the right of search box)
    local teleportBtn = CreateStyledButton(mainFrame, "Teleport", 70, 24)
    teleportBtn:SetPoint("LEFT", GMData.frames.searchBox, "RIGHT", 10, 0)
    teleportBtn:SetScript("OnClick", function()
        -- Use state machine for coordinated teleport opening
        local StateMachine = _G.GMStateMachine
        if StateMachine and StateMachine.canOpenModal() then
            StateMachine.openTeleport()
        else
            print("|cffff0000Teleport system not available|r")
        end
    end)
    teleportBtn:SetTooltip("Teleport List", "Browse and teleport to game locations")
    GMData.frames.teleportButton = teleportBtn
    
    if GMConfig.config.debug then
        -- Debug: UI initialized with content container
    end
    
    -- Create pagination controls
    GMUI.createPaginationControls(mainFrame)
    
    -- Set initial active tab
    GMData.activeTab = 1 -- Start with Creatures tab
    
    -- Hide main frame initially
    mainFrame:Hide()
    
    return mainFrame
end

-- Show/hide functions
function GMUI.show()
    if GMData.frames.mainFrame then
        -- Reset position to center before showing
        GMData.frames.mainFrame:ClearAllPoints()
        GMData.frames.mainFrame:SetPoint("CENTER")
        GMData.frames.mainFrame:Show()
    end
end

function GMUI.hide()
    if GMData.frames.mainFrame then
        GMData.frames.mainFrame:Hide()
    end
end

-- Update pagination button states
function GMUI.updatePaginationButtons()
    -- Skip pagination updates for GM Powers and Reputation tabs
    if GMData.activeTab == 7 or GMData.activeTab == 8 then
        if GMData.frames.paginationContainer then
            GMData.frames.paginationContainer:Hide()
        end
        return
    end
    
    -- Show pagination for other tabs
    if GMData.frames.paginationContainer then
        GMData.frames.paginationContainer:Show()
    end
    
    -- Get current tab state
    local state = GMUtils.GetTabState(GMData.activeTab)
    
    -- Update button states
    local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
    
    if GMData.frames.firstButton then
        if currentOffset > 0 then
            GMData.frames.firstButton:Enable()
        else
            GMData.frames.firstButton:Disable()
        end
    end
    
    if GMData.frames.prevButton then
        if currentOffset > 0 then
            GMData.frames.prevButton:Enable()
        else
            GMData.frames.prevButton:Disable()
        end
    end
    
    if GMData.frames.nextButton then
        if state.hasMoreData then
            GMData.frames.nextButton:Enable()
        else
            GMData.frames.nextButton:Disable()
        end
    end
    
    if GMData.frames.lastButton then
        local totalCount = tonumber(GMUtils.safeGetValue(state.totalCount)) or 0
        local totalPages = tonumber(GMUtils.safeGetValue(state.totalPages)) or 1
        if totalCount > 0 and totalPages > 1 then
            GMData.frames.lastButton:Enable()
        else
            GMData.frames.lastButton:Disable()
        end
    end
    
    -- Update page input and total pages display
    if GMData.frames.pageInput then
        GMData.frames.pageInput:SetText(tostring(state.currentPage))
    end
    
    if GMData.frames.totalPagesText then
        local totalCount = tonumber(GMUtils.safeGetValue(state.totalCount)) or 0
        local totalPages = tonumber(GMUtils.safeGetValue(state.totalPages)) or 1
        if totalCount > 0 then
            GMData.frames.totalPagesText:SetText("/ " .. totalPages)
        else
            GMData.frames.totalPagesText:SetText("/ ?")
        end
    end
    
    -- Update pagination info display
    if GMData.frames.paginationInfo then
        local text = ""
        
        if state.paginationInfo and state.paginationInfo.totalCount then
            local paginationTotalCount = tonumber(GMUtils.safeGetValue(state.paginationInfo.totalCount)) or 0
            if paginationTotalCount > 0 then
                local info = state.paginationInfo
                local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
                local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
                text = string.format("Showing %d-%d of %d items", 
                    info.startIndex or (currentOffset + 1),
                    info.endIndex or math.min(currentOffset + pageSize, paginationTotalCount),
                    paginationTotalCount
                )
            end
        end
        
        if text == "" and state.totalCount then
            local totalCount = tonumber(GMUtils.safeGetValue(state.totalCount)) or 0
            if totalCount > 0 then
                local currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
                local pageSize = tonumber(GMUtils.safeGetValue(state.pageSize)) or 15
                local startIdx = currentOffset + 1
                local endIdx = math.min(currentOffset + pageSize, totalCount)
                text = string.format("Showing %d-%d of %d items", startIdx, endIdx, totalCount)
            end
        end
        
        if text == "" then
            text = string.format("Page %d", state.currentPage)
            if state.hasMoreData then
                text = text .. " (more available)"
            end
        end
        
        GMData.frames.paginationInfo:SetText(text)
        GMData.frames.paginationInfo:Show()
    end
end

-- Create styled card for items
function GMUI.createStyledCard(parent, index, size)
    local card = CreateStyledCard(parent, size, {
        texture = nil,
        quality = "common",
        count = nil,
        onClick = nil,
        onRightClick = nil
    })
    
    -- Add custom properties for GM system
    card.nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.nameText:SetPoint("BOTTOM", card, "BOTTOM", 0, 5)
    card.nameText:SetWidth(size - 10)
    card.nameText:SetJustifyH("CENTER")
    
    return card
end

-- Update content for active tab
function GMUI.updateContentForActiveTab()

    if not GMData.activeTab then
        GMUtils.debug("No active tab set")
        return
    end

    -- Get the active content frame
    local activeFrame = GMUI.getOrCreateContentFrame(GMData.activeTab)

    if not activeFrame then
        GMUtils.debug("Could not get content frame for tab:", GMData.activeTab)
        return
    end

    -- Clear existing cards (this now hides them but preserves model data)
    GMUI.clearContentFrame(activeFrame)
    
    -- Actually clear the cards array for new data
    if activeFrame.cards then
        -- Properly cleanup old cards before creating new ones
        for _, card in ipairs(activeFrame.cards) do
            if card and card.Hide then
                card:Hide()
                card:SetParent(nil)
            end
        end
        wipe(activeFrame.cards)
    end
    
    -- Determine data type based on active tab
    local dataType = GMUI.getDataTypeForTab(GMData.activeTab)
    
    if not dataType then
        GMUtils.debug("Unknown data type for tab:", GMData.activeTab)
        return
    end
    
    -- Special handling for GM Powers tab - BEFORE data check since it doesn't need data
    if GMData.activeTab == 7 and dataType == "gmpowers" then
        -- Create or show GM Powers panel
        if not GMPowers or not GMPowers.frames or not GMPowers.frames.panel then
            -- Load GM Powers module if not loaded
            if GMPowers and GMPowers.CreatePanel then
                GMPowers.CreatePanel(activeFrame)
            else
                GMUI.showEmptyState(activeFrame, "GM Powers module not loaded")
                return
            end
        end
        
        -- Show the GM Powers panel
        if GMPowers.frames.panel then
            GMPowers.frames.panel:SetParent(activeFrame)
            GMPowers.frames.panel:Show()
            
            -- Request current state from server
            AIO.Handle("GameMasterSystem", "getGMPowersState")
        end
        
        -- Hide pagination controls for GM Powers tab (no data pagination needed)
        if GMData.frames.prevButton then GMData.frames.prevButton:Hide() end
        if GMData.frames.nextButton then GMData.frames.nextButton:Hide() end
        if GMData.frames.refreshButton then GMData.frames.refreshButton:Hide() end
        if GMData.frames.paginationInfo then GMData.frames.paginationInfo:Hide() end
        
        return -- Exit early - GM Powers doesn't need data
    end

    -- Special handling for Reputation tab - BEFORE data check since it doesn't need data
    if GMData.activeTab == 8 and dataType == "reputation" then
        -- Create or show Reputation panel
        if not GMReputation or not GMReputation.frames or not GMReputation.frames.panel then
            -- Load Reputation module if not loaded
            if GMReputation and GMReputation.CreatePanel then
                GMReputation.CreatePanel(activeFrame)
            else
                GMUI.showEmptyState(activeFrame, "Reputation module not loaded")
                return
            end
        end

        -- Show the Reputation panel
        if GMReputation.frames.panel then
            GMReputation.frames.panel:SetParent(activeFrame)
            GMReputation.frames.panel:Show()

            -- Request online players from server (faction data is embedded in client)
            AIO.Handle("GameMasterSystem", "getOnlinePlayersForReputation")
        end

        -- Hide pagination controls for Reputation tab (no data pagination needed)
        if GMData.frames.prevButton then GMData.frames.prevButton:Hide() end
        if GMData.frames.nextButton then GMData.frames.nextButton:Hide() end
        if GMData.frames.refreshButton then GMData.frames.refreshButton:Hide() end
        if GMData.frames.paginationInfo then GMData.frames.paginationInfo:Hide() end

        return -- Exit early - Reputation doesn't need data
    end

    -- Show pagination controls for regular data tabs
    if GMData.frames.prevButton then GMData.frames.prevButton:Show() end
    if GMData.frames.nextButton then GMData.frames.nextButton:Show() end
    if GMData.frames.refreshButton then GMData.frames.refreshButton:Show() end
    
    -- Get data from store
    local data = GMData.DataStore and GMData.DataStore[dataType]

    -- Enhanced debug for player data
    if GMConfig.config.debug and dataType == "players" then
        print("[PlayerList Debug] DataType is 'players'")
        print("[PlayerList Debug] GMData.DataStore exists:", GMData.DataStore ~= nil)
        if GMData.DataStore then
            print("[PlayerList Debug] GMData.DataStore.players exists:", GMData.DataStore.players ~= nil)
            if GMData.DataStore.players then
                print("[PlayerList Debug] Number of players in DataStore:", #GMData.DataStore.players)
            end
        end
        print("[PlayerList Debug] data variable:", data ~= nil)
        if data then
            print("[PlayerList Debug] data length:", #data)
        end
    end

    -- Special handling for player tab - use list view (handles both empty and non-empty data)
    if GMData.activeTab == 6 and dataType == "players" then
        -- Use empty array if no data
        data = data or {}
        -- Debug output
        if GMConfig.config.debug then
            print("[PlayerList] Handling player tab with", #data, "players")
        end
        
        -- Always use list view for players
        GMCards.currentViewMode = "list"
        
        -- Store the player data for list view
        GMCards.currentPlayerData = data
        
        -- Check if we need to create the list frame
        -- IMPORTANT: Check if it's attached to the current activeFrame
        local needsCreation = false
        if not GMCards.playerListFrame then
            needsCreation = true
        elseif GMCards.playerListFrame:GetParent() ~= activeFrame then
            -- Frame exists but is attached to a different parent, recreate it
            if GMConfig.config.debug then
                print("[PlayerList] List frame has wrong parent, recreating")
            end
            GMCards.playerListFrame:Hide()
            GMCards.playerListFrame:SetParent(nil)
            GMCards.playerListFrame = nil
            needsCreation = true
        end
        
        -- Create list view container if needed
        if needsCreation then
            if GMConfig.config.debug then
                print("[PlayerList] Creating list frame")
            end
            if GMCards.PlayerList and GMCards.PlayerList.CreateListView then
                GMCards.playerListFrame = GMCards.PlayerList.CreateListView(activeFrame)
                if GMConfig.config.debug then
                    print("[PlayerList] List frame created successfully")
                end
            else
                print("[PlayerList] ERROR: PlayerList module not found!")
                if not GMCards.PlayerList then
                    print("[PlayerList] GMCards.PlayerList is nil")
                end
                if GMCards.PlayerList and not GMCards.PlayerList.CreateListView then
                    print("[PlayerList] CreateListView function is nil")
                end
            end
        else
            if GMConfig.config.debug then
                print("[PlayerList] Reusing existing list frame")
            end
        end
        
        -- Show and populate list frame
        if GMCards.playerListFrame then
            if GMConfig.config.debug then
                print("[PlayerList] Showing and populating list frame")
            end
            GMCards.playerListFrame:Show()
            if GMCards.PlayerList and GMCards.PlayerList.PopulateList then
                GMCards.PlayerList.PopulateList(data)
                if GMConfig.config.debug then
                    print("[PlayerList] List populated with", #data, "players")
                end
            else
                print("[PlayerList] ERROR: PopulateList function not found!")
            end
        else
            print("[PlayerList] ERROR: playerListFrame is nil after creation attempt!")
        end
        return -- Exit after handling Player Management
    end

    -- For other tabs: check for empty data
    if not data or #data == 0 then
        GMUtils.debug("No data available for:", dataType)
        GMUI.showEmptyState(activeFrame, "No " .. dataType .. " found")
        return
    end

    -- Normal card generation for other tabs
    if _G.GMCards and _G.GMCards.generateCards then
        local cardType = GMUI.getCardTypeForDataType(dataType)
        local cards = _G.GMCards.generateCards(activeFrame, data, cardType)
        activeFrame.cards = cards

        -- Debug: Check if cards are visible
        if cards and #cards > 0 and GMConfig.config.debug then
            -- Debug: Cards visibility check
        end
    else
        GMUtils.debug("GMCards.generateCards not available")
    end
end

-- Clear content frame
function GMUI.clearContentFrame(frame)
    if not frame then return end
    
    -- Hide existing cards (but preserve them for model restoration)
    if frame.cards then
        for _, card in ipairs(frame.cards) do
            if card and card.Hide then
                card:Hide()
                -- Don't set parent to nil to preserve model data
                -- card:SetParent(nil) -- REMOVED to preserve models
            end
        end
        -- Don't wipe cards array, keep references for reuse
        -- wipe(frame.cards) -- REMOVED to preserve card references
    end
    
    -- Hide child frames without destroying them
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        if child and child ~= frame then
            child:Hide()
            -- Don't set parent to nil for special frames
            -- This preserves model data and other frame state
            if not (child.preserveOnClear or (child.modelFrame and child.modelFrame:IsObjectType("Model"))) then
                child:SetParent(nil)
            end
        end
    end
end

-- Get data type for tab index
function GMUI.getDataTypeForTab(tabIndex)
    local dataTypeMap = {
        [1] = "npcs",           -- Creatures
        [2] = "gameobjects",    -- Objects
        [3] = "spells",         -- Spells
        [4] = "spellvisuals",   -- Spell Visuals
        [5] = "items",          -- Items (All)
        [6] = "players",        -- Player Management
        [7] = "gmpowers",       -- GM Powers
        [8] = "reputation",     -- Reputation
    }
    
    -- Check if it's a subcategory tab
    if tabIndex >= 100 then
        return "items"  -- All subcategory tabs are items
    end
    
    return dataTypeMap[tabIndex]
end

-- Get card type for data type
function GMUI.getCardTypeForDataType(dataType)
    local cardTypeMap = {
        npcs = "NPC",
        gameobjects = "GameObject",
        spells = "Spell",
        spellvisuals = "SpellVisual",
        items = "Item",
        players = "Player"
    }
    
    return cardTypeMap[dataType] or "Item"
end

-- Show empty state
function GMUI.showEmptyState(frame, message)
    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    emptyText:SetText(message or "No data available")
    emptyText:SetTextColor(0.5, 0.5, 0.5)
end

-- Get or create content frame for a tab
function GMUI.getOrCreateContentFrame(tabIndex)
    -- Ensure content area exists and is visible
    if not GMData.frames.contentArea then
        -- ERROR: Content area does not exist!
        return nil
    end
    
    -- Make sure content area is visible
    GMData.frames.contentArea:Show()
    
    -- Check if frame already exists
    if GMData.dynamicContentFrames[tabIndex] then
        -- Reusing existing content frame
        return GMData.dynamicContentFrames[tabIndex]
    end
    
    -- Create new content frame
    local contentFrame = CreateFrame("Frame", nil, GMData.frames.contentArea)
    contentFrame:SetAllPoints(GMData.frames.contentArea)
    contentFrame:Hide()
    
    -- Add debug background for visibility testing
    if GMConfig.config.debug then
        local bg = contentFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.3) -- Slight tint to see the frame
    end
    
    -- Store in dynamic frames
    GMData.dynamicContentFrames[tabIndex] = contentFrame
    
    -- Created new content frame
    
    return contentFrame
end

-- Get category name for tab index
function GMUI.getCategoryNameForTab(tabIndex)
    -- Main categories
    local mainCategories = {
        [1] = "Creatures",
        [2] = "Objects",
        [3] = "Spells",
        [4] = "Spell Visuals",
        [5] = "Items",
        [6] = "Player Management",
        [7] = "GM Powers",
        [8] = "Reputation"
    }
    
    if mainCategories[tabIndex] then
        return mainCategories[tabIndex]
    end
    
    -- Check subcategories
    if GMConfig.CardTypes and GMConfig.CardTypes.Item and GMConfig.CardTypes.Item.categories then
        for categoryName, category in pairs(GMConfig.CardTypes.Item.categories) do
            if category.subCategories then
                for _, subCategory in ipairs(category.subCategories) do
                    if subCategory.index == tabIndex then
                        return "Items > " .. categoryName .. " > " .. subCategory.name
                    end
                end
            end
        end
    end
    
    return "Unknown Category"
end

-- Handle tab switching
function GMUI.switchToTab(tabIndex)
    if GMConfig.config.debug then
        print("[Tab Switch] Switching to tab:", tabIndex)
    end
    
    -- Store current tab's search query
    if GMData.activeTab then
        local oldState = GMUtils.GetTabState(GMData.activeTab)
        oldState.searchQuery = GMData.currentSearchQuery
    end
    
    -- Update active tab
    GMData.activeTab = tabIndex
    
    -- Restore new tab's state
    local state = GMUtils.GetTabState(tabIndex)
    -- Sanitize currentOffset before assignment
    GMData.currentOffset = tonumber(GMUtils.safeGetValue(state.currentOffset)) or 0
    GMData.hasMoreData = state.hasMoreData
    GMData.currentSearchQuery = state.searchQuery or ""
    GMData.paginationInfo = state.paginationInfo
    
    -- Update category indicator
    if GMData.frames.categoryIndicator then
        local categoryName = GMUI.getCategoryNameForTab(tabIndex)
        GMData.frames.categoryIndicator:SetText(categoryName)
        GMData.frames.categoryIndicator:Show()
    end
    
    -- Maintain search box state
    if GMData.frames.searchBox and GMData.frames.searchBox.editBox then
        -- Keep the current search query displayed
        local currentText = GMData.frames.searchBox.editBox:GetText()
        if currentText ~= GMData.currentSearchQuery then
            -- If the search box text doesn't match our stored query, update it
            GMData.frames.searchBox.editBox:SetText(GMData.currentSearchQuery or "")
        end
    end
    
    -- Hide all existing content frames
    for idx, frame in pairs(GMData.dynamicContentFrames) do
        if frame then
            GMUI.clearContentFrame(frame)
            frame:Hide()
        end
    end
    
    -- Get or create content frame for this tab
    local activeFrame = GMUI.getOrCreateContentFrame(tabIndex)
    if activeFrame then
        activeFrame:Show()
        
        -- Ensure content area is visible
        if GMData.frames.contentArea then
            GMData.frames.contentArea:Show()
        end
        
        -- Ensure main frame is visible
        if GMData.frames.mainFrame then
            -- Main frame visibility check
        end
    else
        -- ERROR: Could not create content frame for tab
    end
    
    -- Show/hide sort dropdown based on tab
    if GMData.frames.sortDropdown and GMData.frames.sortLabel then
        -- Show sort controls for data-oriented tabs and their sub-tabs
        -- Tab 1: Creatures
        -- Tab 2: Objects
        -- Tab 3: Spells (and Spell Visuals which is Tab 4)
        -- Tab 5: Items (All)
        -- Tab >= 100: Item subcategories (Equipment, Weapons, etc.)
        if tabIndex == 1 or tabIndex == 2 or tabIndex == 3 or tabIndex == 4 or tabIndex == 5 or tabIndex >= 100 then
            GMData.frames.sortDropdown:Show()
            GMData.frames.sortLabel:Show()
        else
            -- Hide for GM Powers (7), Reputation (8), Player Management (6), and other non-list tabs
            GMData.frames.sortDropdown:Hide()
            GMData.frames.sortLabel:Hide()
        end
    end
    
    -- Show/hide refresh button based on tab (always show for Player Management)
    if GMData.frames.refreshButton then
        if tabIndex == 6 then
            GMData.frames.refreshButton:Show()
        else
            GMData.frames.refreshButton:Show() -- Show for all tabs
        end
    end
    
    -- Request data for this tab
    GMUI.requestDataForTab(tabIndex)
end

-- Request data for specific tab
function GMUI.requestDataForTab(tabIndex)
    -- Special case for GM Powers and Reputation - trigger content update directly
    if tabIndex == 7 or tabIndex == 8 then
        -- These tabs don't need data from server, just update the content
        GMUI.updateContentForActiveTab()
        return
    end
    
    -- Get tab state
    local state = GMUtils.GetTabState(tabIndex)
    -- Sanitize numeric values to prevent table comparison errors
    local offset = GMUtils and GMUtils.safeGetValue and GMUtils.safeGetValue(state.currentOffset) or state.currentOffset
    offset = tonumber(offset) or 0
    
    local pageSize = GMUtils and GMUtils.safeGetValue and GMUtils.safeGetValue(state.pageSize) or state.pageSize
    pageSize = tonumber(pageSize) or GMConfig.config.PAGE_SIZE or 15
    
    local sortOrder = GMData.sortOrder or "ASC"
    
    -- Sanitize lastRequestedOffset for comparison
    local lastRequestedOffset = GMUtils and GMUtils.safeGetValue and GMUtils.safeGetValue(GMData.lastRequestedOffset) or GMData.lastRequestedOffset
    lastRequestedOffset = tonumber(lastRequestedOffset) or 0
    
    -- Safeguard: Don't request data if we're already at the end and trying to go forward
    if offset > 0 and offset >= lastRequestedOffset and not GMData.hasMoreData then
        if GMConfig.config.debug then
            print("Preventing redundant request - already at end of data")
        end
        return
    end
    
    -- Store the last requested offset (as a number)
    GMData.lastRequestedOffset = offset
    
    -- Determine handler based on tab
    if tabIndex == 1 then
        -- NPCs
        if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
            AIO.Handle("GameMasterSystem", "searchNPCData", GMData.currentSearchQuery, offset, pageSize, sortOrder)
        else
            AIO.Handle("GameMasterSystem", "getNPCData", offset, pageSize, sortOrder)
        end
    elseif tabIndex == 2 then
        -- GameObjects
        if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
            AIO.Handle("GameMasterSystem", "searchGameObjectData", GMData.currentSearchQuery, offset, pageSize, sortOrder)
        else
            AIO.Handle("GameMasterSystem", "getGameObjectData", offset, pageSize, sortOrder)
        end
    elseif tabIndex == 3 then
        -- Spells
        if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
            AIO.Handle("GameMasterSystem", "searchSpellData", GMData.currentSearchQuery, offset, pageSize, sortOrder)
        else
            AIO.Handle("GameMasterSystem", "getSpellData", offset, pageSize, sortOrder)
        end
    elseif tabIndex == 4 then
        -- Spell Visuals
        if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
            AIO.Handle("GameMasterSystem", "searchSpellVisualData", GMData.currentSearchQuery, offset, pageSize, sortOrder)
        else
            AIO.Handle("GameMasterSystem", "getSpellVisualData", offset, pageSize, sortOrder)
        end
    elseif tabIndex == 5 then
        -- Items (All)
        if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
            AIO.Handle("GameMasterSystem", "searchItemData", GMData.currentSearchQuery, offset, pageSize, sortOrder)
        else
            AIO.Handle("GameMasterSystem", "getItemData", offset, pageSize, sortOrder)
        end
    elseif tabIndex == 6 then
        -- Player Management - Use unified filtering system

        -- Use PlayerList.FilterPlayers to handle search with main search bar
        if GMCards and GMCards.PlayerList then
            if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
                -- Filter with search query
                GMCards.PlayerList.FilterPlayers(GMData.currentSearchQuery:lower())
            else
                -- Show all players (respects class filter and show offline state)
                if GMCards.PlayerList.ShowAllPlayers then
                    GMCards.PlayerList.ShowAllPlayers()
                else
                    GMCards.PlayerList.FilterPlayers("")
                end
            end
        else
            -- Fallback if PlayerList not loaded yet
            AIO.Handle("GameMasterSystem", "refreshPlayerData")
        end
    elseif tabIndex >= 100 then
        -- Item subcategory - need to find inventory type
        local inventoryType = GMUI.getInventoryTypeForTab(tabIndex)
        if inventoryType then
            if GMData.currentSearchQuery and GMData.currentSearchQuery ~= "" then
                AIO.Handle("GameMasterSystem", "searchItemData", GMData.currentSearchQuery, offset, pageSize, sortOrder, inventoryType)
            else
                AIO.Handle("GameMasterSystem", "getItemData", offset, pageSize, sortOrder, inventoryType)
            end
        end
    end
end

-- Get inventory type for subcategory tab
function GMUI.getInventoryTypeForTab(tabIndex)
    -- Check all categories for matching tab index
    if GMConfig.CardTypes and GMConfig.CardTypes.Item and GMConfig.CardTypes.Item.categories then
        for categoryName, category in pairs(GMConfig.CardTypes.Item.categories) do
            if category.subCategories then
                for _, subCategory in ipairs(category.subCategories) do
                    if subCategory.index == tabIndex then
                        -- The config uses 'value' for the inventory type/class
                        return subCategory.value
                    end
                end
            end
        end
    end
    return nil
end

-- UI module loaded