-- AstroNvim pins blink.cmp to an untagged commit, so blink can never resolve a
-- release tag for its prebuilt Rust fuzzy matcher: every session it retries the
-- download ("Downloading pre-built binary"), fails — noisily on offline devbox
-- restores — and falls back to Lua anyway. Pin the Lua implementation to make
-- that fallback explicit and silent; completion behavior is unchanged.
return {
  "Saghen/blink.cmp",
  opts = {
    fuzzy = { implementation = "lua" },
  },
}
