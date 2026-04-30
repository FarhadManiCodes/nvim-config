-- lua/config/dap_adapters.lua
local dap = require("dap")

-- ── PRIMARY (Phase 1): GDB 17.1 native DAP ───────────────────────────────────
-- Zero-dependency. GDB 17.1 is already installed — well past the 14.1 minimum.
-- Limitation: does NOT support setupCommands array.
-- When waLBerla work begins (Phase 2), uncomment the cppdbg block below and
-- change type = "gdb" → "cppdbg" in dap_configurations.lua.
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
