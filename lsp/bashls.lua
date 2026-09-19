-- ~/.config/nvim/lsp/bashls.lua
-- BASH LANGUAGE SERVER (BASH/SHELL SCRIPTS - UTILITY)
-- LSP for bash/shell scripts (syntax, shellcheck integration)
-- Installation: sudo pacman -S bash-language-server

return {
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
}
