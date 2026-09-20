# AI code completion — configuration and design notes

**Reviewed 2026-09-20** against the current configuration and installed Minuet
commit `3b0a4c5f97b7124d94302c608fbe01c0270d4fbe` (matches `lazy-lock.json`).
The setup is implemented: **minuet-ai.nvim → Codestral FIM**, cloud-only,
manual, using Minuet's separate virtual-text frontend.

The original implementation record reports a successful live test through
foot → tmux → Neovim, with three FIM jobs. That is historical evidence, not a
fresh API, billing or terminal test. See §7 for this review's verification scope.

## 1. Baseline and rationale

Blink handles ordinary completion; Minuet supplies on-demand multi-line code.

- **blink.cmp** is eager, constrained to `version = "1.*"`, with configuration in
  `lua/config/completion.lua` and its declaration in `lua/plugins/core.lua`.
- Default insert sources are LSP, buffer and path, with filetype overrides.
  Command-line completion is Tab-triggered; snippets expand through `vim.snippet`.
  Insert-mode docs are on demand and Blink ghost text is disabled.
- `lua/config/lsp.lua` supplies Blink capabilities through `vim.lsp.config('*', …)`
  to the native server configurations.
- Minuet is not a Blink source here. Its `InsertEnter` loading installs the manual
  mappings; entering insert mode or typing does not itself send an AI request.
- `<Tab>/<S-Tab>` retain Blink selection/snippet navigation. The existing navigation
  and document mappings stay separate; `<leader>l…` covers LaTeX, Typst and Markdown.
  Alt keys were chosen for AI's insert-mode actions. Leader mappings are technically
  possible in insert mode too; this is a configuration convention, not a Neovim rule.

The original goal was online, manual FIM completion within a €10/month budget,
with code permitted to go to a cloud provider. Cloud hosting avoids maintaining
an additional local model server. Better multi-line suggestions than a local 7B
model were the motivation, not a benchmark established by this repository.
LSP symbol knowledge feeds Blink; it is not passed to Minuet as project context.

## 2. Effective configuration

The source of truth is [`lua/plugins/minuet.lua`](../lua/plugins/minuet.lua).
This repository requires Neovim **0.12+**. Minuet uses `vim.system` to launch
`curl`; this spec declares no plugin dependencies.

| Setting | Effective value | Meaning |
|---|---|---|
| `provider` | `"codestral"` | FIM backend |
| `model` | `"codestral-latest"` | Provider-managed alias, not a fixed model version |
| `end_point` | `https://codestral.mistral.ai/v1/fim/completions` | Configured dedicated endpoint |
| `api_key` | Function calling `secrets.get("CODESTRAL_API_KEY")` | See §5 |
| `stream` | `true` | Requests a streaming API response; see below |
| `optional.max_tokens` | `256` | Output cap per request |
| `optional.stop` | `{ "\n\n" }` | Generation stops at a blank-line delimiter |
| `virtualtext.auto_trigger_ft` | `{}` | No automatic requests |
| `n_completions` | `3` (explicit) | Three concurrent FIM requests per invocation |
| `context_window` | `16000` (inherited) | Total context characters, not tokens |
| `context_ratio` | `0.75` (inherited) | Prefix/suffix budget split when trimming |
| `request_timeout` | `5` seconds | Passed to curl as `--max-time` |
| `notify` | `"warn"` (inherited) | Warnings and errors, no routine request notifications |
| `virtualtext.show_on_completion_menu` | `false` (inherited) | Hide AI preview while the completion menu is visible |

Context comes from the current buffer's prefix and suffix around the cursor.
There is no cross-file retrieval or LSP context injection in this setup.
The local 16,000-character budget is separate from the model's token limit:
Mistral's [Codestral 25.08 model page](https://docs.mistral.ai/models/codestral-25-08)
currently lists **128k** context, not the original guide's 32K.

**Streaming is not token-by-token display here.** At the reviewed commit,
`backends/common.lua` collects curl output and `backends/openai_base.lua` decodes
it on process exit. Candidates become available as each request finishes.
A streaming response can yield partial text when the timeout cuts it short;
`max_tokens` limits generation but cannot guarantee completion within five seconds.
The blank-line stop also intentionally limits longer suggestions.

On 2026-09-20, the user chose to retain three candidates and raise the timeout
from three to five seconds to allow slower responses to finish. Both settings
are now explicit. Five seconds is a starting choice, not a measured optimum;
responses that finish sooner are displayed sooner. Three candidates retain the
cycling workflow at the cost of three requests per invocation.

`add_single_line_entry = true` is an inherited default, but it only affects
completion-menu frontends such as Blink/cmp. It does **not** add single-line
variants to this virtual-text frontend. Use line acceptance instead.

## 3. Insert-mode keys

These are explicitly configured keys, not upstream defaults (upstream leaves
these mappings unset).

| Action | Key |
|---|---|
| Invoke / cycle next | `<A-]>` |
| Invoke / cycle previous | `<A-[>` |
| Accept whole completion | `<A-A>` (Alt + uppercase A) |
| Accept one line | `<A-a>` |
| Accept N lines (prompts for count) | `<A-z>` |
| Dismiss | `<A-e>` |

Next/previous invoke when no candidates are stored, otherwise they cycle existing
candidates without another request. A candidate can be hidden by Blink's menu;
visibility alone does not determine whether the key invokes or cycles.
To request a fresh set, dismiss with `<A-e>`, then invoke with `<A-]>`.
`<A-z>` followed by `2` and `<CR>` accepts two lines.

There is no separate trigger mapping in this spec. Manual requests bypass the
virtual-text auto-trigger throttle/debounce, so manual use does not impose a
one-request-per-second limit. Each invocation launches three requests.

## 4. Cost, limits and provider policy

Mistral's [Codestral model page](https://docs.mistral.ai/models/codestral-25-08)
lists **$0.30 per million input tokens and $0.90 per million output tokens**
at review time. These are illustrative metered rates, not proof of how the
configured dedicated endpoint or this account is billed.

For an estimate, assume 22 working days/month, 4,000 input tokens (a rough
approximation of 16,000 characters) and 150 output tokens **per request**, with
three requests per trigger and no discounts:

| Usage | Triggers/month | Requests/month | Estimated metered cost |
|---|---|---|---|
| 50 triggers/day | 1,100 | 3,300 | $4.41 |
| 150 triggers/day | 3,300 | 9,900 | $13.22 |

Formula: `requests × (input_tokens × 0.30 + output_tokens × 0.90) / 1,000,000`.
Input dominates this example. Tokenization, actual context length, output,
exchange rates and taxes change the result. There is no €10 budget enforcement
in this configuration; the old €2/€6 estimates did not account for three requests
per invocation.

Mistral documents [Free mode with usage limits](https://docs.mistral.ai/getting-started/quickstarts/studio/activate-and-generate-api-key)
and [account-specific request/token limits](https://help.mistral.ai/en/articles/698531-why-am-i-hitting-api-rate-limits-and-how-do-i-increase-them).
Do not assume 1B tokens/month, 1 request/second, or that missing console activity
proves free usage. Check the account's actual key type, endpoint entitlement,
usage and billing. The [current key documentation](https://docs.mistral.ai/admin/identity-access/api-keys)
distinguishes Studio, Vibe and legacy Mistral Code keys; switching plans is not
necessarily accomplished by swapping the key alone.

The old “free trains / paid private” distinction was too broad. Mistral documents
an [API training opt-out](https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training)
in Admin → Privacy, separate from its Vibe setting. This review did not inspect
the account's settings. Provider nationality alone does not establish data
residency, retention or contractual protections for the selected service.

## 5. Secret handling

[`lua/config/secrets.lua`](../lua/config/secrets.lua) parses
`~/.config/secrets/codestral.env` when `init.lua` calls
`require("config.secrets").load("codestral.env")` during Phase 1.
Store the file outside Git with mode `600`, and its directory with mode `700`.
The loader does not create files or enforce their permissions.

Supported lines are `KEY=VALUE` or `export KEY=VALUE`, optionally with matching
surrounding quotes. The loader skips blank/comment lines and empty values; it
parses text rather than executing shell code. It does not perform shell variable
expansion. A missing/unreadable file returns zero loaded keys silently.

Loaded values go into an **in-process Lua table**, not `vim.env`.
Minuet's `api_key` callback reads that table through `secrets.get(name)`.
`get()` falls back to `vim.env[name]` if no stored value exists; it does not erase
an environment variable inherited at launch. `secrets.export(name)` explicitly
copies a value into the environment, but has no callers in this configuration.

This prevents the file-loaded key from being inherited in the environment by
LSP servers, terminal shells and other unrelated child processes. It does not
mean the key never leaves Neovim: Minuet passes it to **curl as an Authorization
header in its argument list**, then sends it to the API over HTTPS. The Lua table
is not isolation from other code running inside Neovim.

The old validation statement “nvim `os.getenv` = SET” contradicted this design.
With the parent environment unset, the expected state is `secrets.get()` present
and `vim.env`/`os.getenv()` unset. Check presence only; never print the key.
`papis.env` is not loaded by this Neovim setup; its consumers belong to the parent
repository and are outside this guide's scope.

## 6. Known limitation: manual buffer access

Blink's `enabled` callback checks `vim.b.large_file`; Minuet's manual virtual-text
trigger does not. Neither this spec nor the reviewed trigger checks that flag or
excludes secret-file patterns. An empty `auto_trigger_ft` stops automatic requests,
but does not restrict where manual requests are allowed. The context cap limits
the transmitted text, not all work needed to read the buffer.

Therefore the general large-file completion guard should not be interpreted as
covering manual AI requests. This documentation review records the gap; adding
Minuet buffer restrictions would be a separate behavior change.

## 7. Verification and troubleshooting

Review evidence: configuration and installed-plugin source inspection, plus a
headless load of the real configuration to check effective settings and actual
insert mappings. Secret-loader isolation is checked using a dummy fixture, without
printing credentials or sending API requests.

For a live acceptance pass, restart Neovim inside a Git repository, use a disposable
code buffer, enter insert mode and test invocation, cycling, whole/line/N-line
acceptance, dismissal and interaction with Blink's menu. Test through foot and
tmux to cover actual Alt-key delivery. This review does not repeat that live test
or verify the account's billing, quota, privacy settings or secret-file permissions.

Use `:checkhealth` for general configuration health and `:checkhealth blink.cmp`
for the separate completion engine. The installed Minuet has no dedicated health
module. After entering insert mode, `:verbose imap <A-]>` checks the trigger mapping.
For missing credentials, request errors or timeouts, inspect `:messages`; temporarily
setting `notify = "debug"` in the spec enables request lifecycle notifications.
Do not print the full provider configuration or curl command with a real key.

## Appendix A — historical local alternative

The original design considered `ggml-org/llama.vim` with a local llama.cpp FIM
server and Qwen2.5-Coder models, then chose Codestral. No local AI completion
server, serving function or llama.vim plugin is configured here.

That is a possible direction to reassess if offline use or keeping code local
becomes a requirement, not a tested fallback procedure. The old model rankings,
hardware throughput assumptions and llama-server preset commands were not
validated by this review and should not be treated as current setup instructions.
