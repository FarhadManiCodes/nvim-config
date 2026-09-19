-- ~/.config/nvim/lsp/basedpyright.lua
-- BASEDPYRIGHT (PYTHON - SECONDARY)
-- Modern Python type checker and LSP (fork of Pyright)
-- Installation: uv tool install basedpyright (one global install; it discovers
-- each project's environment itself, no per-venv copy needed)

return {
  cmd = { "basedpyright-langserver", "--stdio" },

  filetypes = { "python" },

  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    ".git",
  },

  -- basedpyright settings
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "basic",          -- basic, standard, or strict
        autoSearchPaths = true,              -- Auto-detect Python paths
        useLibraryCodeForTypes = true,       -- Use library code for type info
        diagnosticMode = "openFilesOnly",    -- Only check open files (lighter on large repos)
        -- Adding ruff made three diagnostics arrive twice. They are split by
        -- which side owns the useful CODE ACTION, not by which is "faster":
        --
        --   unused import / unused variable -> ruff. Its quickfix removes them,
        --     and there is nothing basedpyright offers here that ruff does not.
        --     Hence "none" below.
        --   undefined name -> BASEDPYRIGHT, deliberately not ruff. Its
        --     reportUndefinedVariable diagnostic is what carries the
        --     "import json" auto-import action; turning it off left 0 actions
        --     on an undefined name (measured). So it stays on, and F821 is
        --     ignored on ruff's side instead -- see lsp/ruff.lua.
        --
        -- reportUnusedExpression stays because ruff's equivalent (B018) is
        -- outside the selected rules. Type diagnostics stay here regardless:
        -- ruff has no type system at all.
        diagnosticSeverityOverrides = {
          reportUnusedImport = "none",
          reportUnusedVariable = "none",
          reportGeneralTypeIssues = "warning",
        },
      },
    },
  },
}
