# Neovim configuration reference

Rationale extracted from `nvim/CLAUDE.md` on 2026-09-06; that duplicate became an
`@AGENTS.md` import on 2026-09-09. Paths are relative to `nvim/` unless stated
otherwise. Verify historical examples and measurements before acting.

## Overview

Neovim 0.12+, modular Lua and lazy.nvim for HPC/CFD (C++, Trilinos, deal.II),
data engineering (Python, SQL, Jupyter) and writing.

## Configuration Architecture

### Initialization Flow (init.lua)
Three phases: bootstrap (leader `\`, bytecode cache), core (`options → plugins → lsp`),
then UI (`autocmds → keymaps`). Preserve this order and set the leader before
`require("config.lazy")`. Blink loads eagerly so that
`lsp.lua` can call `require('blink.cmp').get_lsp_capabilities()` before servers attach.
Its plugin `config` in `plugins/core.lua` loads `completion.lua`, not `init.lua`.

### Module Structure

```
lua/
├── config/              # Core configuration modules
│   ├── options.lua      # Editor behavior, performance, and display settings
│   ├── lazy.lua         # Plugin manager bootstrap and configuration
│   ├── keymaps.lua      # Global keybindings (reference: docs/keymaps.md)
│   ├── autocmds.lua     # Event-driven behaviors and file-type detection
│   ├── themes.lua       # Theme application and toggling logic
│   ├── state.lua        # Tiny single-line persisted state under stdpath("data")
│   ├── md_preview.lua   # Self-contained markdown preview (cmark-gfm + KaTeX + vimb)
│   ├── markdown.lua     # Markdown helpers: heading TOC, $$ math-block collapse
│   ├── papis_bib.lua    # Shared front-end for the papis-bib script (tex + typst)
│   ├── jupytext_resolve.lua   # Where to look for the jupytext CLI (spec + healthcheck)
│   ├── dap_adapters.lua       # Debug adapters (gdb native DAP)
│   ├── dap_configurations.lua # Debug launch configurations (C++/ASAN/pybind)
│   ├── lsp.lua          # Shared LSP setup: attach keymaps, capabilities, enable list
│   ├── secrets.lua      # Load ~/.config/secrets/*.env into an IN-PROCESS table
│   │                    # (NOT vim.env -- see the AI Completion section)
│   └── completion.lua   # blink.cmp completion engine setup
└── plugins/             # Plugin specifications (lazy.nvim format)
    ├── core.lua         # telescope + blink.cmp: fast lookup/insert infrastructure
    ├── editor.lua       # Filetype-agnostic editing: surround, treesj, autopairs,
    │                    # tmux nav, obsession, gitsigns
    ├── data-tools.lua   # dadbod, rainbow_csv, vim-envx (data engineering)
    ├── documents.lua    # vimtex, typst-preview, render-markdown
    ├── jupytext.lua     # .ipynb edited as markdown, behind a resolved-binary guard
    ├── ui.lua           # oil, lualine, nvim-web-devicons, twilight
    ├── minuet.lua       # AI completion (minuet-ai → Codestral FIM, manual virtual text)
    ├── treesitter.lua   # Treesitter setup with language parsers
    ├── dap.lua          # nvim-dap + virtual text + dap-python
    ├── papis.lua        # papis.nvim (bibliography), sqlite.lua, nui.nvim
    ├── which-key.lua    # Keymap discoverability, <leader>? toggles it
    └── themes.lua       # Theme plugin declarations

lsp/                     # One config per server (clangd.lua, ruff.lua, ...), a table
                         # vim.lsp.enable() picks up from the runtimepath

spell/
└── en.utf-8.add        # Tracked technical wordlist (CFD, HPC, tooling, LaTeX).
                        # Compiled to .add.spl automatically; the .spl is gitignored.
```

## Common Development Commands

### Configuration Health Check
```bash
:checkhealth
:checkhealth lazy
:checkhealth treesitter
```

### Plugin Management

```text
:Lazy                 # Open lazy.nvim UI
:Lazy check           # Check for updates allowed by current selectors
:Lazy update <name>   # Update a named plugin
:Lazy restore <name>  # Restore a named plugin to its lockfile revision
```

Telescope tracks `master`; Treesitter and textobjects track `main`. Updates are
deliberate, with tested revisions recorded in `lazy-lock.json`. Preserve Blink's
`1.*` constraint and the other plugins' existing selectors.

Review branches monthly, version caps and dormant dependencies quarterly, and
after Neovim upgrades or regressions. Compare configured branches, not stale
`origin/HEAD` (previously misleading for Treesitter). Literal tags cannot advance
(Telescope's former problem); compare versions by semver and release notes,
not tag dates, including releases outside the selected range.

Before updating, save the affected specs and lock entries. Record the candidate
SHA, validation and health warnings. Update named plugins; do not use `:Lazy sync`
as a generic validation step because it also installs, updates and cleans plugins.
A temporary regression pin needs a reason, an upstream issue and a review date.

To roll back, restore only the affected specs and lock entries from that baseline,
preserving unrelated edits, then run `:Lazy restore <name>` and restart.

Treesitter parser binaries need a separate backup. Rehearsed on an isolated copy,
2026-09-20:

```bash
tar -czf ~/backups/nvim-parsers-$(date +%F).tar.gz \
    -C ~/.local/share/nvim/site parser parser-info queries
```

- Confirm the configurable install dir with
  `:lua print(require('nvim-treesitter.config').get_install_dir())`.
  Here: `~/.local/share/nvim/site`, 38 parsers, 41 MB (4.4 MB compressed).
- Use `tar`, not `cp -r`: `site/queries/` contains 41 absolute symlinks into
  `lazy/nvim-treesitter/runtime/queries/`. The archive preserves links;
  `:Lazy restore nvim-treesitter` restores their content. Without the clone,
  all links dangle and highlighting yields zero captures despite intact parsers
  and an attached highlighter.
- Restore the plugin revision, run `:TSUpdate`, then restart. If rebuilding fails,
  recover `parser/*.so` and `parser-info/*.revision` from the archive. Orphaned
  parsers cannot rebuild; see the zathurarc note in `lua/plugins/treesitter.lua`.

**Assert non-zero `highlights` captures over the parsed tree after restoring.**
This alone distinguished all four rehearsed failure modes: an attached highlighter
can lack a query, and `pcall(vim.treesitter.query.get, ...)` succeeds on a nil result.

Config commits, lockfile updates and the parent submodule pointer are three
separate operations.

### LSP Commands
```bash
:checkhealth vim.lsp   # Enabled configs and clients attached to current buffer
:lsp restart           # Restart LSP clients for current buffer (also: :lsp stop)
:lsp enable clangd     # Enable a specific server
:lua vim.cmd.edit(vim.lsp.log.get_filename())   # Open LSP log file
```

### Treesitter Operations
```bash
:TSUpdate           # Update all parsers
:TSInstall python   # Install specific parser
:TSUninstall python # Remove a parser
:TSLog              # Installer log (there is no :TSInstallInfo on main)
<leader>tc          # Toggle sticky context headers
```

## Important Implementation Details

### LSP Configuration
Native Neovim 0.11+ `vim.lsp.config` loads server tables from `lsp/<name>.lua`
on the runtimepath. `lua/config/lsp.lua` owns shared setup and the single
`vim.lsp.enable({...})` list. Explicit `vim.lsp.config('<name>', ...)` calls
override file configs; do not duplicate them or add nvim-lspconfig.

**Servers configured** (`lsp/<name>.lua`):
- `clangd` — C/C++ (primary focus: Trilinos, deal.II, HPC code)
- `basedpyright` — Python types, completion, hover, navigation. Installed as a global
  uv tool under `~/.local/share/uv/tools/`, it discovers project venvs at runtime.
- `ruff` — Python lint + **formatting**. Paired with basedpyright, not a replacement:
  ruff has no type system, and basedpyright reports
  `supports_method("textDocument/formatting") = false`, so neither covers the other.
- `bashls` — Bash/shell scripts (requires `shellcheck` for linting)
- `yamlls` — YAML (`yaml-language-server`, SchemaStore enabled)
- `jsonls` — JSON (`vscode-json-languageserver`)
- `tinymist` — Typst (formatting via bundled typstyle, `exportPdf=onSave`; see Typst section)
- `lua_ls` — Lua, i.e. this config itself (previously served by nothing)
- `neocmake` — CMake completion/navigation across `add_subdirectory` (27/37 local
  CMake files are authored); clangd handles C++. Chosen over `cmake-language-server`
  (idle since 2025-02). Its formatter left `project(demo   CXX)` untouched, so
  its TOML `[format]` block delegates to **gersemi**.

**Installation** (manual, no Mason):
```bash
sudo pacman -S clang              # clangd
uv tool install basedpyright      # global uv tool here, NOT in a project venv
sudo pacman -S ruff               # native binary; `ruff server` IS the LSP
sudo pacman -S lua-language-server
sudo pacman -S bash-language-server shellcheck
sudo pacman -S yaml-language-server vscode-json-languageserver
sudo pacman -S tinymist           # Typst LSP + formatter + preview server
paru -S neocmakelsp               # AUR; `stdio` is a subcommand, not a flag
sudo pacman -S python-gersemi     # the actual CMake formatter
```

**Ruff configuration** belongs in `init_options.settings`; plain `settings`
silently ignored a measured `lint.select`. `configurationPreference = "filesystemFirst"`
lets project `pyproject.toml` win. Explicit `lint.select` avoids unconfigured
defaults also raising `I001` (isort) and `B018` (bugbear). Duplicate diagnostics
are split by ownership of the useful code action:

- `F401`/`reportUnusedImport` and `F841`/`reportUnusedVariable` → **ruff**, so those two
  basedpyright rules are `"none"`.
- `F821`/`reportUndefinedVariable` → **basedpyright**; ignore Ruff's `F821`.
  Disabling `reportUndefinedVariable` removed all undefined-name code actions,
  including auto-import (`import json`). Preserve this asymmetry.

The standalone `ruff-lsp` package is deprecated and archived; the server lives inside the
ruff binary. ruff needs neither the venv nor a matching interpreter (`Depends On: glibc,
libgcc`) — it parses Python itself and takes the target version from `requires-python`.

**LSP keymaps** (buffer-local, only active when LSP is attached):

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Find references |
| `gi` | Go to implementation |
| `gt` | Go to type definition |
| `K` | Hover documentation |
| `<C-k>` (insert) | Signature help |
| `<leader>ca` | Code actions |
| `<leader>cr` | Rename symbol |
| `<leader>cf` | Format file |
| `<leader>ch` | Switch header/source (clangd only) |
| `<leader>ci` | Toggle inlay hints |
| `[d` / `]d` | Previous/next diagnostic (Neovim built-in; `]D`/`[D` for last/first) |
| `<leader>ed` | Show diagnostic float |
| `<leader>eq` | Send diagnostics to loclist |

**Diagnostics**: `virtual_text = false` (no inline text), underlines only, rounded float on hover.

**Format on save**: Enabled for `*.c, *.cpp, *.cc, *.h, *.hpp, *.typ`. **`*.py` is
deliberately excluded** — ruff formats Python only on demand (`<leader>cf`), because
auto-reformatting third-party data-engineering code on save buries real diffs. `*.lua` is
excluded for the same reason. Before clangd formats, C/C++ code is sanitized
(≪→<<, smart quotes→straight), preserving literals, comments and opaque macro bodies.
Sanitization requires a treesitter parser and skips buffers above 1 MB or flagged large.

**Inlay hints**: Enabled by default, toggle with `<leader>ci`.

**clangd requires `compile_commands.json`** for full functionality:
```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .
```

### Completion Configuration
**blink.cmp** is configured in `lua/config/completion.lua`.
Pinned to `version = "1.*"` — pulls the prebuilt Rust fuzzy-match binary (no cargo build).
This replaced nvim-cmp + its `cmp-*` source plugins; native `lsp/buffer/path/cmdline`
sources and `vim.snippet` cover what the old setup did. Do NOT re-add nvim-cmp.

**Sources** (default): `lsp`, `buffer`, `path`. The LSP provider filters out `Text`-kind
items (noisy in C++) and caps at `max_items = 20`.

**Completion keymaps** (insert mode):

| Key | Action |
|-----|--------|
| `<C-Space>` | Show menu / toggle docs |
| `<C-n>` / `<Tab>` | Next item (Tab also jumps snippet placeholders) |
| `<C-p>` / `<S-Tab>` | Previous item |
| `<CR>` | Confirm (must select first; else newline) |
| `<C-e>` | Hide menu |
| `<C-b>` / `<C-f>` | Scroll docs up/down |

**Style** = low-noise: nothing preselected (`auto_insert` previews), docs on-demand
(`<C-Space>`), ghost text OFF, cmdline menu only on `<Tab>`. `auto_brackets` ON (clangd
sends snippet items so no double-parens; basedpyright gets bare `()`).

**Filetype overrides** (`per_filetype`): SQL/Markdown use buffer+path only; gitcommit uses
buffer only; LaTeX uses buffer+path, with `\cite`/`\ref` via vimtex omni on manual
`<C-x><C-o>` (no cmp-omni, no texlab). papis registers a blink provider but it is NOT in
any source list — cite insertion is the picker (`<leader>pp`).

### AI Completion (minuet-ai → Codestral)
**minuet-ai.nvim** (`lua/plugins/minuet.lua`) provides AI code completion.
See `docs/ai-completion.md` for the full design rationale.

- **Provider**: Codestral FIM (`codestral.mistral.ai/v1/fim/completions`), cloud-only.
- **UI**: minuet's OWN virtual-text frontend (multi-line ghost text), NOT a blink source —
  so a cloud request fires only when asked, off blink's fast path.
- **Manual** (`auto_trigger_ft = {}`): no auto-suggest. Insert-mode Alt keymaps (since
  `<leader>` is normal-mode and vimtex owns `<leader>ll`):

| Key | Action |
|-----|--------|
| `<A-]>` / `<A-[>` | Invoke (when none showing), then cycle next/prev |
| `<A-A>` | Accept whole completion |
| `<A-a>` | Accept one line |
| `<A-z>` | Accept N lines (prompts) |
| `<A-e>` | Dismiss |

- **API key**: `CODESTRAL_API_KEY`, loaded by `lua/config/secrets.lua` from
  `~/.config/secrets/codestral.env` (chmod 600, untracked) into an **in-process table**.
  Never commit it or source it in the shell. `vim.env` would expose it to child
  LSP servers, `:terminal` and `:!`. Minuet's `api_key` callback uses `secrets.get()`;
  the opt-in `secrets.export()` escape hatch for environment-only consumers is unused.
- **Debug**: set `notify = "debug"` in the spec and watch `:messages` (no log file).

### Theme Switching System
Themes use a dual-configuration approach:
- `lua/config/themes.lua` contains theme configs and application functions
- `lua/plugins/themes.lua` declares the theme plugins
- Toggle with `<leader>th` - this properly clears package cache and reloads theme
- After plugin setup, `lua/config/lazy.lua` uses the desktop light/dark state,
  falling back to `~/.local/share/nvim/last_theme.txt`, then `onedark`.
  The toggle overrides the desktop choice for the session; if fallback persistence
  fails, check the saved file's permissions.

When modifying themes, always edit both files (config and plugin declaration).

### Treesitter Configuration
Uses the `main` rewrite with Neovim 0.12+ native highlighting, folding and selection.

**Folding:** `v:lua.vim.treesitter.foldexpr()` in `lua/config/options.lua`.

**Parsers:** 38 languages declared and installed including C/C++, Python, Rust, Go, SQL, YAML, Markdown.

**Performance:** see [Large File Handling](#large-file-handling) for the FileType guard.

**Indentation:** provided by runtime ftplugins and the per-filetype settings in
`autocmds.lua`. Treesitter's experimental indentation is not enabled.

**Features:** Syntax highlighting, text objects (`af/if` functions, `ac/ic` classes), navigation (function `]m/[m` start `]M/[M` end, class `]]/[[` start `][/[]` end), sticky context headers (`<leader>tc`). Incremental node selection is `an`/`in` (expand outward/inward) and `]n`/`[n` (expand to sibling) — Nvim 0.12+ native defaults (`vim.treesitter.select()`), unmapped by this config. `<C-Space>` is NOT incremental selection here — it's blink.cmp's completion trigger (see Completion Configuration); the old `nvim-treesitter` incremental-selection module doesn't exist on the `main` branch this config uses.

**Local shell queries:** upstream zsh's 14 captures omit `@block` and
`@parameter.outer`, making `ab`/`ib` and `aa` no-ops. `queries/zsh/textobjects.scm`
adds `{ … }` / `do … done` blocks and arguments of any node type (including quoted
strings). Preserve `;; extends`: replacing upstream's query would lose `@function`,
`@loop`, `@conditional`, `@comment` and `@assignment`.
Shell has no classes, so `ac`/`ic` and `]] [[ ][ []` intentionally remain no-ops.

**Runtime ftplugin overrides:** buffer-local mappings win over these global maps:

| ft | what the ftplugin maps | resolution |
|---|---|---|
| python | all 8 of `]] [[ ][ [] ]m [m ]M [M`, by regex | disabled — `vim.g.no_python_maps = 1` in `options.lua` |
| sql | `]] [[ ][ []` → regex `BEGIN`/`END` search | kept (unguarded anyway); see below |
| markdown | `]] [[` → "jump to next section" | kept — `ftplugin/markdown.lua` is itself treesitter-based |

Python's regex falsely matches `def` in docstrings/comments; its treesitter queries
are the most complete here. `g:no_python_maps` guards only those 24 mappings.
Do not substitute blanket `g:no_plugin_maps`; preserve SQL/Markdown behavior.

### Filetype Detection and Indentation
Specialized filetype detection in `autocmds.lua` handles:
- Only what Neovim does not detect itself (`vim.filetype.add`): `.dvc` and `MLproject`
  (yaml), `.j2`/`.jinja2` (jinja), `poetry.lock` (toml), `.dvcignore` (gitignore) and a
  bare `aliases` file (sh). dbt/DVC yaml names and every `.env` form are deliberately
  left to Neovim's own detection
- Binary file prevention: `.parquet`, `.h5`, `.stl` (shows warning and closes buffer)
- Per-language indentation: Python/Rust (4 spaces), Lua/YAML/SQL (2 spaces), Go/Make (tabs)

When adding new filetype support:
1. Add detection pattern in the *Filetype detection* section of `autocmds.lua`
2. Add indentation rules in its *File-type specific indentation* section
3. Add treesitter parser in `lua/plugins/treesitter.lua`

### Lazy Loading Strategy
`defaults.lazy = false`: plugins opt into lazy loading explicitly.

- `event = "VeryLazy"` - Load after startup complete
- `ft = "python"` - Load on filetype detection
- `cmd = "Telescope"` - Load when command first invoked
- `keys = {...}` - Load when specific key pressed

### Git Integration Workflow
gitsigns.nvim provides in-buffer git operations:
- `]c` / `[c` - Navigate hunks
- `<leader>hp` - Preview hunk diff
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk

For commits and complex git operations, the user switches to lazygit in tmux (Ctrl+b).

### Database Configuration
Only **vim-dadbod** is installed. `g:dbs` (plural) belongs to the uninstalled
dadbod-ui; dadbod never reads it (its only source occurrence of `dbs` is Redis's
`dbsize`). The former empty `vim.g.dbs` declaration was therefore removed.

vim-dadbod resolves a connection from `t:db`, `b:db`, `$DATABASE_URL`, then `g:db`
(singular) — see `:h dadbod`.

Verified 2026-09-09: rootless-podman PostgreSQL 18 at `127.0.0.1:5432`, sole
database/login role `postgres`. Earlier examples invented `dev_db`/`dev` and used
unset `DB_USER`/`DB_PASSWORD`, producing nils in `.nvim.lua`. The password is a
podman secret: loopback trust does not apply because `rootlessport` rewrites the
source address. No project config is needed; export in Neovim's launching shell:

```bash
export DATABASE_URL="postgresql://postgres:$(podman secret inspect --showsecret \
  --format '{{.SecretData}}' pg_password)@127.0.0.1:5432/postgres"
```

Then `:DB select 1`. Never print the assembled string and never hardcode the credential.
`dotfiles/skills/local-postgres/SKILL.md` is the authoritative reference, including why
the lifecycle is `systemctl --user restart pg.service` and not `podman stop`.

`<leader>rr` pipes the line/selection to `:DB`; `<leader>rf` pipes the whole file.

Installed clients: `psql`, `sqlite3`, and **`duckdb`** (CLI reinstalled 2026-09-05; it had
been absent, which older examples here were written against).

## Performance Optimizations

### Startup Performance
- Bytecode cache enabled (`vim.loader.enable()`)
- Unused providers disabled (Ruby, Perl, Node.js)
- Built-in plugins disabled (netrw, gzip, tar, etc.)
- Treesitter installs parsers asynchronously via `require('nvim-treesitter').install({...})`
  (`sync_install` is a legacy master-branch option and is not used here)
- `blink.cmp` loads eagerly (startup cost is ~1ms-class; prebuilt fuzzy binary)

### Large File Handling
Three-tier approach:
1. **Above 10 MB** (`autocmds.lua`): Sets `vim.b.large_file`, disables undo, swap
   and syntax highlighting. The `LspAttach` guard detaches flagged buffers without
   stopping the client shared by other buffers.
2. **Above 1 MB or flagged large** (`treesitter.lua`): The FileType guard stops
   highlighting and sets buffer-specific window folding to manual. Built-in
   ftplugins can start highlighting before the guard runs, and folding invokes
   parsing even without a highlighter, so both must be stopped explicitly.
3. **Completion** (`completion.lua`): Blink's top-level
   `enabled = function() return not vim.b.large_file end` disables completion
   per-buffer.

### Diff Performance
Modern diff algorithm configured in options.lua:
- `algorithm:histogram` - Better than Myers for code diffs
- `linematch:60` - Shows word-level changes within lines
- `indent-heuristic` - Handles Python/YAML indentation changes intelligently

## Session Management

vim-obsession auto-starts session tracking in git repositories. Sessions are saved to `Session.vim` in project root. To restore: `nvim -S Session.vim`

## Tmux Integration

vim-tmux-navigator maps `<C-h/j/k/l>` across Neovim splits and tmux panes.
See the user's tmux.conf for matching tmux-side bindings.

## Common Pitfalls

- **Edits not taking effect**: See [Testing Changes](#testing-changes).
- **Arrow keys disabled**: hjkl navigation enforced in normal/insert/visual modes.
- **Clipboard behavior**: System clipboard NOT synced by default (use `"+y` / `"+p` explicitly).
- **Terminal escape**: Use `<Esc><Esc>` (double Escape) to exit terminal mode.
- **Treesitter folding issues**: Verify the [native foldexpr](#treesitter-configuration),
  not the old `nvim_treesitter#foldexpr()`.
- **Missing parser**: Run `:TSInstall <language>` and add it to the `install({...})`
  list in `lua/plugins/treesitter.lua` (main has no `ensure_installed`; an unlisted
  parser works here but vanishes on a fresh machine).
- **LSP not attaching**: Check `:checkhealth vim.lsp`. clangd needs
  `compile_commands.json` or a `.git` root; for basedpyright, check `uv tool list`.
  On huge files, detachment is intentional — see [Large File Handling](#large-file-handling).
- **No completions**: Run `:checkhealth blink.cmp` and `:checkhealth vim.lsp`;
  try `<C-Space>` to manually trigger.

## File Type Specific Notes

### C/C++
clangd's navigation, `<leader>ch` header/source switch, save sanitizer and
`compile_commands.json` setup are covered in [LSP Configuration](#lsp-configuration).
Formatting respects `.clang-format`; `--fallback-style=none` means no format without it.

### Python
- PEP 8 indentation: 4 spaces (see [Filetype Detection and Indentation](#filetype-detection-and-indentation)).
- See [LSP Configuration](#lsp-configuration) for basedpyright/ruff responsibilities,
  environment discovery and manual-only formatting.
- Virtual env displayed in statusline when active
- treesj configured with trailing commas (Black-compatible)

### LaTeX (.tex)
- vimtex provides compilation and PDF preview
- Viewer: sioyek (Wayland-native, SyncTeX forward/inverse search) - configure in `lua/plugins/documents.lua` if different
- `<leader>ll` to compile, `<leader>lv` to view
- See [Completion Configuration](#completion-configuration) for manual vimtex
  `\cite`/`\ref` completion and Blink's tex sources.

### Typst (.typ)
Typst is primary for self-authored documents; LaTeX remains for journals,
Overleaf collaboration and TikZ. Markdown math remains LaTeX/KaTeX.

- **LSP/formatting**: system `tinymist` (`lsp/tinymist.lua`, pacman extra) supplies
  completion, hover, navigation, preview and bundled typstyle (`<leader>cf`/save).
  No standalone typstyle or latexmk-like compile step; compilation measured sub-ms.
- **PDF export**: `exportPdf = "onSave"` writes `main.pdf` beside the source;
  browser preview renders in memory without writing files.
- **Preview**: `typst-preview.nvim` (`lua/plugins/documents.lua`, `ft=typst`)
  uses system tinymist through `dependencies_bin`, keeping it pacman-managed and
  matched to the LSP. First use downloads only `websocat`. `<leader>ll` opens
  `firefox --new-window` with bidirectional cursor sync; run it on the **root**
  document (`main.typ`), not an included fragment.
- **Browser rationale**: vimb/WebKitGTK composited later canvas pages over page 1
  despite a correct PDF. Firefox renders correctly but retains Wayland `app_id=firefox`
  regardless of `--class`, so with the main instance running it uses the existing
  session/window-rule rather than a dedicated niri column. Chromium `--app --class`
  remains an option for an isolated preview column.
- **Completion**: `typst = { "lsp", "buffer", "path" }`; citations use the papis
  picker as described in [Completion Configuration](#completion-configuration).
- **Bibliography**: Typst reads BibLaTeX `.bib` natively via `#bibliography("refs.bib")`,
  so papis is unchanged. `papis-bib` (`dotfiles/bash/papis-bib`) handles `.typ` too:
  bib-name from any quoted `"*.bib"` (covers `#bibliography`, alexandria's
  `#load-bibliography`, array forms), `// papis-bib: ignore` opt-out, and `.typ` in the
  cited-file scan (`filter-cited` greps `@key` / `#cite(<key>)` the same as `\cite{key}`).
  For both `.tex` and `.typ`, `<leader>ll` **auto-sync** only adds newly cited
  library entries; existing `.bib` content wins conflicts. Only interactive
  **`papis-bib --prune`** removes uncited entries or updates drifted ones
  (`update --from`), in batch-confirmed phases. Neither mode writes the papis library.

**Keymaps for `.typ`** (mirror the vimtex `<leader>l` prefix):

| Key | Action |
|-----|--------|
| `<leader>ll` | Sync `refs.bib` from papis (additive) + start/refresh preview |
| `<leader>ls` | Stop preview server |
| `<leader>lp` | Sync preview to cursor |
| `<leader>lb` | `papis-bib --prune` (interactive bib cleanup, in a `:terminal` split) |

`<leader>lb` also works in `.tex`. It requires a terminal split: `:!` uses a pipe,
not a pty (`:h vim_diff`), and prune requires interactive stdin. `q` closes the
split after exit. Typst has no `<leader>lv`; `TypstPreview` already toggles/opens.

### SQL
- vim-dadbod for query execution
- Connections and query keys: [Database Configuration](#database-configuration).
- See [Completion Configuration](#completion-configuration) for SQL's non-LSP sources.
- **Text objects are local to this config**: nvim-treesitter-textobjects ships
  no sql queries, so without `queries/sql/textobjects.scm` every `]m`/`af`/`ac`
  is a silent no-op in a `.sql` buffer. That file maps SQL onto the same
  captures the rest of the config uses — `@function` = a statement (one query),
  `@class` = a `BEGIN … END` block, `@block` = a subquery or CTE, `@parameter` =
  a select-list column or call argument, plus `CASE`, `WHILE`, and comments.
  `]] [[ ][ []` remain the built-in ftplugin's regex `BEGIN`/`END` search, which
  it maps unguarded (no `g:no_plugin_maps` check); the query file agrees with it
  on what a block is, so `ac`/`ic` and those motions line up.

### CSV/TSV
- rainbow_csv auto-enables on CSV files
- RBQL query language available with `<leader>cq`
- **`<leader>cc` (`:RainbowAlign`) edits the buffer** — it pads every field with
  spaces via `setline()`, it is not a display mode. Upstream warns against it when
  leading/trailing whitespace is part of the data. `<leader>cs` (`:RainbowShrink`)
  is the inverse and strips the padding back out.
- There is **no alignment mode**: the former `vim.g.rcsv_align_mode = 0` and claim
  that it disabled alignment for performance were removed. The option appears in
  neither the eight `g:` variables read, the fourteen documented, nor anywhere in
  upstream source. `g:rcsv_max_columns` (default 30) caps highlighted columns;
  it is unset here because wide files have not been slow.

### Jupyter notebooks (.ipynb)
Jupytext converts notebooks to/from **markdown** on read/write. Execution would
need `ipykernel` and a kernel-attached plugin; neither is part of this integration.

**Jupyter lives in the per-project venv here, never system-wide**, so `jupytext`
may be missing. `lua/plugins/jupytext.lua` calls `setup()` eagerly and wraps the
read handler to prevent the destructive failures below. Before each conversion,
`lua/config/jupytext_resolve.lua` resolves the CLI in this order, shared with the
healthcheck:

1. `$VIRTUAL_ENV/bin/jupytext` — direnv or `va` has activated something; trust it.
2. `<root>/.venv/bin/jupytext` — nvim launched outside the venv but inside the project.
3. `PATH` — e.g. `uv tool install jupytext`, though the normal route here is
   `uv pip install jupytext` in the project venv (see `dotfiles/revisit.md`).

Per-open resolution picks up a `:terminal` install or late direnv activation on
the next `:e`, without `:restart`. No CLI means raw JSON (`ft=json`).

Upstream failures requiring the wrapper:

- `commands.lua:4` shells out to bare `jupytext` without a binary-path option;
  prepend the resolved directory to `PATH`.
- `init.lua:88` tests `if vim.fn.filereadable(f) then`, but **Lua treats 0 as true**.
  Failed conversion reaches `readfile()`, which throws and leaves an empty buffer;
  `:w` then truncates the notebook (measured: 933 bytes/3 cells → 0).
  The `:92` error `"Couldn't find jupytext file."` is unreachable.
- `BufReadCmd` also fires for nonexistent files (`nvim new.ipynb`);
  `utils.lua:16` calls `io.open(f, "r"):read "a"` without a nil check.
- Malformed, truncated or empty files throw in `vim.json.decode` or the missing
  `kernelspec` lookup (`utils.lua:17`). Guard reads with readability checks and `pcall`.

**All** matching `BufReadCmd` autocommands run, so an earlier handler cannot
pre-empt jupytext's; its callback must be retrieved with `nvim_get_autocmds` and
wrapped. On failure, load the raw file: jupytext registers `BufWriteCmd` only
after a successful read, leaving failures ordinarily writable and vulnerable
to truncation if empty. The wrapper must **not** return a truthy value — that
deletes the autocmd.

**`lua/jupytext/health.lua` deliberately shadows the plugin's.** Upstream uses
`vim.health.report_start`, removed in Neovim 0.10 in favor of `vim.health.start`,
so `:checkhealth` threw `attempt to call field 'report_start' (a nil value)`.
Edits under `~/.local/share/nvim/lazy` are untracked and lost on update;
`~/.config/nvim` wins on the runtimepath. `require("jupytext")` still reaches the
plugin because our directory has neither `jupytext.lua` nor `jupytext/init.lua`
(verified).

The replacement reports the resolved CLI's origin and version, or a **warning,
not an error**, when none is found, since raw JSON is a supported fallback.

Keep **guarded `lazy = false`**: Neovim detects `.ipynb` as `json`, so the original
`ft = { "ipynb" }` never fired and only accidentally prevented truncation. Neither
an `ft` trigger nor unguarded eager loading is safe.
Sandbox: `~/learning/playground/jupytext-nvim-tests` (17 checks, `scenarios.md` for manual runs).

### Markdown
There is **no vim-markdown plugin** — highlighting is the treesitter `markdown` /
`markdown_inline` parsers, and in-buffer rendering is `render-markdown.nvim`
(`ft = markdown`): concealed headings, code blocks, callouts, and LaTeX math via
the `mathunicode` converter only (see the long comment in `lua/plugins/documents.lua`
for why utftex/latex2text were dropped).

**Preview** is a self-contained module, `lua/config/md_preview.lua` — not a
plugin. `<leader>ll` renders the buffer with `cmark-gfm`, splices the raw LaTeX
back in for client-side KaTeX, serves it from `$XDG_RUNTIME_DIR/nvim_md_preview` over a
localhost-bound `python3 -m http.server` on port 7654, and opens vimb. Saving a
`.md` recompiles the HTML (reload with `r` in vimb); the server and browser are
killed on `VimLeavePre`.

**Buffer-local keymaps** (`FileType markdown`): `lua/config/markdown.lua` registers
the mappings, global `:MathCollapse` command, and preview save/exit hooks through
`setup()`, called from `autocmds.lua` at startup. Preview code loads on use;
save refresh retains the `*.md` filename pattern.

| Key | Action |
|-----|--------|
| `<leader>ll` | Render + open preview in vimb |
| `<leader>lt` | TOC — headings into the loclist |
| `<leader>lm` | `:MathCollapse` — collapse `$$`/content/`$$` to one line |

Folding follows the global treesitter `foldexpr` with `foldlevel=99`, so folds
start open; nothing markdown-specific disables it.

**Spelling:** `autocmds.lua` enables it for markdown, tex and typst using Neovim's
bundled `en.utf-8.spl`; no installation or download.

| Key | Action |
|-----|--------|
| `]s` / `[s` | next / previous misspelling |
| `z=` | suggestions for the word under the cursor |
| `zg` | add the word to your dictionary (persists) |
| `zw` | mark a word as wrong |

Default `spelloptions=noplainbuffer` respects treesitter `@nospell`: verified
inline code, fenced Python and `$$ … $$` math are skipped; prose/headings are checked.
Bare URLs are flagged; `[text](url)` and `<url>` are skipped.

`spellfile` explicitly points to `~/.config/nvim/spell/en.utf-8.add`, the tracked
dictionary also loaded through the runtimepath. Words added with `zg` intentionally
appear as repo changes. A separate data-directory dictionary with the same name
was shadowed by the config runtimepath. The prose autocmd compiles the tracked
wordlist when its `.spl` is missing or stale; compiled files are gitignored.

## Testing Changes

lazy.nvim auto-detects file changes (`change_detection.enabled = true`) and
reloads most edits without a restart. Use `:restart` (0.12+, relaunches the
session in place) or the file-specific step below when it doesn't:

1. **Options changes** (`lua/config/options.lua`): Restart Neovim or `:source %`
2. **Plugin additions** (`lua/plugins/*.lua`): `:Lazy sync`
3. **Keymap changes** (`lua/config/keymaps.lua`): `:source %` or restart
4. **Autocmd changes** (`lua/config/autocmds.lua`): Restart Neovim (autocmds can't be easily reloaded)
5. **Theme changes** (`lua/config/themes.lua`): Use `<leader>th` toggle or restart
6. **LSP changes** (`lua/config/lsp.lua`, `lsp/*.lua`): Restart Neovim, then `:checkhealth vim.lsp` to verify
7. **Completion changes** (`lua/config/completion.lua`): `:Lazy reload blink.cmp` or restart

Always test in a git repository to verify vim-obsession session tracking works correctly.
