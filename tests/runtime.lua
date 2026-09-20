-- Run from the repo root: nvim --headless -c 'lua dofile("tests/runtime.lua")'
-- Unlike tests/motions.lua and tests/sanitizer.lua, this one needs the REAL config
-- and its lazy-loaded plugins, so it must not be run with -u NONE.
--
-- Scope: things that are cheap and deterministic to assert with the config loaded.
-- Picker *rendering*, focus and in-picker keystrokes are deliberately absent -- see
-- the note at the bottom.
local ok_all = true
local function check(label, cond, detail)
  if not cond then
    ok_all = false
    io.stderr:write(('FAIL  %s%s\n'):format(label, detail and (' -- ' .. detail) or ''))
  end
end

-- <C-Space> belongs to Blink, not to treesitter selection (docs/architecture.md).
-- Blink does NOT register it as a Vim mapping -- it handles the key internally from
-- its own keymap table -- so the invariant is the pair below: blink still claims it,
-- and no Vim-level mapping exists to shadow it.
check('blink still claims <C-space>',
  vim.tbl_contains(require('blink.cmp.config').keymap['<C-space>'] or {}, 'show'),
  vim.inspect(require('blink.cmp.config').keymap['<C-space>']))
for _, mode in ipairs({ 'i', 'x', 'o' }) do
  check('<C-Space> unclaimed by a Vim map in mode ' .. mode,
    vim.fn.maparg('<C-Space>', mode) == '' and vim.fn.maparg('<C-space>', mode) == '',
    'a treesitter selection map would shadow blink here')
end

require('lazy').load({ plugins = { 'telescope.nvim' } })

-- The fzf extension loads through a pcall in core.lua, so a failure there is silent.
-- Assert the extension table exists rather than trusting the pcall.
pcall(require('telescope').load_extension, 'fzf')
check('telescope fzf extension loaded', require('telescope').extensions.fzf ~= nil)

-- Every picker the keymaps reference must resolve, or the key is dead.
local builtin = require('telescope.builtin')
for _, name in ipairs({
  'find_files', 'buffers', 'live_grep', 'current_buffer_fuzzy_find', 'help_tags',
  'resume', 'oldfiles', 'lsp_document_symbols', 'lsp_workspace_symbols',
  'git_commits', 'git_status', 'treesitter', 'quickfix',
}) do
  check('picker resolves: ' .. name, type(builtin[name]) == 'function')
end

-- An empty result set must not raise. This is the case that used to be reported as
-- a picker crash rather than an empty list.
check('find_files with no match does not error',
  pcall(builtin.find_files, { search_file = 'zzz_definitely_no_such_file_zzz' }))
vim.cmd('sleep 300m')

-- Paths containing spaces: telescope runs its finders as argv arrays, not through a
-- shell, so the risk is in the configured rg arguments rather than in quoting. Run
-- the exact vimgrep_arguments the config sets against a path that contains spaces.
local tmp = vim.fn.tempname() .. '/a dir with spaces'
vim.fn.mkdir(tmp, 'p')
local target = tmp .. '/file with spaces.txt'
vim.fn.writefile({ 'needle_xyz' }, target)
local args = vim.deepcopy(require('telescope.config').values.vimgrep_arguments)
vim.list_extend(args, { 'needle_xyz', tmp })
local res = vim.system(args, { text = true }):wait()
check('rg args find a match under a path with spaces',
  res.code == 0 and (res.stdout or ''):find('file with spaces.txt', 1, true) ~= nil,
  'code=' .. tostring(res.code) .. ' out=' .. vim.inspect((res.stdout or ''):sub(1, 120)))

-- Breakpoint listing is native now; telescope-dap is gone and must stay gone.
check('telescope dap extension absent', rawget(require('telescope').extensions, 'dap') == nil)
check('dap.list_breakpoints exists', type(require('dap').list_breakpoints) == 'function')

-- NOT covered here, on purpose: in-picker keys (<C-j>/<C-k>/<C-q>/<Esc>/q), preview
-- rendering and focus. Driving a floating prompt with feedkeys headlessly is async
-- and flaky, and a flaky test is worse than an honest gap. Those stay in TODO.md as
-- interactive checks.

if ok_all then
  print('PASS')
  vim.cmd('qa!')
else
  print('FAIL')
  vim.cmd('cq!')
end
