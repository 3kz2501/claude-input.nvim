-- claude-input/backends/claudecode.lua
-- Backend for claudecode.nvim integration

local M = {}

M.name = "claudecode"

local config = {}

function M.setup(cfg)
  config = cfg
end

-- Get the terminal buffer number from claudecode.nvim
local function get_terminal_bufnr()
  local ok, terminal = pcall(require, "claudecode.terminal")
  if not ok then
    return nil
  end

  if terminal.get_active_terminal_bufnr then
    return terminal.get_active_terminal_bufnr()
  end

  return nil
end

-- Get the job channel from a terminal buffer
local function get_terminal_chan(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  -- Try to get the terminal channel
  local ok, chan = pcall(vim.api.nvim_buf_get_var, bufnr, "terminal_job_id")
  if ok and chan then
    return chan
  end

  return nil
end

-- Get the window displaying the terminal buffer
local function get_terminal_win(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  -- Find window showing this buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end

  return nil
end

function M.is_available()
  -- Check if claudecode.nvim is loaded
  local ok, _ = pcall(require, "claudecode")
  if not ok then
    return false
  end

  -- Check if ClaudeCode command exists
  local commands = vim.api.nvim_get_commands({})
  if not commands["ClaudeCode"] then
    return false
  end

  -- Only available if terminal is actually open
  local bufnr = get_terminal_bufnr()
  return bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)
end

function M.send(text)
  local bufnr = get_terminal_bufnr()

  if bufnr then
    local chan = get_terminal_chan(bufnr)
    if chan then
      -- Send the text directly to the terminal
      vim.api.nvim_chan_send(chan, text .. "\n")
      return true
    end
  end

  -- Terminal not open or channel not found
  -- Copy to clipboard and open terminal
  vim.fn.setreg("+", text)
  vim.fn.setreg("*", text)

  -- Open Claude Code terminal
  pcall(vim.cmd, "ClaudeCode")

  return true, "Text copied to clipboard. Paste in Claude terminal."
end

function M.status()
  local claudecode_loaded = pcall(require, "claudecode")
  local bufnr = get_terminal_bufnr()
  local terminal_active = bufnr and vim.api.nvim_buf_is_valid(bufnr)

  return {
    claudecode_loaded = claudecode_loaded,
    terminal_active = terminal_active,
    terminal_bufnr = bufnr,
  }
end

-- Get window to focus after sending (for claudecode, the terminal window)
function M.get_focus_win()
  local bufnr = get_terminal_bufnr()
  if bufnr then
    return get_terminal_win(bufnr)
  end
  return nil
end

return M
