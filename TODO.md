# TODO — Neovim config

Open work and decisions, reviewed 2026-09-20. Accepted behavior and update policy
belong in [architecture.md](docs/architecture.md#plugin-management); completed
work belongs in commit history.

## Interactive acceptance

Headless checks passed for large-file highlighting guards, fold isolation,
Telescope setup, fzf extension loading and native breakpoint listing. Telescope
health reported no warnings. Interactive behavior remains untested.

- [ ] In a fresh Neovim process inside a Git repository, exercise all Telescope
      mappings in `lua/plugins/core.lua` and paper search (`<leader>pp`). Check
      highlighted previews, focus, insert/normal-mode mappings, quickfix export,
      empty results and paths containing spaces.
- [ ] Exercise `<leader>dl` during a real debugging session: stop at a breakpoint,
      list, and walk the quickfix entries with `]q`/`[q`. Headless checks cover the
      list contents, not how it behaves mid-session.
- [ ] Verify Treesitter motions and selections against the fixtures below. Check
      counts, end-of-file behavior, selection lookahead and jump history with
      `:jumps` and `<C-o>/<C-i>`. Inspect buffer-local mappings when behavior differs.
- [ ] Check native `an/in` and `]n/[n` selection; preserve Blink's `<C-Space>`.
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
`~/.local/share/nvim/site/parser` and 37 older parsers inside
`~/.local/share/nvim/lazy/nvim-treesitter/parser/`. Only the latter contains
`zathurarc`, which the current upstream parser registry no longer supplies.
Removing or reinstalling the clone could lose it.

- [ ] Inspect effective parser paths before considering removal of the older set.
      Decide whether to preserve the orphan or accept losing its highlighting.
- [ ] Before the next Treesitter update, rehearse the
      [backup and rollback procedure](docs/architecture.md#plugin-management).
      Include the orphan, preserve symlinks, and store backups outside the repository.
      Restore the selected plugin revisions and matching parser assets, restart,
      and verify representative files. A lockfile restore alone is insufficient.

## Dormant-plugin review

These dates are evidence from the original 2026-09-20 audit, not live status.
Quiet history alone does not establish abandonment. Retain the plugins unless
a concrete defect or requirement warrants a change.

| Plugin | Last tracked-branch commit | What to check |
|--------|----------------------------|---------------|
| jupytext.nvim | 2024-04-05 | Converter compatibility and the guarded raw-JSON fallback |
| rainbow_csv | 2024-07-04 | Vimscript commands and external Python/RBQL tooling |
| sqlite.lua | 2025-03-14 | Native-library compatibility through papis.nvim |
| vim-envx | 2025-06-09 | Environment commands |
| nvim-dap-virtual-text | 2025-05-25 | Compatibility with nvim-dap and Treesitter APIs |

- [ ] At the next quarterly review, inspect upstream maintenance notices,
      compatibility reports and the selected branches. Follow the maintenance
      routine in `docs/architecture.md`; release lag and dormancy are separate checks.

The notebook survey found no compelling replacement for the guarded jupytext
integration. `goerz/jupytext.nvim` was the closest alternative; migration would
require porting or revalidating eager loading, per-open venv resolution and
non-destructive fallback. Direct-JSON alternatives such as `ajbucci/ipynb.nvim`
use a different conversion path. Molten and Quarto address execution/authoring
rather than replacing conversion. Detailed historical comparisons remain in
`git log -p -- TODO.md`.
