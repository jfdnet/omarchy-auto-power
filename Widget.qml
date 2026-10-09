import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "io.github.jfdnet.auto-power"

  // stay-awake indicator: ~/.local/state/omarchy/indicators/stay-awake
  property bool stayAwake: false

  readonly property string stayAwakeFile: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"

  // JetBrainsMono Nerd Font (Material Design Icons):
  //   U+F0F61 md-moon_first_quarter (half moon, dimming  = power saving)
  //   U+F0F62 md-moon_full          (full moon, bright   = stay awake)
  // NOTE: QML "\u" escapes take exactly 4 hex digits — 5-digit codepoints
  // MUST go through String.fromCodePoint, else they silently misparse.
  readonly property string iconHalfMoon: String.fromCodePoint(0xF0F61)
  readonly property string iconFullMoon: String.fromCodePoint(0xF0F62)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!queryProc.running)
      queryProc.running = true
  }

  function toggle() {
    if (toggleProc.running)
      return

    root.stayAwake = !root.stayAwake
    toggleProc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: queryProc

    command: ["bash", "-c", "if [ -f \"" + root.stayAwakeFile + "\" ]; then echo on; else echo off; fi"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.stayAwake = String(text || "").trim() === "on"
      }
    }
  }

  Process {
    id: toggleProc

    command: ["bash", "-c",
      "mkdir -p \"$(dirname \"" + root.stayAwakeFile + "\")\"\n" +
      "if [ -f \"" + root.stayAwakeFile + "\" ]; then rm -f \"" + root.stayAwakeFile + "\"; else touch \"" + root.stayAwakeFile + "\"; fi"]

    onExited: function(exitCode) {
      root.refresh()
    }
  }

  // Poll for external changes (omarchy menu, terminal, other widgets).
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.stayAwake ? root.iconFullMoon : root.iconHalfMoon
    fontFamily: "JetBrainsMono Nerd Font"
    fontSize: Style.bar.iconFont
    horizontalMargin: 6
    tooltipText: root.stayAwake
      ? "Stay awake ON · 禁止屏保/锁屏/待机/休眠 · 点击恢复自动电源管理"
      : "Auto power ON · 空闲待机并自动转休眠 · 点击保持唤醒"
    onPressed: function() { root.toggle() }
  }
}
