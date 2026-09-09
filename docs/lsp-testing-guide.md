# LSP testing guide

How to check the LSP setup on **this machine** actually works, and what the right answers
are. Deliberately not a tutorial: writing a two-file C++ project or a typed Python module
is not something worth keeping instructions for. What is kept is the part that is specific
here — which server owns what, where the tuning lives, and the numbers this hardware
should produce.

> **Rewritten 2026-09-09.** The previous version was written in December 2025 against a
> three-server, nvim-cmp setup and had drifted into instructing the reader to do forbidden
> things: verify `nvim-lspconfig` and `nvim-cmp` are installed (both are banned — see
> `AGENTS.md`), run `:CmpStatus` (does not exist), call `vim.diagnostic.disable()` (removed
> in Neovim 0.12; it throws), and install basedpyright per-venv. Those are gone rather than
> hedged. Full text in `git log -p -- docs/lsp-testing-guide.md`.

## What is configured

Nine servers, all via the native `vim.lsp.config` API — **no `nvim-lspconfig`, no Mason**.
`lua/config/lsp.lua` is the only source.

| Server | Language | Installed by |
|---|---|---|
| `clangd` | C/C++/CUDA — the primary case | `pacman -S clang` |
| `basedpyright` | Python types, navigation, auto-import | `uv tool install basedpyright` — **a global uv tool, never in a project venv** |
| `ruff` | Python lint + format | `pacman -S ruff` (`ruff server` *is* the LSP) |
| `bashls` | Bash | `pacman -S bash-language-server shellcheck` |
| `yamlls` / `jsonls` | YAML / JSON | `pacman -S yaml-language-server vscode-json-languageserver` |
| `tinymist` | Typst | `pacman -S tinymist` |
| `lua_ls` | Lua, i.e. this config | `pacman -S lua-language-server` |
| `neocmake` | CMake build files | `paru -S neocmakelsp` (formatting via `python-gersemi`) |

Check presence in one line:

```bash
for b in clangd basedpyright ruff bash-language-server yaml-language-server \
         vscode-json-languageserver tinymist lua-language-server neocmakelsp; do
  printf '%-28s %s\n' "$b" "$(command -v $b || echo MISSING)"
done
```

## Runnable checks beat this document

Where a sandbox exists, run it — it proves the wiring rather than asserting it.

- **Python** — `~/learning/playground/python-lsp-tests`: `bash run.sh`, 13 checks. Covers
  the ruff/basedpyright split below.
- **Notebooks** — `~/learning/playground/jupytext-nvim-tests`: 17 checks, plus
  `scenarios.md` for hands-on runs.

## C/C++ — clangd

**clangd needs `compile_commands.json` or a `.git` root.** Without a compilation database
it parses single files with clang's built-in default and cross-file navigation does not
work:

```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .        # clangd looks at the project root
```

For a non-CMake project use `bear -- make`.

**Tuning lives in two places, both tracked.** Command-line flags are in `lua/config/lsp.lua`
(`--background-index`, `--header-insertion=never`, `--pch-storage=memory`, `-j=8`,
`--fallback-style=none`). Behaviour is in `dotfiles/clangd/config.yaml`, symlinked to
`~/.config/clangd/config.yaml` — that file carries its own commentary and is the place to
add diagnostic suppressions, not this document.

**The `-std` trap, from `config.yaml`.** No global `-std` is set on purpose: clangd appends
`CompileFlags.Add` *after* the project's compile command and the last `-std` wins, so a
global one silently overrides every project's real standard (verified on clangd 22 — a
`c++17` database got reparsed as `c++23`). For a newer standard in a scratch directory,
drop a `compile_flags.txt` with `-std=c++23` there instead.

**What to check by hand**, in any project with a compilation database:

- `gd` / `gr` / `K` cross files, not just within one.
- `<leader>ca` on an unresolved symbol offers to add the include. Note
  `--header-insertion=never`, so it never happens unprompted.
- `<leader>ch` switches header ↔ source (clangd extension, C/C++ only).
- Template-heavy code (Trilinos `Tpetra`, deal.II) hovers with expanded type aliases —
  `Hover.ShowAKA: Yes` — and does not drown in noise, because `unused-parameter`,
  `deprecated-declarations`, `unknown-pragmas` and `unused-local-typedef` are suppressed.
- Diagnostics are underlines only. `virtual_text = false` is deliberate; the float is
  `<leader>ed`.

## Python — the split that matters

Two servers attach, and the division is **not** by speed. It is by which side carries the
useful code action:

| Diagnostic | Owner | Why |
|---|---|---|
| unused import / variable (`F401`, `F841`) | **ruff** | the basedpyright rules are set to `"none"` |
| undefined name (`F821` / `reportUndefinedVariable`) | **basedpyright** | auto-import hangs off it; `F821` is in ruff's `ignore` |
| formatting | **ruff**, on demand only | basedpyright reports `textDocument/formatting = false` |

`*.py` is deliberately **out** of the format-on-save glob (which is `*.c, *.cpp, *.cc, *.h,
*.hpp, *.typ`) — auto-reformatting third-party data-engineering code on save buries real
diffs. `<leader>cf` formats when you ask.

Do not "tidy" the `F821` asymmetry into matching the other two: turning
`reportUndefinedVariable` off to kill the duplicate left **zero** code actions on an
undefined name.

ruff's config must go in `init_options.settings`; under `settings` it is silently ignored.

## Performance — what this hardware should do

| Measure | Expected here | How |
|---|---|---|
| Startup | ~67 ms to ShaDa (audit 2026-09) | `nvim --headless --startuptime /tmp/st +qa && sort -k2 -rn /tmp/st \| head` |
| clangd index, small project | usable < 5 s | open a file, wait for `:LspInfo` to show it attached |
| clangd RSS | 500 MB – 2 GB; up to 4 GB fine on 64 GB | `ps aux \| grep clangd` |
| Completion latency | < 100 ms | type `v.` on a `std::vector<int> v;` |

If clangd is slow: drop `-j=8` to `-j=4` in `lua/config/lsp.lua`, or set `Index.Background:
Skip` in `config.yaml`. Check the file is not over the 10 MB large-file threshold first —
LSP is disabled there by design, via the `on_attach` guard on `vim.b.large_file`.

## Troubleshooting

**LSP not attaching.** `:LspInfo` first, then `:checkhealth vim.lsp`. Confirm the filetype
(`:set filetype?`) and that the binary is on `PATH`. For clangd, confirm
`compile_commands.json` resolves. For basedpyright, check the **global uv tool** —
`uv tool list` should show it, and `command -v basedpyright` should resolve into
`~/.local/bin` (a shim onto `~/.local/share/uv/tools/basedpyright/`). It discovers the
project venv at runtime, so a missing or unactivated venv is not the cause, and installing
a second copy into one is not the fix.

**No completions.** `:checkhealth blink.cmp` — this config uses **blink.cmp**, so there is
no `:CmpStatus`. Sources are `lsp`, `buffer`, `path`; per-filetype overrides drop LSP for
SQL and Markdown deliberately. Nothing is preselected and ghost text is off by design, so
an empty-looking menu may be correct — `<C-Space>` triggers manually. Completion is
disabled entirely on buffers flagged `vim.b.large_file`.

**Too many diagnostics.** Add to `Diagnostics.Suppress` in `dotfiles/clangd/config.yaml`,
which is the tracked file. To silence temporarily: `:lua vim.diagnostic.enable(false)`, and
`true` to restore. **`vim.diagnostic.disable()` was removed in Neovim 0.12 and throws.**

**Headers not found.** `cat compile_commands.json | jq '.[0].command'` and look for the
`-I` flags, then `:LspRestart`.

**Keymaps not working.** They are buffer-local and only exist once a client attaches.
`:verbose map gd` shows the winner. Diagnostic float is `<leader>ed` and loclist is
`<leader>eq` — both were renamed from `<leader>e` / `<leader>q` in the June 2026 keymap
audit, so older notes are wrong.

## Success criteria

- [ ] Nine servers resolve on `PATH`; `:LspInfo` shows the right one attached per filetype
- [ ] clangd: cross-file `gd`/`gr`, header switch, no template diagnostic flood
- [ ] Python: ruff owns unused imports, basedpyright owns undefined names **with** an
      auto-import action, and saving a `.py` does **not** reformat it
- [ ] `:checkhealth` is clean apart from the known upstream warnings recorded in
      `docs/audit-2026-09.md`
- [ ] Startup within ~100 ms; clangd RSS in range
