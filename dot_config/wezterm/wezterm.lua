-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.default_prog = { "C:\\Program Files\\Git\\bin\\bash.exe" }

-- config.front_end = "WebGpu"
-- For example, changing the color scheme:
config.window_background_opacity = 0.85
-- config.win32_system_backdrop = "Mica"
-- config.color_scheme = "Catppuccin Mocha"
config.font = wezterm.font_with_fallback({ "HackGen Console NF" })
config.font_size = 14.0
config.use_ime = true
config.window_decorations = "RESIZE"
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}
config.colors = require("cyberdream")

-- and finally, return the configuration to wezterm
return config
