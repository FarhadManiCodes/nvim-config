-- ~/.config/nvim/lua/config/keymaps.lua
-- Optimized Keybindings - December 2025
-- Cleaned up, conflict-free, focused on data engineering workflow

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- =============================================================================
-- LEADER KEY
-- =============================================================================
-- Note: Leader key is set in init.lua as backslash (\)
-- Verify with: :echo mapleader

-- =============================================================================
-- DISABLE ARROW KEYS (Enforce hjkl discipline)
-- =============================================================================
-- Disabled in Neovim, but still available in other apps (niri, tmux)
local arrow_keys = { "<Up>", "<Down>", "<Left>", "<Right>" }
for _, key in ipairs(arrow_keys) do
  map("i", key, "<Nop>", opts)
  map("n", key, "<Nop>", opts)
  map("v", key, "<Nop>", opts)
end

-- =============================================================================
-- SEARCH
-- =============================================================================
-- Clear search highlighting
map("n", "<leader><space>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlighting" })

-- Better search navigation (keep cursor centered)
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous search result (centered)" })

-- =============================================================================
-- EDITING
-- =============================================================================
-- Keep visual selection when indenting
map("v", "<", "<gv", { desc = "Indent left (keep selection)" })
map("v", ">", ">gv", { desc = "Indent right (keep selection)" })

-- Better paste in visual mode (don't yank replaced text)
map("v", "p", '"_dP', { desc = "Paste without yanking" })

-- Note: File formatting via LSP: <leader>cf (configured in config/lsp.lua)
-- Native option: gg=G for manual indentation if needed

-- Join lines (native J - kept available, no conflicts now)
-- Just documenting: 'J' in normal mode joins lines

-- =============================================================================
-- BUFFER MANAGEMENT
-- =============================================================================
-- Delete current buffer
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Note: Buffer navigation via:
-- - <leader>bb → Telescope buffers (fuzzy search)
-- - ]b / [b → Next/previous buffer (mini.bracketed)

-- =============================================================================
-- TERMINAL MODE
-- =============================================================================
-- Exit terminal mode easily (double Escape)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Note: Terminal creation via tmux panes (not <leader>t)
-- If needed: :split | :terminal

-- =============================================================================
-- THEME SWITCHING
-- =============================================================================
map("n", "<leader>th", function()
  require("config.themes").toggle()
end, { desc = "Toggle light/dark theme" })

-- =============================================================================
-- MINIMAL UI MODE (replaces zen-mode plugin)
-- =============================================================================
-- Toggle minimal UI for focused writing (LaTeX, markdown)
map("n", "<leader>zm", function()
  -- Toggle line numbers
  vim.wo.number = not vim.wo.number
  vim.wo.relativenumber = not vim.wo.relativenumber

  -- Toggle sign column (git signs, diagnostics)
  vim.wo.signcolumn = vim.wo.signcolumn == "yes" and "no" or "yes"

  -- Toggle status line
  vim.o.laststatus = vim.o.laststatus == 0 and 3 or 0
end, { desc = "Toggle minimal UI mode" })

-- =============================================================================
-- MARKDOWN PREVIEW
-- =============================================================================
map("n", "<leader>mp", function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Buffer has no file name", vim.log.levels.WARN)
    return
  end
  require("config.md_preview").preview(file)
end, { desc = "Preview markdown in vimb" })

-- =============================================================================
-- PLUGIN-SPECIFIC KEYBINDINGS
-- =============================================================================
-- These are defined in plugin configs (plugins/init.lua) but documented here:

-- TELESCOPE (Fuzzy Finder)
-- <C-p>              Find files
-- <leader>b          Find buffers
-- <leader>rg         Live grep (search text)
-- <leader>/          Search in current buffer
-- <leader>fh         Help tags
-- <leader>fr         Resume last search
-- <leader>fo         Recent files
-- <leader>fs         Document symbols (functions, classes in current file)
-- <leader>fS         Workspace symbols (symbols across entire project)
-- <leader>gc         Git commits
-- <leader>gs         Git status

-- OIL.NVIM (File Explorer)
-- -                  Open parent directory
-- <leader>-          Open Oil (floating window)
-- gy (in Oil)        Copy file path
-- gx (in Oil)        Open file externally
-- See plugins/init.lua for full Oil keymaps

-- GITSIGNS (Git Integration)
-- ]c / [c            Next/previous git hunk
-- <leader>hp         Preview hunk
-- <leader>hr         Reset hunk
-- <leader>hs         Stage hunk

-- MINI.BRACKETED (Navigation)
-- ]b / [b            Next/previous buffer
-- ]d / [d            Next/previous diagnostic
-- ]f / [f            Next/previous file
-- ]q / [q            Next/previous quickfix

-- TREESJ (Split/Join Code)
-- gS                 Split code structure
-- gJ                 Join code structure
-- gM                 Toggle split/join

-- TREESITTER TEXT OBJECTS (Selection)
-- af / if            Function outer/inner
-- ac / ic            Class outer/inner
-- aa / ia            Argument/parameter outer/inner
-- ab / ib            Block outer/inner
-- al / il            Loop outer/inner
-- ai / ii            Conditional outer/inner
-- a/                 Comment
-- ]m / [m            Next/previous function START
-- ]M / [M            Next/previous function END
-- ]] / [[            Next/previous class START
-- ][ / []            Next/previous class END

-- NATIVE COMMENTING (Neovim 0.10+ built-in, no plugin needed)
-- gcc                Toggle comment line
-- gc{motion}         Comment with motion (e.g. gcip for paragraph)
-- gbc                Toggle block comment

-- VIM-TMUX-NAVIGATOR (Tmux/Neovim Navigation)
-- <C-h>              Navigate left (Neovim + tmux)
-- <C-j>              Navigate down
-- <C-k>              Navigate up
-- <C-l>              Navigate right
-- <C-\>              Navigate to previous

-- MARKDOWN PREVIEW
-- <leader>mp         Render current .md file and open in vimb (cmark-gfm | vimb -)

-- VIMTEX (LaTeX)
-- <leader>ll         Compile LaTeX
-- <leader>lv         View PDF
-- <leader>lt         Toggle TOC
-- <leader>lc         Clean auxiliary files
-- <leader>ls         Stop compilation

-- TWILIGHT (Focus Mode)
-- <leader>tt         Toggle twilight (for presentations)

-- VIM-DADBOD (Database)
-- <leader>rr         Execute SQL line/selection
-- <leader>rf         Execute entire SQL file

-- RAINBOW_CSV (CSV Files - only in .csv/.tsv buffers)
-- <leader>cc         Align CSV columns
-- <leader>cq         RBQL query

-- VIM-ENVX (Environment Variables)
-- <leader>ev         Expand env variable (replace $VAR with its value)
-- <leader>eev        Expand all env vars on line
-- <leader>ex         Extract selection as env variable (visual mode)
--                    NOTE: 'ex' breaks the 'ev*' pattern; it was 'evv'
--                    before, renamed to clear a which-key prefix overlap.

-- =============================================================================
-- NATIVE VIM KEYBINDINGS (Good to remember)
-- =============================================================================
-- These are native Vim, not custom mappings, but worth documenting:

-- UNDO/REDO:
-- u                  Undo
-- <C-r>              Redo
-- :earlier 5m        Go back 5 minutes
-- :later 10m         Go forward 10 minutes

-- WINDOWS/SPLITS:
-- <C-w>s             Horizontal split
-- <C-w>v             Vertical split
-- <C-w>q             Close window
-- <C-w>=             Equalize window sizes
-- (Use vim-tmux-navigator for navigation)

-- MARKS:
-- m{a-z}             Set mark
-- '{a-z}             Jump to mark
-- ''                 Jump to last position

-- MACROS:
-- q{a-z}             Record macro
-- @{a-z}             Play macro
-- @@                 Repeat last macro

-- TEXT OBJECTS:
-- ciw, diw, yiw      Change/delete/yank inner word
-- ca", da", ya"      Change/delete/yank around quotes
-- ci(, di(, yi(      Change/delete/yank inside parentheses
-- And many more...

-- JOINING LINES:
-- J                  Join current line with next (native, no conflict now)

-- =============================================================================
-- NOTES ON REMOVED KEYBINDINGS
-- =============================================================================
-- These were in the old config but removed because:
--
-- <leader>vr         Config reload (never used, just restart Neovim)
-- <leader>=          Manual format (temporary, will be replaced by LSP <leader>f)
-- <C-arrows>         Window resize (doesn't work in terminal, use tmux)
-- <leader>bn/bp      Buffer cycle (use Telescope <leader>bb or ]b/[b instead)
-- <leader>t          Open terminal (use tmux panes instead)
-- <leader>l          Lazy plugin manager (conflicted with LaTeX, never used)
-- Visual J/K         Move lines (conflicted with join-lines, not used)

-- =============================================================================
-- LSP KEYBINDINGS (BUFFER-LOCAL - ONLY IN LSP-ATTACHED BUFFERS)
-- =============================================================================
-- These are configured in config/lsp.lua on_attach function
-- They only work in buffers with LSP attached (C/C++, Python, Bash)
--
-- NAVIGATION:
-- gd                 Go to definition
-- gD                 Go to declaration
-- gr                 Find references
-- gi                 Go to implementation
-- gt                 Go to type definition
--
-- DOCUMENTATION:
-- K                  Hover documentation (shows type info, signatures)
-- <C-k>              Signature help (insert mode - shows parameters while typing)
--
-- CODE ACTIONS:
-- <leader>ca         Code actions (auto-import, quick fixes)
-- <leader>cr         Rename symbol
-- <leader>cf         Format file with LSP
-- <leader>ci         Toggle inlay hints (parameter names, deduced types)
-- <leader>ch         Switch between header/source file (clangd only)
--
-- DIAGNOSTICS:
-- [d                 Previous diagnostic (mini.bracketed, global)
-- ]d                 Next diagnostic     (mini.bracketed, global)
-- <leader>ed         Show diagnostic float: full error/warning msg for the
--                    line under cursor (virtual_text is off, so this reveals it)
-- <leader>eq         Send all buffer diagnostics to the location list,
--                    then walk them with [q / ]q
--                    NOTE: 'ed'/'eq' were '<leader>e'/'<leader>q' before,
--                    nested under the 'e' (Env/Diag) group in this audit.
--
-- COMPLETION (INSERT MODE):
-- <C-Space>          Manual trigger completion
-- <C-n> / <Tab>      Next completion item
-- <C-p> / <S-Tab>    Previous completion item
-- <CR>               Confirm selection
-- <C-e>              Close completion menu
-- <C-b>              Scroll docs up
-- <C-f>              Scroll docs down

-- =============================================================================
-- WORKFLOW-SPECIFIC TIPS
-- =============================================================================
-- DATA ENGINEERING WORKFLOWS:
--
-- 1. File Navigation:
--    <C-p> → Find Python/SQL script
--    <leader>rg → Search for function name
--    - → Browse data directories in Oil
--
-- 2. Git Operations:
--    ]c → Jump to changed code
--    <leader>hp → Preview what changed
--    <leader>hs → Stage the change
--    Ctrl+b in tmux → Switch to lazygit pane
--
-- 3. Database Work:
--    <leader>rr → Quick SQL query test
--    Switch to DataGrip for complex operations
--
-- 4. CSV Analysis:
--    Open CSV → Rainbow colors appear
--    <leader>cq → RBQL query for filtering
--
-- 5. Documentation:
--    .tex file: <leader>ll → Live compile
--    <leader>zm → Minimal UI for writing
--    <leader>tt → Twilight focus mode
--
-- 6. Presentations/Interviews:
--    <leader>th → Switch to light theme
--    <leader>tt → Twilight to focus on code section
--
-- =============================================================================
-- END OF KEYBINDINGS
-- =============================================================================
