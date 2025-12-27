# claude-input.nvim

A Vim-native input interface for Claude Code. Solve Japanese IME (and other input method) issues by using a normal Neovim buffer for input.

## Features

- **Vim-native editing** - Full Vim motions, insert/normal mode, all your muscle memory works
- **IME-friendly** - Perfect Japanese/Chinese/Korean input (no terminal mode issues)
- **Multiple backends** - tmux (priority), claudecode.nvim
- **Selection support** - Send visual selection as code block
- **Auto-return** - Focus returns to editor after sending

## Installation

### lazy.nvim

```lua
{
  "3kz2501/claude-input.nvim",
  config = function()
    require("claude-input").setup({
      backend = "auto", -- "auto" | "tmux" | "claudecode"
    })
  end,
  keys = {
    { "<leader>ci", "<cmd>ClaudeInput<cr>", desc = "Claude Input" },
    { "<leader>cs", "<cmd>ClaudeInputWithSelection<cr>", mode = "v", desc = "Claude Input with Selection" },
  },
}
```

## Usage

### Basic

1. Open input window: `<leader>ci` (or `:ClaudeInput`)
2. Type your prompt (Japanese, English, whatever!)
3. Press `<Esc>` to go to normal mode
4. Type `:W` to send (or `<leader>w`)

### With Selection

1. Select code in visual mode
2. Press `<leader>cs` (or `:ClaudeInputWithSelection`)
3. The selection is inserted as a code block
4. Add your prompt and send with `:W`

### Keymaps in Input Window

| Mode | Key | Action |
|------|-----|--------|
| Normal | `:W` | Send and close |
| Normal | `<leader>w` | Send and close |
| Normal | `q` | Cancel and close |
| Insert | All vim keys | Normal vim insert mode |

## Configuration

```lua
require("claude-input").setup({
  -- Backend selection
  backend = "auto", -- "auto" | "tmux" | "claudecode"

  -- tmux backend settings
  tmux = {
    pane = nil, -- nil = auto-detect, or specify like "%1"
  },

  -- claudecode.nvim settings
  claudecode = {
    -- Uses terminal buffer directly
  },
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

### tmux (Priority)

Sends text to a tmux pane running Claude Code.

**Requirements:**
- Running inside tmux
- Claude Code running in another tmux pane

**Auto-detection:** Looks for panes with "claude" in the command name.

### claudecode.nvim

Integrates with [claudecode.nvim](https://github.com/anthropics/claudecode.nvim).

**Requirements:**
- claudecode.nvim installed and configured
- Claude Code terminal open (`:ClaudeCode`)

**Note:** Only available when claudecode.nvim terminal is active.

## Why?

Terminal mode in Neovim doesn't play well with IME (Input Method Editor) for Japanese, Chinese, Korean, and other languages. This plugin uses a normal Neovim buffer for input, which has perfect IME support.

Plus, you get all the Vim goodness: motions, text objects, registers, macros, etc.

## License

MIT
