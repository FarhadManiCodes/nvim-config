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
-- for every server, so wiring it once here keeps the ten vim.lsp.config blocks
-- below purely declarative (server command + filetypes + settings, nothing else).
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspBufferSetup", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- Buffers no server should see. Both flags are set in autocmds.lua:
    --   large_file  (Section 9)  — >10MB, LSP would stall on it
    --   secret_file (Section 15) — API keys; nothing here needs parsing, and
    --                              bashls would additionally run shellcheck
    --                              across the key material.
    --
    -- buf_detach_client, NOT stop_client: the intent is "not on THIS buffer",
    -- but stop_client stops the whole server, so opening a single >10MB file
    -- killed LSP for every other buffer in the session — silently, since
    -- nothing errors, completion and gd simply stop working project-wide.
    -- (stop_client is also @deprecated in 0.12.) Detaching is scheduled because
    -- we are currently inside that client's own LspAttach dispatch.
    local skip = (vim.b[bufnr].large_file and "large file")
      or (vim.b[bufnr].secret_file and "secret file")
    if skip then
      vim.notify(
        string.format("LSP disabled for %s (buffer %d)", skip, bufnr),
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

    -- Diagnostics (vim.diagnostic; [d / ]d are Neovim built-ins -- mini.bracketed's
    -- diagnostic module is disabled precisely so the built-in stands)
    map('n', '<leader>ed', vim.diagnostic.open_float, "Show diagnostic")
    map('n', '<leader>eq', vim.diagnostic.setloclist, "Diagnostics to loclist")
  end,
})

-- Completion capabilities come from blink.cmp (replaces cmp_nvim_lsp).
-- blink loads at startup, so it is available here during the plugins/lsp phase.
-- Applied via the '*' config so it reaches every server in the chain — see
-- `:h vim.lsp.config()`, which documents '*' for exactly this — instead of
-- being repeated as `capabilities = capabilities` in all ten blocks.
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
-- RUFF (PYTHON LINT + FORMAT; PAIRS WITH BASEDPYRIGHT, DOES NOT REPLACE IT)
-- -----------------------------------------------------------------------------
-- Division of labour: ruff has no type system at all, and basedpyright reports
-- supports_method("textDocument/formatting") = false. So ruff owns formatting
-- and the fast lint rules, basedpyright owns types, completion, hover and
-- navigation. Neither is redundant.
--
-- Installation: sudo pacman -S ruff. Native binary (Depends On: glibc, libgcc
-- only) -- it parses Python itself, so it needs neither the venv nor a matching
-- interpreter, and `target-version`, inferred from requires-python, is what makes
-- one recent ruff correct for every project. `ruff server` is the language server
-- itself; the old standalone ruff-lsp package is deprecated and archived.
--
-- Formatting is MANUAL via <leader>cf. *.py is deliberately absent from the
-- format-on-save glob below: auto-reformatting other people's data-engineering
-- code on save buries real diffs.

vim.lsp.config('ruff', {
  cmd = { "ruff", "server" },

  filetypes = { "python" },

  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },

  -- ruff server reads its configuration from initializationOptions.settings,
  -- NOT from `settings` -- passing it there is silently ignored (measured: the
  -- select below had no effect at all until it moved here).
  init_options = {
    settings = {
      -- A project's own pyproject.toml/ruff.toml must win over anything set
      -- here, or every repo silently gets this machine's opinions.
      configurationPreference = "filesystemFirst",
      lint = {
        -- Explicit, because ruff's defaults are broader than they look:
        -- measured with no config present, they also raise I001 (isort) and
        -- B018 (bugbear), which is noise on pre-existing code. E4 imports,
        -- E7 statements, E9 syntax/IO errors, F pyflakes. Widen by adding here.
        select = { "E4", "E7", "E9", "F" },
        -- F821 is basedpyright's, not ruff's. Both detect undefined names, but
        -- ONLY basedpyright's diagnostic carries the "import json" code action
        -- -- auto-import is attached to reportUndefinedVariable, so suppressing
        -- that to remove the duplicate silently cost auto-import entirely
        -- (measured: basedpyright offered 0 actions on an undefined name).
        -- Dropping ruff's half instead keeps one report AND the action.
        -- basedpyright is the better detector here anyway: it knows imports,
        -- scopes and stubs, where F821 is scope analysis alone.
        ignore = { "F821" },
      },
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
        -- Adding ruff made three diagnostics arrive twice. They are split by
        -- which side owns the useful CODE ACTION, not by which is "faster":
        --
        --   unused import / unused variable -> ruff. Its quickfix removes them,
        --     and there is nothing basedpyright offers here that ruff does not.
        --     Hence "none" below.
        --   undefined name -> BASEDPYRIGHT, deliberately not ruff. Its
        --     reportUndefinedVariable diagnostic is what carries the
        --     "import json" auto-import action; turning it off left 0 actions
        --     on an undefined name (measured). So it stays on, and F821 is
        --     ignored on ruff's side instead -- see the ruff block above.
        --
        -- reportUnusedExpression stays because ruff's equivalent (B018) is
        -- outside the selected rules. Type diagnostics stay here regardless:
        -- ruff has no type system at all.
        diagnosticSeverityOverrides = {
          reportUnusedImport = "none",
          reportUnusedVariable = "none",
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

-- -----------------------------------------------------------------------------
-- LUA_LS (THIS CONFIG ITSELF)
-- -----------------------------------------------------------------------------
-- The config is ~5k lines of Lua across 21 files and had no server at all, so
-- vim.api completion, diagnostics and goto-definition were missing in the one
-- language it is written in.
-- Installation: sudo pacman -S lua-language-server  (official extra repo)

vim.lsp.config('lua_ls', {
  cmd = { "lua-language-server" },

  filetypes = { "lua" },

  -- .luarc.json first so a project can override; lazy-lock.json identifies a
  -- Neovim config root specifically, which .git alone would not.
  root_markers = { ".luarc.json", ".luarc.jsonc", "lazy-lock.json", ".git" },

  settings = {
    Lua = {
      runtime = {
        -- Neovim embeds LuaJIT, not PUC Lua 5.4. Wrong value here means the
        -- server offers 5.4-only stdlib and flags LuaJIT builtins.
        version = "LuaJIT",
      },
      diagnostics = {
        -- Without this every single `vim.` is reported as an undefined global,
        -- which is loud enough to make the server worse than none.
        globals = { "vim" },
      },
      workspace = {
        -- Neovim's own Lua, so vim.api/vim.fn/vim.uv resolve. Deliberately NOT
        -- the whole plugin tree: indexing ~40 plugins to make require("oil")
        -- resolve costs far more than it returns. lazydev.nvim is the tool for
        -- that if it ever becomes worth it.
        library = { vim.env.VIMRUNTIME .. "/lua" },
        -- Stops the "this workspace uses luassert, configure it?" prompts.
        checkThirdParty = false,
      },
      telemetry = { enable = false },
      format = {
        -- Leaves <leader>cf working on Lua, which had no formatter before.
        -- *.lua is intentionally absent from the format-on-save glob below:
        -- reformatting this repo wholesale on every save would bury real
        -- diffs, so Lua formatting stays manual.
        enable = true,
      },
    },
  },
})

-- -----------------------------------------------------------------------------
-- NEOCMAKELSP (CMAKE)
-- -----------------------------------------------------------------------------
-- 27 of the 37 CMake files on this machine are authored (SciCpp's chapters/ tree,
-- toy-pde-solver's src+tests, the playground projects), so completion and
-- goto-definition across add_subdirectory earn their place. clangd still owns the
-- C++ itself; this only covers the build files.
--
-- Installation: paru -S neocmakelsp (AUR; builds with the rust kept for paru, and
-- needs only cmake at runtime). Chosen over cmake-language-server, which has been
-- idle upstream since 2025-02. `stdio` is a subcommand, not a flag.
--
-- Formatting is delegated: neocmakelsp's own formatter is a passthrough (measured
-- -- `project(demo   CXX)` came back untouched), so the real work is done by
-- gersemi, pointed at via a [format] block in its own TOML config rather than
-- through LSP settings. sudo pacman -S python-gersemi.

vim.lsp.config('neocmake', {
  cmd = { "neocmakelsp", "stdio" },

  filetypes = { "cmake" },

  -- CMakeLists.txt first so a subdirectory does not become the root: SciCpp has
  -- a CMakeLists.txt at every level of chapters/, and attaching at the deepest
  -- one would hide the targets defined above it.
  root_markers = { "CMakeLists.txt", ".git" },

  -- init_options, not settings -- this server reads its editor config there.
  init_options = {
    format = { enable = true },
    lint = { enable = true },
    -- Scans installed CMake packages so find_package() completes for things on
    -- the system (AOCL, Trilinos...) rather than only what is in this project.
    scan_cmake_in_package = true,
  },
})

-- -----------------------------------------------------------------------------
-- TAPLO (TOML)
-- -----------------------------------------------------------------------------
-- The draw is SchemaStore validation, the same thing yamlls already gives YAML:
-- seven pyproject.toml files here (papis-ask, paper-refinery, mathunicode,
-- cv-generator, yts...) plus starship.toml, uv.toml and friends. A mistyped
-- [tool.ruff] key becomes a diagnostic instead of a surprise at build time.
-- Nothing shadowed: the toml parser gives highlighting, but there was no
-- validation at all before this.
--
-- Installation: sudo pacman -S taplo-cli (extra, not AUR as first assumed).
-- `taplo lsp stdio` -- verified the lsp subcommand exists in the Arch build,
-- since upstream warns it is absent from some distributions.

vim.lsp.config('taplo', {
  -- --config is required, not a nicety. Schema association does not happen by
  -- itself: with no config a broken pyproject.toml (`version = 123`, a misspelt
  -- key) produced ZERO diagnostics, and neither a [schema] catalog nor LSP
  -- `settings.evenBetterToml` changed that -- only an explicit [[rule]] with
  -- include+url did. taplo has no XDG user-level config, it searches the project
  -- directory only, so pointing it at a tracked global file here avoids needing a
  -- .taplo.toml in all seven projects. Note the option precedes the subcommand.
  cmd = {
    "taplo", "lsp",
    "--config", vim.fn.expand("~/.config/taplo/config.toml"),
    "stdio",
  },

  filetypes = { "toml" },

  -- taplo.toml before .git so a project's own formatter/schema rules win.
  root_markers = { ".taplo.toml", "taplo.toml", ".git" },
})

-- =============================================================================
-- ENABLE LSP SERVERS (NEOVIM 0.11+ AUTO-START)
-- =============================================================================

-- Enable the configured servers. They auto-start when a matching filetype is
-- opened. vim.lsp.enable() takes a list, so this is one call rather than ten.
vim.lsp.enable({
  'clangd',       -- C/C++
  'basedpyright', -- Python
  'bashls',       -- Bash/shell
  'yamlls',       -- YAML
  'jsonls',       -- JSON
  'tinymist',     -- Typst
  'lua_ls',       -- Lua (this config)
  'ruff',         -- Python lint + format
  'neocmake',     -- CMake
  'taplo',        -- TOML
})

-- =============================================================================
-- ADDITIONAL LSP UI CUSTOMIZATION
-- =============================================================================

-- Set LSP log level (reduce noise)
vim.lsp.log.set_level("ERROR")

-- Format on save (enabled)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = true }),
  -- *.py is absent on purpose: ruff formats Python, but only when asked
  -- (<leader>cf). Reformatting third-party Python on save buries real diffs.
  pattern = { "*.c", "*.cpp", "*.cc", "*.h", "*.hpp", "*.typ" },
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
    print("\nConfigured servers: clangd, basedpyright, bashls, yamlls, jsonls, tinymist, lua_ls, ruff, neocmake, taplo")
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
    print("Available: clangd, basedpyright, ruff, bashls, yamlls, jsonls, tinymist, lua_ls")
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = vim.lsp.config[server]
  if cfg then
    vim.lsp.start(cfg, { bufnr = bufnr })
  else
    print("Unknown server: " .. server)
  end
end, { nargs = 1, complete = function()
    return { "clangd", "basedpyright", "ruff", "bashls", "yamlls", "jsonls", "tinymist", "lua_ls", "neocmake", "taplo" }
  end, desc = "Start LSP server" })

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
