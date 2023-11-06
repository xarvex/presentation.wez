local wezterm = require("wezterm")

local M = {}

---@class ConfigModeKeybind
---@field key? string
---@field mods? string

---@class ConfigMode
---@field enabled? boolean
---@field keybind? ConfigModeKeybind
---@field font_weight? string
---@field font_size_multiplier? number

---@class Config
---@field presentation? ConfigMode
---@field presentation_full? ConfigMode
---@field font_weight? string
---@field font_size_multiplier? number

---@type Config
local default_config = {
    presentation = {
        enabled = true,
        keybind = {
            key = "p",
            mods = "CTRL|ALT"
        }
    },
    presentation_full = {
        enabled = true,
        keybind = {
            key = "p",
            mods = "CTRL|ALT|SHIFT"
        }
    }
}


---@param t1 table
---@param t2 table
---@return table t
local function deep_merge_table(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                deep_merge_table(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end

    return t1
end

local presentation_active = false
local presentation_prev_font_weight
local presentation_prev_font_size
local presentation_fullscreen = false

---@class PresentationOpts
---@field fullscreen? boolean
---@field font_weight? string
---@field font_size_multiplier? number

---@type PresentationOpts
local default_toggle = {
    fullscreen = false,
    font_weight = "DemiBold",
    font_size_multiplier = 2.0
}

---@param win table
---@param opts? PresentationOpts
---@param record_attributes? boolean
---@return unknown overrides
local function enable(win, opts, record_attributes)
    ---@type PresentationOpts
    opts = opts and deep_merge_table(default_toggle, opts) or default_toggle

    local config = win:effective_config()
    local overrides = win:get_config_overrides() or {}

    if not overrides.font then
        overrides.font = {}
    end
    if not overrides.font.font then
        overrides.font.font = {}
    end
    if not overrides.font.font[1] then
        overrides.font.font[1] = config.font.font[1]
    end

    if record_attributes then
        presentation_prev_font_weight = overrides.font.font[1].weight
        presentation_prev_font_size = config.font_size
        presentation_fullscreen = not win:get_dimensions().is_full_screen
    end

    overrides.font.font[1].weight = opts.font_weight
    overrides.font_size = presentation_prev_font_size * opts.font_size_multiplier

    if opts.fullscreen ~= win:get_dimensions().is_full_screen then
        win:toggle_fullscreen()
        presentation_fullscreen = opts.fullscreen
        if not opts.fullscreen then
            win:maximize()
        end
    else if opts.fullscreen and presentation_fullscreen then
            win:toggle_fullscreen()
        else if presentation_fullscreen then
                win:maximize()
            end
        end
    end

    presentation_active = true

    return overrides
end

---@param win table
---@param opts? PresentationOpts
local function toggle(win, opts)
    ---@type PresentationOpts
    opts = opts and deep_merge_table(default_toggle, opts) or default_toggle

    local overrides = win:get_config_overrides() or {}

    if presentation_active then
        if opts.fullscreen ~= win:get_dimensions().is_full_screen then
            deep_merge_table(overrides, enable(win, opts, false))
        else
            overrides.font.font[1].weight = presentation_prev_font_weight
            overrides.font_size = presentation_prev_font_size

            if opts.fullscreen and presentation_fullscreen then
                win:toggle_fullscreen()
            end
            win:restore()
            presentation_active = false
        end
    else
        deep_merge_table(overrides, enable(win, opts, true))
    end

    win:set_config_overrides(overrides)
end

---@param config unknown
---@param opts? Config
---@return unknown config
function M.apply_to_config(config, opts)
    if not config.keys then
        config.keys = {}
    end

    ---@type Config
    opts = opts and deep_merge_table(default_config, opts) or default_config

    if opts.presentation.enabled then
        table.insert(config.keys, {
            key = opts.presentation.keybind.key,
            mods = opts.presentation.keybind.mods,
            action = wezterm.action_callback(function(win)
                toggle(win, {
                    fullscreen = false,
                    font_weight = opts.presentation.font_weight or opts.font_weight,
                    font_size_multiplier = opts.presentation.font_size_multiplier or opts.font_size_multiplier
                })
            end)
        })
    end
    if opts.presentation_full.enabled then
        table.insert(config.keys, {
            key = opts.presentation_full.keybind.key,
            mods = opts.presentation_full.keybind.mods,
            action = wezterm.action_callback(function(win)
                toggle(win, {
                    fullscreen = true,
                    font_weight = opts.presentation_full.font_weight or opts.font_weight,
                    font_size_multiplier = opts.presentation_full.font_size_multiplier or opts.font_size_multiplier
                })
            end)
        })
    end

    return config
end

return M
