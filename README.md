# Omarchy Auto Power

Battery-aware idle power management for [Omarchy](https://omarchy.org/), packaged as a shell plugin.

A half-moon / full-moon toggle lives in the top bar. Half moon means auto power
management is active; full moon means stay-awake (everything suppressed).

## What it does

| State | Icon | Behaviour |
|---|---|---|
| Auto power | half moon (U+F0F61) | Idle **suspend** after 10 min, **hibernate** after 30 min — battery only, skipped on AC power |
| Stay awake | full moon (U+F0F62) | Screensaver, lock, suspend and hibernate all suppressed |

- The toggle flips Omarchy's stay-awake indicator
  (`~/.local/state/omarchy/indicators/stay-awake`), which both this plugin's
  hypridle listeners **and** Omarchy's built-in idle shell plugin (screensaver /
  lock) respect — one click silences the whole idle chain.
- Sleep-time hooks are kept sane: lock session before sleep, DPMS back on and
  auto-theme re-applied on wake and unlock.
- **Enable** = your existing `~/.config/hypr/hypridle.conf` is backed up once
  and the plugin's managed config takes over; **disable** = the original file
  is restored and hypridle restarts. Nothing is left behind.

## Install

```bash
omarchy plugin add https://github.com/jfdnet/omarchy-auto-power.git --enable
```

## Usage

- Click the moon in the top bar (right section) to toggle stay-awake, or from a
  terminal: `touch ~/.local/state/omarchy/indicators/stay-awake`
- To change timeouts or policy, edit the plugin's own
  [`hypridle.conf`](hypridle.conf) — never the installed
  `~/.config/hypr/hypridle.conf` — then run `omarchy restart shell`.
- `Super + Space` → type away, or check status:
  `omarchy plugin list | grep auto-power`

## Requirements

- Omarchy with the Quickshell plugin system (Hyprland 0.56+)
- JetBrainsMono Nerd Font (Omarchy default) for the moon glyphs
- hypridle, omarchy-system-lock and omarchy-auto-theme (ship with Omarchy)

## Uninstall

```bash
omarchy plugin remove io.github.jfdnet.auto-power
```

## How it works

The service entry point installs a managed `hypridle.conf` on load and restarts
`hypridle.service`. The listener conditions use `condition_cmd` against the
stay-awake indicator file plus an on-shot AC-power check, so no daemon restart
is needed when toggling. On plugin unload a detached script restores the
backed-up configuration even if the shell is shutting down.

---

## 中文说明

为 [Omarchy](https://omarchy.org/) 打造的电池感知电源管理插件。

- **半月** = 自动电源管理：空闲 10 分钟待机、30 分钟休眠（仅电池，插电自动跳过）
- **满月** = 保持唤醒：屏保 / 锁屏 / 待机 / 休眠全部抑制（点击 bar 上的月亮切换）
- 切换写入 Omarchy 的 stay-awake 指示文件，屏保锁屏（shell idle 插件）与待机
  休眠（本插件）同时生效
- 启用时自动备份并接管 `~/.config/hypr/hypridle.conf`，禁用时自动还原
- 改策略请编辑插件目录内的 `hypridle.conf`，改完 `omarchy restart shell`

```bash
omarchy plugin add https://github.com/jfdnet/omarchy-auto-power.git --enable
```

## License

[MIT](LICENSE)
