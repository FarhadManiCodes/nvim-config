# Keymap reference

Leader is `\`. Press it and wait — `which-key` lists everything live (`<leader>?` toggles
it). That popup, not this file, is the authoritative answer: it is built from the `desc =`
field on each real mapping. This file exists for the groups where the *rationale* matters
or where a table is faster to scan than the popup.

`README.md` has the short everyday table. This file holds the full per-plugin detail for
the groups that are documented nowhere else.

## Telescope (fuzzy finder)

Defined in `lua/plugins/core.lua`.

| Key | Action |
|-----|--------|
| `<C-p>` | Find files |
| `<leader>b` | Find buffers |
| `<leader>rg` | Live grep (search text) |
| `<leader>/` | Search in current buffer |
| `<leader>fh` | Help tags |
| `<leader>fr` | Resume last search |
| `<leader>fo` | Recent files |
| `<leader>fs` | Document symbols (functions, classes in current file) |
| `<leader>fS` | Workspace symbols (symbols across entire project) |
| `<leader>gc` | Git commits |
| `<leader>gs` | Git status |

## Oil.nvim (file explorer)

Defined in `lua/plugins/ui.lua`.

| Key | Action |
|-----|--------|
| `-` | Open parent directory |
| `<leader>-` | Open Oil (floating window) |
| `gy` (in Oil) | Copy file path |
| `gx` (in Oil) | Open file externally |

See `lua/plugins/ui.lua` for full Oil keymaps.

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

## Native commenting

Neovim 0.10+ built-in, no plugin needed.

| Key | Action |
|-----|--------|
| `gcc` | Toggle comment line |
| `gc{motion}` | Comment with motion (e.g. `gcip` for paragraph) |
| `gbc` | Toggle block comment |

## vimtex (LaTeX)

Defined in `lua/plugins/documents.lua`.

| Key | Action |
|-----|--------|
| `<leader>ll` | Compile LaTeX |
| `<leader>lv` | View PDF |
| `<leader>lt` | Toggle TOC |
| `<leader>lc` | Clean auxiliary files |
| `<leader>ls` | Stop compilation |

## Twilight (focus mode)

Defined in `lua/plugins/ui.lua`.

| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle twilight (for presentations) |

## rainbow_csv

Defined in `lua/plugins/data-tools.lua`. Buffer-local, only in `.csv`/`.tsv` buffers.

| Key | Action |
|-----|--------|
| `<leader>cc` | Align CSV columns |
| `<leader>cq` | RBQL query |

## vim-envx (environment variables)

Defined in `lua/plugins/data-tools.lua`.

| Key | Action |
|-----|--------|
| `<leader>ev` | Expand env variable (replace `$VAR` with its value) |
| `<leader>eev` | Expand all env vars on line |
| `<leader>ex` | Extract selection as env variable (visual mode) |

`ex` breaks the `ev*` pattern; it was `evv` before, renamed to clear a which-key prefix
overlap.
