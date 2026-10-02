-- Startup-cost trims for Tree-sitter queries. A query is compiled from scratch in every
-- nvim process, and on a big grammar even a query with no patterns costs ~1.2 ms per MB
-- of parser (sql 13 ms, zsh 10 ms, cpp 5 ms), so work that cannot show up is cut here.
-- A queries/<lang>/*.scm override cannot do it: nvim appends any query file with an
-- `; inherits:` line, so upstream's would be loaded as well. Instead the upstream text
-- is read and patched in memory. If nothing matches, nothing is replaced.
--
--   injections  patterns that inject a language whose parser is not installed are
--               dropped, and a query left empty is not compiled at all (sql, zsh,
--               bash, cpp, typescript ...). Same injected trees on 1282 real files.
--               The check runs every start, so installing a parser (comment, doxygen)
--               brings its patterns back at the next start.
--   cpp         upstream's four-deep qualified_identifier function patterns
--               (a::b::c::d::f()): ~17 ms, no capture changed on 171 real C++ files or
--               60 libstdc++ headers; names up to three deep still highlight.
local M = {}
local MAX_DEPTH = 3
local done, have = {}, {}

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

local function installed(lang)
  lang = vim.treesitter.language.get_lang(lang) or lang
  if have[lang] == nil then
    have[lang] = #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", false) > 0
  end
  return have[lang]
end

-- Upstream text of lang's query with the forms `drop` rejects removed, then how many
-- were removed and kept. Files are joined as nvim joins them (inherited ones first).
local function strip(lang, name, drop)
  local parts, dropped, kept = {}, 0, 0
  for _, file in ipairs(vim.treesitter.query.get_files(lang, name)) do
    local text = table.concat(vim.fn.readfile(file), "\n") .. "\n"
    local out, pos = {}, 1
    for _, span in ipairs(forms(text)) do
      if drop(text:sub(span[1], span[2])) then
        out[#out + 1] = text:sub(pos, span[1] - 1)
        pos, dropped = span[2] + 1, dropped + 1
      else
        kept = kept + 1
      end
    end
    out[#out + 1] = text:sub(pos)
    parts[#parts + 1] = table.concat(out)
  end
  return table.concat(parts, "\n"), dropped, kept
end

-- Patch lang's query. An empty replacement makes query.get() return nil, so nothing is
-- compiled; otherwise parse() (memoized on lang+text) is reused by query.get().
local function replace(lang, name, drop)
  local text, dropped, kept = strip(lang, name, drop)
  if dropped == 0 then return end
  if kept == 0 then
    text = ""
  elseif not pcall(vim.treesitter.query.parse, lang, text) then
    return
  end
  vim.treesitter.query.set(lang, name, text)
end

-- Static `injection.language` targets only: a pattern that takes its language from a
-- capture (@injection.language) or injects into itself is kept.
local function dead_injection(form)
  if form:find("@injection.language", 1, true) or form:find("injection.self", 1, true)
      or form:find("injection.parent", 1, true) then
    return false
  end
  local found = false
  for target in form:gmatch('injection%.language%s+"([^"]+)"') do
    found = true
    if installed(target) then return false end
  end
  return found
end

local function deep_function(form)
  local _, depth = form:gsub("%(qualified_identifier", "")
  return depth > MAX_DEPTH and form:find("@function", 1, true) ~= nil
end

-- Call before the language's first query is built (vim.treesitter.start on its buffer).
-- Queries already built or set by anyone else are replaced; that is what query.set does.
function M.apply(lang)
  if not lang or done[lang] then return end
  done[lang] = true
  if not installed(lang) then return end
  replace(lang, "injections", dead_injection)
  if lang == "cpp" then replace(lang, "highlights", deep_function) end
end

return M
