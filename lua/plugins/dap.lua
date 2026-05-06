-- lua/plugins/dap.lua
return {
  {
    "mfussenegger/nvim-dap",
    lazy = true,

    keys = {
      { "<F5>",  function() require("dap").continue()  end, desc = "DAP: Continue"  },
      { "<F9>",  function() require("dap").step_over() end, desc = "DAP: Step Over" },
      { "<F10>", function() require("dap").step_into() end, desc = "DAP: Step Into" },
      { "<F12>", function() require("dap").step_out()  end, desc = "DAP: Step Out"  },

      { "<leader>db", function() require("dap").toggle_breakpoint() end,
        desc = "DAP: Toggle Breakpoint" },
      { "<leader>dB", function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint Condition: "))
        end,
        desc = "DAP: Set Conditional Breakpoint" },
      { "<leader>dl", function() require("telescope").extensions.dap.list_breakpoints() end,
        desc = "DAP: List Breakpoints" },
    },

    config = function()
      local dap     = require("dap")
      local keymap  = vim.keymap.set
      local widgets = require("dap.ui.widgets")

      vim.fn.sign_define("DapBreakpoint",          { text = "🔴", texthl = "DiagnosticError", linehl = "",           numhl = "" })
      vim.fn.sign_define("DapStopped",             { text = "▶️",  texthl = "DiagnosticWarn",  linehl = "CursorLine", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "⚙️",  texthl = "DiagnosticInfo",  linehl = "",           numhl = "" })

      require("config.dap_adapters")
      require("config.dap_configurations")

      -- PageUp/PageDown: confirmed free in nvim, tmux, and terminal.
      -- Moves the view up/down the call stack while paused — does NOT resume execution.
      keymap("n", "<PageUp>",   dap.up,   { desc = "DAP: Frame Up (call stack)"   })
      keymap("n", "<PageDown>", dap.down, { desc = "DAP: Frame Down (call stack)" })

      keymap({ "n", "v" }, "<leader>dh", widgets.hover, { desc = "DAP: Hover Variable" })
      keymap("n", "<leader>ds", function()
        widgets.centered_float(widgets.scopes)
      end, { desc = "DAP: Float Scopes" })
      keymap("n", "<leader>df", function()
        widgets.centered_float(widgets.frames)
      end, { desc = "DAP: Float Frames" })

      keymap("n", "<leader>dr", dap.repl.toggle, { desc = "DAP: Toggle REPL" })

      -- Esc and q close DAP floating windows (\dh hover, \ds scopes, \df frames)
      vim.api.nvim_create_autocmd("FileType", {
        group    = vim.api.nvim_create_augroup("DapFloatClose", { clear = true }),
        pattern  = "dap-float",
        callback = function(ev)
          vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
          vim.keymap.set("n", "q",     "<cmd>close<cr>", { buffer = ev.buf, silent = true })
        end,
      })
    end,

    dependencies = {
      {
        "theHamsta/nvim-dap-virtual-text",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
          require("nvim-dap-virtual-text").setup({
            enabled                     = true,
            enabled_commands            = true,
            highlight_changed_variables = true,
            highlight_new_as_changed    = true,
            show_stop_reason            = true,
            commented                   = true,
            only_first_definition       = true,
            all_references              = false,
            clear_on_continue           = false,

            virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",

            display_callback = function(variable, buf, stackframe, node, options)
              if options.virt_text_pos == "inline" then
                return " = " .. variable.value
              else
                return variable.name .. " = " .. variable.value
              end
            end,
          })
        end,
      },

      {
        "nvim-telescope/telescope-dap.nvim",
        dependencies = { "nvim-telescope/telescope.nvim" },
        config = function()
          require("telescope").load_extension("dap")
        end,
      },

      {
        "mfussenegger/nvim-dap-python",
        config = function()
          require("dap-python").setup("python3")
        end,
      },
    },
  },
}
