# GameMasterUI for TrinityCore & AzerothCore 3.3.5

A comprehensive in-game Game Master management interface for TrinityCore and AzerothCore servers using the AIO (AddOn In-game Organizer) framework. **Automatic core detection** - works out of the box with both emulators.

## Features

- **NPC Management**: Search, spawn, and manage NPCs
- **Item Management**: Search, add items, and manage inventories
- **Spell Management**: Search and manage spells
- **Player Management**: Manage player accounts, characters, and permissions
- **Ban System**: Comprehensive ban management interface
- **Model Preview**: 3D model viewer for NPCs and items
- **Context Menus**: Right-click context menus for quick actions
- **Bug Reporting**: Built-in issue reporting system for GitHub integration

## Core Support (TrinityCore & AzerothCore)

The addon **automatically detects** your server core using Eluna's `GetCoreName()` function and configures itself accordingly.

### Auto-Detection

| Core | Default Database Names |
|------|----------------------|
| **TrinityCore** | `world`, `characters`, `auth` |
| **AzerothCore** | `acore_world`, `acore_characters`, `acore_auth` |

### Key Differences Handled Automatically

| Feature | TrinityCore | AzerothCore |
|---------|-------------|-------------|
| NPC Models | `modelid1-4` fields in `creature_template` | Uses `creature_template_model` join table |
| Database Names | Standard naming | `acore_` prefix |
| Query Structure | Direct field access | JOIN queries where needed |

**No configuration required** - just install and use. Override database names only if you use custom naming.

## Prerequisites

- TrinityCore or AzerothCore 3.3.5
- Eluna Lua Engine installed and working
- AIO framework (included in most Eluna packages)
- MySQL/MariaDB database

## Installation

> **Quick Database Setup**
>
> | Setup | What to do |
> |-------|-----------|
> | **Auto-detect (default)** | Nothing - works out of the box |
> | **Custom names** | Edit `Server/Core/GameMasterUI_Config.lua` line ~114 |
>
> ```lua
> -- Change this line in GameMasterUI_Config.lua:
> names = {
>     world = "YOUR_WORLD_DB",
>     characters = "YOUR_CHAR_DB",
>     auth = "YOUR_AUTH_DB"
> },
> ```

### 1. Copy Files

Copy the entire `GameMasterUI` folder to your server's Lua scripts directory:

```
lua_scripts/AIO_Server/GameMasterUI/
```

### 2. Ensure AIO Framework

Make sure these AIO core files exist in your `AIO_Server` directory:

- `AIO.lua` - Core AIO framework
- `UIStyleLibraryServer.lua` - Server-side UI library
- `AIO_UIStyleLibraryClient.lua` - Client-side UI library should be
  the https://github.com/Isidorsson/Eluna-scripts/tree/master/AIO%20Scripts

### 3. Database Configuration

The addon uses **automatic core detection** to configure database settings. Most users won't need to change anything.

#### Understanding Core Detection

The addon automatically detects your server type and sets appropriate database names:

**TrinityCore (Default):**

```
world      → world
characters → characters
auth       → auth
```

**AzerothCore:**

```
world      → acore_world
characters → acore_characters
auth       → acore_auth
```

#### Changing Database Settings

Edit `Server/Core/GameMasterUI_Config.lua` to customize database names.

**Step-by-Step: Setting Custom Database Names**

1. Open `Server/Core/GameMasterUI_Config.lua`
2. Find the `database.names` section (around line 114)
3. Replace `defaultDatabaseNames` with your custom names:

---

**Example A: Keep Auto-Detection (Default - No Changes Needed)**
```lua
names = defaultDatabaseNames,  -- Auto-detects TrinityCore or AzerothCore
```

---

**Example B: TrinityCore with Custom Prefix**
```lua
names = {
    world = "myserver_world",
    characters = "myserver_characters",
    auth = "myserver_auth"
},
```

---

**Example C: AzerothCore with Custom Prefix**
```lua
names = {
    world = "ac_world",
    characters = "ac_characters",
    auth = "ac_auth"
},
```

---

**Example D: Production Server Setup**
```lua
names = {
    world = "prod_world_335",
    characters = "prod_chars",
    auth = "prod_auth"
},
```

---

**Example E: Multi-Realm Setup**
```lua
names = {
    world = "realm1_world",
    characters = "realm1_characters",
    auth = "shared_auth"  -- Can share auth across realms
},
```

#### Database Configuration Options

Located in `GameMasterUI_Config.lua` under the `database` section:

| Option                   | Default | Description                                         |
|--------------------------|---------|-----------------------------------------------------|
| `enableAsync`            | `true`  | Use async queries (recommended for performance)     |
| `checkTablesOnStartup`   | `true`  | Verify all required tables exist on server start    |
| `cacheTableChecks`       | `true`  | Cache table existence checks for better performance |
| `fallbackOnMissingTable` | `true`  | Continue operation if optional tables are missing   |

**Optional Tables** (addon works without these):

- `gameobjectdisplayinfo` - GameObject model preview
- `spellvisualeffectname` - Spell visual effects
- `creature_template_model` - Creature model data (AzerothCore)
- `creature_equip_template` - NPC equipment data
- `item_enchantment_template` - Item enchantment data

**Required Tables** (addon needs these):

- `creature_template` - NPC data
- `gameobject_template` - GameObject data
- `item_template` - Item data
- `spell` - Spell data (import from DBC if missing)

#### Async vs Synchronous Queries

**Async Queries (Default - Recommended):**

- Non-blocking database operations
- Better server performance
- Prevents lag during heavy queries
- Uses `WorldDBQueryAsync`, `CharDBQueryAsync`, `AuthDBQueryAsync`

**Synchronous Queries (Legacy):**

```lua
database = {
    enableAsync = false, -- Disable async (not recommended)
    -- ...
}
```

⚠️ **Note:** Synchronous queries can cause server lag on large databases.

#### Database Troubleshooting

**Check Database Connection on Startup:**

The addon validates database connections automatically. Check your server console for:

```
[GameMasterUI] All database tables found!
[GameMasterUI] Database 'world' (world) - Connection OK
```

**Missing Tables Warning:**

```
[GameMasterUI] Missing optional tables: spellvisualeffectname
[GameMasterUI] Some features will work with reduced functionality.
```

**Fix Missing Spell Table:**

If you see errors about missing `spell` table:

1. Import the spell DBC into your world database
2. Use TrinityCore or AzerothCore DBC import tools
3. Restart the server

**Test Database Connection In-Game:**

Open the GameMasterUI (`/gm`) - if it loads successfully, database connections are working.

### 4. Server Configuration

No additional server configuration is required. The addon will automatically load when Eluna initializes.

## Usage

### Opening the Interface

Game Masters can open the interface using:

```
/gm
/gamemaster
```

### Permissions

The addon automatically checks GM levels:

- Only accounts with GM level > 0 can access the interface
- Different features may require different GM levels

### Key Bindings

- **ESC**: Close the current window
- **Right-Click**: Open context menus on items, NPCs, or players
- **Left-Click**: Select items or activate buttons
- **Ctrl+R**: Refresh current data

### Reporting Issues

The GameMasterUI includes a built-in issue reporting system:

1. Click the **"!"** button in the top-right corner (next to the Refresh button)
2. Fill out the report form with:
    - Category (Bug Report, Feature Request, etc.)
    - Title of the issue
    - Description of the problem
3. Click "Generate Report URL"
4. Copy the generated GitHub issue URL (Ctrl+C)
5. Paste the URL in your browser to create the issue on GitHub

**Note**: Before using the report feature, update the GitHub repository URL in:

```
Client/00_Core/GMClient_01_Config.lua
```

Change `githubRepo = "yourusername/yourrepo"` to your actual repository.

## File Structure

```
GameMasterUI/
├── README.md                          # This file
├── CHANGELOG.md                       # Version history
├── gameMasterUtils.lua                # Shared utilities
├── Client/                            # Client-side (100+ files)
│   ├── 00_Core/                       # Config, state machine, utils
│   ├── 01_UI/                         # Main frame, layout
│   ├── 02_Cards/                      # Card display system
│   ├── 03_Systems/                    # Object editor, templates, inventory
│   ├── 04_Menus/                      # Context menus (80+ files)
│   └── GMClient_09_Init.lua           # Client initialization
├── Server/                            # Server-side (140+ files)
│   ├── GameMasterUIServer.lua         # Main entry point
│   ├── Core/                          # Config, constants, helpers
│   │   ├── GameMasterUI_Config.lua    # ⭐ Main configuration file
│   │   ├── GameMasterUI_Constants.lua # WoW 3.3.5 constants
│   │   ├── GameMasterUI_DatabaseHelper.lua
│   │   └── GameMasterUI_Utils.lua
│   ├── Database/                      # Query templates (per-core)
│   │   └── GameMasterUI_Database.lua  # TrinityCore & AzerothCore queries
│   ├── Data/                          # Static data (enchants, factions)
│   ├── Handlers/                      # AIO message handlers
│   │   ├── Entity/                    # NPC, Item, Object spawning
│   │   ├── Player/                    # Character, spells, inventory, mail
│   │   ├── Template/                  # Live template editing
│   │   ├── Teleport/                  # Teleport system
│   │   └── GMPowers/                  # GM power handlers
│   └── Utils/                         # Cache, fuzzy matcher, async utils
└── docs/                              # Documentation (30+ guides)
```

## Troubleshooting

### Common Issues

1. **"You do not have permission to use this command"**
    - Ensure your account has GM level ≥ 2 (default requirement)
    - Check account permissions: `SELECT * FROM auth.account_access WHERE id = YOUR_ACCOUNT_ID;`
    - Set GM level: `UPDATE auth.account_access SET gmlevel = 2 WHERE id = YOUR_ACCOUNT_ID;`
    - Modify required level in `GameMasterUI_Config.lua` if needed

2. **UI doesn't appear after `/gm` command**
    - Verify AIO is working: Type `.aio` in-game (should show AIO status)
    - Check server console for Lua errors during startup
    - Verify all files are in `lua_scripts/AIO_Server/GameMasterUI/`
    - Check Eluna.log for errors: `[ServerPath]/Eluna.log`

3. **Missing UI elements or broken layout**
    - Verify `00_UIStyleLibrary` folder exists in `AIO_Server/`
    - Clear WoW cache: Delete `[WoW]/Cache` folder
    - Clear WDB files: Delete `[WoW]/Data/enUS/cache/WDB/enUS/` folder
    - Reload UI in-game: `/reload`

### Database Issues

**Symptom: "Table not found" errors**

Check the server console on startup:

```
[GameMasterUI] Missing required tables: spell
[GameMasterUI] Some features may not work correctly!
```

**Solutions:**

- Import DBC data (spell table): Use TrinityCore/AzerothCore DBC extractor
- Check database connection: Verify credentials in `worldserver.conf`
- Verify database exists: `SHOW DATABASES;` in MySQL

**Symptom: Slow queries or server lag**

Enable debug mode to identify slow queries:

```lua
-- In GameMasterUI_Config.lua
config = {
    debug = true, -- Enable debug logging
}
```

Check console output for query timing information.

**Solution: Enable async queries (if not already enabled)**

```lua
database = {
    enableAsync = true, -- Recommended for large databases
}
```

**Symptom: Custom database names not working**

Verify configuration:

```lua
database = {
    names = {
        world = "your_actual_database_name",
        characters = "your_chars_db_name",
        auth = "your_auth_db_name"
    },
}
```

Check server console for:

```
[GameMasterUI] Custom database: world = 'your_actual_database_name'
```

**Test database connection manually:**

```sql
-- In MySQL client, verify database exists:
SHOW
DATABASES LIKE 'your_database_name';

-- Test table access:
SELECT COUNT(*)
FROM your_database_name.creature_template;
```

### Performance Monitoring

**Check query performance:**

Enable debug logging temporarily:

```lua
config = {
    debug = true,
}
```

Restart server and monitor console output for query times.

**Optimize large databases:**

- Ensure async queries are enabled
- Increase `defaultPageSize` if needed (default: 100)
- Add database indexes on frequently searched columns:
  ```sql
  CREATE INDEX idx_creature_name ON creature_template(name);
  CREATE INDEX idx_item_name ON item_template(name);
  ```

### Log Files

**Check these files for errors:**

1. **Eluna.log** - Lua script errors
    - Location: `[ServerPath]/Eluna.log`
    - Empty file = No errors ✓

2. **Server.log** - General server errors
    - Location: `[ServerPath]/Server.log`
    - Check for database connection errors

3. **DBErrors.log** - Database errors
    - Location: `[ServerPath]/DBErrors.log`
    - Check for query syntax errors

**Enable detailed logging:**

```lua
-- In GameMasterUI_Config.lua
config = {
    debug = true, -- Enable debug output
    LOG_LEVEL = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4
    }
}
```

### Getting Help

If issues persist:

1. Check server console for error messages
2. Review Eluna.log for Lua errors
3. Verify database configuration
4. Test with debug mode enabled
5. Report issues with console output and config details

## Configuration & Customization

### General Settings

Edit `Server/Core/GameMasterUI_Config.lua` to customize addon behavior:

**Core Settings:**

```lua
config = {
    debug = false, -- Enable debug logging
    REQUIRED_GM_LEVEL = 2, -- Minimum GM level to access (0-3)
    defaultPageSize = 100, -- Search results per page
    removeFromWorld = true, -- Remove GM from world when UI opens
}
```

**GM Level Requirements:**

- `0` = Player (no GM access)
- `1` = Moderator (basic commands)
- `2` = Game Master (full access) ← Default for GameMasterUI
- `3` = Administrator (full server control)

### Database Settings

All database configuration is in `Server/Core/GameMasterUI_Config.lua`:

```lua
database = {
    names = {
        world = "world", -- Change to your database names
        characters = "characters",
        auth = "auth"
    },
    enableAsync = true, -- Use async queries (recommended)
    checkTablesOnStartup = true, -- Validate tables on server start
    cacheTableChecks = true, -- Cache table existence checks
}
```

### How Database Queries Work

**Query Routing:**
The addon automatically routes queries to the correct database:

- `world` → Uses `WorldDBQuery` / `WorldDBQueryAsync`
- `characters` → Uses `CharDBQuery` / `CharDBQueryAsync`
- `auth` → Uses `AuthDBQuery` / `AuthDBQueryAsync`

**Core-Specific Queries:**
The addon maintains separate query definitions for each core type in `Server/Database/GameMasterUI_Database.lua`:

- TrinityCore queries use `modelid1`, `modelid2`, `modelid3`, `modelid4`
- AzerothCore queries use `creature_template_model` join table

**Table Name Qualification:**
When using custom database names (not standard `world`/`characters`/`auth`), the system automatically qualifies table
names:

```sql
-- Standard setup (no qualification needed):
SELECT *
FROM creature_template

-- Custom database names (automatic qualification):
SELECT *
FROM myserver_world.creature_template
```

### Modifying UI Elements

**UI Layout:**

- Client-side files in `Client/` define all UI elements
- Uses UIStyleLibrary for consistent WoW 3.3.5 styling
- Modify positioning, colors, and sizes in respective client files

**Adding Custom Context Menu Actions:**

1. Edit handler files in `Server/Handlers/`
2. Add new AIO message handlers
3. Implement corresponding client-side menu items

**Example - Adding a New Handler:**

```lua
-- Server/Handlers/GameMasterUI_MyHandlers.lua
function GameMasterUI.MyNewAction(player, data)
    -- Your server-side logic here
    AIO.Handle(player, "GameMasterUI", "MyResponse", result)
end

-- Client/MyNewFeature.lua
AIO.Handle("GameMasterUI", "MyResponse", function(player, result)
    -- Your client-side response here
end)
```

## Quick Reference

### Key File Locations

| File                                          | Purpose            | When to Edit                                |
|-----------------------------------------------|--------------------|---------------------------------------------|
| `Server/Core/GameMasterUI_Config.lua`         | Main configuration | Changing database names, GM level, settings |
| `Server/Database/GameMasterUI_Database.lua`   | Database queries   | Adding new queries, modifying SQL           |
| `Server/Core/GameMasterUI_DatabaseHelper.lua` | Database utilities | Advanced database customization             |
| `Client/00_Core/GMClient_01_Config.lua`       | Client settings    | GitHub repo URL for bug reports             |
| `Server/Handlers/`                            | Server logic       | Adding new features, handlers               |
| `Client/`                                     | UI elements        | Modifying UI layout, appearance             |

### Important Settings Summary

**Database Configuration:**

```lua
-- Server/Core/GameMasterUI_Config.lua
database = {
    names = {
        world = "world", -- Your world database name
        characters = "characters", -- Your characters database name
        auth = "auth"          -- Your auth database name
    },
    enableAsync = true, -- Use async queries (recommended)
}
```

**Permission Levels:**

```lua
REQUIRED_GM_LEVEL = 2  -- Default: Game Master level required
```

**Debug Mode:**

```lua
debug = false  -- Set to true for detailed logging
```

### Console Commands

**In-Game Commands:**

- `/gm` or `/gamemaster` - Open GameMasterUI
- `.aio` - Check AIO status
- `/reload` - Reload UI after changes

**MySQL Commands:**

```sql
-- Check GM level
SELECT *
FROM auth.account_access
WHERE id = YOUR_ACCOUNT_ID;

-- Set GM level
UPDATE auth.account_access
SET gmlevel = 2
WHERE id = YOUR_ACCOUNT_ID;

-- Verify database exists
SHOW
DATABASES LIKE 'world';

-- Check tables exist
SHOW
TABLES FROM world LIKE 'creature_template';
```

### Monitoring Server Health

**Check on startup:**

1. Look for: `[GameMasterUI] All database tables found!`
2. Verify: `[GameMasterUI] Database 'world' (world) - Connection OK`
3. No errors in Eluna.log (empty file is good!)

**If problems occur:**

1. Enable debug: `debug = true` in config
2. Check console output
3. Review Eluna.log
4. Test database connection manually

## Support

For issues or questions:

1. Check the server console for error messages
2. Review Eluna.log for Lua errors
3. Verify database configuration in `GameMasterUI_Config.lua`
4. Review the [AIO Development Guide](../AIO-DEVELOPMENT-GUIDE.md)
5. Contact the Eluna community on Discord

## Credits

- Built using the AIO framework by Rochet2
- Uses Eluna Lua Engine for TrinityCore
- UI styling based on WoW 3.3.5 interface guidelines
- Database system supports TrinityCore and AzerothCore