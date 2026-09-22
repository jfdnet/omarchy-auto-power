import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null

  property bool applied: false
  property bool applyPending: false
  property bool unloading: false

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string confSource: Qt.resolvedUrl("hypridle.conf").toString().replace("file://", "")
  readonly property string targetPath: homeDir + "/.config/hypr/hypridle.conf"
  readonly property string backupPath: homeDir + "/.config/hypr/hypridle.conf.omarchy-auto-power-backup"
  readonly property string stayAwakeFile: homeDir + "/.local/state/omarchy/indicators/stay-awake"

  readonly property string applyScript:
    "set -e\n" +
    "mkdir -p \"$HOME/.config/hypr\"\n" +
    "if [ ! -f \"" + root.backupPath + "\" ]; then\n" +
    "  cp \"" + root.targetPath + "\" \"" + root.backupPath + "\" 2>/dev/null || true\n" +
    "fi\n" +
    "cp \"" + root.confSource + "\" \"" + root.targetPath + "\"\n" +
    "systemctl --user restart hypridle\n"

  readonly property string restoreScript:
    "if [ -f \"" + root.backupPath + "\" ]; then\n" +
    "  mv \"" + root.backupPath + "\" \"" + root.targetPath + "\"\n" +
    "else\n" +
    "  rm -f \"" + root.targetPath + "\"\n" +
    "fi\n" +
    "systemctl --user restart hypridle\n"

  function apply() {
    if (root.unloading)
      return

    if (applyProcess.running) {
      root.applyPending = true
      return
    }

    root.applyPending = false
    applyProcess.command = ["bash", "-c", root.applyScript]
    applyProcess.running = true
  }

  Process {
    id: applyProcess

    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.log("omarchy-auto-power: " + text.trim())
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("omarchy-auto-power: " + text.trim())
      }
    }

    onExited: function(exitCode) {
      root.applied = exitCode === 0
      if (exitCode !== 0)
        console.warn("omarchy-auto-power: apply failed with exit code " + exitCode)
      if (root.applyPending && !root.unloading)
        Qt.callLater(root.apply)
    }
  }

  Component.onCompleted: Qt.callLater(root.apply)

  Component.onDestruction: {
    root.unloading = true
    // Detached so the restore survives shell teardown.
    Quickshell.execDetached(["bash", "-c", root.restoreScript])
  }
}
