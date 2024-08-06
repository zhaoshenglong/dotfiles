return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {"nvim-tree/nvim-web-devicons"},
    lazy = false,
    config = function()
      require("nvim-tree").setup {}
    end,
  },
  {
    'numToStr/Comment.nvim',
  },
}
