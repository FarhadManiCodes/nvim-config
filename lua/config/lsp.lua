-- ~/.config/nvim/lua/config/lsp.lua
-- LSP Configuration for C++, Python, and Bash
-- Using Neovim 0.11+ native vim.lsp.config API (not deprecated lspconfig)
-- Optimized for Trilinos/deal.II C++ development

-- =============================================================================
-- DIAGNOSTIC CONFIGURATION (MINIMAL VISUAL NOISE)
-- =============================================================================

vim.diagnostic.config({
  virtual_text = false,        -- NO inline error text (reduces clutter)
  underline = true,            -- Red underlines on errors
  update_in_insert = false,    -- Wait for normal mode (less distracting)
  severity_sort = true,        -- Errors first, then warnings

  -- Diagnostic signs in gutter (modern Neovim 0.12+ way)
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN]  = "W",
      [vim.diagnostic.severity.HINT]  = "H",
      [vim.diagnostic.severity.INFO]  = "I",
    },
  },

  float = {
    border = "rounded",        -- Rounded border for diagnostic popups
    source = true,             -- Show source (clangd, basedpyright, etc.)
                               -- 'source' is typed boolean|"if_many" as of 0.11;
                               -- the old "always" only worked as a truthy string.
    header = "",               -- No header text
    prefix = "",               -- No prefix characters
  },
})


-- =============================================================================
-- REMOVE REDUNDANT NEOVIM 0.11+ DEFAULT LSP KEYMAPS
-- =============================================================================
-- Neovim ships global gr* maps (grr/gri/grt/gra/grn/grx). They duplicate our
-- explicit scheme (gr, gi, gt, <leader>ca, <leader>cr; codelens unused) and the
-- shared `gr` prefix makes plain `gr` wait for 'timeoutlen' before firing.
-- Deleting them clears the which-key overlap warning and removes the lag.
for _, lhs in ipairs({ "grr", "gri", "grt", "gra", "grn", "grx" }) do
  pcall(vim.keymap.del, "n", lhs)
end

-- =============================================================================
-- BUFFER-LOCAL LSP SETUP (LspAttach)
-- =============================================================================

-- Buffer-local setup for any attached server. Driven by the LspAttach event
-- rather than a per-server `on_attach = ...` key: the behaviour is identical
-- for every server, so wiring it once here keeps the six vim.lsp.config blocks
-- below purely declarative (server command + filetypes + settings, nothing else).
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspBufferSetup", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- CRITICAL: Don't run LSP on large files
    -- Respects existing large file handling from autocmds.lua.
    --
    -- buf_detach_client, NOT stop_client: the intent is "not on THIS buffer",
    -- but stop_client stops the whole server, so opening a single >10MB file
    -- killed LSP for every other buffer in the session — silently, since
    -- nothing errors, completion and gd simply stop working project-wide.
    -- (stop_client is also @deprecated in 0.12.) Detaching is scheduled because
    -- we are currently inside that client's own LspAttach dispatch.
    if vim.b[bufnr].large_file then
      vim.notify(
        string.format("LSP disabled for large file (buffer %d)", bufnr),
        vim.log.levels.WARN
      )
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.lsp.buf_detach_client(bufnr, client.id)
        end
      end)
      return
    end

    -- Local helper: every mapping here is buffer-local, silent and noremap,
    -- so that shape is expressed once instead of being rebuilt per keymap.
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, {
        noremap = true,
        silent = true,
        buffer = bufnr,
        desc = desc,
      })
    end

    -- Navigation
    map('n', 'gd', vim.lsp.buf.definition, "Go to definition")
    map('n', 'gD', vim.lsp.buf.declaration, "Go to declaration")
    map('n', 'gr', vim.lsp.buf.references, "Find references")
    map('n', 'gi', vim.lsp.buf.implementation, "Go to implementation")
    map('n', 'gt', vim.lsp.buf.type_definition, "Go to type definition")

    -- Documentation
    map('n', 'K', vim.lsp.buf.hover, "Hover documentation")
    map('i', '<C-k>', vim.lsp.buf.signature_help, "Signature help")

    -- Code actions
    map('n', '<leader>ca', vim.lsp.buf.code_action, "Code actions")
    map('n', '<leader>cr', vim.lsp.buf.rename, "Rename symbol")
    map('n', '<leader>cf', function()
      vim.lsp.buf.format({ async = true })
    end, "Format file")

    -- Header/source switching (clangd only)
    if client.name == 'clangd' then
      map('n', '<leader>ch', function()
        local params = { uri = vim.uri_from_bufnr(0) }
        vim.lsp.buf_request(0, 'textDocument/switchSourceHeader', params, function(err, result)
          if err or not result then
            vim.notify("No corresponding file found", vim.log.levels.WARN)
            return
          end
          vim.cmd('edit ' .. vim.uri_to_fname(result))
        end)
      end, "Switch header/source")
    end

    -- Inlay hints (enabled by default, toggle with <leader>ci)
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    map('n', '<leader>ci', function()
      vim.lsp.inlay_hint.enable(
        not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
        { bufnr = bufnr }
      )
    end, "Toggle inlay hints")

    -- Diagnostics (vim.diagnostic; [d / ]d are handled by mini.bracketed)
    map('n', '<leader>ed', vim.diagnostic.open_float, "Show diagnostic")
    map('n', '<leader>eq', vim.diagnostic.setloclist, "Diagnostics to loclist")
  end,
})

-- Completion capabilities come from blink.cmp (replaces cmp_nvim_lsp).
-- blink loads at startup, so it is available here during the plugins/lsp phase.
-- Applied via the '*' config so it reaches every server in the chain — see
-- `:h vim.lsp.config()`, which documents '*' for exactly this — instead of
-- being repeated as `capabilities = capabilities` in all six blocks.
vim.lsp.config('*', {
  capabilities = require('blink.cmp').get_lsp_capabilities(),
})

-- =============================================================================
-- LSP SERVER CONFIGURATIONS (USING VIM.LSP.CONFIG - NEOVIM 0.11+)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CLANGD (C/C++ - PRIMARY FOCUS)
-- -----------------------------------------------------------------------------
-- Best LSP for C++ templates, handles Trilinos/deal.II complexity
-- Installation: sudo pacman -S clang

vim.lsp.config('clangd', {
  cmd = {
    "clangd",
    "--background-index",              -- Index in background (non-blocking)
    "--header-insertion=never",         -- Don't auto-insert includes (stay in control)
    "--completion-style=detailed",     -- Show full function signatures
    "--pch-storage=memory",            -- Use RAM for precompiled headers (fast, user has 64GB)
    "--function-arg-placeholders",     -- Show parameter names in completion
    "--fallback-style=none",            -- No format without .clang-format (stay out of others' code)
    "-j=8",                            -- Parallel jobs (Zen4 CPU)
    "--log=error",                     -- Only log errors (reduce noise)
    -- clang-tidy is opt-in per project: add .clang-tidy at the project root to enable it
  },

  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },

  root_markers = {
    "compile_commands.json",
    ".git",
    "CMakeLists.txt",
    "Makefile",
  },

  -- clangd-specific settings
  settings = {
    clangd = {
      semanticHighlighting = true,
    },
  },
})

-- -----------------------------------------------------------------------------
-- BASEDPYRIGHT (PYTHON - SECONDARY)
-- -----------------------------------------------------------------------------
-- Modern Python type checker and LSP (fork of Pyright)
-- Installation: pip install basedpyright (in each venv) or uv pip install basedpyright

vim.lsp.config('basedpyright', {
  cmd = { "basedpyright-langserver", "--stdio" },

  filetypes = { "python" },

  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    ".git",
  },

  -- basedpyright settings
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "basic",          -- basic, standard, or strict
        autoSearchPaths = true,              -- Auto-detect Python paths
        useLibraryCodeForTypes = true,       -- Use library code for type info
        diagnosticMode = "openFilesOnly",    -- Only check open files (lighter on large repos)
        -- Disable some noisy checks
        diagnosticSeverityOverrides = {
          reportUnusedImport = "warning",
          reportUnusedVariable = "warning",
          reportGeneralTypeIssues = "warning",
        },
      },
    },
  },
})

-- -----------------------------------------------------------------------------
-- BASH LANGUAGE SERVER (BASH/SHELL SCRIPTS - UTILITY)
-- -----------------------------------------------------------------------------
-- LSP for bash/shell scripts (syntax, shellcheck integration)
-- Installation: sudo pacman -S bash-language-server

vim.lsp.config('bashls', {
  cmd = { "bash-language-server", "start" },

  filetypes = { "sh", "bash", "zsh" },

  root_markers = { ".git" },

  -- bash-language-server settings
  settings = {
    bashIde = {
      globPattern = "*@(.sh|.inc|.bash|.command|.zsh)",
      shellcheckPath = "shellcheck",     -- Requires shellcheck installed
    },
  },
})

-- -----------------------------------------------------------------------------
-- YAML LANGUAGE SERVER (DATA ENGINEERING - dbt, CI, docker-compose)
-- -----------------------------------------------------------------------------
-- Schema-aware completion + validation via SchemaStore.
-- Installation: sudo pacman -S yaml-language-server  (official extra repo)

vim.lsp.config('yamlls', {
  cmd = { "yaml-language-server", "--stdio" },

  filetypes = { "yaml" },

  root_markers = { ".git" },

  settings = {
    yaml = {
      schemaStore = {
        enable = true,        -- pull schemas from SchemaStore.org
        url = "https://www.schemastore.org/api/json/catalog.json",
      },
      validate = true,
      keyOrdering = false,    -- don't complain about key order
    },
    redhat = { telemetry = { enabled = false } },
  },
})

-- -----------------------------------------------------------------------------
-- JSON LANGUAGE SERVER (DATA ENGINEERING - configs, package.json)
-- -----------------------------------------------------------------------------
-- Installation: sudo pacman -S vscode-json-languageserver  (official extra repo)

vim.lsp.config('jsonls', {
  cmd = { "vscode-json-languageserver", "--stdio" },

  filetypes = { "json", "jsonc" },

  root_markers = { ".git" },

  settings = {
    json = {
      schemaStore = { enable = true },
      validate = { enable = true },
    },
  },
})

-- -----------------------------------------------------------------------------
-- TINYMIST (TYPST - DOCUMENTS)
-- -----------------------------------------------------------------------------
-- One binary covering what vimtex+latexmk do for .tex: completion, hover,
-- goto-def, formatting (bundles typstyle) and the live preview server that
-- typst-preview.nvim drives. There is no separate compiler step.
-- Installation: sudo pacman -S tinymist  (official extra repo)

vim.lsp.config('tinymist', {
  cmd = { "tinymist" },

  filetypes = { "typst" },

  -- typst.toml marks a package/project root; .git covers plain document dirs.
  root_markers = { "typst.toml", ".git" },

  settings = {
    -- typstyle ships inside tinymist, so <leader>cf / format-on-save works
    -- with no extra package (the standalone `typstyle` binary is redundant).
    formatterMode = "typstyle",
    -- Write main.pdf next to the source on every save. The browser preview
    -- renders from memory and never produces a file, so without this there is
    -- no PDF to hand to anyone.
    exportPdf = "onSave",
    -- Search a project-local `fonts/` dir (relative to the workspace root) in
    -- addition to system fonts. Projects that bundle their own fonts for
    -- portability (e.g. the CV: Lato, Roboto Slab, FontAwesome 5 — none of
    -- which are installed system-wide) render in the preview AND in the
    -- exportPdf output exactly as `typst compile --font-path fonts` does.
    -- Harmless when a project has no fonts/ dir.
    fontPaths = { "fonts" },
  },
})

-- =============================================================================
-- ENABLE LSP SERVERS (NEOVIM 0.11+ AUTO-START)
-- =============================================================================

-- Enable the configured servers. They auto-start when a matching filetype is
-- opened. vim.lsp.enable() takes a list, so this is one call rather than six.
vim.lsp.enable({
  'clangd',       -- C/C++
  'basedpyright', -- Python
  'bashls',       -- Bash/shell
  'yamlls',       -- YAML
  'jsonls',       -- JSON
  'tinymist',     -- Typst
})

-- =============================================================================
-- ADDITIONAL LSP UI CUSTOMIZATION
-- =============================================================================

-- Set LSP log level (reduce noise)
vim.lsp.log.set_level("ERROR")

-- Format on save (enabled)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true }),
  pattern = { "*.c", "*.cpp", "*.cc", "*.h", "*.hpp", "*.py", "*.typ" },
  callback = function()
    -- C/C++ only: sanitize PDF / smart-quote artifacts BEFORE clangd formats,
    -- so the formatter never sees invalid syntax (≪/≫ pasted from papers, etc.).
    -- Must run ahead of vim.lsp.buf.format() — hence it lives here, not in a
    -- separate BufWritePre autocmd (ordering between autocmds is load-order).
    local ft = vim.bo.filetype
    if ft == "c" or ft == "cpp" then
      local save_cursor = vim.fn.getpos(".")
      pcall(vim.cmd, [[%s/≪/<</ge]])    -- U+226A → <<
      pcall(vim.cmd, [[%s/≫/>>/ge]])    -- U+226B → >> (template closing)
      pcall(vim.cmd, [[%s/[""]/"/ge]])  -- smart quotes → straight quotes
      vim.fn.setpos(".", save_cursor)
    end
    vim.lsp.buf.format({ async = false })
  end,
})

-- =============================================================================
-- CUSTOM COMMANDS (REPLACEMENTS FOR NVIM-LSPCONFIG COMMANDS)
-- =============================================================================

-- :LspInfo - Show LSP client information
vim.api.nvim_create_user_command('LspInfo', function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    print("No LSP clients attached to current buffer")
    print("\nConfigured servers: clangd, basedpyright, bashls, yamlls, jsonls, tinymist")
    print("Filetype: " .. vim.bo.filetype)
  else
    for _, client in ipairs(clients) do
      print(string.format("Client: %s (id %d)", client.name, client.id))
      print(string.format("  filetypes: %s", table.concat(client.config.filetypes or {}, ", ")))
      print(string.format("  cmd: %s", table.concat(client.config.cmd or {}, " ")))
      if client.server_info then
        print(string.format("  version: %s", client.server_info.version or "unknown"))
      end
    end
  end
end, { desc = "Show LSP client info" })

-- :LspRestart - Restart LSP clients in current buffer
vim.api.nvim_create_user_command('LspRestart', function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    print("No LSP clients to restart")
    return
  end
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
    print(string.format("Stopped %s", client.name))
  end
  -- Re-attach will happen automatically via filetype
  vim.cmd('edit')
end, { desc = "Restart LSP clients" })

-- :LspLog - Open LSP log file
vim.api.nvim_create_user_command('LspLog', function()
  vim.cmd('edit ' .. vim.lsp.get_log_path())
end, { desc = "Open LSP log file" })

-- :LspStart - Manually start LSP for current buffer
vim.api.nvim_create_user_command('LspStart', function(opts)
  local server = opts.args
  if server == "" then
    print("Usage: :LspStart <server_name>")
    print("Available: clangd, basedpyright, bashls")
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = vim.lsp.config[server]
  if cfg then
    vim.lsp.start(cfg, { bufnr = bufnr })
  else
    print("Unknown server: " .. server)
  end
end, { nargs = 1, complete = function() return { "clangd", "basedpyright", "bashls" } end, desc = "Start LSP server" })

-- =============================================================================
-- NOTES FOR TROUBLESHOOTING
-- =============================================================================
--
-- Check LSP status: :LspInfo
-- Check completion status: :CmpStatus
-- View LSP logs: :LspLog
-- Restart LSP: :LspRestart
-- Start LSP manually: :LspStart clangd
--
-- Native Lua commands:
--   :lua print(vim.inspect(vim.lsp.get_clients()))
--   :lua vim.print(vim.lsp.config._configs)
--
-- clangd requires compile_commands.json for full functionality:
--   cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
--   ln -s build/compile_commands.json .
--
-- clang-tidy is opt-in per project: add a .clang-tidy file at the project root to enable it.
-- (The --clang-tidy flag is intentionally absent from the clangd cmd above.)
--
-- basedpyright finds installed in current Python environment:
--   which basedpyright-langserver  (should be in venv bin/)
--
-- bash-language-server requires shellcheck for linting:
--   sudo pacman -S shellcheck
--
-- =============================================================================
