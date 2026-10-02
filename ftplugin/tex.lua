-- tex is vimtex's, not Tree-sitter's (see config/treesitter.lua). Folds in particular:
-- options.lua sets the global foldexpr to the treesitter one, and vimtex's ftplugin
-- turns on foldmethod=expr before it sets its own foldexpr, so nvim evaluated the
-- treesitter expression once on every .tex file. That loaded the latex parser,
-- parsed the buffer and compiled its folds and injections queries (~22 ms) only to
-- throw the result away. This file runs before vimtex's ftplugin (the config
-- directory is first on the runtimepath), so the window never sees the global one.
-- foldtext is set too: config/treesitter.lua resets both when the filetype leaves tex,
-- and vimtex does not re-run its fold setup for a buffer it has already initialised.
vim.opt_local.foldexpr = "vimtex#fold#level(v:lnum)"
vim.opt_local.foldtext = "vimtex#fold#text()"
