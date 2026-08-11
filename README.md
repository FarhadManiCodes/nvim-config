# nvim-config

Neovim configuration for HPC/CFD work (C++, Trilinos, deal.II) with data engineering
on the side (Python, SQL, Jupyter) and a writing stack (LaTeX, Typst, Markdown).

Lua, modular, `lazy.nvim` for plugins. LSP uses the **native `vim.lsp.config` API** —
no `nvim-lspconfig`, no Mason. External tools are installed by hand via the system
package manager.

## Requirements

- Neovim **0.11+** (developed on 0.12; `:restart` and native treesitter selection assume 0.12)
- `git`, `ripgrep`, `fd`, a C compiler (treesitter parsers), `make` (telescope-fzf-native)
- Language servers, installed as needed:
  ```bash
  sudo pacman -S clang bash-language-server shellcheck \
                 yaml-language-server vscode-json-languageserver tinymist
  uv pip install basedpyright        # per-venv
  ```
- Optional, per feature: `gdb` + `debugpy` (DAP), `psql` / `sqlite3` (dadbod),
  `cmark-gfm` + `vimb` + `python3` (Markdown preview), `sioyek` (LaTeX viewer),
  `papis` (bibliography)

## Install

```bash
git clone git@github.com:FarhadManiCodes/nvim-config.git ~/.config/nvim
nvim   # lazy.nvim bootstraps itself and installs everything
```

Then `:checkhealth` to see what's missing.

## Layout

```
init.lua              # 3 phases: bootstrap → options/plugins/lsp → autocmds/keymaps
lua/config/           # options, lazy, keymaps, autocmds, themes, lsp, completion,
                      # dap_*, md_preview, papis_bib, secrets, state
lua/plugins/          # lazy.nvim specs: init, treesitter, themes, dap, papis,
                      # minuet, which-key
queries/sql/          # treesitter text objects for SQL (not shipped upstream)
docs/                 # ai-completion.md, keymap audit
```

Load order in `init.lua` is deliberate — `options → plugins → lsp → autocmds → keymaps`.
LSP must come after plugins because it asks `blink.cmp` for capabilities.

## What's set up

- **LSP** — clangd, basedpyright, bashls, yamlls, jsonls, tinymist. Inlay hints on,
  virtual text off, format-on-save for C/C++/Python/Typst.
- **Completion** — `blink.cmp` (lsp/buffer/path), tuned low-noise: nothing preselected,
  docs on demand, no ghost text. Per-filetype source overrides.
- **AI** — `minuet-ai` → Codestral FIM, **manual only** (`<A-]>`), on its own virtual-text
  frontend so it never sits on the completion hot path. Key read from
  `~/.config/secrets/codestral.env`, never exported to child processes.
- **Treesitter** — highlighting, indent, folding (`vim.treesitter.foldexpr`), text objects,
  sticky context.
- **Debugging** — `nvim-dap` with gdb (C/C++) and debugpy (Python), `<F5>`-driven.
- **Writing** — vimtex (LaTeX), typst-preview (Typst, live in Firefox), a self-contained
  Markdown preview module with KaTeX, papis for citations.
- **Data** — vim-dadbod, rainbow_csv + RBQL, and jupytext for editing `.ipynb` as markdown
  (needs a `jupytext` CLI in the project venv or on `PATH`; without one, notebooks open as
  raw JSON rather than being mangled).
- **Performance** — bytecode cache, unused providers/plugins off, three-tier large-file
  guard (10 MB: LSP/undo/syntax off; 1 MB: treesitter off; completion off per-buffer).

37 plugins, pinned in `lazy-lock.json`.

## Keys

Leader is `\`. Press it and wait — `which-key` lists everything (`<leader>?` toggles it).

| Key | |
|---|---|
| `gd` `gr` `K` | definition / references / hover |
| `<leader>ca` `<leader>cr` `<leader>cf` | code action / rename / format |
| `<leader>ed` `[d` `]d` | diagnostic float / prev / next |
| `<C-p>` `<leader>rg` `<leader>bb` | files / grep / buffers (telescope) |
| `<leader>-` | file browser (oil) |
| `<leader>hp` `<leader>hs` `<leader>hr` | hunk preview / stage / reset |
| `<leader>ll` | compile+preview (tex, typ, md) |
| `<leader>pp` | search papers, insert citation |
| `<leader>rr` `<leader>rf` | run SQL selection / file |
| `<leader>th` | toggle theme (onedark ⇄ newpaper) |
| `<C-h/j/k/l>` | move across splits *and* tmux panes |

Arrow keys are disabled on purpose. The system clipboard is not synced — use `"+y` / `"+p`.

## Notes

- Themes persist across restarts (`~/.local/share/nvim/last_theme.txt`).
- `exrc` is on: per-project `.nvim.lua` is read. Never hardcode credentials there —
  use `os.getenv()`.
- clangd needs `compile_commands.json`:
  `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build && ln -s build/compile_commands.json .`
- `CLAUDE.md` holds the long-form rationale for most decisions here.
