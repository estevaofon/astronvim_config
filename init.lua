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
          ignore = { "E501", "E126", "E127", "W391" },
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
      elseif vim.fn.executable(cwd .. "/.env/bin/python") == 1 then
        return cwd .. "/.env/bin/python"
      elseif vim.fn.executable(cwd .. "/env/bin/python") == 1 then
        return cwd .. "/env/bin/python"
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
      elseif vim.fn.executable(cwd .. "/.env/bin/python") == 1 then
        return cwd .. "/.env/bin/python"
      elseif vim.fn.executable(cwd .. "/env/bin/python") == 1 then
        return cwd .. "/env/bin/python"
      end
      return "python"
    end,
  },
}

vim.keymap.set("n", "<F12>", require("dap").step_into, { desc = "Step Into Function" })
vim.keymap.set("n", "<F6>", require("dap").terminate, { desc = "Stop Debugging" })

-- Disable the default Tab mapping for Copilot
vim.g.copilot_no_tab_map = true

-- Remap Copilot's accept action to <C-l> in insert mode
vim.api.nvim_set_keymap("i", "<C-l>", 'copilot#Accept("<CR>")', { expr = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>a", ":lua print(vim.fn.expand('%:p'))<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>gp", ":GitSigns preview_hunk<CR>", {})

-- Function to set the Python environment for DAP
local function set_python_env()
  local cwd = vim.fn.getcwd()
  local venv_paths = {
    cwd .. "/.venv/bin/python",
    cwd .. "/venv/bin/python",
    cwd .. "/.env/bin/python",
  }

  for _, path in ipairs(venv_paths) do
    if vim.fn.executable(path) == 1 then
      vim.g.python3_host_prog = path -- Use the correct global variable
      -- print("Python environment activated: " .. path)
      return path
    end
  end

  -- Optionally, set a default Python interpreter if no venv is found:
  -- vim.g.python4_host_prog = '/usr/bin/python3'
  return nil
end

set_python_env()

local M = {}
local HOME = os.getenv "HOME"

M.store_breakpoints = function(clear)
  -- if doesn't exist create it:
  if vim.fn.filereadable(HOME .. "/.cache/dap/breakpoints.json") == 0 then
    -- Create file
    os.execute("mkdir -p " .. HOME .. "/.cache/dap")
    os.execute("touch " .. HOME .. "/.cache/dap/breakpoints.json")
  end

  local load_bps_raw = io.open(HOME .. "/.cache/dap/breakpoints.json", "r"):read "*a"
  if load_bps_raw == "" then load_bps_raw = "{}" end

  local bps = vim.fn.json_decode(load_bps_raw)
  local breakpoints_by_buf = require("dap.breakpoints").get()
  if clear then
    for _, bufrn in ipairs(vim.api.nvim_list_bufs()) do
      local file_path = vim.api.nvim_buf_get_name(bufrn)
      if bps[file_path] ~= nil then bps[file_path] = {} end
    end
  else
    for buf, buf_bps in pairs(breakpoints_by_buf) do
      bps[vim.api.nvim_buf_get_name(buf)] = buf_bps
    end
  end
  local fp = io.open(HOME .. "/.cache/dap/breakpoints.json", "w")
  local final = vim.fn.json_encode(bps)
  fp:write(final)
  fp:close()
end

M.load_breakpoints = function()
  local fp = io.open(HOME .. "/.cache/dap/breakpoints.json", "r")
  if fp == nil then
    print "No breakpoints found."
    return
  end
  local content = fp:read "*a"
  local bps = vim.fn.json_decode(content)
  local loaded_buffers = {}
  local found = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local file_name = vim.api.nvim_buf_get_name(buf)
    if bps[file_name] ~= nil and bps[file_name] ~= {} then found = true end
    loaded_buffers[file_name] = buf
  end
  if found == false then return end
  for path, buf_bps in pairs(bps) do
    for _, bp in pairs(buf_bps) do
      local line = bp.line
      local opts = {
        condition = bp.condition,
        log_message = bp.logMessage,
        hit_condition = bp.hitCondition,
      }
      require("dap.breakpoints").set(opts, tonumber(loaded_buffers[path]), line)
    end
  end
end

-- In your init.lua, after requiring dap and configuring it:
-- Instead of requiring a separate module, use the table defined above.
local dap_breakpoints = M

-- On VimEnter, load stored breakpoints.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function() dap_breakpoints.load_breakpoints() end,
})

-- On VimLeavePre, store your breakpoints.
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    dap_breakpoints.store_breakpoints(false) -- 'false' means do not clear breakpoints.
  end,
})

vim.api.nvim_set_keymap("n", "<leader>fg", ":Telescope live_grep<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>lg", ":Telescope live_grep<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-a>", "ggVG", { noremap = true, silent = true })

-- Function to prompt for search and replace, then run the substitution command
local function search_replace_prompt()
  vim.ui.input({ prompt = "Enter word to search: " }, function(search)
    if not search or search == "" then
      print "Search term is empty."
      return
    end
    vim.ui.input({ prompt = "Enter replacement word: " }, function(replacement)
      if replacement == nil then
        print "Replacement term is empty."
        return
      end
      -- Escape any special characters in the input
      local escaped_search = vim.fn.escape(search, "/")
      local escaped_replacement = vim.fn.escape(replacement, "/")
      -- Build and execute the substitution command with word boundaries
      local cmd = string.format("%%s/\\<%s\\>/%s/g", escaped_search, escaped_replacement)
      vim.cmd(cmd)
      print(string.format("Replaced '%s' with '%s' in the entire file.", search, replacement))
    end)
  end)
end

-- Create a user command so you can call it via :SearchReplace
vim.api.nvim_create_user_command("SearchReplace", search_replace_prompt, {})

-- Optionally, map it to a key (e.g., <leader>sr)
vim.keymap.set("n", "<leader>sr", search_replace_prompt, { desc = "Search and Replace" })
vim.keymap.set("n", "<F4>", require("dap.ui.widgets").hover, { silent = true })

local dapui = require "dapui"
dapui.setup {
  auto_open = true, -- Automatically open the UI when debugging starts
  auto_close = false, -- Keep the UI open after the debug session ends
}

local dap = require "dap"
-- Disable any default auto-close listeners added by dap-ui:
dap.listeners.before.event_terminated["dapui_config"] = function() end
dap.listeners.before.event_exited["dapui_config"] = function() end

-- vim.keymap.set("n", "<leader>dq", function() require("dapui").close() end, { desc = "Close all DAP windows" })

-- Save the current buffer when starting the DAP session
dap.listeners.before.event_initialized["save_buffer"] = function(session)
  vim.g.last_dap_buffer = vim.api.nvim_get_current_buf()
end

-- Create a key mapping that closes the DAP UI and returns to the original buffer
vim.keymap.set("n", "<leader>dq", function()
  dapui.close() -- close all DAP windows
  if vim.g.last_dap_buffer then
    vim.api.nvim_set_current_buf(vim.g.last_dap_buffer)
  else
    print "No original file recorded."
  end
end, { desc = "Return to file where DAP was issued" })

vim.keymap.set(
  "n",
  "<leader>cn",
  function() require("notify").dismiss { silent = true, pending = true } end,
  { desc = "Dismiss all notifications" }
)

-- In visual mode: Comment selected lines
-- vim.api.nvim_set_keymap("v", "<leader>c", ":s/^/# /<CR>", { noremap = true, silent = true })
-- vim.keymap.set("x", "<leader>c", ":s/^\\(\\s*\\)/\\1# /<CR>", { silent = true })
vim.keymap.set({ "n", "x" }, "<leader>c", ":s/^\\(\\s*\\)/\\1# /<CR>", { silent = true })
vim.keymap.del("n", "<C-q>")
vim.api.nvim_set_keymap("n", "<C-q>", "<C-v>", { noremap = true, silent = true })
