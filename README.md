# Omarchy Auto Power

Battery-aware idle power management for [Omarchy](https://omarchy.org/), packaged as a shell plugin.

A half-moon / full-moon toggle lives in the top bar. Half moon means auto power
management is active; full moon means stay-awake (everything suppressed).

## What it does

| State | Icon | Behaviour |
|---|---|---|
| Auto power | half moon (U+F0F61) | Idle **suspend-then-hibernate** after 10 min — battery only, skipped on AC power and on machines without a battery |
| Stay awake | full moon (U+F0F62) | Screensaver, lock, suspend and hibernate all suppressed |

- The toggle flips Omarchy's stay-awake indicator
  (`~/.local/state/omarchy/indicators/stay-awake`), which this plugin **and**
  Omarchy's built-in idle shell plugin (screensaver / lock) respect — one click
  silences the whole idle chain.
- 100% official primitives: the plugin's service is a Quickshell `IdleMonitor`
  (the same compositor input-idle source the stock idle plugin reads), and the
  suspend→hibernate transition is systemd's built-in RTC logic. No extra
  daemons, no scripts, no state files.
- Updating from a hypridle-based version (≤ 1.1.2)? The service migrates on
  load: the managed `~/.config/hypr/hypridle.conf` is removed and
  `hypridle.service` (which stock Omarchy never shipped) is disabled. Your
  pre-install backup `hypridle.conf.omarchy-auto-power-backup`, if any, is
  left in place.

## Install

```bash
omarchy plugin add https://github.com/jfdnet/omarchy-auto-power.git --enable
```

## Usage

- Click the moon in the top bar (right section) to toggle stay-awake, or from a
  terminal: `touch ~/.local/state/omarchy/indicators/stay-awake`
- Status: `omarchy-shell auto-power status`
- To change the idle timeout, edit `idleTimeoutSeconds` in the plugin's
  [`Service.qml`](Service.qml), then run `omarchy restart shell`.

## Requirements

- Omarchy with the Quickshell plugin system (Hyprland 0.56+)
- JetBrainsMono Nerd Font (Omarchy default) for the moon glyphs

Hibernate requires the usual OS-level setup (swap + `resume=`). Without it,
`suspend-then-hibernate` simply stays suspended — nothing breaks. systemd
converts suspend to hibernate on its own schedule (low battery by default); to
pin it to a fixed delay, create `/etc/systemd/sleep.conf.d/auto-power.conf`:

```ini
[Sleep]
HibernateDelaySec=20min
```

## Uninstall

```bash
omarchy plugin remove io.github.jfdnet.auto-power
```

Nothing is left behind — v2 never takes over any config outside its own plugin
folder.

## How it works

The service runs a Quickshell `IdleMonitor` with a 600 s timeout, gated by the
stay-awake indicator. On idle it re-checks power state at trigger time
(`/sys/class/power_supply`: skip when no battery exists or any AC source is
online) and runs `systemctl suspend-then-hibernate`. Wayland idle inhibitors
(video playback, etc.) are respected, matching the stock idle plugin.

Idle chain on battery: 2.5 min screensaver → 5 min lock + blank (stock
`omarchy.idle`, configurable in `~/.config/omarchy/shell.json`) → 10 min
suspend-then-hibernate (this plugin) → hibernate via systemd RTC.

---

## 中文说明

为 [Omarchy](https://omarchy.org/) 打造的电池感知电源管理插件。

- **半月** = 自动电源管理：空闲 10 分钟 suspend-then-hibernate(仅电池;插电
  或无电池设备自动跳过)，待机后由 systemd 内置 RTC 自动转休眠(零功耗)
- **满月** = 保持唤醒：屏保 / 锁屏 / 待机 / 休眠全部抑制(点击 bar 上的月亮切换)
- 切换写入 Omarchy 的 stay-awake 指示文件，屏保锁屏(shell idle 插件)与待机
  休眠(本插件)同时生效
- 全部使用官方原语：Quickshell `IdleMonitor`(与官方 idle 插件同读
  ext-idle-notify)+ systemd 原生 suspend-then-hibernate,无脚本无轮询无状态
- 从 hypridle 旧版(≤ 1.1.2)升级：加载时自动移除受管的 hypridle 配置并停用
  hypridle 服务(stock Omarchy 本就不带)
- 改策略：编辑插件内 `Service.qml` 的 `idleTimeoutSeconds`,然后
  `omarchy restart shell`;固定待机转休眠时间可选配置
  `/etc/systemd/sleep.conf.d/auto-power.conf`(`HibernateDelaySec=20min`)

```bash
omarchy plugin add https://github.com/jfdnet/omarchy-auto-power.git --enable
```

## License

[MIT](LICENSE)
