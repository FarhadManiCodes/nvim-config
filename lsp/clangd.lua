-- ~/.config/nvim/lsp/clangd.lua
-- CLANGD (C/C++ - PRIMARY FOCUS)
-- Best LSP for C++ templates, handles Trilinos/deal.II complexity
-- Installation: sudo pacman -S clang

return {
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
}
