return {
  -- 1. 下载 Catppuccin 主题
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "latte", -- 强制使用 Latte (浅色)
      transparent_background = false,
      term_colors = true,
      integrations = {
        astronvim = true,
        mason = true,
        neotree = true,
        treesitter = true,
        telescope = true,
        which_key = true,
      },
    },
  },
  -- 2. 设置 AstroNvim 默认主题
  {
    "AstroNvim/astroui",
    opts = { colorscheme = "catppuccin" },
  },
  -- 3. 核心设置：强制 Light Mode (关键)
  {
    "AstroNvim/astrocore",
    opts = {
      options = {
        opt = { background = "light" },
      },
    },
  },
}
