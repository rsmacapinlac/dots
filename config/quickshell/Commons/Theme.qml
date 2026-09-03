// Semantic colour roles for the shell.
//
// Widgets bind to the roles here, never to Colors directly. The palette names
// what a colour *is* ("mauve"); this names what it is *for* ("the focused
// workspace"). Keeping the indirection means regenerating or swapping the
// palette never touches a widget, and a role can be retargeted in one place.

pragma Singleton
import QtQuick

QtObject {
    id: root

    // ------------------------------------------------------------------ bar
    readonly property color barBackground: Colors.base
    readonly property color barText: Colors.text
    readonly property color barTextMuted: Colors.overlay1

    // Accent for the focused workspace, and anything else that should read as
    // "this one, right now".
    readonly property color active: Colors.mauve

    // ------------------------------------------------------------- surfaces
    readonly property color surface: Colors.surface0
    readonly property color surfaceHover: Colors.surface1
    readonly property color border: Colors.surface2

    // Hyprland marks a workspace urgent when a window on it wants attention.
    readonly property color urgent: Colors.red

    // --------------------------------------------------------------- levels
    // Severity, for widgets reading a measurement rather than a state. One
    // shared ladder, so "this is getting low" looks the same wherever it
    // appears and the eye only has to learn it once.
    readonly property color good: Colors.green
    readonly property color warning: Colors.peach
    readonly property color critical: Colors.red
}
