# Keymap reference

Leader is `\`. Press it and wait — `which-key` lists everything live (`<leader>?` toggles
it). That popup, not this file, is the authoritative answer: it is built from the `desc =`
field on each real mapping. This file exists for the groups where the *rationale* matters
or where a table is faster to scan than the popup.

`README.md` has the short everyday table. This file holds the full per-plugin detail for
the groups documented nowhere else, plus an index to the ones that live with their
rationale in another document. `docs/keymap-audit-changes.md` is the changelog for
renames — read it before assuming a key was always spelled the way it is now.

## Documented elsewhere

These groups are *not* repeated here; each lives next to the reasoning that explains it.

| Group | Lives in |
|-------|----------|
| LSP — `gd` `gD` `gr` `gi` `gt` `K` `<C-k>`, `<leader>ca/cr/cf/ci/ch`, `<leader>ed` `<leader>eq`, `[d` `]d` `[D` `]D` | `docs/architecture.md` § LSP Configuration |
| Completion, insert mode — `<C-Space>` `<C-n>` `<C-p>` `<Tab>` `<S-Tab>` `<CR>` `<C-e>` `<C-b>` `<C-f>` | `docs/architecture.md` § Completion Configuration |
| AI completion (minuet/Codestral) — `<A-]>` `<A-[>` `<A-A>` `<A-a>` `<A-z>` `<A-e>` | `docs/ai-completion.md` § 5 |
| Debugging — `\d*`, `<F5>` `<F9>` `<F10>` `<F12>`, `<PageUp>`/`<PageDown>` | `docs/dap-config.md` § Keybindings |
| Typst — `<leader>ll` `<leader>ls` `<leader>lp` `<leader>lb` | `docs/architecture.md` § Typst (.typ) |
| Gitsigns — `]c` `[c`, `<leader>hp/hr/hs` | `docs/architecture.md` § Git Integration Workflow |
| vim-dadbod — `<leader>rr` `<leader>rf` | `docs/architecture.md` § Database Configuration |
| Markdown — `<leader>ll` `<leader>lt` `<leader>lm` | `docs/architecture.md` § Markdown |
| vim-tmux-navigator — `<C-h/j/k/l>` `<C-\>` | `docs/architecture.md` § Tmux Integration |

## which-key prefix groups

Defined in `lua/plugins/which-key.lua`. Pressing the prefix alone opens the popup for it.

| Prefix | Group | Prefix | Group |
|--------|-------|--------|-------|
| `<leader>b` | Buffers | `<leader>h` | Git Hunks |
| `<leader>c` | Code | `<leader>l` | LaTeX (relabelled "Markdown" in `.md` buffers) |
| `<leader>d` | Debug | `<leader>p` | Papers |
| `<leader>e` | Env/Diag | `<leader>r` | Run/Search |
| `<leader>f` | Find | `<leader>t` | Theme/UI |
| `<leader>g` | Git Log | `<leader>z` | Focus |

## General & UI (core keymaps)

Defined in `lua/config/keymaps.lua`.

| Key | Mode | Action |
|-----|------|--------|
| `<leader><space>` | normal | Clear search highlighting (`:nohlsearch`) |
| `<leader>bd` | normal | Delete current buffer (`:bdelete`) |
| `<leader>th` | normal | Toggle light/dark theme (`onedark` ⇄ `newpaper`) |
| `<leader>zm` | normal | Toggle minimal UI mode (numbers, sign column, status line) |
| `<Esc><Esc>` | terminal | Exit terminal mode (`<C-\><C-n>`) |
| `<` / `>` | visual | Indent left/right (keeps visual selection) |
| `p` | visual | Paste without replacing register (`"_dP`) |

## Telescope (fuzzy finder)

Defined in `lua/plugins/core.lua`.

| Key | Action |
|-----|--------|
| `<C-p>` | Find files |
| `<leader>bb` | Find buffers |
| `<leader>rg` | Live grep (search text) |
| `<leader>/` | Search in current buffer |
| `<leader>fh` | Help tags |
| `<leader>fr` | Resume last search |
| `<leader>fo` | Recent files |
| `<leader>fs` | Document symbols (functions, classes in current file) |
| `<leader>fS` | Workspace symbols (symbols across entire project) |
| `<leader>gc` | Git commits |
| `<leader>gs` | Git status |

Inside a picker:

| Key | Mode | Action |
|-----|------|--------|
| `<C-j>` / `<C-k>` | insert | Next/previous result |
| `<C-q>` | insert | Send results to the quickfix list and open it |
| `<Esc>` | insert | Close the picker (does not drop to normal mode) |
| `q` | normal | Close the picker |
| `<C-d>` | insert | Delete selected buffer (in `<leader>bb` buffers picker) |

## Oil.nvim (file explorer)

Defined in `lua/plugins/ui.lua`.

| Key | Action |
|-----|--------|
| `-` | Open parent directory |
| `<leader>-` | Open Oil (floating window) |
| `<CR>` | Open the entry under the cursor |
| `<C-s>` | Open in a vertical split |
| `<C-x>` | Open in a horizontal split |
| `<C-t>` | Open in a new tab |
| `<C-p>` | Preview |
| `<C-c>` | Close |
| `<C-r>` | Refresh |
| `_` | Open the current working directory |
| `` ` `` / `~` | `:cd` / `:tcd` to the current Oil directory |
| `gy` | Copy file path (a directory gets a trailing `/`) |
| `gx` | Open file externally |
| `gs` | Change sort order |
| `g.` | Toggle hidden files |
| `g\` | Toggle trash |
| `g?` | Show Oil's own help |

`<C-x>` rather than Oil's default `<C-h>`: `<C-h/j/k/l>` are vim-tmux-navigator's
split/pane movement everywhere else, and a buffer-local map wins over a global one, so Oil
was the single place those four keys did not navigate. The trade-off is that `<C-x>`
otherwise falls through to the built-in decrement-number, which is unavailable while
renaming in Oil. Dropping Oil's `<C-h>` needs an explicit `["<C-h>"] = false` — the keymap
table is *merged* into Oil's defaults, not substituted for them, so simply omitting the key
leaves Oil's own binding in place (`:h oil-config`).

## mini.bracketed (navigation)

Defined in `lua/plugins/editor.lua`. Only what Neovim has no built-in for:

| Key | Action |
|-----|--------|
| `]f` / `[f` | Next/previous file in the directory |
| `]i` / `[i` | Next/previous line at a different indent (Python, YAML) |
| `]x` / `[x` | Next/previous merge-conflict marker |
| `]y` / `[y` | Cycle yank history after a paste |

Neovim built-ins — mini.bracketed's versions of these are disabled:

| Key | Action |
|-----|--------|
| `]b` / `[b` | Next/previous buffer (`:bnext`) |
| `]d` / `[d` | Next/previous diagnostic (`vim.diagnostic.jump`) |
| `]q` / `[q` | Next/previous quickfix (`:cnext`) |
| `]l` / `[l` | Next/previous loclist (`:lnext`) |
| `]t` / `[t` | Next/previous tag (`:tnext`) |
| `]c` / `[c` | Next/previous git hunk (gitsigns, buffer-local) |

## TreeSJ (split/join code)

Defined in `lua/plugins/editor.lua`.

| Key | Action |
|-----|--------|
| `gS` | Split code structure |
| `gJ` | Join code structure |
| `gM` | Toggle split/join |

## Treesitter text objects (selection)

Defined in `lua/plugins/treesitter.lua`.

| Key | Action |
|-----|--------|
| `af` / `if` | Function outer/inner |
| `ac` / `ic` | Class outer/inner |
| `aa` / `ia` | Argument/parameter outer/inner |
| `ab` / `ib` | Block outer/inner |
| `al` / `il` | Loop outer/inner |
| `ai` / `ii` | Conditional outer/inner |
| `a/` | Comment |
| `]m` / `[m` | Next/previous function START |
| `]M` / `[M` | Next/previous function END |
| `]]` / `[[` | Next/previous class START |
| `][` / `[]` | Next/previous class END |
| `<leader>tc` | Toggle treesitter context (sticky scope header) |

SQL gets these from this config's own `queries/sql/textobjects.scm`, not from upstream —
see `docs/architecture.md` § SQL. In shell buffers the class motions are a deliberate
no-op.

## Native commenting

Neovim 0.10+ built-in, no plugin needed.

| Key | Action |
|-----|--------|
| `gcc` | Toggle comment line |
| `gc{motion}` | Comment with motion (e.g. `gcip` for paragraph) |

## vimtex (LaTeX)

Defined in `lua/plugins/documents.lua`; buffer-local to `.tex`.

| Key | Action |
|-----|--------|
| `<leader>ll` | Sync `refs.bib` from papis (additive), then compile |
| `<leader>lv` | View PDF |
| `<leader>lt` | Toggle TOC |
| `<leader>lc` | Clean auxiliary files |
| `<leader>ls` | Stop compilation |
| `<leader>lb` | `papis-bib --prune` — interactive bib cleanup, in a `:terminal` split |

`<leader>ll` is not a bare compile: it syncs newly-cited papers into `refs.bib` first so a
fresh citation resolves on the first pass. The sync is additive and safe on every compile;
`<leader>lb` is the only destructive path. Both are shared with Typst — see
`lua/config/papis_bib.lua`. In the `<leader>lb` output split, `q` closes it once the script
exits.

## Twilight (focus mode)

Defined in `lua/plugins/ui.lua`.

| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle twilight (for presentations) |

## rainbow_csv

Defined in `lua/plugins/data-tools.lua`. Buffer-local, only in `.csv`/`.tsv` buffers.

| Key | Action |
|-----|--------|
| `<leader>cc` | Align CSV columns — **rewrites the buffer**, padding every field |
| `<leader>cs` | Strip surrounding spaces from fields, including alignment padding |
| `<leader>cq` | RBQL query |

Avoid `<leader>cc` where surrounding spaces are data: alignment removes them before
adding padding. `<leader>cs` also strips surrounding spaces and cannot restore the
original text. Use undo to recover from accidental alignment.

## vim-envx (environment variables)

Defined in `lua/plugins/data-tools.lua`.

| Key | Action |
|-----|--------|
| `<leader>ev` | Expand env variable (replace `$VAR` with its value) |
| `<leader>eev` | Expand all env vars on line |
| `<leader>ex` | Extract selection as env variable (visual mode) |

`ex` breaks the `ev*` pattern; it was `evv` before, renamed to clear a which-key prefix
overlap.

## papis (paper library)

Defined in `lua/plugins/papis.lua`.

| Key | Action |
|-----|--------|
| `<leader>pp` | Search papers, insert citation |
| `<leader>pf` | Open the paper's file at cursor |
| `<leader>pn` | Open the paper's notes |
| `<leader>pi` | Paper info popup |
| `<leader>pe` | Edit the papis entry |

All but `<leader>pp` act on the citation key under the cursor.

## Easy to miss

| Key | Where | Action |
|-----|-------|--------|
| `<S-CR>` | insert, `lua/config/completion.lua` | Insert a literal newline even with a completion item selected — the one way to get a plain `<CR>` without accepting |
| `<Esc>` / `q` | DAP float, `lua/plugins/dap.lua` | Close a `\dh` hover, `\ds` scopes or `\df` frames window |
| `q` | papis-bib split, `lua/config/papis_bib.lua` | Close the `<leader>lb` output once the script exits |
