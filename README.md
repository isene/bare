# bare - Pure Assembly Shell

<img src="img/bare.svg" align="left" width="150" height="150">

![Version](https://img.shields.io/badge/version-0.1.0-blue) ![Assembly](https://img.shields.io/badge/language-x86__64%20Assembly-purple) ![License](https://img.shields.io/badge/license-Unlicense-green) ![Platform](https://img.shields.io/badge/platform-Linux%20x86__64-blue) ![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen) ![Binary](https://img.shields.io/badge/binary-~92KB-orange) ![Stay Amazing](https://img.shields.io/badge/Stay-Amazing-important)

Interactive shell written in x86_64 Linux assembly. No libc, no runtime, pure syscalls. Single static binary, roughly 92KB. Every feature is hand-coded with direct kernel interaction.

<br clear="left"/>

## Build

```bash
nasm -f elf64 bare.asm -o bare.o && ld bare.o -o bare
```

## Features

### Prompt and Navigation
- Dynamic prompt: `user@host: ~/cwd (git-branch) >`
- Bookmarks with tags (`:bm`), auto-cd from bookmark and directory names
- Directory history (`:dirs`), pushd/popd
- Ctrl-L clear screen, Ctrl-C clear line

### Command Execution
- Multi-pipe support (up to 16 segments)
- Redirections: `>`, `>>`, `<`
- Command chaining: `;`, `&&`, `||`
- Command substitution: `$(cmd)`
- Background execution with `&`
- Command timing for slow commands

### Expansion
- Brace expansion: `{a,b,c}`
- Tilde expansion: `~`, `~/path`
- Variable expansion: `$VAR`, `${VAR}`, `$?`, `$$`
- Glob expansion: `*`, `?`
- History expansion: `!!`, `!N`, `!-N`

### Aliases and Abbreviations
- Nick aliases: `:nick`
- Global aliases: `:gnick`
- Abbreviations: `:abbrev` (expand on space)

### Line Editing and Completion
- Interactive tab cycling with highlighting (TAB/Shift-TAB)
- Ctrl-R reverse incremental history search
- Inline history suggestions (grayed text, right-arrow to accept)
- Ctrl-G edit current line in `$EDITOR`
- Tab completion for commands (PATH search) and files

### Job Control
- Ctrl-Z suspend foreground process
- `:jobs`, `:fg`, `:bg` builtins

### Themes and Colors
- 6 built-in themes: default, solarized, dracula, gruvbox, nord, monokai
- Switch with `:theme <name>`
- 16 individual color settings via `:config c_<name> <value>`

### Configuration
- Config file: `~/.barerc` (line-based key=value format)
- Auto-saved on exit
- History: `~/.bare_history` with smart deduplication
- Companion TUI config tool: [bareconf](https://github.com/isene/bareconf)

### Other
- Signal handling and TTY detection
- Builtins: cd, pwd, exit, export, unset, history

## Part of the Fe2O3 Rust Terminal Suite

| Tool | Clones | Type |
|------|--------|------|
| [bare](https://github.com/isene/bare) / [rush](https://github.com/isene/rush) | [rsh](https://github.com/isene/rsh) | Shell |
| [bareconf](https://github.com/isene/bareconf) | | Shell config TUI |
| [crust](https://github.com/isene/crust) | [rcurses](https://github.com/isene/rcurses) | TUI library |
| [glow](https://github.com/isene/glow) | [termpix](https://github.com/isene/termpix) | Image display |
| [plot](https://github.com/isene/plot) | [termchart](https://github.com/isene/termchart) | Charts |
| [pointer](https://github.com/isene/pointer) | [RTFM](https://github.com/isene/RTFM) | File manager |

## License

[Unlicense](https://unlicense.org/) - public domain.

## Credits

Created by Geir Isene (https://isene.org) with extensive pair-programming with Claude Code.
