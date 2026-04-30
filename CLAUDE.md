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

Loading order is critical: `options → plugins (lazy.nvim) → lsp → autocmds → keymaps`. Do not reorder these phases. LSP loads after plugins because `cmp_nvim_lsp` must be available when `lsp.lua` calls `require('cmp_nvim_lsp').default_capabilities()`.

### Module Structure

```
lua/
├── config/              # Core configuration modules
│   ├── options.lua      # Editor behavior, performance, and display settings
│   ├── lazy.lua         # Plugin manager bootstrap and configuration
│   ├── keymaps.lua      # All keybindings and workflow documentation
│   ├── autocmds.lua     # Event-driven behaviors and file-type detection
│   ├── themes.lua       # Theme application and toggling logic
│   ├── lsp.lua          # LSP server setup (clangd, basedpyright, bashls)
│   └── completion.lua   # nvim-cmp completion engine setup
└── plugins/             # Plugin specifications (lazy.nvim format)
    ├── init.lua         # Main plugin list with configurations
    ├── treesitter.lua   # Treesitter setup with language parsers
    └── themes.lua       # Theme plugin declarations
```

`completion.lua` is NOT loaded directly in `init.lua`. It is loaded via the `nvim-cmp` plugin's `config` function in `plugins/init.lua`, triggered on `InsertEnter` or `CmdlineEnter`.

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
2. If no auto-reload, restart Neovim: `:qa` then reopen
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
- `basedpyright` — Python (data engineering, scientific computing)
- `bashls` — Bash/shell scripts (requires `shellcheck` for linting)

**Installation** (manual, no Mason):
```bash
sudo pacman -S clang              # clangd
pip install basedpyright          # or: uv pip install basedpyright
sudo pacman -S bash-language-server shellcheck
```

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
| `[d` / `]d` | Previous/next diagnostic |
| `<leader>e` | Show diagnostic float |
| `<leader>q` | Send diagnostics to loclist |

**Diagnostics**: `virtual_text = false` (no inline text), underlines only, rounded float on hover.

**Format on save**: Enabled for `*.c, *.cpp, *.h, *.hpp, *.py`.

**Inlay hints**: Enabled by default, toggle with `<leader>ci`.

**Large file guard**: `on_attach` checks `vim.b[bufnr].large_file` and stops the client if true.

**clangd requires `compile_commands.json`** for full functionality:
```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .
```

### Completion Configuration
nvim-cmp is configured in `lua/config/completion.lua`, loaded lazily on `InsertEnter` / `CmdlineEnter`.

**Sources** (priority order): LSP (1000) → Buffer (500) → Path (250), plus cmdline and omni (vimtex) for specific filetypes.

**Completion keymaps** (insert mode):

| Key | Action |
|-----|--------|
| `<C-Space>` | Manual trigger |
| `<C-n>` / `<Tab>` | Next item |
| `<C-p>` / `<S-Tab>` | Previous item |
| `<CR>` | Confirm (must select first) |
| `<C-e>` | Abort / close menu |
| `<C-b>` / `<C-f>` | Scroll docs up/down |

**Filetype overrides**: SQL/Markdown use buffer+path only; LaTeX uses vimtex omni; gitcommit uses buffer only.

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

**Parsers:** 35+ languages auto-installed including C/C++, Python, Rust, Go, SQL, YAML, Markdown.

**Performance:** Two-tier large file handling:
1. Files > 10MB: Disables all expensive features (autocmds.lua)
2. Files > 1MB: Disables treesitter specifically (treesitter.lua)

**Features:** Syntax highlighting, smart indentation, incremental selection (`<C-Space>` / `<BS>`), text objects (`af/if` functions, `ac/ic` classes), navigation (`]m/[m`, `]M/[M`), sticky context headers (`<leader>tc`).

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

`cmp-nvim-lsp` is `lazy = false` (loaded at startup) because LSP capabilities must be built before any server attaches.

### Git Integration Workflow
gitsigns.nvim provides in-buffer git operations:
- `]c` / `[c` - Navigate hunks
- `<leader>hp` - Preview hunk diff
- `<leader>hs` - Stage hunk
- `<leader>hr` - Reset hunk

For commits and complex git operations, the user switches to lazygit in tmux (Ctrl+b).

### Database Configuration
vim-dadbod connections are configured in `lua/plugins/init.lua` using environment variables:
```lua
vim.g.dbs = {
  duckdb = "duckdb:~/data/analytics.duckdb",
  postgres_dev = string.format(
    "postgresql://%s:%s@localhost:5432/dev_db",
    os.getenv("DB_USER"),
    os.getenv("DB_PASSWORD")
  ),
}
```

Never hardcode credentials. Always use `os.getenv()` for sensitive data.

## Performance Optimizations

### Startup Performance
- Bytecode cache enabled (`vim.loader.enable()`)
- Unused providers disabled (Ruby, Perl, Node.js)
- Built-in plugins disabled (netrw, gzip, tar, etc.)
- Treesitter auto-installs parsers asynchronously (`sync_install = false`)
- `cmp-nvim-lsp` is the only non-lazy completion plugin (startup cost is minimal)

### Large File Handling
Three-tier approach:
1. **10MB threshold** (autocmds.lua): Disables undo, swap, syntax highlighting, LSP
2. **1MB threshold** (treesitter.lua): Disables treesitter parsing specifically
3. **Completion** (completion.lua): Disables nvim-cmp per-buffer when `vim.b.large_file` is set

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
10. **No completions**: Run `:CmpStatus`. Check `:LspInfo`. Try `<C-Space>` to manually trigger.
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
- basedpyright provides type checking and LSP; install in each venv
- Virtual env displayed in statusline when active
- treesj configured with trailing commas (Black-compatible)

### LaTeX (.tex)
- vimtex provides compilation and PDF preview
- Viewer: zathura (Linux) - configure in `lua/plugins/init.lua` if different
- `<leader>ll` to compile, `<leader>lv` to view
- nvim-cmp uses vimtex omni source for `\cite` and `\ref` completion

### SQL
- vim-dadbod for query execution
- `<leader>rr` executes line/selection
- `<leader>rf` executes entire file
- nvim-cmp uses buffer+path sources only (no LSP) for SQL files

### CSV/TSV
- rainbow_csv auto-enables on CSV files
- RBQL query language available with `<leader>cq`
- Alignment disabled by default for large file performance

### Markdown
- vim-markdown provides syntax highlighting
- LaTeX math syntax supported
- Folding disabled (`vim_markdown_folding_disabled = 1`)

## Testing Changes

When modifying this configuration:

1. **Options changes** (`lua/config/options.lua`): Restart Neovim or `:source %`
2. **Plugin additions** (`lua/plugins/*.lua`): `:Lazy sync`
3. **Keymap changes** (`lua/config/keymaps.lua`): `:source %` or restart
4. **Autocmd changes** (`lua/config/autocmds.lua`): Restart Neovim (autocmds can't be easily reloaded)
5. **Theme changes** (`lua/config/themes.lua`): Use `<leader>th` toggle or restart
6. **LSP changes** (`lua/config/lsp.lua`): Restart Neovim, then `:LspInfo` to verify
7. **Completion changes** (`lua/config/completion.lua`): `:Lazy reload nvim-cmp` or restart

Always test in a git repository to verify vim-obsession session tracking works correctly.
