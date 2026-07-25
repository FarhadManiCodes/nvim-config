-- ~/.config/nvim/lua/config/papis_bib.lua
-- Shared front-end for `papis-bib` (dotfiles/bash/papis-bib).
--
-- Both .tex (vimtex) and .typ (typst-preview) drive the same script with the
-- same two operations, so the logic and the rationale live here once instead of
-- being copy-pasted into each plugin spec in lua/plugins/init.lua.
--
-- Two modes, mirroring the script's own contract (see CLAUDE.md):
--   sync()  — ADDITIVE. Adds newly-cited library entries to refs.bib, keeps
--             everything else; on a clash the .bib version wins. Never removes
--             or overwrites, so it is safe to run on every compile/preview.
--   prune() — DESTRUCTIVE and interactive. The only path that removes uncited
--             entries or updates drifted ones. Manual, never automatic.

local M = {}

-- Sync refs.bib from the papis library for the document containing `file`.
--
-- Synchronous on purpose: it runs immediately before a compile/preview, so a
-- freshly-cited paper resolves on the first pass rather than the second. The
-- script writes only when the .bib actually changes, so latexmk -pvc sees a
-- stable file and does not enter a compile loop.
function M.sync(file)
  if file and file ~= "" then
    vim.fn.system({ "papis-bib", file })
  end
end

-- Interactive bib cleanup for the current buffer's directory.
--
-- Routed through :! rather than vim.fn.system so the script's batch y/N
-- confirmation prompts get a real terminal to draw on.
function M.prune()
  vim.cmd("!papis-bib --prune " .. vim.fn.shellescape(vim.fn.expand("%:p:h")))
end

-- Register the buffer-local <leader>lb prune mapping. Identical for tex and
-- typst, hence shared; call from each filetype's FileType callback.
function M.map_prune(bufnr)
  vim.keymap.set("n", "<leader>lb", M.prune, {
    buffer = bufnr or true,
    desc = "Prune bib (papis-bib --prune)",
  })
end

return M
