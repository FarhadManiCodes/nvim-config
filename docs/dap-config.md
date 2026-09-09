# Neovim DAP configuration — scientific computing setup

Debugging C/C++ (and Python → C++ extensions) with `nvim-dap` and GDB's native DAP
interpreter. Phase 1 is live; Phases 2 and 3 are stubs with no code behind them.

> **Rewritten 2026-09-09.** This was a pre-implementation *spec* that shipped in April 2026
> and never became a post-implementation record. It still carried a "REQUIRES AUDIT BEFORE
> IMPLEMENTATION — discuss with the user before proceeding" banner over a decision made a
> year earlier, and ~250 lines of Lua transcribed from the config. Those listings had drifted
> from the code they claimed to document — they showed `vim.fn.input` where the shipped
> config uses `pick_executable`, and an `lldb` adapter that does not exist — which is the
> normal fate of a copy. The listings are now pointers to the real files. Argument and full
> text in `git log -p -- docs/dap-config.md`.

## Status

| Phase | Status |
|---|---|
| **Phase 1 — core DAP integration** | ✅ **Complete** — implemented and tested 2026-04-30 |
| Phase 2 — waLBerla / pretty-printers + MPI | Stub — begin when waLBerla work starts |
| Phase 3 — remote HPC cluster | Stub — begin when cluster access is active |

## Where the code lives

Three files, each with one job. The split exists so that swapping the adapter for Phase 2
touches the adapter layer and the `type` fields only, never the plugin spec.

| File | Holds |
|---|---|
| `lua/plugins/dap.lua` | Plugin spec, lazy `keys`, breakpoint signs, widget keymaps, dependency wiring (`nvim-dap-virtual-text`, `telescope-dap`, `nvim-dap-python`) |
| `lua/config/dap_adapters.lua` | Adapter definitions — `gdb` active, `cppdbg` a commented Phase 2 stub |
| `lua/config/dap_configurations.lua` | The three C++ launch configurations, plus the `c` and `rust` aliases |

**Read those files rather than a transcription of them.** They are the source of truth and
they carry their own inline commentary.

## Environment

| Property | Value |
|---|---|
| Neovim | 0.11+ (native `vim.lsp.config`) |
| GDB | 17.1 — native `--interpreter=dap` fully supported |
| Leader key | `\` (backslash), set in `init.lua` before plugins load |
| Python | system `python3`; `debugpy` via `sudo pacman -S python-debugpy` |
| OS | Arch Linux / niri |

C++ debugging needs no new installs — GDB is already on `PATH`. Python debugging needs
`python-debugpy` before the first session.

## Adapter strategy across phases

| Phase | Primary adapter | Reason |
|---|---|---|
| **1 — now** | GDB 17.1 native DAP | zero deps, already installed |
| **2 — waLBerla** | cpptools (manual install) | `setupCommands` needed for pretty-printers |
| **3 — HPC cluster** | GDB native DAP again | no Node.js on compute nodes |

The one limitation of GDB native DAP is that it does not support the `setupCommands` array —
the mechanism that auto-sources GDB Python pretty-printer scripts at session start. That is
acceptable while no custom printers are needed. When waLBerla work begins, cpptools is
installed manually and the adapter swaps with a one-line change.

## Phase 1 — implementation notes (actual vs spec)

Decisions made during implementation that differ from the original spec. These are the part
of this document that is not recoverable by reading the code.

**Binary picker** — replaced `vim.fn.input` with an fzf floating terminal. Searches `build/`
automatically, excludes CMake internal binaries, shows only the binary name. A shared
`pick_executable()` serves both the standard and ASAN launch configs.

**Args** — removed from the standard launch config (default empty; use the `\dr` REPL for
`set args` if needed). Kept as a simple prompt on the ASAN config so a scenario can be picked.

**ASAN env format** — the spec used cppdbg's `environment = [{name, value}]`. GDB native DAP
requires a flat `env = {KEY = "value"}` dict. Fixed during testing.

**stopAtEntry** — `false` for the standard launch. `true` for ASAN, required so GDB sets up
signal handling before ASAN's `abort_on_error=1` fires SIGABRT.

**Esc to close floats** — a `FileType dap-float` autocmd maps `<Esc>` and `q` to `:close` for
the `\dh`, `\ds`, `\df` windows.

**timeoutlen** — raised from 400 ms to 600 ms so three-key sequences are comfortable.

**REPL limitation** — the GDB native DAP REPL takes raw GDB commands (`p expr`). Struct
inspection returns addresses rather than expanded values; Phase 2 resolves this with cppdbg.

## Keybindings

Verified against `lua/plugins/dap.lua` on 2026-09-09.

| Key | Mode | Action |
|---|---|---|
| `<F5>` | n | Continue |
| `<F9>` | n | Step over |
| `<F10>` | n | Step into |
| `<F12>` | n | Step out |
| `<PageUp>` / `<PageDown>` | n | Move view up/down one call-stack frame |
| `\db` | n | Toggle breakpoint |
| `\dB` | n | Set conditional breakpoint |
| `\dl` | n | List breakpoints (Telescope) |
| `\dh` | n, v | Hover variable under cursor |
| `\ds` | n | Float scopes window |
| `\df` | n | Float frames window |
| `\dr` | n | Toggle REPL |

Region logic: **F-keys** move program state forward; **PageUp/PageDown** move the view
through paused state without resuming; **`\d*`** is breakpoints and introspection.

`<PageUp>`/`<PageDown>` were confirmed free in nvim, tmux and the terminal. There are
**seven** `\d*` bindings, not the six an earlier version of this table claimed — it predated
`\dl`, and called it `\dL`.

## A typical session

1. Build with debug symbols: `cmake -DCMAKE_BUILD_TYPE=Debug ..`
2. Open a source file, `\db` to set a breakpoint
3. `<F5>` → pick `Launch C++ (GDB)`; the picker offers binaries found under `build/`
4. Execution pauses — virtual text shows variable values inline
5. `\dh` over a variable for a floating detail view
6. `<PageDown>` / `<PageUp>` to walk the call stack
7. `\ds` for the full scopes float (locals, registers)
8. `\dr` for the REPL and raw GDB commands
9. `<F9>` / `<F10>` / `<F12>` to step, `<F5>` to continue

## Phase 2 — waLBerla / pretty-printers + MPI (future)

> **Stub only — do not implement until waLBerla work begins.**

**Install cpptools manually (no Mason):**

```bash
mkdir -p ~/.local/share/cpptools
curl -L "https://github.com/microsoft/vscode-cpptools/releases/latest/download/cpptools-linux-x64.vsix" \
  -o /tmp/cpptools.vsix
unzip /tmp/cpptools.vsix -d ~/.local/share/cpptools
ls ~/.local/share/cpptools/extension/debugAdapters/bin/OpenDebugAD7   # verify
```

**Activate cppdbg:** uncomment the `cppdbg` block in `dap_adapters.lua` (the path is already
correct), change `type = "gdb"` → `"cppdbg"` in the configs that need pretty-printers, and add
the `setupCommands` block from Appendix A.

**MPI parallel debugging (volatile spin-trap):**

1. Insert `volatile int trap = 1; while(trap) { sleep(1); }` in `main()`, guarded by rank
2. Launch externally: `mpirun -np 4 ./sim`
3. Use `request = "attach"` with `processId = require("dap.utils").pick_process`
4. Attach to the target rank's PID
5. In the REPL: `.exec set var trap = 0` to release the spin-lock
6. Add `break MPI_Abort` in `setupCommands` to catch distributed crashes

Configs to add: *Attach to MPI Rank (PID Picker)*, *Launch with MPI_Abort Breakpoint*.

## Phase 3 — remote HPC cluster debugging (future)

> **Stub only — do not implement until cluster access is active.**

`gdbserver` on the remote node; the local config uses `miDebuggerServerAddress`.

```bash
# on the remote compute node:
gdbserver 0.0.0.0:6666 ./build/bin/sim config.prm
```

Config to add: *Attach to Remote HPC Cluster (gdbserver)*. Key fields:
`miDebuggerServerAddress = "cluster.hpc.domain:6666"`, and `set sysroot /` in `setupCommands`
to prevent local library mapping conflicts.

## Appendix A — waLBerla pretty-printer setupCommands

Add to any cppdbg launch configuration once waLBerla is active. Replace the `source` path with
the real location in the waLBerla tree.

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

The printer file lives at
`<walberla_root>/utilities/gdbPrettyPrinter/walberla_printers.py`.

## Appendix B — adapter summary

| Adapter | Status | Phase | Notes |
|---|---|---|---|
| `gdb` — GDB 17.1 native DAP | **Active** | 1 and 3 | no deps, no `setupCommands` |
| `cppdbg` — cpptools | Commented stub | 2 | manual install; enables `setupCommands` |

An earlier version listed a third, passive `lldb` adapter. There is no such block in
`dap_adapters.lua` — verified 2026-09-09, the file defines `gdb` and nothing else live.
