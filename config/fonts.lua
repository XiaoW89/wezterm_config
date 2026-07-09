local wezterm = require("wezterm")

local constants = require("config.constants")

local M = {}

function M.apply(config)
    -- 1. 依然指定你的自定义字体目录
    config.font_dirs = { constants.CONFIG_DIR .. "/fonts" }
    
    -- 2. 删掉原来的 font_locator 配置，让 WezTerm 默认同时查找自定义和系统目录
    
    -- 3. 多字体回退机制
    config.font = wezterm.font_with_fallback {
        { family = "JetBrains Mono NL Regular" },
        { family = "Microsoft YaHei" },    -- Windows 微软雅黑
        { family = "PingFang SC" },        -- macOS 萍方
        { family = "Noto Sans CJK SC" },   -- Linux/通用
    }
    
    config.font_size = 12
    config.use_cap_height_to_scale_fallback_fonts = true
end

return M