local config = require("devnull.config")
local ui = require("devnull.ui")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

--- Open a user's profile and commits. Defaults to `config.username`.
function M.user(username)
  ui.open_user(username or config.options.username)
end

--- Open a single commit by id or by dev-null.sh commit URL.
function M.commit(id)
  ui.open_commit(id)
end

return M
