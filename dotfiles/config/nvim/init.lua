-- Neovim config — Catppuccin Mocha (2026 nerd setup)
-- lazy.nvim bootstrap + catppuccin + treesitter + lualine + telescope + oil
-- Minimalista ma potente: solo quello che serve davvero.

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Opzioni base
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.undofile = true
vim.opt.updatetime = 200
vim.opt.timeoutlen = 300
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.pumblend = 10
vim.opt.winblend = 10
vim.opt.laststatus = 3
vim.opt.showmode = false

-- Plugin
require("lazy").setup({
  -- 🎨 Catppuccin Mocha (colorscheme)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        background = { light = "latte", dark = "mocha" },
        transparent_background = true,   -- blur KWin passa attraverso
        show_end_of_buffer = false,
        term_colors = true,
        dim_inactive = { enabled = true, shade = "dark", percentage = 0.15 },
        styles = {
          comments = { "italic" },
          keywords = { "bold" },
          functions = { "italic" },
          strings = {},
          variables = {},
        },
        integrations = {
          treesitter = true,
          telescope = { enabled = true, style = "nvchad" },
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          mini = { enabled = true },
          which_key = true,
          lualine = true,
          markdown = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- 📊 Lualine (statusline Catppuccin)
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "catppuccin",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { { "location", separator = { right = "" }, left_padding = 2 } },
        },
      })
    end,
  },

  -- 🌳 Treesitter (syntax highlighting)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "vim", "vimdoc", "bash", "python", "javascript",
          "typescript", "json", "toml", "yaml", "markdown", "css", "html",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- 🔭 Telescope (fuzzy finder)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help" },
    },
    config = function()
      local t = require("telescope")
      t.setup({
        defaults = {
          prompt_prefix = " 🔍 ",
          selection_caret = " ❯ ",
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
        },
      })
    end,
  },

  -- 📂 Mini files (file explorer)
  {
    "echasnovski/mini.files",
    version = "*",
    keys = { { "<leader>e", "<cmd>lua MiniFiles.open()<cr>", desc = "Files" } },
    config = function()
      require("mini.files").setup({
        windows = { preview = true, width_preview = 40 },
      })
    end,
  },

  -- ⚡ Which-key (keybind helper)
  {
    "folke/which-key.nvim",
    event = "VimEnter",
    config = function()
      require("which-key").setup({
        preset = "helix",
        icons = { mappings = true, keys = {} },
      })
    end,
  },

  -- 🏠 Mini starter (dashboard)
  {
    "echasnovski/mini.starter",
    version = "*",
    config = function()
      local starter = require("mini.starter")
      starter.setup({
        header = table.concat({
          "  ██████╗ █████╗ ████████╗██████╗ ██████╗ ██╗   ██╗ ██████╗ ██████╗██╗███╗  ██╗",
          " ██╔════╝██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██║   ██║██╔════╝██╔════╝██║████╗ ██║",
          " ██║     ███████║   ██║   ██████╔╝██████╔╝██║   ██║██║     ██║     ██║██╔██╗██║",
          " ██║     ██╔══██║   ██║   ██╔═══╝ ██╔═══╝ ██║   ██║██║     ██║     ██║██║╚████║",
          " ╚██████╗██║  ██║   ██║   ██║     ██║     ╚██████╔╝╚██████╗╚██████╗██║██║ ╚███║",
          "  ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝      ╚═════╝  ╚═════╝ ╚═════╝╚═╝╚═╝  ╚══╝",
          "",
          "           Catppuccin Mocha · KDE Wayland · Arch Linux 2026",
        }, "\n"),
        items = {
          starter.sections.recent_files(5, true),
          starter.sections.builtin_actions(),
        },
        content_hooks = {
          starter.gen_hook.adding_bullet("  "),
          starter.gen_hook.aligning("center", "center"),
        },
      })
    end,
  },

  -- 💡 Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "▎" }, change = { text = "▎" },
          delete = { text = "" }, topdelete = { text = "" },
          changedelete = { text = "▎" },
        },
      })
    end,
  },

  -- 🔢 Mini indentscope
  {
    "echasnovski/mini.indentscope",
    version = "*",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("mini.indentscope").setup({
        symbol = "│",
        options = { try_as_border = true },
      })
    end,
  },
}, {
  ui = { border = "rounded" },
})

-- Keymaps essenziali
local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear highlight" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")
-- Navigate buffers
map("n", "<S-h>", "<cmd>bprevious<cr>")
map("n", "<S-l>", "<cmd>bnext<cr>")
