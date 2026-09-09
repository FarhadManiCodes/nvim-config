# Neovim-specific instructions

This is a separate Git repository, included as a dotfiles submodule and symlinked
to `~/.config/nvim`. Preserve existing changes here. Config commits, parent pointer
updates, and lazy.nvim plugin updates are separate operations.

Read `README.md` and the relevant sections of `docs/architecture.md` before edits;
the latter preserves the detailed Claude guidance, implementation constraints, and
filetype-specific behavior. Consult `docs/ai-completion.md`, `docs/dap-config.md`,
and `docs/lsp-testing-guide.md` for those tasks. `CLAUDE.md` imports this file, so this is
the single source of Neovim guardrails. Verify dated examples against current code.

## Architecture and conventions

- Preserve startup order: options → plugins → LSP → autocmds → keymaps. Set leader
  (`\`) before plugins. Blink loads eagerly; its plugin config loads `completion.lua`.
- Use native `vim.lsp.config` / `vim.lsp.enable`; do not add nvim-lspconfig, Mason,
  or restore nvim-cmp. Preserve explicit plugin loading and the blink 1.x pin.
- Keep theme configuration and plugin declarations synchronized in
  `lua/config/themes.lua` and `lua/plugins/themes.lua`. Preserve desktop-theme
  integration, manual session override, and fallback persistence.
- New filetypes need detection and indentation in `autocmds.lua` and appropriate
  parser entries in `lua/plugins/treesitter.lua`. Match existing indentation.
- Preserve large-file guards: treesitter stops above 1 MB; expensive features,
  LSP and completion are disabled for the >10 MB large-file flag.
- Keep local SQL text objects and the `;; extends` header in shell queries.
  Preserve intentional shell class-motion no-ops and filetype-specific runtime mappings;
  do not replace `no_python_maps` with the blanket `no_plugin_maps` switch.

## LSP, formatting, and secrets

- Basedpyright is installed as a uv tool and discovers project environments.
  Older per-venv installation examples in the retained reference are historical.
- Ruff owns unused-import/variable diagnostics; Basedpyright owns undefined names
  to retain auto-import actions. Ruff settings belong in `init_options.settings`
  with filesystem-first preference. Use `ruff server`, not standalone ruff-lsp.
- Format on save only for `*.c, *.cpp, *.cc, *.h, *.hpp, *.typ`. Python and Lua
  formatting stays manual (`<leader>cf`). Preserve C/C++ pre-format sanitization
  and clangd's project formatting policy. Do not bulk-format this repository.
- AI completion stays manual and separate from Blink. Load Codestral credentials
  into the in-process secrets table, not `vim.env` or shell startup files.
- Never hardcode database credentials. Dadbod uses singular `g:db` or buffer/tab
  connections and environment URLs; `g:dbs` belongs to the uninstalled dadbod-ui.

## Notebook and document safeguards

- Keep jupytext's guarded eager loading; `.ipynb` is detected as JSON, so an `ft=ipynb`
  trigger cannot protect conversion. Resolve jupytext on each open, venv first.
- Missing converter, malformed/empty notebook, or failed reads must fall back to
  raw JSON without truncation. Preserve wrapped read handlers, their non-truthy
  return, and `lua/jupytext/health.lua` shadowing. Read the full notebook section.
- Typst uses system tinymist, bundled typstyle and Firefox preview. Preserve the
  root-document preview workflow, additive bibliography sync, and interactive-only
  `papis-bib --prune` in a terminal split. LaTeX remains supported alongside Typst.
- Markdown preview is the local module, not a plugin. Preserve buffer-local prose
  mappings, spelling behavior, and document-specific completion sources.

## Validation

Use `:checkhealth` and relevant sections, `:LspInfo` with a representative buffer,
and the documented manual scenarios. Restart after autocmd/LSP changes; `:restart`
requires Neovim 0.12+. Test in a Git repository to cover vim-obsession session tracking.
Use the theme toggle for theme changes and check actual mappings after keymap changes.
`:Lazy sync` updates plugins and the tracked lockfile; run it for intended plugin
changes, not as a generic test. Report any health warnings or untested interactive behavior.
