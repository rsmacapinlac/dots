// Structural style tokens: everything the shell can be themed by that is not
// a colour. Sizes are in logical pixels, so Hyprland's per-monitor scaling
// (1.25 on eDP-1, 1 on the external) is applied by the compositor and nothing
// here needs to know which screen it is drawing on.

pragma Singleton
import QtQuick

QtObject {
    id: root

    // --------------------------------------------------------------- fonts
    // Matches kitty and the waybar config this replaces, so glyph metrics and
    // the Nerd Font icon set stay consistent across the desktop.
    readonly property string fontFamily: "BlexMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 11

    // ----------------------------------------------------------- dimensions
    readonly property int barSize: 34
    readonly property int radius: 8
    readonly property int borderWidth: 1

    // ------------------------------------------------------------- spacing
    // One scale, used everywhere, so padding stays proportional if the bar
    // grows. space(1) is the base unit; widgets ask for multiples.
    readonly property int spaceUnit: 4

    function space(multiplier) {
        return Math.round(root.spaceUnit * multiplier);
    }

    // Gap between adjacent widgets in a bar section. Deliberately wide: with no
    // separator chrome in the bar, whitespace is the only thing grouping a
    // widget's own parts against its neighbours. It therefore has to be clearly
    // larger than any spacing used *inside* a widget -- the clock's date-to-time
    // gap is space(2) -- or adjacent widgets read as one run of glyphs.
    readonly property int widgetSpacing: space(5)
    // Inset from the bar's leading and trailing screen edges.
    readonly property int barPadding: space(3)
    // Horizontal padding inside a single widget's hit area.
    readonly property int widgetPadding: space(2.5)

    // -------------------------------------------------------------- motion
    readonly property int animationFast: 120
    readonly property int animationNormal: 240
}
