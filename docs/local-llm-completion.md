# Local-LLM code completion — design notes

**Status:** planned, **not implemented**. Branch: `feat/minuet-ai-completion`.
Captures full context so work can resume after a conversation compaction.
**Two plugins are kept as options** (see §3): `llama.vim` for local FIM, `minuet-ai`
for provider flexibility (e.g. Codestral / cloud). They can coexist.

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

## 1. Goal

Manual, on-demand AI **code completion** from a **local llama.cpp** model, low-noise,
whole-file (ideally cross-file) aware, upgradeable to a bigger model later. Keep a path
open to **Codestral / cloud** providers.

## 2. Local stack to reuse

- **llama.cpp-vulkan** (custom AUR PKGBUILD the user maintains; Vulkan GPU). Binaries:
  `llama-server`, `llama-cli`. HW: AMD Zen4, **64 GB RAM**, Vulkan offload.
- Serving pattern in `dotfiles/zsh/functions/papis.zsh` (`pask`): lazy-starts
  `llama-server -hf <model> -ngl 99 --port 8088`, OpenAI-compatible API, `/health` check,
  start-on-demand. A code model = a **second `llama-server` on a new port** (e.g. 8089).

## 3. The two options (keep both)

### Option A — `llama.vim` (ggml-org)  ·  local FIM, best context
- Made by the llama.cpp authors; native `/infill`; lightweight; efficient on modest HW.
- **Ring-buffer context**: pulls chunks from **open + recently-edited files + yanked
  text** → *cross-file aware* (the main reason to prefer it). Smart context reuse.
- Manual trigger: disable auto-FIM, use `keymap_fim_trigger` (default `<leader>llf` —
  **must remap**, collides with vimtex `<leader>ll`). Also instruction-edit `<leader>lli`.
- Standalone **virtual-text** UI (not a blink source); accept via Tab/S-Tab.
- Vimscript config; Neovim-compatible (lazy.nvim examples in its README).
- Local-only (no cloud).

### Option B — `minuet-ai.nvim`  ·  provider flexibility (Codestral/cloud) + blink
- Lua; integrates as a **blink source** *or* virtual-text. Streaming.
- Providers: llama.cpp, Ollama, OpenAI, Claude, Gemini, **Codestral**, any OpenAI-compatible.
- Context: **current buffer only** (prefix/suffix FIM) — no cross-file ring buffer.
- Manual trigger supported; render as on-demand virtual text (chosen) to stay low-noise.

### Recommended split
- **Local daily driver / cross-file FIM → llama.vim** (best fit for the llama.cpp stack).
- **Codestral or any cloud/alt provider → minuet-ai** (point it at the provider).
- They can **coexist**: llama.vim for local FIM, minuet invoked when you want Codestral.
  Keep both manual + virtual-text so they don't fight; bind to distinct keys.

## 4. How FIM context works ("does it read the whole file?")

FIM = fill-in-the-middle: sends `<prefix>` (before cursor) + `<suffix>` (after cursor)
wrapped in the model's FIM tokens; model fills the middle.
- **llama.vim**: current file **+ ring buffer of other open/edited files** → broadest context.
- **minuet**: current buffer only; `context_window` (chars) + `context_ratio` size it —
  raise to send the whole buffer. Ceiling = the model's context length (Qwen-Coder ≈ 32k–256k).
- Whole-**repo** semantic context (RAG) is OUT of scope for both.

## 5. Models (for 64 GB)

| Tier | Model | Notes |
|---|---|---|
| fastest (<8GB) | **Qwen2.5-Coder-1.5B** | preset `--fim-qwen-1.5b-default`; near-instant, weaker quality |
| fast (<16GB) | **Qwen2.5-Coder-3B** | preset `--fim-qwen-3b-default`; snappy, low GPU, good quality — best "fast" pick |
| starter/balanced | **Qwen2.5-Coder-7B** | preset `--fim-qwen-7b-default`; proven FIM, still fast on 64GB+Vulkan |
| advanced (FIM-proven) | **Qwen2.5-Coder-32B** | the "FIM king" for inline completion |
| advanced (MoE/agentic) | **Qwen3-Coder-30B-A3B** | preset `--fim-qwen-30b-default`; ~30B/3B-active MoE, newer, more agentic; verify FIM quality |
| cloud (via minuet) | **Codestral** | requires API key; minuet `codestral` provider |

Version note: the **30B is Qwen3** (new gen, MoE); the **7B/3B/1.5B presets are Qwen2.5**
(Qwen3 has no small coder sizes). llama.cpp `--fim-qwen-*-default` flags auto-pull each.

## 6. llama.vim wiring (Option A) — sketch (verify API at impl)

```lua
{
  "ggml-org/llama.vim",
  init = function()
    vim.g.llama_config = {
      endpoint = "http://127.0.0.1:8089/infill",
      auto_fim = false,                 -- MANUAL only (low-noise)
      -- remap to avoid vimtex <leader>ll :
      keymap_trigger = "<A-y>",         -- verify exact option name
      -- ring/context options: n_prefix / n_suffix / ring_n_chunks (verify names)
    }
  end,
}
```
Verify: exact `vim.g.llama_config` keys (endpoint vs endpoint_fim, trigger keymap name,
ring-context knobs); confirm `/infill` is what your llama-server exposes.

## 7. minuet wiring (Option B) — sketch (verify API at impl)

```lua
{
  "milanglacier/minuet-ai.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("minuet").setup({
      provider = "openai_fim_compatible",          -- local llama.cpp
      n_completions = 1,
      context_window = 16000,
      provider_options = {
        openai_fim_compatible = {
          api_key = "TERM", name = "llamacpp",
          end_point = "http://127.0.0.1:8089/v1/completions",
          model = "qwen2.5-coder",
          optional = { max_tokens = 256 },
        },
        -- later: codestral = { api_key = "CODESTRAL_API_KEY", model = "codestral-latest" }
      },
      virtualtext = {
        auto_trigger_ft = {},                        -- manual only
        keymap = { accept = "<A-a>", accept_line = "<A-l>", dismiss = "<A-e>" },
      },
    })
  end,
}
```
Verify: `provider_options` field names, manual virtual-text trigger fn, `/v1/completions`
vs `/infill`, keymaps avoid blink `<Tab>` and tmux `<C-h/j/k/l>`.

## 8. Serving (dotfiles) — `zsh/functions/aicomplete.zsh`, mirror `papis.zsh`

```sh
AICODE_PORT=8089
# preset auto-pulls the model; pick per §5:
nohup llama-server --fim-qwen-7b-default -ngl 99 --port "$AICODE_PORT" >"$LOG" 2>&1 &!
# health: curl -sf http://127.0.0.1:8089/health
```
Lazy start-on-demand + `/health` wait, same shape as `_papis_ask_ensure_embed`.

## 9. Open questions (decide at implementation)

1. Run **one** plugin or **both** (llama.vim local + minuet for Codestral)?
2. Final local model: Qwen2.5-Coder-32B (FIM-proven) vs Qwen3-Coder-30B-A3B (MoE)?
3. Manual trigger keybinding(s) — avoid `<leader>l…`, `<Tab>`, `<C-h/j/k/l>` (proposed `<A-y>`).
4. `context_window` (minuet) / ring-chunk count (llama.vim) vs latency.

## 10. Integration points (when implementing)

- `nvim/lua/plugins/llama-vim.lua` and/or `nvim/lua/plugins/minuet.lua` — new specs
- `nvim/lua/config/completion.lua` — only if exposing minuet as a blink source too
- `dotfiles/zsh/functions/aicomplete.zsh` — serving function (mirror `papis.zsh`)
- After wiring: `:checkhealth` + headless load (repo convention)
