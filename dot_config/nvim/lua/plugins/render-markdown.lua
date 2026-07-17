return {
    'MeanderingProgrammer/render-markdown.nvim',
    -- Use the standalone mini.icons — the SAME provider AstroNvim installs and sets up.
    -- Depending on the full 'echasnovski/mini.nvim' suite here pulls in a SECOND copy of
    -- the mini.icons module; require('mini.icons') then resolves to mini.nvim's copy,
    -- which AstroNvim never sets up, so the statusline's icon-color lookup races the
    -- highlight creation and errors with "Invalid highlight name: 'MiniIcons*'".
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- standalone mini.icons (matches AstroNvim)
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- full mini.nvim suite (duplicates mini.icons — avoid)
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
}
