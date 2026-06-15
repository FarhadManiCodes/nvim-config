-- lua/config/dap_configurations.lua
--
-- All configurations use type = "gdb" in Phase 1.
-- To upgrade a config to Phase 2 (cppdbg): change type = "gdb" → "cppdbg"
-- and add a setupCommands block (see Phase 2 section and waLBerla Appendix).

local dap = require("dap")

dap.configurations.cpp = {}

-- ── Shared: executable picker (fzf floating terminal) ────────────────────────
-- Finds binaries in build/, excludes CMake internals.
-- Opens fzf in a small floating terminal — shows only the binary name,
-- returns the full path to nvim-dap via coroutine.
local function pick_executable()
  return coroutine.create(function(co)
    local build_dir = vim.fn.getcwd() .. "/build"
    local exes = vim.fn.systemlist(
      "find " .. build_dir
      .. " -maxdepth 3 -type f -executable"
      .. " ! -name '*.so' ! -name '*.a'"
      .. " ! -path '*/CMakeFiles/*'"
      .. " 2>/dev/null | sort"
    )
    if #exes == 0 then
      vim.notify("No executables found in " .. build_dir, vim.log.levels.WARN)
      coroutine.resume(co, dap.ABORT)
      return
    end

    local input_file  = vim.fn.tempname()
    local output_file = vim.fn.tempname()

    local fh = io.open(input_file, "w")
    fh:write(table.concat(exes, "\n") .. "\n")
    fh:close()

    local buf    = vim.api.nvim_create_buf(false, true)
    local width  = 60
    local height = math.min(#exes + 4, 15)
    local win    = vim.api.nvim_open_win(buf, true, {
      relative  = "editor",
      width     = width,
      height    = height,
      col       = math.floor((vim.o.columns - width) / 2),
      row       = math.floor((vim.o.lines   - height) / 2),
      style     = "minimal",
      border    = "rounded",
      title     = " DAP: Select Executable ",
      title_pos = "center",
    })

    -- fzf displays only the binary name (--with-nth) but writes the full path
    vim.fn.jobstart(
      "fzf --prompt='> ' --delimiter='/' --with-nth='-1' --reverse"
      .. " < " .. input_file .. " > " .. output_file,
      {
        term = true,
        on_exit = function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
          vim.schedule(function()
            local rf  = io.open(output_file, "r")
            local sel = rf and rf:read("*l") or nil
            if rf then rf:close() end
            os.remove(input_file)
            os.remove(output_file)
            coroutine.resume(co, (sel and sel ~= "") and sel or dap.ABORT)
          end)
        end,
      }
    )
    vim.cmd("startinsert")
  end)
end

-- ── Config 1: Standard C++ Launch ────────────────────────────────────────────
table.insert(dap.configurations.cpp, {
  name        = "Launch C++ (GDB)",
  type        = "gdb",
  request     = "launch",
  program         = pick_executable,
  args            = {},
  cwd             = "${workspaceFolder}",
  stopAtEntry     = false,
  externalConsole = false,
  -- NOTE: setupCommands is not supported by the GDB native DAP adapter.
  -- When Phase 2 begins (cppdbg), add the setupCommands block here.
})

-- ── Config 2: ASAN / UBSAN Memory Trap ───────────────────────────────────────
-- Use when the binary is compiled with -fsanitize=address or -fsanitize=undefined.
--
-- Without these env vars, ASAN calls exit(1) — the stack unwinds and state is lost.
-- abort_on_error=1 forces SIGABRT instead, which GDB catches natively.
--
-- Phase 1: GDB intercepts SIGABRT and lands near the violation site.
-- Phase 2: with cppdbg, add setupCommands with explicit breakpoints on
-- __asan_report_error and __ubsan_handle_* to freeze precisely at the violation.
table.insert(dap.configurations.cpp, {
  name        = "Launch C++ with ASAN/UBSAN (GDB)",
  type        = "gdb",
  request     = "launch",
  program     = pick_executable,
  args        = function()
    local choice = vim.fn.input("Scenario [1=heap overflow 2=use-after-free 3=stack overflow 4=int overflow]: ")
    if choice == "" then return {} end
    return { choice }
  end,
  cwd         = "${workspaceFolder}",
  stopAtEntry = true,
  -- GDB native DAP uses flat env dict, not cppdbg's {name,value} array
  env = {
    ASAN_OPTIONS  = "abort_on_error=1:detect_leaks=0:halt_on_error=1",
    UBSAN_OPTIONS = "print_stacktrace=1:halt_on_error=1",
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
  env = {
    PYTHONPATH = "${workspaceFolder}/build/apps/pythonmodule",
  },
})

-- ── Language aliases ──────────────────────────────────────────────────────────
dap.configurations.c    = dap.configurations.cpp
dap.configurations.rust = dap.configurations.cpp
