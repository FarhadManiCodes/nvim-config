# Neovim DAP Configuration — Scientific Computing Setup

> Moved from the repo root to `docs/` in the 2026-08 audit; the content is
> current. Phase 1 is live and the Phase 2/3 stubs are still stubs. One caveat:
> the "all six `\d*` bindings" note near the end predates `<leader>db`/`dB`/`dl`
> being joined by the widget maps — check `lua/plugins/dap.lua` for the real list.

---

## Status

| Phase | Status |
|---|---|
| **Phase 1 — Core DAP Integration** | ✅ **Complete** — implemented and tested 2026-04-30 |
| Phase 2 — waLBerla / Pretty-Printers + MPI | Stub — begin when waLBerla work starts |
| Phase 3 — Remote HPC Cluster | Stub — begin when cluster access is active |

---

## Phase 1 — Implementation Notes (Actual vs Spec)

These are the decisions made during implementation that differ from the original spec.

**Binary picker** — replaced `vim.fn.input` with an fzf floating terminal. Searches
`build/` automatically, excludes CMake internal binaries, shows only the binary name.
Shared `pick_executable()` function used by both the standard and ASAN launch configs.

**Args** — removed from the standard launch config (default to empty; use `\dr` REPL
for `set args` if needed). Added back as a simple prompt for the ASAN config so you
can pick scenario 1–4.

**ASAN env format** — the spec used cppdbg's `environment = [{name, value}]` format.
GDB native DAP requires a flat `env = {KEY = "value"}` dict. Fixed during testing.

**stopAtEntry** — `false` for standard launch (works correctly once binary path is
right). `true` for ASAN launch — required so GDB sets up signal handling before
ASAN's `abort_on_error=1` fires SIGABRT.

**Additional keybinding** — `\dL` added for Telescope breakpoint list
(`telescope-dap.nvim` was already installed as a dependency).

**Esc to close floats** — `FileType dap-float` autocmd maps `<Esc>` and `q` to
`:close` for the `\dh`, `\ds`, `\df` floating windows.

**timeoutlen** — increased from 400ms to 600ms to make 3-key sequences like `\dL`
comfortable.

**REPL limitation** — GDB native DAP REPL accepts raw GDB commands (use `p expr`
syntax). Struct inspection returns memory addresses rather than expanded values.
This is resolved in Phase 2 with cppdbg.

---

## Instructions for Claude Code

Phase 1 is complete. When returning to this config:

- **Phase 2** begins when waLBerla work starts — uncomment `cppdbg` in
  `dap_adapters.lua`, change `type = "gdb"` → `"cppdbg"` in `dap_configurations.lua`,
  add `setupCommands` block from Appendix A.
- **Do not modify Phase 1 files** unless fixing a bug.
- **Do not install Mason** — cpptools installs manually (see Phase 2 section).

### What NOT to do

- Do not implement Phase 2 or Phase 3 — they are stubs for future sessions
- Do not change any keybindings outside the `\d*` namespace and `<PageUp>`/`<PageDown>`
- Do not add `cppdbg` as an active adapter — it is a commented stub in `dap_adapters.lua`
- Do not add any REPL command aliases

---

## Environment

| Property | Value |
|---|---|
| Neovim | 0.11+ (native `vim.lsp.config`) |
| GDB | 17.1 — native `--interpreter=dap` fully supported |
| Plugin manager | `lazy.nvim` |
| Leader key | `\` (backslash) — set in `init.lua` before plugins load |
| Python | System `python3` — `debugpy` installed via `sudo pacman -S python-debugpy` |
| OS | Arch Linux / niri |
| Telescope | Already installed ✓ |
| nvim-treesitter | Already installed ✓ (cpp and c grammars required) |

---

## Phase 1 — Core DAP Integration (Current)

### 1.1 Prerequisites

**C++ debugging:** no new installs needed. GDB 17.1 is already on PATH.

**Python debugging:** install debugpy system-wide before first Python debug session:
```bash
sudo pacman -S python-debugpy
```

Verify GDB:
```bash
which gdb && gdb --version
```

---

**Adapter strategy across phases:**

| Phase | Primary adapter | Reason |
|---|---|---|
| **1 — now** | GDB 17.1 native DAP | Zero deps, already installed |
| **2 — waLBerla** | cpptools (manual install) | `setupCommands` needed for pretty-printers |
| **3 — HPC cluster** | GDB native DAP again | No Node.js on compute nodes |

The one limitation of GDB native DAP is that it does not support the `setupCommands`
array — the mechanism that auto-sources GDB Python pretty-printer scripts at session
start. This is acceptable in Phase 1 since no custom printers are needed yet.
When waLBerla work begins, cpptools is installed manually (see Phase 2) and the
adapter is swapped with a one-line change.

---

### 1.2 File Structure

> ⚠️ **PRELIMINARY — REQUIRES AUDIT BEFORE IMPLEMENTATION**
> Before creating any files, Claude Code must inspect `~/.config/nvim/lua/` and
> confirm whether this structure fits the existing conventions. Discuss with the user
> before proceeding.

Proposed structure — all paths relative to `~/.config/nvim/`:

```
lua/
├── plugins/
│   └── dap.lua               ← Plugin spec, signs, keybindings, dependency wiring
└── config/
    ├── dap_adapters.lua       ← Adapter definitions (gdb active, cppdbg stub, lldb passive)
    └── dap_configurations.lua ← Launch configurations per language
```

Rationale for the split: each file has a single responsibility. Swapping the adapter
layer (Phase 1 → Phase 2) only requires changes to `dap_adapters.lua` and the `type`
fields in `dap_configurations.lua` — the plugin spec is untouched. If the existing
config colocates everything in `plugins/` or uses a different convention, consolidating
into one file is equally valid — the Lua content does not change.

---

### 1.3 Plugin Spec — `lua/plugins/dap.lua`

```lua
-- lua/plugins/dap.lua
return {
  {
    "mfussenegger/nvim-dap",
    lazy = true,

    -- Plugin loads only when one of these keys is first pressed (preserves startup time)
    keys = {
      -- Execution control — F-keys are physically distinct from all other bindings
      { "<F5>",  function() require("dap").continue()  end, desc = "DAP: Continue"  },
      { "<F9>",  function() require("dap").step_over() end, desc = "DAP: Step Over" },
      { "<F10>", function() require("dap").step_into() end, desc = "DAP: Step Into" },
      { "<F12>", function() require("dap").step_out()  end, desc = "DAP: Step Out"  },

      -- Breakpoint management
      { "<leader>db", function() require("dap").toggle_breakpoint() end,
        desc = "DAP: Toggle Breakpoint" },
      { "<leader>dB", function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint Condition: "))
        end,
        desc = "DAP: Set Conditional Breakpoint" },
    },

    config = function()
      local dap     = require("dap")
      local keymap  = vim.keymap.set
      local widgets = require("dap.ui.widgets")

      -- Sign column indicators
      vim.fn.sign_define("DapBreakpoint",          { text = "🔴", texthl = "DiagnosticError", linehl = "",           numhl = "" })
      vim.fn.sign_define("DapStopped",             { text = "▶️",  texthl = "DiagnosticWarn",  linehl = "CursorLine", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "⚙️",  texthl = "DiagnosticInfo",  linehl = "",           numhl = "" })

      -- Load adapter and launch configuration modules
      require("config.dap_adapters")
      require("config.dap_configurations")

      -- Stack frame navigation
      -- PageUp/PageDown confirmed free in nvim, tmux, and terminal.
      -- Moves the view up/down the call stack while paused — does NOT resume execution.
      keymap("n", "<PageUp>",   dap.up,   { desc = "DAP: Frame Up (call stack)"   })
      keymap("n", "<PageDown>", dap.down, { desc = "DAP: Frame Down (call stack)" })

      -- Floating widget introspection — on-demand, no persistent panels
      keymap({ "n", "v" }, "<leader>dh", widgets.hover, { desc = "DAP: Hover Variable" })
      keymap("n", "<leader>ds", function()
        widgets.centered_float(widgets.scopes)
      end, { desc = "DAP: Float Scopes" })
      keymap("n", "<leader>df", function()
        widgets.centered_float(widgets.frames)
      end, { desc = "DAP: Float Frames" })

      -- REPL
      keymap("n", "<leader>dr", dap.repl.toggle, { desc = "DAP: Toggle REPL" })
    end,

    dependencies = {
      -- Inline virtual text via Tree-sitter AST
      -- nvim-treesitter is already installed; cpp and c grammars must be present.
      {
        "theHamsta/nvim-dap-virtual-text",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
          require("nvim-dap-virtual-text").setup({
            enabled                     = true,
            enabled_commands            = true,
            highlight_changed_variables = true,
            highlight_new_as_changed    = true,
            show_stop_reason            = true,
            commented                   = true,
            only_first_definition       = true,
            all_references              = false,
            clear_on_continue           = false,

            -- Confirmed: running Neovim 0.11+ — inline mode is active
            virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",

            -- In inline mode suppress redundant variable name duplication
            display_callback = function(variable, buf, stackframe, node, options)
              if options.virt_text_pos == "inline" then
                return " = " .. variable.value
              else
                return variable.name .. " = " .. variable.value
              end
            end,
          })
        end,
      },

      -- Telescope integration — fuzzy search over call stacks, breakpoints, scopes
      -- telescope.nvim is already installed.
      {
        "nvim-telescope/telescope-dap.nvim",
        dependencies = { "nvim-telescope/telescope.nvim" },
        config = function()
          require("telescope").load_extension("dap")
        end,
      },

      -- Python debugpy bridge
      -- Prerequisite: sudo pacman -S python-debugpy (system-wide install)
      {
        "mfussenegger/nvim-dap-python",
        config = function()
          require("dap-python").setup("python3")
        end,
      },
    },
  },
}
```

---

### 1.4 Adapters — `lua/config/dap_adapters.lua`

```lua
-- lua/config/dap_adapters.lua
local dap = require("dap")

-- ── PRIMARY (Phase 1): GDB 17.1 native DAP ───────────────────────────────────
-- Zero-dependency. GDB 17.1 is already installed — well past the 14.1 minimum.
-- Limitation: does NOT support setupCommands array.
-- This is acceptable for Phase 1. When waLBerla work begins (Phase 2), uncomment
-- the cppdbg block below and change type = "gdb" → "cppdbg" in dap_configurations.lua.
dap.adapters.gdb = {
  id      = "gdb",
  type    = "executable",
  command = "gdb",
  args    = { "--quiet", "--interpreter=dap" },
}

-- ── PHASE 2 STUB: cpptools (Microsoft OpenDebugAD7) ───────────────────────────
-- DO NOT UNCOMMENT until Phase 2. See Phase 2 section for install instructions.
-- Required for: setupCommands (waLBerla pretty-printers), ASAN precise breakpoints.
--
-- dap.adapters.cppdbg = {
--   id      = "cppdbg",
--   type    = "executable",
--   command = os.getenv("HOME") .. "/.local/share/cpptools/extension/debugAdapters/bin/OpenDebugAD7",
--   options = { detached = false },
-- }

-- ── PASSIVE: lldb-dap ─────────────────────────────────────────────────────────
-- Defined but not referenced by any active launch configuration.
-- Available if LLDB-specific debugging is ever needed.
-- Requires: sudo pacman -S lldb
dap.adapters.lldb = {
  type    = "executable",
  command = "/usr/bin/lldb-dap",
  name    = "lldb",
}
```

---

### 1.5 Launch Configurations — `lua/config/dap_configurations.lua`

```lua
-- lua/config/dap_configurations.lua
--
-- All configurations use type = "gdb" in Phase 1.
-- To upgrade a config to Phase 2 (cppdbg): change type = "gdb" → "cppdbg"
-- and add a setupCommands block (see Phase 2 section and waLBerla Appendix).

local dap = require("dap")

dap.configurations.cpp = {}

-- ── Config 1: Standard C++ Launch ────────────────────────────────────────────
table.insert(dap.configurations.cpp, {
  name        = "Launch C++ (GDB)",
  type        = "gdb",
  request     = "launch",
  program     = function()
    local path = vim.fn.input({
      prompt     = "Path to executable: ",
      default    = vim.fn.getcwd() .. "/build/bin/",
      completion = "file",
    })
    return (path and path ~= "") and path or dap.ABORT
  end,
  args        = function()
    local args_str = vim.fn.input({ prompt = "Arguments: " })
    return vim.split(args_str, " +")
  end,
  cwd             = "${workspaceFolder}",
  stopAtEntry     = false,
  externalConsole = false,
  -- NOTE: setupCommands is not supported by the GDB native DAP adapter.
  -- When Phase 2 begins (cppdbg), add the setupCommands block here.
  -- See the Phase 2 section and waLBerla Appendix for the exact content.
})

-- ── Config 2: ASAN / UBSAN Memory Trap ───────────────────────────────────────
-- Use when the binary is compiled with -fsanitize=address or -fsanitize=undefined.
--
-- Without these env vars, ASAN calls exit(1) — the stack unwinds and state is lost.
-- abort_on_error=1 forces SIGABRT instead, which GDB catches natively.
--
-- Phase 1 behaviour: GDB intercepts SIGABRT and lands near the violation site.
-- Phase 2 improvement: with cppdbg, add setupCommands with explicit breakpoints on
-- __asan_report_error and __ubsan_handle_* to freeze precisely at the violation.
table.insert(dap.configurations.cpp, {
  name        = "Launch C++ with ASAN/UBSAN (GDB)",
  type        = "gdb",
  request     = "launch",
  program     = function()
    return vim.fn.input(
      "Path to ASAN-instrumented executable: ",
      vim.fn.getcwd() .. "/build/bin/",
      "file"
    )
  end,
  cwd         = "${workspaceFolder}",
  stopAtEntry = false,
  environment = {
    { name = "ASAN_OPTIONS",  value = "abort_on_error=1:detect_leaks=0:halt_on_error=1" },
    { name = "UBSAN_OPTIONS", value = "print_stacktrace=1:halt_on_error=1" },
  },
  -- TODO Phase 2: switch type to "cppdbg" and add setupCommands:
  --   { text = "break __asan_report_error", ignoreFailures = true }
  --   { text = "rbreak ^__ubsan_handle_",   ignoreFailures = true }
})

-- ── Config 3: Python → C++ Extension Boundary ────────────────────────────────
-- For debugging pybind11 or ctypes extensions invoked from a Python script.
-- GDB launches python3 directly and intercepts the dlopen() call when Python
-- loads the .so extension. Pending C++ breakpoints resolve at that moment.
--
-- Usage: open the Python driver script as the active buffer, then launch this config.
-- Adjust PYTHONPATH to wherever your compiled .so files live.
table.insert(dap.configurations.cpp, {
  name        = "Debug Python → C++ Extension (GDB)",
  type        = "gdb",
  request     = "launch",
  program     = "/usr/bin/python3",
  args        = { "${file}" },
  cwd         = "${workspaceFolder}",
  stopAtEntry = false,
  environment = {
    { name = "PYTHONPATH", value = "${workspaceFolder}/build/apps/pythonmodule" },
  },
})

-- ── Language aliases ──────────────────────────────────────────────────────────
dap.configurations.c    = dap.configurations.cpp
dap.configurations.rust = dap.configurations.cpp
```

---

### 1.6 Keybinding Reference

| Key | Mode | Action |
|---|---|---|
| `<F5>` | n | Continue execution |
| `<F9>` | n | Step over |
| `<F10>` | n | Step into |
| `<F12>` | n | Step out |
| `<PageUp>` | n | Move view up one call stack frame |
| `<PageDown>` | n | Move view down one call stack frame |
| `\db` | n | Toggle breakpoint |
| `\dB` | n | Set conditional breakpoint |
| `\dh` | n, v | Hover variable under cursor |
| `\ds` | n | Float scopes window |
| `\df` | n | Float frames window |
| `\dr` | n | Toggle REPL |

Key region logic:
- **F-keys** — execution control (move program state forward)
- **PageUp/PageDown** — stack frame navigation (move view through paused state)
- **`\d*`** — breakpoints and introspection

All bindings confirmed free. `<PageUp>`/`<PageDown>` are unbound in nvim, tmux, and
the terminal. All six `\d*` bindings have no conflicts in the existing config.

---

### 1.7 Typical Debugging Session Flow

1. Build with debug symbols: `cmake -DCMAKE_BUILD_TYPE=Debug ..`
2. Open a source file, press `\db` to set a breakpoint
3. Press `<F5>` → select `Launch C++ (GDB)` from the picker
4. Enter the path to the binary when prompted
5. Execution pauses at the breakpoint — virtual text appears inline with variable values
6. `\dh` over any variable for a floating detailed view
7. `<PageDown>` / `<PageUp>` to walk up and down the call stack
8. `\ds` for the full scopes float (locals, registers)
9. `\dr` to open the REPL for manual GDB commands
10. `<F9>` / `<F10>` / `<F12>` to step, `<F5>` to continue

---

## Phase 2 — waLBerla / Pretty-Printers + MPI (Future)

> **Status: stub only — do not implement until waLBerla work begins.**

### 2.1 Install cpptools manually (no Mason)

```bash
mkdir -p ~/.local/share/cpptools
curl -L "https://github.com/microsoft/vscode-cpptools/releases/latest/download/cpptools-linux-x64.vsix" \
  -o /tmp/cpptools.vsix
unzip /tmp/cpptools.vsix -d ~/.local/share/cpptools

# Verify
ls ~/.local/share/cpptools/extension/debugAdapters/bin/OpenDebugAD7
```

### 2.2 Activate cppdbg

In `dap_adapters.lua`: uncomment the `cppdbg` block (path is already correct).

In `dap_configurations.lua`: change `type = "gdb"` → `type = "cppdbg"` in any config
that needs pretty-printer support. Then add `setupCommands` — see waLBerla Appendix.

### 2.3 MPI Parallel Debugging (Volatile Spin-Trap)

Pattern:
1. Insert `volatile int trap = 1; while(trap) { sleep(1); }` in `main()` guarded by rank
2. Launch externally: `mpirun -np 4 ./sim`
3. Use `request = "attach"` with `processId = require("dap.utils").pick_process`
4. Attach to the target rank PID
5. In REPL: `.exec set var trap = 0` to release the spin-lock
6. Add `break MPI_Abort` in `setupCommands` to catch distributed crashes

Configs to add: `Attach to MPI Rank (PID Picker)`, `Launch with MPI_Abort Breakpoint`

---

## Phase 3 — Remote HPC Cluster Debugging (Future)

> **Status: stub only — do not implement until cluster access is active.**

Pattern: `gdbserver` on the remote node, local config uses `miDebuggerServerAddress`.

```bash
# On the remote compute node:
gdbserver 0.0.0.0:6666 ./build/bin/sim config.prm
```

Config to add: `Attach to Remote HPC Cluster (gdbserver)`
Key fields: `miDebuggerServerAddress = "cluster.hpc.domain:6666"`, `set sysroot /` in
`setupCommands` to prevent local library mapping conflicts.

---

## Appendix A — waLBerla Pretty-Printer setupCommands

Add this block to any cppdbg launch configuration when waLBerla is active.
Replace the `source` path with the actual location in the waLBerla repo tree.

```lua
setupCommands = {
  { text = "-enable-pretty-printing",   ignoreFailures = false },
  { text = "set auto-load safe-path /", ignoreFailures = true  },
  {
    text           = "source /path/to/walberla/utilities/gdbPrettyPrinter/walberla_printers.py",
    description    = "Load waLBerla GhostLayerField and BlockStorage pretty-printers",
    ignoreFailures = true,
  },
  { text = "set print pretty on", ignoreFailures = true },
}
```

The printer file lives at:
```
<walberla_root>/utilities/gdbPrettyPrinter/walberla_printers.py
```

---

## Appendix B — Adapter Summary

| Adapter | Status | Phase | Notes |
|---|---|---|---|
| `gdb` — GDB 17.1 native DAP | **Active** | 1 and 3 | No deps, no `setupCommands` |
| `cppdbg` — cpptools | Commented stub | 2 | Manual install; enables `setupCommands` |
| `lldb` — lldb-dap | Defined, passive | — | Unused; available if needed |
