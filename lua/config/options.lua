-- Editor behavior, performance, and display settings.

local opt = vim.opt
local g = vim.g

-- File handling and persistent undo
opt.autoread = true
opt.confirm = true
opt.swapfile = false
opt.backup = false
opt.writebackup = false

local undodir = vim.fn.stdpath("data") .. "/undodir"
opt.undofile = true
opt.undodir = undodir
opt.undolevels = 10000
opt.undoreload = 3000

-- Appearance and scrolling
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes" -- Prevent text shifting when signs appear.
opt.cursorline = true
opt.scrolloff = 6
opt.sidescrolloff = 8

-- Global indentation defaults; filetype overrides live in autocmds.lua.
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.smartindent = true

-- Search
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Windows and command line
opt.splitright = true
opt.splitbelow = true
opt.wildmenu = true
opt.wildmode = "longest:full,full"
opt.wildoptions = "pum"

-- Keep the unnamed register separate from the system clipboard. Use "+y and
-- "+p explicitly. Neovim auto-detects wl-copy/wl-paste locally; over SSH,
-- OSC 52 carries clipboard data through the terminal and tmux.
opt.clipboard = ""
if vim.env.SSH_TTY ~= nil then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

-- Timing
opt.updatetime = 250 -- CursorHold and gitsigns refresh.
opt.timeoutlen = 600
opt.ttimeoutlen = 10

-- Display
opt.termguicolors = true
vim.o.winborder = "rounded"
opt.pumheight = 15
opt.pumblend = 0
opt.wrap = true
opt.linebreak = true
opt.breakindent = true

opt.showcmd = false
opt.showmode = false -- Cursor shape indicates the current mode.
opt.shortmess:append({
  I = true, -- Suppress the startup message.
  W = true, -- Suppress the write confirmation.
  c = true, -- Suppress insert-completion messages.
  C = true, -- Suppress insert-completion scanning messages.
})

-- Treesitter folding, open by default
opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldnestmax = 10

-- Histogram keeps code blocks together better than Myers; indent-heuristic
-- improves Python/YAML alignment. linematch and inline:char limit highlights
-- to the changed words and characters within paired lines.
opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "context:5",
  "algorithm:histogram",
  "indent-heuristic",
  "linematch:60",
  "inline:char",
}
opt.fillchars:append({ diff = "╱" })

-- Mouse and completion UI
opt.mouse = "a"
opt.mousemoveevent = true
opt.completeopt = {
  "menu",
  "menuone",
  "noselect",
}

-- Do not continue comment leaders automatically. Recognize numbered lists
-- during formatting and remove comment leaders when joining lines.
opt.formatoptions:remove({ "c", "r", "o" })
opt.formatoptions:append({ "n", "j" })

-- Cursor shape identifies the mode, allowing showmode to remain disabled.
opt.guicursor = {
  "n-v-c:block",
  "i-ci-ve:ver25",
  "r-cr:hor20",
  "o:hor50",
  "a:blinkwait700-blinkoff400-blinkon250",
  "sm:block-blinkwait175-blinkoff150-blinkon175",
}

-- Bound syntax work on long or complex lines.
opt.synmaxcol = 300
opt.redrawtime = 1500

-- Whitespace
opt.list = true
opt.listchars = {
  tab = "→ ",
  trail = "·",
  nbsp = "␣",
  extends = "⟩",
  precedes = "⟨",
}

-- Terminal title and spelling
opt.title = true
opt.titlestring = "NVIM - %t"
opt.spell = false -- Enabled per filetype in autocmds.lua.
opt.spelllang = "en_us"

-- Shell
if vim.fn.executable("zsh") == 1 then
  opt.shell = "zsh"
else
  opt.shell = "bash"
end

-- Disable unused external-language providers.
g.loaded_ruby_provider = 0
g.loaded_perl_provider = 0
g.loaded_node_provider = 0
g.loaded_python3_provider = 0

-- Python's ftplugin installs regex-based class and function motions in every
-- Python buffer. Buffer-local mappings win over the treesitter motions in
-- plugins/treesitter.lua, and the regex can stop on def/class text inside a
-- docstring. This flag disables only those Python runtime mappings.
--
-- Do not use g.no_plugin_maps: SQL's runtime maps are useful, while Markdown's
-- ]] and [[ maps come from this config's treesitter-based ftplugin.
g.no_python_maps = 1

-- Load trusted project-local .nvim.lua files. Neovim also searches parent
-- directories, so shared or mounted trees may prompt for a file above cwd.
opt.exrc = true
