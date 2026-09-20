-- nvim --headless -u NONE -i NONE -l tests/dap.lua
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-dap")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-dap-python")
require("dap-python").setup("python3")
local dap = require("dap")
local I = dofile("lua/config/dap_configurations.lua")._internal
local count = 0
local function check(value, message)
  assert(value, message)
  count = count + 1
end
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local function executable(name)
  local path = root .. "/" .. name
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ "#!/bin/sh", "exit 0" }, path)
  assert(vim.uv.fs_chmod(path, 493))
  return path
end
local expected = {
  executable("build/a/b/c/solver"), executable("build/apps/solver"),
  executable("build/it's $a\tstrange\nname"),
}
executable("build/CMakeFiles/deep/compiler")
executable("build/libx.so.1")
executable("build/libx.so")
executable("build/libx.a")
local function find(path, rust)
  local complete, paths, reason = false
  I.find_executables(path, rust, function(p, r) paths, reason, complete = p, r, true end)
  assert(vim.wait(5000, function() return complete end))
  return paths, reason
end
table.sort(expected)
check(vim.deep_equal(find(root .. "/build", false), expected), "deep/unusual paths and library/CMake exclusions")
local paths, reason = find(root .. "/missing", false)
check(paths == nil and reason:match("No build directory"), "missing directory")
vim.fn.mkdir(root .. "/empty", "p")
paths, reason = find(root .. "/empty", false)
check(paths == nil and reason:match("No executables"), "empty directory")
local rust = executable("target/debug/solver")
executable("target/debug/deps/test")
executable("target/debug/build/helper")
check(vim.deep_equal(find(root .. "/target", true), { rust }), "Cargo internals pruned")
check(#dap.configurations.cpp == 2 and dap.configurations.c == dap.configurations.cpp, "C/C++ registration")
check(#dap.configurations.rust == 1 and dap.configurations.rust ~= dap.configurations.cpp, "Rust independent")
local native, debugpy = 0, 0
for _, cfg in ipairs(dap.configurations.python) do
  if cfg.type == "gdb" then native = native + 1 else debugpy = debugpy + 1 end
end
check(native == 1 and debugpy > 0, "Python native launch preserves debugpy")
for _, configs in pairs(dap.configurations) do
  for _, cfg in ipairs(configs) do
    if cfg.type == "gdb" then
      check(cfg.stopAtEntry == nil and cfg.externalConsole == nil, "no unsupported fields")
    end
  end
end
vim.env.DAP_REGRESSION_SENTINEL = "inherited"
local env = I.sanitizer_env()
check(env.DAP_REGRESSION_SENTINEL == "inherited" and env.PATH == vim.env.PATH, "inherited environment")
check(env.UBSAN_OPTIONS:match("abort_on_error=1") ~= nil, "UBSAN abort")
check(dap.configurations.cpp[2].stopAtBeginningOfMainSubprogram, "sanitizer main stop")
local original_input = vim.ui.input
local function args(value)
  vim.ui.input = function(_, cb) vim.schedule(function() cb(value) end) end
  local result, finished
  local co = coroutine.create(function() result = coroutine.yield(); finished = true end)
  assert(coroutine.resume(co))
  assert(coroutine.resume(I.arguments(), co))
  assert(vim.wait(1000, function() return finished end))
  return result
end
check(vim.deep_equal(args('one "two three"'), { "one", "two three" }), "quoted arguments")
check(vim.deep_equal(args(""), {}), "empty arguments")
check(args(nil) == dap.ABORT, "cancel arguments")
local old_venv, old_conda = vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX
vim.env.CONDA_PREFIX = nil
vim.env.VIRTUAL_ENV = root .. "/venv"
local interpreter = executable("venv/bin/python")
check(I.python() == interpreter, "active environment")
vim.env.VIRTUAL_ENV = root .. "/missing"
check(I.python() == dap.ABORT, "invalid active environment aborts")
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = old_venv, old_conda

local original_cwd = vim.fn.getcwd()
vim.cmd.cd(root)
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
local project_python = executable(".venv/bin/python")
check(I.python() == project_python, "project interpreter")
vim.env.CONDA_PREFIX = root .. "/venv"
check(I.python() == interpreter, "Conda interpreter")
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = old_venv, old_conda
vim.fn.writefile({ '[package]', 'name = "dap-regression"', 'version = "0.1.0"', 'edition = "2021"' }, root .. "/Cargo.toml")
vim.fn.mkdir(root .. "/src", "p")
vim.fn.writefile({ 'fn main() {}' }, root .. "/src/main.rs")
local cargo_done, cargo_paths
I.discover(true, function(p) cargo_paths, cargo_done = p, true end)
assert(vim.wait(5000, function() return cargo_done end))
check(vim.deep_equal(cargo_paths, { rust }), "real offline Cargo metadata")
local custom_project = root .. "/cargo-project"
local custom_binary = executable("cargo-project/build/debug/app")
executable("cargo-project/build/debug/build/helper")
executable("cargo-project/build/debug/deps/test")
vim.fn.writefile(vim.fn.readfile(root .. "/Cargo.toml"), custom_project .. "/Cargo.toml")
vim.fn.mkdir(custom_project .. "/src", "p")
vim.fn.writefile({ 'fn main() {}' }, custom_project .. "/src/main.rs")
local old_target_dir = vim.env.CARGO_TARGET_DIR
vim.env.CARGO_TARGET_DIR = "build"
vim.cmd.cd(custom_project)
cargo_done, cargo_paths = false, nil
I.discover(true, function(p) cargo_paths, cargo_done = p, true end)
assert(vim.wait(5000, function() return cargo_done end))
vim.env.CARGO_TARGET_DIR = old_target_dir
check(vim.deep_equal(cargo_paths, { custom_binary }), "Cargo target named build is searched; nested internals pruned")
vim.cmd.cd(original_cwd)

local function manual(value)
  local result
  vim.ui.input = function(_, cb) cb(value) end
  I.manual_path(function(p) result = p end)
  return result
end
check(manual(expected[1]) == expected[1], "manual executable")
check(manual(root) == dap.ABORT, "directory is not a program")
check(manual(nil) == dap.ABORT, "manual cancellation")
local old_executable = vim.fn.executable
vim.fn.executable = function(path) return path == "fzf" and 0 or old_executable(path) end
vim.ui.input = function(_, cb) cb(expected[1]) end
local fallback
I.select_executable(expected, root, function(p) fallback = p end)
check(fallback == expected[1], "missing fzf manual fallback")
vim.fn.executable = old_executable

-- Use real windows/files with a controlled job boundary to exercise races.
local old_jobstart, old_jobstop = vim.fn.jobstart, vim.fn.jobstop
for _, mode in ipairs({ "select", "cancel", "failure", "close", "start_failure" }) do
  local calls, result, exit, output, input = 0
  vim.fn.jobstop = function() return 1 end
  vim.fn.jobstart = function(command, opts)
    exit = opts.on_exit
    input, output = command:match(" < '([^']+)' > '([^']+)'")
    assert(input and output)
    if mode == "start_failure" then return -1 end
    vim.schedule(function()
      if mode == "select" then
        local fh = assert(io.open(output, "wb")); fh:write("1\tlabel\0"); fh:close()
        exit(42, 0)
      elseif mode == "close" then
        vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
      else exit(42, mode == "cancel" and 130 or 2) end
    end)
    return 42
  end
  I.select_executable(expected, root .. "/build", function(value) calls, result = calls + 1, value end)
  assert(vim.wait(1000, function() return calls > 0 end))
  exit(42, 130) -- late duplicate exit must do nothing
  vim.wait(20, function() return false end)
  check(calls == 1, mode .. " completes once")
  check(result == (mode == "select" and expected[1] or dap.ABORT), mode .. " result")
  check(vim.uv.fs_stat(input) == nil and vim.uv.fs_stat(output) == nil, mode .. " cleanup")
end
vim.fn.jobstart, vim.fn.jobstop, vim.ui.input = old_jobstart, old_jobstop, original_input
local old_open = io.open
io.open = function() return nil, "injected write failure" end
local failed
I.select_executable(expected, root, function(p) failed = p end)
check(failed == dap.ABORT, "file-open failure aborts")
io.open = old_open
-- Exercise the actual fzf process and NUL protocol without keyboard input.
local old_opts = vim.env.FZF_DEFAULT_OPTS
vim.env.FZF_DEFAULT_OPTS = "--filter=apps/solver"
local actual_result
I.select_executable(expected, root .. "/build", function(p) actual_result = p end)
assert(vim.wait(5000, function() return actual_result ~= nil end))
check(actual_result == root .. "/build/apps/solver", "real fzf selection")
vim.env.FZF_DEFAULT_OPTS = old_opts
vim.fn.delete(root, "rf")
print("DAP regression checks passed: " .. count)
