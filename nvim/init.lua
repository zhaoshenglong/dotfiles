-- bootstrap lazy.nvim, LoongVim and other plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = {
		{
			"zhaoshenglong/LoongVim",
			branch = "loongvim",
			import = "loongvim.plugins",
			-- "LazyVim/LazyVim",
			-- import = "lazyvim.plugins",
			opts = {
				colorscheme = "catppuccin-mocha",
			},
		},
		{ import = "plugins" },
	},
	install = {
		colorscheme = { "catppuccin-mocha", "habamax" },
	},
	checker = {
		enabled = true, -- check for plugin updates regularly
		notify = true, -- notify on updates
	},
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})
