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

-- 1. Initialize the configuration
require("config").setup({
	colorscheme = "catppuccin-mocha",
})

-- 2. Import plugins
-- require("lazy").setup({
-- 	spec = {
-- 		{ import = "plugins" },
-- 	},
-- 	install = {
-- 		colorscheme = { "catppuccin-mocha", "habamax" },
-- 	},
-- 	checker = {
-- 		enabled = true, -- check for plugin updates regularly
-- 		notify = true, -- notify on updates
-- 	},
-- 	performance = {
-- 		rtp = {
-- 			disabled_plugins = {
-- 				"gzip",
-- 				"tarPlugin",
-- 				"tohtml",
-- 				"tutor",
-- 				"zipPlugin",
-- 			},
-- 		},
-- 	},
-- })

-- 3. Explicityly load the colorscheme
LazyUtil.try(function()
	vim.cmd.colorscheme("catppuccin-mocha")
end, {
	msg = "Could not load your catppuccin-mocha",
	on_error = function(msg)
		LoongVim.error(msg)
		vim.cmd.colorscheme("habamax")
	end,
})
