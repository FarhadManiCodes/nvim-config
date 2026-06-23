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
  `<leader>a…` is **free** (grep-verified, no conflicts) → use for the AI namespace.

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

⚠ **Verify at impl:** Alt/Meta keys must survive **foot → tmux → nvim** (terminals can
swallow Meta). Test `<A-]>` actually reaches insert mode before finalizing these.

## 6. minuet wiring — sketch (verify API at impl)

```lua
{
  "milanglacier/minuet-ai.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  config = function()
    require("minuet").setup({
      provider = "codestral",
      n_completions = 1,                 -- one suggestion, low-noise
      context_window = 16000,            -- raise toward buffer size; vs latency
      provider_options = {
        codestral = {
          model = "codestral-latest",
          -- Dedicated Codestral FIM endpoint (has the free monthly tier);
          -- distinct from the general La Plateforme key at api.mistral.ai.
          end_point = "https://codestral.mistral.ai/v1/fim/completions",
          -- NEVER hardcode keys (repo rule). This is the env-var NAME minuet reads:
          api_key = "CODESTRAL_API_KEY",
          stream = true,
          optional = { max_tokens = 256, stop = { "\n\n" } },
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
        -- show_on_completion_menu = false (default) keeps AI ghost text from
        -- fighting the blink menu — they stay separate. Confirm at impl.
      },
    })
  end,
}
```

**Verify at impl:** confirm `provider_options.codestral` field names against the installed
version; that `api_key` takes the env **var name** (it does per docs); Alt keys survive
foot→tmux→nvim; whether `show_on_completion_menu` needs setting; `max_tokens`/`stop` keys.

## 7. Secret handling

- Put the key in the shell env, **not** in the repo: `export CODESTRAL_API_KEY=...`
  in a non-tracked file (e.g. `~/.config/zsh/secrets.zsh`, gitignored — mirror how DB
  creds are handled with `os.getenv` in `lua/plugins/init.lua`).
- minuet reads it via env; nothing secret lands in dotfiles.

## 8. Open questions (decide at implementation)

1. Free Experiment tier (€0, trains on data) vs paid ($0.30/$0.90, private)? → depends on
   code sensitivity; can start free, switch by swapping the key.
2. `context_window` size vs latency (16k is a reasonable start).
3. ~~Manual trigger keybind~~ → **resolved**: minuet's `prev`/`next` (`<A-[>`/`<A-]>`)
   double as the manual invoke; native Alt keymaps, insert-mode (see §5).
4. `auto_trigger_ft` empty (pure manual) vs a tiny allowlist for a couple of fast filetypes.

## 9. Integration points (when implementing)

- `nvim/lua/plugins/minuet.lua` — new plugin spec (§6).
- `lua/config/keymaps.lua` — document the minuet Alt-key bindings (insert-mode, §5).
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

- Keymap: trigger must avoid vimtex `<leader>ll`; use the `<leader>a…` namespace.
- Note: trigger mode (manual vs auto) does **not** change completion quality — same model,
  same FIM payload, same ring-buffer context. Manual just controls *when* it fires and
  avoids idle iGPU churn. (This corrected an earlier misconception.)
