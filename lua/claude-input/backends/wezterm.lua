-- claude-input/backends/wezterm.lua
-- wezterm backend for sending to Claude Code

local M = {}

M.name = "wezterm"

local config = {}
local detected_pane = nil
local wezterm_cmd = nil

function M.setup(cfg)
  config = cfg
  detected_pane = nil
  wezterm_cmd = nil
end

-- Find the wezterm CLI command (works in WSL too)
local function get_wezterm_cmd()
  if wezterm_cmd then
    return wezterm_cmd
  end

  -- Try wezterm first
  vim.fn.system("which wezterm 2>/dev/null")
  if vim.v.shell_error == 0 then
    wezterm_cmd = "wezterm"
    return wezterm_cmd
  end

  -- Try wezterm.exe (WSL)
  vim.fn.system("wezterm.exe --version 2>/dev/null")
  if vim.v.shell_error == 0 then
    wezterm_cmd = "wezterm.exe"
    return wezterm_cmd
  end

  return nil
end

function M.is_available()
  -- Check if we're in wezterm (WEZTERM_PANE or TERM_PROGRAM)
  local in_wezterm = vim.env.WEZTERM_PANE or vim.env.TERM_PROGRAM == "WezTerm"
  if not in_wezterm then
    return false
  end

  -- Check if wezterm CLI exists
  return get_wezterm_cmd() ~= nil
end

-- Find a pane running Claude Code
local function find_claude_pane()
  if config.pane_id then
    return config.pane_id
  end

  if detected_pane then
    return detected_pane
  end

  local cmd = get_wezterm_cmd()
  if not cmd then
    return nil
  end

  -- List all panes using wezterm cli
  local result = vim.fn.system(cmd .. " cli list --format json 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local ok, panes = pcall(vim.json.decode, result)
  if not ok or type(panes) ~= "table" then
    return nil
  end

  -- Find a pane with Claude Code indicators:
  -- Title contains "✳" (Claude Code uses this for conversation title)
  for _, pane in ipairs(panes) do
    local title = pane.title or ""
    if title:match("✳") then
      detected_pane = pane.pane_id
      return pane.pane_id
    end
  end

  -- Also check for "claude" in title
  for _, pane in ipairs(panes) do
    local title = (pane.title or ""):lower()
    if title:match("claude") then
      detected_pane = pane.pane_id
      return pane.pane_id
    end
  end

  return nil
end

function M.send(text)
  local cmd = get_wezterm_cmd()
  if not cmd then
    return false, "wezterm CLI not found"
  end

  local pane = find_claude_pane()

  if not pane then
    return false, "No Claude Code pane found. Start Claude Code in another wezterm pane first."
  end

  -- Escape for shell
  local escaped = text:gsub("'", "'\\''")

  -- Send the text
  local send_cmd = string.format("%s cli send-text --pane-id %s '%s'", cmd, pane, escaped)
  vim.fn.system(send_cmd)

  if vim.v.shell_error ~= 0 then
    return false, "Failed to send to wezterm pane"
  end

  -- Send Enter to submit
  vim.fn.system(string.format("%s cli send-text --pane-id %s --no-paste $'\\n'", cmd, pane))

  return true
end

function M.status()
  local cmd = get_wezterm_cmd()
  local pane = find_claude_pane()
  local in_wezterm = vim.env.WEZTERM_PANE or vim.env.TERM_PROGRAM == "WezTerm"
  return {
    in_wezterm = in_wezterm,
    wezterm_cmd = cmd or "not found",
    current_pane = vim.env.WEZTERM_PANE or "unknown",
    target_pane = pane or "not found",
    configured_pane = config.pane_id or "auto",
  }
end

return M
