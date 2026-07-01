local M = {}

local DIR  = "/tmp/nvim_md_preview"
local HTML = DIR .. "/index.html"
local PORT = 7654
-- "localhost" resolves to ::1 (IPv6) first on most systems, but python's
-- http.server only binds IPv4 (0.0.0.0) -- that IPv6-first attempt gets
-- refused before falling back, so use the IPv4 address directly.
local URL  = "http://127.0.0.1:" .. PORT

-- Injected into every compiled page: polls for content change, preserves scroll
local SCRIPT = [[<script>(function(){
  var prev='';
  function check(){
    fetch(location.href+'?t='+Date.now(),{cache:'no-store'})
      .then(function(r){return r.text();})
      .then(function(t){
        if(prev&&t!==prev){
          sessionStorage.setItem('sp',scrollX+','+scrollY);
          location.reload();
        }
        prev=t;
      }).catch(function(){});
    setTimeout(check,800);
  }
  var sp=sessionStorage.getItem('sp');
  if(sp){var a=sp.split(',');scrollTo(+a[0],+a[1]);sessionStorage.removeItem('sp');}
  check();
})();</script>]]

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
  content = content:gsub("%$%$(.-)%$%$", function(m) return stash("display", m) end)
  content = content:gsub("%$(.-)%$", function(m) return stash("inline", m) end)
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

-- Relative image/link paths in the source markdown are resolved against the
-- file's own directory, but the HTTP server root is the fixed tmp DIR. Symlink
-- the source directory in as "assets" and rewrite relative srcs to point there.
local function localize_assets(html, file)
  local src_dir = vim.fn.fnamemodify(file, ":h")
  vim.fn.system({ "ln", "-sfn", src_dir, DIR .. "/assets" })
  return (html:gsub('(<img[^>]-src=")([^"]+)(")', function(pre, src, post)
    if src:match("^%a[%w+.-]*://") or src:match("^/") or src:match("^data:") then
      return pre .. src .. post
    end
    return pre .. "assets/" .. src .. post
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
    .. "</head><body>\n" .. body .. "\n" .. KATEX_RENDER .. "\n" .. SCRIPT .. "</body></html>"
  local f = io.open(HTML, "w")
  if f then f:write(html); f:close() end
end

local function server_running()
  return vim.fn.system("ss -tlnp 2>/dev/null"):find(tostring(PORT)) ~= nil
end

local function ensure_server()
  if server_running() then return end
  vim.fn.system(
    "python3 -m http.server " .. PORT .. " --directory " .. DIR .. " >/dev/null 2>&1 &"
  )
  -- python's startup + module import can take longer than a couple hundred ms
  -- under load; poll inside a single shell call (up to 10s) rather than a Lua
  -- loop of separate system() calls, whose per-call overhead eats into the wait.
  vim.fn.system(
    "for i in $(seq 1 100); do ss -tln 2>/dev/null | grep -q ':" .. PORT
    .. " ' && exit 0; sleep 0.1; done; exit 1"
  )
end

local function vimb_open()
  return vim.fn.system("pgrep -a vimb 2>/dev/null"):find(tostring(PORT)) ~= nil
end

function M.preview(file)
  compile(file)
  ensure_server()
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
  if not vimb_open() then return end
  compile(file)
  -- JS in the page detects the content change and reloads in place
end

function M.close()
  vim.fn.system("pkill -f 'vimb.*" .. PORT .. "' 2>/dev/null")
  vim.fn.system("pkill -f 'http.server " .. PORT .. "' 2>/dev/null")
end

return M
