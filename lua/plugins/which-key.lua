-- lua/plugins/which-key.lua
-- Keymap discoverability: press <leader> and wait to see all available bindings.
-- Toggle on/off with <leader>? — preference persists across restarts.

local wk_state_file = vim.fn.stdpath("data") .. "/which_key_enabled.txt"

local function load_enabled()
  local f = io.open(wk_state_file, "r")
  if f then
    local val = f:read("*l"); f:close()
    return val ~= "false"
  end
  return true  -- enabled by default
end

local function save_enabled(state)
  local f = io.open(wk_state_file, "w")
  if f then f:write(tostring(state)); f:close() end
end

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",

    opts = {
      delay = 1000,  -- ms before popup appears

      spec = {
        -- ── Prefix group labels ──────────────────────────────────────────
        { "<leader>b", group = "Buffers"    },
        { "<leader>c", group = "Code"       },
        { "<leader>d", group = "Debug"      },
        { "<leader>e", group = "Env/Diag"   },
        { "<leader>f", group = "Find"       },
        { "<leader>g", group = "Git Log"    },
        { "<leader>h", group = "Git Hunks"  },
        { "<leader>l", group = "LaTeX"      },
        { "<leader>p", group = "Papers"     },
        { "<leader>r", group = "Run/Search" },
        { "<leader>t", group = "Theme/UI"   },
        { "<leader>z", group = "Focus"      },

        -- ── Hidden keymaps to suppress overlap warnings ──────────────────
        -- These are irreducible Vim operator-pending mappings: the short key is
        -- intentionally a prefix that waits for a target (timeout disambiguates).
        -- nvim-surround add / change / delete:
        { "ys", hidden = true },
        { "yss", hidden = true },
        { "yS", hidden = true },
        { "ySS", hidden = true },
        { "cs", hidden = true },
        { "cS", hidden = true },
        { "ds", hidden = true },
        { "dS", hidden = true },
        -- built-in comments:
        { "gc", hidden = true },
        { "gcc", hidden = true },
        -- nvim-autopairs default insert-mode pair keys (parents of move-past
        -- / pair-handling mappings; functionality is unaffected by hiding):
        { "`", hidden = true, mode = "i" },
        { "]", hidden = true, mode = "i" },

        -- ── DAP F-key bindings (shown in which-key help) ─────────────────
        { "<F5>",      desc = "DAP: Continue"               },
        { "<F9>",      desc = "DAP: Step Over"              },
        { "<F10>",     desc = "DAP: Step Into"              },
        { "<F12>",     desc = "DAP: Step Out"               },
        { "<PageUp>",  desc = "DAP: Frame Up (call stack)"  },
        { "<PageDown>",desc = "DAP: Frame Down (call stack)"},
      },
    },

    config = function(_, opts)
      local wk = require("which-key")

      -- Apply enabled state from persisted preference
      opts.plugins = opts.plugins or {}
      local enabled = load_enabled()
      if not enabled then
        -- Start disabled: override the delay to a huge number so popup never fires
        opts.delay = 9999999
      end

      wk.setup(opts)

      -- <leader>? — toggle which-key on/off, persist the choice
      vim.keymap.set("n", "<leader>?", function()
        local currently_enabled = load_enabled()
        local new_state = not currently_enabled
        save_enabled(new_state)

        -- Apply immediately by reloading with new delay
        local new_opts = vim.deepcopy(opts)
        new_opts.delay = new_state and 1000 or 9999999
        wk.setup(new_opts)

        vim.notify(
          new_state and "which-key enabled" or "which-key disabled",
          vim.log.levels.INFO
        )
      end, { desc = "Toggle which-key" })
    end,
  },
}
