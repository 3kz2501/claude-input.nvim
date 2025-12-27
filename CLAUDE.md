# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-input.nvim is a Neovim plugin that provides a Vim-native input interface for Claude Code. It solves IME (Input Method Editor) issues with Japanese/Chinese/Korean input by using a normal Neovim buffer instead of terminal mode.

## Architecture

```
lua/claude-input/
├── init.lua          # Main module: setup, commands, public API (M.open, M.send)
├── ui.lua            # Floating window UI: buffer/window creation, keymaps, state management
├── history.lua       # Input history: JSON persistence, add/get/navigation
└── backends/
    ├── init.lua      # Backend manager: auto-detection, loading, selection
    ├── tmux.lua      # tmux backend: pane detection, send-keys
    ├── claudecode.lua # claudecode.nvim backend: terminal channel send
    └── wezterm.lua   # wezterm backend: CLI pane detection, send-text
```

### Key Design Patterns

**Backend System**: Each backend implements the same interface:
- `setup(cfg)` - Configure the backend
- `is_available()` - Check if backend can be used
- `send(text)` - Send text to Claude Code (returns `ok, msg`)
- `status()` - Return diagnostic info table
- `name` - String identifier

**Auto-detection Priority**: tmux → claudecode (checked in order in `backends/init.lua:28-40`)

**State Management**: UI state is module-local in `ui.lua` (lines 7-15): buffer, window, callbacks, history index, original window for focus restoration.

## Testing

No test framework is currently set up. Manual testing requires:
1. Running Neovim with the plugin loaded
2. Having Claude Code running in a supported environment (tmux pane, wezterm pane, or claudecode.nvim terminal)

## Development Notes

- Plugin uses lazy-loading: modules (`ui`, `history`, `backends`) are only required in `setup()`
- History persists to `stdpath("data")/claude-input-history.json`
- The input window filetype is set to `markdown` for syntax highlighting
- Backend detection happens at setup time and when explicitly changed via `ClaudeInputSetBackend`
