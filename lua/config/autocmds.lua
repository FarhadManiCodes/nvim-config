-- Shared editor behavior, filetype settings, and buffer safeguards.

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Relative number toggling
local number_toggle = augroup("NumberToggle", { clear = true })

autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  group = number_toggle,
  desc = "Enable relative numbers in normal mode",
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "" then
      return
    end

    local exclude_ft = { "help", "oil", "TelescopePrompt", "lazy", "mason" }
    if vim.tbl_contains(exclude_ft, vim.bo[event.buf].filetype) then
      return
    end

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

-- Cursor position restore
autocmd("BufReadPost", {
  group = augroup("CursorRestore", { clear = true }),
  desc = "Restore cursor position when opening file",
  callback = function(event)
    local exclude_ft = { "gitcommit", "gitrebase", "hgcommit" }
    local buf = event.buf

    if vim.tbl_contains(exclude_ft, vim.bo[buf].filetype) then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)

    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Highlight on yank
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

-- Filetype detection
local filetype_group = augroup("FiletypeDetection", { clear = true })

-- Add only gaps in native detection. BufRead overrides used to misclassify
-- aliases.json/my_aliases.md as sh, zsh files as sh, and .dvcignore as yaml.
-- Native detection handles shell files, Dockerfiles, TOML, Scala, dbt/DVC
-- YAML names, and .env variants (ft=env); leave those answers intact.
vim.filetype.add({
  extension = {
    dvc = "yaml",       -- DVC stage files
    -- Neovim knows .jinja but not these. Templated SQL stays `jinja` rather
    -- than being forced to `sql`, so the {{ }} delimiters are highlighted as
    -- what they actually are.
    j2 = "jinja",
    jinja2 = "jinja",
  },
  filename = {
    ["poetry.lock"] = "toml",
    ["MLproject"] = "yaml",
    [".dvcignore"] = "gitignore",
    ["aliases"] = "sh",  -- bare `aliases`, e.g. dotfiles/zsh/aliases
  },
})

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

-- Terminal settings
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

-- Auto-create directories
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

    if vim.fn.isdirectory(dir) == 0 then
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

-- Trim trailing whitespace
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

    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    -- Remove trailing whitespace (keeppatterns = don't pollute search history)
    vim.cmd([[keeppatterns %s/\s\+$//e]])

    pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
  end,
})

-- File-type specific indentation
local indent_group = augroup("FileTypeIndent", { clear = true })

-- Add filetypes to the matching style. With expandtab off, softtabstop = 0
-- avoids mixing tabs and spaces (important for gofmt and Makefiles).
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

-- Large file handling
autocmd("BufReadPre", {
  group = augroup("LargeFileHandling", { clear = true }),
  desc = "Disable expensive features for large files",
  callback = function(event)
    local ok, stats = pcall(vim.uv.fs_stat, event.match)

    if ok and stats and stats.size > 10485760 then  -- 10MB
      vim.b[event.buf].large_file = true

      vim.opt_local.swapfile = false
      vim.opt_local.undofile = false
      vim.opt_local.undolevels = -1
      vim.opt_local.spell = false
      vim.opt_local.foldmethod = "manual"  -- Disable Treesitter folding
      vim.opt_local.list = false           -- Hide whitespace characters

      -- Syntax is NOT disabled here: filetype detection runs after BufReadPre
      -- and would immediately overwrite buffer-local 'syntax'. It is handled by
      -- the FileType autocmd below, which fires last.

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

-- Disable regex syntax per buffer after filetype detection. "syntax off" is
-- global and would also remove highlighting from unrelated buffers.
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

-- Spell checking
local spell_group = augroup("SpellChecking", { clear = true })

-- Treesitter @nospell captures exclude code and math with noplainbuffer.
-- Bare Markdown URLs may still be flagged; links and <URLs> are excluded.
-- Skip >200 KB: generated paper extractions contain PDF noise and misparsed
-- math, making spelling noisy and expensive.
autocmd("FileType", {
  group = spell_group,
  pattern = { "tex", "markdown", "typst" },
  desc = "Enable spell checking for prose filetypes (skips generated/huge files)",
  callback = function(args)
    local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
    if ok and stats and stats.size > 200 * 1024 then
      return
    end
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"

    -- Use one tracked dictionary for runtime loading and zg. A second data-dir
    -- dictionary with the same name was shadowed by the config runtimepath.
    local spelldir = vim.fn.stdpath("config") .. "/spell"
    vim.fn.mkdir(spelldir, "p")
    local add = spelldir .. "/en.utf-8.add"
    vim.opt_local.spellfile = add

    -- Compile missing/stale dictionaries on fresh installs and after edits.
    -- Only zg recompiles automatically; the generated .spl is gitignored.
    local a = vim.uv.fs_stat(add)
    local c = vim.uv.fs_stat(add .. ".spl")
    if a and (not c or c.mtime.sec < a.mtime.sec) then
      pcall(function() vim.cmd("silent mkspell! " .. vim.fn.fnameescape(add)) end)
    end
  end,
})

-- C++ new file templates
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
-- Treesitter parser auto-sync
-- Sync after plugin updates (other plugins can supply queries) and Neovim
-- upgrades (bundled parsers can change). The plugin's build hook only covers
-- updates to nvim-treesitter itself; cache the Neovim version across sessions.

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

-- Markdown commands, buffer-local mappings, and preview lifecycle
require("config.markdown").setup()

-- Secret files: disable undo/swap persistence
-- Persistent undo stores secret text, even when its permissions match the
-- source: data-directory copies can enter backups or sync unexpectedly.
-- Disable undo persistence before reading, so existing undo files are not
-- loaded either. In-session undo still works; swap is also disabled.
-- The secret_file flag tells LSP to keep servers off these buffers.
-- Registers can still reach ShaDa (a global option), so avoid yanking/deleting
-- secrets into persisted registers.
local secret_group = augroup("SecretFiles", { clear = true })

autocmd({ "BufNewFile", "BufReadPre" }, {
  group = secret_group,
  -- Covers ~/.config/secrets/*.env, a bare project .env, and plain files named
  -- `secrets` (e.g. ~/.config/papis/secrets). Verified against all three shapes.
  pattern = { "*.env", "*.env.*", "*/secrets", "*/secrets/*" },
  desc = "Secret file: no undo/swap persistence, no LSP",
  callback = function(event)
    vim.b[event.buf].secret_file = true
    vim.bo[event.buf].undofile = false
    vim.bo[event.buf].swapfile = false
  end,
})

-- An --embed server whose UI is gone would wait forever at the exit prompt, ignoring SIGTERM.
autocmd("VimLeave", {
  group = augroup("OrphanExit", { clear = true }),
  desc = "Exit at once when no UI is left to answer a prompt",
  callback = function()
    if #vim.api.nvim_list_uis() == 0 and vim.tbl_contains(vim.v.argv, "--embed") then
      os.exit(vim.v.exiting)
    end
  end,
})
