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
-- - ]b / [b → Next/previous buffer (Neovim built-in, :bnext/:bprevious)

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
-- EVERYTHING ELSE
-- =============================================================================
-- Maps defined elsewhere (plugins, LSP, buffer-local) are documented in
-- docs/keymaps.md -- not duplicated here.
