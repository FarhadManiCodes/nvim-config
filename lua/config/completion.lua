-- ~/.config/nvim/lua/config/completion.lua
-- blink.cmp Completion Configuration
-- Sources: LSP, buffer, path (+ papis for \cite in tex). Snippets via vim.snippet.
-- Migrated from nvim-cmp. Design decisions captured per-topic in commit message.
--
-- Why blink: Rust fuzzy matcher (frizbee) is fastest exactly on clangd's huge
-- candidate lists (templates/overloads/MPI/OMP). Built-in lsp/buffer/path/cmdline/
-- snippet sources replace the old nvim-cmp + 5 cmp-* plugins.

local CompletionItemKind = vim.lsp.protocol.CompletionItemKind

-- =============================================================================
-- KIND ICONS (carried over 1:1 from the old nvim-cmp config)
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

-- Source name → short label shown in the menu's right column ([LSP], [Buf], …)
local source_labels = {
  LSP = "[LSP]",
  Buffer = "[Buf]",
  Path = "[Path]",
  Snippets = "[Snip]",
}

require("blink.cmp").setup({
  -- ---------------------------------------------------------------------------
  -- LARGE-FILE GUARD (tier 3 of the large-file strategy; see CLAUDE.md)
  -- ---------------------------------------------------------------------------
  -- Disable completion entirely on buffers flagged >10MB (autocmds.lua sets
  -- vim.b.large_file). Mirrors the old nvim-cmp `enabled` guard.
  enabled = function()
    return not vim.b.large_file
  end,

  -- ---------------------------------------------------------------------------
  -- KEYMAPS (Topic 4 — replicate the old nvim-cmp muscle memory)
  -- ---------------------------------------------------------------------------
  -- <Tab>/<S-Tab> are "smart": select in the menu, else jump clangd's argument
  -- placeholders (${1:...}), else fall back to a literal Tab. <C-h/j/k/l> are
  -- reserved for vim-tmux-navigator, so Tab is the only free key for snippet jump.
  keymap = {
    preset = "none",

    ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },

    ["<C-n>"]   = { "select_next", "fallback" },
    ["<C-p>"]   = { "select_prev", "fallback" },
    ["<Tab>"]   = { "select_next", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

    ["<C-b>"] = { "scroll_documentation_up", "fallback" },
    ["<C-f>"] = { "scroll_documentation_down", "fallback" },

    -- Accept only if an item is explicitly selected, else insert a newline
    -- (matches the old `confirm({ select = false })` behavior).
    ["<CR>"]  = { "accept", "fallback" },
    ["<C-e>"] = { "hide", "fallback" },
  },

  -- ---------------------------------------------------------------------------
  -- APPEARANCE (Topic 5)
  -- ---------------------------------------------------------------------------
  appearance = {
    kind_icons = kind_icons,
  },

  -- ---------------------------------------------------------------------------
  -- COMPLETION BEHAVIOR
  -- ---------------------------------------------------------------------------
  completion = {
    -- Fuzzy match on text before the cursor. blink triggers after the first
    -- keyword character by default (= the old completion.keyword_length = 1).
    keyword = { range = "prefix" },

    list = {
      -- Nothing preselected; you must Tab/<C-n> to pick. <CR> on an unselected
      -- menu inserts a newline. auto_insert previews the selected text inline in
      -- the buffer as you navigate (old SelectBehavior.Insert).
      selection = { preselect = false, auto_insert = true },
    },

    -- Topic 2/3a: keep auto_brackets ON. clangd sends snippet items (arg
    -- placeholders) and blink defers to them (no double parens). basedpyright
    -- sends plain items, so blink supplies bare () for Python functions.
    accept = {
      auto_brackets = { enabled = true },
    },

    menu = {
      border = "rounded",
      draw = {
        columns = {
          { "kind_icon" },
          { "label", "label_description", gap = 1 },
          { "source_name" },
        },
        components = {
          source_name = {
            text = function(ctx)
              return source_labels[ctx.source_name] or ("[" .. ctx.source_name .. "]")
            end,
          },
        },
      },
    },

    -- Topic 5: documentation is on-demand (press <C-Space>), not auto-shown.
    documentation = {
      auto_show = false,
      window = { border = "rounded" },
    },

    -- Topic 5: ghost text off (kept off, as in the old config).
    ghost_text = { enabled = false },
  },

  -- ---------------------------------------------------------------------------
  -- SNIPPETS (Topic 7) — Neovim built-in vim.snippet, no snippet library
  -- ---------------------------------------------------------------------------
  -- This is the expansion ENGINE (expands clangd's ${1:...} placeholders).
  -- There is no standalone "snippets" SOURCE in the lists below, matching the
  -- old config (no friendly-snippets / luasnip).
  snippets = { preset = "default" },

  -- ---------------------------------------------------------------------------
  -- FUZZY / SORTING (Topic 8)
  -- ---------------------------------------------------------------------------
  fuzzy = {
    implementation = "prefer_rust_with_warning", -- prebuilt binary, no cargo build
    frecency = { enabled = true }, -- learns most-used items (≈ old recently_used)
    use_proximity = true,          -- boosts words near cursor (≈ old locality)
  },

  -- ---------------------------------------------------------------------------
  -- SOURCES (Topics 1, 2, 3a/b/c)
  -- ---------------------------------------------------------------------------
  sources = {
    -- Default: LSP (clangd / basedpyright / bashls / yamlls / jsonls), buffer, path.
    default = { "lsp", "buffer", "path" },

    per_filetype = {
      -- LaTeX: \cite/\ref/\begin/commands via manual <C-x><C-o> (vimtex omni,
      -- which parses the local refs.bib) — no cmp-omni, no texlab. papis is NOT
      -- an as-you-type \cite source (its completion only does tag completion in
      -- papis info.yaml files); cite search/insert is the picker (<leader>pp).
      tex = { "buffer", "path" },

      -- SQL: buffer + path only (execution via vim-dadbod, no schema completion).
      sql   = { "buffer", "path" },
      mysql = { "buffer", "path" },
      plsql = { "buffer", "path" },

      -- Markdown: buffer + path.
      markdown = { "buffer", "path" },

      -- Git commit messages: buffer only.
      gitcommit = { "buffer" },
    },

    providers = {
      lsp = {
        name = "LSP",
        max_items = 20, -- was max_item_count = 20
        -- Filter out Text-kind items from the LSP (noisy in C++); buffer covers text.
        transform_items = function(_, items)
          return vim.tbl_filter(function(item)
            return item.kind ~= CompletionItemKind.Text
          end, items)
        end,
      },

      buffer = {
        name = "Buffer",
        max_items = 10,
        opts = {
          -- Search words from all visible buffers (old get_bufnrs).
          get_bufnrs = function()
            local bufs = {}
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              bufs[vim.api.nvim_win_get_buf(win)] = true
            end
            return vim.tbl_keys(bufs)
          end,
        },
      },

      path = {
        name = "Path",
        opts = { trailing_slash = true },
      },

      -- NOTE: papis.nvim still registers a "papis" provider into blink (its
      -- completion is tag completion for info.yaml files), but it is intentionally
      -- not listed in any source list above — cite insertion is the picker
      -- (<leader>pp), and cite/ref completion is vimtex omni via <C-x><C-o>.
    },
  },

  -- ---------------------------------------------------------------------------
  -- COMMAND-LINE COMPLETION (Topic 6 — Tab-triggered, not auto-popup)
  -- ---------------------------------------------------------------------------
  cmdline = {
    enabled = true,
    -- Menu only appears when you press <Tab> (quiet while typing).
    completion = { menu = { auto_show = false } },
    keymap = {
      preset = "none",
      ["<Tab>"]   = { "show", "select_next", "fallback" },
      ["<S-Tab>"] = { "show", "select_prev", "fallback" },
      ["<C-n>"]   = { "select_next", "fallback" },
      ["<C-p>"]   = { "select_prev", "fallback" },
      ["<CR>"]    = { "accept", "fallback" },
      ["<C-e>"]   = { "hide", "fallback" },
    },
    sources = function()
      local t = vim.fn.getcmdtype()
      -- ':' → Vim commands + paths; '/' '?' → buffer words (search).
      if t == ":" then
        return { "cmdline", "path" }
      elseif t == "/" or t == "?" then
        return { "buffer" }
      end
      return {}
    end,
  },
})
