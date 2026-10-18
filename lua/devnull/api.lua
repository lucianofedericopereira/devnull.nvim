local config = require("devnull.config")

local M = {}

local function url_encode(s)
  return (tostring(s):gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

--- GET a path (or absolute URL) and call `cb(err, decoded)` on the main loop.
function M.get(path, query, cb)
  local url = path:match("^https?://") and path or (config.options.base_url .. "/api/v1" .. path)

  if query then
    local parts = {}
    for k, v in pairs(query) do
      if v ~= nil then
        table.insert(parts, url_encode(k) .. "=" .. url_encode(v))
      end
    end
    if #parts > 0 then
      url = url .. (url:find("?", 1, true) and "&" or "?") .. table.concat(parts, "&")
    end
  end

  local cmd = {
    "curl", "-sS", "-L",
    "-H", "Accept: application/json",
    "-w", "\n%{http_code}",
    "--max-time", tostring(math.ceil(config.options.timeout / 1000)),
    url,
  }

  vim.system(cmd, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb("request failed: " .. vim.trim(res.stderr or ""))
      end

      local body, status = res.stdout:match("^(.*)\n(%d+)$")
      status = tonumber(status)

      if status == 404 then
        return cb("not found")
      elseif status == 429 then
        return cb("rate limited (60 requests/minute), try again shortly")
      elseif not status or status >= 400 then
        return cb("HTTP " .. tostring(status))
      end

      local ok, decoded = pcall(vim.json.decode, body, { luanil = { object = true, array = true } })
      if not ok then
        return cb("invalid JSON response")
      end

      cb(nil, decoded)
    end)
  end)
end

function M.user(username, cb)
  M.get("/users/" .. url_encode(username), nil, cb)
end

function M.commits(username, opts, cb)
  opts = opts or {}
  M.get("/users/" .. url_encode(username) .. "/commits", {
    cursor = opts.cursor,
    replies = opts.replies and "1" or nil,
  }, cb)
end

function M.commit(id, cb)
  M.get("/commits/" .. url_encode(id), nil, cb)
end

return M
