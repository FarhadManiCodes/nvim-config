-- lua/config/dap_adapters.lua
local dap = require("dap")

-- Native DAP requires a Python-enabled GDB (14.1+; tested here with 17.2).
-- Pretty-printers work natively. setupCommands is a cppdbg-specific field;
-- future migration also requires translating launch fields, not just type.
dap.adapters.gdb = {
  id      = "gdb",
  type    = "executable",
  command = "gdb",
  args    = { "--quiet", "--interpreter=dap" },
}

-- ── PHASE 2 STUB: cpptools (Microsoft OpenDebugAD7) ───────────────────────────
-- DO NOT UNCOMMENT until Phase 2. See Phase 2 section for install instructions.
-- Optional alternative for Phase 2; not required for printers or breakpoints.
--
-- dap.adapters.cppdbg = {
--   id      = "cppdbg",
--   type    = "executable",
--   command = os.getenv("HOME") .. "/.local/share/cpptools/extension/debugAdapters/bin/OpenDebugAD7",
--   options = { detached = false },
-- }
