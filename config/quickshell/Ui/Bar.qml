// The bar host: one layer-shell surface per monitor, three content sections.
//
// Sections are supplied as Components rather than Items because Variants
// instantiates this whole surface once per screen, and each screen needs its
// own copy of every widget. A shared Item would be reparented onto whichever
// screen mapped last, leaving the others blank.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
    id: root

    // Widget components, in display order, per section.
    property list<Component> leftWidgets
    property list<Component> centerWidgets
    property list<Component> rightWidgets

    property string position: "top"
    property bool hidden: false

    readonly property int barSize: Style.barSize
    readonly property color background: Theme.barBackground
    readonly property color foreground: Theme.barText

    // Run a command without keeping a child process attached to the shell.
    // execDetached double-forks, so a spawned terminal outliving the shell
    // cannot take the bar down with it.
    function run(command) {
        Quickshell.execDetached(["sh", "-c", command]);
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            BarSurface {
                required property var modelData

                screen: modelData
            }
        }
    }

    component BarSurface: PanelWindow {
        id: surface

        // Hiding parks the surface just past the screen edge instead of
        // unmapping it. Unmapping frees the layer surface and the entire scene
        // graph, so every reveal has to rebuild both; a negative margin leaves
        // everything mapped and costs one property change.
        exclusionMode: root.hidden ? ExclusionMode.Ignore : ExclusionMode.Auto

        margins {
            top: root.hidden && root.position === "top" ? -root.barSize : 0
            bottom: root.hidden && root.position === "bottom" ? -root.barSize : 0
        }

        anchors {
            top: root.position === "top"
            bottom: root.position === "bottom"
            left: true
            right: true
        }

        implicitHeight: root.barSize
        color: root.background
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Sections are siblings in a single row. Center is anchored to the
        // surface rather than placed between the other two, so a long window
        // title on the left cannot shove the clock off-centre.
        Item {
            anchors.fill: parent
            anchors.leftMargin: Style.barPadding
            anchors.rightMargin: Style.barPadding

            WidgetRow {
                id: leftRow
                widgets: root.leftWidgets
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            WidgetRow {
                id: centerRow
                widgets: root.centerWidgets
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            WidgetRow {
                id: rightRow
                widgets: root.rightWidgets
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component WidgetRow: RowLayout {
        id: row

        property list<Component> widgets

        spacing: Style.widgetSpacing
        height: root.barSize

        Repeater {
            model: row.widgets

            delegate: Loader {
                required property Component modelData

                sourceComponent: modelData
                Layout.alignment: Qt.AlignVCenter

                // The widget is constructed before this assignment lands, so
                // BarWidget's geometry properties fall back to Style until the
                // host is attached. See BarWidget.qml.
                onLoaded: if (item && "bar" in item)
                    item.bar = root
            }
        }
    }
}
