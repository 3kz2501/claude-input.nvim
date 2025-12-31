# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-input.nvim is a Neovim plugin that provides a Vim-native input interface for Claude Code. It solves IME (Input Method Editor) issues with Japanese/Chinese/Korean input by using a normal Neovim buffer instead of terminal mode.

## Architecture

### Backend System

Each backend in `lua/claude-input/backends/` implements the same interface:
- `setup(cfg)` - Configure the backend
- `is_available()` - Check if backend can be used (should be fast, use caching)
- `send(text)` - Send text to Claude Code (returns `ok, msg`)
- `status()` - Return diagnostic info table
- `get_focus_win()` - Optional: return window to focus after sending
- `name` - String identifier

**Auto-detection priority** (in `backends/init.lua:28-40`): tmux → claudecode

### Key Modules

- **init.lua**: Entry point, setup(), commands registration, `M.send()` handles backend dispatch and focus switching
- **backends/init.lua**: Backend loading, auto-detection, `backend_modules` table defines available backends
- **backends/tmux.lua**: Uses `tmux send-keys`, caches pane detection (2s TTL) to avoid slowness
- **backends/claudecode.lua**: Sends via `nvim_chan_send()` to claudecode.nvim terminal buffer

### State Management

UI state is module-local in `ui.lua`: buffer, window, callbacks, history index, original window for focus restoration.

## Testing

No test framework. Manual testing requires:
1. Neovim with the plugin loaded
2. Claude Code running in tmux pane or claudecode.nvim terminal

## Adding a New Backend

1. Create `lua/claude-input/backends/{name}.lua` implementing the interface above
2. Register in `backends/init.lua:backend_modules` table
3. Add to priority array in `detect_backend()` if needed
4. Add config section in `init.lua:M.config`
