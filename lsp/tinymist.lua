-- ~/.config/nvim/lsp/tinymist.lua
-- TINYMIST (TYPST - DOCUMENTS)
-- One binary covering what vimtex+latexmk do for .tex: completion, hover,
-- goto-def, formatting (bundles typstyle) and the live preview server that
-- typst-preview.nvim drives. There is no separate compiler step.
-- Installation: sudo pacman -S tinymist  (official extra repo)

return {
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
}
