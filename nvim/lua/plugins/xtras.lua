-- Some extras need to be loaded before others
local prios = {
  ["loongvim.plugins.extras.test.core"] = 1,
  ["loongvim.plugins.extras.dap.core"] = 1,
  ["loongvim.plugins.extras.ui.edgy"] = 2,
  ["loongvim.plugins.extras.lang.typescript"] = 5,
  ["loongvim.plugins.extras.formatting.prettier"] = 10,
  -- default priority is 50
  ["loongvim.plugins.extras.editor.aerial"] = 100,
  ["loongvim.plugins.extras.editor.outline"] = 100,
}

---I do not want to use json to save plugins
---But I need to try it one day to enable/disable plugins
---@type string[]
local extras = LoongVim.dedup(LoongVim.config.json.data.extras)

local version = vim.version()
local v = version.major .. "_" .. version.minor

local compat = { "0_9" }

LoongVim.plugin.save_core()
if vim.tbl_contains(compat, v) then
  table.insert(extras, 1, "loongvim.plugins.compat.nvim-" .. v)
end

table.sort(extras, function(a, b)
  local pa = prios[a] or 50
  local pb = prios[b] or 50
  if pa == pb then
    return a < b
  end
  return pa < pb
end)

---@param extra string
return vim.tbl_map(function(extra)
  return { import = extra }
end, extras)
