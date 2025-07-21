-- Kimai Integration Plugin for Pomodux (clean version)
-- Provides TUI for project/activity selection and synchronizes timers with Kimai

-- Dynamically determine the directory of this script
local info = debug.getinfo(1, "S")
local script_dir = info and info.source and info.source:match("@(.*/)")
if not script_dir then
  -- Fallback: use $HOME/.config/pomodux/plugins/kimai/
  script_dir = os.getenv("HOME") .. "/.config/pomodux/plugins/kimai/"
end
package.path = package.path .. ";" .. script_dir .. "?.lua"

-- DEBUG: Print script_dir and package.path to Pomodux log
if pomodux and pomodux.log then
  pomodux.log("[kimai/plugin.lua] script_dir=" .. tostring(script_dir))
  pomodux.log("[kimai/plugin.lua] package.path=" .. tostring(package.path))
end

local json = require("json")

pomodux.register_plugin({
    name = "kimai",
    version = "0.1.0",
    description = "Integrates with Kimai time tracking API for project/activity selection",
    author = "User"
})

-- Configuration
-- Read Kimai token and URL from pass keys/kimai (first line: token, second line: URL)
local function get_kimai_credentials()
    local handle = io.popen("pass keys/kimai 2>/dev/null")
    if not handle then return nil, nil end
    local lines = {}
    for line in handle:lines() do
        table.insert(lines, line)
    end
    handle:close()
    local token = lines[1] and lines[1]:gsub("%s+", "") or nil
    local url = lines[2]
    if url then
        url = url:gsub("^url:%s*", "") -- Remove leading 'url:' and any spaces
        url = url:gsub("%s+", "")      -- Remove any remaining whitespace
    end
    return token, url
end

local env_url = os.getenv("KIMAI_URL")
local env_token = os.getenv("KIMAI_API_TOKEN") or os.getenv("KIMAI_TOKEN")
local token, url = get_kimai_credentials()
local KIMAI_URL = env_url or url or "https://your-kimai-instance.com"
local KIMAI_API_TOKEN = env_token or token or ""

-- Remove lunajson dependency and use jq for JSON parsing in shell

-- Helper: HTTP request to Kimai API (no longer parses JSON)
local function kimai_api_request(endpoint, method, data)
    method = method or "GET"
    local curl_cmd = string.format(
        "curl -s -w '\nHTTP_CODE:%%{http_code}' -X %s '%s/api/%s' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json'",
        method, KIMAI_URL, endpoint, KIMAI_API_TOKEN
    )
    if data then curl_cmd = curl_cmd .. string.format(" -d '%s'", data:gsub("'", "'\"'\"'")) end
    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()
    local response_body, http_code = result:match("^(.*)HTTP_CODE:(%d+)$")
    return response_body or result, http_code or "unknown"
end

-- Fetch projects from Kimai using bundled json.lua for parsing
local function get_projects()
    local curl_cmd = string.format(
        "curl -s -w '\nHTTP_CODE:%%{http_code}' -H 'Authorization: Bearer %s' '%s/api/projects'",
        KIMAI_API_TOKEN, KIMAI_URL
    )
    pomodux.log("Kimai: Running curl command: " .. curl_cmd)
    local handle = io.popen(curl_cmd)
    if not handle then
        pomodux.show_notification("❌ Failed to run curl for Kimai projects")
        pomodux.log("Kimai: Failed to run curl for projects")
        return {}
    end
    local result = handle:read("*a")
    handle:close()
    local response_body, http_code = result:match("^(.*)HTTP_CODE:(%d+)$")
    pomodux.log("Kimai: HTTP status code: " .. tostring(http_code))
    pomodux.log("Kimai: Raw response (first 500 chars): " .. (response_body and response_body:sub(1, 500) or "<empty>"))
    if not response_body or response_body == "" then
        pomodux.log("Kimai: Empty response body from API")
        return {}
    end
    local ok, data = pcall(json.decode, response_body)
    if not ok or type(data) ~= "table" then
        pomodux.log("Kimai: Failed to decode JSON: " .. tostring(data))
        return {}
    end
    local projects = {}
    for _, project in ipairs(data) do
        if project.id and project.name then
            table.insert(projects, {id = project.id, name = project.name})
        end
    end
    pomodux.log("Kimai: Parsed projects: " .. (#projects > 0 and table.concat((function() local t = {}; for _,p in ipairs(projects) do table.insert(t, p.name) end; return t end)(), ", ") or "<none>"))
    return projects
end

-- Fetch activities for a project using bundled json.lua for parsing, with debug logging
local function get_activities(project_id)
    local curl_cmd = string.format(
        "curl -s -w '\nHTTP_CODE:%%{http_code}' -H 'Authorization: Bearer %s' '%s/api/activities?project=%s'",
        KIMAI_API_TOKEN, KIMAI_URL, tostring(project_id)
    )
    pomodux.log("Kimai: Running curl command for activities: " .. curl_cmd)
    local handle = io.popen(curl_cmd)
    if not handle then
        pomodux.show_notification("❌ Failed to run curl for Kimai activities")
        pomodux.log("Kimai: Failed to run curl for activities")
        return {}
    end
    local result = handle:read("*a")
    handle:close()
    local response_body, http_code = result:match("^(.*)HTTP_CODE:(%d+)$")
    pomodux.log("Kimai: Activities HTTP status code: " .. tostring(http_code))
    pomodux.log("Kimai: Raw activities response (first 500 chars): " .. (response_body and response_body:sub(1, 500) or "<empty>"))
    if not response_body or response_body == "" then
        pomodux.log("Kimai: Empty activities response body from API")
        return {}
    end
    local ok, data = pcall(json.decode, response_body)
    if not ok or type(data) ~= "table" then
        pomodux.log("Kimai: Failed to decode activities JSON: " .. tostring(data))
        return {}
    end
    local activities = {}
    for _, activity in ipairs(data) do
        if activity.id and activity.name then
            table.insert(activities, {id = activity.id, name = activity.name})
        end
    end
    pomodux.log("Kimai: Parsed activities: " .. (#activities > 0 and table.concat((function() local t = {}; for _,a in ipairs(activities) do table.insert(t, a.name) end; return t end)(), ", ") or "<none>"))
    return activities
end

-- Start a timesheet in Kimai and get the ID using jq
local function start_kimai_timer(project_id, activity_id)
    local data = string.format(
        '{"begin":"%s","project":%d,"activity":%d}',
        os.date("%Y-%m-%dT%H:%M:%S"), tonumber(project_id), tonumber(activity_id)
    )
    -- Ensure no extra formatting artifacts are appended
    local curl_cmd = string.format(
        "curl -s -w '\nHTTP_CODE:%%{http_code}' -X POST '%s/api/timesheets' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d '%s'",
        KIMAI_URL, KIMAI_API_TOKEN, data
    )
    pomodux.log("Kimai: Running curl command to start timer: " .. curl_cmd)
    local handle = io.popen(curl_cmd)
    if not handle then
        pomodux.show_notification("❌ Failed to run curl for Kimai start timer")
        pomodux.log("Kimai: Failed to run curl for Kimai start timer")
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    local response_body, http_code = result:match("^(.*)HTTP_CODE:(%d+)$")
    pomodux.log("Kimai: Start timer HTTP status code: " .. tostring(http_code))
    pomodux.log("Kimai: Start timer raw response: " .. (response_body and response_body:sub(1, 500) or "<empty>"))
    if not response_body or response_body == "" then
        pomodux.show_notification("❌ Kimai API error: Empty response when starting timer")
        return nil
    end
    local ok, obj = pcall(json.decode, response_body)
    if ok and obj and obj.id then return obj.id end
    pomodux.show_notification("❌ Kimai API error: Failed to start timer")
    return nil
end

-- Plugin state (module-level)
local selected_project = nil
local selected_activity = nil
local kimai_timesheet_id = nil

-- Helper: Stop a timesheet in Kimai
local function stop_kimai_timer(timesheet_id)
    if not timesheet_id then return end
    local curl_cmd = string.format(
        "curl -s -w '\nHTTP_CODE:%%{http_code}' -X PATCH '%s/api/timesheets/%s/stop' -H 'Authorization: Bearer %s' -H 'Content-Type: application/json'",
        KIMAI_URL, tostring(timesheet_id), KIMAI_API_TOKEN
    )
    pomodux.log("Kimai: Running curl command to stop timer: " .. curl_cmd)
    local handle = io.popen(curl_cmd)
    if not handle then
        pomodux.show_notification("❌ Failed to run curl for Kimai stop timer")
        pomodux.log("Kimai: Failed to run curl for Kimai stop timer")
        return false
    end
    local result = handle:read("*a")
    handle:close()
    local response_body, http_code = result:match("^(.*)HTTP_CODE:(%d+)$")
    pomodux.log("Kimai: Stop timer HTTP status code: " .. tostring(http_code))
    pomodux.log("Kimai: Stop timer raw response: " .. (response_body and response_body:sub(1, 500) or "<empty>"))
    if http_code ~= "200" and http_code ~= "201" then
        pomodux.show_notification("❌ Kimai API error: HTTP " .. tostring(http_code) .. " (stop)")
        pomodux.log("Kimai stop failed: " .. tostring(response_body))
        return false
    end
    pomodux.log("Kimai timer stopped: " .. tostring(timesheet_id))
    return true
end

-- Main Pomodux hook: TUI runs in timer_setup
pomodux.register_hook("timer_setup", function(event)
    pomodux.log("Kimai: timer_setup hook triggered")
    -- Do NOT declare local selected_project, selected_activity here; use module-level
    ::project_selection::
    -- Project selection loop
    local projects = get_projects()
    if #projects == 0 then
        pomodux.show_notification("❌ No Kimai projects found. Cancelling timer setup.")
        if pomodux and pomodux.log then
            pomodux.log("[kimai/plugin.lua] timer setup cancelled by user (no projects)")
        end
        return false
    end
    local project_names = {}
    for _, p in ipairs(projects) do table.insert(project_names, p.name) end
    local pidx, pok = pomodux.select_from_list("Select Kimai Project", project_names)
    if not pok or not pidx then
        if pomodux and pomodux.log then
            pomodux.log("[kimai/plugin.lua] timer setup cancelled by user (Esc pressed on project selection)")
        end
        return false
    end
    selected_project = projects[pidx]
    pomodux.log("Kimai: selected project " .. selected_project.name .. " (id=" .. tostring(selected_project.id) .. ")")
    -- Activity selection loop
    while true do
        local activities = get_activities(selected_project.id)
        if #activities == 0 then
            pomodux.show_notification("❌ No Kimai activities found. Cancelling timer setup.")
            if pomodux and pomodux.log then
                pomodux.log("[kimai/plugin.lua] timer setup cancelled by user (no activities)")
            end
            return false
        end
        local activity_names = {"< Back"}
        for _, a in ipairs(activities) do table.insert(activity_names, a.name) end
        local aidx, aok = pomodux.select_from_list("Select Kimai Activity", activity_names)
        if not aok or not aidx then
            if pomodux and pomodux.log then
                pomodux.log("[kimai/plugin.lua] timer setup cancelled by user (Esc pressed on activity selection)")
            end
            return false
        end
        if aidx == 1 then
            -- < Back> selected: go back to project selection
            goto project_selection
        end
        selected_activity = activities[aidx - 1]
        pomodux.log("Kimai: selected activity " .. selected_activity.name .. " (id=" .. tostring(selected_activity.id) .. ")")
        break
    end
    -- Confirmation screen
    local confirm_msg = string.format(
        "Project: %s\nActivity: %s\n\nOK to start timer? (Esc=Cancel)",
        selected_project.name,
        selected_activity.name
    )
    local confirmed = pomodux.show_notification(confirm_msg)
    if not confirmed then
        if pomodux and pomodux.log then
            pomodux.log("[kimai/plugin.lua] timer setup cancelled by user (confirmation dialog)")
        end
        return false
    end
    pomodux.log("Kimai: user confirmed project/activity selection")
    -- Set session type to 'Project -> Activity' by returning a table
    return { session_type = selected_project.name .. " -> " .. selected_activity.name }
end)

pomodux.register_hook("timer_started", function(event)
    pomodux.log("Kimai: timer_started hook triggered")
    if not (selected_project and selected_activity) then
        pomodux.log("Kimai: timer_started with no project/activity selected")
        return
    end
    kimai_timesheet_id = start_kimai_timer(selected_project.id, selected_activity.id)
    if kimai_timesheet_id then
        pomodux.log("Kimai: started Kimai timer, timesheet id " .. tostring(kimai_timesheet_id))
    else
        pomodux.show_notification("❌ Failed to start Kimai timer.")
        pomodux.log("Kimai: failed to start Kimai timer")
    end
end)

pomodux.register_hook("timer_paused", function(event)
    pomodux.log("Kimai: timer_paused hook triggered")
    if kimai_timesheet_id then
        stop_kimai_timer(kimai_timesheet_id)
        kimai_timesheet_id = nil
    else
        pomodux.log("Kimai: timer_paused but no Kimai timer running")
    end
end)

pomodux.register_hook("timer_resumed", function(event)
    pomodux.log("Kimai: timer_resumed hook triggered")
    if selected_project and selected_activity then
        kimai_timesheet_id = start_kimai_timer(selected_project.id, selected_activity.id)
        if kimai_timesheet_id then
            pomodux.log("Kimai: resumed Kimai timer, timesheet id " .. tostring(kimai_timesheet_id))
        else
            pomodux.show_notification("❌ Failed to resume Kimai timer.")
            pomodux.log("Kimai: failed to resume Kimai timer")
        end
    else
        pomodux.log("Kimai: timer_resumed with no project/activity selected")
    end
end)

local function cleanup_kimai_state()
    pomodux.log("Kimai: cleaning up plugin state")
    selected_project = nil
    selected_activity = nil
    kimai_timesheet_id = nil
end

pomodux.register_hook("timer_cancelled", function(event)
    pomodux.log("Kimai: timer_cancelled hook triggered")
    if kimai_timesheet_id then
        stop_kimai_timer(kimai_timesheet_id)
    end
    cleanup_kimai_state()
end)

pomodux.register_hook("timer_completed", function(event)
    pomodux.log("Kimai: timer_completed hook triggered")
    if kimai_timesheet_id then
        stop_kimai_timer(kimai_timesheet_id)
    end
    cleanup_kimai_state()
end)

pomodux.register_hook("timer_stopped", function(event)
    pomodux.log("Kimai: timer_stopped hook triggered")
    if kimai_timesheet_id then
        stop_kimai_timer(kimai_timesheet_id)
    end
    cleanup_kimai_state()
end)
