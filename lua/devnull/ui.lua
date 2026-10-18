local api = require("devnull.api")
local config = require("devnull.config")

local M = {}

local ns = vim.api.nvim_create_namespace("devnull")

-- Per-buffer view state, keyed by bufnr.
local views = {}

local function set_highlights()
  local links = {
    DevNullTitle = "Title",
    DevNullHash = "Identifier",
    DevNullAuthor = "Function",
    DevNullMeta = "Comment",
    DevNullStars = "DiagnosticWarn",
    DevNullReplies = "DiagnosticInfo",
    DevNullLink = "Underlined",
    DevNullReply = "Special",
    DevNullSeparator = "NonText",
  }
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

--- "2026-10-18T20:20:05Z" -> "3h ago"
local function relative_time(iso)
  local y, mo, d, h, mi, s = (iso or ""):match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then
    return iso or ""
  end
  local now = os.time()
  -- os.time() treats its table as local time; correct by the local UTC offset.
  local offset = os.difftime(now, os.time(os.date("!*t", now)))
  local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) + offset
  local diff = os.difftime(now, t)

  if diff < 60 then
    return "just now"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h ago"
  elseif diff < 86400 * 30 then
    return math.floor(diff / 86400) .. "d ago"
  end
  return string.format("%s-%s-%s", y, mo, d)
end

local function open_url(url)
  if not url then
    return
  end
  if vim.ui.open then
    vim.ui.open(url)
  else
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  end
end

local function notify(msg, level)
  vim.notify("dev-null: " .. msg, level or vim.log.levels.INFO)
end

-- Builder that collects lines, highlights and the commit each line belongs to.
local function builder()
  local b = { lines = {}, hls = {}, owners = {} }

  function b:add(text, hl, owner)
    table.insert(self.lines, text)
    local lnum = #self.lines - 1
    if hl then
      table.insert(self.hls, { lnum, 0, -1, hl })
    end
    self.owners[lnum + 1] = owner
    return lnum
  end

  function b:hl(lnum, from, to, group)
    table.insert(self.hls, { lnum, from, to, group })
  end

  return b
end

local function render_commit(b, c, opts)
  opts = opts or {}
  local author = c.author and c.author.username or "?"
  local when = relative_time(c.created_at)
  local reply = c.parent_id and "↳ " or ""

  local head = string.format("%s%s  @%s · %s", reply, c.short_hash or "", author, when)
  local stats = string.format("   ★ %d  ↩ %d", c.stars_count or 0, c.replies_count or 0)
  local lnum = b:add(head .. stats, nil, c)

  local col = 0
  if reply ~= "" then
    b:hl(lnum, 0, #reply, "DevNullReply")
    col = #reply
  end
  b:hl(lnum, col, col + #(c.short_hash or ""), "DevNullHash")
  local at = head:find("@", 1, true) - 1
  b:hl(lnum, at, at + 1 + #author, "DevNullAuthor")
  b:hl(lnum, at + 1 + #author, #head, "DevNullMeta")
  local star = #head + 3
  b:hl(lnum, star, star + #("★ " .. (c.stars_count or 0)) + 2, "DevNullStars")
  local rep = (head .. stats):find("↩", 1, true) - 1
  b:hl(lnum, rep, -1, "DevNullReplies")

  for _, line in ipairs(vim.split(c.body or "", "\n", { plain = true })) do
    b:add("  " .. line, nil, c)
  end

  if c.link_preview then
    local lp = c.link_preview
    local title = lp.title and lp.title ~= vim.NIL and lp.title or lp.url
    b:add("  ⧉ " .. tostring(title), "DevNullLink", c)
    if opts.full then
      if lp.description and lp.description ~= vim.NIL then
        b:add("    " .. lp.description, "DevNullMeta", c)
      end
      b:add("    " .. lp.url, "DevNullLink", c)
    end
  end

  if c.images and #c.images > 0 then
    if opts.full then
      for _, img in ipairs(c.images) do
        local src = type(img) == "table" and (img.url or img.src) or img
        b:add("  ▣ " .. tostring(src), "DevNullLink", c)
      end
    else
      b:add(string.format("  ▣ %d image%s", #c.images, #c.images == 1 and "" or "s"), "DevNullMeta", c)
    end
  end

  b:add("", nil, nil)
end

local function render_profile(b, u)
  b:add(string.format("@%s", u.username), "DevNullTitle")
  if u.name and u.name ~= u.username then
    b:add(u.name, "DevNullAuthor")
  end
  if u.bio and u.bio ~= "" then
    for _, line in ipairs(vim.split(u.bio, "\n", { plain = true })) do
      b:add(line)
    end
  end
  local meta = {}
  for _, f in ipairs({ "company", "location", "website" }) do
    if u[f] and u[f] ~= "" then
      table.insert(meta, u[f])
    end
  end
  if #meta > 0 then
    b:add(table.concat(meta, " · "), "DevNullMeta")
  end
  b:add(
    string.format(
      "%d commits · %d followers · %d following",
      u.commits_count or 0,
      u.followers_count or 0,
      u.following_count or 0
    ),
    "DevNullMeta"
  )
  b:add(string.rep("─", 60), "DevNullSeparator")
  b:add("")
end

local function draw(buf)
  local view = views[buf]
  if not view or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local b = builder()

  if view.kind == "user" then
    if view.user then
      render_profile(b, view.user)
    end
    if view.replies then
      b:add("[including replies]", "DevNullMeta")
      b:add("")
    end
    for _, c in ipairs(view.commits) do
      render_commit(b, c)
    end
    if view.loading then
      b:add("Loading…", "DevNullMeta")
    elseif view.next_cursor then
      b:add(string.format("── %s to load more ──", config.options.keymaps.more), "DevNullSeparator")
    elseif #view.commits > 0 then
      b:add("── end ──", "DevNullSeparator")
    else
      b:add("No commits.", "DevNullMeta")
    end
  elseif view.kind == "commit" then
    if view.commit then
      render_commit(b, view.commit, { full = true })
      local c = view.commit
      b:add(c.html_url or "", "DevNullLink", c)
      if c.parent_id then
        b:add(string.format("In reply to %s — press %s", c.parent_id, config.options.keymaps.parent), "DevNullMeta", c)
      end
    else
      b:add("Loading…", "DevNullMeta")
    end
  end

  view.owners = b.owners

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, b.lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(b.hls) do
    pcall(vim.api.nvim_buf_add_highlight, buf, ns, h[4], h[1], h[2], h[3])
  end
end

local function commit_under_cursor(buf)
  local view = views[buf]
  if not view then
    return nil
  end
  return view.owners and view.owners[vim.api.nvim_win_get_cursor(0)[1]]
end

local function load_more(buf)
  local view = views[buf]
  if not view or view.kind ~= "user" or view.loading then
    return
  end
  if view.started and not view.next_cursor then
    return notify("no more commits")
  end

  view.loading = true
  view.started = true
  draw(buf)

  api.commits(view.username, { cursor = view.next_cursor, replies = view.replies }, function(err, res)
    view.loading = false
    if err then
      draw(buf)
      -- A missing user is already reported by the profile request.
      if err ~= "not found" then
        notify(err, vim.log.levels.ERROR)
      end
      return
    end
    vim.list_extend(view.commits, res.data or {})
    view.next_cursor = res.meta and res.meta.next_cursor or nil
    draw(buf)
  end)
end

local function refresh(buf)
  local view = views[buf]
  if not view then
    return
  end

  if view.kind == "user" then
    view.commits, view.next_cursor, view.started = {}, nil, false
    api.user(view.username, function(err, res)
      if err then
        return notify(string.format("@%s: %s", view.username, err), vim.log.levels.ERROR)
      end
      view.user = res.data
      draw(buf)
    end)
    load_more(buf)
  else
    view.commit = nil
    draw(buf)
    api.commit(view.id, function(err, res)
      if err then
        return notify(string.format("commit %s: %s", view.id, err), vim.log.levels.ERROR)
      end
      view.commit = res.data
      draw(buf)
    end)
  end
end

local function show_help()
  local k = config.options.keymaps
  local lines = {
    k.open .. "  open commit",
    k.browser .. "  open in browser",
    k.author .. "  open author's profile",
    k.parent .. "  open parent commit",
    k.yank .. "  yank URL",
    k.more .. "  load more",
    k.replies .. "  toggle replies",
    k.refresh .. "  refresh",
    k.close .. "  close",
  }
  notify("\n" .. table.concat(lines, "\n"))
end

local function attach_keymaps(buf)
  local k = config.options.keymaps
  local function map(lhs, fn, desc)
    if lhs then
      vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = "dev-null: " .. desc })
    end
  end

  map(k.open, function()
    local c = commit_under_cursor(buf)
    if c then
      M.open_commit(c.id)
    end
  end, "open commit")

  map(k.browser, function()
    local c = commit_under_cursor(buf)
    local view = views[buf]
    open_url(c and c.html_url or (view.user and view.user.html_url))
  end, "open in browser")

  map(k.author, function()
    local c = commit_under_cursor(buf)
    if c and c.author then
      M.open_user(c.author.username)
    end
  end, "open author")

  map(k.parent, function()
    local c = commit_under_cursor(buf) or views[buf].commit
    if c and c.parent_id then
      M.open_commit(c.parent_id)
    else
      notify("not a reply")
    end
  end, "open parent")

  map(k.yank, function()
    local c = commit_under_cursor(buf)
    local view = views[buf]
    local url = c and c.html_url or (view.user and view.user.html_url)
    if url then
      vim.fn.setreg("+", url)
      vim.fn.setreg('"', url)
      notify("yanked " .. url)
    end
  end, "yank URL")

  map(k.more, function()
    load_more(buf)
  end, "load more")

  map(k.replies, function()
    local view = views[buf]
    if view.kind == "user" then
      view.replies = not view.replies
      refresh(buf)
    end
  end, "toggle replies")

  map(k.refresh, function()
    refresh(buf)
  end, "refresh")

  map(k.close, function()
    vim.api.nvim_buf_delete(buf, { force = true })
  end, "close")

  map(k.help, show_help, "help")
end

local function create_buffer(name, view)
  set_highlights()

  -- Reuse an existing buffer for the same target.
  local existing = vim.fn.bufnr(name)
  if existing ~= -1 and views[existing] then
    local win = vim.fn.bufwinid(existing)
    if win ~= -1 then
      vim.api.nvim_set_current_win(win)
    else
      vim.cmd("buffer " .. existing)
    end
    return existing, false
  end

  local open = config.options.open
  if open == "tab" then
    vim.cmd("tabnew")
  elseif open == "split" then
    vim.cmd("new")
  elseif open == "vsplit" then
    vim.cmd("vnew")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "devnull"
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.conceallevel = 0

  views[buf] = view
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      views[buf] = nil
    end,
  })

  attach_keymaps(buf)
  return buf, true
end

function M.open_user(username)
  username = (username or ""):gsub("^@", "")
  if username == "" then
    return notify("no username given (pass one or set `username` in setup())", vim.log.levels.WARN)
  end
  local buf, fresh = create_buffer("devnull://@" .. username, {
    kind = "user",
    username = username,
    commits = {},
    replies = false,
  })
  if fresh then
    draw(buf)
    refresh(buf)
  end
end

function M.open_commit(id)
  id = (id or ""):match("commits/([%w%-]+)") or id
  if id == "" then
    return notify("no commit id given", vim.log.levels.WARN)
  end
  local buf, fresh = create_buffer("devnull://commit/" .. id, { kind = "commit", id = id })
  if fresh then
    refresh(buf)
  end
end

return M
