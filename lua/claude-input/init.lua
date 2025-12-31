-- claude-input.nvim
-- A Vim-native input interface for Claude Code
-- Supports tmux and claudecode.nvim backends

local M = {}

M.config = {
  backend = "auto", -- "auto" | "tmux" | "claudecode"

  window = {
    width = 0.6,
    height = 0.4,
    border = "rounded",
    title = " Claude Input ",
    title_pos = "center",
  },

  keymaps = {
    send = "<CR>",           -- Normal mode: send and close
    send_stay = "<C-s>",     -- Normal mode: send but keep window open
    cancel = "q",            -- Normal mode: cancel and close
    history_prev = "<C-p>",  -- Normal mode: previous history
    history_next = "<C-n>",  -- Normal mode: next history
  },

  tmux = {
    pane = nil, -- nil = auto detect, or specify like "%1"
  },

  claudecode = {
    -- Uses :ClaudeCodeSend internally
  },

  history = {
    enabled = true,
    max_entries = 100,
    save_path = vim.fn.stdpath("data") .. "/claude-input-history.json",
  },

  -- Automatically include visual selection as code block
  include_selection = true,
}

local ui = nil
local history = nil
local backends = nil

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  ui = require("claude-input.ui")
  history = require("claude-input.history")
  backends = require("claude-input.backends")

  ui.setup(M.config)
  history.setup(M.config.history)
  backends.setup(M.config)

  -- Register commands
  vim.api.nvim_create_user_command("ClaudeInput", function()
    M.open()
  end, { desc = "Open Claude input window" })

  vim.api.nvim_create_user_command("ClaudeInputWithSelection", function()
    M.open_with_selection()
  end, { range = true, desc = "Open Claude input with visual selection" })

  vim.api.nvim_create_user_command("ClaudeInputSetBackend", function(args)
    M.set_backend(args.args)
  end, {
    nargs = 1,
    complete = function()
      return { "auto", "tmux", "claudecode" }
    end,
    desc = "Set Claude input backend",
  })

  vim.api.nvim_create_user_command("ClaudeInputStatus", function()
    M.show_status()
  end, { desc = "Show Claude input status" })
end

function M.open(initial_text)
  if not backends then
    vim.notify("claude-input: not initialized. Call setup() first", vim.log.levels.ERROR)
    return
  end

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  -- Set initial content
  if initial_text and initial_text ~= "" then
    local lines = vim.split(initial_text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  -- Open in split
  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, 10)

  -- Set window title
  vim.wo[win].statusline = " Claude Input | :w to send | :q to cancel "

  -- Keymaps for this buffer
  local opts = { buffer = buf, silent = true }

  -- Helper to close input window safely
  local function close_input_win()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- :w to send
  vim.keymap.set("n", "<leader>w", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = vim.trim(table.concat(lines, "\n"))
    close_input_win()
    if text ~= "" then
      M.send(text)
      vim.notify("Sent to Claude!", vim.log.levels.INFO)
    end
  end, opts)

  -- Also map :w command
  vim.api.nvim_buf_create_user_command(buf, "W", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = vim.trim(table.concat(lines, "\n"))
    close_input_win()
    if text ~= "" then
      M.send(text)
      vim.notify("Sent to Claude!", vim.log.levels.INFO)
    end
  end, {})

  -- q to cancel
  vim.keymap.set("n", "q", function()
    close_input_win()
  end, opts)

  -- Go to end and insert mode
  vim.cmd("normal! G")
  vim.cmd("startinsert!")
end

function M.open_with_selection()
  -- Get visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if type(lines) == "string" then
    lines = { lines }
  end

  if #lines == 0 then
    M.open()
    return
  end

  -- Handle partial line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  -- Get filetype for code block
  local ft = vim.bo.filetype or ""

  -- Format as code block
  local code_block = "```" .. ft .. "\n" .. table.concat(lines, "\n") .. "\n```\n\n"

  M.open(code_block)
end

function M.send(text)
  if not text or text == "" then
    vim.notify("claude-input: empty input", vim.log.levels.WARN)
    return
  end

  -- Save to history
  if history then
    history.add(text)
  end

  -- Send via backend (re-detect if current is unavailable)
  local backend = backends.ensure_available()
  if backend then
    local ok, msg = backend.send(text)
    if not ok then
      -- Try re-detecting backend and retry once
      local new_backend = backends.ensure_available()
      if new_backend and new_backend ~= backend then
        ok, msg = new_backend.send(text)
        if ok then
          backend = new_backend
        end
      end
      if not ok then
        vim.notify("claude-input: " .. (msg or "failed to send"), vim.log.levels.ERROR)
        return
      end
    end
    if msg then
      -- Success with message (e.g., copied to clipboard)
      vim.notify("claude-input: " .. msg, vim.log.levels.INFO)
    end

    -- Focus the backend's target window if available
    if backend.get_focus_win then
      local win = backend.get_focus_win()
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
      end
    end
  else
    vim.notify("claude-input: no backend available", vim.log.levels.ERROR)
  end
end

function M.set_backend(name)
  M.config.backend = name
  backends.setup(M.config)
  vim.notify("claude-input: backend set to " .. name, vim.log.levels.INFO)
end

function M.show_status()
  local current = backends.get_current()
  local name = current and current.name or "none"
  local available = backends.list_available()

  local lines = {
    "Claude Input Status",
    "==================",
    "",
    "Current backend: " .. name,
    "Available backends: " .. table.concat(available, ", "),
    "",
  }

  -- Backend-specific status
  if current and current.status then
    local status = current.status()
    for k, v in pairs(status) do
      table.insert(lines, k .. ": " .. tostring(v))
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
