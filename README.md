# devnull.nvim

Browse [dev-null.sh](https://dev-null.sh), the social network for developers, without leaving Neovim.

```
@nunomaduro
staff software engineer at @laravel · speaker · content creator
132 commits · 2674 followers · 72 following
────────────────────────────────────────────────────────────

3fdaba9  @nunomaduro · 2h ago   ★ 37  ↩ 8
  tomorrow stream hacking on /dev/null?

f19dc53  @nunomaduro · 4h ago   ★ 23  ↩ 5
  wallpapers? https://dev-null.sh/brand#wallpapers
  ⧉ Brand - /dev/null
  ▣ 1 image
```

It uses the public dev-null.sh API, which is read-only. You can read profiles and commits, but you can't post, star or follow.

## Requirements

- Neovim 0.10+
- `curl`

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "lucianofullstack/devnull.nvim",
  cmd = "DevNull",
  opts = {
    username = "your-github-username",
  },
}
```

Any other plugin manager also works. Without one, call `require("devnull").setup({})` yourself; `setup` is optional.

## Usage

| Command | |
|---|---|
| `:DevNull` | Open the profile of your configured `username` |
| `:DevNull <username>` | Open a user's profile and commits |
| `:DevNull user <username>` | Same as above |
| `:DevNull commit <id or url>` | Open a single commit |

### Keymaps (inside a devnull buffer)

| Key | Action |
|---|---|
| `<CR>` | Open the commit under the cursor |
| `gx` | Open the commit (or profile) in the browser |
| `a` | Open the author's profile |
| `p` | Open the parent commit of a reply |
| `yu` | Yank the URL |
| `]]` | Load the next page |
| `t` | Toggle replies in the timeline |
| `R` | Refresh |
| `q` | Close |
| `g?` | Show keymaps |

## Configuration

Defaults:

```lua
require("devnull").setup({
  base_url = "https://dev-null.sh",
  username = nil,      -- profile opened by a bare :DevNull
  open = "tab",        -- "tab" | "split" | "vsplit" | "current"
  timeout = 10000,     -- ms
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
})
```

Set any keymap to `false` to disable it.

### Highlights

`DevNullTitle`, `DevNullHash`, `DevNullAuthor`, `DevNullMeta`, `DevNullStars`, `DevNullReplies`, `DevNullLink`, `DevNullReply`, `DevNullSeparator`. Each is linked by default to a standard group, so overriding it is easy.

## Limits

The API allows 60 requests per minute per IP. Only approved commits are returned.

## License

MIT © Luciano Federico Pereira
