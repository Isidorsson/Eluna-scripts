-- GameMaster UI System - Reputation Management Tab
-- This file handles the reputation management UI panel
-- Load order: Systems

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

-- Create GMReputation namespace
_G.GMReputation = _G.GMReputation or {}
local GMReputation = _G.GMReputation
local GMData = _G.GMData
local GMConfig = _G.GMConfig

-- Static faction data (embedded to avoid AIO serialization issues)
local FACTION_DATA = {
    categories = {
        {
            name = "Classic",
            factions = {
                { id = 72, name = "Stormwind" },
                { id = 47, name = "Ironforge" },
                { id = 69, name = "Darnassus" },
                { id = 54, name = "Gnomeregan Exiles" },
                { id = 76, name = "Orgrimmar" },
                { id = 68, name = "Undercity" },
                { id = 81, name = "Thunder Bluff" },
                { id = 530, name = "Darkspear Trolls" },
                { id = 529, name = "Argent Dawn" },
                { id = 87, name = "Bloodsail Buccaneers" },
                { id = 21, name = "Booty Bay" },
                { id = 910, name = "Brood of Nozdormu" },
                { id = 609, name = "Cenarion Circle" },
                { id = 909, name = "Darkmoon Faire" },
                { id = 749, name = "Hydraxian Waterlords" },
                { id = 349, name = "Ravenholdt" },
                { id = 809, name = "Shen'dralar" },
                { id = 59, name = "Thorium Brotherhood" },
                { id = 576, name = "Timbermaw Hold" },
                { id = 270, name = "Zandalar Tribe" },
                { id = 730, name = "Stormpike Guard" },
                { id = 890, name = "Silverwing Sentinels" },
                { id = 509, name = "The League of Arathor" },
                { id = 729, name = "Frostwolf Clan" },
                { id = 889, name = "Warsong Outriders" },
                { id = 510, name = "The Defilers" },
                { id = 169, name = "Steamwheedle Cartel" },
                { id = 470, name = "Ratchet" },
                { id = 369, name = "Gadgetzan" },
                { id = 577, name = "Everlook" },
                { id = 589, name = "Wintersaber Trainers" },
            }
        },
        {
            name = "The Burning Crusade",
            factions = {
                { id = 930, name = "Exodar" },
                { id = 911, name = "Silvermoon City" },
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
                { id = 990, name = "The Scale of the Sands" },
                { id = 1012, name = "Ashtongue Deathsworn" },
                { id = 967, name = "The Violet Eye" },
                { id = 946, name = "Honor Hold" },
                { id = 947, name = "Thrallmar" },
                { id = 1077, name = "Shattered Sun Offensive" },
            }
        },
        {
            name = "Wrath of the Lich King",
            factions = {
                { id = 1037, name = "Alliance Vanguard" },
                { id = 1050, name = "Valiance Expedition" },
                { id = 1068, name = "Explorers' League" },
                { id = 1126, name = "The Frostborn" },
                { id = 1094, name = "The Silver Covenant" },
                { id = 1052, name = "Horde Expedition" },
                { id = 1067, name = "The Hand of Vengeance" },
                { id = 1064, name = "The Taunka" },
                { id = 1085, name = "Warsong Offensive" },
                { id = 1124, name = "The Sunreavers" },
                { id = 1090, name = "Kirin Tor" },
                { id = 1091, name = "The Wyrmrest Accord" },
                { id = 1098, name = "Knights of the Ebon Blade" },
                { id = 1106, name = "Argent Crusade" },
                { id = 1073, name = "The Kalu'ak" },
                { id = 1119, name = "The Sons of Hodir" },
                { id = 1104, name = "Frenzyheart Tribe" },
                { id = 1105, name = "The Oracles" },
                { id = 1156, name = "The Ashen Verdict" },
            }
        }
    }
}

-- Build "All Factions" category
local allFactions = {}
for _, category in ipairs(FACTION_DATA.categories) do
    for _, faction in ipairs(category.factions) do
        table.insert(allFactions, { id = faction.id, name = faction.name })
    end
end
table.sort(allFactions, function(a, b) return a.name < b.name end)
table.insert(FACTION_DATA.categories, { name = "All Factions", factions = allFactions })

-- Reputation state tracking
GMReputation.state = {
    selectedTargetName = "Self",
    selectedExpansion = "All Factions",
    selectedFactionId = nil,
    selectedFactionName = nil,
    currentRep = 0,
    standingName = "Neutral",
    factionData = FACTION_DATA -- Use embedded data
}

-- UI Elements storage
GMReputation.frames = {}

-- Standing presets (will be updated from server data)
GMReputation.STANDING_PRESETS = {
    { name = "Hated", value = -42000, color = {0.8, 0, 0} },
    { name = "Hostile", value = -6000, color = {1, 0, 0} },
    { name = "Unfriendly", value = -3000, color = {1, 0.5, 0} },
    { name = "Neutral", value = 0, color = {1, 1, 0} },
    { name = "Friendly", value = 3000, color = {0, 1, 0} },
    { name = "Honored", value = 9000, color = {0, 1, 0.5} },
    { name = "Revered", value = 21000, color = {0, 0.5, 1} },
    { name = "Exalted", value = 42000, color = {0.5, 0, 1} }
}

-- Get standing from reputation value
local function GetStandingFromValue(value)
    if value >= 42000 then return "Exalted", GMReputation.STANDING_PRESETS[8]
    elseif value >= 21000 then return "Revered", GMReputation.STANDING_PRESETS[7]
    elseif value >= 9000 then return "Honored", GMReputation.STANDING_PRESETS[6]
    elseif value >= 3000 then return "Friendly", GMReputation.STANDING_PRESETS[5]
    elseif value >= 0 then return "Neutral", GMReputation.STANDING_PRESETS[4]
    elseif value >= -3000 then return "Unfriendly", GMReputation.STANDING_PRESETS[3]
    elseif value >= -6000 then return "Hostile", GMReputation.STANDING_PRESETS[2]
    else return "Hated", GMReputation.STANDING_PRESETS[1]
    end
end

-- Create the main Reputation panel
function GMReputation.CreatePanel(parent)
    -- Main container frame
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -10)
    title:SetText("Reputation Management")
    title:SetTextColor(1, 1, 1)

    -- Create sections
    GMReputation.CreateTargetSection(panel)
    GMReputation.CreateFactionSection(panel)
    GMReputation.CreateReputationSection(panel)
    GMReputation.CreateQuickSetSection(panel)

    GMReputation.frames.panel = panel
    GMReputation.frames.title = title
    panel:Show()

    -- Populate faction dropdown with embedded data
    GMReputation.UpdateFactionDropdown()

    return panel
end

-- Create target selection section
function GMReputation.CreateTargetSection(parent)
    local section = CreateStyledFrame(parent, UISTYLE_COLORS.OptionBg)
    local sectionWidth = parent:GetWidth() - 40
    section:SetSize(sectionWidth, 60)
    section:SetPoint("TOP", parent, "TOP", 0, -40)
    section:Show()

    -- Section title
    local sectionTitle = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionTitle:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -10)
    sectionTitle:SetText("Target Player")
    sectionTitle:SetTextColor(0.9, 0.9, 0.9)

    -- Target input container
    local inputContainer = CreateFrame("Frame", nil, section)
    inputContainer:SetSize(300, 26)
    inputContainer:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -30)
    inputContainer:SetBackdrop(UISTYLE_BACKDROPS.Frame)
    inputContainer:SetBackdropColor(UISTYLE_COLORS.ButtonBg[1], UISTYLE_COLORS.ButtonBg[2], UISTYLE_COLORS.ButtonBg[3], 1)
    inputContainer:SetBackdropBorderColor(UISTYLE_COLORS.ButtonBorder[1], UISTYLE_COLORS.ButtonBorder[2], UISTYLE_COLORS.ButtonBorder[3], 1)

    -- Target input field
    local targetInput = CreateFrame("EditBox", nil, inputContainer)
    targetInput:SetPoint("LEFT", 8, 0)
    targetInput:SetPoint("RIGHT", -28, 0)
    targetInput:SetHeight(20)
    targetInput:SetFontObject("GameFontNormalSmall")
    targetInput:SetTextColor(1, 1, 1)
    targetInput:SetAutoFocus(false)
    targetInput:SetMaxLetters(50)
    targetInput:SetText("Self")

    -- Clear button (X) on right side
    local clearBtn = CreateFrame("Button", nil, inputContainer)
    clearBtn:SetSize(20, 20)
    clearBtn:SetPoint("RIGHT", -4, 0)

    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearText:SetPoint("CENTER", 0, 0)
    clearText:SetText("X")
    clearText:SetTextColor(0.6, 0.6, 0.6)

    clearBtn:SetScript("OnEnter", function(self)
        clearText:SetTextColor(1, 0.3, 0.3)
    end)
    clearBtn:SetScript("OnLeave", function(self)
        clearText:SetTextColor(0.6, 0.6, 0.6)
    end)
    clearBtn:SetScript("OnClick", function()
        targetInput:SetText("Self")
        GMReputation.state.selectedTargetName = "Self"
        targetInput:ClearFocus()
    end)

    -- Input event handlers
    targetInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text == "" then
            self:SetText("Self")
            GMReputation.state.selectedTargetName = "Self"
        else
            GMReputation.state.selectedTargetName = text
        end
        self:ClearFocus()
        -- Request updated reputation for new target
        if GMReputation.state.selectedFactionId then
            AIO.Handle("GameMasterSystem", "getPlayerReputationByName",
                GMReputation.state.selectedTargetName,
                GMReputation.state.selectedFactionId)
        end
    end)

    targetInput:SetScript("OnEscapePressed", function(self)
        self:SetText(GMReputation.state.selectedTargetName or "Self")
        self:ClearFocus()
    end)

    GMReputation.frames.targetSection = section
    GMReputation.frames.targetInput = targetInput
    GMReputation.frames.targetClearBtn = clearBtn
end

-- Create faction selection section
function GMReputation.CreateFactionSection(parent)
    local section = CreateStyledFrame(parent, UISTYLE_COLORS.OptionBg)
    local sectionWidth = parent:GetWidth() - 40
    section:SetSize(sectionWidth, 60)
    section:SetPoint("TOP", GMReputation.frames.targetSection, "BOTTOM", 0, -10)
    section:Show()

    -- Section title
    local sectionTitle = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionTitle:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -10)
    sectionTitle:SetText("Faction Selection")
    sectionTitle:SetTextColor(0.9, 0.9, 0.9)

    -- Expansion dropdown (filter)
    local expansionDropdown = CreateFullyStyledDropdown(
        section,
        180,
        {
            { text = "All Factions", value = "All Factions" },
            { text = "Classic", value = "Classic" },
            { text = "The Burning Crusade", value = "The Burning Crusade" },
            { text = "Wrath of the Lich King", value = "Wrath of the Lich King" }
        },
        "All Factions",
        function(value)
            GMReputation.state.selectedExpansion = value
            GMReputation.UpdateFactionDropdown()
        end
    )
    expansionDropdown:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -30)

    -- Faction dropdown (will be populated after server sends data)
    local factionDropdown = CreateFullyStyledDropdown(
        section,
        300,
        {{ text = "Loading...", value = nil }},
        "Select Faction",
        function(value, item)
            if value then
                GMReputation.state.selectedFactionId = value
                GMReputation.state.selectedFactionName = item.text
                -- Get target name from input field
                local targetName = "Self"
                if GMReputation.frames.targetInput then
                    targetName = GMReputation.frames.targetInput:GetText()
                    if targetName == "" then targetName = "Self" end
                end
                -- Request current reputation for this faction
                AIO.Handle("GameMasterSystem", "getPlayerReputationByName",
                    targetName,
                    GMReputation.state.selectedFactionId)
            end
        end,
        true, -- Enable search
        "Search factions..."
    )
    factionDropdown:SetPoint("LEFT", expansionDropdown, "RIGHT", 15, 0)

    GMReputation.frames.factionSection = section
    GMReputation.frames.expansionDropdown = expansionDropdown
    GMReputation.frames.factionDropdown = factionDropdown
end

-- Create reputation display and slider section
function GMReputation.CreateReputationSection(parent)
    local section = CreateStyledFrame(parent, UISTYLE_COLORS.OptionBg)
    local sectionWidth = parent:GetWidth() - 40
    section:SetSize(sectionWidth, 120)
    section:SetPoint("TOP", GMReputation.frames.factionSection, "BOTTOM", 0, -10)
    section:Show()

    -- Current standing display
    local standingLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    standingLabel:SetPoint("TOP", section, "TOP", 0, -15)
    standingLabel:SetText("Current Standing: Select a faction")
    standingLabel:SetTextColor(1, 1, 1)

    -- Reputation value display
    local repValueLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repValueLabel:SetPoint("TOP", standingLabel, "BOTTOM", 0, -5)
    repValueLabel:SetText("")
    repValueLabel:SetTextColor(0.8, 0.8, 0.8)

    -- Slider container
    local sliderContainer = CreateFrame("Frame", nil, section)
    sliderContainer:SetSize(sectionWidth - 60, 50)
    sliderContainer:SetPoint("TOP", repValueLabel, "BOTTOM", 0, -10)

    -- Min label
    local minLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minLabel:SetPoint("LEFT", sliderContainer, "LEFT", 0, -5)
    minLabel:SetText("-42000")
    minLabel:SetTextColor(0.8, 0, 0)

    -- Max label
    local maxLabel = sliderContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxLabel:SetPoint("RIGHT", sliderContainer, "RIGHT", 0, -5)
    maxLabel:SetText("42999")
    maxLabel:SetTextColor(0.5, 0, 1)

    -- Create the reputation slider
    local repSlider = CreateStyledSlider(
        sliderContainer,
        sectionWidth - 140, -- Width
        20,                  -- Height
        -42000,              -- Min
        42999,               -- Max
        100,                 -- Step
        0                    -- Default
    )
    repSlider:SetPoint("CENTER", sliderContainer, "CENTER", 0, 0)
    repSlider:SetLabel("Reputation")
    repSlider:SetValueText("%.0f")

    -- Slider value changed callback
    repSlider:SetOnValueChanged(function(value)
        GMReputation.state.currentRep = value
        local standingName, standingData = GetStandingFromValue(value)
        GMReputation.UpdateStandingDisplay(standingName, value)
    end)

    -- Apply button
    local applyBtn = CreateStyledButton(section, "Apply Changes", 120, 28)
    applyBtn:SetPoint("BOTTOM", section, "BOTTOM", 0, 10)
    applyBtn:SetScript("OnClick", function()
        if not GMReputation.state.selectedFactionId then
            print("[Reputation] Please select a faction first")
            return
        end

        -- Get target name directly from input field
        local targetName = "Self"
        if GMReputation.frames.targetInput then
            targetName = GMReputation.frames.targetInput:GetText()
            if targetName == "" then targetName = "Self" end
        end

        print("[Reputation] Setting " .. targetName .. "'s reputation with " ..
              (GMReputation.state.selectedFactionName or "faction") .. " to " .. GMReputation.state.currentRep)

        AIO.Handle("GameMasterSystem", "setPlayerReputationByName",
            targetName,
            GMReputation.state.selectedFactionId,
            GMReputation.state.currentRep)
    end)

    GMReputation.frames.reputationSection = section
    GMReputation.frames.standingLabel = standingLabel
    GMReputation.frames.repValueLabel = repValueLabel
    GMReputation.frames.repSlider = repSlider
    GMReputation.frames.applyBtn = applyBtn
end

-- Create quick set buttons section
function GMReputation.CreateQuickSetSection(parent)
    local section = CreateStyledFrame(parent, UISTYLE_COLORS.OptionBg)
    local sectionWidth = parent:GetWidth() - 40
    section:SetSize(sectionWidth, 90)
    section:SetPoint("TOP", GMReputation.frames.reputationSection, "BOTTOM", 0, -10)
    section:Show()

    -- Section title
    local sectionTitle = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionTitle:SetPoint("TOP", section, "TOP", 0, -10)
    sectionTitle:SetText("Quick Set Standing")
    sectionTitle:SetTextColor(0.9, 0.9, 0.9)

    -- Calculate button layout (4 per row, 2 rows)
    local buttonWidth = 95
    local buttonHeight = 25
    local buttonsPerRow = 4
    local xSpacing = buttonWidth + 10
    local totalWidth = (buttonsPerRow * buttonWidth) + ((buttonsPerRow - 1) * 10)
    local startX = (sectionWidth - totalWidth) / 2
    local startY = -30

    for i, preset in ipairs(GMReputation.STANDING_PRESETS) do
        local row = math.floor((i - 1) / buttonsPerRow)
        local col = (i - 1) % buttonsPerRow

        local btn = CreateStyledButton(section, preset.name, buttonWidth, buttonHeight)
        btn:SetPoint("TOPLEFT", section, "TOPLEFT",
            startX + (col * xSpacing),
            startY - (row * (buttonHeight + 5)))

        -- Color the button text based on standing
        if btn.text then
            btn.text:SetTextColor(preset.color[1], preset.color[2], preset.color[3])
        end

        btn:SetScript("OnClick", function()
            if GMReputation.frames.repSlider then
                GMReputation.frames.repSlider:SetValue(preset.value)
                GMReputation.state.currentRep = preset.value
                GMReputation.UpdateStandingDisplay(preset.name, preset.value)
            end
        end)

        btn:SetTooltip(preset.name, "Set reputation to " .. preset.value)
        GMReputation.frames["quickSet_" .. preset.name] = btn
    end

    GMReputation.frames.quickSetSection = section
end

-- Update the target display
function GMReputation.UpdateTargetDisplay()
    -- Currently just used for internal state tracking
end

-- Update the standing display
function GMReputation.UpdateStandingDisplay(standingName, repValue)
    if GMReputation.frames.standingLabel then
        local standingData
        for _, preset in ipairs(GMReputation.STANDING_PRESETS) do
            if preset.name == standingName then
                standingData = preset
                break
            end
        end

        local displayText = "Current Standing: " .. standingName
        if GMReputation.state.selectedFactionName then
            displayText = GMReputation.state.selectedFactionName .. ": " .. standingName
        end

        GMReputation.frames.standingLabel:SetText(displayText)
        if standingData then
            GMReputation.frames.standingLabel:SetTextColor(
                standingData.color[1],
                standingData.color[2],
                standingData.color[3]
            )
        end
    end

    if GMReputation.frames.repValueLabel then
        GMReputation.frames.repValueLabel:SetText("(" .. tostring(repValue) .. ")")
    end
end

-- Update faction dropdown based on selected expansion
function GMReputation.UpdateFactionDropdown()
    if not GMReputation.state.factionData then return end
    if not GMReputation.state.factionData.categories then return end
    if type(GMReputation.state.factionData.categories) ~= "table" then return end

    local factions = {}
    local selectedCategory = GMReputation.state.selectedExpansion

    -- Only match the exact category name (fixes duplicate entries bug)
    for _, category in ipairs(GMReputation.state.factionData.categories) do
        if category and category.name and category.name == selectedCategory then
            if category.factions and type(category.factions) == "table" then
                for _, faction in ipairs(category.factions) do
                    if faction and faction.name and faction.id then
                        table.insert(factions, {
                            text = faction.name,
                            value = faction.id
                        })
                    end
                end
            end
            break -- Found the category, no need to continue
        end
    end

    -- Sort alphabetically
    table.sort(factions, function(a, b) return a.text < b.text end)

    -- Update the dropdown
    if GMReputation.frames.factionDropdown and GMReputation.frames.factionDropdown.UpdateItems then
        GMReputation.frames.factionDropdown:UpdateItems(factions)
    end
end

-- Handler: Receive faction data from server (kept for compatibility, data is now embedded)
GameMasterSystem.receiveReputationData = function(data)
    -- Faction data is now embedded in client, this handler is no longer needed
    -- but kept for backwards compatibility
end

-- Handler: Receive player reputation data
GameMasterSystem.receivePlayerReputation = function(data)
    GMReputation.state.currentRep = data.currentRep
    GMReputation.state.standingName = data.standingName

    -- Update slider
    if GMReputation.frames.repSlider then
        GMReputation.frames.repSlider:SetValue(data.currentRep)
    end

    -- Update display
    GMReputation.UpdateStandingDisplay(data.standingName, data.currentRep)
end

-- Handler: Reputation update confirmed
GameMasterSystem.reputationUpdateConfirmed = function(data)
    if data.success then
        print("[Reputation] " .. data.message)
        GMReputation.state.currentRep = data.currentRep
        GMReputation.state.standingName = data.standingName

        -- Update display
        GMReputation.UpdateStandingDisplay(data.standingName, data.currentRep)
    else
        print("[Reputation] Error: " .. (data.message or "Unknown error"))
    end
end

-- Handler: Reputation error
GameMasterSystem.reputationError = function(message)
    print("[Reputation] Error: " .. message)
end
