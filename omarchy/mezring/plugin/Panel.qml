import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget + popup for mezringd (the J09 / Anko ring driver).
// Talks to the daemon over its unix socket: receives state + a live event
// stream, sends per-ring mode changes and mapping edits.
// The popup is organised per ring: pick J09 or Anko, see that ring's
// status, mode, recent events and mappings.
Panel {
  id: root
  moduleName: "mez.rings"
  ipcTarget: "mez.rings"

  property var state: ({})
  property var log: []                  // most recent first, capped
  property bool daemonUp: false
  property bool showMappings: false
  property string selectedRing: "j09"
  property string editMode: ""          // mode being edited; "" = the ring's current mode
  property bool allEvents: false        // live log: only the selected ring, or both
  property string lastError: ""

  readonly property color fg: Color.popups.text
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property var rings: state.rings || ({})
  readonly property var ringNames: ["j09", "anko"]
  readonly property var ring: rings[selectedRing] || ({})
  readonly property int connectedCount: ringNames.filter(function(n) { return rings[n] && rings[n].connected }).length
  readonly property var active: state.active || ({})
  readonly property string ringMode: active[selectedRing] || ""
  readonly property var modes: state.modes || []
  readonly property var ringModes: (state.ring_modes || ({}))[selectedRing] || modes   // modes this ring takes part in
  readonly property var mappings: state.mappings || ({})
  readonly property var eventNames: state.events || ({})
  readonly property var eventHelp: state.event_help || ({})
  readonly property string activeEditMode: editMode !== "" ? editMode : ringMode
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/mezring.sock"
  readonly property var visibleLog: allEvents ? log : log.filter(function(e) { return e.ring === root.selectedRing })

  // The bar sizes the widget from the root item's implicit size.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function ringLabel(n) { return (rings[n] && rings[n].label) || n }

  function handleLine(line) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (msg.type === "state") {
      root.state = msg
      root.lastError = ""
    } else if (msg.type === "event") {
      var d = new Date(msg.t * 1000)
      var hh = String(d.getHours()).padStart(2, "0")
      var mm = String(d.getMinutes()).padStart(2, "0")
      var ss = String(d.getSeconds()).padStart(2, "0")
      var entry = {
        time: hh + ":" + mm + ":" + ss,
        ring: msg.ring,
        event: msg.event,
        actions: (msg.actions || []).join(" | ")
      }
      var next = [entry].concat(root.log)
      if (next.length > 40) next = next.slice(0, 40)
      root.log = next
    } else if (msg.type === "error") {
      root.lastError = String(msg.error || "")
    }
  }

  function send(obj) {
    if (!sock.connected) return
    sock.write(JSON.stringify(obj) + "\n")
    sock.flush()
  }

  function mappingText(ring, ev) {
    var m = root.mappings[root.activeEditMode] || {}
    var r = m[ring] || {}
    var v = r[ev]
    return v === undefined ? "" : String(v)
  }

  function fallbackText(ring, ev) {
    var c = root.mappings["common"] || {}
    var r = c[ring] || {}
    var v = r[ev]
    return v === undefined ? "" : String(v)
  }

  function setMapping(ring, ev, text) {
    if (text === root.mappingText(ring, ev)) return
    root.send({ cmd: "set", mode: root.activeEditMode, ring: ring, event: ev, action: text })
  }

  function statusText(r) {
    if (!r || !r.connected) return "disconnected"
    if (r.battery === null || r.battery === undefined) return "connected"
    return "connected · " + r.battery + "%"
  }

  function modeSummary() {
    return root.ringNames.map(function(n) { return root.ringLabel(n) + " " + (root.active[n] || "?") }).join(" · ")
  }

  Socket {
    id: sock
    path: root.socketPath
    connected: true
    parser: SplitParser {
      onRead: function(line) { root.handleLine(line) }
    }
    onConnectedChanged: {
      root.daemonUp = connected
      if (!connected) {
        root.state = ({})
        retry.start()
      }
    }
    onError: function(err) { retry.start() }
  }

  Timer {
    id: retry
    interval: 2000
    repeat: false
    onTriggered: if (!sock.connected) sock.connected = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: {
      var icon = "◎"
      if (!root.daemonUp) return icon
      if (root.setting("showCount", true) && !root.vertical && root.connectedCount > 0)
        return icon + " " + root.connectedCount
      return icon
    }
    slotSize: Style.bar.iconSlot * (root.setting("showCount", true) && !root.vertical && root.connectedCount > 0 ? 1.6 : 1)
    dimmed: !root.daemonUp || root.connectedCount === 0
    tooltipText: root.daemonUp ? root.modeSummary() : "mezringd not running"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.send({ cmd: "mode", ring: root.selectedRing, mode: "next" })
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.showMappings   // let text fields keep their keystrokes
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          title: "Rings"
          meta: root.daemonUp ? ("mezringd · " + root.modeSummary() + (root.state.uinput ? "" : " · no uinput")) : "mezringd not running"
          detail: root.daemonUp ? (root.connectedCount + " connected") : ""
          foreground: root.fg
          iconComponent: Component {
            Text {
              text: "◎"
              color: root.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.display
            }
          }
        }

        // ------------------------------------------------------------ ring selector
        PanelSeparator { foreground: root.fg }

        Column {
          width: parent.width
          spacing: Style.space(6)

          ButtonGroup {
            width: parent.width
            options: root.ringNames.map(function(n) {
              var r = root.rings[n] || {}
              return { value: n, label: (r.connected ? "● " : "○ ") + root.ringLabel(n) }
            })
            value: root.selectedRing
            foreground: root.fg
            background: Color.popups.background
            onChanged: function(v) { root.selectedRing = v; root.editMode = "" }
          }

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text {
              text: root.statusText(root.ring)
              color: root.ring.connected ? root.fg : root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: root.ring.addr || ""
              color: root.dim
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: root.ring.node ? root.ring.node.replace("/dev/", "") : ""
              color: root.dim
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        // ------------------------------------------------------------ mode (per ring)
        PanelSeparator { foreground: root.fg; visible: root.daemonUp }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.daemonUp && root.modes.length > 0

          PanelSectionHeader { text: root.ringLabel(root.selectedRing).toUpperCase() + " MODE"; foreground: root.fg }

          ButtonGroup {
            width: parent.width
            options: root.ringModes
            value: root.ringMode
            foreground: root.fg
            background: Color.popups.background
            onChanged: function(v) { root.send({ cmd: "mode", ring: root.selectedRing, mode: v }) }
          }

        }

        // ------------------------------------------------------------ live events
        PanelSeparator { foreground: root.fg; visible: root.daemonUp }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.daemonUp

          Row {
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader {
              text: "LIVE EVENTS"
              foreground: root.fg
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - Style.space(84) - allBtn.width - clearBtn.width - Style.space(16); height: 1 }
            Button {
              id: allBtn
              text: root.allEvents ? "both rings" : root.ringLabel(root.selectedRing) + " only"
              foreground: root.dim
              fontSize: Style.font.caption
              verticalPadding: 0
              onClicked: root.allEvents = !root.allEvents
            }
            Button {
              id: clearBtn
              text: "clear"
              foreground: root.dim
              fontSize: Style.font.caption
              verticalPadding: 0
              onClicked: root.log = []
            }
          }

          Text {
            visible: root.visibleLog.length === 0
            text: "press something on the " + root.ringLabel(root.selectedRing) + "…"
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.visibleLog.slice(0, 10)
            delegate: Row {
              required property var modelData
              required property int index
              width: column.width
              spacing: Style.space(8)
              opacity: index === 0 ? 1.0 : Math.max(0.35, 1.0 - index * 0.08)

              Text {
                text: modelData.time
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                text: modelData.ring
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                width: Style.space(36)
              }
              Text {
                text: modelData.event
                color: index === 0 ? Color.accent : root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                width: Style.space(80)
                elide: Text.ElideRight
              }
              Text {
                text: modelData.actions !== "" ? "→ " + modelData.actions : "→ (no action)"
                color: root.dim
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                width: column.width - Style.space(36) - Style.space(80) - Style.space(70)
                elide: Text.ElideRight
              }
            }
          }
        }

        // ------------------------------------------------------------ mappings (selected ring)
        PanelSeparator { foreground: root.fg; visible: root.daemonUp }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.daemonUp

          Row {
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader {
              text: root.ringLabel(root.selectedRing).toUpperCase() + " MAPPINGS"
              foreground: root.fg
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - Style.space(110) - toggleBtn.width - Style.space(8); height: 1 }
            Button {
              id: toggleBtn
              text: root.showMappings ? "hide" : "edit"
              foreground: root.dim
              fontSize: Style.font.caption
              verticalPadding: 0
              onClicked: root.showMappings = !root.showMappings
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.showMappings

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Editing “" + root.activeEditMode + "” for the " + root.ringLabel(root.selectedRing) + ". Actions: key:KEY_X, scroll:±N, click:left, hypr:…, wtype:…, mode:name, notify:…, or a shell command. Chain with “ | ”. Empty = fall back to common."
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            ButtonGroup {
              width: parent.width
              options: root.ringModes.concat(["common"])   // only the modes this ring takes part in
              value: root.activeEditMode
              foreground: root.fg
              background: Color.popups.background
              fontSize: Style.font.caption
              onChanged: function(v) { root.editMode = v }
            }

            Text {
              visible: root.lastError !== ""
              width: parent.width
              wrapMode: Text.WordWrap
              text: root.lastError
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            // Scrolls inside a capped height so the popup never runs off screen.
            Flickable {
              id: mapScroll
              width: parent.width
              height: Math.min(mapInner.implicitHeight, Style.space(380))
              contentWidth: width
              contentHeight: mapInner.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: mapInner
                width: mapScroll.width
                spacing: Style.space(4)

                Repeater {
                  model: root.eventNames[root.selectedRing] || []
                  delegate: Row {
                    required property var modelData
                    readonly property string ev: modelData
                    readonly property string ring: root.selectedRing
                    width: column.width
                    spacing: Style.space(8)

                    Column {
                      width: Style.space(120)
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        text: ev
                        color: root.fg
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                      }
                      Text {
                        text: (root.eventHelp[ring] || {})[ev] || ""
                        color: root.dim
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        width: parent.width
                        elide: Text.ElideRight
                      }
                    }

                    TextField {
                      id: field
                      width: column.width - Style.space(120) - Style.space(8)
                      foreground: root.fg
                      verticalPadding: Style.space(3)
                      font.pixelSize: Style.font.bodySmall
                      placeholderText: root.activeEditMode === "common" ? "(none)"
                        : (root.fallbackText(ring, ev) !== "" ? "common: " + root.fallbackText(ring, ev) : "(none)")
                      text: root.mappingText(ring, ev)
                      onEditingFinished: root.setMapping(ring, ev, text)
                      // Re-sync when the daemon pushes new state and we are not mid-edit.
                      Connections {
                        target: root
                        function onStateChanged() { if (!field.activeFocus) field.text = root.mappingText(ring, ev) }
                        function onEditModeChanged() { field.text = root.mappingText(ring, ev) }
                        function onSelectedRingChanged() { field.text = root.mappingText(ring, ev) }
                      }
                    }
                  }
                }
              }
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Saved to " + (root.state.config || "~/.config/mezring/mezring.toml") + " and applied immediately."
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
