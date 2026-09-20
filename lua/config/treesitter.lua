-- Highlighting and window-local folding policy, separate from parser installation.
local M = {}
local limit = 1024 * 1024
local attached, pending, folds = {}, {}, {}

function M.too_large(buf)
  if vim.b[buf].large_file then return true end
  -- Includes a final newline, as documented by nvim_buf_get_offset(). This
  -- measures loaded text (including unsaved edits), without copying its lines.
  return vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) > limit
end

function M.update(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  local blocked = M.too_large(buf)
  if blocked then
    vim.treesitter.stop(buf)
  elseif vim.bo[buf].filetype ~= "" and not vim.treesitter.highlighter.active[buf] then
    -- Missing parsers are allowed. pcall also suppresses parser/query failures;
    -- use :checkhealth nvim-treesitter to diagnose missing highlighting.
    pcall(vim.treesitter.start, buf)
  end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    folds[win] = folds[win] or {}
    local saved = folds[win][buf]
    if blocked then
      if not saved then folds[win][buf] = vim.wo[win][0].foldmethod end
      -- The second index changes only this window's setting for this buffer;
      -- the window default for subsequently opened buffers stays untouched.
      vim.wo[win][0].foldmethod = "manual"
    elseif saved then
      if vim.wo[win][0].foldmethod == "manual" then
        vim.wo[win][0].foldmethod = saved
      end
      folds[win][buf] = nil
    end
  end
end

local function schedule(buf)
  if pending[buf] then return end
  pending[buf] = true
  vim.schedule(function()
    pending[buf] = nil
    M.update(buf)
  end)
end

local function watch(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  if not attached[buf] then
    attached[buf] = vim.api.nvim_buf_attach(buf, false, {
      -- API edits and edits to hidden buffers do not reliably emit TextChanged.
      -- Defer window/option changes until outside the buffer callback's textlock.
      on_lines = function(_, b) schedule(b) end,
      on_reload = function(_, b) schedule(b) end,
      on_detach = function(_, b) attached[b] = nil end,
    })
  end
  M.update(buf)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("treesitter_start", { clear = true })
  local previous_win
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function() previous_win = vim.api.nvim_get_current_win() end,
  })
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      -- A split inherits the source window's temporary manual setting. Inherit
      -- its restoration value too, before WinEnter applies the guard again.
      local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
      local saved = folds[previous_win]
      if saved and saved[buf] then folds[win] = { [buf] = saved[buf] } end
    end,
  })
  vim.api.nvim_create_autocmd({ "FileType", "BufReadPost", "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function(args)
      -- A changed filetype may need a different language/query set.
      if args.event == "FileType" then vim.treesitter.stop(args.buf) end
      watch(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      for _, saved in pairs(folds) do saved[args.buf] = nil end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args) folds[tonumber(args.match)] = nil end,
  })
end

return M
