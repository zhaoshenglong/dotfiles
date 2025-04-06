vim.uv = vim.uv or vim.loop

local M = {}

---@param opts? LoongVimConfig
function M.setup(opts)
  require("loongvim.config").setup(opts)
end

return M
