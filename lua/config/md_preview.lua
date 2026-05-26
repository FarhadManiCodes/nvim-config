local M = {}

local DIR  = "/tmp/nvim_md_preview"
local HTML = DIR .. "/index.html"
local PORT = 7654
local URL  = "http://localhost:" .. PORT

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

local function compile(file)
  vim.fn.system("mkdir -p " .. DIR)
  local body = vim.fn.system(
    "cmark-gfm --unsafe -e table -e strikethrough -e tasklist "
    .. vim.fn.shellescape(file)
  )
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
  local html = "<!DOCTYPE html><html><head><meta charset=utf-8><meta name='color-scheme' content='light dark'>" .. css
    .. "</head><body>\n" .. body .. "\n" .. SCRIPT .. "</body></html>"
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
  for _ = 1, 20 do
    if server_running() then return end
    vim.fn.system("sleep 0.1")
  end
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
