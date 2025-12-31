-- claude-input/backends/init.lua
-- Backend manager for Claude input

local M = {}

local config = {}
local current_backend = nil

local backend_modules = {
	tmux = "claude-input.backends.tmux",
	claudecode = "claude-input.backends.claudecode",
}

local function load_backend(name)
	local module_name = backend_modules[name]
	if not module_name then
		return nil
	end

	local ok, backend = pcall(require, module_name)
	if not ok then
		return nil
	end

	return backend
end

local function detect_backend()
	-- Priority order for auto-detection
	-- tmux first (most common), then claudecode (nvim integrated)
	local priority = { "tmux", "claudecode" }

	for _, name in ipairs(priority) do
		local backend = load_backend(name)
		if backend and backend.is_available and backend.is_available() then
			return backend
		end
	end

	return nil
end

function M.setup(cfg)
	config = cfg
	current_backend = nil

	-- Setup all backends
	for name, module_name in pairs(backend_modules) do
		local ok, backend = pcall(require, module_name)
		if ok and backend.setup then
			local backend_config = cfg[name] or {}
			backend.setup(backend_config)
		end
	end

	-- Set current backend
	if config.backend == "auto" then
		current_backend = detect_backend()
	else
		current_backend = load_backend(config.backend)
		if current_backend and current_backend.is_available and not current_backend.is_available() then
			vim.notify(
				"claude-input: configured backend '" .. config.backend .. "' is not available, falling back to auto",
				vim.log.levels.WARN
			)
			current_backend = detect_backend()
		end
	end
end

function M.get_current()
	return current_backend
end

-- Re-detect backend if current one is unavailable
function M.ensure_available()
	if current_backend and current_backend.is_available and current_backend.is_available() then
		return current_backend
	end

	-- Current backend unavailable, try to find another
	local new_backend = detect_backend()
	if new_backend then
		current_backend = new_backend
	end
	return current_backend
end

function M.list_available()
	local available = {}

	for name, _ in pairs(backend_modules) do
		local backend = load_backend(name)
		if backend and backend.is_available and backend.is_available() then
			table.insert(available, name)
		end
	end

	return available
end

function M.set(name)
	local backend = load_backend(name)
	if backend then
		current_backend = backend
		return true
	end
	return false
end

return M
