# wezterm_config

模块化的 WezTerm 配置，用 Lua 编写。保存任意文件即自动重载，无需重启。

## 结构

`wezterm.lua` 是唯一入口，它遍历模块名列表，`require()` 后调用各自的 `apply(config)`。
每个文件都返回带 `apply` 函数的表 `M`，新增分类只需创建 `config/foo.lua` 并把 `"config.foo"` 加进入口的 modules 列表。

```
wezterm.lua          ← 入口，模块加载器
config/
  constants.lua      ← CONFIG_DIR、COLOR_SCHEMES
  utils.lua          ← 系统检测、命令是否存在
  fonts.lua          ← 字体栈（含 CJK 回退）、font_dirs
  appearance.lua     ← 配色、渲染器（WebGPU）、fps、内边距
  window.lua         ← 窗口装饰、关闭行为
  tab_bar.lua        ← format-tab-title 自定义标签渲染
  cursor.lua         ← 光标闪烁
  shell.lua          ← 默认 shell（Windows 用 pwsh）
  keybindings.lua    ← Leader=Ctrl+A、全部按键绑定
  mouse.lua          ← 鼠标绑定
  events.lua         ← toggle-tab-bar、open-uri
  advanced.lua       ← 回滚缓冲、ssh_backend
  hyperlink.lua      ← 自定义超链接规则
  ssh_domains.lua    ← SSH 域快捷方式
  launch_menu.lua    ← 启动器菜单条目
  background.lua     ← 背景图轮播（默认未启用）
```

## 重要设定

- **Leader 键**：`Ctrl+A`，超时 1500 ms。
- **默认快捷键已全部禁用**：`disable_default_key_bindings = true`，下方列表即全部绑定。
- **窗口栏**：默认可见（`TITLE | RESIZE`），可用 `LEADER+d` 切换隐藏。

## 快捷键

### 窗口

| 快捷键 | 作用 |
| --- | --- |
| `F11` | 全屏切换 |
| `LEADER` `d` | 显示 / 隐藏窗口栏（标题栏与最大化、最小化、关闭按钮） |
| `LEADER` `m` | 隐藏窗口（最小化到后台） |
| `Ctrl+Alt+左键拖动` | 移动窗口 |

### 标签页

| 快捷键 | 作用 |
| --- | --- |
| `LEADER` `n` | 新建标签页 |
| `LEADER` `w` | 关闭当前标签页（不询问） |
| `LEADER` `Tab` | 切换到下一个标签页 |
| `LEADER` `t` | 显示 / 隐藏标签栏 |
| `LEADER` `l` | 模糊搜索并跳转标签页 |
| `Alt` `1` … `Alt` `9` | 跳转到第 1–9 个标签页 |

### 窗格

| 快捷键 | 作用 |
| --- | --- |
| `LEADER` `\` | 左右分割（水平分屏） |
| `LEADER` `-` | 上下分割（垂直分屏） |
| `LEADER` `←` `↓` `↑` `→` | 按方向切换窗格 |
| `Ctrl+Shift+←` `↓` `↑` `→` | 按方向调整窗格大小（每次 5 格） |
| `Ctrl+Shift` `W` | 关闭当前窗格（需确认） |

### 搜索与启动器

| 快捷键 | 作用 |
| --- | --- |
| `LEADER` `/` | 搜索（默认用当前选中内容） |
| `LEADER` `p` | 打开启动菜单 |
| `LEADER` `Space` | 万能启动器（启动项 / 域 / 快捷键查询） |
| `LEADER` `k` | 清空回滚缓冲 |

### 滚动与复制模式

| 快捷键 | 作用 |
| --- | --- |
| `LEADER` `Home` | 滚动到顶部 |
| `LEADER` `End` | 滚动到底部 |
| `LEADER` `c` | 进入复制模式（类 Vim 的键盘选择） |

### 配色与连接

| 快捷键 | 作用 |
| --- | --- |
| `LEADER` `s` | 选择配色方案（列表见 `constants.COLOR_SCHEMES`） |
| `LEADER` `o` | 选择 SSH 域并连接 |

### 粘贴

| 快捷键 | 作用 |
| --- | --- |
| `LEADER` `v` | 以 Bracketed Paste 粘贴剪贴板（适用于支持该模式的编辑器） |
| `Ctrl+Shift` `V` | 直接发送剪贴板文本（`send_text`，适用于所有终端程序，远程 Vim/Helix 常用） |

## 鼠标

| 操作 | 作用 |
| --- | --- |
| 左键松开 | 把选中内容复制到剪贴板 |
| 右键按下 | 粘贴剪贴板内容 |
| `Ctrl` + 左键 | 打开光标处的超链接 |
| `Ctrl+Alt` + 左键拖动 | 移动窗口 |

## 启动器菜单

`LEADER+p` 打开，条目定义在 `config/launch_menu.lua`：

| 条目 | 说明 |
| --- | --- |
| Bash / Zsh | Unix 下的 shell |
| Pwsh / PowerShell | Windows 下的 shell |
| WSL: fedora | 进入 WSL 发行版 |
| SSH: 247-7123 / 248-60890 | 内网主机的 `ssh` 子进程连接 |

`config/ssh_domains.lua` 里配的是 `config.ssh_domains`（WezTerm 原生 SSH 域，支持多路复用），与本文件的 `launch_menu` 用途不同；两个文件都写 `config.launch_menu` 的情况已不存在。

## 关于快捷键的两点

- `LEADER` 即 `Ctrl+A`：按下后松开，再按后面的键，1.5 秒内有效。
- 配色方案和窗口栏的切换走的是 `set_config_overrides`（只影响当前窗口，不写配置文件），且每次都是先读出现有覆盖再改其中一个键，所以 `LEADER+s` 和 `LEADER+d` 不会互相覆盖。
