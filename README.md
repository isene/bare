# bare - Pure Assembly Shell

<img src="img/bare.svg" align="left" width="150" height="150">

![Version](https://img.shields.io/badge/version-0.2.5-blue) ![Assembly](https://img.shields.io/badge/language-x86__64%20Assembly-purple) ![License](https://img.shields.io/badge/license-Unlicense-green) ![Platform](https://img.shields.io/badge/platform-Linux%20x86__64-blue) ![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen) ![Binary](https://img.shields.io/badge/binary-~126KB-orange) ![Startup](https://img.shields.io/badge/startup-9%C2%B5s-ff6600) ![Stay Amazing](https://img.shields.io/badge/Stay-Amazing-important)

Interactive shell written in x86_64 Linux assembly. No libc, no runtime, pure syscalls. Single static binary, 126KB. **9 microsecond startup.**

Pure syscalls, zero overhead. No interpreter, no runtime, no garbage collector. Just your keystrokes and the kernel.

This is my login shell. It is not released for your use. It is released for inspiration. This is how you can benefit: 1) Clone this repo, 2) Fire up Claude Code, 3) Prompt it to make it into what you want or need.

<br clear="left"/>

## Install

### From source (requires nasm and ld)

```bash
git clone https://github.com/isene/bare.git
cd bare
make
sudo make install
```

### Arch Linux (AUR)

```bash
yay -S bare-shell
```

### Debian/Ubuntu

```bash
curl -LO https://github.com/isene/bare/releases/latest/download/bare_0.2.5-1_amd64.deb
sudo dpkg -i bare_0.2.5-1_amd64.deb
```

### Set as default shell

```bash
# Add to allowed shells
sudo sh -c 'echo /usr/local/bin/bare >> /etc/shells'

# Set as default terminal shell (wezterm)
# In ~/.config/wezterm/wezterm.lua:
config.default_prog = { '/usr/local/bin/bare', '-l' }
```

### Setup

```bash
# Install AI plugins (optional, needs Anthropic API key)
make install-plugins

# Create login profile
cat > ~/.bare_profile << 'EOF'
export PATH=/usr/local/bin:/usr/bin:/bin:$HOME/bin:$HOME/.local/bin
export EDITOR=vim
export PAGER=less
EOF
```

## Benchmark

```
$ ./bare --bench
bare startup: 9 microseconds

$ time ./bare -c exit
./bare -c exit  0.00s user 0.00s system 94% cpu 0.003 total
```

## Features

### Prompt and Navigation
- Dynamic prompt: `user@host: ~/cwd/ (git-branch) >` with configurable colors
- Git dirty indicator: green dot (clean) / red dot (uncommitted changes)
- Git branch display (toggleable via `show_git_branch`)
- Root user detection: separate colors for sudo sessions
- Bookmarks with tags (`:bm name [path] [#tags]`), tag search (`:bm ?tag`)
- Auto-cd from bookmark names and bare directory names
- Directory history (`:dirs`), `cd N` to jump, `cd -` for previous
- `pushd`/`popd` directory stack
- Pointer/RTFM file manager auto-cd on exit

### Command Execution
- Multi-pipe (up to 16 segments): `cmd1 | cmd2 | cmd3`
- Redirections: `>`, `>>`, `<`
- Command chaining: `;`, `&&`, `||`
- Command substitution: `$(cmd)` with nesting
- Background execution: `&`
- `time` builtin: `time sleep 1` shows elapsed with ms precision
- Login shell (`-l`), command mode (`-c "cmd"`)

### Expansion
- Brace expansion: `file.{txt,md,rs}` -> `file.txt file.md file.rs`
- Tilde, variable (`$VAR`, `${VAR}`, `$?`, `$$`), glob (`*`, `?`, `[a-z]`, `[!x]`)
- History expansion: `!!`, `!N`, `!-N`
- Global nick expansion anywhere in line

### Aliases and Abbreviations
- `:nick ls = ls --color -F` (expand at execution, self-referencing works)
- `:gnick G = | grep` (expand anywhere in line)
- `:abbrev gst = git status` (expand live on space)

### Line Editing and Completion
- Interactive tab cycling with LS_COLORS (dirs blue, symlinks gray)
- Tab completion for `:commands` (`:th<TAB>` -> `:theme`)
- `$VAR` tab completion, subcommand completion (git, apt, cargo)
- Ctrl-R reverse incremental history search
- Inline history suggestions (grayed preview, right-arrow to accept)
- Prefix history search: type text, press Up/Down to filter
- Alt-F / Alt-B: word movement forward/backward
- Ctrl-G edit in `$EDITOR`, Ctrl-Y copy to clipboard
- Syntax highlighting: valid commands (green), nicks (cyan), colon commands, switches
- Multi-line editing: continuation on `\`, `|`, `&&`, `||`, unclosed quotes
- Auto-pairing brackets and quotes (configurable)

### Job Control
- Ctrl-Z suspend, `:jobs`, `:fg [N]`, `:bg [N]`

### Themes and Colors
- 6 themes: default, solarized, dracula, gruvbox, nord, monokai
- 18 individual color settings including root-specific colors
- Companion TUI configurator: [bareconf](https://github.com/isene/bareconf)

### Configuration
- `~/.barerc`: auto-saved on exit, line-based key=value format (multi-terminal safe)
- `~/.bare_profile`: login profile (simple export lines)
- `~/.bare_history`: capped at 1000 entries, smart deduplication
- Runtime changes: `:config key value`
- Toggles: show_tips, auto_correct, auto_pair, rprompt, show_git_branch, completion_fuzzy

### Plugins

Plugins are executables in `~/.bare/plugins/`. Any unknown colon command runs the matching plugin.

```bash
make install-plugins    # installs :ask and :suggest (AI via Anthropic API)
```

- `:ask <question>` - ask AI a question
- `:suggest <task>` - get a shell command suggestion

See [plugins/README.md](plugins/README.md) for setup and writing your own.

### Other Builtins
- `cd`, `pwd`, `exit`, `export`, `unset`, `history`, `pushd`, `popd`, `time`
- `:calc`, `:stats`, `:validate`, `:save_session`, `:load_session`
- `:save`, `:backup [name]`, `:restore [name]` (config/history snapshots)
- `:env`, `:rehash`, `:reload`, `:rmhistory`, `:info`, `:version`, `:help`
- Auto-correct suggestions on command not found
- Startup tips (configurable)

## Part of CHasm (CHange to ASM)

The same shell, three languages:

| Shell | Language | Startup | Suite |
|-------|----------|---------|-------|
| **[bare](https://github.com/isene/bare)** | **x86_64 Assembly** | **9us** | **CHasm** |
| [rush](https://github.com/isene/rush) | Rust | ~26ms | Fe2O3 |
| [rsh](https://github.com/isene/rsh) | Ruby | ~300ms | |

Companion: [bareconf](https://github.com/isene/bareconf) (TUI configurator, built on [crust](https://github.com/isene/crust))

## License

[Unlicense](https://unlicense.org/) - public domain.

## Credits

Created by Geir Isene (https://isene.org) with extensive pair-programming with Claude Code.
