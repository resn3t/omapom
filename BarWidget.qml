import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "local.pomodoro"

  property string phase: "work"
  property bool running: false
  property bool settingsOpen: false
  property bool alertOpen: false
  property string alertComment: "The tomato says: step away, stretch, and let your brain simmer."
  property string alertPhase: "Break"
  property string alertPhaseDuration: ""
  property int completedWork: 0
  property real deadlineMs: 0
  property int remainingSeconds: 0
  property int phaseTotal: 0
  property bool restored: false
  property bool resetTimer: false
  property bool resetConfirmVisible: false
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy-pomodoro"

  readonly property int workDuration: Math.max(1, Number(setting("workMinutes", 25)) || 25) * 60
  readonly property int breakDuration: Math.max(1, Number(setting("breakMinutes", 5)) || 5) * 60
  readonly property int longBreakDuration: Math.max(1, Number(setting("longBreakMinutes", 15)) || 15) * 60
  readonly property int iterationTarget: Math.max(1, Number(setting("iterations", 4)) || 4)
  readonly property int phaseDuration: phase === "work" ? workDuration : (phase === "longBreak" ? longBreakDuration : breakDuration)
  readonly property string phaseLabel: phase === "work" ? "Focus session" : (phase === "longBreak" ? "Long break" : "Break")
  readonly property string phaseGlyph: phase === "work" ? "󰔛" : (phase === "longBreak" ? "󰒲" : "󰛊")
  readonly property string displayTime: formatSeconds(remainingSeconds)
  readonly property real progress: phaseTotal > 0 ? Math.max(0, Math.min(1, remainingSeconds / phaseTotal)) : 0

  function formatSeconds(value) {
    var safe = Math.max(0, Math.floor(Number(value) || 0))
    var minutes = Math.floor(safe / 60)
    var seconds = safe % 60
    return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
  }

  function reset() {
    resetTimer = false
    resetConfirmVisible = false
    running = false
    phase = "work"
    completedWork = 0
    remainingSeconds = workDuration
    phaseTotal = workDuration
    deadlineMs = 0
    saveState()
  }

  function saveState() {
    if (!restored) return
    saveTimer.restart()
  }

  function writeState() {
    stateFile.setText(JSON.stringify({
      phase: phase, running: running, completedWork: completedWork,
      deadlineMs: deadlineMs, remainingSeconds: remainingSeconds, phaseTotal: phaseTotal
    }))
  }

  function restoreState() {
    try {
      var saved = JSON.parse(stateFile.text())
      if (["work", "break", "longBreak"].indexOf(saved.phase) < 0) throw "bad phase"
      phase = saved.phase
      completedWork = Math.max(0, Number(saved.completedWork) || 0)
      phaseTotal = Math.max(1, Number(saved.phaseTotal) || phaseDuration)
      remainingSeconds = Math.max(0, Number(saved.remainingSeconds) || phaseTotal)
      if (saved.running === true && Number(saved.deadlineMs) > Date.now()) {
        deadlineMs = Number(saved.deadlineMs)
        running = true
        updateRemaining()
      } else if (saved.running === true) {
        remainingSeconds = phaseTotal
      }
    } catch (e) {
      remainingSeconds = workDuration
      phaseTotal = workDuration
    }
    restored = true
  }

  function syncDurations() {
    if (!restored) return
    var untouched = !running && remainingSeconds === phaseTotal
    if (untouched) {
      remainingSeconds = phaseDuration
      phaseTotal = phaseDuration
    } else if (remainingSeconds > phaseDuration) {
      remainingSeconds = phaseDuration
      phaseTotal = phaseDuration
      if (running) deadlineMs = Date.now() + remainingSeconds * 1000
    } else if (phaseTotal > phaseDuration) {
      phaseTotal = phaseDuration
    }
    saveState()
  }

  onPhaseDurationChanged: syncDurations()

  function startOrPause() {
    if (running) {
      updateRemaining()
      running = false
      deadlineMs = 0
    } else {
      if (remainingSeconds <= 0) remainingSeconds = phaseDuration
      deadlineMs = Date.now() + remainingSeconds * 1000
      running = true
    }
    saveState()
  }

  function openSettings() {
    alertOpen = false
    settingsOpen = false
    Qt.callLater(function() {
      if (!root.alertOpen) root.settingsOpen = true
    })
  }

  function close() {
    settingsOpen = false
    alertOpen = false
  }

  function advancePhase(continueRunning) {
    if (phase === "work") {
      completedWork += 1
      if (completedWork >= iterationTarget) {
        phase = "longBreak"
        completedWork = 0
      } else {
        phase = "break"
      }
    } else {
      phase = "work"
    }
    remainingSeconds = phaseDuration
    phaseTotal = phaseDuration
    deadlineMs = 0
    running = continueRunning === true
    if (running) deadlineMs = Date.now() + remainingSeconds * 1000
    saveState()
  }

  function updateRemaining() {
    if (!running) return
    var left = Math.ceil((deadlineMs - Date.now()) / 1000)
    if (left <= 0) {
      var finishedPhase = phase
      advancePhase(true)
      if (finishedPhase === "work") triggerBreakAlert()
      return
    }
    if (left !== remainingSeconds) {
      remainingSeconds = left
      if (left % 15 === 0) saveState()
    }
  }

  function helperPath() {
    return decodeURIComponent(String(Qt.resolvedUrl("bin/pomodoro-reminder"))
      .replace(/^file:\/\//, ""))
  }

  function fallbackComment() {
    var lines = [
      "The tomato says: step away, stretch, and let your brain simmer.",
      "Break protocol: water, shoulders down, eyes off the glowing rectangle.",
      "Omarchy suggests a tiny walk. Your future self has filed a formal request.",
      "The work goblin is fed. Go recharge before the next round.",
      "Look at something farther away than your terminal. The tomato insists."
    ]
    return lines[Math.floor((Date.now() / 1000) % lines.length)]
  }

  function triggerBreakAlert() {
    alertPhase = phase === "longBreak" ? "Long break" : "Break"
    alertPhaseDuration = formatSeconds(phaseDuration)
    alertComment = fallbackComment()
    alertOpen = true
    notifyProc.command = ["bash", helperPath(), "--notify", alertComment]
    notifyProc.running = true
    reminderProc.command = ["bash", helperPath(), "--generate", alertComment]
    reminderProc.running = true
  }

  function persistSettings(changes) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    for (var changed in changes) entry[changed] = changes[changed]
    root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function settingNumber(key, fallback) {
    return Math.max(1, Number(setting(key, fallback)) || fallback)
  }

  function adjustSetting(key, delta, fallback, maximum) {
    var next = settingNumber(key, fallback) + delta
    next = Math.max(1, Math.min(maximum, next))
    var change = {}
    change[key] = next
    persistSettings(change)
  }

  function tooltipText() {
    var state = running ? "running" : "paused"
    return phaseLabel + " · " + displayTime + " · " + state + " · " + completedWork + "/" + iterationTarget + " sessions\n"
      + "Start/pause: left-click  ·  Settings: right-click  ·  Skip: middle-click"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: {
    mkdirProc.running = true
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
    onExited: root.restoreState()
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/state.json"
    printErrors: false
  }

  Timer {
    id: saveTimer
    interval: 300
    onTriggered: root.writeState()
  }

  Timer {
    interval: 250
    running: root.running
    repeat: true
    triggeredOnStart: true
    onTriggered: root.updateRemaining()
  }

  IpcHandler {
    target: "local.pomodoro"
    function toggle(): void { root.startOrPause() }
    function skip(): void { root.advancePhase(root.running) }
    function reset(): void { root.reset() }
    function settings(): void { root.openSettings() }
    function close(): void { root.close() }
    function status(): string {
      return root.phase + " " + root.displayTime + " " + (root.running ? "running" : "paused")
        + " " + root.completedWork + "/" + root.iterationTarget
    }
  }

  Process {
    id: notifyProc
  }

  Process {
    id: reminderProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var generated = String(text).trim()
        if (generated !== "") root.alertComment = generated
      }
    }
  }

  Timer {
    id: resetConfirmTimer
    interval: 2500
    repeat: false
    onTriggered: root.resetConfirmVisible = false
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.running ? root.phaseGlyph + "  " + root.displayTime : root.phaseGlyph
    labelVisible: true
    tooltipText: root.tooltipText()
    horizontalMargin: Style.space(3.5)
    active: root.running
    activeColor: Color.accent
    useActiveColor: true
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.openSettings()
      else if (mouseButton === Qt.MiddleButton) root.advancePhase(root.running)
      else root.startOrPause()
    }
  }

  // Keep right-click settings reliable during active-state transitions.
  MouseArea {
    id: settingsMouseArea
    anchors.fill: button
    z: 10
    acceptedButtons: Qt.RightButton
    onPressed: root.openSettings()
  }

  Rectangle {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: parent.width * root.progress
    height: Math.max(2, Style.space(2))
    radius: height / 2
    color: root.running ? Color.accent : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.35)
    opacity: root.running ? 0.7 : 0.35
    enabled: false
  }

  PopupCard {
    id: settingsPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.settingsOpen
    contentWidth: settingsPopup.fittedContentWidth(Style.space(292), Style.space(360))
    contentHeight: settingsPopup.fittedContentHeight(form.implicitHeight, Style.space(330))
    onVisibleChanged: {
      if (!visible) {
        root.resetTimer = false
        root.resetConfirmVisible = false
      }
      if (visible) {}
    }

    Column {
      id: form
      anchors.fill: parent
      spacing: Style.space(6)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "󰔛  Pomodoro"
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          width: parent.width - closeButton.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
        }

        Button {
          id: closeButton
          iconText: "󰅖"
          focusable: true
          tooltipText: "Close (Esc)"
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.close()
        }
      }

      Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Minutes · use + and − to adjust"
        color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.35)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      SettingRow { id: workRow; label: "Work"; keyName: "workMinutes"; fallback: 25; maximum: 240 }
      SettingRow { label: "Break"; keyName: "breakMinutes"; fallback: 5; maximum: 120 }
      SettingRow { label: "Long break"; keyName: "longBreakMinutes"; fallback: 15; maximum: 240 }
      SettingRow { label: "Sessions"; keyName: "iterations"; fallback: 4; maximum: 12 }

      Row {
        spacing: Style.space(6)

        Button {
          iconText: "󰑓"
          tooltipText: root.resetConfirmVisible ? "Confirm?" : "Reset timer (click to confirm)"
          focusable: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          active: root.resetConfirmVisible
          onClicked: {
            if (root.resetConfirmVisible) {
              root.reset()
              root.resetConfirmVisible = false
            } else {
              root.resetTimer = true
              root.resetConfirmVisible = true
              resetConfirmTimer.start()
            }
          }
        }

        Button {
          iconText: root.running ? "󰏤" : "󰐊"
          tooltipText: root.running ? "Pause" : "Start"
          focusable: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.startOrPause()
        }

        Button {
          iconText: "󰒭"
          tooltipText: "Skip to next phase"
          focusable: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.advancePhase(root.running)
        }

        Button {
          iconText: "󰦛"
          tooltipText: "Restore default durations"
          focusable: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.persistSettings({ workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15, iterations: 4 })
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "All changes reset" + (root.resetTimer ? " · Esc closes without reset" : " · Click twice to confirm")
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        visible: root.resetConfirmVisible
      }
    }
  }

  PopupCard {
    id: alertPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.alertOpen
    centerOnBar: true
    contentWidth: alertPopup.fittedContentWidth(Style.space(340), Style.space(400))
    contentHeight: alertPopup.fittedContentHeight(alertContent.implicitHeight, Style.space(300))
    onVisibleChanged: if (!visible) root.alertOpen = false

    Column {
      id: alertContent
      anchors.fill: parent
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(12)

        Text {
          text: "🍅"
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.pixelSize: Style.font.display
          verticalAlignment: Text.AlignVCenter
        }

        Column {
          width: parent.width - Style.space(52)
          spacing: Style.space(3)

          Text {
            text: root.alertPhase + " time"
            color: root.bar ? root.bar.barForeground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            width: parent.width
            text: "Remaining: " + root.alertPhaseDuration
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            width: parent.width
            text: root.alertComment
            color: root.bar ? Qt.darker(root.bar.barForeground, 1.25) : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }
        }
      }

      PanelSeparator {
        width: parent.width
        foreground: root.bar ? root.bar.barForeground : Color.foreground
      }

      Text {
        width: parent.width
        text: "Take a real break: water, stretch, and look away from the screen."
        color: root.bar ? Qt.darker(root.bar.barForeground, 1.45) : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)

        Button {
          text: "▶ Start break"
          iconText: "󰐊"
          focusable: true
          foreground: Color.accent
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: { root.advancePhase(true); root.alertOpen = false }
        }

        Button {
          text: "⏭ Skip"
          iconText: "󰒭"
          focusable: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: { root.advancePhase(root.running); root.alertOpen = false }
        }

        Button {
          text: "Dismiss"
          iconText: "󰅖"
          focusable: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.alertOpen = false
        }
      }
    }
  }

  component SettingRow: Item {
    property string label: ""
    property string keyName: ""
    property int fallback: 1
    property int maximum: 240
    property string suffix: " min"
    property int holdDelta: 0
    width: form.width
    readonly property real gap: Style.space(6)
    height: Math.max(plusButton.implicitHeight, valueText.implicitHeight)

    Text {
      text: label
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      width: Style.space(92)
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Button {
      id: minusButton
      anchors.left: parent.left
      anchors.leftMargin: Style.space(92) + gap
      anchors.verticalCenter: parent.verticalCenter
      iconText: "󰍴"
      tooltipText: "Decrease"
      focusable: true
      foreground: root.bar ? root.bar.barForeground : Color.foreground
      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      onClicked: {
        root.adjustSetting(keyName, -1, fallback, maximum)
      }

      MouseArea {
        width: parent.width
        height: parent.height
        z: 2
        acceptedButtons: Qt.LeftButton
        onPressed: {
          holdDelta = -1
          root.adjustSetting(keyName, holdDelta, fallback, maximum)
          holdDelay.restart()
        }
        onReleased: {
          holdDelay.stop()
          repeatTimer.stop()
        }
        onCanceled: {
          holdDelay.stop()
          repeatTimer.stop()
        }
      }
    }

    Rectangle {
      id: valueText
      anchors.left: minusButton.right
      anchors.leftMargin: gap
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.darker(Color.background, 1.08)
      width: Style.space(92)
      height: Style.space(28) + Style.space(4)
      radius: Style.space(4)

      Text {
        anchors.fill: parent
        anchors.margins: Style.space(2)
        text: String(root.settingNumber(keyName, fallback))
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    Button {
      id: plusButton
      anchors.left: valueText.right
      anchors.leftMargin: gap
      anchors.verticalCenter: parent.verticalCenter
      iconText: "󰐕"
      tooltipText: "Increase"
      focusable: true
      foreground: root.bar ? root.bar.barForeground : Color.foreground
      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      onClicked: {
        root.adjustSetting(keyName, 1, fallback, maximum)
      }

      MouseArea {
        width: parent.width
        height: parent.height
        z: 2
        acceptedButtons: Qt.LeftButton
        onPressed: {
          holdDelta = 1
          root.adjustSetting(keyName, holdDelta, fallback, maximum)
          holdDelay.restart()
        }
        onReleased: {
          holdDelay.stop()
          repeatTimer.stop()
        }
        onCanceled: {
          holdDelay.stop()
          repeatTimer.stop()
        }
      }
    }

    Timer {
      id: holdDelay
      interval: 450
      repeat: false
      onTriggered: repeatTimer.start()
    }

    Timer {
      id: repeatTimer
      interval: 90
      repeat: true
      onTriggered: root.adjustSetting(keyName, holdDelta, fallback, maximum)
    }
  }
}
