-- ~/.config/nvim/lsp/neocmake.lua
-- NEOCMAKELSP (CMAKE)
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

return {
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
}
