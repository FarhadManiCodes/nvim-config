# AI code completion — design notes

**Status:** planned, **not implemented**. Branch: `feat/ai-completion` (rename pending).
Captures full context so work can resume after a conversation compaction.

**Decision:** cloud-only, **minuet-ai.nvim → Codestral**, manual, low-noise. Local
llama.cpp FIM (llama.vim) was evaluated and **dropped** — kept only as a documented
offline fallback in the appendix (§A).

---

## 0. Baseline (completed prerequisite)

Completion stack was migrated **nvim-cmp → blink.cmp** (on `main`, pushed).
- Engine: **blink.cmp** (`version="1.*"`, prebuilt Rust binary), eager at startup.
  Config: `lua/config/completion.lua`; spec: `lua/plugins/init.lua`.
- Sources: `lsp`, `buffer`, `path`, `cmdline` (Tab-triggered); snippets via `vim.snippet`.
- LSP caps: `require('blink.cmp').get_lsp_capabilities()` in `lua/config/lsp.lua`
  (clangd, basedpyright, bashls, yamlls, jsonls).
- Style = **low-noise**: manual/Tab-triggered cmdline, on-demand docs, ghost-text OFF.
- **Reserved keys**: `<C-h/j/k/l>` = vim-tmux-navigator; `<Tab>/<S-Tab>` = blink select +
  snippet jump; **`<leader>l…` = LaTeX/vimtex** (`<leader>ll` compile, etc.).
  AI completion is **insert-mode** so it uses **Alt keys** (`<A-…>`, none mapped today),
  not `<leader>` (a normal-mode concept). `<leader>a…` stays free for any future
  normal-mode AI commands.

## 1. Goal

Manual, on-demand AI **code completion**, low-noise, multi-line FIM, *better quality than
a local 7B*, for ≤ €10/month. Online use is the norm; code is OK to send to a cloud API.

## 2. Why cloud-only (the reasoning)

- **clangd / basedpyright already give cross-file symbol context** in blink (signatures,
  types). The AI layer's real job is **multi-line logic / boilerplate**, where raw model
  capability beats context breadth. A strong cloud model on the *current buffer* therefore
  beats a small local model with a cross-file ring buffer for the completions we want.
- User is **almost always online** and code is **fine to send** → the only real reasons to
  keep local (offline, privacy) don't apply. Cost difference is small (~€2–6/mo vs €0).
- Result: drop local, drop the second `llama-server`, drop the serving function. One
  plugin, one keybind, best quality. Local fallback documented in §A if needs change.

## 3. Plugin: minuet-ai.nvim → Codestral

- **minuet-ai.nvim** (Lua): manual, **inline virtual-text** FIM. Streaming.
- Provider: **`codestral`** (Mistral's code-specialist, purpose-built for FIM, 32K ctx).
- Context: current buffer (prefix/suffix FIM); `context_window` sizes how much is sent.
- Why Codestral over alternatives:
  - True **FIM endpoint** (most chat APIs — Claude/GPT/Gemini — don't expose FIM).
  - **EU company (Mistral, France) → best GDPR/data-residency** story vs DeepSeek (cheaper
    but Chinese provider, worse fit for research code).
  - Clear quality step up over local Qwen2.5-Coder-7B.

## 4. Cost (manual triggering keeps volume low)

Codestral API: **$0.30/M input, $0.90/M output**, 32K context.

| Usage | Requests/mo | Est. monthly cost |
|---|---|---|
| Moderate (~50 triggers/day) | ~1,100 | **~€2** |
| Heavy (~150 triggers/day) | ~3,300 | **~€6** |

Output (the costly side) is tiny for FIM (~150 tok). Both well under the €10 gate.

**Free path:** Mistral **Experiment plan** ≈ 1B tokens/mo at ~1 req/s, phone-verify, no
card. Manual triggering never bursts past 1 req/s → could run at **€0**. ⚠ **Caveat:** the
free tier likely **trains on your data** (verify ToS); the paid tier ($0.30/$0.90) has
proper data handling. Decide free-vs-paid at impl based on code sensitivity.

## 5. Keymaps — minuet native virtual-text engine (insert-mode, Alt keys)

minuet ships its **own ghost-text frontend** (no blink/cmp involved). In manual mode
(`auto_trigger_ft = {}`) the **`prev`/`next` keys are dual-purpose**: with no suggestion
showing they **invoke** a completion; with one showing they **cycle** candidates. There is
**no separate trigger key** — `<A-]>` both summons and cycles.

These actions all happen in **insert mode**, so `<leader>` (a normal-mode concept) is the
wrong pattern — minuet's **Alt-key defaults are correct**. No Alt maps exist in the config
(grep-verified), so the defaults are conflict-free:

| Action | Key |
|---|---|
| Invoke / cycle next | `<A-]>` |
| Cycle prev | `<A-[>` |
| Accept whole completion | `<A-A>` |
| Accept one line | `<A-a>` |
| Accept N lines (prompts for count) | `<A-z>` |
| Dismiss | `<A-e>` |

**Incremental acceptance (nice for FIM):** `accept_line` takes one line; `accept_n_lines`
prompts for a count (`<A-z>` `2` `<CR>` = accept 2 lines), so a long suggestion can be
pulled in at your own pace. `add_single_line_entry = true` (default) also injects
single-line *variants* into the candidate list, so cycling with `<A-]>` can surface a
one-liner version of a multi-line completion.

⚠ **Verify at impl:** Alt/Meta keys must survive **foot → tmux → nvim** (terminals can
swallow Meta). Test `<A-]>` actually reaches insert mode before finalizing these.

## 6. minuet wiring — sketch (verify API at impl)

```lua
{
  "milanglacier/minuet-ai.nvim",
  -- No plenary needed: minuet uses builtin vim.system now. Needs Neovim 0.10+ (we're 0.11+).
  event = "InsertEnter",
  config = function()
    require("minuet").setup({
      provider = "codestral",
      n_completions = 1,                 -- default 3; 1 = low-noise
      context_window = 16000,            -- default 16000; max context chars
      -- context_ratio = 0.75,           -- default; before/after-cursor split (3:1)
      request_timeout = 3,               -- default 3s; bump if cloud completions get cut
      -- throttle/debounce gate AUTO requests (1000/400ms default); irrelevant in manual
      provider_options = {
        codestral = {
          model = "codestral-latest",
          -- Dedicated Codestral FIM endpoint (has the free monthly tier);
          -- distinct from the general La Plateforme key at api.mistral.ai.
          end_point = "https://codestral.mistral.ai/v1/fim/completions",
          -- NEVER hardcode keys (repo rule). This is the env-var NAME minuet reads:
          api_key = "CODESTRAL_API_KEY",
          stream = true,                 -- tokens render as they arrive
          -- Codestral is a TEXT-completion (FIM) model, not chat: no system prompt.
          optional = { max_tokens = 256, stop = { "\n\n" } },  -- prevents timeouts
        },
      },
      virtualtext = {
        auto_trigger_ft = {},            -- MANUAL only (no auto-suggest)
        -- prev/next double as manual INVOKE when nothing is showing (see §5).
        keymap = {
          accept        = "<A-A>",       -- accept whole completion
          accept_line   = "<A-a>",       -- accept one line
          accept_n_lines = "<A-z>",      -- accept N lines (prompts)
          prev = "<A-[>", next = "<A-]>", dismiss = "<A-e>",
        },
        -- show_on_completion_menu = false is the DEFAULT → AI ghost text won't
        -- fight the blink menu; they stay separate. No need to set it.
      },
    })
  end,
}
```

**Verify at impl:** confirm `provider_options.codestral` field names against the installed
version; Alt keys survive foot→tmux→nvim; whether `request_timeout = 3s` is enough for
Codestral (raise if completions truncate); `max_tokens`/`stop` keys.

## 7. Secret handling — Lua loader, NOT zsh sourcing (IMPLEMENTED)

`lua/config/secrets.lua` parses `~/.config/secrets/*.env` (chmod 600, untracked) and
sets `vim.env`. `init.lua` (Phase 1) calls
`require("config.secrets").load("codestral.env")`, so minuet's
`api_key = "CODESTRAL_API_KEY"` resolves via `os.getenv` at request time.

**Why Lua, not `source` in zsh** (the safer choice for nvim):
- nvim has the key **however it was launched** (terminal, file manager, systemd) — no
  reliance on shell-env inheritance.
- the key stays in **nvim's process only**, never exported into every interactive shell
  and inherited by its children.

**Layout (`~/.config/secrets/`, 700; files 600, never tracked):**
- `codestral.env` — `export CODESTRAL_API_KEY=…` → loaded by nvim (above).
- `papis.env` — moved from `~/.config/papis/secrets`; consumed by the `pask` zsh function
  via a **function-scoped** `source` (keeps `OPENAI_API_BASE` for the local embedding
  server out of the global env). **Not** loaded by nvim.

**Validated:** with a real key in the file, nvim `os.getenv` = SET while the parent shell
stays unset — the key never enters the shell environment.

## 8. Open questions (decide at implementation)

1. Free Experiment tier (€0, trains on data) vs paid ($0.30/$0.90, private)? → depends on
   code sensitivity; can start free, switch by swapping the key.
2. `context_window` size vs latency (16k is a reasonable start).
3. ~~Manual trigger keybind~~ → **resolved**: minuet's `prev`/`next` (`<A-[>`/`<A-]>`)
   double as the manual invoke; native Alt keymaps, insert-mode (see §5).
4. `auto_trigger_ft` empty (pure manual) vs a tiny allowlist for a couple of fast filetypes.

## 9. Integration points (when implementing)

- ✅ `lua/config/secrets.lua` + `init.lua` call — secret loader (DONE, §7).
- ✅ `~/.config/secrets/{codestral.env,papis.env}` created (600); `zsh/functions/papis.zsh`
   repointed to `secrets/papis.env` (DONE, in the dotfiles parent repo).
- ✅ `nvim/lua/plugins/minuet.lua` — plugin spec (§6), installed; clean headless load,
   `provider=codestral`, `n_completions=1`, `auto_trigger_ft={}` (manual).
- `lua/config/keymaps.lua` — optionally document the minuet Alt-key bindings (insert-mode, §5).
- **Live test pending** (needs network + key): trigger `<A-]>` in insert mode, confirm
   ghost text appears and Alt keys survive foot→tmux→nvim.
- Shell: ensure `CODESTRAL_API_KEY` is exported from a gitignored secrets file.
- After wiring: `:checkhealth` + headless load (repo convention) + a live FIM test.
- **No serving function** (cloud) — `aicomplete.zsh` from the earlier local plan is dropped.

---

## Appendix A — local fallback (llama.vim), if offline/privacy ever needed

Evaluated and **not** chosen, but the cleanest local path if requirements change:

- **`ggml-org/llama.vim`** (llama.cpp authors): native `/infill`, lightweight, **ring-buffer
  cross-file context** (open + recently-edited files + yanks). Manual trigger, inline
  virtual text. Local-only.
- Serve with the existing **llama.cpp-vulkan** stack, a second `llama-server` on a new port
  (e.g. 8089), lazy start-on-demand mirroring `dotfiles/zsh/functions/papis.zsh` (`pask`):
  `llama-server --fim-qwen-7b-default -ngl 99 --port 8089`, `/health` gate.
- Model dial (64 GB RAM, Radeon 780M iGPU shares system RAM → compute-bound, not VRAM):

  | Tier | Model | Preset |
  |---|---|---|
  | fast | Qwen2.5-Coder-3B | `--fim-qwen-3b-default` |
  | balanced | **Qwen2.5-Coder-7B** | `--fim-qwen-7b-default` |
  | strong (FIM king) | Qwen2.5-Coder-32B | — |
  | MoE/agentic | Qwen3-Coder-30B-A3B | `--fim-qwen-30b-default` |

- Keymap: insert-mode trigger must avoid blink `<Tab>` and tmux `<C-h/j/k/l>`; use an
  Alt key (same rationale as §5 — `<leader>` is normal-mode, vimtex owns `<leader>ll`).
- Note: trigger mode (manual vs auto) does **not** change completion quality — same model,
  same FIM payload, same ring-buffer context. Manual just controls *when* it fires and
  avoids idle iGPU churn. (This corrected an earlier misconception.)
