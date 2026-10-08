local M = {}

function M.apply(config)
    -- 窗口装饰样式（标题栏 + 最大化/最小化/关闭按钮）
    -- 运行时可用 LEADER+d 在 "TITLE | RESIZE" 与 "NONE" 之间切换
    config.window_decorations = "TITLE | RESIZE"

    -- 窗口行为
    config.adjust_window_size_when_changing_font_size = false
    config.window_close_confirmation = "NeverPrompt"
end

return M
