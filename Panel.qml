import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "focusd"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var timerService: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: Color.popups.text
  readonly property color activeColor: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string progressBarStyle: setting("progressBarStyle", "linear")
  property int selectedAction: 0
  property bool cursorActive: true

  property bool installed: false
  property bool checkingInstallation: true
  property bool installing: false
  property string installError: ""
  readonly property string installFailurePath: String(Quickshell.env("XDG_RUNTIME_DIR") || "") + "/focusd-panel-install.failed"

  property string currentPage: "timer"
  property bool checkingUpdate: false
  property bool updateAvailable: false

  readonly property bool resetVisible: timerService ? timerService.active : false
  readonly property bool addTimeVisible: timerService ? (timerService.active && timerService.hasAddMinutesFeature) : false

  function timerActionCount() {
    var count = 3;
    if (root.resetVisible)
      count += 1;
    if (root.addTimeVisible)
      count += 1;
    if (root.updateAvailable)
      count += 1;
    return count;
  }

  function open() {
    currentPage = "timer";
    selectedAction = 0;
    cursorActive = true;
    controller.show();
    root.checkInstallation();
    if (root.installed)
      root.checkForUpdates();
  }

  function close() {
    controller.hide();
  }

  function toggle() {
    if (opened)
      close();
    else
      open();
  }

  function actionCount() {
    if (!root.installed)
      return 1;
    if (currentPage === "info")
      return 3;
    return root.timerActionCount();
  }

  function selectAction(delta) {
    cursorActive = true;
    if (!root.installed) {
      selectedAction = 0;
      return;
    }
    if (!timerService && currentPage === "timer") {
      selectedAction = 0;
      return;
    }
    var count = root.actionCount();
    selectedAction = ((selectedAction + delta) % count + count) % count;
  }

  function activateSelected() {
    if (!root.installed) {
      root.install();
      return;
    }
    if (!timerService)
      return;
    if (currentPage === "info") {
      if (selectedAction === 0)
        Qt.openUrlExternally("https://github.com/BibekBhusal0/focusd");
      else if (selectedAction === 1)
        Quickshell.execDetached(["omarchy-launch-tui", "focusd", "settings"]);
      else if (selectedAction === 2)
        Quickshell.execDetached(["omarchy-launch-tui", "focusd", "stats"]);
      return;
    }
    var idx = 0;
    if (selectedAction === idx && !timerService.stopped) {
      timerService.togglePause();
      return;
    }
    idx++;
    if (selectedAction === idx && !timerService.stopped) {
      timerService.skip();
      return;
    }
    idx++;
    if (root.resetVisible && selectedAction === idx) {
      timerService.stop();
      return;
    }
    if (root.resetVisible)
      idx++;
    if (root.addTimeVisible && selectedAction === idx) {
      timerService.addMinutes(5);
      return;
    }
    if (root.addTimeVisible)
      idx++;
    if (selectedAction === idx) {
      root.currentPage = "info";
      root.selectedAction = 0;
      return;
    }
    if (root.updateAvailable) {
      idx++;
      if (selectedAction === idx) {
        root.updateFocusd();
        return;
      }
    }
  }

  function actionHovered(index, hovered) {
    if (!hovered)
      return;
    cursorActive = true;
    selectedAction = index;
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction);
    return false;
  }

  function checkInstallation() {
    if (whichProcess.running)
      return;
    root.checkingInstallation = true;
    whichProcess.command = ["sh", "-c", "if command -v focusd >/dev/null 2>&1; then exit 0; elif test -f \"$1\"; then cat \"$1\"; exit 2; else exit 1; fi", "sh", root.installFailurePath];
    whichProcess.running = true;
  }

  readonly property string pinnedVersion: "v0.2.13"
  readonly property string focusdSha256: "5a058eaaacf80222a3c76e55ea7a78b784b30707f4d60fdfaa1d4e63c1ab7aa1"
  readonly property string focusdDownloadUrl: "https://github.com/BibekBhusal0/focusd/releases/download/" + pinnedVersion + "/focusd-linux-x86_64"

  function installCommand() {
    return "rm -f \"$XDG_RUNTIME_DIR/focusd-panel-install.failed\"; status=0; " + "mkdir -p \"$HOME/.local/bin\" && " + "tmp=$(mktemp) && " + "curl -fsSL \"" + focusdDownloadUrl + "\" -o \"$tmp\" && " + "actual=$(sha256sum \"$tmp\" | awk '{print $1}') && " + "if [ \"$actual\" = \"" + focusdSha256 + "\" ]; then " + "  mv \"$tmp\" \"$HOME/.local/bin/focusd\" && chmod +x \"$HOME/.local/bin/focusd\"; " + "else " + "  rm -f \"$tmp\"; status=1; " + "fi " + "|| status=$?; " + "if (( status != 0 )); then printf '%s\\n' \"$status\" > \"$XDG_RUNTIME_DIR/focusd-panel-install.failed\"; fi; " + "(exit \"$status\")";
  }

  function install() {
    root.installing = true;
    root.installError = "";
    installerProcess.command = ["sh", "-c", root.installCommand()];
    installerProcess.running = true;
    installPoll.restart();
    installTimeout.restart();
  }

  function checkForUpdates() {
    if (!root.installed || root.checkingUpdate)
      return;
    root.checkingUpdate = true;
    versionCheckProcess.command = ["focusd", "--version"];
    versionCheckProcess.running = true;
  }

  function compareVersions(v1, v2) {
    var parts1 = String(v1).replace(/^v/, "").split(".");
    var parts2 = String(v2).replace(/^v/, "").split(".");
    for (var i = 0; i < Math.max(parts1.length, parts2.length); i++) {
      var p1 = Number(parts1[i]) || 0;
      var p2 = Number(parts2[i]) || 0;
      if (p1 > p2)
        return 1;
      if (p1 < p2)
        return -1;
    }
    return 0;
  }

  function updateFocusd() {
    if (!root.installed)
      return;
    if (root.isYayPackage) {
      Quickshell.execDetached(["omarchy", "launch", "floating", "terminal", "with", "presentation", "sh", "-c", "yay -S focusd && echo 'Restarting daemon...' && focusd --stop-daemon && focusd -d && echo 'Done! Press Enter to close.' && read"]);
      root.close();
      return;
    }
    updateDownloadProc.command = ["sh", "-c", "INSTALLED_PATH=$(which focusd) && " + "tmp=$(mktemp) && curl -fsSL \"" + focusdDownloadUrl + "\" -o \"$tmp\" && actual=$(sha256sum \"$tmp\" | awk '{print $1}') && " + "if [ \"$actual\" != \"" + focusdSha256 + "\" ]; then rm -f \"$tmp\" && echo 'checksum_failed'; exit 1; fi && " + "if mv \"$tmp\" \"$INSTALLED_PATH\" 2>/dev/null; then " + "  chmod +x \"$INSTALLED_PATH\" && focusd --stop-daemon && focusd -d && echo 'updated'; " + "else " + "  echo \"needs_sudo $tmp\"; " + "fi"];
    updateDownloadProc.running = true;
    root.close();
  }

  Component.onCompleted: root.checkInstallation()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function (dx, dy) {
        if (dx !== 0)
          root.selectAction(dx);
        else if (dy !== 0)
          root.selectAction(dy);
      }
      onActivateRequested: root.activateSelected()
      onCloseRequested: {
        if (root.currentPage === "info") {
          root.currentPage = "timer";
          root.selectedAction = 0;
        } else {
          root.close();
        }
      }
      onTabRequested: function (direction) {
        root.switchPanel(direction);
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(18)

        Column {
          visible: !root.installed && !root.checkingInstallation
          width: parent.width
          spacing: Style.space(16)

          Item {
            width: parent.width
            implicitHeight: Style.space(64)

            Text {
              anchors.centerIn: parent
              text: "󱎫"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display + Style.space(12)
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: "Focusd is not installed."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              text: "Install the pomodoro daemon this widget controls."
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }

          Button {
            width: parent.width
            text: root.installing ? "Installing focusd…" : "Install focusd"
            iconText: root.installing ? "" : "󰏔"
            iconSpinning: root.installing
            fontFamily: root.fontFamily
            fontSize: Style.font.body
            iconSize: Style.font.icon
            foreground: root.foreground
            accent: root.activeColor
            verticalPadding: Style.space(14)
            bordered: true
            selected: true
            hasCursor: root.cursorActive && root.selectedAction === 0
            enabled: !root.installing
            onHovered: function (hovered) {
              if (hovered) {
                root.cursorActive = true;
                root.selectedAction = 0;
              }
            }
            onClicked: root.install()
          }

          Text {
            visible: root.installError !== ""
            width: parent.width
            text: root.installError
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Loader {
          id: timerPageLoader
          width: parent.width
          active: root.installed && root.currentPage === "timer"
          visible: active
          source: "TimerPage.qml"
          onLoaded: {
            item.timerService = Qt.binding(function () {
              return root.timerService;
            });
            item.foreground = Qt.binding(function () {
              return root.foreground;
            });
            item.activeColor = Qt.binding(function () {
              return root.activeColor;
            });
            item.fontFamily = Qt.binding(function () {
              return root.fontFamily;
            });
            item.progressBarStyle = Qt.binding(function () {
              return root.progressBarStyle;
            });
            item.updateAvailable = Qt.binding(function () {
              return root.updateAvailable;
            });
            item.cursorActive = Qt.binding(function () {
              return root.cursorActive;
            });
            item.selectedAction = Qt.binding(function () {
              return root.selectedAction;
            });
            item.resetVisible = Qt.binding(function () {
              return root.resetVisible;
            });
            item.addTimeVisible = Qt.binding(function () {
              return root.addTimeVisible;
            });
            item.hasSessionData = Qt.binding(function () {
              return root.timerService ? root.timerService.hasSessionData : false;
            });
            item.totalActionCount = Qt.binding(function () {
              return root.timerActionCount();
            });
            item.updateRequested.connect(root.updateFocusd);
            item.infoRequested.connect(function () {
              root.currentPage = "info";
              root.selectedAction = 0;
            });
            item.actionHovered.connect(root.actionHovered);
          }
        }

        Loader {
          id: infoPageLoader
          width: parent.width
          active: root.installed && root.currentPage === "info"
          visible: active
          source: "InfoPage.qml"
          onLoaded: {
            item.timerService = Qt.binding(function () {
              return root.timerService;
            });
            item.foreground = Qt.binding(function () {
              return root.foreground;
            });
            item.activeColor = Qt.binding(function () {
              return root.activeColor;
            });
            item.fontFamily = Qt.binding(function () {
              return root.fontFamily;
            });
            item.cursorActive = Qt.binding(function () {
              return root.cursorActive;
            });
            item.selectedAction = Qt.binding(function () {
              return root.selectedAction;
            });
            item.actionHovered.connect(root.actionHovered);
          }
        }
      }
    }
  }

  Process {
    id: whichProcess
    stdout: StdioCollector {
      id: whichOutput
      waitForEnd: true
    }
    onExited: function (exitCode) {
      root.checkingInstallation = false;
      root.installed = exitCode === 0;
      if (root.installed) {
        root.installing = false;
        installPoll.stop();
        installTimeout.stop();
        Qt.callLater(root.checkForUpdates);
      } else if (exitCode === 2 && root.installing) {
        root.installing = false;
        installPoll.stop();
        installTimeout.stop();
        var exitStatus = String(whichOutput.text || "").trim();
        root.installError = exitStatus === "130" ? "Installation was canceled." : exitStatus === "1" ? "Checksum verification failed. The download may be corrupted." : "Installation did not finish. Check the Omarchy terminal and try again.";
      } else {
        root.installError = "";
      }
    }
  }

  Process {
    id: installerProcess
  }

  Process {
    id: versionCheckProcess
    stdout: StdioCollector {
      id: versionCheckOutput
      waitForEnd: true
    }
    onExited: function (exitCode) {
      root.checkingUpdate = false;
      if (exitCode === 0) {
        var output = String(versionCheckOutput.text || "").trim();
        var match = output.match(/focusd\s+(\d+\.\d+\.\d+)/);
        if (match && match[1]) {
          var installedVersion = "v" + match[1];
          root.updateAvailable = root.compareVersions(root.pinnedVersion, installedVersion) > 0;
        }
      }
    }
  }

  Process {
    id: yayCheckProcess
    stdout: SplitParser {
      onRead: function (data) {}
    }
    onExited: function (exitCode) {
      root.isYayPackage = exitCode === 0;
    }
  }

  Process {
    id: updateDownloadProc
    stdout: SplitParser {
      onRead: function (data) {
        var msg = String(data || "").trim();
        if (msg === "updated")
          root.checkForUpdates();
        else if (msg.indexOf("needs_sudo") === 0) {
          var tmpPath = msg.split(" ")[1];
          var sudoCmd = "INSTALLED_PATH=$(which focusd) && " + "sudo mv \"" + tmpPath + "\" \"$INSTALLED_PATH\" && sudo chmod +x \"$INSTALLED_PATH\" && " + "focusd --stop-daemon && focusd -d && echo 'Done! Press Enter to close.' && read";
          Quickshell.execDetached(["omarchy", "launch", "floating", "terminal", "with", "presentation", "sh", "-c", sudoCmd]);
        }
      }
    }
  }

  Timer {
    id: installPoll
    interval: 1000
    repeat: true
    running: root.installing && !root.installed
    onTriggered: root.checkInstallation()
  }

  Timer {
    id: installTimeout
    interval: 300000
    onTriggered: {
      if (!root.installing)
        return;
      root.installing = false;
      installPoll.stop();
      root.installError = "Installation is still waiting. Check the Omarchy terminal and try again.";
    }
  }
}
