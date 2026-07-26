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
-- Runs in a :terminal split, NOT `:!`. Nvim connects `:!` to a pipe rather than
-- a pty (see |vim_diff|: ":! does not support interactive commands"), so the
-- script's `[[ ! -t 0 ]]` guard fires and it aborts before asking anything.
-- A terminal buffer is the only way to give its batch y/N prompts a real tty.
function M.prune()
  local dir = vim.fn.expand("%:p:h")
  vim.cmd("botright 15new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = "wipe"

  vim.fn.jobstart({ "papis-bib", "--prune", dir }, {
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        -- Leave terminal mode so the output is scrollable and `q` reaches us.
        if vim.api.nvim_get_current_buf() == buf then
          vim.cmd("stopinsert")
        end
        vim.keymap.set("n", "q", "<cmd>close<cr>", {
          buffer = buf,
          desc = "Close papis-bib output",
        })
        if code ~= 0 then
          vim.notify("papis-bib --prune exited " .. code, vim.log.levels.WARN)
        end
      end)
    end,
  })

  vim.cmd("startinsert")
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
