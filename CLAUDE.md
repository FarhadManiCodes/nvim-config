# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Neovim 0.11+ configuration optimized for HPC/CFD workflows (C++, Trilinos, deal.II) with data engineering support (Python, SQL, Jupyter). Uses lazy.nvim for plugin management, organized into modular Lua files. LSP is fully implemented using the Neovim 0.11+ native API.

## Configuration Architecture

### Initialization Flow (init.lua)
The configuration loads in three distinct phases:

1. **PHASE 1: BOOTSTRAP** - Sets fundamental variables (leader keys, bytecode cache)
2. **PHASE 2: CORE CONFIGURATION** - Loads editor options, plugins via lazy.nvim, then LSP
3. **PHASE 3: USER INTERFACE** - Loads autocommands and keymaps

Loading order is critical: `options → plugins (lazy.nvim) → lsp → autocmds → keymaps`. Do not reorder these phases. LSP loads after plugins because `blink.cmp` must be available when `lsp.lua` calls `require('blink.cmp').get_lsp_capabilities()`.

### Module Structure

```
lua/
├── config/              # Core configuration modules
│   ├── options.lua      # Editor behavior, performance, and display settings
│   ├── lazy.lua         # Plugin manager bootstrap and configuration
│   ├── keymaps.lua      # All keybindings and workflow documentation
│   ├── autocmds.lua     # Event-driven behaviors and file-type detection
│   ├── themes.lua       # Theme application and toggling logic
│   ├── state.lua        # Tiny single-line persisted state under stdpath("data")
│   ├── md_preview.lua   # Self-contained markdown preview (cmark-gfm + KaTeX + vimb)
│   ├── papis_bib.lua    # Shared front-end for the papis-bib script (tex + typst)
│   ├── dap_adapters.lua       # Debug adapters (gdb native DAP)
│   ├── dap_configurations.lua # Debug launch configurations (C++/ASAN/pybind)
│   ├── lsp.lua          # LSP server setup (clangd, basedpyright, bashls, yamlls, jsonls, tinymist)
│   ├── secrets.lua      # Load ~/.config/secrets/*.env into an IN-PROCESS table
│   │                    # (NOT vim.env -- see the AI Completion section)
│   └── completion.lua   # blink.cmp completion engine setup
└── plugins/             # Plugin specifications (lazy.nvim format)
    ├── init.lua         # Main plugin list with configurations
    ├── minuet.lua       # AI completion (minuet-ai → Codestral FIM, manual virtual text)
    ├── treesitter.lua   # Treesitter setup with language parsers
    ├── dap.lua          # nvim-dap + virtual text + telescope-dap
    ├── papis.lua        # papis.nvim (bibliography), sqlite.lua, nui.nvim
    ├── which-key.lua    # Keymap discoverability, <leader>? toggles it
    └── themes.lua       # Theme plugin declarations

spell/
└── en.utf-8.add        # Tracked technical wordlist (CFD, HPC, tooling, LaTeX).
                        # Compiled to .add.spl automatically; the .spl is gitignored.
```

`completion.lua` is NOT loaded directly in `init.lua`. It is loaded via the `blink.cmp` plugin's `config` function in `plugins/init.lua`. blink loads eagerly at startup (its LSP capabilities must be built before any server attaches).

### Key Design Principles

- **Explicit over implicit**: Default lazy loading is disabled (`defaults.lazy = false`), plugins opt-in to lazy loading where beneficial
- **Performance-first**: Disabled unused built-in plugins, enabled bytecode cache (`vim.loader.enable()`)
- **Large file handling**: Autocmds detect files >10MB and disable expensive features (undo, swap, treesitter, LSP, completion)
- **Filetype-specific behavior**: Indentation and settings configured per-language in autocmds.lua
- **Theme persistence**: Last used theme saved to `~/.local/share/nvim/last_theme.txt` and restored on startup

## Common Development Commands

### Configuration Health Check
```bash
:checkhealth
:checkhealth lazy
:checkhealth treesitter
```

### Plugin Management
```bash
:Lazy          # Open lazy.nvim UI
:Lazy update   # Update all plugins
:Lazy sync     # Clean + update
:Lazy check    # Check for updates
```

### LSP Commands
```bash
:LspInfo       # Show LSP clients attached to current buffer
:LspRestart    # Restart LSP clients for current buffer
:LspLog        # Open LSP log file
:LspStart clangd   # Manually start a specific server
```

### Testing Configuration Changes
After editing Lua files in `lua/config/` or `lua/plugins/`:
1. Save the file - lazy.nvim auto-detects changes (`change_detection.enabled = true`)
2. If no auto-reload, restart Neovim with `:restart` (Nvim 0.12+ — restarts the
   session in place, no need to `:qa` and relaunch by hand)
3. For plugin changes specifically: `:Lazy sync`

### Treesitter Operations
```bash
:TSUpdate           # Update all parsers
:TSInstall python   # Install specific parser
:TSInstallInfo      # Check parser status
<leader>tc          # Toggle sticky context headers
```

## Important Implementation Details

### Leader Key Configuration
The leader key is `\` (backslash), set in init.lua BEFORE any plugins load. If changing the leader key, it MUST be set before `require("config.lazy")`.

### LSP Configuration
LSP uses the **Neovim 0.11+ native `vim.lsp.config` API** — there is no `nvim-lspconfig` plugin. Servers are configured with `vim.lsp.config('name', {...})` and enabled with `vim.lsp.enable('name')`.

**Servers configured** (`lua/config/lsp.lua`):
- `clangd` — C/C++ (primary focus: Trilinos, deal.II, HPC code)
- `basedpyright` — Python types, completion, hover, navigation
- `ruff` — Python lint + **formatting**. Paired with basedpyright, not a replacement:
  ruff has no type system, and basedpyright reports
  `supports_method("textDocument/formatting") = false`, so neither covers the other.
- `bashls` — Bash/shell scripts (requires `shellcheck` for linting)
- `yamlls` — YAML (`yaml-language-server`, SchemaStore enabled)
- `jsonls` — JSON (`vscode-json-languageserver`)
- `tinymist` — Typst (formatting via bundled typstyle, `exportPdf=onSave`; see Typst section)
- `lua_ls` — Lua, i.e. this config itself (~5k lines across 21 files, previously served
  by nothing)

**Installation** (manual, no Mason):
```bash
sudo pacman -S clang              # clangd
uv tool install basedpyright      # a uv tool here, NOT per-venv
sudo pacman -S ruff               # native binary; `ruff server` IS the LSP
sudo pacman -S lua-language-server
sudo pacman -S bash-language-server shellcheck
sudo pacman -S yaml-language-server vscode-json-languageserver
sudo pacman -S tinymist           # Typst LSP + formatter + preview server
```

**ruff notes worth not rediscovering.** Its config must go in
`init_options.settings` — passing it under `settings` is **silently ignored** (measured:
a `lint.select` there had no effect whatsoever). `configurationPreference` is pinned to
`filesystemFirst` so a project's own `pyproject.toml` wins over this machine's opinions.
`lint.select` is stated explicitly because ruff's defaults are broader than they look:
with no config present they also raise `I001` (isort) and `B018` (bugbear). ruff duplicated three basedpyright diagnostics, and they are split by **which side carries
the useful code action**, not by which server is faster:

- `F401`/`reportUnusedImport` and `F841`/`reportUnusedVariable` → **ruff**, so those two
  basedpyright rules are `"none"`.
- `F821`/`reportUndefinedVariable` → **basedpyright**, so `F821` is in ruff's `ignore`
  list. This one is load-bearing: auto-import (`import json`) is attached to
  `reportUndefinedVariable`, so turning it off to kill the duplicate left **zero** code
  actions on an undefined name. Do not "tidy" this into matching the other two.

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
excluded for the same reason. C/C++ buffers are sanitized first (≪→<<, smart quotes→straight) before clangd formats, so the formatter never sees PDF-pasted artifacts.

**Inlay hints**: Enabled by default, toggle with `<leader>ci`.

**Large file guard**: `on_attach` checks `vim.b[bufnr].large_file` and stops the client if true.

**clangd requires `compile_commands.json`** for full functionality:
```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .
```

### Completion Configuration
**blink.cmp** is configured in `lua/config/completion.lua` (loaded via blink's `config`).
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

**Large-file guard**: top-level `enabled = function() return not vim.b.large_file end`
disables completion on buffers flagged >10MB (tier 3 of the large-file strategy).

### AI Completion (minuet-ai → Codestral)
Manual, on-demand AI code completion via **minuet-ai.nvim** (`lua/plugins/minuet.lua`),
separate from blink. See `docs/ai-completion.md` for the full design rationale.

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
  `~/.config/secrets/codestral.env` (chmod 600, untracked) into an **in-process Lua
  table — deliberately NOT `vim.env`**. Child processes inherit the environment, so
  exporting it would hand the key to every LSP server, `:terminal` shell and `:!`
  command. Consumers read it through `secrets.get()`, which is why minuet's `api_key`
  is a function rather than a variable name. `secrets.export()` exists as an opt-in
  escape hatch for a consumer that can only read a real env var; nothing uses it.
  Never sourced in the shell, never committed.
- **Debug**: set `notify = "debug"` in the spec and watch `:messages` (no log file).

### Theme Switching System
Themes use a dual-configuration approach:
- `lua/config/themes.lua` contains theme configs and application functions
- `lua/plugins/themes.lua` declares the theme plugins
- Toggle with `<leader>th` - this properly clears package cache and reloads theme
- Theme persistence handled in `lua/config/lazy.lua` after plugin setup completes

When modifying themes, always edit both files (config and plugin declaration).

### Treesitter Configuration
Uses **Neovim 0.11+ native features**:

**Folding:** `v:lua.vim.treesitter.foldexpr()` (set in `lua/config/options.lua:176`) — faster than the old plugin-based approach.

**Parsers:** 38 languages auto-installed including C/C++, Python, Rust, Go, SQL, YAML, Markdown.

**Performance:** Two-tier large file handling:
1. Files > 10MB: Disables all expensive features (autocmds.lua)
2. Files > 1MB: Disables treesitter specifically (treesitter.lua)

**Features:** Syntax highlighting, smart indentation, text objects (`af/if` functions, `ac/ic` classes), navigation (function `]m/[m` start `]M/[M` end, class `]]/[[` start `][/[]` end), sticky context headers (`<leader>tc`). Incremental node selection is `an`/`in` (expand outward/inward) and `]n`/`[n` (expand to sibling) — Nvim 0.12+ native defaults (`vim.treesitter.select()`), unmapped by this config. `<C-Space>` is NOT incremental selection here — it's blink.cmp's completion trigger (see Completion Configuration); the old `nvim-treesitter` incremental-selection module doesn't exist on the `main` branch this config uses.

**Shell text objects are local to this config**, like SQL's. Upstream's zsh query defines 14
captures but neither `@block` nor `@parameter.outer`, so `ab`/`ib` and `aa` were silent
no-ops in every shell buffer. `queries/zsh/textobjects.scm` adds them: `@block` covers both a
`{ … }` body and a `do … done` body, and `@parameter.outer` widens arguments to any node so
`aa` works on a quoted string, not just a bare word. The `;; extends` first line is
**load-bearing** — without it the file *replaces* upstream's query and `@function`, `@loop`,
`@conditional`, `@comment` and `@assignment` all stop working.

`ac`/`ic` and `]] [[ ][ []` stay no-ops in shell **on purpose**: there is no class, and
pointing them at something arbitrary would be worse than nothing.

**Built-in ftplugins vs these motions.** All of the above are *global* mappings,
so any buffer-local mapping from a runtime ftplugin wins over them. Three
filetypes do that, and the config treats each differently:

| ft | what the ftplugin maps | resolution |
|---|---|---|
| python | all 8 of `]] [[ ][ [] ]m [m ]M [M`, by regex | disabled — `vim.g.no_python_maps = 1` in `options.lua` |
| sql | `]] [[ ][ []` → regex `BEGIN`/`END` search | kept (unguarded anyway); see below |
| markdown | `]] [[` → "jump to next section" | kept — `ftplugin/markdown.lua` is itself treesitter-based |

Python's regex motions stop on `def` inside docstrings and comments; its
treesitter queries are the most complete of any language here, so the flag is a
straight upgrade — and those 24 mappings are the only thing `g:no_python_maps`
guards. `g:no_plugin_maps` (the blanket version) is deliberately NOT set, since
it would take the other two with it.

### Filetype Detection and Indentation
Specialized filetype detection in `autocmds.lua` handles:
- Data engineering formats: `.dvc`, `dbt_project.yml`, `.env.*`
- Binary file prevention: `.parquet`, `.h5`, `.stl` (shows warning and closes buffer)
- Per-language indentation: Python/Rust (4 spaces), Lua/YAML/SQL (2 spaces), Go/Make (tabs)

When adding new filetype support:
1. Add detection pattern in `autocmds.lua` Section 4
2. Add indentation rules in Section 8
3. Add treesitter parser in `lua/plugins/treesitter.lua`

### Lazy Loading Strategy
- `event = "VeryLazy"` - Load after startup complete
- `ft = "python"` - Load on filetype detection
- `cmd = "Telescope"` - Load when command first invoked
- `keys = {...}` - Load when specific key pressed

`blink.cmp` loads eagerly at startup (not lazy) because its LSP capabilities must be built before any server attaches.

### Git Integration Workflow
gitsigns.nvim provides in-buffer git operations:
- `]c` / `[c` - Navigate hunks
- `<leader>hp` - Preview hunk diff
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk

For commits and complex git operations, the user switches to lazygit in tmux (Ctrl+b).

### Database Configuration
Only **vim-dadbod** is installed — not vim-dadbod-ui. This matters: `g:dbs` (plural)
is dadbod-**ui**'s setting. vim-dadbod itself never reads it; the string `dbs` does
not appear anywhere in its source apart from `dbsize` in the redis adapter. The
config used to declare an empty `vim.g.dbs`, which would have done nothing however
it was filled in. It has been removed rather than left looking like live config.

vim-dadbod resolves a connection from `t:db`, `b:db`, `$DATABASE_URL`, then `g:db`
(singular) — see `:h dadbod`. Pass a URL inline:

```vim
:DB postgresql://localhost/dev_db select 1
```

or set a per-project default in `.nvim.lua` (`exrc` is enabled):

```lua
vim.b.db = string.format(
  "postgresql://%s:%s@localhost:5432/dev_db",
  os.getenv("DB_USER"),
  os.getenv("DB_PASSWORD")
)
```

Never hardcode credentials — always `os.getenv()`. `<leader>rr` (line/selection) and
`<leader>rf` (whole file) pipe to `:DB` and work once a connection resolves.

Installed clients: `psql`, `sqlite3`. **`duckdb` is not installed**, despite older
examples here referencing it.

## Performance Optimizations

### Startup Performance
- Bytecode cache enabled (`vim.loader.enable()`)
- Unused providers disabled (Ruby, Perl, Node.js)
- Built-in plugins disabled (netrw, gzip, tar, etc.)
- Treesitter auto-installs parsers asynchronously (`sync_install = false`)
- `blink.cmp` loads eagerly (startup cost is ~1ms-class; prebuilt fuzzy binary)

### Large File Handling
Three-tier approach:
1. **10MB threshold** (autocmds.lua): Disables undo, swap, syntax highlighting, LSP
2. **1MB threshold** (treesitter.lua): Disables treesitter parsing specifically
3. **Completion** (completion.lua): blink's `enabled` guard disables completion per-buffer when `vim.b.large_file` is set

Files marked as `vim.b.large_file = true` are skipped by LSP (`on_attach` guard), treesitter, and completion.

### Diff Performance
Modern diff algorithm configured in options.lua:
- `algorithm:histogram` - Better than Myers for code diffs
- `linematch:60` - Shows word-level changes within lines
- `indent-heuristic` - Handles Python/YAML indentation changes intelligently

## Session Management

vim-obsession auto-starts session tracking in git repositories. Sessions are saved to `Session.vim` in project root. To restore: `nvim -S Session.vim`

## Tmux Integration

vim-tmux-navigator provides seamless pane navigation:
- `<C-h/j/k/l>` navigate between Neovim splits and tmux panes
- No distinction between Neovim windows and tmux panes
- Configure tmux side: see user's tmux.conf for matching bindings

## Common Pitfalls

1. **Modifying plugin configs without restart**: Some plugin settings require `:Lazy sync` or full restart
2. **Changing leader key after plugins load**: Leader must be set in init.lua before `require("config.lazy")`
3. **Arrow keys disabled**: hjkl navigation enforced in normal/insert/visual modes
4. **Clipboard behavior**: System clipboard NOT synced by default (use `"+y` / `"+p` explicitly)
5. **Terminal escape**: Use `<Esc><Esc>` (double Escape) to exit terminal mode
6. **Theme not persisting**: Theme saved to `~/.local/share/nvim/last_theme.txt` - check file permissions
7. **Treesitter folding issues**: Verify `foldexpr` is set to `v:lua.vim.treesitter.foldexpr()` (not the old `nvim_treesitter#foldexpr()`)
8. **Missing parser**: Run `:TSInstall <language>` or add to `ensure_installed` in `lua/plugins/treesitter.lua`
9. **LSP not attaching**: Check `:LspInfo`. clangd needs `compile_commands.json` or a `.git` root. basedpyright needs to be installed in the active venv.
10. **No completions**: Run `:checkhealth blink.cmp`. Check `:LspInfo`. Try `<C-Space>` to manually trigger.
11. **LSP on large files**: LSP is intentionally disabled for files with `vim.b.large_file = true` (>10MB).
12. **`vim.lsp.config` vs nvim-lspconfig**: This config uses the native 0.11+ API. Do NOT add nvim-lspconfig — it conflicts with `vim.lsp.config`.

## File Type Specific Notes

### C/C++
- clangd provides full LSP: go-to-def, completion, hover, code actions, inlay hints
- `<leader>ch` switches between header and source file (clangd extension)
- Format on save uses clangd (respects `.clang-format` if present; `--fallback-style=none` means no format without it)
- Needs `compile_commands.json` at project root for cross-file navigation

### Python
- 4-space indentation (PEP 8)
- basedpyright provides types, completion and navigation. Installed as a **uv tool**
  (`uv tool install basedpyright`), not per-venv — it discovers the venv at runtime
- ruff provides lint + formatting. `<leader>cf` formats; **save does not** (by design)
- Virtual env displayed in statusline when active
- treesj configured with trailing commas (Black-compatible)

### LaTeX (.tex)
- vimtex provides compilation and PDF preview
- Viewer: sioyek (Wayland-native, SyncTeX forward/inverse search) - configure in `lua/plugins/init.lua` if different
- `<leader>ll` to compile, `<leader>lv` to view
- `\cite` and `\ref` completion via vimtex omni on manual `<C-x><C-o>` (blink tex sources are buffer+path only)

### Typst (.typ)
Modern typesetting, added **alongside** LaTeX (not a replacement). LaTeX is kept for
journal submissions, Overleaf co-authored work, and TikZ; Typst is the primary driver
for self-authored documents. `.md` math stays LaTeX/KaTeX — unrelated.

- **LSP**: `tinymist` (`lua/config/lsp.lua`) — one binary covering completion, hover,
  goto-def, formatting, and the preview server. There is **no compiler step** (no
  latexmk equivalent); compile is sub-ms. Install: `sudo pacman -S tinymist` (extra repo).
- **Formatting**: typstyle, bundled inside tinymist — `<leader>cf` and format-on-save
  (`*.typ` in the glob) work with no extra package. The standalone `typstyle` binary is
  redundant, don't add it.
- **PDF export**: `exportPdf = "onSave"` writes `main.pdf` next to the source on every
  save (the browser preview renders from memory and never writes a file).
- **Preview**: `typst-preview.nvim` (`lua/plugins/init.lua`), loaded on `ft=typst`. Uses
  the **system** tinymist via `dependencies_bin` (stays pacman-managed, in lockstep with
  the LSP). Preview opens in **Firefox** (`firefox --new-window`) with bidirectional
  cursor sync — better than SyncTeX. Run `<leader>ll` on the project's **root** file
  (e.g. `main.typ`) so the whole multi-file document renders, not a standalone
  `#include`'d fragment. First `:TypstPreview` downloads a one-time `websocat` helper
  (not tinymist).
  - **Why Firefox and not vimb**: vimb (WebKitGTK) could not render typst-preview's
    incremental canvas — it composited later pages on top of page 1 (looked like the
    document was broken; it wasn't — the PDF compiles clean). Firefox renders
    correctly. It can't be isolated into a dedicated niri column while the main
    instance runs (Wayland `app_id` stays `firefox` regardless of `--class`), so the
    preview opens as a normal window in the running session and tiles via the existing
    firefox window-rule. A Chromium `--app --class` window would tile as its own column
    if a lightweight isolated preview is wanted later.
- **Completion**: full LSP (`typst = { "lsp", "buffer", "path" }`), unlike tex which is
  buffer+path only. Cite insertion is still the papis picker (`<leader>pp`), not an
  as-you-type source.
- **Bibliography**: Typst reads BibLaTeX `.bib` natively via `#bibliography("refs.bib")`,
  so papis is unchanged. `papis-bib` (`dotfiles/bash/papis-bib`) handles `.typ` too:
  bib-name from any quoted `"*.bib"` (covers `#bibliography`, alexandria's
  `#load-bibliography`, array forms), `// papis-bib: ignore` opt-out, and `.typ` in the
  cited-file scan (`filter-cited` greps `@key` / `#cite(<key>)` the same as `\cite{key}`).
  Two modes (same for `.tex` and `.typ`): **auto-sync** (the `<leader>ll` hook) is
  additive — adds newly-cited library entries, keeps everything else, on a clash the
  `.bib` version wins; it never removes or overwrites, so it's safe on every compile.
  **`papis-bib --prune`** (manual, interactive) is the only destructive path: batch-
  confirmed phases to remove uncited entries and to update entries that drifted from
  the library (`update --from`; the papis library itself is never written).

**Keymaps for `.typ`** (mirror the vimtex `<leader>l` prefix):

| Key | Action |
|-----|--------|
| `<leader>ll` | Sync `refs.bib` from papis (additive) + start/refresh preview |
| `<leader>ls` | Stop preview server |
| `<leader>lp` | Sync preview to cursor |
| `<leader>lb` | `papis-bib --prune` (interactive bib cleanup, in a `:terminal` split) |

`<leader>lb` opens a terminal split, not `:!` — nvim connects `:!` to a pipe
rather than a pty (`:h vim_diff`), and `papis-bib --prune` refuses to run
without an interactive stdin. `q` closes the split once the script exits.

`<leader>lb` is also bound on `.tex`. There is no `<leader>lv` for typst
(`TypstPreview` already toggles/opens, so a separate view map is redundant).

### SQL
- vim-dadbod for query execution
- `<leader>rr` executes line/selection
- `<leader>rf` executes entire file
- blink uses buffer+path sources only (no LSP) for SQL files
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
- There is **no alignment "mode" to enable or disable.** An earlier version of this
  file claimed alignment was "disabled by default for large file performance", backed
  by `vim.g.rcsv_align_mode = 0` in the plugin spec — but no such option exists:
  rainbow_csv reads eight `g:` variables and documents fourteen, and that name is in
  neither list nor anywhere in its source. Both the setting and the claim are gone.
  The real knob for wide files is `g:rcsv_max_columns` (default 30), which caps how
  many columns get rainbow highlighting; unset here, since nothing has been slow.

### Jupyter notebooks (.ipynb)
Notebooks are edited **as markdown**, converted on read/write by jupytext.nvim. There is no
kernel: running cells would need `ipykernel` plus a kernel-attached plugin, which is not
installed.

**Jupyter lives in the per-project venv here, never system-wide**, so the `jupytext` CLI is not
guaranteed to be present — and the plugin's behaviour when it is missing is destructive, so the
spec guards on it. `lua/plugins/init.lua` resolves the binary **before** calling `setup()`:

1. `$VIRTUAL_ENV/bin/jupytext` — direnv or `va` has activated something; trust it.
2. `<root>/.venv/bin/jupytext` — nvim launched outside the venv but inside the project.
3. `PATH` — e.g. `uv tool install jupytext`, though the normal route here is
   `uv pip install jupytext` in the project venv (see `dotfiles/revisit.md`).

Nothing resolvable ⇒ `setup()` is never called, no `BufReadCmd` is registered, and `.ipynb`
opens as **raw JSON**. That is the safe fallback, not a bug. Install jupytext, then `:restart`.

Two upstream faults make the ordering load-bearing rather than defensive:

- `commands.lua:4` runs a **bare `jupytext`** through the shell; there is no option for the
  binary path, which is why the resolved directory is prepended to `PATH`.
- `init.lua:88` reads `if vim.fn.filereadable(f) then` — that returns `0`/`1`, and **`0` is
  truthy in Lua**, so the branch runs even after conversion failed. `readfile()` throws, the
  buffer is left empty, and the next `:w` **truncates the notebook** (measured: 933 bytes and
  3 cells → 0). The `error "Couldn't find jupytext file."` on `:92` is unreachable.

Once armed, two further inputs threw raw stack traces, so jupytext's `BufReadCmd` is
re-registered behind a readability check and a `pcall`:

- **A notebook that does not exist yet** — `nvim new.ipynb`. `BufReadCmd` fires for nonexistent
  files too, and `utils.lua:16` calls `io.open(f, "r"):read "a"` with no nil check. Creating a
  notebook was therefore broken.
- **A malformed, truncated or 0-byte `.ipynb`** — `vim.json.decode` throws, or `utils.lua:17`
  indexes a missing `kernelspec`.

Registering an earlier `BufReadCmd` cannot pre-empt jupytext's — **all** matching `BufReadCmd`
autocommands run — hence pulling their callback out of `nvim_get_autocmds` and wrapping it. On
failure the raw file goes into the buffer, because jupytext registers its `BufWriteCmd` only after
a *successful* read: a failed read leaves an ordinary writable buffer, and leaving it empty would
let `:w` truncate the notebook. The wrapper must **not** return a truthy value — that deletes the
autocmd.

**`lua/jupytext/health.lua` in this repo deliberately shadows the plugin's.** Upstream's
calls `vim.health.report_start`, which Neovim removed in 0.10 (renamed `vim.health.start`),
so `:checkhealth` did not report a problem — it *threw*:
`attempt to call field 'report_start' (a nil value)`. Shadowing rather than editing the
plugin, because anything under `~/.local/share/nvim/lazy` is reverted by the next update and
tracked nowhere. `~/.config/nvim` precedes the plugin directories on the runtimepath, so ours
wins; `require("jupytext")` still reaches the plugin, since Lua wants `jupytext.lua` or
`jupytext/init.lua` and this directory has neither (verified).

The replacement also answers the question upstream's could not: it reports **which** jupytext
the venv-first resolver actually picks (`$VIRTUAL_ENV` / `<root>/.venv` / `PATH`) plus its
version, since that is what decides whether notebooks open as markdown. With none found it
reports a **warning, not an error** — declining to arm is the designed safe outcome, and
flagging it red would just train you to ignore the section.

`ft = { "ipynb" }` — the original trigger — could never fire, because Neovim detects `.ipynb` as
`json`. Hence `lazy = false`. Do **not** "simplify" this back to an `ft` trigger, and do not set
`lazy = false` without the guard: the broken trigger was the only thing preventing the
truncation bug from ever firing. Sandbox: `~/learning/playground/jupytext-nvim-tests` (17 checks,
plus `scenarios.md` for hands-on runs).

### Markdown
There is **no vim-markdown plugin** — highlighting is the treesitter `markdown` /
`markdown_inline` parsers, and in-buffer rendering is `render-markdown.nvim`
(`ft = markdown`): concealed headings, code blocks, callouts, and LaTeX math via
the `mathunicode` converter only (see the long comment in `lua/plugins/init.lua`
for why utftex/latex2text were dropped).

**Preview** is a self-contained module, `lua/config/md_preview.lua` — not a
plugin. `<leader>ll` renders the buffer with `cmark-gfm`, splices the raw LaTeX
back in for client-side KaTeX, serves it from `/tmp/nvim_md_preview` over a
localhost-bound `python3 -m http.server` on port 7654, and opens vimb. Saving a
`.md` recompiles the HTML (reload with `r` in vimb); the server and browser are
killed on `VimLeavePre`.

**Buffer-local keymaps** (`.md` only, set in `autocmds.lua` Section 14):

| Key | Action |
|-----|--------|
| `<leader>ll` | Render + open preview in vimb |
| `<leader>lt` | TOC — headings into the loclist |
| `<leader>lm` | `:MathCollapse` — collapse `$$`/content/`$$` to one line |

Folding follows the global treesitter `foldexpr` with `foldlevel=99`, so folds
start open; nothing markdown-specific disables it.

**Spell checking is on for markdown** (and tex, typst), enabled in `autocmds.lua` Section 10.
Free — `en.utf-8.spl` ships with Neovim, no package, no download.

| Key | Action |
|-----|--------|
| `]s` / `[s` | next / previous misspelling |
| `z=` | suggestions for the word under the cursor |
| `zg` | add the word to your dictionary (persists) |
| `zw` | mark a word as wrong |

It is not noisy, because `spelloptions` defaults to `noplainbuffer`, which makes spell
obey treesitter's `@nospell` captures. Verified on a real note: inline code, a whole
```` ```python ```` block, and `$$ … $$` math are all skipped; prose and headings are
checked. The one exception is a **bare URL**, which is flagged — write it as `[text](url)`
or `<url>` and it is skipped, which is better markdown regardless.

`spellfile` is deliberately **unset**. Left empty, `zg` picks the first writable spell
directory on the runtimepath, which resolves to
`~/.local/share/nvim/site/spell/en.utf-8.add`. Setting it explicitly risks pointing at
`~/.config/nvim`, which is a symlink into this repo — added words would then surface as
git changes.

## Testing Changes

When modifying this configuration:

Use `:restart` (0.12+) wherever "restart Neovim" appears below — it relaunches
the session in place.

1. **Options changes** (`lua/config/options.lua`): Restart Neovim or `:source %`
2. **Plugin additions** (`lua/plugins/*.lua`): `:Lazy sync`
3. **Keymap changes** (`lua/config/keymaps.lua`): `:source %` or restart
4. **Autocmd changes** (`lua/config/autocmds.lua`): Restart Neovim (autocmds can't be easily reloaded)
5. **Theme changes** (`lua/config/themes.lua`): Use `<leader>th` toggle or restart
6. **LSP changes** (`lua/config/lsp.lua`): Restart Neovim, then `:LspInfo` to verify
7. **Completion changes** (`lua/config/completion.lua`): `:Lazy reload blink.cmp` or restart

Always test in a git repository to verify vim-obsession session tracking works correctly.
