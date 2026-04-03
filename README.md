# Zushi

A minimal ZSH theme with rich git integration.

No framework required — just source it in your `.zshrc`.

## Features

### Left prompt
- `⌘` on macOS, `λ` on Linux — 🔴 success, ⚫ failure
- Git branch name (short ref in detached HEAD)
- Status indicators:
  - ⚫ untracked files only
  - ⚪ dirty (tracked modifications)
  - 🟡 staged + dirty or untracked
  - 🟢 staged, clean (ready to commit)
  - 🟠 stash
- `+N` / `-N` ahead/behind upstream
- SSH `(user:host)` prefix

### Right prompt
- ⏱️ Command duration
- 🔗 GitHub PR number (requires `gh` CLI)
- 🐙 Git repo name (opens editor) + subpath (opens Finder)
- 🌳 Git worktree name (opens editor) + subpath (opens Finder)
- 🗂️ Path (opens Finder)
- Paths truncated to configurable depth

### Other
- `⏎` EOL mark

## Configuration

Set these in your `.zshrc` before the theme is loaded:

| Variable | Default | Description |
|----------|---------|-------------|
| `ZUSHI_PR_CACHE_TTL` | `300` | Seconds before PR info is refreshed |
| `ZUSHI_DURATION_THRESHOLD_MS` | `300` | Minimum milliseconds before duration is shown |
| `ZUSHI_PATH_MAX_DEPTH` | `3` | Max directory depth before truncating with `...` |
| `ZUSHI_EDITOR_URL` | auto-detected | URL template for clicking repo name (`%s` = path). Auto-detects Cursor, VS Code, Zed, JetBrains, Sublime. Override: `cursor://file%s`, `jetbrains://open?file=%s`, etc. |
| `ZUSHI_GREETING` | `uname -npsr` output | Greeting message on new session. Set to empty to disable |
| `ZUSHI_GH_ENABLED` | `1` | Set to `0` to disable GitHub PR integration |

## Dependencies

- **Required**: ZSH
- **Optional**: [`gh`](https://cli.github.com/) CLI — for showing PR numbers in the right prompt

## Install

### Oh My Zsh

```zsh
git clone https://github.com/alyyousuf7/theme-zushi.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/theme-zushi
```

Then set the theme in your `~/.zshrc`:

```zsh
ZSH_THEME="theme-zushi/zushi"
```

### Manual

```zsh
git clone https://github.com/alyyousuf7/theme-zushi.git ~/.zsh/theme-zushi
echo 'source ~/.zsh/theme-zushi/zushi.zsh-theme' >> ~/.zshrc
source ~/.zshrc
```