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

  readonly property bool stopVisible: timerService ? timerService.active : false

  function open() {
    selectedAction = 0
    cursorActive = true
    controller.show()
    root.checkInstallation()
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function actionCount() {
    if (!root.installed) return 1
    return (!!root.timerService && !root.timerService.stopped) ? 3 : 2
  }

  function selectAction(delta) {
    cursorActive = true
    if (!root.installed) {
      selectedAction = 0
      return
    }
    if (!timerService) {
      selectedAction = 0
      return
    }
    var count = root.actionCount()
    selectedAction = ((selectedAction + delta) % count + count) % count
  }

  function activateSelected() {
    if (!root.installed) {
      root.install()
      return
    }
    if (!timerService) return
    if (selectedAction === 0 && !timerService.stopped) timerService.togglePause()
    else if (selectedAction === 1 && !timerService.stopped) timerService.skip()
    else if (selectedAction === 2 && root.stopVisible) timerService.stop()
  }

  function actionHovered(index, hovered) {
    if (!hovered) return
    cursorActive = true
    selectedAction = index
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function checkInstallation() {
    if (whichProcess.running) return
    root.checkingInstallation = true
    whichProcess.command = [
      "sh",
      "-c",
      "if command -v focusd >/dev/null 2>&1; then exit 0; elif test -f \"$1\"; then cat \"$1\"; exit 2; else exit 1; fi",
      "sh",
      root.installFailurePath
    ]
    whichProcess.running = true
  }

  readonly property string focusdVersion: "v0.2.0"
  readonly property string focusdSha256: "13538979d894f5b8f665a0a392598a78e94078939fec478246329b37521a8595"
  readonly property string focusdDownloadUrl:
    "https://github.com/BibekBhusal0/focusd/releases/download/" + focusdVersion + "/focusd-linux-x86_64"

  function installCommand() {
    return "rm -f \"$XDG_RUNTIME_DIR/focusd-panel-install.failed\"; status=0; " +
      "mkdir -p \"$HOME/.local/bin\" && " +
      "tmp=$(mktemp) && " +
      "curl -fsSL \"" + focusdDownloadUrl + "\" -o \"$tmp\" && " +
      "actual=$(sha256sum \"$tmp\" | awk '{print $1}') && " +
      "if [ \"$actual\" = \"" + focusdSha256 + "\" ]; then " +
      "  mv \"$tmp\" \"$HOME/.local/bin/focusd\" && chmod +x \"$HOME/.local/bin/focusd\"; " +
      "else " +
      "  rm -f \"$tmp\"; status=1; " +
      "fi " +
      "|| status=$?; " +
      "if (( status != 0 )); then printf '%s\\n' \"$status\" > \"$XDG_RUNTIME_DIR/focusd-panel-install.failed\"; fi; " +
      "(exit \"$status\")"
  }

  function install() {
    root.installing = true
    root.installError = ""
    installerProcess.command = ["sh", "-c", root.installCommand()]
    installerProcess.running = true
    installPoll.restart()
    installTimeout.restart()
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

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.selectAction(dx)
        else if (dy !== 0) root.selectAction(dy)
      }
      onActivateRequested: root.activateSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

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
            text: root.installing
              ? "Installing focusd…"
              : "Install focusd"
            iconText: root.installing ? "" : "󰏔"
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
            onHovered: function(hovered) {
              if (hovered) {
                root.cursorActive = true
                root.selectedAction = 0
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

        LinearFace {
          width: parent.width
          visible: root.installed && root.progressBarStyle !== "circular"
        }

        CircularFace {
          width: parent.width
          visible: root.installed && root.progressBarStyle === "circular"
        }

        Column {
          visible: root.installed
          width: parent.width
          spacing: Style.space(10)

          Row {
            width: parent.width
            spacing: Style.space(20)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { icon: ""; label: "Streak"; value: (root.timerService ? root.timerService.currentStreak : 0) + "d" }
              InfoPair { icon: "󰓾"; label: "Goal"; value: root.timerService ? root.timerService.dailyGoal : "—" }
            }

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { icon: ""; label: "Sessions today"; value: root.timerService ? String(root.timerService.sessionsToday) : "0" }
              InfoPair { icon: "󰔟"; label: "Focused today"; value: root.timerService ? root.timerService.focusedToday : "—" }
            }
          }
        }

        Row {
          id: actions
          visible: root.installed
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(10)
          readonly property real buttonSize: Style.space(42)

          Button {
            id: pauseButton
            implicitWidth: actions.buttonSize
            implicitHeight: actions.buttonSize
            width: actions.buttonSize
            height: actions.buttonSize
            iconText: root.timerService && root.timerService.paused ? "" : "󰏤"
            tooltipText: root.timerService && root.timerService.paused
              ? "Resume session"
              : "Pause session"
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.iconLarge
            horizontalPadding: 0
            verticalPadding: 0
            enabled: !!root.timerService && !root.timerService.stopped
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 0
            onHovered: function(value) { root.actionHovered(0, value) }
            onClicked: if (root.timerService) root.timerService.togglePause()
          }

          Button {
            id: skipButton
            implicitWidth: actions.buttonSize
            implicitHeight: actions.buttonSize
            width: actions.buttonSize
            height: actions.buttonSize
            iconText: "󰒭"
            tooltipText: "Skip to " + (root.timerService ? root.timerService.nextSessionLabel : "next session")
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.iconLarge
            horizontalPadding: 0
            verticalPadding: 0
            enabled: !!root.timerService && !root.timerService.stopped
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 1
            onHovered: function(value) { root.actionHovered(1, value) }
            onClicked: if (root.timerService) root.timerService.skip()
          }

          Button {
            id: stopButton
            implicitWidth: actions.buttonSize
            implicitHeight: actions.buttonSize
            width: actions.buttonSize
            height: actions.buttonSize
            iconText: "󰛉"
            tooltipText: "Stop session"
            foreground: root.foreground
            accent: root.activeColor
            iconSize: Style.font.iconLarge
            horizontalPadding: 0
            verticalPadding: 0
            visible: !!root.timerService && !root.timerService.stopped
            enabled: !!root.timerService && !root.timerService.stopped
            opacity: enabled ? 1 : 0.35
            hasCursor: root.cursorActive && root.selectedAction === 2
            onHovered: function(value) { root.actionHovered(2, value) }
            onClicked: if (root.timerService) root.timerService.stop()
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string icon: ""
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    Text {
      id: iconText
      visible: icon !== ""
      text: icon
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[1].implicitWidth - parent.children[3].implicitWidth - parent.spacing * 3); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component LinearFace: Column {
    width: parent.width
    spacing: Style.space(12)

    Item {
      width: parent.width
      implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroTime.implicitHeight)

      Text {
        id: heroIcon
        text: root.timerService ? root.timerService.icon : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: heroLabels
        anchors.left: heroIcon.right
        anchors.leftMargin: Style.space(14)
        anchors.right: heroTime.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          text: root.timerService ? root.timerService.sessionLabel : "Work"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          text: (root.timerService && root.timerService.paused ? "Paused"
                : root.timerService && root.timerService.running ? "Running"
                : "Stopped").toUpperCase()
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
          elide: Text.ElideRight
          width: parent.width
        }
      }

      Text {
        id: heroTime
        text: root.timerService ? root.timerService.remainingText : "25:00"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.displayLarge
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      width: parent.width
      implicitHeight: Style.space(8)

      Rectangle {
        id: progressTrack
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
      }

      Rectangle {
        id: progressFill
        anchors.left: progressTrack.left
        anchors.verticalCenter: progressTrack.verticalCenter
        height: progressTrack.height
        radius: progressTrack.radius
        color: root.foreground
        width: Math.max(progressTrack.height, progressTrack.width * (root.timerService ? root.timerService.progress : 0))

        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      }
    }
  }

  component CircularFace: Item {
    width: parent.width
    implicitHeight: Style.space(180)

    CircularProgress {
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height)
      height: width
      progress: root.timerService ? root.timerService.progress : 0
      trackColor: Color.muted
      fillColor: root.foreground
      strokeWidth: Math.max(5, Style.spaceReal(7))
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(5)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.timerService ? root.timerService.remainingText : "25:00"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Math.round(Style.font.displayLarge * 1.7)
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.timerService ? root.timerService.sessionLabel : "Work"
        color: root.activeColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
      }
    }
  }

  Process {
    id: whichProcess
    stdout: StdioCollector { id: whichOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.checkingInstallation = false
      root.installed = exitCode === 0
      if (root.installed) {
        root.installing = false
        installPoll.stop()
        installTimeout.stop()
      } else if (exitCode === 2 && root.installing) {
        root.installing = false
        installPoll.stop()
        installTimeout.stop()
        var exitStatus = String(whichOutput.text || "").trim()
        root.installError = exitStatus === "130"
          ? "Installation was canceled."
          : exitStatus === "1"
            ? "Checksum verification failed. The download may be corrupted."
            : "Installation did not finish. Check the Omarchy terminal and try again."
      } else {
        root.installError = ""
      }
    }
  }

  Process { id: installerProcess }

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
      if (!root.installing) return
      root.installing = false
      installPoll.stop()
      root.installError = "Installation is still waiting. Check the Omarchy terminal and try again."
    }
  }
}
