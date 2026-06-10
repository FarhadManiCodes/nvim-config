# Keymap Audit and Overlap Fixes
*(Date: June 10, 2026)*

This document summarizes the changes made to the Neovim configuration to resolve
keymap overlap warnings reported by `which-key.nvim`, fix a config validation
error, and keep the documentation in sync.

## 1. Resolved Keymap Overlaps

### A. Environment Variables (`vim-envx`)
- **Problem:** `<leader>ev` (Expand env variable) was a prefix of `<leader>evv`
  (Extract as env variable, visual mode), causing a which-key timeout/overlap.
- **Fix:** Changed "Extract as env variable" from `<leader>evv` to `<leader>ex`.
- **Files Modified:** `lua/plugins/init.lua`, `lua/config/keymaps.lua` (docs).

### B. Telescope Buffers vs Which-Key Group
- **Problem:** `which-key.lua` defined `<leader>b` as a prefix group ("Buffers"),
  but `init.lua` mapped `<leader>b` directly to `Telescope buffers`. A direct
  mapping cannot share a key with a group prefix.
- **Fix:** Changed the buffer finder from `<leader>b` to `<leader>bb`, nesting it
  under the Buffers group.
- **Files Modified:** `lua/plugins/init.lua`, `lua/config/keymaps.lua` (docs).

### C. LSP Diagnostics vs Which-Key "Env/Diag" Group
- **Problem:** `which-key.lua` grouped `<leader>e` as "Env/Diag", but `lsp.lua`
  mapped `<leader>e` directly to `vim.diagnostic.open_float` (same prefix-vs-group
  conflict as B).
- **Fix:** Moved the diagnostic float from `<leader>e` to `<leader>ed`, and the
  location-list mapping from `<leader>q` to `<leader>eq`.
- **Files Modified:** `lua/config/lsp.lua`, `lua/config/keymaps.lua` (docs),
  `CLAUDE.md` (LSP keymap table).

### D. `mini.bracketed` vs LSP Diagnostics
- **Problem:** Both `lsp.lua` and `mini.bracketed` mapped `[d` / `]d` for
  diagnostic jumping.
- **Fix:** Removed the manual `[d` / `]d` mappings from `lua/config/lsp.lua`;
  `mini.bracketed` (`diagnostic = { suffix = 'd' }`) handles them. Note this makes
  diagnostic navigation **global** (mini.bracketed) rather than buffer-local — it
  now works even in buffers without an attached LSP client.
- **Files Modified:** `lua/config/lsp.lua`.

## 2. Suppressed False Positives in Which-Key

### A. Operator-Pending Motions (`nvim-surround` & built-in comments)
- **Problem:** Standard Vim operator sequences where one is a prefix of another —
  `ys` / `yss` / `yS` / `ySS` (nvim-surround) and `gc` / `gcc` (built-in
  comments) — trigger which-key overlap warnings. This is expected Vim behavior
  (timeouts disambiguate them), not a real conflict.
- **Fix:** Registered these sequences in `lua/plugins/which-key.lua` with
  `hidden = true`. They keep working as normal motions; which-key stops flagging
  them and also stops listing them in the popup.
- **Files Modified:** `lua/plugins/which-key.lua`.

## 3. Which-Key Group Labels
- Added missing prefix group labels `"m"` (Markdown) and `"p"` (Papers / Papis)
  to `lua/plugins/which-key.lua` for correct popup display.

## 4. render-markdown Config Fix
- **Problem:** `lua/plugins/init.lua` set `latex.rendering_mode = "widget"` under
  the render-markdown `latex` table. That key does not exist in the plugin schema
  (valid keys: `enabled`, `render_modes`, `converter`, `highlight`, `position`,
  `top_pad`, `bottom_pad`), so `:checkhealth render-markdown` reported
  `latex.rendering_mode - expected: nil, got: string`.
- **Fix:** Removed the invalid line. LaTeX math rendering is unaffected — it is
  controlled by `enabled = true` and `converter`.
- **Files Modified:** `lua/plugins/init.lua`.

## 5. Cleanup
- Removed scratch debug files left in the repo root:
  `test_wk.lua`, `test_wk_health.lua`, `test_wk_health2.lua`, `test_wk_hidden.lua`.

---

## Verification

```bash
# which-key health only works once the plugin is loaded (it is lazy-loaded),
# so force-load it first — a bare headless run reports "no healthcheck found".
nvim --headless "+Lazy! load which-key.nvim" "+checkhealth which-key" \
     "+w! /tmp/wk.txt" +qa! && grep -E "overlap|duplicate|issues" /tmp/wk.txt
```

Result: the `<leader>`-prefixed conflicts addressed above (B, C) and the explicitly
hidden sequences (`ys`/`gc`) no longer warn, and there are **no duplicate
mappings**. The only which-key note is an informational "`mini.icons` is not
installed" (harmless — `nvim-web-devicons` is present).

> **IMPORTANT — headless checkhealth is NOT a reliable verification.** When run
> headless (even with `Lazy! load all`), buffer-local operator/motion mappings
> from nvim-surround, nvim-treesitter-textobjects, and nvim-autopairs are not set,
> so their overlaps are invisible and checkhealth falsely reports "no overlapping
> keymaps." In a real interactive session, `:checkhealth which-key` still shows a
> number of overlap **warnings** for these plugins:
> - `cs`/`ds` and variants — nvim-surround change/delete surrounding pair
> - `[m`/`]m`/`[M`/`]M` and their `…e` variants — treesitter-textobjects motions
> - `` `> `` and `]` — nvim-autopairs map keys
>
> These are **expected false positives**: standard Vim operator-pending/motion
> sequences where a short key is intentionally the prefix of a longer one (a
> timeout disambiguates them). which-key's own health output says not to treat
> them as a problem. They are NOT introduced by this audit and are harmless. They
> can be silenced with additional `hidden = true` registrations per mode, but that
> list is long and brittle across plugin updates, so it is intentionally left
> as-is.

`:checkhealth render-markdown` no longer reports a configuration error.

### Known upstream health errors (not config issues)
These come from the plugins' own health checks, which are on their latest
available commits; the plugins still load and function:
- **jupytext.nvim** — calls the removed `vim.health.report_start` and deprecated
  `vim.validate{<table>}` APIs (plugin last updated April 2024).
- **papis.nvim** — `health.lua:21` indexes a nil `data` field before DB init.
