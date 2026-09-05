import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  readonly property var timerService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property string barDisplayText: root.timerService ? (root.timerService.installed ? root.timerService.barText : "󰏔") : "󱎫"
  readonly property var verticalLines: {
    if (!root.timerService || !root.timerService.installed)
      return [root.barDisplayText];
    var icon = String(root.timerService.icon || "");
    var remaining = String(root.timerService.remainingText || "");
    if (remaining === "")
      return [icon !== "" ? icon : root.barDisplayText];
    var parts = remaining.split(":");
    if (parts.length < 2)
      return [icon, remaining];
    var lines = [icon];
    for (var i = 0; i < parts.length; i++) {
      lines.push(parts[i]);
      if (i < parts.length - 1)
        lines.push("-");
    }
    return lines;
  }

  function syncService() {
    if (timerService && typeof timerService.configure === "function")
      timerService.configure(settings);
    injectPanel();
  }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target)
      return;
    if ("bar" in target)
      target.bar = root.bar;
    if ("settings" in target)
      target.settings = root.settings;
    if ("anchorItem" in target)
      target.anchorItem = button;
    if ("hostWidget" in target)
      target.hostWidget = root;
    if ("timerService" in target)
      target.timerService = root.timerService;
  }

  function open() {
    if (panelLoader.item)
      panelLoader.item.open();
  }

  function close() {
    if (panelLoader.item)
      panelLoader.item.close();
  }

  function toggle() {
    if (panelLoader.item)
      panelLoader.item.toggle();
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item)
      panelLoader.item.closeForPopoutSwitch();
  }

  moduleName: "focusd"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: Qt.callLater(syncService)
  onSettingsChanged: Qt.callLater(syncService)
  onTimerServiceChanged: Qt.callLater(syncService)
  Component.onCompleted: Qt.callLater(syncService)

  Loader {
    id: panelLoader

    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.syncService);
    }
  }

  WidgetButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.barDisplayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    dimmed: root.timerService ? root.timerService.paused : false
    tooltipText: root.timerService && root.timerService.installed ? root.timerService.barTooltip : "Install Focusd"
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.LeftButton)
        root.toggle();
      else if (buttonCode === Qt.RightButton && root.timerService && !root.timerService.stopped)
        root.timerService.skip();
      else if (buttonCode === Qt.MiddleButton && root.timerService && !root.timerService.stopped)
        root.timerService.stop();
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
