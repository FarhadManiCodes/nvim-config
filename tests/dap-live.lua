-- Actual native GDB DAP sessions, isolated from the user's configuration.
-- nvim --headless -u NONE -i NONE -l tests/dap-live.lua
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-dap")
local dap = require("dap")
local I = dofile("lua/config/dap_configurations.lua")._internal
dofile("lua/config/dap_adapters.lua")
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local function write(name, lines)
  local path = root .. "/" .. name
  vim.fn.writefile(lines, path)
  return path
end
local function compile(name, source, flags)
  local path = write(name .. ".c", source)
  local argv = { "gcc", "-g", "-O0", "-fno-omit-frame-pointer", path, "-o", root .. "/" .. name }
  vim.list_extend(argv, flags or {})
  local result = vim.system(argv, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return root .. "/" .. name, path
end
local normal = compile("normal", {
  '#include <stdlib.h>', '#include <string.h>',
  'int main(void) { const char *s = getenv("DAP_LIVE_SENTINEL"); return s && !strcmp(s, "preserved") ? 0 : 7; }',
})
local asan = compile("asan", {
  '#include <stdlib.h>',
  'int main(void) { volatile int *p = malloc(sizeof(int)); p[1] = 7; free((void *)p); return 0; }',
}, { "-fsanitize=address" })
local ubsan = compile("ubsan", {
  '#include <limits.h>', 'int main(void) { volatile int x = INT_MAX; return x + 1; }',
}, { "-fsanitize=undefined" })
local extension, extension_source = compile("extension.so", {
  'int native_add(int x) {', '  volatile int result = x + 1;', '  return result;', '}',
}, { "-shared", "-fPIC" })
local driver = write("driver.py", {
  'import ctypes', 'lib = ctypes.CDLL(' .. vim.json.encode(extension) .. ')',
  'assert lib.native_add(2) == 3',
})
vim.env.DAP_LIVE_SENTINEL = "preserved"
local function session(label, config, expected_stops, expected_exit)
  local stopped, terminated, exitcode, failure = {}, false
  dap.listeners.after.event_stopped["regression"] = function(s, body)
    stopped[#stopped + 1] = body.reason
    s:request("stackTrace", { threadId = body.threadId }, function(err, response)
      if err then failure = vim.inspect(err)
      elseif #stopped == 1 and config.stopAtBeginningOfMainSubprogram then
        if not response.stackFrames[1].name:match("main") then failure = "entry stop was not main" end
      end
      vim.schedule(function() dap.continue() end)
    end)
  end
  dap.listeners.after.event_exited["regression"] = function(_, body) exitcode = body.exitCode end
  dap.listeners.after.event_terminated["regression"] = function() terminated = true end
  config.type, config.request, config.cwd = "gdb", "launch", root
  dap.run(config)
  assert(vim.wait(20000, function() return terminated end, 10), label .. " timed out; inspect DAP log")
  assert(not failure, failure)
  assert(#stopped == expected_stops, label .. " stops: " .. vim.inspect(stopped))
  if expected_exit then assert(exitcode == expected_exit, label .. " exit: " .. tostring(exitcode)) end
  if expected_stops == 2 then assert(stopped[2] == "signal", label .. " did not stop on signal: " .. vim.inspect(stopped)) end
  assert(vim.wait(3000, function() return dap.session() == nil end))
  print("PASS " .. label)
end
session("inherited environment and main stop", {
  name = "normal", program = normal, env = I.sanitizer_env(), stopAtBeginningOfMainSubprogram = true,
}, 1, 0)
session("ASAN signal", {
  name = "asan", program = asan, env = I.sanitizer_env(), stopAtBeginningOfMainSubprogram = true,
}, 2)
session("UBSAN-only signal", {
  name = "ubsan", program = ubsan, env = I.sanitizer_env(), stopAtBeginningOfMainSubprogram = true,
}, 2)
local buf = vim.fn.bufadd(extension_source)
vim.fn.bufload(buf)
require("dap.breakpoints").set({}, buf, 2)
session("Python pending native breakpoint", {
  name = "extension", program = "/usr/bin/python3", args = { driver },
}, 1, 0)
dap.clear_breakpoints()
vim.fn.delete(root, "rf")
print("All live GDB DAP checks passed")
