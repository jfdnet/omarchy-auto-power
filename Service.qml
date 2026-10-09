import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null

  // Power policy: idle seconds before suspend-then-hibernate (battery only).
  // Edit + `omarchy restart shell` to change.
  readonly property int idleTimeoutSeconds: 600

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string stayAwakeStateDir: homeDir + "/.local/state/omarchy/indicators"
  readonly property string stayAwakeFile: stayAwakeStateDir + "/stay-awake"

  property bool stayAwake: false
  property bool stayAwakeStateLoaded: false
  property string lastEvent: "starting"
  property string lastEventAt: ""

  readonly property bool serviceEnabled: root.stayAwakeStateLoaded && !root.stayAwake

  function nowIso() {
    return new Date().toISOString()
  }

  function logEvent(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details)
    root.lastEventAt = nowIso()
    root.lastEvent = event + suffix
    console.log("omarchy auto-power " + root.lastEventAt + " " + root.lastEvent)
  }

  // The gate is evaluated at trigger time, so plugging in after the timer
  // started still cancels the suspend. stay-awake is checked again here as a
  // belt-and-braces guard next to the disabled IdleMonitor.
  readonly property string suspendGateScript:
    "if [ -f \"" + root.stayAwakeFile + "\" ]; then echo \"skip: stay-awake\"; exit 0; fi\n" +
    "has_battery=0\n" +
    "for t in /sys/class/power_supply/*/type; do\n" +
    "  [ \"$(cat \"$t\" 2>/dev/null)\" = \"Battery\" ] && has_battery=1\n" +
    "done\n" +
    "if [ \"$has_battery\" = 0 ]; then echo \"skip: no battery\"; exit 0; fi\n" +
    "for f in /sys/class/power_supply/*/online; do\n" +
    "  if [ \"$(cat \"$f\" 2>/dev/null)\" = \"1\" ]; then echo \"skip: on ac power\"; exit 0; fi\n" +
    "done\n" +
    "echo \"trigger: systemctl suspend-then-hibernate\"\n" +
    "systemctl suspend-then-hibernate\n"

  // One-time migration away from the hypridle-based versions (<= 1.1.2):
  // remove the config we managed and stop the daemon our docs asked users to
  // install (stock Omarchy does not ship hypridle). The pre-takeover backup,
  // if any, is left untouched for the user.
  readonly property string migrationScript:
    "conf=\"$HOME/.config/hypr/hypridle.conf\"\n" +
    "if [ -f \"$conf\" ] && grep -q \"MANAGED BY OMARCHY PLUGIN io.github.jfdnet.auto-power\" \"$conf\" 2>/dev/null; then\n" +
    "  rm -f \"$conf\"\n" +
    "  echo \"migration: removed managed hypridle.conf\"\n" +
    "fi\n" +
    "if systemctl --user is-active hypridle.service >/dev/null 2>&1 || systemctl --user is-enabled hypridle.service >/dev/null 2>&1; then\n" +
    "  systemctl --user disable --now hypridle.service 2>/dev/null || true\n" +
    "  echo \"migration: disabled hypridle.service\"\n" +
    "fi"

  function handleIdleChanged() {
    logEvent("idle-monitor", idleMonitor.isIdle ? "idle" : "active")
    if (!idleMonitor.isIdle)
      return

    if (!root.serviceEnabled) {
      logEvent("idle-skip", "stay-awake")
      return
    }

    logEvent("idle-fire", "evaluating power gate")
    if (!suspendProcess.running)
      suspendProcess.running = true
  }

  function statusJson() {
    return JSON.stringify({
      enabled: root.serviceEnabled,
      stayAwake: root.stayAwake,
      stayAwakeStateLoaded: root.stayAwakeStateLoaded,
      idle: idleMonitor.isIdle,
      timeout: root.idleTimeoutSeconds,
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    })
  }

  function refreshStayAwakeState() {
    if (!stayAwakeStateProbe.running)
      stayAwakeStateProbe.running = true
  }

  function applyStayAwake(value) {
    var enabled = !!value
    if (root.stayAwakeStateLoaded && root.stayAwake === enabled)
      return

    root.stayAwake = enabled
    root.stayAwakeStateLoaded = true
    logEvent("stay-awake", enabled ? "enabled" : "disabled")
  }

  IdleMonitor {
    id: idleMonitor

    // Same authority the stock omarchy.idle plugin uses: compositor input
    // idle via ext-idle-notify, Wayland inhibitors respected.
    enabled: root.serviceEnabled
    timeout: root.idleTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: root.handleIdleChanged()
  }

  Process {
    id: suspendProcess

    command: ["bash", "-c", root.suspendGateScript]

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          logEvent("gate", text.trim())
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("omarchy auto-power: " + text.trim())
      }
    }
  }

  Process {
    id: migrationProcess

    command: ["bash", "-c", root.migrationScript]

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          logEvent(text.trim())
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("omarchy auto-power migration: " + text.trim())
      }
    }
  }

  // stay-awake indicator watching, mirroring the stock omarchy.idle service:
  // probe the file, then watch its directory for changes.
  Process {
    id: stayAwakeStateProbe

    command: ["bash", "-c", "mkdir -p \"" + root.stayAwakeStateDir + "\"; if [[ -f \"" + root.stayAwakeFile + "\" ]]; then echo yes; else echo no; fi"]

    stdout: SplitParser {
      onRead: function(line) { root.applyStayAwake(String(line).trim() === "yes") }
    }

    onExited: function() { stayAwakeStateDirWatcher.reload() }
  }

  FileView {
    id: stayAwakeStateDirWatcher

    path: root.stayAwakeStateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshStayAwakeState()
  }

  Component.onCompleted: {
    logEvent("service-ready")
    refreshStayAwakeState()
    if (!migrationProcess.running)
      migrationProcess.running = true
  }

  IpcHandler {
    target: "auto-power"

    function status(): string {
      return root.statusJson()
    }

    function debug(): string {
      return root.statusJson()
    }
  }
}
