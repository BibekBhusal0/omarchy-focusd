import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: root

  property var timerService: null
  property color foreground: Color.popups.text
  property color activeColor: Color.accent
  property string fontFamily: Style.font.family
  property bool cursorActive: false
  property int selectedAction: 0

  signal closeRequested
  signal actionHovered(int index, bool hovered)

  width: parent.width
  spacing: Style.space(16)

  Text {
    width: parent.width
    text: "Focusd Info"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Column {
    width: parent.width
    spacing: Style.space(8)

    Text {
      width: parent.width
      text: "This plugin integrates with the Focusd CLI pomodoro timer. Configure timer durations, view detailed statistics, and track your focus history using the Focusd TUI."
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Text {
      visible: root.timerService && root.timerService.focusdVersion !== ""
      width: parent.width
      text: "Version: " + (root.timerService ? root.timerService.focusdVersion : "")
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(10)

    Button {
      width: parent.width
      text: "View on GitHub"
      iconText: ""
      foreground: root.foreground
      accent: root.activeColor
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      bordered: true
      hasCursor: root.cursorActive && root.selectedAction === 0
      onHovered: function (value) {
        root.actionHovered(0, value);
      }
      onClicked: Qt.openUrlExternally("https://github.com/BibekBhusal0/focusd")
    }

    Button {
      width: parent.width
      text: "Open Settings (TUI)"
      iconText: ""
      foreground: root.foreground
      accent: root.activeColor
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      bordered: true
      hasCursor: root.cursorActive && root.selectedAction === 1
      onHovered: function (value) {
        root.actionHovered(1, value);
      }
      onClicked: Quickshell.execDetached(["focusd", "settings"])
    }

    Button {
      width: parent.width
      text: "View Stats (TUI)"
      iconText: ""
      foreground: root.foreground
      accent: root.activeColor
      fontFamily: root.fontFamily
      fontSize: Style.font.body
      bordered: true
      hasCursor: root.cursorActive && root.selectedAction === 2
      onHovered: function (value) {
        root.actionHovered(2, value);
      }
      onClicked: Quickshell.execDetached(["focusd", "stats"])
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
  }

  Text {
    width: parent.width
    text: "Press Esc to return to timer"
    color: Qt.darker(root.foreground, 1.6)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
  }
}
