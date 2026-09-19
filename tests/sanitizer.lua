-- Run from the repo root: nvim --headless -u NONE -i NONE -l tests/sanitizer.lua
-- Requires the installed C and C++ treesitter parsers; no LSP processes started.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/site')
package.loaded['blink.cmp'] = { get_lsp_capabilities = function() return {} end }
vim.lsp.enable = function() end
local formatted
vim.lsp.buf.format = function()
  formatted = vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
require('config.lsp')

local function check(ft, input, expected)
  vim.cmd('enew!')
  vim.bo.filetype = ft
  vim.api.nvim_buf_set_lines(0, 0, -1, false, input)
  local tick = vim.api.nvim_buf_get_changedtick(0)
  formatted = nil
  vim.api.nvim_exec_autocmds('BufWritePre', {
    group = 'LspFormatOnSave', pattern = 'sample.' .. ft,
  })
  assert(vim.deep_equal(formatted, expected), vim.inspect({input=input, expected=expected, actual=formatted}))
  if vim.deep_equal(input, expected) then
    assert(vim.api.nvim_buf_get_changedtick(0) == tick, 'unchanged text must not be rewritten')
  end
end

for _, ft in ipairs({'c', 'cpp'}) do
  local literals = {
    [[const char* s = "“Hello” ≪ ≫ don’t";]],
    [[const char* escaped = "\"“Hello”\"";]],
    [[int c = L'’';]],
    [[// “comment” ≪ ‘comment’]],
    [[/* “block]],
    [[comment” ≫ */]],
    [[#define MESSAGE "“Hello”"]],
    [[#define MULTILINE \]],
    [[  "‘Hello’"]],
    [[#include <“header”.h>]],
    [[// continued comment \]],
    [[“still a comment”]],
  }
  check(ft, literals, literals)
  check(ft, {[[const char* s = “Hello”;]], [[int c = ‘x’;]], [[int n = 1 ≪ 2;]]},
    {[[const char* s = "Hello";]], [[int c = 'x';]], [[int n = 1 << 2;]]})
  check(ft, {[[const char* s = "“Hello”"; int n = 8 ≫ 1; // ≪]]},
    {[[const char* s = "“Hello”"; int n = 8 >> 1; // ≪]]})
end
local raw = {[[auto text = u8R"tag(“Hello”]], [[‘world’ ≪ ≫)tag";]]}
check('cpp', raw, raw)
check('typ', {'“text”'}, {'“text”'})

local get_parser = vim.treesitter.get_parser
vim.treesitter.get_parser = function() error('parser unavailable') end
check('cpp', {'int n = 1 ≪ 2;'}, {'int n = 1 ≪ 2;'})
local parse_attempts = 0
vim.treesitter.get_parser = function()
  parse_attempts = parse_attempts + 1
  error('must not parse a large buffer')
end
local large = { '// ' .. string.rep('x', 1024 * 1024), 'int n = 1 ≪ 2;' }
check('cpp', large, large)
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'int n = 1 ≪ 2;'})
vim.b.large_file = true
vim.api.nvim_exec_autocmds('BufWritePre', {group='LspFormatOnSave', pattern='sample.cpp'})
assert(formatted[1] == 'int n = 1 ≪ 2;')
assert(parse_attempts == 0, 'large-file guards must run before parsing')
vim.treesitter.get_parser = get_parser
print('PASS: code repair, protected literals/comments/macros, raw strings, missing parser, large-file guards, pre-format ordering')
vim.cmd('qa!')
