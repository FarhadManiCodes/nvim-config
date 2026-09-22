# TODO — Neovim config

Open work and decisions, reviewed 2026-09-20. Accepted behavior and update policy
belong in [architecture.md](docs/architecture.md#plugin-management); completed
work belongs in commit history.

## Interactive acceptance

Headless checks passed for large-file highlighting guards, fold isolation,
Telescope setup, fzf extension loading and native breakpoint listing. Telescope
health reported no warnings. `tests/motions.lua` now asserts that motions and text
objects reach the right nodes in python, c, zsh and sql. What remains below needs a
human: rendering, focus, how things feel, and a live debug session.

- [ ] In a fresh Neovim process inside a Git repository, exercise all Telescope
      mappings in `lua/plugins/core.lua` and paper search (`<leader>pp`). Check
      highlighted previews, focus, the in-picker mappings and quickfix export.
      `tests/runtime.lua` already covers picker resolution, the fzf extension
      actually loading, empty results not erroring, and the configured rg arguments
      matching under a path containing spaces. Driving a floating prompt headlessly
      is async and flaky, so the in-picker keys stay here deliberately.
- [ ] Exercise `<leader>dl` during a real debugging session: stop at a breakpoint,
      list, and walk the quickfix entries with `]q`/`[q`. Headless checks cover the
      list contents, not how it behaves mid-session.
- [x] Treesitter motions and selections for python, c, zsh and sql, including
      counts, function ends, end-of-file, selection lookahead and the `set_jumps`
      jump — `tests/motions.lua`, 23 assertions, proven to fail when the local zsh
      query is removed. `ai`/`ii` and native `an` are covered there too.
- [ ] Markdown/Typst/LaTeX prose (last fixture row): heading overrides, injected
      highlighting, spell exclusions and document mappings. Not in the harness —
      these are rendering and buffer-local behaviour, not node selection.
- [x] `]n`/`[n` sibling selection — `tests/motions.lua`. Blink's ownership of
      `<C-space>` — `tests/runtime.lua`, which asserts both that blink still claims
      it and that no Vim mapping shadows it, since blink handles the key internally
      rather than through `maparg`.
- [ ] Exercise folds, context toggle, treesj, twilight, Markdown rendering and DAP
      inline values.

| Fixture | Expected behavior |
|---------|-------------------|
| Python with nested functions/classes and fake `def` in strings/comments | Function/class start and end motions reach syntax nodes; preserve `no_python_maps` |
| C/C++ functions/classes | `]m/[m`, `]M/[M`, `]]/[[`, `][/[]`, and `af/if/ac/ic` select the expected boundaries |
| Zsh functions, brace/do blocks and quoted arguments | `af/if`, `ab/ib`, `aa/ia` work; class motions remain no-ops; preserve `;; extends` |
| SQL functions and BEGIN/END blocks | Local textobjects and function motions work; buffer-local class keys retain BEGIN/END navigation |
| Markdown headings and fenced code; Typst/LaTeX prose | Heading overrides, injections, spell exclusions and document mappings remain intact |

## Parser backup and restore rehearsal

The 2026-09-20 inventory found 38 declared parsers in
`~/.local/share/nvim/site/parser` (the configured install dir) and a stale set of
37 inside `~/.local/share/nvim/lazy/nvim-treesitter/parser/`. `zathurarc` is the
only parser that exists solely in the clone; upstream no longer supplies it.

**Orphan decision, 2026-09-20: accept the loss.** It highlights one 682-byte
config file and cannot be reinstalled, so it is not worth hand-restoring a deleted
grammar after every update. No backup, no pinning. It still works today and is
left in place; when a reinstall or `:Lazy clean` removes it, `zathurarc` opens as
plain text and nothing else changes. Rationale is in `lua/plugins/treesitter.lua`.

- [x] Backup and restore rehearsed 2026-09-20 against an isolated copy; the real
      parser dir was only read. Restoring `parser`/`parser-info` from a tar archive
      took a deliberately broken install from zero highlight captures back to
      working. Two corrections went into
      [the procedure](docs/architecture.md#plugin-management): `site/queries/` is 41
      symlinks into the plugin clone, so query content comes back with
      `:Lazy restore` rather than from the archive, and a restore must be verified by
      counting captures — `pcall` and an attached highlighter both report health on a
      broken install.

## Notebooks: keep jupytext, try euporie for execution

Researched 2026-09-20, no action taken. Three tiers, pick by what the notebook does:

1. **Edit only** — nvim + jupytext, as now. Unchanged.
2. **Run cells, matplotlib, standard ipywidgets** — `uvx euporie notebook x.ipynb`.
   Terminal, vim keys, its own LSP client (ruff/basedpyright via TOML), sixel plots
   (`foot.ini` already sets `sixel=yes`). Healthiest project in the space.
3. **plotly, bokeh, 3D, geo, lab extensions** — browser, genuinely required. euporie
   has no renderer for those and falls back to a text placeholder.

Do **not** migrate to `goerz/jupytext.nvim` (dormant too), to a direct-JSON plugin
(alpha, and it would make us own notebook parsing — data loss as the failure mode),
or to a browser vim mode (`jupyterlab-vim`'s last release is 2024-09, more dormant
than what we run).

- [ ] **On the next Neovim API break in jupytext.nvim, absorb it instead of shimming
      again.** We already carry 182 lines wrapping a 265-line plugin, and the spec
      exists mostly to stub `vim.validate` around `setup()`. Rewriting the
      `BufReadCmd`/`BufWriteCmd` lifecycle risks mangled notebooks, so it needs a
      forcing function — not a quiet afternoon.

## Settled: staying on telescope

Considered replacing telescope with a snacks.picker migration on 2026-09-20 and
**declined**. Recorded so it is not re-argued, and because the constraint below is
expensive to rediscover.

- **papis hard-requires telescope or snacks.** `papis.nvim/lua/papis/search/init.lua:78-96`
  has exactly two providers and `error()`s if neither plugin is present; `<leader>pp` never
  registers, because the keymap is added inside the successful setup branch. So fzf-lua and
  mini.pick — the single-purpose pickers that actually fit a one-tool-one-task preference —
  are out unless someone writes and maintains a third provider.
- **That leaves telescope or snacks**, and snacks means enabling 1 of its 31 modules. It
  would drop two plugins and the `make` dependency, but it is a suite, not a tool.
- **The migration's risk is silent.** `file_ignore_patterns` (`lua/plugins/core.lua:80-107`)
  holds Lua patterns; snacks `exclude` is glob, applied as `fd -E` / `rg -g !`
  (`snacks/picker/source/files.lua`). A bad translation does not error — build artifacts
  simply return to results in a CMake tree.
- **Nothing is broken.** Telescope is at `40aedd8`, maintained, and every integration
  passes. The old "only if the bump goes badly" trigger never fired.

Revisit only if the interactive acceptance above turns up something telescope actually does
badly — that would say what a replacement must fix, which "it is the LazyVim default" does not.

## Dormant-plugin review

**Reviewed 2026-09-20.** None archived or disabled upstream. Verdict unchanged:
keep all, act on defects rather than on quiet commit feeds. Next review 2026-12.

| Plugin | Tracked-branch tip | Status |
|--------|--------------------|--------|
| jupytext.nvim | 2024-04-05 | Issue #39 (`vim.health.report_start` removed) still open after 16 months — the local `lua/jupytext/health.lua` shim is permanent, not a stopgap |
| rainbow_csv | 2024-07-05 | Vimscript and an external Python/RBQL core; little Neovim API to rot |
| sqlite.lua | 2025-03-14 | Reached only through papis.nvim; native binding, so ABI not Lua API is the risk |
| nvim-dap-virtual-text | 2025-05-25 | **Highest risk, confirmed.** #97 (2026-06) and #98 (2026-09) are open correctness bugs with zero maintainer replies |

`vim-envx` left the list: it is `FarhadManiCodes/vim-envx`, our own repository, so
its quiet history is a choice rather than an upstream risk.

Method note, since it bit again: check the *tracked branch* tip, not GitHub's
`pushed_at`. rainbow_csv reports `pushed_at` 2025-10-04 against a `master` tip of
2024-07-05, because `pushed_at` counts any branch.

- [ ] Watch `nvim-dap-virtual-text` #97 — wrong value shown for same-named variables
      in different scopes. It would surface as misleading inline values during a real
      C++ session, so check it while running the playground DAP pass.

The notebook survey found no compelling replacement for the guarded jupytext
integration. `goerz/jupytext.nvim` was the closest alternative; migration would
require porting or revalidating eager loading, per-open venv resolution and
non-destructive fallback. Direct-JSON alternatives such as `ajbucci/ipynb.nvim`
use a different conversion path. Molten and Quarto address execution/authoring
rather than replacing conversion. Detailed historical comparisons remain in
`git log -p -- TODO.md`.

## Upstream workaround: orphaned server exit

- [ ] On each Neovim upgrade, check whether the `OrphanExit` autocmds in
      `lua/config/autocmds.lua` can go. An `--embed` server whose UI is gone waits forever
      at the exit prompt after an exit-time error, ignoring SIGTERM (it held a reboot for
      90s on 2026-09-22). A fix for neovim#41940, the ShaDa rename race, removes only one
      trigger and is not enough. Check: `chmod 400` a copy of `main.shada`, run
      `nvim -u NONE -i <copy>` in a terminal, close the terminal; remove the workaround
      once no `nvim --embed` process survives.
