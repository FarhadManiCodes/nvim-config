-- ~/.config/nvim/lua/config/markdown.lua
-- Markdown editing helpers: heading TOC and $$ math-block collapse.
--
-- Only the implementations live here. The buffer-local <leader>lt / <leader>lm
-- maps and the global :MathCollapse command are registered in autocmds.lua
-- ("Math block collapse", "Markdown preview + keymaps") and require this module
-- on first use. The preview itself is a separate module, config/md_preview.lua.

local M = {}

-- render-markdown.nvim's latex handler only conceals the raw $$...$$ source
-- when the equation's treesitter node spans a single buffer line
-- (lua/render-markdown/handler/latex.lua: position="center" -- the only mode
-- that actually calls the conceal function -- gets silently overridden to
-- "above" whenever node:height() > 1, and "above" never conceals at all).
-- A $$ / content / $$ block written across 3 lines therefore always shows
-- both the raw source and the render side by side; collapsing it onto one
-- line ($$ content $$) is the only way to get concealment for that equation.
--
-- Delegates to mathunicode-collapse-blocks (~/projects/mathunicode) rather
-- than reimplementing the block-finding regex here -- same "one shared
-- backend" reasoning as pointing the latex converter at mathunicode itself:
-- the batch-fix script over the whole papis library uses the identical
-- Python implementation, so there's exactly one place this logic lives.
function M.collapse_math()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local input = table.concat(lines, "\n")
  local result = vim.system({ "mathunicode-collapse-blocks" }, { stdin = input, text = true }):wait()

  if result.code ~= 0 or not result.stdout then
    vim.notify(
      "mathunicode-collapse-blocks failed: " .. (result.stderr or "unknown error"),
      vim.log.levels.ERROR
    )
    return
  end

  local output = result.stdout:gsub("\n$", "")
  if output == input then
    vim.notify("No multi-line math blocks found", vim.log.levels.INFO)
    return
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, "\n", { plain = true }))
  vim.notify("Collapsed multi-line math block(s) to single-line form", vim.log.levels.INFO)
end

-- Build a Table of Contents in the location list from markdown headings.
-- Scans the live buffer (works on unsaved changes). Handles, mirroring
-- vim-markdown's s:GetHeaderList:
--   * ATX headings (# .. ######), with trailing hashes stripped (## X ## -> X)
--   * Setext headings (a text line underlined with === for H1, --- for H2)
--   * Fenced code blocks (``` / ~~~): headings inside them are ignored
--   * YAML frontmatter (--- ... --- at the very top): skipped, so its closing
--     --- is not mistaken for a setext H2 underline
function M.toc()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local items = {}
  local in_fence = false
  local in_frontmatter = false
  local prev_title, prev_lnum  -- the previous line, when it could be a setext title

  -- A setext underline only promotes a PARAGRAPH to a heading. Treating every
  -- non-blank line as a candidate meant a `---` thematic break after a table or
  -- a list turned the preceding row/item into a TOC entry — e.g. a table whose
  -- last row is `| a | b |` showed up as a heading called "| a | b |".
  -- Structural lines are therefore excluded here.
  local function can_be_setext_title(line)
    if not line:match("^%S") then return false end       -- blank / indented
    if line:match("^[-=_*]+%s*$") then return false end  -- thematic break or underline
    if line:match("^[-*+]%s") then return false end      -- bullet list item
    if line:match("^%d+[.)]%s") then return false end    -- ordered list item
    if line:match("^|") then return false end            -- table row
    if line:match("^>") then return false end            -- block quote
    return true
  end

  for i, line in ipairs(lines) do
    if i == 1 and line == "---" then
      -- Opening frontmatter delimiter on the first line.
      in_frontmatter = true
      prev_title = nil
    elseif in_frontmatter then
      if line == "---" then in_frontmatter = false end
      prev_title = nil
    elseif line:match("^%s*```") or line:match("^%s*~~~") then
      in_fence = not in_fence
      prev_title = nil
    elseif in_fence then
      prev_title = nil
    else
      local hashes, text = line:match("^(#+)%s+(.*)")
      if hashes and #hashes <= 6 then
        text = text:gsub("%s*#*%s*$", "")  -- strip optional closing hashes
        table.insert(items, {
          bufnr = bufnr, lnum = i, col = 1,
          text = string.rep("  ", #hashes - 1) .. text,
        })
        prev_title = nil
      elseif prev_title and line:match("^=+%s*$") then
        table.insert(items, { bufnr = bufnr, lnum = prev_lnum, col = 1, text = prev_title })
        prev_title = nil
      elseif prev_title and line:match("^%-+%s*$") then
        table.insert(items, { bufnr = bufnr, lnum = prev_lnum, col = 1, text = "  " .. prev_title })
        prev_title = nil
      elseif can_be_setext_title(line) then
        -- A paragraph line: a candidate setext title for the next line.
        prev_title, prev_lnum = line, i
      else
        prev_title = nil
      end
    end
  end

  if vim.tbl_isempty(items) then
    vim.notify("No markdown headings found", vim.log.levels.INFO)
    return
  end
  vim.fn.setloclist(0, {}, " ", { title = "Markdown TOC", items = items })
  vim.cmd("lopen")
end

return M
