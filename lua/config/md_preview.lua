local M = {}

-- Private runtime directory, not predictable /tmp: the HTTP server follows
-- symlinks to local image directories. Keep its root private and bind loopback.
local DIR  = vim.fn.stdpath("run") .. "/nvim_md_preview"
local PORT = 7654
-- Match the server's IPv4 loopback binding.
local URL  = "http://127.0.0.1:" .. PORT

-- Protect fenced and inline code before extracting math (committed parser).
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

-- Inline math needs non-space edges and cannot cross a newline.
-- Rejected openers stay literal so later dollar signs can still start math.
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

-- Extract display math before inline math so $ delimiters stay together.
local function extract_math(content)
  local blocks = {}
  local function stash(kind, text)
    table.insert(blocks, { kind = kind, text = text })
    return "MATHTOKEN" .. #blocks .. "END"
  end
  -- Hide escaped dollars before matching, then restore them inside/outside math.
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

-- Render only extracted spans: KaTeX auto-render would reinterpret literal dollars.
local function restore_math(html, blocks)
  return (html:gsub("MATHTOKEN(%d+)END", function(idx)
    local b = blocks[tonumber(idx)]
    if not b then return "" end
    return string.format(
      '<span class="katex-src" data-display="%s">%s</span>',
      b.kind == "display" and "1" or "0",
      escape_html(b.text)
    )
  end))
end

local KATEX_VERSION = "0.17.0"
local KATEX_ASSETS = "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@"
  .. KATEX_VERSION .. "/dist/katex.min.css\">"
-- No auto-render extension: render exactly the marked spans. textContent gives
-- the decoded LaTeX back (the browser undoes escape_html when parsing), and
-- throwOnError=false keeps one malformed equation from blanking the page.
local KATEX_RENDER = "<script src=\"https://cdn.jsdelivr.net/npm/katex@" .. KATEX_VERSION
  .. "/dist/katex.min.js\"></script>\n"
  .. "<script>document.querySelectorAll('span.katex-src').forEach(function(el){"
  .. "try{katex.render(el.textContent,el,"
  .. "{displayMode:el.dataset.display==='1',throwOnError:false});}"
  .. "catch(e){el.classList.add('katex-failed');}});</script>"

-- Punctuation replacement made /a-b and /a/b collide. Hashing the complete
-- path keeps URLs distinct and bounded even for deeply nested source files.
local function dir_alias(dir)
  return vim.fn.sha256(dir)
end

-- Each document has a stable page; multiple previews must not overwrite it.
local function doc_page(file)
  return dir_alias(vim.fn.fnamemodify(file, ":p")) .. ".html"
end

local function doc_url(file)
  return URL .. "/" .. doc_page(file)
end

-- Decode cmark's HTML attribute escapes once, before interpreting URL syntax.
-- Otherwise the # in &#x27; becomes a fragment instead of an apostrophe.
local function decode_attribute(value)
  local named = { amp = "&", quot = '"', apos = "'", lt = "<", gt = ">" }
  return (value:gsub("&([#%w]+);", function(entity)
    local code = tonumber(entity:match("^#(%d+)$"))
      or tonumber(entity:match("^#[xX](%x+)$") or "", 16)
    if code and code > 0 and code <= 0x10FFFF and not (code >= 0xD800 and code <= 0xDFFF) then
      return vim.fn.nr2char(code)
    end
    return named[entity]
  end))
end

local function localize_assets(html, file)
  local src_dir = vim.fn.fnamemodify(file, ":h")
  local aliased = {}
  -- Fetch images afresh on each compile, even when the path is unchanged.
  local cache_bust = tostring(vim.uv.hrtime())
  return (html:gsub('(<img[^>]-src=")([^"]+)(")', function(pre, src, post)
    -- Leave remote, embedded, and protocol-relative images alone.
    if src:match("^%a[%w+.-]*://") or src:match("^data:") or src:match("^//") then
      return pre .. src .. post
    end
    -- Decode HTML first, split URL components, then percent-decode the path.
    -- Encoded #/? belong to filenames; literal #/? delimit URL components.
    local path, suffix = decode_attribute(src):match("^([^?#]*)(.*)$")
    path = vim.uri_decode(path)
    local abs_src = path:match("^/") and path or (src_dir .. "/" .. path)
    local dir = vim.fn.fnamemodify(abs_src, ":h")
    local base = vim.fn.fnamemodify(abs_src, ":t")
    local alias = aliased[dir]
    if not alias then
      alias = dir_alias(dir)
      vim.fn.system({ "ln", "-sfn", dir, DIR .. "/" .. alias })
      if vim.v.shell_error ~= 0 then error("Cannot link image directory: " .. dir) end
      aliased[dir] = alias
    end
    local query, fragment = suffix:match("^([^#]*)(.*)$")
    local bust = (query == "" and "?" or "&") .. "v=" .. cache_bust
    local url = alias .. "/" .. vim.uri_encode(base, "rfc2396") .. query .. bust .. fragment
    return pre .. escape_html(url):gsub('"', "&quot;") .. post
  end))
end

-- Renders `file` to its own page under DIR and returns that path.
local function compile(file)
  vim.fn.mkdir(DIR, "p")
  local content, math_blocks = extract_math(table.concat(vim.fn.readfile(file), "\n"))
  -- Stdin avoids scratch Markdown files and races between simultaneous renders.
  local body = vim.fn.system({ "cmark-gfm", "--unsafe", "-e", "table",
    "-e", "strikethrough", "-e", "tasklist" }, content)
  if vim.v.shell_error ~= 0 then error("cmark-gfm failed: " .. body) end
  body = restore_math(body, math_blocks)
  body = localize_assets(body, file)
  body = body:gsub("(<table[%s>])", '<div class="table-scroll">%1'):gsub("</table>", "</table></div>")
  local css = "<style>"
    .. "body{max-width:80ch;margin:2rem auto;padding:0 1rem;line-height:1.6;font-family:sans-serif;"
    .. "background:#eeeeee;color:#444}"
    .. "a{color:#0087af}"
    .. "h1,h2,h3,h4,h5,h6{color:#875f00}"
    .. "code{background:#d0d0d0;color:#005f87;padding:.1em .3em;border-radius:3px}"
    .. "pre{background:#d0d0d0;padding:1em;overflow-x:auto;border-radius:4px}"
    .. "pre code{background:none;padding:0}"
    .. ".table-scroll{overflow-x:auto;margin:1.5em 0}"
    .. "table{border-collapse:collapse;width:100%;font-size:.95em}"
    .. "th,td{border:1px solid #aaa;padding:.6em .85em;vertical-align:top}"
    .. "th{background:#ddd;font-weight:600}th:not([align]){text-align:left}"
    .. "tbody tr:nth-child(even){background:#e5e5e5}"
    .. "img{max-width:100%;height:auto}"
    .. "blockquote{border-left:3px solid #878787;margin-left:0;padding-left:1em;color:#878787}"
    .. "@media(prefers-color-scheme:dark){"
    .. "body{background:#282c34;color:#abb2bf}"
    .. "a{color:#61afef}"
    .. "h1,h2,h3,h4,h5,h6{color:#e5c07b}"
    .. "code{background:#2c323c;color:#98c379}"
    .. "pre{background:#2c323c}"
    .. "th,td{border-color:#505866}th{background:#343b47}"
    .. "tbody tr:nth-child(even){background:#2c323c}"
    .. "blockquote{border-color:#5c6370;color:#5c6370}}"
    .. "</style>"
  local title = vim.fn.fnamemodify(file, ":t")
  local html = "<!DOCTYPE html><html><head><meta charset=utf-8><meta name='color-scheme' content='light dark'>"
    .. "<title>" .. escape_html(title) .. "</title>"
    .. css .. KATEX_ASSETS
    .. "</head><body>\n" .. body .. "\n" .. KATEX_RENDER .. "</body></html>"
  local out = DIR .. "/" .. doc_page(file)
  -- Publish atomically in the same directory; failed conversion/writes leave
  -- the previous page intact, and readers never see a partially written page.
  local tmp = out .. "." .. vim.fn.getpid() .. ".tmp"
  local ok, err = pcall(function()
    assert(vim.fn.writefile(vim.split(html, "\n", { plain = true }), tmp, "b") == 0, "Cannot write preview")
    assert(vim.uv.fs_rename(tmp, out))
  end)
  if not ok then vim.fn.delete(tmp); error(err) end
  return out
end

-- Match the exact port, not a longer port or a process ID.
local function server_running()
  return vim.fn.system("ss -tln 2>/dev/null"):find(":" .. PORT .. "%s") ~= nil
end

local function ensure_server()
  if server_running() then return true end
  -- Loopback only: the root includes symlinked local image directories.
  vim.fn.system(
    "python3 -m http.server " .. PORT .. " --bind 127.0.0.1 --directory " .. vim.fn.shellescape(DIR) .. " >/dev/null 2>&1 &"
  )
  -- Allow up to ten seconds for server startup.
  vim.fn.system(
    "for i in $(seq 1 100); do ss -tln 2>/dev/null | grep -q ':" .. PORT
    .. " ' && exit 0; sleep 0.1; done; exit 1"
  )
  return vim.v.shell_error == 0
end

-- One browser window per document URL.
local function vimb_showing(url)
  return vim.fn.system("pgrep -a vimb 2>/dev/null"):find(url, 1, true) ~= nil
end

-- Avoid subprocesses on saves/exits when this instance has no previews.
local previewed = {}

local function render(file)
  local ok, result = pcall(compile, file)
  if not ok then vim.notify("Markdown preview: " .. tostring(result), vim.log.levels.ERROR) end
  return ok
end

function M.preview(file)
  file = vim.fn.fnamemodify(file, ":p")
  if not render(file) then return end
  if not ensure_server() then
    vim.notify("Markdown preview server failed to start", vim.log.levels.ERROR)
    return
  end
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
  -- Other Neovim instances drive their own refreshes.
  file = vim.fn.fnamemodify(file, ":p")
  if not previewed[file] then return end
  render(file)
  -- rewrites this document's own page; reload it in vimb (`r`) to see the change
end

function M.close()
  -- Shared server lifecycle: this still closes previews from other instances.
  -- Runs from VimLeavePre on EVERY exit, so return before forking anything
  -- unless this instance actually has a preview to tear down.
  if next(previewed) == nil then return end
  previewed = {}
  vim.fn.system("pkill -f 'vimb.*" .. PORT .. "' 2>/dev/null")
  vim.fn.system("pkill -f 'http.server " .. PORT .. "' 2>/dev/null")
end

-- Test seam for ~/learning/playground/md-preview-tests; unused by the UI.
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
