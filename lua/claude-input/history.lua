-- claude-input/history.lua
-- Input history management

local M = {}

local config = {
  enabled = true,
  max_entries = 100,
  save_path = vim.fn.stdpath("data") .. "/claude-input-history.json",
}

local entries = {}
local loaded = false

local function load_history()
  if loaded then
    return
  end

  loaded = true

  if not config.enabled then
    return
  end

  local path = config.save_path
  local file = io.open(path, "r")
  if not file then
    return
  end

  local content = file:read("*all")
  file:close()

  if content and content ~= "" then
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
      entries = data
    end
  end
end

local function save_history()
  if not config.enabled then
    return
  end

  local path = config.save_path
  local ok, json = pcall(vim.json.encode, entries)
  if not ok then
    return
  end

  local file = io.open(path, "w")
  if not file then
    return
  end

  file:write(json)
  file:close()
end

function M.setup(cfg)
  config = vim.tbl_deep_extend("force", config, cfg or {})
  load_history()
end

function M.add(text)
  if not config.enabled or not text or text == "" then
    return
  end

  -- Don't add duplicates of the most recent entry
  if #entries > 0 and entries[#entries] == text then
    return
  end

  table.insert(entries, text)

  -- Trim to max entries
  while #entries > config.max_entries do
    table.remove(entries, 1)
  end

  save_history()
end

function M.get_all()
  return entries
end

function M.get(index)
  return entries[index]
end

function M.count()
  return #entries
end

function M.clear()
  entries = {}
  save_history()
end

return M
