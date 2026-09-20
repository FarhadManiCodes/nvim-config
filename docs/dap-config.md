# Neovim DAP configuration

Phase 1 uses native GDB DAP for C/C++, Rust and Python-loaded native extensions,
and debugpy for Python source debugging. Phases 2 and 3 remain unimplemented.
Reviewed 2026-09-20; observed versions: Neovim 0.12.5 and GDB 17.2.

## Requirements and ownership

This repository requires Neovim 0.12+. Native DAP needs GDB built with Python
support (14.1+; current behavior verified against 17.2). The binary picker uses
GNU find and fzf; without fzf it offers manual path entry. Rust discovery uses
Cargo offline metadata. Build your programs with debug symbols before launching.
For Python source debugging, the `python3` used by dap-python must have debugpy
installed (`sudo pacman -S python-debugpy` for system Python on Arch).
Native extension debugging does not require debugpy.

| File | Responsibility |
|---|---|
| `lua/plugins/dap.lua` | Lazy keys, signs, widgets, virtual text and dap-python setup |
| `lua/config/dap_adapters.lua` | Active native GDB adapter; commented cppdbg stub |
| `lua/config/dap_configurations.lua` | Launches, interpreter resolution, async binary picker |

## Launches and project setup

Open Neovim at the project root: `${workspaceFolder}` means its current working
directory, not automatic Git/LSP root detection. Use trusted project-local
`.nvim.lua` configuration for alternate working directories or custom launches.

- **C/C++:** standard and ASAN/UBSAN launches search `build/` recursively, pruning
  `CMakeFiles` and excluding `.a`, `.so` and versioned `.so` libraries. Results are
  executable candidates, not a guarantee of debug symbols or a native binary.
- **Rust:** its own standard GDB launch obtains `target_directory` through
  `cargo metadata --no-deps --format-version 1 --offline`. It searches target
  outputs, including debug/release and cross-target layouts, pruning build-script,
  dependency, fingerprint and incremental directories. Cargo test binaries under
  `deps` require manual selection. This does not build or install anything.
- **Picker:** fzf shows relative paths so duplicate basenames remain distinguishable.
  Select the manual-path row for nonstandard layouts. Discovery failures or missing
  directories also offer manual entry. Esc cancels fzf; canceling the subsequent
  path/argument prompt aborts the launch. Manual paths must be executable files.
- **Arguments:** C/C++ and Rust launches prompt before starting. Blank means none;
  quoted strings are split with `dap.utils.splitstr`, not evaluated by a shell.
  GDB's REPL `set args` changes a subsequent run, not the current process.
- **Sanitizers:** the sanitizer launch stops at `main` using GDB's
  `stopAtBeginningOfMainSubprogram`. This is optional inspection time, not a
  prerequisite for signal handling. Both ASAN and UBSAN use `abort_on_error=1`
  and `halt_on_error=1`, allowing GDB to stop on SIGABRT. The stop is in the abort
  path; walk up the stack to the violation. ASAN leak detection is disabled because
  LeakSanitizer does not work under ptrace. Run a separate undebugged leak check.
  Overrides are merged into the inherited environment at launch time; the configured
  ASAN/UBSAN option strings replace any inherited strings of those names.

The standard launches run until a breakpoint, signal or exit. `stopAtEntry` and
`externalConsole` are cppdbg fields and are not used by native GDB here.

## Python → C++ extensions

Open the Python driver and select **Debug Python → C++ Extension (GDB)** from
the Python launch menu. The existing debugpy choices remain available separately.
The active file is passed as the Python script argument.

Interpreter lookup is performed at launch: active `VIRTUAL_ENV`, active
`CONDA_PREFIX`, project `.venv`, then `python3` on PATH. A broken explicitly active
environment aborts with a warning. Activate centrally managed environments before
starting Neovim; this resolver does not execute `.envrc` files.

The process inherits `PYTHONPATH` and library paths. Make the extension importable
through the project's installation/environment, or supply `env` in a project-local
configuration, merging it with `vim.fn.environ()` because GDB replaces the entire
inferior environment when `env` is supplied. No project-specific build path is
hardcoded. Set native source breakpoints before launching; pending breakpoints can
resolve when Python loads the shared library. This session steps native code, not
Python source; it is not simultaneous mixed-language source debugging.

## Keys and a typical session

Leader is `\`. Existing mappings are unchanged.

| Key | Mode | Action |
|---|---|---|
| `<F5>` | n | Launch / continue |
| `<F9>` | n | Step over |
| `<F10>` | n | Step into |
| `<F12>` | n | Step out |
| `<PageUp>` / `<PageDown>` | n | Move up/down the paused call stack |
| `\db` | n | Toggle breakpoint |
| `\dB` | n | Conditional breakpoint |
| `\dl` | n | List breakpoints and open quickfix (`]q` / `[q`) |
| `\dh` | n, v | Hover |
| `\ds` | n | Scopes float |
| `\df` | n | Frames float |
| `\dr` | n | Toggle REPL |

Build with debug symbols, open source, set a breakpoint with `\db`, then press
F5 and select a launch and executable. Enter arguments if prompted. At a stop,
inspect scopes/hover and step or continue. Esc or `q` closes the DAP floats.
The native GDB REPL accepts raw GDB commands such as `p value`, `p *pointer` and
`bt`. Its output is textual; expandable structured inspection lives in the widgets.
Structs are not inherently printed as addresses. Native GDB supports pretty-printers.
Inline values are convenient but the open virtual-text issues in `TODO.md` mean
same-named variables in different scopes should be cross-checked in scopes/REPL.

## Phase 2 — waLBerla / MPI (future, do not implement yet)

Revisit when waLBerla work begins. Native GDB can load Python printers through
trusted auto-loading, initialization commands or a REPL `source` command; cppdbg
is an optional alternative, not a prerequisite for printers or precise breakpoints.
The waLBerla printer location and registration procedure must be verified against
the actual checkout; the former `utilities/gdbPrettyPrinter/walberla_printers.py`
path was not verified and must not be assumed.

If cppdbg is selected, install Microsoft's cpptools manually (no Mason), verify
`~/.local/share/cpptools/extension/debugAdapters/bin/OpenDebugAD7`, then activate
the existing commented adapter. Translate native launch fields as well as `type`:
native `env` is a dictionary; cppdbg uses an `environment` name/value array.
Native `stopAtBeginningOfMainSubprogram` becomes cppdbg `stopAtEntry`.
`setupCommands` is cppdbg-specific; loading printers is not a one-line adapter swap.
Trust only the required printer directories with `add-auto-load-safe-path`, never
`set auto-load safe-path /`.

MPI attachment is also future work. A rank-specific volatile spin trap can hold a
process for attachment. Native GDB attach uses `pid`; cppdbg uses `processId`.
Release the trap through native REPL `set var trap = 0` (cppdbg uses `.exec`).
Breakpoints on `MPI_Abort` or sanitizer handlers do not require cppdbg.

## Phase 3 — remote HPC (future, do not implement yet)

A native GDB DAP attach can use `target = "localhost:6666"` and a matching local
`program` to connect to a remote gdbserver through an SSH tunnel. Run gdbserver
bound to loopback on the compute node and arrange the tunnel under cluster policy.
`miDebuggerServerAddress` is a cppdbg setting, not a native GDB setting.

Use matching executable/debug symbols and remote libraries. Configure an appropriate
sysroot (a matching local copy or GDB's remote target filesystem support); blindly
setting `sysroot /` selects local libraries and does not solve version mismatches.
Native GDB and cppdbg can both use a local debugger with remote gdbserver; absence
of Node.js on compute nodes does not by itself select an adapter.

## Validation

Run `nvim --headless -u NONE -i NONE -l tests/dap.lua` for registration, environment,
discovery and picker lifecycle regressions, and
`nvim --headless -c 'lua dofile("tests/runtime.lua")'` for real-config wiring.
`tests/dap-live.lua` compiles temporary native fixtures and exercises actual GDB DAP
sessions: `nvim --headless -u NONE -i NONE -l tests/dap-live.lua` (needs gcc, GDB,
system Python and permission to trace child processes).
These replace the old external playground check, whose synchronous discovery,
three-level search and Rust-alias assertions no longer describe this configuration.

Interactive acceptance still includes fzf focus/selection/cancellation, small terminal
geometry, Python-menu selection, breakpoint quickfix navigation, scopes and inline
rendering. Historical Phase 1 testing on 2026-04-30 is not proof of these current paths.
Load DAP first (`:lua require("lazy").load({plugins={"nvim-dap"}})`), then use
`:checkhealth dap` after installation changes. Function-based debugpy adapters
cannot be validated by that check; validate them with a Python debug session.

## References

- [Native GDB DAP fields](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html)
- [GDB printer selection](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Selecting-Pretty_002dPrinters.html)
- [GDB auto-load trust](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Auto_002dloading-safe-path.html)
- [cppdbg launch fields](https://code.visualstudio.com/docs/cpp/launch-json-reference)
