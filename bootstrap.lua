-- Invoked after normal init.lua, in separate processes for plugins and tools.
local ok, err = xpcall(function()
  local lazy = require "lazy"
  if vim.env.SETUP_STAGE == "plugins" then
    lazy.install { wait = true, show = false, lockfile = true }
    lazy.restore { wait = true, show = false, clear = false }
    for name, plugin in pairs(require("lazy.core.config").plugins) do
      assert(vim.fn.isdirectory(plugin.dir) == 1, "Missing plugin: " .. name)
      for _, task in ipairs(plugin._.tasks or {}) do
        assert(not task:has_errors(), "Plugin task failed: " .. name .. "; inspect :Lazy log")
      end
    end
  else
    lazy.load { plugins = { "mason.nvim", "nvim-treesitter" } }
    local registry = require "mason-registry"
    registry.refresh()
    local names = {
      "basedpyright", "black", "clangd", "codelldb", "debugpy", "isort",
      "ltex-ls-plus", "lua-language-server", "selene", "stylua", "taplo", "rust-analyzer",
    }
    for _, name in ipairs(names) do
      local package = registry.get_package(name)
      if not package:is_installed() then
        local handle = package:install()
        assert(vim.wait(600000, function() return handle:is_closed() end, 100), "Timed out: " .. name)
        assert(package:is_installed(), "Mason install failed: " .. name .. "; inspect :MasonLog")
      end
    end
    -- This checkout pins the legacy nvim-treesitter installer with synchronous commands.
    vim.cmd "TSUpdateSync"
    local parsers = require("nvim-treesitter.configs").get_ensure_installed_parsers()
    vim.cmd("TSInstallSync " .. table.concat(parsers, " "))
    for _, parser in ipairs(parsers) do
      assert(#vim.api.nvim_get_runtime_file("parser/" .. parser .. ".*", false) > 0, "Missing parser: " .. parser)
    end
  end
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd "cquit 1"
else
  vim.cmd "qa!"
end
