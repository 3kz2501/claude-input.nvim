-- claude-input/ui.lua
-- Floating window UI for Claude input

local M = {}

local config = {}
local state = {
  buf = nil,
  win = nil,
  on_send = nil,
  on_cancel = nil,
  history = nil,
  history_index = nil,
  original_win = nil,
}

function M.setup(cfg)
  config = cfg
end

local function get_window_dimensions()
  local width = config.window.width
  local height = config.window.height

  -- Convert percentage to actual size
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  if width <= 1 then
    width = math.floor(editor_width * width)
  end
  if height <= 1 then
    height = math.floor(editor_height * height)
  end

  -- Ensure minimum size
  width = math.max(width, 40)
  height = math.max(height, 5)

  -- Calculate position (centered)
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

  return {
    width = width,
    height = height,
    row = row,
    col = col,
  }
end

local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].swapfile = false

  return buf
end

local function create_window(buf)
  local dim = get_window_dimensions()

  local win_opts = {
    relative = "editor",
    width = dim.width,
    height = dim.height,
    row = dim.row,
    col = dim.col,
    style = "minimal",
    border = config.window.border,
    title = config.window.title,
    title_pos = config.window.title_pos,
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Window options
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].cursorline = true

  return win
end

local function get_buffer_content()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return ""
  end

  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  return table.concat(lines, "\n")
end

local function set_buffer_content(text)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = vim.split(text, "\n")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
end

local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  state.buf = nil
  state.win = nil
  state.history_index = nil

  -- Return focus to original window
  if state.original_win and vim.api.nvim_win_is_valid(state.original_win) then
    vim.api.nvim_set_current_win(state.original_win)
  end

  state.original_win = nil
end

local function do_send()
  local text = get_buffer_content()
  text = vim.trim(text)

  if text ~= "" and state.on_send then
    state.on_send(text)
  end

  close_window()
end

local function do_send_stay()
  local text = get_buffer_content()
  text = vim.trim(text)

  if text ~= "" and state.on_send then
    state.on_send(text)
    -- Clear buffer but keep window open
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "" })
    vim.notify("Sent!", vim.log.levels.INFO)
  end
end

local function do_cancel()
  if state.on_cancel then
    state.on_cancel()
  end

  close_window()
end

local function history_prev()
  if not state.history then
    return
  end

  local entries = state.history.get_all()
  if #entries == 0 then
    return
  end

  -- Save current content if at the end
  if state.history_index == nil then
    state.history_current = get_buffer_content()
    state.history_index = #entries
  elseif state.history_index > 1 then
    state.history_index = state.history_index - 1
  else
    return
  end

  set_buffer_content(entries[state.history_index])
end

local function history_next()
  if not state.history or state.history_index == nil then
    return
  end

  local entries = state.history.get_all()

  if state.history_index < #entries then
    state.history_index = state.history_index + 1
    set_buffer_content(entries[state.history_index])
  else
    -- Back to current input
    state.history_index = nil
    set_buffer_content(state.history_current or "")
  end
end

local function setup_keymaps(buf)
  local opts = { buffer = buf, silent = true }

  -- Normal mode: send
  vim.keymap.set("n", config.keymaps.send, do_send, vim.tbl_extend("force", opts, {
    desc = "Send to Claude",
  }))

  -- Normal mode: send but stay
  vim.keymap.set("n", config.keymaps.send_stay, do_send_stay, vim.tbl_extend("force", opts, {
    desc = "Send to Claude (keep window)",
  }))

  -- Normal mode: cancel
  vim.keymap.set("n", config.keymaps.cancel, do_cancel, vim.tbl_extend("force", opts, {
    desc = "Cancel",
  }))

  -- Also Esc to cancel in normal mode
  vim.keymap.set("n", "<Esc>", do_cancel, vim.tbl_extend("force", opts, {
    desc = "Cancel",
  }))

  -- History navigation (normal mode)
  vim.keymap.set("n", config.keymaps.history_prev, history_prev, vim.tbl_extend("force", opts, {
    desc = "Previous history",
  }))

  vim.keymap.set("n", config.keymaps.history_next, history_next, vim.tbl_extend("force", opts, {
    desc = "Next history",
  }))

  -- Help hint
  vim.keymap.set("n", "?", function()
    vim.notify(
      "Claude Input:\n"
        .. "  <CR>     - Send and close\n"
        .. "  <C-s>    - Send and keep open\n"
        .. "  q/<Esc>  - Cancel\n"
        .. "  <C-p>    - Previous history\n"
        .. "  <C-n>    - Next history\n"
        .. "  i/a/o    - Insert mode (normal vim)",
      vim.log.levels.INFO
    )
  end, vim.tbl_extend("force", opts, { desc = "Show help" }))
end

function M.open(opts)
  opts = opts or {}

  -- Save original window
  state.original_win = vim.api.nvim_get_current_win()

  -- Store callbacks
  state.on_send = opts.on_send
  state.on_cancel = opts.on_cancel
  state.history = opts.history
  state.history_index = nil

  -- Create buffer and window
  state.buf = create_buffer()
  state.win = create_window(state.buf)

  -- Set initial text if provided
  if opts.initial_text then
    set_buffer_content(opts.initial_text)
    -- Move cursor to end
    local line_count = vim.api.nvim_buf_line_count(state.buf)
    vim.api.nvim_win_set_cursor(state.win, { line_count, 0 })
  end

  -- Setup keymaps
  setup_keymaps(state.buf)

  -- Auto-close on buffer leave (optional)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.buf,
    once = true,
    callback = function()
      -- Delay to allow for normal operations
      vim.defer_fn(function()
        if state.win and vim.api.nvim_win_is_valid(state.win) then
          close_window()
        end
      end, 100)
    end,
  })

  -- Start in insert mode at end
  vim.cmd("normal! G$")
  vim.cmd("startinsert!")
end

function M.is_open()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

function M.close()
  close_window()
end

return M
