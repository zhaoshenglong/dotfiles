vim.api.nvim_create_autocmd(
  { "VimEnter" },
  {
    pattern = "*",
    callback = function(data)
      local directory = vim.fn.isdirectory(data.file) == 1
      if not directory then
        return
      end
      vim.cmd.cd(data.file)
      require("nvim-tree.api").tree.open()
    end
  }
)
