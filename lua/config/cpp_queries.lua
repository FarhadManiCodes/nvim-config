-- Trim the C++ highlights query, which costs ~110 ms to compile in every nvim process
-- (tree-sitter analyses nested patterns against the 5.6 MB cpp grammar).
-- nvim-treesitter spells out `a::b::c::d::f()` as qualified_identifier chains up to
-- four deep. The four-deep patterns cost ~17 ms and matched nothing in 171 real C++
-- files or 60 libstdc++ headers; a three-deep chain still highlights.
-- A queries/cpp/highlights.scm override cannot do this: nvim appends any query file
-- with an `; inherits:` line, so upstream's would be loaded as well. Instead the
-- upstream text is read and patched in memory. If upstream stops matching, nothing
-- is replaced.
local M = {}
local MAX_DEPTH = 3
local done = false

-- Byte spans {first, last} of the top-level forms: `(...)` and `[...]`, with any
-- trailing captures on the closing line. Strings and comments are skipped.
local function forms(s)
  local out, i, n, depth, start = {}, 1, #s, 0, nil
  while i <= n do
    local c = s:sub(i, i)
    if c == ";" then
      i = s:find("\n", i, true) or n
    elseif c == '"' then
      i = i + 1
      while i <= n and s:sub(i, i) ~= '"' do
        if s:sub(i, i) == "\\" then i = i + 1 end
        i = i + 1
      end
    elseif c == "(" or c == "[" then
      if depth == 0 then start = i end
      depth = depth + 1
    elseif c == ")" or c == "]" then
      depth = depth - 1
      if depth == 0 and start then
        local e = s:find("\n", i, true) or n
        out[#out + 1] = { start, e }
        start, i = nil, e
      end
    end
    i = i + 1
  end
  return out
end

-- Call before the first cpp query is built (vim.treesitter.start on a cpp buffer).
function M.apply()
  if done then return end
  done = true
  local ok, files = pcall(vim.treesitter.query.get_files, "cpp", "highlights")
  if not ok or #files == 0 then return end

  local parts, dropped = {}, 0
  for _, file in ipairs(files) do
    local text = table.concat(vim.fn.readfile(file), "\n") .. "\n"
    local keep, pos = {}, 1
    for _, span in ipairs(forms(text)) do
      local form = text:sub(span[1], span[2])
      local _, depth = form:gsub("%(qualified_identifier", "")
      if depth > MAX_DEPTH and form:find("@function", 1, true) then
        keep[#keep + 1] = text:sub(pos, span[1] - 1)
        pos, dropped = span[2] + 1, dropped + 1
      end
    end
    keep[#keep + 1] = text:sub(pos)
    parts[#parts + 1] = table.concat(keep)
  end
  if dropped == 0 then return end

  local patched = table.concat(parts, "\n")
  -- parse() is memoized on (lang, text), so query.get() reuses this compile.
  if pcall(vim.treesitter.query.parse, "cpp", patched) then
    vim.treesitter.query.set("cpp", "highlights", patched)
  end
end

return M
