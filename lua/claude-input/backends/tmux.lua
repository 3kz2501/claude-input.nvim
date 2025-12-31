-- claude-input/backends/tmux.lua
-- tmux backend for sending to Claude Code in a tmux pane

local M = {}

M.name = "tmux"

local config = {}
local detected_pane = nil
local cache = {
  tmux_available = nil,
  pane_list = nil,
  pane_list_time = 0,
}
local CACHE_TTL = 2000 -- 2 seconds

-- Forward declarations
local find_claude_pane

function M.setup(cfg)
  config = cfg
  detected_pane = nil
  cache = { tmux_available = nil, pane_list = nil, pane_list_time = 0 }
end

-- Check if tmux command exists (cached permanently)
local function has_tmux_cmd()
  if cache.tmux_available ~= nil then
    return cache.tmux_available
  end
  vim.fn.system("which tmux")
  cache.tmux_available = vim.v.shell_error == 0
  return cache.tmux_available
end

function M.is_available()
  -- Check if we're in tmux
  if not vim.env.TMUX then
    return false
  end

  -- Check if tmux command exists
  if not has_tmux_cmd() then
    return false
  end

  -- Check if Claude pane actually exists (uses cached result with TTL)
  return find_claude_pane() ~= nil
end

-- Get current pane id
local function get_current_pane()
  local result = vim.fn.system("tmux display-message -p '#{pane_id}'")
  if vim.v.shell_error == 0 then
    return vim.trim(result)
  end
  return nil
end

-- Find a pane running Claude Code
find_claude_pane = function()
  if config.pane then
    return config.pane
  end

  -- Use cached result if still valid (including nil results)
  local now = vim.loop.now()
  if cache.pane_list_time > 0 and (now - cache.pane_list_time) < CACHE_TTL then
    return cache.pane_list
  end

  local current_pane = get_current_pane()

  -- List all panes
  local result = vim.fn.system("tmux list-panes -a -F '#{pane_id}:#{pane_current_command}'")
  if vim.v.shell_error ~= 0 then
    return nil
  end

  -- Find pane running "claude" command
  for line in result:gmatch("[^\n]+") do
    local pane_id, cmd = line:match("([^:]+):(.+)")
    if pane_id and pane_id ~= current_pane then
      if cmd and cmd:lower():match("claude") then
        cache.pane_list = pane_id
        cache.pane_list_time = now
        return pane_id
      end
    end
  end

  cache.pane_list = nil
  cache.pane_list_time = now
  return nil
end

function M.send(text)
  local pane = find_claude_pane()

  if not pane then
    return false, "No Claude Code pane found. Start Claude Code in a tmux pane first."
  end

  -- Escape special characters for tmux
  -- We need to handle newlines specially - send them as Enter keys
  local lines = vim.split(text, "\n")

  for i, line in ipairs(lines) do
    -- Escape single quotes and backslashes
    line = line:gsub("\\", "\\\\")
    line = line:gsub("'", "'\\''")

    -- Send the line
    local cmd = string.format("tmux send-keys -t %s '%s'", pane, line)
    vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
      return false, "Failed to send to tmux pane"
    end

    -- Send Enter after each line except possibly the last
    if i < #lines or text:sub(-1) == "\n" then
      vim.fn.system(string.format("tmux send-keys -t %s Enter", pane))
    end
  end

  -- Always send final Enter to submit
  vim.fn.system(string.format("tmux send-keys -t %s Enter", pane))

  return true
end

function M.status()
  local current = get_current_pane()
  local pane = find_claude_pane()
  return {
    in_tmux = vim.env.TMUX ~= nil,
    current_pane = current or "unknown",
    target_pane = pane or "not found",
    configured_pane = config.pane or "auto",
  }
end

return M
