-- Native GDB fields are adapter-specific; see docs/dap-config.md.
local dap = require("dap")
local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = "DAP" })
end

local function run(argv, opts, callback)
  local ok, err = pcall(vim.system, argv, opts, function(result)
    vim.schedule(function() callback(result) end)
  end)
  if not ok then
    vim.schedule(function() callback({ code = -1, stderr = tostring(err) }) end)
  end
end

local function find_executables(root, rust, callback)
  if vim.fn.isdirectory(root) == 0 then callback(nil, "No build directory: " .. root); return end
  -- Evaluate pruning only below the root: Cargo may name its target dir build.
  local argv = { "find", root, "-mindepth", "1", "-type", "d", "(", "-name", "CMakeFiles" }
  if rust then
    vim.list_extend(argv, { "-o", "-name", "build", "-o", "-name", "deps", "-o", "-name", "incremental", "-o", "-name", ".fingerprint" })
  end
  vim.list_extend(argv, { ")", "-prune", "-o", "-type", "f", "-executable",
    "!", "-name", "*.so", "!", "-name", "*.so.*", "!", "-name", "*.a", "-print0" })
  run(argv, {}, function(result)
    if result.code ~= 0 then
      callback(nil, "Executable discovery failed: " .. (result.stderr or "find failed")); return
    end
    local paths = vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })
    table.sort(paths)
    callback(#paths > 0 and paths or nil, #paths == 0 and ("No executables found in " .. root) or nil)
  end)
end

local function discover(rust, callback)
  local cwd = vim.fn.getcwd()
  if not rust then
    find_executables(cwd .. "/build", false, function(paths, err) callback(paths, err, cwd .. "/build") end)
    return
  end
  run({ "cargo", "metadata", "--no-deps", "--format-version", "1", "--offline" }, { cwd = cwd }, function(result)
    local ok, metadata = pcall(vim.json.decode, result.stdout or "")
    if result.code ~= 0 or not ok or type(metadata) ~= "table" or type(metadata.target_directory) ~= "string" then
      callback(nil, "Cannot resolve Cargo target directory; select an executable manually", cwd); return
    end
    local root = metadata.target_directory
    find_executables(root, true, function(paths, err) callback(paths, err, root) end)
  end)
end

local function manual_path(done)
  vim.ui.input({ prompt = "Executable path: ", default = vim.fn.getcwd() .. "/", completion = "file" }, function(value)
    if value == nil or value == "" then done(dap.ABORT); return end
    local path = vim.fn.fnamemodify(vim.fn.expand(value), ":p")
    if vim.fn.isdirectory(path) == 1 or vim.fn.executable(path) ~= 1 then
      warn("Not an executable file: " .. path); done(dap.ABORT); return
    end
    done(path)
  end)
end

local function select_executable(paths, root, done)
  if vim.fn.executable("fzf") ~= 1 then
    warn("fzf is unavailable; enter an executable path"); manual_path(done); return
  end
  local input, output = vim.fn.tempname(), vim.fn.tempname()
  local buf, win, job, close_event
  local finished = false
  local function finish(value, err)
    if finished then return end
    finished = true
    if close_event then pcall(vim.api.nvim_del_autocmd, close_event) end
    if job and job > 0 then pcall(vim.fn.jobstop, job) end
    if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
    if buf and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    os.remove(input)
    os.remove(output)
    if err then warn(err) end
    if value == "manual" then manual_path(done) else done(value or dap.ABORT) end
  end
  local ok, err = pcall(function()
    -- IDs separate escaped display labels from original filenames.
    local rows = { "0\t[Enter executable path manually]" }
    for i, path in ipairs(paths) do
      local label = path:sub(1, #root + 1) == root .. "/" and path:sub(#root + 2) or path
      rows[#rows + 1] = i .. "\t" .. vim.fn.strtrans(label)
    end
    local fh = assert(io.open(input, "wb"))
    local written, write_err = fh:write(table.concat(rows, "\0") .. "\0")
    local closed, close_err = fh:close()
    assert(written, write_err)
    assert(closed, close_err)
    buf = vim.api.nvim_create_buf(false, true)
    local width = math.max(1, math.min(80, vim.o.columns - 4))
    local height = math.max(1, math.min(#rows + 2, 15, vim.o.lines - 4))
    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = width, height = height,
      col = math.max(0, math.floor((vim.o.columns - width) / 2)),
      row = math.max(0, math.floor((vim.o.lines - height) / 2)),
      style = "minimal", border = "rounded", title = " DAP: Select Executable ", title_pos = "center",
    })
    close_event = vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(win), once = true,
      callback = function() vim.schedule(function() finish() end) end,
    })
    -- Redirects require a shell; only escaped temporary paths enter it.
    job = vim.fn.jobstart("fzf --read0 --print0 --delimiter='\t' --with-nth=2.. --reverse --prompt='> '"
      .. " < " .. vim.fn.shellescape(input) .. " > " .. vim.fn.shellescape(output), {
      term = true,
      on_exit = function(_, code)
        vim.schedule(function()
          if finished then return end
          if code ~= 0 then
            finish(nil, code ~= 1 and code ~= 130 and ("fzf exited with status " .. code) or nil); return
          end
          local rf = io.open(output, "rb")
          if not rf then finish(nil, "Cannot read fzf selection"); return end
          local selected = rf:read("*a")
          rf:close()
          local id = selected and tonumber(selected:match("^(%d+)\t"))
          if id == 0 then finish("manual")
          elseif id and paths[id] then finish(paths[id])
          else finish(nil, "Invalid fzf selection") end
        end)
      end,
    })
    assert(job > 0, "Cannot start fzf terminal")
    vim.cmd("startinsert")
  end)
  if not ok then finish(nil, tostring(err)) end
end

local function pick_executable(rust)
  return function()
    return coroutine.create(function(co)
      local resumed = false
      local function done(value)
        if resumed then return end
        resumed = true
        coroutine.resume(co, value)
      end
      discover(rust, function(paths, err, root)
        if not paths then warn(err); manual_path(done)
        else select_executable(paths, root, done) end
      end)
    end)
  end
end

local function arguments()
  return coroutine.create(function(co)
    vim.ui.input({ prompt = "Program arguments: " }, function(value)
      coroutine.resume(co, value == nil and dap.ABORT or require("dap.utils").splitstr(value))
    end)
  end)
end

local function sanitizer_env()
  return vim.tbl_extend("force", vim.fn.environ(), {
    ASAN_OPTIONS = "abort_on_error=1:detect_leaks=0:halt_on_error=1",
    UBSAN_OPTIONS = "print_stacktrace=1:halt_on_error=1:abort_on_error=1",
  })
end

local function python()
  for _, variable in ipairs({ "VIRTUAL_ENV", "CONDA_PREFIX" }) do
    local env = vim.env[variable]
    if env and env ~= "" then
      local path = env .. "/bin/python"
      if vim.fn.executable(path) == 1 then return path end
      warn("Invalid " .. variable .. " interpreter: " .. path); return dap.ABORT
    end
  end
  local root = vim.fs.root(vim.fn.getcwd(), { ".venv", "pyproject.toml", ".git" }) or vim.fn.getcwd()
  local path = root .. "/.venv/bin/python"
  if vim.fn.executable(path) == 1 then return path end
  path = vim.fn.exepath("python3")
  if path ~= "" then return path end
  warn("No Python interpreter found")
  return dap.ABORT
end

dap.configurations.cpp = {
  {
    name = "Launch C++ (GDB)", type = "gdb", request = "launch",
    program = pick_executable(false), args = arguments, cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = false,
  },
  {
    name = "Launch C++ with ASAN/UBSAN (GDB)", type = "gdb", request = "launch",
    program = pick_executable(false), args = arguments, cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = true, env = sanitizer_env,
  },
}
dap.configurations.c = dap.configurations.cpp
dap.configurations.rust = {
  {
    name = "Launch Rust (GDB)", type = "gdb", request = "launch",
    program = pick_executable(true), args = arguments, cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = false,
  },
}
dap.configurations.python = dap.configurations.python or {}
table.insert(dap.configurations.python, {
  name = "Debug Python → C++ Extension (GDB)", type = "gdb", request = "launch",
  program = python, args = { "${file}" }, cwd = "${workspaceFolder}",
  stopAtBeginningOfMainSubprogram = false,
  -- Inherit project PYTHONPATH and library paths unchanged.
})

-- Repository-owned regression tests; not a public configuration API.
return { _internal = {
  find_executables = find_executables, discover = discover, select_executable = select_executable,
  manual_path = manual_path, arguments = arguments, python = python, sanitizer_env = sanitizer_env,
} }
