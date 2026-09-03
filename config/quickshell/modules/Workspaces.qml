// Workspace indicators.
//
// Two questions, per docs/quickshell-widgets.md:
//   1. Which workspace is this screen on?
//   2. Which workspace wants attention?
//
// The widget shows exactly those two things and nothing else. Each is encoded
// three ways at once -- size, shape, and colour -- so it resolves in peripheral
// vision without being looked at. Every other workspace is an identical neutral
// dot: not a state, just scaffolding, so the pills have somewhere to sit and
// position stays readable.
//
// Every workspace is labelled, including the idle ones. The numeral is
// identity, not a state: it says *which* workspace, never how it is doing. A
// bare dot only implies its number when the row happens to be contiguous, and
// with workspaces 1, 3 and 7 alive it is unreadable -- you would be clicking
// blind. Identity is cheap here because the pill already carries both answers
// through size, shape and fill, so a muted numeral cannot be mistaken for one.
//
// What is deliberately absent is whether a workspace holds windows, which
// answers neither question: you are not on it, and it is not asking for you.
//
// An earlier version separated states by colour alone -- accent fill for
// focused, opacity 0.45 vs 1.0 for empty vs occupied, every numeral the same
// weight. The empty and occupied numerals composited about 21/255 apart, so
// the row read as undifferentiated digits and neither answer stood out. The
// lesson was that colour alone is too weak a channel, not that numerals are.
//
// Only workspaces that exist are drawn. Hyprland destroys a workspace when its
// last window closes, so "exists" already means "has windows, or is the one you
// are on" -- the widget gets that for free as presence, without spending any
// contrast to encode it.
//
// A fixed 1-5 was drawn here at first, justified as keeping the bar from
// reflowing. That was backwards: four dots for workspaces that do not exist
// answer neither question, and the row is a truer picture of the session when
// it is allowed to grow and shrink.

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "workspaces"

    // Geometry of the two shapes. The strong pill is deliberately several times
    // the dot's area: size is the channel that survives peripheral vision.
    readonly property int pillWidth: Style.space(8)
    readonly property int pillHeight: Style.space(5.5)
    // Idle slots are narrower but the same height, so the numerals sit on one
    // baseline and only the pill's width marks it out.
    readonly property int idleWidth: Style.space(5)
    readonly property int slotStrong: pillWidth
    readonly property int slotWeak: idleWidth

    // Positive ids only: Hyprland numbers special workspaces (scratchpads)
    // negatively, and those are summoned by name rather than picked out of a
    // row, so they answer neither question.
    readonly property var workspaceIds: {
        var ids = [];
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            var id = values[i].id;
            if (id > 0 && ids.indexOf(id) === -1)
                ids.push(id);
        }
        ids.sort(function (a, b) {
            return a - b;
        });
        return ids;
    }

    function workspaceById(id) {
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i];
        }
        return null;
    }

    // This Hyprland is configured in Lua, and its dispatcher parses Lua too:
    // `dispatch workspace 3` fails with a Lua syntax error. The call has to be
    // written as the Lua expression the compositor evaluates. Verified against
    // Hyprland 0.56.2 -- see docs/hyprland-startup.md.
    function focusWorkspace(id) {
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
    }

    implicitWidth: row.implicitWidth

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Style.space(1.5)

        Repeater {
            model: root.workspaceIds

            delegate: Item {
                id: slot

                required property int modelData

                readonly property var workspace: root.workspaceById(modelData)
                readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
                // Hyprland clears urgency when you arrive, so the two strong
                // states rarely coincide. If they do, focused wins: you are
                // already looking at it, which is what urgency was asking for.
                readonly property bool urgent: workspace !== null && workspace.urgent && !focused
                readonly property bool strong: focused || urgent

                // Animated so the row grows and shrinks as focus moves rather
                // than snapping, which makes the change legible as movement.
                property real slotWidth: strong ? root.slotStrong : root.slotWeak

                Behavior on slotWidth {
                    NumberAnimation {
                        duration: Style.animationNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Layout.preferredWidth: slotWidth
                Layout.preferredHeight: root.barSize
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: shape

                    anchors.centerIn: parent
                    width: slot.strong ? root.pillWidth : root.idleWidth
                    height: root.pillHeight
                    radius: height / 2

                    // Fill is reserved for the two answers. An idle slot has
                    // none; hover gives it a quiet surface so the click target
                    // is discoverable, which is an affordance, not a state.
                    color: {
                        if (slot.focused)
                            return Theme.active;
                        if (slot.urgent)
                            return Theme.urgent;
                        return mouse.containsMouse ? Theme.surfaceHover : "transparent";
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Style.animationFast
                        }
                    }
                    // A slow pulse on urgency only. Motion is the one channel
                    // that reaches you when you are not looking at the bar,
                    // which is exactly the case urgency has to survive.
                    SequentialAnimation on scale {
                        running: slot.urgent
                        loops: Animation.Infinite
                        alwaysRunToEnd: true

                        NumberAnimation {
                            to: 1.12
                            duration: 620
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: 620
                            easing.type: Easing.InOutSine
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(slot.modelData)
                        // Dark on the filled pill; muted when idle, so identity
                        // is readable without competing with the answers.
                        color: slot.strong ? Theme.barBackground : (mouse.containsMouse ? Theme.barText : Theme.barTextMuted)
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: slot.strong

                        Behavior on color {
                            ColorAnimation {
                                duration: Style.animationFast
                            }
                        }
                    }
                }

                // The hit area is the whole slot, not the dot: an 8px target is
                // not clickable in practice.
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(slot.modelData)
                }
            }
        }
    }
}
