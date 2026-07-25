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
    vim.hl.on_yank({
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

-- Indentation rules, one entry per style. Adding a language is a one-word edit
-- to the relevant `filetypes` list rather than another copy of the same
-- four-option callback.
--   softtabstop = 0 for tabs: with expandtab off, a non-zero softtabstop makes
--   <Tab> insert a mix of tabs and spaces, which gofmt and make both reject.
local indent_styles = {
  {
    width = 2,
    expandtab = true,
    filetypes = {
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
      -- Systems programming (.h/.hpp resolve to c/cpp, no separate ft exists)
      "c", "cpp",
    },
  },
  {
    width = 4,
    expandtab = true,
    filetypes = {
      "python",  -- PEP 8 standard
      "rust",    -- rustfmt standard
    },
  },
  {
    width = 4,
    expandtab = false,  -- tabs required by format or convention
    filetypes = {
      "go",       -- gofmt standard
      "make",     -- Makefile requires tabs
    },
  },
}

for _, style in ipairs(indent_styles) do
  autocmd("FileType", {
    group = indent_group,
    pattern = style.filetypes,
    desc = string.format(
      "Indent: %d %s", style.width, style.expandtab and "spaces" or "wide tabs"
    ),
    callback = function()
      vim.bo.expandtab = style.expandtab
      vim.bo.tabstop = style.width
      vim.bo.shiftwidth = style.width
      vim.bo.softtabstop = style.expandtab and style.width or 0
    end,
  })
end

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

      -- Syntax is NOT disabled here: filetype detection runs after BufReadPre
      -- and would immediately overwrite buffer-local 'syntax'. It is handled by
      -- the FileType autocmd below, which fires last.

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

-- Turn off regex syntax highlighting for flagged large buffers.
-- Deliberately buffer-local and deliberately on FileType (the last event in the
-- read sequence, so nothing overwrites it afterwards). The obvious-looking
-- `vim.cmd("syntax off")` is wrong twice over: it is a GLOBAL command, so one
-- 10MB file strips regex highlighting from every other buffer in the session
-- (rainbow_csv, and any filetype without a treesitter parser) with no way to
-- notice; and placed in BufReadPre it gets clobbered by filetype detection.
autocmd("FileType", {
  group = augroup("LargeFileSyntax", { clear = true }),
  desc = "Disable syntax highlighting for large buffers (buffer-local)",
  callback = function(event)
    if not vim.b[event.buf].large_file then
      return
    end
    -- Scheduled, not set inline: syntax loading installs its own `FileType *`
    -- handler (`set syntax=<ft>`) that runs after this one and would overwrite
    -- an inline assignment. Deferring puts the write after that chain.
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.bo[event.buf].syntax = "off"
      end
    end)
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

-- Note: C++ symbol sanitization (≪→<<, smart quotes) now runs inside the
-- format-on-save autocmd in lsp.lua, so it executes BEFORE clangd formats.
-- =============================================================================
-- SECTION 12: TREESITTER PARSER AUTO-SYNC
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
local _nvim_ver_cache = "nvim_ts_nvim_version.txt"
local _v = vim.version()
local _current_ver = _v.major .. "." .. _v.minor .. "." .. _v.patch

autocmd("VimEnter", {
  group = ts_sync,
  once = true,
  callback = function()
    local state = require("config.state")

    if state.read(_nvim_ver_cache) ~= _current_ver then
      state.write(_nvim_ver_cache, _current_ver)

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
-- SECTION 13: MATH BLOCK COLLAPSE
-- =============================================================================
-- render-markdown.nvim's latex handler only conceals the raw $$...$$ source
-- when the equation's treesitter node spans a single buffer line
-- (lua/render-markdown/handler/latex.lua: position="center" -- the only mode
-- that actually calls the conceal function -- gets silently overridden to
-- "above" whenever node:height() > 1, and "above" never conceals at all).
-- A $$ / content / $$ block written across 3 lines therefore always shows
-- both the raw source and the render side by side; collapsing it onto one
-- line ($$ content $$) is the only way to get concealment for that equation.
--
-- Delegates to mathunicode-collapse-blocks (~/projects/mathunicode) rather
-- than reimplementing the block-finding regex here -- same "one shared
-- backend" reasoning as pointing the latex converter at mathunicode itself:
-- the batch-fix script over the whole papis library uses the identical
-- Python implementation, so there's exactly one place this logic lives.
local function collapse_math_blocks()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local input = table.concat(lines, "\n")
  local result = vim.system({ "mathunicode-collapse-blocks" }, { stdin = input, text = true }):wait()

  if result.code ~= 0 or not result.stdout then
    vim.notify(
      "mathunicode-collapse-blocks failed: " .. (result.stderr or "unknown error"),
      vim.log.levels.ERROR
    )
    return
  end

  local output = result.stdout:gsub("\n$", "")
  if output == input then
    vim.notify("No multi-line math blocks found", vim.log.levels.INFO)
    return
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, "\n", { plain = true }))
  vim.notify("Collapsed multi-line math block(s) to single-line form", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command(
  "MathCollapse",
  collapse_math_blocks,
  { desc = "Collapse $$/content/$$ math blocks to single-line $$ content $$ form" }
)

-- =============================================================================
-- SECTION 14: MARKDOWN PREVIEW + KEYMAPS
-- =============================================================================

-- Build a Table of Contents in the location list from markdown headings.
-- Scans the live buffer (works on unsaved changes). Handles, mirroring
-- vim-markdown's s:GetHeaderList:
--   * ATX headings (# .. ######), with trailing hashes stripped (## X ## -> X)
--   * Setext headings (a text line underlined with === for H1, --- for H2)
--   * Fenced code blocks (``` / ~~~): headings inside them are ignored
--   * YAML frontmatter (--- ... --- at the very top): skipped, so its closing
--     --- is not mistaken for a setext H2 underline
local function markdown_toc()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local items = {}
  local in_fence = false
  local in_frontmatter = false
  local prev_title, prev_lnum  -- the previous line, when it could be a setext title

  for i, line in ipairs(lines) do
    if i == 1 and line == "---" then
      -- Opening frontmatter delimiter on the first line.
      in_frontmatter = true
      prev_title = nil
    elseif in_frontmatter then
      if line == "---" then in_frontmatter = false end
      prev_title = nil
    elseif line:match("^%s*```") or line:match("^%s*~~~") then
      in_fence = not in_fence
      prev_title = nil
    elseif in_fence then
      prev_title = nil
    else
      local hashes, text = line:match("^(#+)%s+(.*)")
      if hashes and #hashes <= 6 then
        text = text:gsub("%s*#*%s*$", "")  -- strip optional closing hashes
        table.insert(items, {
          bufnr = bufnr, lnum = i, col = 1,
          text = string.rep("  ", #hashes - 1) .. text,
        })
        prev_title = nil
      elseif prev_title and line:match("^=+%s*$") then
        table.insert(items, { bufnr = bufnr, lnum = prev_lnum, col = 1, text = prev_title })
        prev_title = nil
      elseif prev_title and line:match("^%-+%s*$") then
        table.insert(items, { bufnr = bufnr, lnum = prev_lnum, col = 1, text = "  " .. prev_title })
        prev_title = nil
      elseif line:match("^%S") then
        -- A non-blank, non-special line: a candidate setext title for the next line.
        prev_title, prev_lnum = line, i
      else
        prev_title = nil
      end
    end
  end

  if vim.tbl_isempty(items) then
    vim.notify("No markdown headings found", vim.log.levels.INFO)
    return
  end
  vim.fn.setloclist(0, {}, " ", { title = "Markdown TOC", items = items })
  vim.cmd("lopen")
end

-- Buffer-local markdown keymaps under the <leader>l prefix. These mirror the
-- vimtex LaTeX maps; both are buffer-local to their own filetype, so reusing
-- <leader>ll / <leader>lt / <leader>lm causes no conflict.
autocmd("FileType", {
  group = augroup("MarkdownKeymaps", { clear = true }),
  pattern = "markdown",
  desc = "Buffer-local markdown keymaps (preview + TOC + math collapse)",
  callback = function(event)
    local bufnr = event.buf

    vim.keymap.set("n", "<leader>ll", function()
      local file = vim.api.nvim_buf_get_name(bufnr)
      if file == "" then
        vim.notify("Buffer has no file name", vim.log.levels.WARN)
        return
      end
      require("config.md_preview").preview(file)
    end, { buffer = bufnr, desc = "Preview markdown in vimb" })

    vim.keymap.set("n", "<leader>lt", markdown_toc, { buffer = bufnr, desc = "TOC (headings)" })

    vim.keymap.set(
      "n",
      "<leader>lm",
      collapse_math_blocks,
      { buffer = bufnr, desc = "Collapse $$/content/$$ math blocks to single-line form" }
    )

    -- Relabel the <leader>l group as "Markdown" in this buffer (it's "LaTeX"
    -- globally). which-key may not be loaded yet, so guard the require.
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({ { "<leader>l", group = "Markdown", buffer = bufnr } })
    end
  end,
})

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
