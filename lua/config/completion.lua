-- ~/.config/nvim/lua/config/completion.lua
-- nvim-cmp Completion Configuration
-- 3 sources: LSP, buffer, path — snippets via vim.snippet (Neovim built-in)
-- Optimized for C++ template completion and Python data engineering

local cmp = require("cmp")

-- =============================================================================
-- KIND ICONS (COMPLETION ITEM TYPES)
-- =============================================================================

local kind_icons = {
  Text = "",
  Method = "󰆧",
  Function = "󰊕",
  Constructor = "",
  Field = "󰇽",
  Variable = "󰂡",
  Class = "󰠱",
  Interface = "",
  Module = "",
  Property = "󰜢",
  Unit = "",
  Value = "󰎠",
  Enum = "",
  Keyword = "󰌋",
  Snippet = "",
  Color = "󰏘",
  File = "󰈙",
  Reference = "",
  Folder = "󰉋",
  EnumMember = "",
  Constant = "󰏿",
  Struct = "",
  Event = "",
  Operator = "󰆕",
  TypeParameter = "󰅲",
}

-- =============================================================================
-- NVIM-CMP SETUP
-- =============================================================================

cmp.setup({
  -- -------------------------------------------------------------------------
  -- LARGE FILE GUARD
  -- -------------------------------------------------------------------------
  enabled = function()
    return not vim.b.large_file
  end,

  -- -------------------------------------------------------------------------
  -- COMPLETION BEHAVIOR
  -- -------------------------------------------------------------------------
  completion = {
    completeopt = "menu,menuone,noselect",  -- User must select (no auto-complete)
    keyword_length = 1,                     -- Trigger after 1 character
    keyword_pattern = [[\k\+]],             -- Default keyword pattern
  },

  -- -------------------------------------------------------------------------
  -- CONFIRMATION BEHAVIOR
  -- -------------------------------------------------------------------------
  confirmation = {
    default_behavior = cmp.ConfirmBehavior.Replace,
  },

  -- -------------------------------------------------------------------------
  -- PRESELECTION (DISABLED)
  -- -------------------------------------------------------------------------
  preselect = cmp.PreselectMode.None,  -- Don't auto-select first item

  -- -------------------------------------------------------------------------
  -- SNIPPET SUPPORT (Neovim 0.10+ built-in, no extra plugin needed)
  -- -------------------------------------------------------------------------
  snippet = {
    expand = function(args)
      vim.snippet.expand(args.body)
    end,
  },

  -- -------------------------------------------------------------------------
  -- WINDOW APPEARANCE
  -- -------------------------------------------------------------------------
  window = {
    completion = cmp.config.window.bordered({
      border = "rounded",
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
    }),
    documentation = cmp.config.window.bordered({
      border = "rounded",
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    }),
  },

  -- -------------------------------------------------------------------------
  -- FORMATTING (HOW COMPLETION ITEMS APPEAR)
  -- -------------------------------------------------------------------------
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      -- Kind icons
      vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)

      -- Source name in menu
      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        omni     = "[Omni]",
        buffer   = "[Buf]",
        path     = "[Path]",
        luasnip  = "[Snip]",  -- If you add snippets later
      })[entry.source.name]

      -- Truncate long completion items
      local max_width = 50
      if #vim_item.abbr > max_width then
        vim_item.abbr = vim_item.abbr:sub(1, max_width - 3) .. "..."
      end

      return vim_item
    end,
  },

  -- -------------------------------------------------------------------------
  -- KEYBINDINGS
  -- -------------------------------------------------------------------------
  mapping = cmp.mapping.preset.insert({
    -- Manual trigger
    ['<C-Space>'] = cmp.mapping.complete(),

    -- Navigation
    ['<C-n>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
    ['<C-p>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
    ['<Tab>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
    ['<S-Tab>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),

    -- Scroll documentation
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),

    -- Confirm selection
    ['<CR>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,  -- Must explicitly select item (no auto-confirm)
    }),

    -- Close completion menu
    ['<C-e>'] = cmp.mapping.abort(),

    -- Navigate between snippet placeholders (if you add snippets later)
    -- ['<C-j>'] = cmp.mapping(function(fallback)
    --   if luasnip.jumpable(1) then
    --     luasnip.jump(1)
    --   else
    --     fallback()
    --   end
    -- end, { "i", "s" }),
  }),

  -- -------------------------------------------------------------------------
  -- COMPLETION SOURCES (PRIORITY ORDER)
  -- -------------------------------------------------------------------------
  sources = cmp.config.sources({
    -- Primary: LSP (methods, functions, types, etc.)
    {
      name = "nvim_lsp",
      priority = 1000,
      -- Limit number of items for performance
      max_item_count = 20,
      -- Filter out text completions (noisy in C++)
      entry_filter = function(entry, ctx)
        local kind = require("cmp.types").lsp.CompletionItemKind[entry:get_kind()]
        -- Disable Text completions from LSP (use buffer for text)
        if kind == "Text" then
          return false
        end
        return true
      end,
    },

    -- Secondary: Buffer words (useful for long template names)
    {
      name = "buffer",
      priority = 500,
      max_item_count = 10,
      option = {
        -- Search visible buffers
        get_bufnrs = function()
          local bufs = {}
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            bufs[vim.api.nvim_win_get_buf(win)] = true
          end
          return vim.tbl_keys(bufs)
        end,
      },
    },

    -- Tertiary: File paths (for includes)
    {
      name = "path",
      priority = 250,
      option = {
        trailing_slash = true,
      },
    },
  }),

  -- -------------------------------------------------------------------------
  -- SORTING AND MATCHING
  -- -------------------------------------------------------------------------
  sorting = {
    priority_weight = 2,
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.score,
      cmp.config.compare.recently_used,
      cmp.config.compare.locality,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },

  -- -------------------------------------------------------------------------
  -- EXPERIMENTAL FEATURES
  -- -------------------------------------------------------------------------
  experimental = {
    ghost_text = false,  -- Don't show inline ghost text (too distracting)
  },
})

-- =============================================================================
-- FILETYPE-SPECIFIC OVERRIDES
-- =============================================================================

-- SQL: Use buffer and path completion (no LSP)
cmp.setup.filetype({ "sql", "mysql", "plsql" }, {
  sources = cmp.config.sources({
    { name = "buffer", max_item_count = 15 },
    { name = "path" },
  }),
})

-- Markdown: Use buffer completion primarily
cmp.setup.filetype("markdown", {
  sources = cmp.config.sources({
    { name = "buffer", max_item_count = 15 },
    { name = "path" },
  }),
})

-- LaTeX: Use vimtex omnicomplete for citations/references
cmp.setup.filetype("tex", {
  sources = cmp.config.sources({
    { name = "omni", priority = 1000 },  -- vimtex citations (\cite) and references (\ref)
    { name = "buffer", max_item_count = 10 },
    { name = "path" },
  }),
})

-- Git commit messages: Buffer only
cmp.setup.filetype("gitcommit", {
  sources = cmp.config.sources({
    { name = "buffer" },
  }),
})

-- =============================================================================
-- COMMAND-LINE COMPLETION
-- =============================================================================

-- Use buffer source for `/` and `?` (searching in buffer)
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})

-- Use path and cmdline sources for `:` (Vim commands)
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' },
    { name = 'cmdline' }
  }),
  matching = { disallow_symbol_nonprefix_matching = false }
})

-- =============================================================================
-- INTEGRATION WITH NVIM-AUTOPAIRS
-- =============================================================================

-- Automatically insert parentheses after function/method completion
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
cmp.event:on(
  'confirm_done',
  cmp_autopairs.on_confirm_done()
)

-- =============================================================================
-- NOTES FOR TROUBLESHOOTING
-- =============================================================================
--
-- Check completion status: :CmpStatus
-- Check sources: :CmpStatus shows active sources
-- Toggle completion: You can disable/enable per buffer
-- Check mappings: :verbose imap <Tab>
--
-- If completion is slow:
-- 1. Reduce max_item_count in sources
-- 2. Check :LspInfo for slow LSP servers
-- 3. Ensure large_file detection is working
--
-- If no completions appear:
-- 1. :CmpStatus - check if sources are active
-- 2. :LspInfo - check if LSP is attached
-- 3. Try <C-Space> to manually trigger
--
-- =============================================================================
