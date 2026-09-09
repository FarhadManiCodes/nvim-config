# CLAUDE.md

Guidance for Claude Code when working on this Neovim configuration. The Neovim guardrails
are shared with Codex and live in one file, imported here so there is only ever one copy:

@AGENTS.md

Repository-wide guardrails are in the dotfiles `AGENTS.md`, loaded via the dotfiles
`CLAUDE.md` when the session starts at the repository root. This is a separate Git
repository included there as a submodule, so a session started inside `nvim/` does not load
them — read `../AGENTS.md` in that case; a cross-directory `@` import does not expand.

Detailed reference, read on demand rather than loaded into every session:
`README.md` (what is set up, requirements, keys), `docs/architecture.md` (per-feature
rationale and implementation constraints), and the task-specific `docs/ai-completion.md`,
`docs/dap-config.md` and `docs/lsp-testing-guide.md`.
