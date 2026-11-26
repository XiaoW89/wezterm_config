# X11 转发排错记录：Windows + Xming → 远程容器

> 记录日期：2026-11-26
> 现象：远程容器里运行 `feh` 等 GUI 程序报
> `feh ERROR: Can't open X display. It *is* running, yeah?`
> 本地 Xming（XLaunch）正常运行、SSH 配置看起来也正常。

## 环境

| 位置 | 组件 |
| --- | --- |
| 本地 | Windows 11、Xming（`Xming :0 -multiwindow -clipboard`，监听 `0.0.0.0:6000`，无访问控制） |
| 本地 | WezTerm（`config.ssh_domains` 用原生 SSH；`config.launch_menu` 用系统 `ssh`） |
| 本地 | Windows OpenSSH 9.5p2（System32）/ Git OpenSSH 10.2 |
| 远端 | Ubuntu 20.04 Docker 容器，SSH 别名 `247-7123`（该主机本身就是容器，PID 1 为 sshd） |
| 远端 | zsh 5.8、zellij 0.42.2 |

## 结论：三个独立的坑叠在一起

### 1. Windows 端根本没有 `DISPLAY`

Windows **OpenSSH 只有在本地 `DISPLAY` 非空时才会请求 X11 转发**。Windows 默认不设置它，
所以即使 `ForwardX11 yes` 写在配置里，客户端也不会发 X11 请求。

```powershell
# 修复（用户级永久环境变量，新进程才生效）
setx DISPLAY 127.0.0.1:0.0
```

注意：**WezTerm 必须完全退出再启动**。`wezterm-gui.exe` 是在启动时继承环境的，
只重载配置不会更新它；它启动之后拉起的 `ssh` 子进程也就没有 `DISPLAY`。
（当时的现象：手动 `ssh` 可以，`LEADER+p` 的 SSH 菜单项不行，因为 WezTerm 进程早于 `setx` 启动。）

也可以用 WezTerm 配置注入环境变量（WSL 场景慎用，`127.0.0.1` 在 WSL 里到不了 Xming）：

```lua
config.set_environment_variables = { DISPLAY = "127.0.0.1:0.0" }
```

### 2. `ssh -X`（untrusted）在 Windows 上直接失败

Windows 的 OpenSSH **不带 `xauth`**。OpenSSH 9.5+ 对 untrusted X11 转发改为 fail-closed：

```
debug1: No xauth program.
Warning: untrusted X11 forwarding setup failed: xauth key data not generated
```

此时 X11 转发根本没有建立。修复方式是改用 **trusted** 转发：

```sshconfig
Host 247-7123
    HostName ...
    ForwardX11 yes
    ForwardX11Trusted yes
    User ...
    Port ...
```

两个都要写：**只写 `ForwardX11Trusted yes` 时 `forwardx11` 仍然是 `no`**，必须有 `ForwardX11 yes`。

trusted 模式在拿不到 xauth 数据时会退化为 fake auth data，所以能通。
代价是远端可以完全控制本地 X server（截屏、注入按键等），仅建议在可信网络使用。

> 验证（本地 PowerShell）：
> ```powershell
> ssh -G 247-7123 | Select-String forwardx11
> # 期望两行：forwardx11 yes / forwardx11trusted yes
> ```

### 3. zellij / tmux 的长命 server 冻结了 `DISPLAY`

这类工具的 server 进程会长期存活，**pane 继承的是 server 启动时的环境**，
不是当前 SSH 会话的环境。排查时看到：

```bash
pgrep -af 'zellij --server'
# 3086765 /usr/bin/zellij --server /tmp/zellij-1000/0.42.2/h61   ← 9 月 27 日启动
#  700333 /usr/bin/zellij --server /tmp/zellij-1000/0.42.2/h151  ← 8 月 25 日启动

tr '\0' '\n' < /proc/3086765/environ | grep -E '^(DISPLAY|XAUTHORITY)='
# （无输出：server 环境里只有 HOME、ZELLIJ=0）
```

而且 **每次 SSH 登录分配的显示号会变化**（`:10.0`、`:11.0`、`:12.0` …），
即使 server 里恰好存着一个旧值，重连后也会指向已经关闭的通道。

zellij 0.42.2 没有修改 server 环境的 action 或配置项（`zellij action --help`、
`zellij setup --dump-config` 均无 env 相关项），所以要么重启会话，要么让 pane 里的 shell 自己刷新。

## 诊断命令速查

本地（PowerShell）：

```powershell
$env:DISPLAY                                      # 应为 127.0.0.1:0.0
ssh -G 247-7123 | Select-String forwardx11        # 两项都应为 yes
ssh -Y -o BatchMode=yes 247-7123 "echo \$DISPLAY; xdpyinfo | head -3"
```

远端：

```bash
echo $DISPLAY                                     # 例如 localhost:10.0
xdpyinfo | head -3                                # vendor string: Colin Harrison → Xming

# 找出 sshd 当前活着的 X11 转发监听端口（6010-601F，十六进制 1770-177F）
awk '$4=="0A" && $2 ~ /:177[0-9A-F]$/ {print $2}' /proc/net/tcp /proc/net/tcp6

# 查看某个进程（zellij/tmux server 等）实际的环境
tr '\0' '\n' < /proc/<pid>/environ | grep -E '^(DISPLAY|XAUTHORITY)='
```

## 修复 zellij / tmux 里的 GUI 程序

### 方案 A（推荐，已验证可用）：pane 里自动刷新 `DISPLAY`

在容器的 `~/.zshrc` 末尾加：

```zsh
# >>> zellij-x11 >>>
# 长命进程（zellij/tmux server）会冻结启动时的 DISPLAY。每次出提示符时
# 从 /proc/net/tcp{,6} 找 sshd 的 X11 转发监听端口（6010-601F），重设 DISPLAY。
_x11_live_display() {
  emulate -L zsh
  local f hex st
  for f in /proc/net/tcp /proc/net/tcp6; do
    [[ -r $f ]] || continue
    while read -r _ hex _ st _; do
      [[ $st == 0A && $hex == *:177[0-9A-F] ]] || continue
      print -r -- "localhost:$(( 16#${hex##*:} - 6000 )).0"
      return 0
    done < "$f"
  done
  return 1
}
_x11_refresh_display() {
  local d
  d=$(_x11_live_display) && export DISPLAY="$d"
}
autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook precmd _x11_refresh_display
# <<< zellij-x11 <<<
```

- **新开的 pane** 自动生效；SSH 重连后显示号变了也能跟上。
- **已有的 pane** 需要在新 shell 里才会读到（开个新 pane，或手动执行下面的应急命令）。
- 前提：当前存在一条**带 X11 转发**的 SSH 连接，否则没有监听端口可探测。

### 方案 B（应急，只对当前连接有效）

在出问题的 pane 里执行（zsh / bash 均可）：

```bash
hex=$(awk '$4=="0A" && $2 ~ /^0100007F:177[0-9A-F]$/ {print $2; exit}' /proc/net/tcp)
export DISPLAY=localhost:$((16#${hex#*:} - 6000)).0
xdpyinfo | head -1     # 能输出即成功
```

### 方案 C（简单粗暴，会丢 pane）

让 zellij server 重新启动、继承当前会话的环境：

```bash
zellij kill-all-sessions            # 会结束所有 zellij 会话
# zellij delete-all-sessions -y     # 可选：连同已退出的会话记录一起清掉
zellij                              # 重新启动，新 server 带着当前 DISPLAY
```

缺点：下次重连且显示号变化后又会失效，所以长期还是用方案 A。

## WezTerm 特有的注意点

- **WezTerm 原生 SSH 没有 X11 转发实现**。`config.ssh_domains` 走的是内置 SSH 库
  （`Ssh2` / `LibSsh` 均未实现 X11 forwarding），用它连接永远无法转发 X11。
- `config.launch_menu` 里 `SSH: 247-7123` 等条目调用的是**系统 `ssh`**，
  所以 `LEADER+p` 与手敲 `ssh 247-7123` 行为一致；之前不行的唯一原因是
  WezTerm 进程本身没有 `DISPLAY`（第 1 个坑），重启即可。
- 切换配色、窗口栏用的 `set_config_overrides` 与 X11 无关，不需要改动。

## 容易踩的细节

1. **显示号不是固定的**：每次登录可能得到 `:10.0`、`:11.0`、`:12.0`，
   不要把它写死到脚本或配置里（除了方案 A 这类动态探测）。
2. **PowerShell 双引号会展开 `$DISPLAY`**：向远端发命令时用单引号，
   否则 `echo $DISPLAY` 会在本地变成空字符串，远端 zsh 收到 `DISPLAY=[]` 并报
   `no matches found`（zsh 的 glob 把 `[]` 当通配符）。
3. **`-X` 不等于 `-Y`**：Windows 上无 xauth 时 `-X` 直接失败，必须 trusted 转发。
4. **Xming 无认证**：`0.0.0.0:6000` 暴露在网络里意味着任何能访问该端口的人都能操作 X server，
   不要把它暴露到不可信网络（必要时用防火墙限制来源）。
5. **验证成功的标志**：`xdpyinfo` 的 `vendor string` 显示 `Colin Harrison`（即 Xming）。

## 最短恢复流程（下次直接照做）

1. 本地：确认 Xming 在跑；`$env:DISPLAY` 为 `127.0.0.1:0.0`。
2. 本地：`ssh -G 247-7123` 看到 `forwardx11 yes` 和 `forwardx11trusted yes`。
3. 远端：`echo $DISPLAY` + `xdpyinfo | head -3` 有输出 → 链路正常。
4. 若在 zellij/tmux 里失败：按方案 A 装钩子；或当场用方案 B 两行命令；
   实在不行再 `zellij kill-all-sessions` 重启（方案 C）。
