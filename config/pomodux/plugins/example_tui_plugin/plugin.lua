-- Example TUI Plugin for Pomodux
-- Demonstrates usage of the TUI API (since 0.4.0)

pomodux.register_plugin({
    name = "example_tui_plugin",
    version = "1.0.0",
    description = "Shows how to use Pomodux TUI API in a plugin.",
    author = "Pomodux Team"
})

-- Register a hook for timer setup (runs before timer starts)
pomodux.register_hook("timer_setup", function(event)
    -- 1. Show a notification
    pomodux.show_notification("👋 Hello from the Example TUI Plugin!")

    -- 2. List selection
    local options = {"Red", "Green", "Blue"}
    local idx, ok = pomodux.select_from_list("Pick a color", options)
    if not ok or not idx then
        pomodux.log("[example_tui_plugin] timer setup cancelled by user (Esc pressed)")
        return false -- signal cancellation to Go core
    end
    local color = options[idx]
    pomodux.show_notification("✅ You picked: " .. color)

    -- 3. Input prompt
    local name, ok = pomodux.input_prompt("Enter your name", "", "Name")
    if not ok or name == "" then
        pomodux.log("[example_tui_plugin] timer setup cancelled by user (no name entered)")
        return false -- signal cancellation to Go core
    end
    pomodux.show_notification("👋 Welcome, " .. name .. "! Timer will start now.")

    -- (Optional) Log a debug message
    pomodux.log("User selected color: " .. color .. ", name: " .. name)
end)

print("✅ Example TUI Plugin loaded!") 