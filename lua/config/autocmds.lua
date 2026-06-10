-- ~/.config/nvim/lua/config/autocmds.lua
-- Autocmd configuration - Optimized for Data Engineering + HPC/CFD
-- December 2025

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- =============================================================================
-- SECTION 1: RELATIVE NUMBER TOGGLING
-- =============================================================================
-- Smart relative numbers: ON in normal mode, OFF in insert mode and special buffers
local number_toggle = augroup("NumberToggle", { clear = true })

autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  group = number_toggle,
  desc = "Enable relative numbers in normal mode",
  callback = function(event)
    -- Don't enable for special buffers (terminal, quickfix, etc.)
    if vim.bo[event.buf].buftype ~= "" then
      return
    end

    -- Don't enable for certain filetypes
    local exclude_ft = { "help", "oil", "TelescopePrompt", "lazy", "mason" }
    if vim.tbl_contains(exclude_ft, vim.bo[event.buf].filetype) then
      return
    end

    -- Enable relative numbers
    if vim.wo.number then
      vim.wo.relativenumber = true
    end
  end,
})

autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  group = number_toggle,
  desc = "Disable relative numbers in insert mode",
  callback = function(event)
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end,
})

-- =============================================================================
-- SECTION 2: CURSOR POSITION RESTORE
-- =============================================================================
-- Restore cursor to last position when opening file (except git commits)
autocmd("BufReadPost", {
  group = augroup("CursorRestore", { clear = true }),
  desc = "Restore cursor position when opening file",
  callback = function(event)
    -- Exclude certain filetypes where cursor should start at top
    local exclude_ft = { "gitcommit", "gitrebase", "hgcommit" }
    local buf = event.buf

    -- Don't restore for excluded filetypes
    if vim.tbl_contains(exclude_ft, vim.bo[buf].filetype) then
      return
    end

    -- Get last cursor position
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)

    -- Restore if position is valid
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- =============================================================================
-- SECTION 3: HIGHLIGHT ON YANK
-- =============================================================================
-- Brief highlight when yanking text (visual feedback)
autocmd("TextYankPost", {
  group = augroup("YankHighlight", { clear = true }),
  desc = "Highlight text on yank",
  callback = function()
    vim.highlight.on_yank({
      higroup = "IncSearch",
      timeout = 200,
    })
  end,
})

-- =============================================================================
-- SECTION 4: FILETYPE DETECTION
-- =============================================================================
local filetype_group = augroup("FiletypeDetection", { clear = true })

-- Shell files (comprehensive pattern matching)
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = {
    "*.sh", "*.bash", "*.zsh", "*.ksh",
    "*alias*", "*aliases",
    ".bashrc", ".zshrc", ".bash_profile", ".zprofile", ".bash_aliases",
    "bashrc", "zshrc", "bash_profile", "zprofile",
  },
  callback = function()
    vim.bo.filetype = "sh"
  end,
})

-- Environment files
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = { "*.env", "*.env.*" },
  callback = function()
    vim.bo.filetype = "sh"
  end,
})

-- Docker
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = "Dockerfile*",
  callback = function()
    vim.bo.filetype = "dockerfile"
  end,
})

-- TOML (Python tools)
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = { "*.toml", "Pipfile", "poetry.lock" },
  callback = function()
    vim.bo.filetype = "toml"
  end,
})

-- MLflow/DVC (Data Engineering)
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = {
    "MLproject",
    "dvc.yaml", "*.dvc",
    ".dvcignore",
    "params.yaml", "metrics.yaml",
  },
  callback = function()
    vim.bo.filetype = "yaml"
  end,
})

-- dbt (Data Build Tool) - SQL with Jinja templates
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = { "*.sql.jinja", "*.sql.jinja2", "*.sql.j2" },
  callback = function()
    vim.bo.filetype = "sql"  -- SQL highlighting, ignore Jinja for now
  end,
})

-- dbt YAML configs
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = {
    "dbt_project.yml",
    "profiles.yml",
    "schema.yml", "sources.yml", "models.yml",
  },
  callback = function()
    vim.bo.filetype = "yaml"
  end,
})

-- Scala (Spark)
autocmd({ "BufNewFile", "BufRead" }, {
  group = filetype_group,
  pattern = { "*.scala", "*.sc" },
  callback = function()
    vim.bo.filetype = "scala"
  end,
})

-- Binary file prevention (prevent accidental opening of binary data files)
autocmd({ "BufReadPre" }, {
  group = filetype_group,
  pattern = {
    -- Data Engineering formats
    "*.parquet",
    "*.pkl", "*.pickle",
    "*.h5", "*.hdf5",
    "*.feather",
    "*.arrow",
    "*.duckdb",
    "*.db", "*.sqlite",
    "*.snappy",
    -- Machine Learning formats
    "*.npy", "*.npz",
    "*.pt", "*.pth",
    -- HPC/CFD formats
    "*.stl",
  },
  callback = function(event)
    vim.notify(
      string.format(
        "Binary file detected: %s\nUse appropriate viewer (ParaView, MeshLab, pandas, etc.)",
        vim.fn.fnamemodify(event.match, ":t")
      ),
      vim.log.levels.WARN
    )
    vim.schedule(function()
      vim.cmd("bdelete")
    end)
  end,
})

-- =============================================================================
-- SECTION 5: TERMINAL SETTINGS
-- =============================================================================
-- Clean terminal appearance (no line numbers, sign column)
autocmd("TermOpen", {
  group = augroup("TerminalSettings", { clear = true }),
  desc = "Terminal settings",
  callback = function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.spell = false
    vim.cmd("startinsert")
  end,
})

-- =============================================================================
-- SECTION 6: AUTO-CREATE DIRECTORIES
-- =============================================================================
-- Auto-create parent directories when saving (with confirmation to catch typos)
autocmd("BufWritePre", {
  group = augroup("AutoCreateDirs", { clear = true }),
  desc = "Auto-create parent directories when saving (with confirmation)",
  callback = function(event)
    -- Skip special buffers (URLs, etc.)
    if event.match:match("^%w+://") then
      return
    end

    local file = vim.uv.fs_realpath(event.match) or event.match
    local dir = vim.fn.fnamemodify(file, ":p:h")

    -- Check if directory exists
    if vim.fn.isdirectory(dir) == 0 then
      -- Ask for confirmation (catches typos!)
      local choice = vim.fn.confirm(
        string.format("Create directory '%s'?", dir),
        "&Yes\n&No",
        1  -- Default to Yes (just press Enter)
      )

      if choice == 1 then
        vim.fn.mkdir(dir, "p")
      end
    end
  end,
})

-- =============================================================================
-- SECTION 7: TRIM TRAILING WHITESPACE
-- =============================================================================
-- Remove trailing whitespace on save (with exclusions for formats that need it)
autocmd("BufWritePre", {
  group = augroup("TrimWhitespace", { clear = true }),
  desc = "Remove trailing whitespace on save (with exclusions)",
  callback = function(event)
    -- Skip non-modifiable or special buffers (e.g. checkhealth, help, terminal)
    if not vim.bo[event.buf].modifiable or vim.bo[event.buf].buftype ~= "" then
      return
    end

    -- Don't trim for certain filetypes where trailing spaces matter
    local exclude_ft = { "markdown", "text", "diff", "gitcommit", "tex" }
    if vim.tbl_contains(exclude_ft, vim.bo[event.buf].filetype) then
      return
    end

    -- Save cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    -- Remove trailing whitespace (keeppatterns = don't pollute search history)
    vim.cmd([[keeppatterns %s/\s\+$//e]])

    -- Restore cursor position
    pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
  end,
})

-- =============================================================================
-- SECTION 8: FILE-TYPE SPECIFIC INDENTATION
-- =============================================================================
-- Set proper indentation for different languages and file types
local indent_group = augroup("FileTypeIndent", { clear = true })

-- 2 spaces indentation
autocmd("FileType", {
  group = indent_group,
  pattern = {
    -- Config languages
    "lua", "yaml", "json", "toml",
    -- Web languages
    "html", "css", "scss", "javascript", "typescript",
    "javascriptreact", "typescriptreact",
    -- System languages
    "sh", "bash", "zsh",
    -- Data/Query languages
    "sql",
    -- Container/Infrastructure
    "dockerfile",
    -- JVM languages
    "scala",
    -- Systems programming
    "c", "cpp", "h", "hpp",
  },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
  end,
})

-- 4 spaces indentation
autocmd("FileType", {
  group = indent_group,
  pattern = {
    "python",  -- PEP 8 standard
    "rust",    -- rustfmt standard
  },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
  end,
})

-- Tabs (required by format or convention)
autocmd("FileType", {
  group = indent_group,
  pattern = {
    "go",       -- gofmt standard
    "make",     -- Makefile requires tabs
  },
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 0
  end,
})

-- =============================================================================
-- SECTION 9: LARGE FILE HANDLING
-- =============================================================================
-- Disable expensive features for large files (>10MB) to prevent freezing
autocmd("BufReadPre", {
  group = augroup("LargeFileHandling", { clear = true }),
  desc = "Disable expensive features for large files",
  callback = function(event)
    local ok, stats = pcall(vim.uv.fs_stat, event.match)

    if ok and stats and stats.size > 10485760 then  -- 10MB
      -- Mark as large file
      vim.b[event.buf].large_file = true

      -- Disable expensive features
      vim.opt_local.swapfile = false
      vim.opt_local.undofile = false
      vim.opt_local.undolevels = -1
      vim.opt_local.spell = false
      vim.opt_local.foldmethod = "manual"  -- Disable Treesitter folding
      vim.opt_local.list = false           -- Hide whitespace characters

      -- Disable syntax highlighting
      vim.cmd("syntax off")

      -- Notify user
      vim.notify(
        string.format(
          "Large file detected (%s > 10MB). Disabled heavy features for performance.",
          vim.fn.fnamemodify(event.match, ":t")
        ),
        vim.log.levels.WARN
      )

      -- Note: LSP and Treesitter will be disabled by their respective configs
      -- checking for vim.b.large_file flag
    end
  end,
})

-- =============================================================================
-- SECTION 10: SPELL CHECKING
-- =============================================================================
-- Enable spell checking for documentation files
local spell_group = augroup("SpellChecking", { clear = true })

autocmd("FileType", {
  group = spell_group,
  pattern = "tex",
  desc = "Enable spell checking for LaTeX files",
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
  end,
})

-- =============================================================================
-- SECTION 11: C++ NEW FILE TEMPLATES
-- =============================================================================
autocmd("BufNewFile", {
  group = augroup("CppNewFile", { clear = true }),
  pattern = { "*.hpp", "*.h" },
  desc = "Insert #pragma once in new header files",
  callback = function()
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "#pragma once", "" })
  end,
})

-- =============================================================================
-- SECTION 12: C++ SYMBOL SANITIZATION
-- =============================================================================
-- Automatically replace weird PDF symbols with valid C++ operators
local cpp_sanitize = augroup("CppSanitize", { clear = true })

autocmd("BufWritePre", {
  group = cpp_sanitize,
  pattern = { "*.cpp", "*.h", "*.hpp", "*.cc" },
  desc = "Replace ≪ with << on save",
  callback = function()
    local save_cursor = vim.fn.getpos(".")

    pcall(vim.cmd, [[%s/≪/<</ge]])    -- U+226A → << (PDF math symbol)
    pcall(vim.cmd, [[%s/≫/>>/ge]])    -- U+226B → >> (PDF math symbol, template closing)
    pcall(vim.cmd, [[%s/[""]/"/ge]])  -- smart quotes → straight quotes

    vim.fn.setpos(".", save_cursor)
  end,
})
-- =============================================================================
-- SECTION 13: TREESITTER PARSER AUTO-SYNC
-- =============================================================================
-- Two triggers that keep parsers in sync with nvim-treesitter's query files:
--
--   a) After :Lazy update / :Lazy sync
--      nvim-treesitter's build = ":TSUpdate" already handles the case where
--      nvim-treesitter itself is updated, but a full LazySync may also pull
--      new queries via other treesitter plugins. This catches that edge case.
--
--   b) After Neovim is upgraded
--      Neovim bundles a set of parsers (lua, c, markdown…). When Neovim
--      upgrades, those bundled parsers change version and can become
--      incompatible with nvim-treesitter's query files until :TSUpdate runs.
--      We detect this by caching the Neovim version between sessions.

local ts_sync = augroup("TreesitterSync", { clear = true })

-- (a) Re-run :TSUpdate after any plugin update or sync
autocmd("User", {
  group = ts_sync,
  pattern = { "LazyUpdate", "LazySync" },
  callback = function()
    vim.schedule(function()
      vim.cmd("TSUpdate")
    end)
  end,
})

-- (b) Re-run :TSUpdate when the Neovim version changes between sessions
local _nvim_ver_cache = vim.fn.stdpath("data") .. "/nvim_ts_nvim_version.txt"
local _v = vim.version()
local _current_ver = _v.major .. "." .. _v.minor .. "." .. _v.patch

autocmd("VimEnter", {
  group = ts_sync,
  once = true,
  callback = function()
    local cached = ""
    local rf = io.open(_nvim_ver_cache, "r")
    if rf then cached = rf:read("*l") or ""; rf:close() end

    if cached ~= _current_ver then
      local wf = io.open(_nvim_ver_cache, "w")
      if wf then wf:write(_current_ver); wf:close() end

      vim.schedule(function()
        vim.notify(
          "Neovim upgraded to " .. _current_ver .. " → running :TSUpdate",
          vim.log.levels.INFO
        )
        vim.cmd("TSUpdate")
      end)
    end
  end,
})

-- =============================================================================
-- SECTION 14: MARKDOWN PREVIEW REFRESH
-- =============================================================================
autocmd("BufWritePost", {
  group = augroup("MdPreviewRefresh", { clear = true }),
  pattern = "*.md",
  desc = "Refresh vimb markdown preview on save",
  callback = function()
    local file = vim.api.nvim_buf_get_name(0)
    if file ~= "" then
      require("config.md_preview").refresh(file)
    end
  end,
})

autocmd("VimLeavePre", {
  group = augroup("MdPreviewCleanup", { clear = true }),
  desc = "Close markdown preview server and vimb on nvim exit",
  callback = function()
    require("config.md_preview").close()
  end,
})

-- =============================================================================
-- END OF AUTOCMDS (14 sections)
-- =============================================================================

-- Note: Treesitter already checks for vim.b.large_file to disable for large files
-- Note: Use :checkhealth to diagnose configuration issues
