vim.o.background = "light"
-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo(
  { { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } },
    true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require "lazy_setup"
require "polish"

-- vim.cmd.colorscheme "catppuccin"

vim.cmd.colorscheme "solarized"

local lspconfig = require "lspconfig"

lspconfig.pylsp.setup {
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          -- Ignore E501: line too long
          ignore = { "E501", "E126", "E127" },
        },
      },
    },
  },
}

require("dap").configurations.python = {
  {
    name = "Launch File",
    type = "python",
    request = "launch",
    program = "${file}", -- This runs the current file directly
    console = "integratedTerminal",
    cwd = vim.fn.getcwd(),
    justMyCode = true,
    pythonPath = function()
      local cwd = vim.fn.getcwd()
      if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
        return cwd .. "/venv/bin/python"
      elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
        return cwd .. "/.venv/bin/python"
      end
      return "python"
    end,
  },
  {
    name = "Pytest: Current File",
    type = "python",
    request = "launch",
    module = "pytest", -- This tells DAP to run pytest
    args = {
      "${file}",
      "-sv",
      "--log-cli-level=INFO",
      "--log-file=test_out.log",
    },
    console = "integratedTerminal",
    cwd = vim.fn.getcwd(),
    justMyCode = false,
    subProcess = true,
    pythonPath = function()
      local cwd = vim.fn.getcwd()
      if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
        return cwd .. "/venv/bin/python"
      elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
        return cwd .. "/.venv/bin/python"
      end
      return "python"
    end,
  },
}

vim.keymap.set("n", "<F12>", require("dap").step_into, { desc = "Step Into Function" })

-- Disable the default Tab mapping for Copilot
vim.g.copilot_no_tab_map = true

-- Remap Copilot's accept action to <C-l> in insert mode
vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Accept("<CR>")', { expr = true, silent = true })
