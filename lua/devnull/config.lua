local M = {}

M.defaults = {
  -- Base URL of the dev-null.sh instance.
  base_url = "https://dev-null.sh",
  -- Username opened by a bare `:DevNull`.
  username = nil,
  -- How the buffer is opened: "tab", "split", "vsplit" or "current".
  open = "tab",
  -- Request timeout in milliseconds.
  timeout = 10000,
  keymaps = {
    open = "<CR>",
    browser = "gx",
    more = "]]",
    refresh = "R",
    replies = "t",
    parent = "p",
    author = "a",
    yank = "yu",
    close = "q",
    help = "g?",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
