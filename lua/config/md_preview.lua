local M = {}

local DIR  = "/tmp/nvim_md_preview"
local HTML = DIR .. "/index.html"
local PORT = 7654
-- "localhost" resolves to ::1 (IPv6) first on most systems, but python's
-- http.server only binds IPv4 (0.0.0.0) -- that IPv6-first attempt gets
-- refused before falling back, so use the IPv4 address directly.
local URL  = "http://127.0.0.1:" .. PORT

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
  content = content:gsub("\\%$", ESC)
  content = content:gsub("%$%$(.-)%$%$", function(m) return stash("display", m) end)
  content = content:gsub("%$(.-)%$", function(m) return stash("inline", m) end)
  for _, b in ipairs(blocks) do
    b.text = b.text:gsub(ESC, "\\$")
  end
  content = content:gsub(ESC, "\\$")
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

local function localize_assets(html, file)
  local src_dir = vim.fn.fnamemodify(file, ":h")
  local aliased = {}
  -- Preview content is live (re-compiled on every save); images must never
  -- be served from the browser's cache, only ever fetched fresh from disk.
  -- A per-compile query string forces that regardless of what caching
  -- headers python's http.server does or doesn't send.
  local cache_bust = tostring(vim.uv.hrtime())
  return (html:gsub('(<img[^>]-src=")([^"]+)(")', function(pre, src, post)
    if src:match("^%a[%w+.-]*://") or src:match("^data:") then
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

local function compile(file)
  vim.fn.system("mkdir -p " .. DIR)
  local content, math_blocks = extract_math(table.concat(vim.fn.readfile(file), "\n"))
  local tmp = DIR .. "/_src.md"
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
  local html = "<!DOCTYPE html><html><head><meta charset=utf-8><meta name='color-scheme' content='light dark'>"
    .. css .. KATEX_ASSETS
    .. "</head><body>\n" .. body .. "\n" .. KATEX_RENDER .. "</body></html>"
  local f = io.open(HTML, "w")
  if f then f:write(html); f:close() end
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

-- Match the full URL we launched vimb with, as a plain (non-pattern) substring,
-- rather than the bare port digits anywhere in the pgrep output.
local function vimb_open()
  return vim.fn.system("pgrep -a vimb 2>/dev/null"):find(URL, 1, true) ~= nil
end

-- Did THIS nvim ever start a preview? Gates the two hot paths below so they
-- cost nothing in the overwhelmingly common case of never previewing at all.
-- Measured: pgrep ~30ms and the two pkills ~53ms, which the autocmds in
-- autocmds.lua Section 14 were paying on every single .md write and on every
-- nvim exit respectively — regardless of whether a preview existed.
local started = false

function M.preview(file)
  compile(file)
  ensure_server()
  started = true
  if not vimb_open() then
    vim.fn.jobstart(
      { "env",
        "WEBKIT_DISABLE_DMABUF_RENDERER=1",
        "GSK_RENDERER=ngl",
        "GDK_BACKEND=wayland",
        "vimb", "--no-maximize", "-i", URL },
      { detach = true }
    )
  end
end

function M.refresh(file)
  -- Cheap in-process check FIRST: without it every .md write forked pgrep
  -- (~30ms) purely to discover there was nothing to refresh. A preview started
  -- by a different nvim instance is deliberately not adopted here — that
  -- instance drives its own refreshes.
  if not started then return end
  if not vimb_open() then return end
  compile(file)
  -- recompiles index.html on disk; reload manually in vimb (`r`) to see it
end

function M.close()
  -- Runs from VimLeavePre on EVERY exit, so return before forking anything
  -- unless this instance actually has a preview to tear down.
  if not started then return end
  started = false
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
  extract_math   = extract_math,
  restore_math   = restore_math,
  escape_html    = escape_html,
  dir_alias      = dir_alias,
  localize_assets = localize_assets,
  compile        = compile,
  HTML           = HTML,
  DIR            = DIR,
}

return M
