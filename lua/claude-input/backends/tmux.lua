-- claude-input/backends/tmux.lua
-- tmux backend for sending to Claude Code in a tmux pane

local M = {}

M.name = "tmux"

local config = {}
local detected_pane = nil

function M.setup(cfg)
  config = cfg
  detected_pane = nil
end

function M.is_available()
  -- Check if we're in tmux
  if not vim.env.TMUX then
    return false
  end

  -- Check if tmux command exists
  vim.fn.system("which tmux")
  return vim.v.shell_error == 0
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
local function find_claude_pane()
  if config.pane then
    return config.pane
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
        return pane_id
      end
    end
  end

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
