# TODO — Neovim config

Items needing a decision or a change, newest first. Each carries the evidence that
produced it so it can be re-checked rather than re-argued. Accepted behaviour belongs in
`docs/architecture.md`; finished work belongs in git history, not here.

---

## Plugin pin audit — 2026-09-20

Measured on branch `audit-2026-09-plugin-pins`. Plugin clones' remote refs were last
fetched 2026-09-19 22:33, so "behind" counts are as of then, not live. Re-run `:Lazy check`
before acting on any number here.

**Scope: all 37 installed plugins.** 37 directories under `lazy/`, 37 entries in
`lazy-lock.json`, no discrepancy. (`lua/plugins/*.lua` declares 41 specs — the extra four
are the same plugins re-declared as dependencies.)

Two independent problems, which need separating:

**(a) Behind upstream — 6 of 37.** Only one is genuinely stale.

| Plugin | Pinned at | Behind | Newest release | Verdict |
|--------|-----------|--------|----------------|---------|
| telescope.nvim | `0.1.8` (2024-05-24) | 476 | `v0.2.2` (2026-02-16) | **stale, and broken — item 1** |
| blink.cmp | `v1.10.2` | 239 | `v1.10.2` | at latest release |
| nvim-treesitter-textobjects | `main` | 40 | — | `origin/HEAD` points at `master`; count is an artifact |
| nvim-treesitter | `main` | 2 | `v0.10.0` (on `master`) | deliberate — item 4 |
| nvim-surround | `v4.0.5` | 1 | `v4.0.5` | at latest release |
| mini.bracketed | `v0.18.0` | 1 | `v0.18.0` | at latest release |

The other 31 are at zero commits behind.

**(b) Up to date, but upstream is dormant — 6 of 37.** A different risk, and one that
"behind" counts cannot show: these are fully current, because nothing has happened
upstream in over a year. See item 6.

---

### 1. Bump telescope off `0.1.8` — it is actively broken

**Status:** not started. This is the substantive item; the rest are small.

**The bug.** Telescope 0.1.8 calls nvim-treesitter's *archived master-branch* API. This
config runs the `main`-branch rewrite, where those modules do not exist. Confirmed by
running a real picker:

```
vim.schedule callback: telescope/previewers/utils.lua:135:
    attempt to call field 'ft_to_lang' (a nil value)
  ts_highlighter      utils.lua:135
  highlighter         utils.lua:119
  fn                  buffer_previewer.lua:247
```

- `nvim-treesitter.locals` and `nvim-treesitter.configs` both fail to load — verified
  directly with `pcall(require, ...)`; neither file exists under
  `lazy/nvim-treesitter/lua/nvim-treesitter/`.
- `nvim-treesitter.parsers` loads but has no `ft_to_lang` on `main`.
- The call at `utils.lua:119` has no `pcall`, so the regex fallback at `:122` is never
  reached. Every preview of a file with a parser throws — `<C-p>`, `<leader>rg`,
  `<leader>fo`.
- `:Telescope treesitter` is dead outright: `builtin/__files.lua:380,389` bare-`require`
  the two missing modules.

**Why the bump fixes it.** v0.2.0 refactored treesitter "to rely purely on Nvim core API,
eliminating nvim-treesitter as a requirement".

**Compatibility, checked:**
- v0.2.0 needs Nvim ≥ 0.10.4; this machine runs 0.12.5. Clear.
- Breaking changes between `0.1.8` and `v0.2.2`, none of which look harmful here: Nvim 0.9
  dropped; `winblend` falls back to `vim.o.winblend` (telescope's is not set here);
  quickfix entry-maker width (cosmetic); new `preview.highlight_limit`, default 1 MB —
  arguably aligned with the large-file guards. The "resolve 1 as a percentage" change was
  reverted upstream and does not apply.

**Still to check before merging — do not skip:**
- [ ] `telescope-fzf-native` (`version = "1.*"`, `core.lua:155` loads it) against v0.2.2
- [ ] **`telescope-dap` (`dap.lua:92-94`, powers `<leader>dl`) against v0.2.2 — the real
      risk in this item.** Its upstream has been dormant 22 months (last commit
      2024-11-04, item 6), so it was written against the 0.1.x extension API and nobody
      will fix it if v0.2.x moved. If it breaks, the fallbacks are
      `require("dap").list_breakpoints()` into the quickfix list, or dropping
      `<leader>dl`. Neither blocks the bump — DAP Phase 1 does not depend on telescope.
- [ ] `papis.nvim`'s telescope provider still resolves (`<leader>pp`)
- [ ] the in-picker mappings at `core.lua:65+` (`<C-j>`/`<C-k>`/`<C-q>`/`<Esc>`/`q`)

**Verification:** previews highlight again on a `.py`/`.c` buffer; `:Telescope treesitter`
runs; `<leader>dl`, `<leader>pp` and all eleven pickers in `core.lua:21-44` still work;
`:checkhealth telescope`. Interactive — headless cannot see a preview window.

---

### 2. `tag =` is the reason it froze — change the pin style, not just the version

**Status:** not started. Do this *with* item 1, or item 1 will simply freeze again at
v0.2.2.

This is the "don't stay on an old thing forever" mechanism. Four pin styles are in use here
and only one of them can never move:

| Style | Behaviour on `:Lazy update` | Used by |
|-------|------------------------------|---------|
| `tag = "0.1.8"` | **never moves** — a literal tag is frozen forever | telescope only |
| `version = "*"` | follows the newest stable semver release | nvim-surround, mini.bracketed |
| `version = "1.*"` | follows the newest 1.x release; deliberate major pin | blink.cmp, typst-preview |
| no pin | follows the default branch | everything else |

The two `version = "*"` plugins are both sitting on their newest release with no
intervention — that is the mechanism working. Telescope is the only `tag =` in the repo and
the only plugin that fell 476 commits behind. That is not a coincidence.

**Proposal:** `core.lua:12` becomes `version = "*"` rather than `tag = "v0.2.2"`.

- [ ] Confirm lazy.nvim's semver handling copes with telescope's mixed tag spelling — old
      tags are bare (`0.1.8`), new ones are prefixed (`v0.1.9`, `v0.2.2`). If it does not,
      fall back to `tag = "v0.2.2"` and add a dated note here to revisit.
- [ ] Decide whether `version = "*"` is too loose for a plugin this central — `version =
      "0.2.*"` would take patches automatically but hold the minor.

**Know what `version = "*"` buys, measured.** Tracking stable is not tracking current — it
is only as fresh as the project's release cadence. Gap between each version-pinned
plugin's newest release and its upstream HEAD, 2026-09-20:

| Plugin | Newest release | Upstream HEAD | Gap |
|--------|----------------|---------------|-----|
| telescope.nvim | v0.2.2 · 2026-02-16 | 2026-08-17 | **181 days — 6 months + 1 day** |
| blink.cmp | v1.10.2 · 2026-04-04 | 2026-09-10 | 159 days |
| nvim-surround | v4.0.5 · 2026-05-02 | 2026-06-08 | 37 days |
| mini.bracketed | v0.18.0 · 2026-06-19 | 2026-07-07 | 18 days |
| typst-preview.nvim | v1.5.0 · 2026-07-14 | 2026-07-14 | 0 — the tag is HEAD |

Telescope is the only one past six months, and only just. So `version = "*"` there means
accepting roughly a half-year lag behind development — which is what "stable" is *for*,
and is still infinitely better than the 27-month lag `tag =` produced. Worth choosing
knowingly rather than discovering later.

Do **not** compute this across all plugins with "newest tag vs HEAD" — it is mostly noise.
Several projects use a moving `stable`/`release` tag (oil, which-key, lazy, gitsigns,
twilight) or a compat tag that is not a release at all (lualine's `compat-nvim-0.5`,
nvim-web-devicons' `nerd-v3.2-compat`, vim-tmux-navigator's `v1.0` from 2015). The measure
only means something for plugins actually pinned by `version =`.

---

### 3. Make staleness visible on a schedule

**Status:** not started. Process item, no code.

`:Lazy check` already fetches and reports (refs here were fetched 2026-09-19, so it does
get run). The gap is that a `tag =` pin **never appears as updatable**, so the one plugin
that most needed attention was the one the existing routine could not surface. Fixing item
2 closes most of this.

- [ ] Decide on a cadence — quarterly is probably right for a config this stable.
- [ ] Decide what the check actually is. `:Lazy check` covers commits-behind but not
      "a new release tag exists that my pin style cannot reach". The audit that produced
      this file compared `git describe --tags` against `git tag --sort=-creatordate | head -1`
      per plugin, which is what caught telescope; worth keeping as a snippet.
- [ ] Never run `:Lazy sync` to validate unrelated edits (`AGENTS.md`). A pin bump is an
      intended plugin change and should move only the plugin in question, not the whole
      lockfile.

---

### 4. Recorded so it is not re-audited

No action. Findings that looked like problems and are not:

- **blink.cmp, nvim-surround, mini.bracketed** — each `git describe --tags` is exactly its
  newest tag. Their commits-behind counts are unreleased upstream `main`. Nothing to do.
- **nvim-treesitter** — tracks `branch = "main"` deliberately; master is archived and
  0.12-incompatible. The `v0.10.0` tag is on the old branch and is not a target. `git
  describe` reads `v0.9.3-859-g...` for the same reason. Working as intended.
- **jupytext.nvim** — genuinely unmaintained: local HEAD equals `origin/HEAD`, both
  2024-04-05, zero commits behind. Upstream has not moved, so there is nothing to bump to.
  Already recorded in `docs/keymap-audit-changes.md:117`.
- **oil.nvim** — the five deprecated actions were fixed on `main` (commits `31fdfd1`,
  `470002e`). Not outstanding.

---

### 5. Consider telescope alternatives — only if item 1 goes badly

**Status:** not started, low priority. Recorded because the question was asked.

Telescope went quiet for ~18 months (2024-05 → 2025-11) and the ecosystem moved: LazyVim
switched to fzf-lua, and snacks.picker gained ground through 2025-26. Telescope has since
resumed releasing (four tags between 2025-11 and 2026-02, plus commits to 2026-08-17), so
the premise for switching has largely gone.

If it is ever revisited: `papis.nvim` takes `"auto"|"snacks"|"telescope"` so it would
follow a move to snacks; `telescope-dap` would not, and `<leader>dl` would need
hand-rolling. `telescope-fzf-native` already provides the speed that motivates most
fzf-lua migrations.

---

### 6. Six plugins are current only because upstream stopped

**Status:** not started. No urgency — all six work today. This is a watch-list, not a
defect list.

`:Lazy check` reports these as perfectly up to date, which is true and misleading: they are
at zero commits behind because nothing has been committed upstream in over a year. A
commits-behind check can never surface this, so it needs its own look.

| Plugin | Last upstream commit | Dormant | Exposure |
|--------|---------------------|---------|----------|
| jupytext.nvim | 2024-04-05 | 29 mo | Already known and already shimmed — `lua/jupytext/health.lua` shadows its broken healthcheck and the `setup()` call is wrapped. See `docs/keymap-audit-changes.md:117`. |
| rainbow_csv | 2024-07-04 | 26 mo | `<leader>cc/cs/cq`. Vimscript, few Neovim API surfaces, low risk. |
| telescope-dap.nvim | 2024-11-04 | 22 mo | **Blocks nothing but complicates item 1** — see that item. |
| sqlite.lua | 2025-03-14 | 18 mo | Dependency of papis.nvim, not used directly. Native binding, so an Nvim API break is unlikely but an ABI/soname change is not. |
| vim-envx | 2025-06-09 | 15 mo | `<leader>ev/eev/ex`. Small and Vimscript. |
| nvim-dap-virtual-text | 2025-05-25 | 15 mo | DAP Phase 1. Lua against the nvim-dap API, so the most likely of these to break on an nvim-dap update. |

**The lesson telescope already taught, in a second form.** Telescope broke because 0.1.8
called an API that moved underneath it. These six are the same shape: none of them will
adapt to a Neovim or dependency change, because nobody is maintaining them. The failure
will look like telescope's did — an uncaught `attempt to call field ... (a nil value)` from
inside the plugin, not a warning.

- [ ] Decide which of the six matter enough to have a replacement identified *before*
      they break, rather than after. `nvim-dap-virtual-text` and `telescope-dap` are the
      two with live Lua API surfaces.
- [ ] Add the dormancy check to whatever routine item 3 settles on. The probe used here:
      for each plugin, `git rev-list --count HEAD..origin/HEAD` equal to zero **and**
      `git log -1 --format=%cs origin/HEAD` older than twelve months.
- [ ] Do not act on this preemptively. All six work; replacing a working plugin because
      its commit feed is quiet is how a config acquires churn it did not need.
