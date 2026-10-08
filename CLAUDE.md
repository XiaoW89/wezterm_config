# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ This repo is public — never commit secrets or personal data

This repository is pushed to a public GitHub remote. Before any commit or push:

- **Never commit tokens, API keys, passwords, private keys, certificates, or `.env` files** — not even in a comment, an example, or a "temporary" line. If one appears in a diff, stop and flag it instead of committing. This is the hard rule.
- **Never commit personal identifiers** such as real names or email addresses.
- **Do not sanitize the author's own host entries.** This config intentionally contains internal-network SSH aliases and addresses (`247-7123`, `248-60890`, and the `122.207.79.207` hosts in `ssh_domains.lua`). The author has accepted that these are public; leave them as they are and do not replace them with placeholders.
- If a secret has already been committed, say so plainly and recommend rotating the credential — rewriting history does not un-leak it.
- Adding a `.gitignore` entry is the default fix for a file that shouldn't be tracked at all.

## What this is

A modular WezTerm terminal emulator configuration written in Lua. WezTerm reloads `wezterm.lua` automatically on save (`automatically_reload_config = true`), so changes take effect immediately without restart.

## Architecture

`wezterm.lua` is the sole entry point. It iterates a list of module names, `require()`s each one, and calls `module.apply(config)` on it. Every file under `config/` follows the same pattern: return a table `M` with an `apply(config)` function.

```
wezterm.lua          ← entry point, module loader
config/
  constants.lua      ← shared values: CONFIG_DIR, COLOR_SCHEMES list
  utils.lua          ← OS detection, command-existence helpers
  fonts.lua          ← font stack with CJK fallback, font_dirs
  appearance.lua     ← color scheme, renderer (WebGPU), fps, padding
  window.lua         ← decorations, close behavior
  tab_bar.lua        ← custom tab rendering via format-tab-title event
  cursor.lua         ← blink style/rate
  shell.lua          ← default_prog (pwsh on Windows, zsh/bash on Unix)
  keybindings.lua    ← Leader=Ctrl+A, all keys, color scheme picker
  mouse.lua          ← left-click copy, right-click paste, Ctrl+click link
  events.lua         ← toggle-tab-bar, open-uri (file:// normalization)
  advanced.lua       ← scrollback, status_update_interval, ssh_backend
  hyperlink.lua      ← custom hyperlink_rules (Windows paths, bracketed URLs)
  ssh_domains.lua    ← WezTerm-native `ssh_domains` entries (placeholder hosts)
  launch_menu.lua    ← shell + WSL + SSH entries for the launcher (wins over ssh_domains.lua)
  background.lua     ← optional background image rotator (disabled in loader)
```

To add a new setting category: create `config/foo.lua` with `M.apply(config)`, then add `"config.foo"` to the `modules` list in `wezterm.lua`.

## Key behaviors

- **Leader key**: `Ctrl+A`, 1500 ms timeout. Most custom bindings use `LEADER+<key>`.
- **Default key bindings disabled**: `disable_default_key_bindings = true` — all bindings are explicit.
- **Color scheme switching**: `LEADER+s` opens an `InputSelector` over the list in `constants.COLOR_SCHEMES`; selection applies via `set_config_overrides`, not a config write.
- **Window decorations**: default `"TITLE | RESIZE"` (visible title bar + buttons). `LEADER+d` toggles to `"NONE"` and back via `set_config_overrides`. Per-window overrides are merged (`get_config_overrides()` then mutate one key), so toggling decorations does not clobber the color scheme override and vice versa.
- **Tab title rendering**: `format-tab-title` event in `tab_bar.lua` resolves the active color scheme on every render by calling `wezterm.get_builtin_color_schemes()`.
- **Background images**: `background.lua` is fully written but commented out of the module list. Re-enable by uncommenting its entry in `wezterm.lua`.
- **SSH**: both `ssh_domains` (WezTerm-native multiplexing) and `launch_menu` SSH entries (plain `ssh` subprocess) exist side by side.
