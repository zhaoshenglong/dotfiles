return {
  -- Treesitter is a new parser generator tool that we can
  -- use in Neovim to power faster and more accurate
  -- syntax highlighting.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main", -- the rewritten plugin; master is frozen legacy
    build = ":TSUpdate",
    lazy = false, -- the main branch does not support lazy-loading
    opts_extend = { "ensure_installed" },
    opts = {
      -- parsers to install; highlighting/indentation/folding are enabled
      -- per filetype in the autocommand below (there is no configs module
      -- anymore, and incremental selection was dropped upstream)
      ensure_installed = {
        "bash",
        "c",
        "cmake",
        "cpp",
        "diff",
        "html",
        "gitignore",
        "git_config",
        "git_rebase",
        "go",
        "gomod",
        "gosum",
        "javascript",
        "jsdoc",
        "json",
        "lua",
        "luadoc",
        "luap",
        "markdown",
        "markdown_inline",
        "printf",
        "python",
        "query",
        "regex",
        "sql",
        "ssh_config",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
        "rust",
      },
    },
    config = function(_, opts)
      require("nvim-treesitter").setup()
      if type(opts.ensure_installed) == "table" then
        -- async no-op for parsers that are already installed
        require("nvim-treesitter").install(LoongVim.dedup(opts.ensure_installed))
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("loongvim_treesitter", { clear = true }),
        callback = function(ev)
          -- highlighting is provided by Neovim itself; only proceed when a
          -- parser for this filetype is actually installed
          if not pcall(vim.treesitter.start, ev.buf) then
            return
          end
          -- experimental treesitter indentation (same as the old indent module)
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          -- treesitter-based folds, provided by Neovim
          vim.wo[0][0].foldmethod = "expr"
          vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
        end,
      })

      -- Parsers install asynchronously, so on a fresh setup a buffer can be
      -- opened before its parser is ready and the callbacks above return
      -- without configuring it. TSUpdate fires once installation finishes;
      -- re-trigger FileType for buffers still missing highlighting (this also
      -- retries the textobjects keymaps, which share the same condition).
      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        group = vim.api.nvim_create_augroup("loongvim_treesitter_retry", { clear = true }),
        callback = function()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if
              vim.api.nvim_buf_is_loaded(buf)
              and vim.bo[buf].filetype ~= ""
              and not vim.treesitter.highlighter.active[buf]
            then
              vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
            end
          end
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main", -- main tracks the rewritten nvim-treesitter
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "VeryLazy",
    opts = {
      select = { lookahead = true },
      move = { set_jumps = true },
    },
    config = function(_, opts)
      require("nvim-treesitter-textobjects").setup(opts)

      -- the new plugin no longer creates keymaps; define the move maps
      -- the old textobjects module provided (buffer-local, only where a
      -- parser exists, keeping the diff-mode fallback for ]c/[c)
      local maps = {
        ["]f"] = { "goto_next_start", "@function.outer", "Next function start" },
        ["]c"] = { "goto_next_start", "@class.outer", "Next class start" },
        ["]a"] = { "goto_next_start", "@parameter.inner", "Next parameter start" },
        ["]F"] = { "goto_next_end", "@function.outer", "Next function end" },
        ["]C"] = { "goto_next_end", "@class.outer", "Next class end" },
        ["]A"] = { "goto_next_end", "@parameter.inner", "Next parameter end" },
        ["[f"] = { "goto_previous_start", "@function.outer", "Previous function start" },
        ["[c"] = { "goto_previous_start", "@class.outer", "Previous class start" },
        ["[a"] = { "goto_previous_start", "@parameter.inner", "Previous parameter start" },
        ["[F"] = { "goto_previous_end", "@function.outer", "Previous function end" },
        ["[C"] = { "goto_previous_end", "@class.outer", "Previous class end" },
        ["[A"] = { "goto_previous_end", "@parameter.inner", "Previous parameter end" },
      }
      local function attach(buf)
        if not pcall(vim.treesitter.get_parser, buf) then
          return
        end
        for lhs, map in pairs(maps) do
          local method, query, desc = map[1], map[2], map[3]
          vim.keymap.set({ "n", "x", "o" }, lhs, function()
            -- in diff mode keep the default vim behavior for ]c/[c
            if vim.wo.diff and lhs:find("[cC]") then
              return vim.cmd("normal! " .. lhs)
            end
            require("nvim-treesitter-textobjects.move")[method](query, "textobjects")
          end, { buffer = buf, desc = desc, silent = true })
        end
      end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("loongvim_treesitter_textobjects", { clear = true }),
        callback = function(ev)
          attach(ev.buf)
        end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        attach(buf)
      end
    end,
  },

  -- Automatically add closing tags for HTML and JSX
  {
    "windwp/nvim-ts-autotag",
    event = "LazyFile",
    opts = {},
  },
}
