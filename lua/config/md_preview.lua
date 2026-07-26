local M = {}

local DIR  = "/tmp/nvim_md_preview"
local PORT = 7654
-- "localhost" resolves to ::1 (IPv6) first on most systems, but python's
-- http.server only binds IPv4 (0.0.0.0) -- that IPv6-first attempt gets
-- refused before falling back, so use the IPv4 address directly.
local URL  = "http://127.0.0.1:" .. PORT

-- cmark-gfm treats `_`, `*`, and leading `- ` as markdown syntax, which corrupts
-- LaTeX (e.g. `h_{k-1}` or a `$$` block whose second line starts with `- \overline`).
-- Pull math spans out before conversion, then splice the raw LaTeX back into the
-- HTML afterwards so KaTeX (loaded client-side) renders it untouched by cmark.
-- A "$" inside code is not a math delimiter: `echo $HOME`, `$PATH`, a Makefile
-- `$(CC)`, a printf "$%d". The span patterns below cannot tell the difference,
-- so such a dollar pairs with the next real one -- typically the "$" that OPENS
-- a genuine equation further down -- and everything between the two is swallowed
-- into one bogus span. A bash block plus an equation later in the same note lost
-- its closing fence, an intervening heading and a whole paragraph that way.
--
-- Same remedy as the escaped-"\$" case below: hide those dollars behind a
-- sentinel so they cannot pair, then restore them afterwards. Fence tracking
-- uses the same toggle rule as markdown_toc() in config/autocmds.lua.
local CODE = "\2"

local function protect_code_dollars(content)
  local lines = vim.split(content, "\n", { plain = true })
  local in_fence = false
  for i, line in ipairs(lines) do
    if line:match("^%s*```") or line:match("^%s*~~~") then
      in_fence = not in_fence
      lines[i] = line:gsub("%$", CODE)
    elseif in_fence then
      lines[i] = line:gsub("%$", CODE)
    else
      -- Inline spans: `code`, ``code with ` inside``. The %1 back-reference
      -- makes the closing run match the opening run's length.
      lines[i] = line:gsub("(`+)(.-)%1", function(ticks, inner)
        return ticks .. inner:gsub("%$", CODE) .. ticks
      end)
    end
  end
  return table.concat(lines, "\n")
end

-- Inline "$...$" spans, using pandoc's tex_math_dollars rule: an OPENING "$"
-- must be followed immediately by a non-space, and a CLOSING "$" preceded
-- immediately by a non-space. Without that rule a stray dollar in prose --
--   "A lone $ sign ... then real maths $y = mx + c$."
-- -- pairs with the "$" that opens the genuine equation, and the sentence
-- between them renders as italic maths. The same rule keeps unescaped prices
-- ("$100 and $250") intact, since "$ " and " $" can be neither end of a span.
--
-- Written as an explicit scan rather than gsub: a rejected candidate must leave
-- its "$" available as a later opener, which gsub cannot express (it resumes
-- after the whole attempted match and would lose the following span).
-- A span may not cross a newline; runaway multi-line pairing is the failure this
-- whole function exists to prevent, and display maths uses "$$" anyway.
local function extract_inline_math(content, stash)
  local out, i, n = {}, 1, #content
  while i <= n do
    local s = content:find("%$", i)
    if not s then
      out[#out + 1] = content:sub(i)
      break
    end
    local after = content:sub(s + 1, s + 1)
    if after == "" or after:match("%s") then
      out[#out + 1] = content:sub(i, s)   -- not an opener; keep the "$" literal
      i = s + 1
    else
      local close, j = nil, s + 1
      while true do
        local e = content:find("%$", j)
        if not e or content:sub(s + 1, e - 1):find("\n") then break end
        if not content:sub(e - 1, e - 1):match("%s") then close = e break end
        j = e + 1
      end
      if close then
        out[#out + 1] = content:sub(i, s - 1)
        out[#out + 1] = stash("inline", content:sub(s + 1, close - 1))
        i = close + 1
      else
        out[#out + 1] = content:sub(i, s)  -- unmatched; keep it literal
        i = s + 1
      end
    end
  end
  return table.concat(out)
end

-- cmark-gfm treats `_`, `*`, and leading `- ` as markdown syntax, which corrupts
-- LaTeX (e.g. `h_{k-1}` or a `$$` block whose second line starts with `- \overline`).
-- Pull math spans out before conversion, then splice the raw LaTeX back into the
-- HTML afterwards so KaTeX (loaded client-side) renders it untouched by cmark.
local function extract_math(content)
  local blocks = {}
  local function stash(kind, text)
    table.insert(blocks, { kind = kind, text = text })
    return "MATHTOKEN" .. #blocks .. "END"
  end
  -- an escaped "\$" is a literal dollar sign inside LaTeX (e.g. a footnote
  -- mark), not a span delimiter -- but the naive pattern below can't tell the
  -- difference. Left alone, it pairs with the wrong "$" and desyncs every
  -- span after it, swallowing arbitrarily large stretches of the document
  -- (headings included) into one bogus math block. Hide it first, restore after.
  local ESC = "\1"
  content = protect_code_dollars(content)
  content = content:gsub("\\%$", ESC)
  content = content:gsub("%$%$(.-)%$%$", function(m) return stash("display", m) end)
  content = extract_inline_math(content, stash)
  for _, b in ipairs(blocks) do
    b.text = b.text:gsub(ESC, "\\$"):gsub(CODE, "$")
  end
  content = content:gsub(ESC, "\\$"):gsub(CODE, "$")
  return content, blocks
end

local function escape_html(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function restore_math(html, blocks)
  return (html:gsub("MATHTOKEN(%d+)END", function(idx)
    local b = blocks[tonumber(idx)]
    if not b then return "" end
    local escaped = escape_html(b.text)
    if b.kind == "display" then
      return "$$" .. escaped .. "$$"
    end
    return "$" .. escaped .. "$"
  end))
end

local KATEX_VERSION = "0.17.0"
local KATEX_ASSETS = "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@"
  .. KATEX_VERSION .. "/dist/katex.min.css\">"
local KATEX_RENDER = "<script src=\"https://cdn.jsdelivr.net/npm/katex@" .. KATEX_VERSION
  .. "/dist/katex.min.js\"></script>\n"
  .. "<script src=\"https://cdn.jsdelivr.net/npm/katex@" .. KATEX_VERSION
  .. "/dist/contrib/auto-render.min.js\"></script>\n"
  .. "<script>renderMathInElement(document.body,{delimiters:["
  .. "{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false}]});</script>"

-- Image/link paths in the source markdown -- relative (resolved against the
-- file's own directory) or absolute filesystem paths -- don't exist under the
-- HTTP server root (the fixed tmp DIR). Symlink whichever directories are
-- referenced and rewrite srcs to point there.
--
-- The alias for a directory must be a pure function of that directory's own
-- path (never a counter or a fixed name like "assets" reused across different
-- previews). python's http.server sends Last-Modified but no Cache-Control or
-- ETag, so the browser applies heuristic caching per URL; if two different
-- papers each have e.g. "figures/page_6_fig_0.png" and both get aliased to
-- the same URL across previews, the browser can serve the wrong paper's
-- cached bytes under that recycled URL. A stable, directory-derived alias
-- means two different directories never share a URL, so this can't happen.
local function dir_alias(dir)
  return (dir:gsub("[^%w]+", "_"))
end

-- One HTML page per source document, named from its absolute path, rather than
-- a single shared index.html. With one page, previewing a second .md overwrote
-- the first: the server was already up and a vimb was already running, so no
-- new window opened and the existing one kept showing stale content until you
-- reloaded it -- at which point the first document was gone. Per-document pages
-- give each file its own URL, so several previews coexist, each reloads to its
-- own content, and the URL stays stable across previews (bookmarkable).
local function doc_page(file)
  return dir_alias(vim.fn.fnamemodify(file, ":p")) .. ".html"
end

local function doc_url(file)
  return URL .. "/" .. doc_page(file)
end

local function localize_assets(html, file)
  local src_dir = vim.fn.fnamemodify(file, ":h")
  local aliased = {}
  -- Preview content is live (re-compiled on every save); images must never
  -- be served from the browser's cache, only ever fetched fresh from disk.
  -- A per-compile query string forces that regardless of what caching
  -- headers python's http.server does or doesn't send.
  local cache_bust = tostring(vim.uv.hrtime())
  return (html:gsub('(<img[^>]-src=")([^"]+)(")', function(pre, src, post)
    -- Leave anything that is not a local filesystem path alone. The "^//" arm
    -- covers protocol-relative URLs (//cdn.example.com/a.png): they match
    -- neither the scheme nor the data: pattern, so without it they were
    -- resolved against the document's directory and symlinked as local files.
    if src:match("^%a[%w+.-]*://") or src:match("^data:") or src:match("^//") then
      return pre .. src .. post
    end
    local abs_src = src:match("^/") and src or (src_dir .. "/" .. src)
    local dir = vim.fn.fnamemodify(abs_src, ":h")
    local base = vim.fn.fnamemodify(abs_src, ":t")
    local alias = aliased[dir]
    if not alias then
      alias = dir_alias(dir)
      vim.fn.system({ "ln", "-sfn", dir, DIR .. "/" .. alias })
      aliased[dir] = alias
    end
    return pre .. alias .. "/" .. base .. "?v=" .. cache_bust .. post
  end))
end

-- Renders `file` to its own page under DIR and returns that path.
local function compile(file)
  vim.fn.system("mkdir -p " .. DIR)
  local content, math_blocks = extract_math(table.concat(vim.fn.readfile(file), "\n"))
  -- Per-document scratch name: two nvim instances previewing different files
  -- would otherwise race on a single shared _src.md.
  local tmp = DIR .. "/_src_" .. doc_page(file) .. ".md"
  vim.fn.writefile(vim.split(content, "\n"), tmp)
  local body = vim.fn.system(
    "cmark-gfm --unsafe -e table -e strikethrough -e tasklist "
    .. vim.fn.shellescape(tmp)
  )
  body = restore_math(body, math_blocks)
  body = localize_assets(body, file)
  local css = "<style>"
    .. "body{max-width:80ch;margin:2rem auto;padding:0 1rem;line-height:1.6;font-family:sans-serif;"
    .. "background:#eeeeee;color:#444}"
    .. "a{color:#0087af}"
    .. "h1,h2,h3,h4,h5,h6{color:#875f00}"
    .. "code{background:#d0d0d0;color:#005f87;padding:.1em .3em;border-radius:3px}"
    .. "pre{background:#d0d0d0;padding:1em;overflow-x:auto;border-radius:4px}"
    .. "pre code{background:none;padding:0}"
    .. "blockquote{border-left:3px solid #878787;margin-left:0;padding-left:1em;color:#878787}"
    .. "@media(prefers-color-scheme:dark){"
    .. "body{background:#282c34;color:#abb2bf}"
    .. "a{color:#61afef}"
    .. "h1,h2,h3,h4,h5,h6{color:#e5c07b}"
    .. "code{background:#2c323c;color:#98c379}"
    .. "pre{background:#2c323c}"
    .. "blockquote{border-color:#5c6370;color:#5c6370}}"
    .. "</style>"
  local title = vim.fn.fnamemodify(file, ":t")
  local html = "<!DOCTYPE html><html><head><meta charset=utf-8><meta name='color-scheme' content='light dark'>"
    .. "<title>" .. escape_html(title) .. "</title>"
    .. css .. KATEX_ASSETS
    .. "</head><body>\n" .. body .. "\n" .. KATEX_RENDER .. "</body></html>"
  local out = DIR .. "/" .. doc_page(file)
  local f = io.open(out, "w")
  if f then f:write(html); f:close() end
  return out
end

-- Anchor on ":<port>" followed by whitespace, and drop `-p`.
-- A bare :find("7654") searched the WHOLE ss output as a substring, so it also
-- matched a listener on 17654/27654/… and — because -p appends
-- `users:(("firefox",pid=7654,…))` — any process whose PID happened to be 7654.
-- A false positive made ensure_server() skip starting the server, leaving the
-- browser on a connection-refused blank page with nothing to explain why.
-- The colon rules out PIDs (preceded by `=`) and longer ports (":17654" has no
-- ":7654" substring). Same shape as the readiness poll below, which was already
-- correct. -p is dropped because the process info was never used.
local function server_running()
  return vim.fn.system("ss -tln 2>/dev/null"):find(":" .. PORT .. "%s") ~= nil
end

local function ensure_server()
  if server_running() then return end
  -- --bind 127.0.0.1 is REQUIRED, not cosmetic: python's http.server defaults to
  -- binding all interfaces, which would publish DIR to the whole LAN with no
  -- auth. DIR is not just the rendered HTML — localize_assets() symlinks every
  -- directory referenced by an image into it, and http.server follows symlinks,
  -- so the default bind would expose arbitrary parts of the filesystem.
  vim.fn.system(
    "python3 -m http.server " .. PORT .. " --bind 127.0.0.1 --directory " .. DIR .. " >/dev/null 2>&1 &"
  )
  -- python's startup + module import can take longer than a couple hundred ms
  -- under load; poll inside a single shell call (up to 10s) rather than a Lua
  -- loop of separate system() calls, whose per-call overhead eats into the wait.
  vim.fn.system(
    "for i in $(seq 1 100); do ss -tln 2>/dev/null | grep -q ':" .. PORT
    .. " ' && exit 0; sleep 0.1; done; exit 1"
  )
end

-- Is a vimb already showing THIS document's page? Matched as a plain
-- (non-pattern) substring of the pgrep output. Per-document now: previously it
-- asked the broader question "is any vimb showing the preview server", which is
-- why a second document never got a window of its own.
local function vimb_showing(url)
  return vim.fn.system("pgrep -a vimb 2>/dev/null"):find(url, 1, true) ~= nil
end

-- Documents THIS nvim has previewed, as a set. Gates the two hot paths below so
-- they cost nothing in the common case of never previewing at all. Measured:
-- pgrep ~30ms and the two pkills ~53ms, which the autocmds in autocmds.lua
-- Section 14 were paying on every .md write and every nvim exit regardless.
local previewed = {}

function M.preview(file)
  file = vim.fn.fnamemodify(file, ":p")
  compile(file)
  ensure_server()
  previewed[file] = true
  -- Each document has its own URL, so a second .md opens its own vimb window
  -- instead of silently overwriting the first one's page.
  local url = doc_url(file)
  if not vimb_showing(url) then
    vim.fn.jobstart(
      { "env",
        "WEBKIT_DISABLE_DMABUF_RENDERER=1",
        "GSK_RENDERER=ngl",
        "GDK_BACKEND=wayland",
        "vimb", "--no-maximize", "-i", url },
      { detach = true }
    )
  end
end

function M.refresh(file)
  -- Cheap in-process check FIRST: without it every .md write forked pgrep
  -- (~30ms) purely to discover there was nothing to refresh. A preview started
  -- by a different nvim instance is deliberately not adopted here — that
  -- instance drives its own refreshes.
  file = vim.fn.fnamemodify(file, ":p")
  if not previewed[file] then return end
  compile(file)
  -- rewrites this document's own page; reload it in vimb (`r`) to see the change
end

function M.close()
  -- Runs from VimLeavePre on EVERY exit, so return before forking anything
  -- unless this instance actually has a preview to tear down.
  if next(previewed) == nil then return end
  previewed = {}
  vim.fn.system("pkill -f 'vimb.*" .. PORT .. "' 2>/dev/null")
  vim.fn.system("pkill -f 'http.server " .. PORT .. "' 2>/dev/null")
end

-- -----------------------------------------------------------------------------
-- TEST SEAM
-- -----------------------------------------------------------------------------
-- The transformations above are hand-written string parsing, and this file's
-- history is mostly fixes to them (escaped dollars in extract_math, absolute
-- paths in localize_assets, image cache aliasing) — each found in real use
-- rather than by inspection. They are exposed here so the harness in
-- ~/learning/playground/md-preview-tests can assert on them directly.
--
-- Not part of the module's interface: nothing in this config calls M._internal,
-- and the preview path does not go through it.
M._internal = {
  extract_math    = extract_math,
  restore_math    = restore_math,
  escape_html     = escape_html,
  dir_alias       = dir_alias,
  localize_assets = localize_assets,
  compile         = compile,   -- returns the path it wrote
  doc_page        = doc_page,
  doc_url         = doc_url,
  DIR             = DIR,
}

return M
