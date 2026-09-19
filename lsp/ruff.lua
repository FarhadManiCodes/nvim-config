-- ~/.config/nvim/lsp/ruff.lua
-- RUFF (PYTHON LINT + FORMAT; PAIRS WITH BASEDPYRIGHT, DOES NOT REPLACE IT)
-- Division of labour: ruff has no type system at all, and basedpyright reports
-- supports_method("textDocument/formatting") = false. So ruff owns formatting
-- and the fast lint rules, basedpyright owns types, completion, hover and
-- navigation. Neither is redundant.
--
-- Installation: sudo pacman -S ruff. Native binary (Depends On: glibc, libgcc
-- only) -- it parses Python itself, so it needs neither the venv nor a matching
-- interpreter, and `target-version`, inferred from requires-python, is what makes
-- one recent ruff correct for every project. `ruff server` is the language server
-- itself; the old standalone ruff-lsp package is deprecated and archived.
--
-- Formatting is MANUAL via <leader>cf. *.py is deliberately absent from the
-- format-on-save glob in lua/config/lsp.lua: auto-reformatting other people's data-engineering
-- code on save buries real diffs.

return {
  cmd = { "ruff", "server" },

  filetypes = { "python" },

  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },

  -- ruff server reads its configuration from initializationOptions.settings,
  -- NOT from `settings` -- passing it there is silently ignored (measured: the
  -- select below had no effect at all until it moved here).
  init_options = {
    settings = {
      -- A project's own pyproject.toml/ruff.toml must win over anything set
      -- here, or every repo silently gets this machine's opinions.
      configurationPreference = "filesystemFirst",
      lint = {
        -- Explicit, because ruff's defaults are broader than they look:
        -- measured with no config present, they also raise I001 (isort) and
        -- B018 (bugbear), which is noise on pre-existing code. E4 imports,
        -- E7 statements, E9 syntax/IO errors, F pyflakes. Widen by adding here.
        select = { "E4", "E7", "E9", "F" },
        -- F821 is basedpyright's, not ruff's. Both detect undefined names, but
        -- ONLY basedpyright's diagnostic carries the "import json" code action
        -- -- auto-import is attached to reportUndefinedVariable, so suppressing
        -- that to remove the duplicate silently cost auto-import entirely
        -- (measured: basedpyright offered 0 actions on an undefined name).
        -- Dropping ruff's half instead keeps one report AND the action.
        -- basedpyright is the better detector here anyway: it knows imports,
        -- scopes and stubs, where F821 is scope analysis alone.
        ignore = { "F821" },
      },
    },
  },
}
