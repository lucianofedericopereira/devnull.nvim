if vim.g.loaded_devnull then
  return
end
vim.g.loaded_devnull = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify("dev-null.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end

local subcommands = { "user", "commit" }

vim.api.nvim_create_user_command("DevNull", function(cmd)
  local devnull = require("devnull")
  local sub, arg = cmd.fargs[1], cmd.fargs[2]

  if sub == "commit" then
    devnull.commit(arg)
  elseif sub == "user" then
    devnull.user(arg)
  elseif sub then
    -- `:DevNull nunomaduro` is shorthand for `:DevNull user nunomaduro`.
    devnull.user(sub)
  else
    devnull.user()
  end
end, {
  nargs = "*",
  desc = "Browse dev-null.sh",
  complete = function(arglead, line)
    if #vim.split(line, "%s+", { trimempty = true }) <= 2 and not line:match("%s%S+%s") then
      return vim.tbl_filter(function(s)
        return s:find(arglead, 1, true) == 1
      end, subcommands)
    end
    return {}
  end,
})
