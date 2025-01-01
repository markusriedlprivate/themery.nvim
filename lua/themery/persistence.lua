local constants = require("themery.constants")
local utils = require("themery.utils")
local filesystem = require("themery.filesystem")
local config = require('themery.config')

local need_fallback = false

-- Saves the selected theme configuration to the user's config file.
-- @param theme table containing the theme data
-- @param theme_id number representing the theme's ID
local function saveTheme(theme, theme_id)
    local settings = config.getSettings()

    local data = {
        version = 0,
        colorscheme = theme.colorscheme,
        theme_id = theme_id,
        beforeCode = theme.before and utils.trimStartSpaces(theme.before) or "",
        afterCode = theme.after and utils.trimStartSpaces(theme.after) or "",
        globalBeforeCode = settings.globalBefore,
        globalAfterCode = settings.globalAfter
    }

    local json_data = vim.json.encode(data)

    local statePaths = config.getStatePaths()
    local state_folder_path = statePaths.state_folder_path
    local state_file_path = statePaths.state_file_path

    -- Create plugin folder if not exist.
    local status, err = pcall(function()
        return filesystem.createDirectoryIfNotExists(state_folder_path)
    end)

    if not status then
        print(constants.MSG_ERROR.CREATE_DIRECTORY .. ": " .. state_folder_path)
        return
    end

    local status, err = pcall(function()
        return filesystem.writeToFile(state_file_path, json_data)
    end)

    if not status then
        print(constants.MSG_ERROR.WRITE_FILE .. ": " .. err)
        return
    end

    print(constants.MSG_INFO.THEME_SAVED)
end

-- Load a function and then execute it.
-- @param code string
local function execute(code)
    local fn, err = load(code)

    if fn then
        fn()
    end
end

-- Load the state.
local function loadState()
    local status, json_data = pcall(function()
        return filesystem.readFromFile(config.getStatePaths().state_file_path)
    end)

    if not status then
        -- The file not exist. It's the first time the plugin is run so
        -- nothing to do.
        return
    end

    local data = vim.json.decode(json_data)

    -- Set a global variable in vim
    vim.g.theme_id = data.theme_id

    if data.globalBeforeCode then
        execute(data.globalBeforeCode)
    end

    execute(data.beforeCode)

    local ok = pcall(function() vim.cmd.colorscheme(data.colorscheme) end)

    if ok then
        execute(data.afterCode)

        if data.globalAfterCode then
            execute(data.globalAfterCode)
        end
    else
        need_fallback = true
    end
end

-- Get if it need to fallback to other colorscheme.
-- @return boolean
local function getIfNeedFallback()
    return need_fallback
end

return {
    saveTheme = saveTheme,
    loadState = loadState,
    getIfNeedFallback = getIfNeedFallback
}
