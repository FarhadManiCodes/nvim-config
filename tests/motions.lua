-- Run from the repo root: nvim --headless -u NONE -i NONE -l tests/motions.lua
-- Asserts that treesitter motions and text objects land on the right NODES, which
-- `maparg` cannot tell you -- a key can be mapped and still select the wrong thing.
-- Covers the locally written queries/{sql,zsh}/textobjects.scm, which upstream does
-- not ship and which nothing else tests.
--
-- Runs the real config function from lua/plugins/treesitter.lua rather than
-- re-declaring the keymaps, so this cannot drift from what the config actually maps.
-- rtp order matters: the repo (local queries) and site (parsers) must precede the
-- plugin clone, which still carries a stale parser set that fails to load.
local L = vim.fn.stdpath('data') .. '/lazy/'
vim.opt.rtp:prepend(L .. 'nvim-treesitter')
vim.opt.rtp:prepend(L .. 'nvim-treesitter-textobjects')
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/site')
vim.opt.rtp:prepend(vim.fn.getcwd())

for _, spec in ipairs(dofile('lua/plugins/treesitter.lua')) do
  if spec[1] == 'nvim-treesitter/nvim-treesitter-textobjects' then spec.config() end
end

local function buf(ft, lines)
  vim.cmd('enew!')
  vim.bo.filetype = ft
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  assert(pcall(vim.treesitter.start, 0, ft), 'no parser for ' .. ft)
end

local function at(row, col) vim.api.nvim_win_set_cursor(0, { row, col or 0 }) end

---Run a motion, assert the resulting cursor line.
local function moves(keys, from, want)
  at(from)
  vim.cmd('normal ' .. keys)
  local got = vim.api.nvim_win_get_cursor(0)[1]
  assert(got == want, string.format('%s from %d: want line %d, got %d', keys, from, want, got))
end

---Run a visual text object, assert the selected line range.
local function selects(keys, from, want_s, want_e, col)
  at(from, col)
  vim.cmd('normal ' .. keys)
  vim.cmd('normal! \27')
  local s = vim.api.nvim_buf_get_mark(0, '<')[1]
  local e = vim.api.nvim_buf_get_mark(0, '>')[1]
  assert(s == want_s and e == want_e,
    string.format('%s at %d: want %d..%d, got %d..%d', keys, from, want_s, want_e, s, e))
end

-- Python: the point of the fixture is the decoys. A regex would take either of the
-- first two lines for a function; the parser must skip both.
buf('python', {
  's = "def fake_in_string():"',
  '# def fake_in_comment():',
  'def real_one():',
  '    return 1',
  '',
  'def real_two():',
  '    return 2',
})
moves(']m', 1, 3)          -- skips the string and the comment
moves('2]m', 1, 6)         -- counts
moves(']M', 3, 4)          -- function end, not start
moves('[m', 7, 6)
moves(']m', 7, 7)          -- end of file: stays put, does not wrap or error
selects('vaf', 4, 3, 4)
selects('vif', 4, 4, 4)
selects('vaf', 5, 6, 7)    -- lookahead: from a blank line, takes the NEXT function

-- Jump list: move.set_jumps = true, so a motion is undoable with <C-o>.
at(1)
vim.cmd('normal ]m')
vim.cmd('normal! \15')     -- <C-o>
assert(vim.api.nvim_win_get_cursor(0)[1] == 1, 'set_jumps: <C-o> must return to the start line')

-- C: function motions and operator-pending ranges over braces.
buf('c', {
  'int add(int a, int b) {',
  '  return a + b;',
  '}',
  'int mul(int a, int b) {',
  '  return a * b;',
  '}',
})
moves(']m', 1, 4)
selects('vaf', 2, 1, 3)
selects('vif', 2, 2, 2)

-- Zsh: every assertion here exercises queries/zsh/textobjects.scm. Upstream's zsh
-- query defines neither @block nor @parameter.outer, so before that file these were
-- silent no-ops -- they fail by selecting nothing, not by erroring.
buf('zsh', {
  'function greet() {',
  '  local msg="hello world"',
  '  print -l $msg',
  '}',
})
selects('vaf', 2, 1, 4)
selects('vab', 2, 1, 4)    -- @block.outer
selects('vib', 2, 2, 3)    -- @block.inner
selects('vaa', 3, 3, 3, 11)  -- @parameter.outer on $msg
moves(']]', 1, 1)          -- class motions stay no-ops in shell: nothing to jump to

-- SQL: queries/sql/textobjects.scm, likewise local.
buf('sql', {
  'CREATE FUNCTION addone(a int) RETURNS int AS $$',
  'BEGIN',
  '  RETURN a + 1;',
  'END;',
  '$$ LANGUAGE plpgsql;',
})
selects('vaf', 3, 1, 5)

-- Native Neovim selection (an/in) and the conditional text object coexisting:
-- `ai`/`ii` are this config's conditional maps, NOT snacks-style generic scope.
buf('python', { 'def f():', '    if True:', '        return 1' })
selects('vai', 3, 2, 3, 8)
selects('van', 3, 3, 3, 8)

print('PASS')
vim.cmd('qa!')
