# claude-input.nvim

A Vim-native input interface for Claude Code. Solve Japanese IME (and other input method) issues by using a normal Neovim buffer for input.

## Features

- 🎯 **Vim-native editing** - Full Vim motions, insert/normal mode, all your muscle memory works
- 🇯🇵 **IME-friendly** - Perfect Japanese/Chinese/Korean input (no terminal mode issues)
- 📜 **Input history** - Navigate with `<C-p>` / `<C-n>`
- 🔌 **Multiple backends** - tmux, claudecode.nvim, wezterm
- 📋 **Selection support** - Send visual selection as code block
- ⌨️ **Auto-return** - Focus returns to editor after sending

## Installation

### lazy.nvim

```lua
return {
  "your-username/claude-input.nvim",
  config = function()
    require("claude-input").setup({
      backend = "auto", -- "auto" | "tmux" | "claudecode" | "wezterm"
    })
  end,
  keys = {
    { "<leader>ci", "<cmd>ClaudeInput<cr>", desc = "Claude Input" },
    { "<leader>cs", "<cmd>ClaudeInputWithSelection<cr>", mode = "v", desc = "Claude Input with Selection" },
  },
}
```

### With claudecode.nvim

```lua
return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    },
  },
  {
    "your-username/claude-input.nvim",
    config = function()
      require("claude-input").setup({
        backend = "claudecode",
      })
    end,
    keys = {
      { "<leader>ci", "<cmd>ClaudeInput<cr>", desc = "Claude Input" },
      { "<leader>cs", "<cmd>ClaudeInputWithSelection<cr>", mode = "v", desc = "Claude Input with Selection" },
    },
  },
}
```

## Usage

### Basic

1. Open input window: `<leader>ci` (or `:ClaudeInput`)
2. Type your prompt (Japanese, English, whatever!)
3. Press `<Esc>` to go to normal mode
4. Press `<Enter>` to send

### With Selection

1. Select code in visual mode
2. Press `<leader>cs` (or `:ClaudeInputWithSelection`)
3. The selection is inserted as a code block
4. Add your prompt and send

### Keymaps in Input Window

| Mode | Key | Action |
|------|-----|--------|
| Normal | `<CR>` | Send and close |
| Normal | `<C-s>` | Send but keep window open |
| Normal | `q` / `<Esc>` | Cancel and close |
| Normal | `<C-p>` | Previous history |
| Normal | `<C-n>` | Next history |
| Normal | `?` | Show help |
| Insert | `<Enter>` | Newline (normal behavior) |
| Insert | All vim keys | Normal vim insert mode |

## Configuration

```lua
require("claude-input").setup({
  -- Backend selection
  backend = "auto", -- "auto" | "tmux" | "claudecode" | "wezterm"

  -- Window appearance
  window = {
    width = 0.6,      -- 60% of editor width
    height = 0.4,     -- 40% of editor height
    border = "rounded",
    title = " Claude Input ",
    title_pos = "center",
  },

  -- Keymaps (in input window)
  keymaps = {
    send = "<CR>",
    send_stay = "<C-s>",
    cancel = "q",
    history_prev = "<C-p>",
    history_next = "<C-n>",
  },

  -- tmux backend settings
  tmux = {
    pane = nil, -- nil = auto-detect, or specify like "%1"
  },

  -- wezterm backend settings
  wezterm = {
    pane_id = nil, -- nil = auto-detect
  },

  -- claudecode.nvim settings
  claudecode = {
    -- Uses :ClaudeCodeSend internally
  },

  -- History settings
  history = {
    enabled = true,
    max_entries = 100,
    save_path = vim.fn.stdpath("data") .. "/claude-input-history.json",
  },

  -- Include visual selection as code block
  include_selection = true,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:ClaudeInput` | Open input window |
| `:ClaudeInputWithSelection` | Open with visual selection |
| `:ClaudeInputSetBackend {name}` | Change backend |
| `:ClaudeInputStatus` | Show status |

## Backends

### tmux

Sends text to a tmux pane running Claude Code.

**Requirements:**
- Running inside tmux
- Claude Code running in another tmux pane

**Auto-detection:** Looks for panes with "claude" in the command or title.

### claudecode.nvim

Integrates with [coder/claudecode.nvim](https://github.com/coder/claudecode.nvim).

**Requirements:**
- claudecode.nvim installed and configured
- Claude Code terminal open (`:ClaudeCode`)

### wezterm

Sends text to a wezterm pane running Claude Code.

**Requirements:**
- Running inside wezterm
- Claude Code running in another wezterm pane
- `wezterm` CLI available

## Why?

Terminal mode in Neovim doesn't play well with IME (Input Method Editor) for Japanese, Chinese, Korean, and other languages. This plugin uses a normal Neovim buffer for input, which has perfect IME support.

Plus, you get all the Vim goodness: motions, text objects, registers, macros, etc.

## License

MIT
