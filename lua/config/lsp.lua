-- ~/.config/nvim/lua/config/lsp.lua
-- LSP configuration: C/C++, Python, shell, YAML, JSON, Typst, Lua, CMake
-- Using Neovim 0.11+ native vim.lsp.config API (not deprecated lspconfig)

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
-- for every server, so wiring it once here keeps the nine lsp/<name>.lua files
-- purely declarative (server command + filetypes + settings, nothing else).
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspBufferSetup", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- Buffers no server should see. Both flags are set in autocmds.lua:
    --   large_file  ("Large file handling") — >10MB, LSP would stall on it
    --   secret_file ("Secret files")        — API keys; nothing here needs
    --                                         parsing, and bashls would
    --                                         additionally run shellcheck
    --                                         across the key material.
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
-- being repeated as `capabilities = capabilities` in all nine lsp/ files.
vim.lsp.config('*', {
  capabilities = require('blink.cmp').get_lsp_capabilities(),
})

-- =============================================================================
-- SERVER CONFIGURATIONS: lsp/<name>.lua
-- =============================================================================
-- One file per server under lsp/ at the config root. Neovim merges each onto
-- the '*' config above when vim.lsp.enable() below resolves it. Do not also
-- call vim.lsp.config('<name>', ...) here: explicit calls take precedence over
-- lsp/*.lua and would silently override the file.

-- =============================================================================
-- ENABLE LSP SERVERS (NEOVIM 0.11+ AUTO-START)
-- =============================================================================

-- Enable the configured servers. They auto-start when a matching filetype is
-- opened. vim.lsp.enable() takes a list, so this is one call rather than nine.
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
      -- Code points spelled as \u escapes: literal curly quotes in this file
      -- were once normalised to ASCII, silently turning this into a no-op.
      pcall(vim.cmd, [[%s/[“”]/"/ge]])  -- “ ” → "
      pcall(vim.cmd, [[%s/[‘’]/'/ge]])  -- ‘ ’ → '
      vim.fn.setpos(".", save_cursor)
    end
    vim.lsp.buf.format({ async = false })
  end,
})

-- =============================================================================
-- TROUBLESHOOTING (Neovim 0.12 built-ins; no custom :Lsp* commands)
-- =============================================================================
--
-- Status of attached clients and enabled configs: :checkhealth vim.lsp
-- Restart / stop / start for the current buffer:  :lsp restart | :lsp stop | :lsp enable <name>
-- LSP log:                                         :lua vim.cmd.edit(vim.lsp.log.get_filename())
-- Resolved config for one server:                  :lua vim.print(vim.lsp.config.clangd)
--
-- clangd requires compile_commands.json for full functionality:
--   cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
--   ln -s build/compile_commands.json .
--
-- clang-tidy is opt-in per project: add a .clang-tidy file at the project root to enable it.
-- (The --clang-tidy flag is intentionally absent from the cmd in lsp/clangd.lua.)
--
-- bash-language-server requires shellcheck for linting:
--   sudo pacman -S shellcheck
--
-- =============================================================================
