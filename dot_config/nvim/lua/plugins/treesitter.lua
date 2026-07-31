-- Replaces the AstroNvim template's disabled treesitter stub (chezmoi overwrites
-- it), giving devbox bundles an offline-safe treesitter policy:
--
--   * auto_install = false — AstroNvim v6 defaults this to true, which makes
--     nvim try to download a parser every time a file with a missing parser is
--     opened. On an offline restore target that surfaces a download error on
--     every such open. Parsers are baked at image build instead; on a connected
--     machine `:TSInstall <lang>` still works for anything extra.
--
--   * ensure_installed — the broad everyday set. Keep this in sync with
--     TS_PARSERS in devbox scripts/init_plugins.sh, which is what actually
--     compiles them into the image (this list merges with AstroNvim's own
--     defaults via `opts_extend`, so startup finds everything already present
--     and never touches the network).
return {
  "AstroNvim/astrocore",
  opts = {
    treesitter = {
      auto_install = false,
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "cmake",
        "css",
        "csv",
        "diff",
        "dockerfile",
        "git_config",
        "git_rebase",
        "gitcommit",
        "gitignore",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "html",
        "ini",
        "javascript",
        "jsdoc",
        "json",
        "json5",
        "lua",
        "luadoc",
        "make",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "requirements",
        "rust",
        "ssh_config",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
        "zsh",
      },
    },
  },
}
