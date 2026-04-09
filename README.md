# bare - Pure Assembly Shell

<img src="img/bare.svg" align="left" width="150" height="150">

![Version](https://img.shields.io/badge/version-0.1.0-blue) ![Assembly](https://img.shields.io/badge/language-x86__64%20Assembly-purple) ![License](https://img.shields.io/badge/license-Unlicense-green) ![Platform](https://img.shields.io/badge/platform-Linux%20x86__64-blue) ![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen) ![Binary](https://img.shields.io/badge/binary-~115KB-orange) ![Stay Amazing](https://img.shields.io/badge/Stay-Amazing-important)

Interactive shell written in x86_64 Linux assembly. No libc, no runtime, pure syscalls. Single static binary, roughly 115KB. Every feature is hand-coded with direct kernel interaction.

Pure syscalls, zero overhead. No interpreter, no runtime, no garbage collector. Just your keystrokes and the kernel.

<br clear="left"/>

## Build

```bash
nasm -f elf64 bare.asm -o bare.o && ld bare.o -o bare
```

## Features

### Prompt and Navigation
- Dynamic prompt: `user@host: ~/cwd/ (git-branch) >`
- Git branch detection (reads `.git/HEAD`, walks up directories)
- Right prompt: command duration display for long-running commands
- Root user detection: separate colors for sudo sessions (`c_user_root`, `c_host_root`)
- Tilde substitution in prompt (`$HOME` shown as `~`)
- Window title via OSC escape sequence
- Bookmarks with tags (`:bm name [path] [#tags]`), tag search (`:bm ?tag`)
- Auto-cd from bookmark names and bare directory names
- Directory history (`:dirs`), `cd N` to jump to Nth entry, `cd -` for previous
- `pushd`/`popd` directory stack

### Command Execution
- Multi-pipe support (up to 16 segments): `cmd1 | cmd2 | cmd3`
- Redirections: `>`, `>>`, `<`
- Command chaining: `;`, `&&`, `||`
- Command substitution: `$(cmd)` with nesting
- Background execution: `&`
- Command timing for slow commands (configurable threshold)
- Login shell support: `-l`/`--login` (sources `/etc/profile`, `~/.profile`)
- Command mode: `-c "cmd"` (execute and exit)

### Expansion
- Brace expansion: `file.{txt,md,rs}` -> `file.txt file.md file.rs`
- Tilde expansion: `~`, `~/path`
- Variable expansion: `$VAR`, `${VAR}`, `$?`, `$$`
- Glob expansion: `*`, `?`
- History expansion: `!!`, `!N`, `!-N`
- Global nick (gnick) expansion anywhere in the command line

### Aliases and Abbreviations
- Nick aliases: `:nick ls = ls --color -F` (expand at execution)
- Global aliases: `:gnick G = | grep` (expand anywhere in line)
- Abbreviations: `:abbrev gst = git status` (expand live on space)
- List, add, delete for all three types

### Line Editing and Completion
- Interactive tab cycling with highlighted selection (TAB/Shift-TAB)
- Ctrl-R reverse incremental history search (substring match)
- Inline history suggestions (grayed preview, right-arrow to accept)
- Prefix history search: type text, press Up/Down to filter matching entries
- `$VAR` tab completion from environment variables
- Subcommand completion for git, apt, cargo
- Ctrl-G edit current line in `$EDITOR` (falls back to vi)
- Ctrl-Y copy line to clipboard (xclip)
- Ctrl-L clear screen, Ctrl-C clear line
- Ctrl-A/E home/end, Ctrl-K kill to end, Ctrl-U clear, Ctrl-W delete word
- Syntax highlighting: commands, colon commands, switches, pipe segments
- Multi-line editing: continuation on `\`, `|`, `&&`, `||`, unclosed quotes
- Auto-pairing brackets and quotes (configurable)
- Tab completion deduplication across PATH directories

### Job Control
- Ctrl-Z suspend foreground process
- `:jobs` list, `:fg [N]` foreground, `:bg [N]` background
- Background job reaping

### Themes and Colors
- 6 built-in themes: default, solarized, dracula, gruvbox, nord, monokai
- Switch with `:theme <name>`
- 18 individual color settings via `:config c_<name> <value>`
- Root-specific colors: `c_user_root`, `c_host_root` (red by default)
- Colors: user, host, cwd, prompt, cmd, nick, gnick, path, switch, bookmark, colon, git, stamp, tabsel, tabopt, suggest

### Configuration
- Config file: `~/.barerc` (line-based key=value format, auto-saved on exit)
- History: `~/.bare_history` with smart deduplication (off/full/smart)
- Settings: `:config key value` for runtime changes
- Boolean toggles: `show_tips`, `auto_correct`, `auto_pair`, `rprompt`
- Numeric: `slow_command_threshold`, `completion_limit`
- Companion TUI configurator: [bareconf](https://github.com/isene/bareconf)

### Plugins

Plugins are executables in `~/.bare/plugins/`. Any unknown colon command runs the matching plugin. Write plugins in any language.

```bash
# Install included plugins
cp plugins/* ~/.bare/plugins/
chmod +x ~/.bare/plugins/*
```

Included plugins:
- `:ask <question>` - ask AI a question (requires OpenAI API key)
- `:suggest <task>` - get a shell command suggestion from AI

See [plugins/README.md](plugins/README.md) for setup and writing your own.

### Other Builtins
- `cd`, `pwd`, `exit`, `export`, `unset`, `history`, `pushd`, `popd`
- `:calc` integer calculator (+, -, *, /, %)
- `:stats` command frequency analysis (top 20 from history)
- `:validate pattern = warn/confirm/block` safety rules
- `:save_session`, `:load_session`, `:list_sessions` session management
- `:env [VAR | set VAR val | unset VAR]` environment management
- `:rehash` rebuild PATH cache, `:reload` reload config
- `:rmhistory` clear history, `:info` feature overview
- `:version`, `:help`
- Auto-correct: suggests similar commands on "command not found"
- Random startup tips (~30% chance, configurable)

## Part of CHasm (CHange to ASM)

The same shell, three languages:

| Shell | Language | Suite |
|-------|----------|-------|
| **[bare](https://github.com/isene/bare)** | **x86_64 Assembly** | **CHasm** |
| [rush](https://github.com/isene/rush) | Rust | Fe2O3 |
| [rsh](https://github.com/isene/rsh) | Ruby | |

Companion: [bareconf](https://github.com/isene/bareconf) (TUI configurator, built on [crust](https://github.com/isene/crust))

## License

[Unlicense](https://unlicense.org/) - public domain.

## Credits

Created by Geir Isene (https://isene.org) with extensive pair-programming with Claude Code.
