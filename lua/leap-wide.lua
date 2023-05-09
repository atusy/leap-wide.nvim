---@alias Cache table<integer, table<integer, string>>

---@param buf integer
---@param n integer
---@param cache Cache
---@return string
local function get_line(buf, n, cache)
  if cache[buf] then
    if cache[buf][n] then
      return cache[buf][n]
    end
  else
    cache[buf] = {}
  end

  local s = vim.api.nvim_buf_get_lines(buf, n, n + 1, true)[1]
  cache[buf][n] = s
  return s
end

---@class Opts
---@field priority integer
---@field hl_group string
local opts_default = {
  priority = 1,
  hl_group = "Normal",
}

---Fix displacement of base text caused by narrow virt_text
---@param opts Opts
---@return nil
local function fix_labelling(opts)
  opts = vim.tbl_deep_extend("force", opts_default, opts or {})

  local ns = vim.api.nvim_create_namespace("")
  local buf0 = vim.api.nvim_get_current_buf()
  local cache = { [buf0] = {} } ---@type Cache

  for _, t in pairs(require("leap").state.args.targets) do
    local buf = t.wininfo and t.wininfo.bufnr or buf0
    local n = t.pos[1] - 1
    local line = get_line(buf, n, cache)
    local idx = vim.fn.charidx(line, t.pos[2] - 1)
    local displaywidth = vim.fn.strdisplaywidth(vim.fn.strcharpart(line, idx, 1))
    if displaywidth > 1 then
      local start_col = vim.fn.byteidx(line, idx)
      vim.api.nvim_buf_set_extmark(buf, ns, n, start_col, {
        virt_text = { { string.rep(" ", displaywidth), opts.hl_group } },
        virt_text_pos = "overlay",
        priority = opts.priority,
      })
    end
  end

  -- clear extmark and cache on LeapLeave
  vim.api.nvim_create_autocmd("User", {
    pattern = "LeapLeave",
    once = true,
    callback = function()
      for bufnr, _ in pairs(cache) do
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      end
      cache = {}
    end,
  })
end

return { fix_labelling = fix_labelling }
