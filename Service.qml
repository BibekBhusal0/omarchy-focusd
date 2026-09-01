import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null

  property string status: "stopped"
  property string session: "work"
  property string sessionLabel: "Work"
  property string nextSessionLabel: "Short Break"
  property string remainingText: "25:00"
  property real progress: 0
  property string tooltipText: ""

  property bool installed: true

  property int sessionsToday: 0
  property string focusedToday: "0s"
  property string dailyGoal: ""
  property int currentStreak: 0
  property int workSessionsBeforeLongBreak: 4
  property int completedSessions: 0
  property bool hasSessionData: false

  property string focusdVersion: ""
  property bool versionChecked: false
  readonly property string requiredVersionForAddMinutes: "0.2.1"
  readonly property bool hasAddMinutesFeature: versionChecked && compareVersions(focusdVersion, requiredVersionForAddMinutes) >= 0

  readonly property bool stopped: status === "stopped"
  readonly property bool running: status === "running"
  readonly property bool paused: status === "paused"
  readonly property bool active: !stopped && (running || progress > 0)

  // Icons shown in the bar, keyed like waybar's format-icons. Customizable
  // through the plugin settings (see README).
  property var icons: defaultIcons()
  function defaultIcons() {
    return {
      "work": "",
      "work-paused": "󰏤",
      "short-break": "",
      "short-break-paused": "󰏤",
      "long-break": "󰒲",
      "long-break-paused": "󰏤"
    };
  }

  // The bar label, e.g. "󰏤 24:45".
  readonly property string barText: root.icon + (root.remainingText !== "" ? " " + root.remainingText : "")
  readonly property string barTooltip: root.tooltipText !== "" ? root.tooltipText : root.sessionLabel + " · " + root.remainingText

  function configure(settings) {
    var merged = defaultIcons();
    if (settings) {
      var custom = settings.icons || settings["format-icons"] || {};
      for (var key in custom)
        if (custom[key] !== undefined)
          merged[key] = String(custom[key]);
    }
    icons = merged;
  }

  function iconFor(key) {
    var value = icons[key];
    return value !== undefined && value !== "" ? value : "";
  }

  readonly property string icon: root.iconFor(status === "paused" ? session + "-paused" : session)

  function playOrStop() {
    if (running)
      Quickshell.execDetached(["focusd", "reset"]);
    else
      Quickshell.execDetached(["focusd", "start"]);
  }

  function togglePause() {
    if (stopped)
      return;
    Quickshell.execDetached(["focusd", "toggle"]);
  }

  function skip() {
    if (stopped)
      return;
    Quickshell.execDetached(["focusd", "next"]);
  }

  function stop() {
    if (stopped)
      return;
    Quickshell.execDetached(["focusd", "reset"]);
  }

  function addMinutes(minutes) {
    if (stopped || !hasAddMinutesFeature)
      return;
    Quickshell.execDetached(["focusd", "--add-minutes", String(minutes)]);
  }

  function compareVersions(v1, v2) {
    if (!v1 || !v2)
      return 0;
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

  function poll() {
    stateProc.running = false;
    stateProc.collected = "";
    stateProc.command = ["focusd", "status"];
    stateProc.running = true;
  }

  function checkVersion() {
    if (!root.versionChecked && !versionProc.running) {
      versionProc.running = false;
      versionProc.collected = "";
      versionProc.command = ["focusd", "--version"];
      versionProc.running = true;
    }
  }

  function parseState(raw) {
    var text = String(raw || "").trim();
    if (!text) {
      status = "stopped";
      return;
    }
    var state = {};
    try {
      state = JSON.parse(text);
    } catch (error) {
      console.warn("Focusd: ignoring invalid state:", error);
      status = "stopped";
      return;
    }
    var classes = state.class || [];
    var alt = String(state.alt || "work");
    root.status = classes.indexOf("paused") !== -1 ? "paused" : "running";
    var sessionKey = alt.replace(/-paused$/, "");
    root.session = sessionKey;
    root.sessionLabel = sessionLabelFor(sessionKey);
    root.nextSessionLabel = String(state.next_session || nextSessionLabelFor(sessionKey));
    root.remainingText = String(state.text || "");
    root.progress = Math.max(0, Math.min(1, (Number(state.percentage) || 0) / 100));
    root.tooltipText = String(state.tooltip || "");
    root.sessionsToday = Number(state.sessions_today) || 0;
    root.focusedToday = String(state.focused_today || "");
    root.dailyGoal = String(state.daily_goal || "");
    root.currentStreak = Number(state.current_streak) || 0;
    if (state.work_sessions_before_long_break !== undefined)
      root.workSessionsBeforeLongBreak = Number(state.work_sessions_before_long_break) || 4;
    if (state.completed_sessions !== undefined)
      root.completedSessions = Number(state.completed_sessions) || 0;
    root.hasSessionData = state.work_sessions_before_long_break !== undefined && state.completed_sessions !== undefined;
  }

  function sessionLabelFor(key) {
    if (key === "short-break")
      return "Short Break";
    if (key === "long-break")
      return "Long Break";
    return "Work";
  }

  function nextSessionLabelFor(key) {
    if (key === "work")
      return "Short Break";
    if (key === "short-break")
      return "Work";
    return "Work";
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.poll()
  }

  Process {
    id: stateProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function (data) {
        stateProc.collected += data + "\n";
      }
    }
    onExited: function (exitCode) {
      root.installed = exitCode === 0;
      if (exitCode === 0 && String(stateProc.collected).trim() !== "") {
        root.parseState(stateProc.collected);
      } else {
        root.status = "stopped";
      }
    }
  }

  Process {
    id: versionProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function (data) {
        versionProc.collected += data;
      }
    }
    onExited: function (exitCode) {
      if (exitCode === 0) {
        var output = String(versionProc.collected || "").trim();
        var match = output.match(/focusd\s+(\d+\.\d+\.\d+)/);
        if (match && match[1]) {
          root.focusdVersion = match[1];
          root.versionChecked = true;
        }
      }
    }
  }

  Component.onCompleted: {
    root.poll();
    root.checkVersion();
  }
}
