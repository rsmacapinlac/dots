local function folder_exist(path)
  local attr = io.popen('ls -ld "' ..path ..'" 2>/dev/null'):read("*a")
  return attr:match("^d")
end

if folder_exist("~/Nextcloud/Apps/Obsidian/Second Brain") then
  require("obsidian").setup({
    workspaces = {
      {
        name = "Second Brain",
        path = "~/Nextcloud/Apps/obsidian/Second Brain",
      },
    },
    -- see below for full list of options 👇
  })
end
