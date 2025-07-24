return {
  -- 在这里添加所有你想安装的自定义插件
  -- 将你提供的 csvview.nvim 配置粘贴到这里

  {
    "hat0uma/csvview.nvim",
    -- 你提供的 opts 配置
    opts = {
      parser = { comments = { "#", "//" } },
      keymaps = {
        -- Text objects for selecting fields
        textobject_field_inner = { "if", mode = { "o", "x" } },
        textobject_field_outer = { "af", mode = { "o", "x" } },
        -- Excel-like navigation
        jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
        jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
        jump_next_row = { "<Enter>", mode = { "n", "v" } },
        jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
      },
    },
    -- 你提供的 cmd 配置
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  },

  -- 如果你还有其他想装的插件，也可以加在这里
  -- 比如:
  -- { "tpope/vim-surround" },
  
}
