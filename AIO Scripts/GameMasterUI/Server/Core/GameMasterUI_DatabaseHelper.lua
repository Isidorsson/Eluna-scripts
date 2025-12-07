--[[
    GameMasterUI Database Helper Module

    Provides safe database query functions with:
    - Table existence checking
    - Multi-database support (qualified table names)
    - Error handling
    - Query result caching
]]--

-- Load constants module
local Constants = require("GameMasterUI.Server.Core.GameMasterUI_Constants")

local DatabaseHelper = {}

-- Cache for table existence checks
local tableExistsCache = {}
local CACHE_MAX_SIZE = 100  -- Prevent unlimited cache growth

-- Reference to config (will be loaded)
local Config

-- Log level constants (will be loaded from config)
local LOG_LEVEL

-- =====================================================
-- Logging Functions
-- =====================================================

local function log(level, message, ...)
    if not Config then return end
    
    local currentLevel = Config.debug and LOG_LEVEL.DEBUG or LOG_LEVEL.INFO
    if level > currentLevel then return end
    
    local prefix = "[GameMasterUI]"
    local levelStr = ""
    
    if level == LOG_LEVEL.ERROR then
        levelStr = "[ERROR]"
    elseif level == LOG_LEVEL.WARN then
        levelStr = "[WARN]"
    elseif level == LOG_LEVEL.DEBUG then
        levelStr = "[DEBUG]"
    end
    
    print(string.format("%s %s %s", prefix, levelStr, string.format(message, ...)))
end

-- =====================================================
-- Database Query Router
-- =====================================================

local function executeDatabaseFunction(databaseType, queryFunc, executeFunc, query)
    local dbFunc

    if databaseType == "world" then
        dbFunc = queryFunc and WorldDBQuery or WorldDBExecute
    elseif databaseType == "char" then
        dbFunc = queryFunc and CharDBQuery or CharDBExecute
    elseif databaseType == "auth" then
        dbFunc = queryFunc and AuthDBQuery or AuthDBExecute
    else
        return nil, string.format("Invalid database type: %s", tostring(databaseType))
    end

    return dbFunc(query), nil
end

-- Async version of executeDatabaseFunction
local function executeDatabaseFunctionAsync(databaseType, queryFunc, executeFunc, query, callback)
    local dbFunc

    if databaseType == "world" then
        dbFunc = queryFunc and WorldDBQueryAsync or nil -- WorldDBExecuteAsync doesn't exist yet
    elseif databaseType == "char" then
        dbFunc = queryFunc and CharDBQueryAsync or nil
    elseif databaseType == "auth" then
        dbFunc = queryFunc and AuthDBQueryAsync or nil
    else
        if callback then
            callback(nil, string.format("Invalid database type: %s", tostring(databaseType)))
        end
        return
    end

    if dbFunc then
        dbFunc(query, callback)
    else
        if callback then
            callback(nil, "Async execute operations not yet available in Eluna")
        end
    end
end

-- =====================================================
-- Initialization
-- =====================================================

-- Initialize the module with config
function DatabaseHelper.Initialize(config)
    Config = config
    tableExistsCache = {}

    -- Load constants from config
    LOG_LEVEL = Config.LOG_LEVEL

    -- Report core detection and database configuration
    if Config.core then
        -- Report database configuration
        local standardNames = { world = true, characters = true, auth = true }
        local customDbCount = 0

        for dbType, dbName in pairs(Config.database.names) do
            if not standardNames[dbName] then
                log(LOG_LEVEL.INFO, "Custom database: %s = '%s'", dbType, dbName)
                customDbCount = customDbCount + 1
            end
        end

        if customDbCount == 0 then
            -- log(LOG_LEVEL.INFO, "Using standard database names (default TrinityCore setup)")
        end
    end

    if Config.database.checkTablesOnStartup then
        DatabaseHelper.CheckRequiredTables()
    end
end

-- =====================================================
-- Utility Functions
-- =====================================================

-- Validate database type using Constants module
local function isValidDatabaseType(databaseType)
    return Constants.IsValidDatabaseType(databaseType)
end

-- Manage cache size
local function manageCacheSize()
    local cacheCount = 0
    for _ in pairs(tableExistsCache) do
        cacheCount = cacheCount + 1
    end
    
    if cacheCount > CACHE_MAX_SIZE then
        -- Clear oldest entries (simple approach: clear all)
        log(LOG_LEVEL.DEBUG, "Cache size exceeded %d, clearing cache", CACHE_MAX_SIZE)
        tableExistsCache = {}
    end
end

-- =====================================================
-- Core Functions
-- =====================================================

-- Build a qualified table name with database name
function DatabaseHelper.GetQualifiedTableName(tableName, databaseType)
    databaseType = databaseType or "world"

    -- Validate inputs
    if not tableName or type(tableName) ~= "string" or tableName == "" then
        log(LOG_LEVEL.ERROR, "Invalid table name provided: %s", tostring(tableName))
        return tableName
    end

    if not isValidDatabaseType(databaseType) then
        log(LOG_LEVEL.WARN, "Invalid database type: %s, defaulting to world", tostring(databaseType))
        databaseType = "world"
    end

    -- Get database name from config
    -- Use Constants to map internal type (e.g., "char") to config key (e.g., "characters")
    local configKey = Constants.GetConfigKey(databaseType)
    local databaseName = Config.database.names[configKey]

    if not databaseName then
        log(LOG_LEVEL.WARN, "No database name configured for type: %s", databaseType)
        return tableName
    end

    -- For standard TrinityCore/AzerothCore setup, no database qualifier is needed
    -- as tables are in the same database context
    local standardNames = {
        world = true, characters = true, auth = true,
        acore_world = true, acore_characters = true, acore_auth = true
    }
    if standardNames[databaseName] then
        return tableName
    end

    -- For custom database names, qualify with database name
    return databaseName .. "." .. tableName
end

-- Check if a table exists in the database
function DatabaseHelper.TableExists(tableName, databaseType)
    databaseType = databaseType or "world"
    
    -- Validate inputs
    if not tableName or type(tableName) ~= "string" or tableName == "" then
        log(LOG_LEVEL.ERROR, "Invalid table name for existence check: %s", tostring(tableName))
        return false
    end
    
    if not isValidDatabaseType(databaseType) then
        log(LOG_LEVEL.WARN, "Invalid database type for table check: %s", tostring(databaseType))
        return false
    end
    
    -- Check cache first
    local cacheKey = databaseType .. "." .. tableName
    if Config.database.cacheTableChecks and tableExistsCache[cacheKey] ~= nil then
        return tableExistsCache[cacheKey]
    end
    
    -- Query to check table existence
    local checkQuery = string.format("SHOW TABLES LIKE '%s'", tableName)
    
    local success, result = pcall(function()
        return executeDatabaseFunction(databaseType, true, false, checkQuery)
    end)
    
    local exists = success and result ~= nil
    
    -- Cache the result
    if Config.database.cacheTableChecks then
        manageCacheSize()
        tableExistsCache[cacheKey] = exists
    end
    
    return exists
end

-- Execute a safe query with error handling
function DatabaseHelper.SafeQuery(query, databaseType)
    databaseType = databaseType or "world"
    
    -- Validate inputs
    if not query or type(query) ~= "string" or query == "" then
        local err = "Invalid query provided"
        log(LOG_LEVEL.ERROR, err)
        return nil, err
    end
    
    if not isValidDatabaseType(databaseType) then
        local err = string.format("Invalid database type: %s", tostring(databaseType))
        log(LOG_LEVEL.ERROR, err)
        return nil, err
    end
    
    local success, result = pcall(function()
        return executeDatabaseFunction(databaseType, true, false, query)
    end)

    if not success then
        local errorMsg = tostring(result)
        local coreName = Config.core or "Unknown"

        -- Add helpful context about the error
        log(LOG_LEVEL.ERROR, "Database query failed on %s: %s", coreName, errorMsg)
        log(LOG_LEVEL.DEBUG, "Failed query: %s", query)

        -- Provide specific guidance for common errors
        if errorMsg:find("Unknown column") and coreName == "AzerothCore" then
            log(LOG_LEVEL.WARN, "Possible AzerothCore compatibility issue - table structure may differ from TrinityCore")
        elseif errorMsg:find("doesn't exist") then
            log(LOG_LEVEL.WARN, "Table not found - check if required tables exist in %s database", databaseType)
        elseif errorMsg:find("syntax error") then
            log(LOG_LEVEL.WARN, "SQL syntax error - query may be incompatible with %s", coreName)
        end

        return nil, errorMsg
    end
    
    return result, nil
end

-- Execute a safe database update/insert/delete
function DatabaseHelper.SafeExecute(query, databaseType)
    databaseType = databaseType or "world"

    -- Validate inputs
    if not query or type(query) ~= "string" or query == "" then
        local err = "Invalid query provided for execute"
        log(LOG_LEVEL.ERROR, err)
        return false, err
    end

    if not isValidDatabaseType(databaseType) then
        local err = string.format("Invalid database type: %s", tostring(databaseType))
        log(LOG_LEVEL.ERROR, err)
        return false, err
    end

    local success, result = pcall(function()
        return executeDatabaseFunction(databaseType, false, true, query)
    end)

    if not success then
        log(LOG_LEVEL.ERROR, "Database execute failed: %s", tostring(result))
        log(LOG_LEVEL.DEBUG, "Failed query: %s", query)
        return false, tostring(result)
    end

    return true, nil
end

-- Execute an asynchronous safe query with callback
function DatabaseHelper.SafeQueryAsync(query, callback, databaseType, allowEmptyResults)
    databaseType = databaseType or "world"
    allowEmptyResults = allowEmptyResults or false

    -- Check if async is enabled in config
    if not (Config and Config.database and Config.database.enableAsync) then
        -- Fallback to synchronous query
        local result, error = DatabaseHelper.SafeQuery(query, databaseType)
        if callback then
            callback(result, error)
        end
        return
    end

    -- Validate inputs
    if not query or type(query) ~= "string" or query == "" then
        local err = "Invalid query provided"
        log(LOG_LEVEL.ERROR, err)
        if callback then callback(nil, err) end
        return
    end

    if not callback or type(callback) ~= "function" then
        local err = "Invalid callback function provided"
        log(LOG_LEVEL.ERROR, err)
        return
    end

    if not isValidDatabaseType(databaseType) then
        local err = string.format("Invalid database type: %s", tostring(databaseType))
        log(LOG_LEVEL.ERROR, err)
        callback(nil, err)
        return
    end

    -- Wrap callback with error handling
    local safeCallback = function(result, error)
        local success, callbackError = pcall(function()
            if result then
                callback(result, nil)
            else
                local errorMsg = error or "Query returned no results"

                -- Only log error if empty results are not allowed for this query type
                if not allowEmptyResults then
                    log(LOG_LEVEL.ERROR, "Async database query failed: %s", errorMsg)
                    log(LOG_LEVEL.DEBUG, "Failed query: %s", query)
                elseif Config and Config.debug then
                    -- Debug logging for empty results when allowed
                    log(LOG_LEVEL.DEBUG, "Query returned empty results (expected): %s", query)
                end

                callback(nil, errorMsg)
            end
        end)

        if not success then
            log(LOG_LEVEL.ERROR, "Callback execution failed: %s", tostring(callbackError))
        end
    end

    executeDatabaseFunctionAsync(databaseType, true, false, query, safeCallback)
end

-- Execute an asynchronous safe database update/insert/delete
function DatabaseHelper.SafeExecuteAsync(query, callback, databaseType)
    databaseType = databaseType or "world"

    -- Check if async is enabled in config, or fallback to sync for execute operations
    -- Note: Async execute operations are not yet available in Eluna, so we always use sync
    if not (Config and Config.database and Config.database.enableAsync) then
        -- Fallback to synchronous execute
        local success, error = DatabaseHelper.SafeExecute(query, databaseType)
        if callback then
            callback(success, error)
        end
        return
    end

    -- Validate inputs
    if not query or type(query) ~= "string" or query == "" then
        local err = "Invalid query provided for async execute"
        log(LOG_LEVEL.ERROR, err)
        if callback then callback(false, err) end
        return
    end

    if not callback or type(callback) ~= "function" then
        local err = "Invalid callback function provided"
        log(LOG_LEVEL.ERROR, err)
        return
    end

    if not isValidDatabaseType(databaseType) then
        local err = string.format("Invalid database type: %s", tostring(databaseType))
        log(LOG_LEVEL.ERROR, err)
        callback(false, err)
        return
    end

    -- For now, always fallback to sync execute since async execute not available in Eluna
    local success, error = DatabaseHelper.SafeExecute(query, databaseType)
    callback(success, error)
end

-- Optimized table name replacement with caching
local tableReplacementCache = {}
local REPLACEMENT_CACHE_MAX = 50

local function replaceTableNames(query, tableName, qualifiedName)
    -- Cache key includes both names to handle different prefixes
    local cacheKey = query .. "|" .. tableName .. "|" .. qualifiedName
    
    -- Check cache
    if tableReplacementCache[cacheKey] then
        return tableReplacementCache[cacheKey]
    end
    
    -- Escape special pattern characters in table name
    local escapedTableName = tableName:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    
    -- More efficient replacement patterns
    local patterns = {
        -- Table name at start of query or after whitespace
        { "^" .. escapedTableName .. "([^%w])", qualifiedName .. "%1" },
        { "([%s%(])" .. escapedTableName .. "([^%w])", "%1" .. qualifiedName .. "%2" },
        -- Table name at end of query
        { "([^%w])" .. escapedTableName .. "$", "%1" .. qualifiedName },
        -- Table name followed by whitespace or punctuation
        { "([^%w])" .. escapedTableName .. "([%s%p])", "%1" .. qualifiedName .. "%2" }
    }
    
    local modifiedQuery = query
    for _, pattern in ipairs(patterns) do
        modifiedQuery = modifiedQuery:gsub(pattern[1], pattern[2])
    end
    
    -- Manage cache size
    local cacheCount = 0
    for _ in pairs(tableReplacementCache) do
        cacheCount = cacheCount + 1
    end
    if cacheCount > REPLACEMENT_CACHE_MAX then
        tableReplacementCache = {}
    end
    
    -- Cache result
    tableReplacementCache[cacheKey] = modifiedQuery
    
    return modifiedQuery
end

-- Build a safe query that checks for table existence first
function DatabaseHelper.BuildSafeQuery(query, requiredTables, databaseType)
    databaseType = databaseType or "world"

    -- Validate inputs
    if not query or type(query) ~= "string" then
        local err = "Invalid query provided to BuildSafeQuery"
        log(LOG_LEVEL.ERROR, err)
        return nil, err
    end

    if not requiredTables or type(requiredTables) ~= "table" then
        local err = "Invalid required tables list"
        log(LOG_LEVEL.ERROR, err)
        return nil, err
    end

    if not isValidDatabaseType(databaseType) then
        local err = string.format("Invalid database type: %s", tostring(databaseType))
        log(LOG_LEVEL.ERROR, err)
        return nil, err
    end

    -- Check if all required tables exist
    for _, tableName in ipairs(requiredTables) do
        if not DatabaseHelper.TableExists(tableName, databaseType) then
            log(LOG_LEVEL.WARN, "Table '%s' does not exist in %s database", tableName, databaseType)
            return nil, string.format("Table '%s' not found", tableName)
        end
    end

    -- Sort tables by length (longest first) to avoid substring replacement issues
    -- e.g., replace "creature_template_model" before "creature_template"
    local sortedTables = {}
    for _, tableName in ipairs(requiredTables) do
        table.insert(sortedTables, tableName)
    end
    table.sort(sortedTables, function(a, b) return #a > #b end)

    -- Replace table names with qualified names
    local modifiedQuery = query
    for _, tableName in ipairs(sortedTables) do
        local qualifiedName = DatabaseHelper.GetQualifiedTableName(tableName, databaseType)
        -- Only replace if we have a prefix
        if qualifiedName ~= tableName then
            modifiedQuery = replaceTableNames(modifiedQuery, tableName, qualifiedName)
        end
    end

    return modifiedQuery, nil
end

-- Async version of BuildSafeQuery that executes the query automatically
function DatabaseHelper.BuildSafeQueryAsync(query, requiredTables, callback, databaseType)
    databaseType = databaseType or "world"

    -- Check if async is enabled in config
    if not (Config and Config.database and Config.database.enableAsync) then
        -- Fallback to synchronous operation
        local modifiedQuery, error = DatabaseHelper.BuildSafeQuery(query, requiredTables, databaseType)
        if modifiedQuery then
            local result, queryError = DatabaseHelper.SafeQuery(modifiedQuery, databaseType)
            if callback then callback(result, queryError) end
        else
            if callback then callback(nil, error) end
        end
        return
    end

    -- Validate inputs
    if not query or type(query) ~= "string" then
        local err = "Invalid query provided to BuildSafeQueryAsync"
        log(LOG_LEVEL.ERROR, err)
        if callback then callback(nil, err) end
        return
    end

    if not requiredTables or type(requiredTables) ~= "table" then
        local err = "Invalid required tables list"
        log(LOG_LEVEL.ERROR, err)
        if callback then callback(nil, err) end
        return
    end

    if not callback or type(callback) ~= "function" then
        local err = "Invalid callback function provided"
        log(LOG_LEVEL.ERROR, err)
        return
    end

    if not isValidDatabaseType(databaseType) then
        local err = string.format("Invalid database type: %s", tostring(databaseType))
        log(LOG_LEVEL.ERROR, err)
        callback(nil, err)
        return
    end

    -- Check if all required tables exist
    for _, tableName in ipairs(requiredTables) do
        if not DatabaseHelper.TableExists(tableName, databaseType) then
            local err = string.format("Table '%s' not found", tableName)
            log(LOG_LEVEL.WARN, "Table '%s' does not exist in %s database", tableName, databaseType)
            callback(nil, err)
            return
        end
    end

    -- Sort tables by length (longest first) to avoid substring replacement issues
    -- e.g., replace "creature_template_model" before "creature_template"
    local sortedTables = {}
    for _, tableName in ipairs(requiredTables) do
        table.insert(sortedTables, tableName)
    end
    table.sort(sortedTables, function(a, b) return #a > #b end)

    -- Replace table names with qualified names
    local modifiedQuery = query
    for _, tableName in ipairs(sortedTables) do
        local qualifiedName = DatabaseHelper.GetQualifiedTableName(tableName, databaseType)
        -- Only replace if we have a prefix
        if qualifiedName ~= tableName then
            modifiedQuery = replaceTableNames(modifiedQuery, tableName, qualifiedName)
        end
    end

    -- Execute the query asynchronously
    DatabaseHelper.SafeQueryAsync(modifiedQuery, callback, databaseType)
end

-- =====================================================
-- Database Maintenance Functions
-- =====================================================

-- Check for required tables on startup
function DatabaseHelper.CheckRequiredTables()
    -- Checking database tables

    -- Report database configuration
    local standardNames = { world = true, characters = true, auth = true }
    local hasCustomDb = false

    for dbType, dbName in pairs(Config.database.names) do
        if not standardNames[dbName] then
            -- Using custom database name
            hasCustomDb = true
        end
    end

    if not hasCustomDb then
        -- Using standard database names
    end

    local missingRequired = {}
    local missingOptional = {}
    
    -- Check required tables
    for _, tableName in ipairs(Config.database.requiredTables) do
        if not DatabaseHelper.TableExists(tableName, "world") then
            table.insert(missingRequired, tableName)
        end
    end
    
    -- Check optional tables and categorize DBC tables
    local missingDBC = {}
    local missingOther = {}
    local dbcTables = {
        gameobjectdisplayinfo = true,
        spellvisual = true,
        spellvisualkit = true,
        spellvisualeffectname = true
    }

    for _, tableName in ipairs(Config.database.optionalTables) do
        if not DatabaseHelper.TableExists(tableName, "world") then
            table.insert(missingOptional, tableName)
            if dbcTables[tableName] then
                table.insert(missingDBC, tableName)
            else
                table.insert(missingOther, tableName)
            end
        end
    end

    -- Report missing tables
    if #missingRequired > 0 then
        log(LOG_LEVEL.WARN, "Missing required tables: %s", table.concat(missingRequired, ", "))
        log(LOG_LEVEL.WARN, "Some features may not work correctly!")
    end

    if #missingDBC > 0 then
        log(LOG_LEVEL.INFO, "Missing DBC tables: %s", table.concat(missingDBC, ", "))
        log(LOG_LEVEL.INFO, "Visual data features will be limited. These tables require manual DBC import.")
        log(LOG_LEVEL.INFO, "To enable: Use DBC import tools (WoW Spell Editor, node-dbc-reader, or AzerothCore utilities)")
    end

    if #missingOther > 0 then
        log(LOG_LEVEL.DEBUG, "Missing optional tables: %s", table.concat(missingOther, ", "))
        log(LOG_LEVEL.DEBUG, "Some features will work with reduced functionality.")
    end
    
    if #missingRequired == 0 and #missingOptional == 0 then
        log(LOG_LEVEL.INFO, "All database tables found!")
    end
end

-- Clear the table existence cache
function DatabaseHelper.ClearCache()
    tableExistsCache = {}
    tableReplacementCache = {}
    log(LOG_LEVEL.DEBUG, "Database helper caches cleared")
end

-- Check if an optional table is available
function DatabaseHelper.IsOptionalTableAvailable(tableName, databaseType)
    databaseType = databaseType or "world"

    -- Validate inputs
    if not tableName or type(tableName) ~= "string" then
        log(LOG_LEVEL.WARN, "Invalid table name for optional check: %s", tostring(tableName))
        return false
    end

    -- Check if it's in the optional tables list
    local isOptional = false
    for _, optTable in ipairs(Config.database.optionalTables) do
        if optTable == tableName then
            isOptional = true
            break
        end
    end

    -- If it's optional and fallback is enabled, check existence
    if isOptional and Config.database.fallbackOnMissingTable then
        return DatabaseHelper.TableExists(tableName, databaseType)
    end

    -- If not optional, assume it exists (will error if it doesn't)
    return true
end

-- Validate database connections
function DatabaseHelper.ValidateDatabaseConnections()
    log(LOG_LEVEL.INFO, "Validating database connections...")

    local results = {
        world = false,
        char = false,
        auth = false
    }

    local errors = {}

    -- Test each database with a simple query
    for dbType, _ in pairs(Constants.VALID_DATABASE_TYPES) do
        local configKey = Constants.GetConfigKey(dbType)
        local dbName = Config.database.names[configKey]

        if not dbName then
            table.insert(errors, string.format("No database name configured for type: %s", dbType))
            results[dbType] = false
        else
            -- Try a simple SELECT query to test connection
            local testQuery = "SELECT 1 LIMIT 1"
            local success, result = pcall(function()
                return executeDatabaseFunction(dbType, true, false, testQuery)
            end)

            if success and result then
                results[dbType] = true
                log(LOG_LEVEL.INFO, "Database '%s' (%s) - Connection OK", dbName, dbType)
            else
                results[dbType] = false
                local errorMsg = string.format("Database '%s' (%s) - Connection FAILED", dbName, dbType)
                table.insert(errors, errorMsg)
                log(LOG_LEVEL.ERROR, errorMsg)
            end
        end
    end

    -- Return results
    local allValid = results.world and results.char and results.auth

    if allValid then
        log(LOG_LEVEL.INFO, "All database connections validated successfully!")
    else
        log(LOG_LEVEL.WARN, "Some database connections failed. Check configuration.")
        for _, error in ipairs(errors) do
            log(LOG_LEVEL.ERROR, error)
        end
    end

    return allValid, results, errors
end

-- =====================================================
-- Module Export
-- =====================================================

return DatabaseHelper