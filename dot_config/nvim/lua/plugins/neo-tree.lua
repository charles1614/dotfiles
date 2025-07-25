-- File: ~/.config/nvim/lua/plugins/neo-tree.lua

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- Optional, for file icons
    "MunifTanjim/nui.nvim",
  },
  -- If you want to use the system_open command with the `o` key,
  -- you need to provide the opts table with the commands and mappings.
  opts = {
    -- The `system_open` command is defined here
    commands = {
      system_open = function(state)
        local node = state.tree:get_node()
        if not node or not node.path then
          return
        end
        local path = node:get_id()

        -- Check the operating system and run the appropriate command
        if vim.fn.has("macunix") then
          -- macOS
          vim.fn.jobstart({ "open", path }, { detach = true })
        elseif vim.fn.has("win32") then
          -- Windows: Use 'cmd /c start ""' to open the file or directory.
          vim.fn.jobstart({ "cmd", "/c", "start", '""', path }, { detach = true })
        else
          -- Linux and other Unix-like systems
          vim.fn.jobstart({ "xdg-open", path }, { detach = true })
        end
      end,
    },
    -- All other neo-tree options go here.
    -- We add the mapping for our custom command.
    filesystem = {
      window = {
        mappings = {
          ["O"] = "system_open",
        },
      },
      -- You can add other filesystem options here
      -- filtered_items = {
      --   visible = true,
      --   hide_dotfiles = false,
      --   hide_gitignored = true,
      -- },
    },
    -- Example of other top-level options
    -- close_if_last_window = true,
  },
}
