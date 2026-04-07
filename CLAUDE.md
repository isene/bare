# bare

Interactive shell written in x86_64 Linux assembly. No libc, no runtime, pure syscalls.

## Build

```bash
nasm -f elf64 bare.asm -o bare.o && ld bare.o -o bare
```

## Architecture

- NASM syntax, x86_64 Linux
- Direct syscalls via `syscall` instruction (no libc)
- Static binary (~39KB), no dynamic linking
- All memory management via mmap/brk
- Raw termios for char-by-char input

## Features implemented

- Line editing: left/right arrows, Home/End, Ctrl-A/E/K/U/W, backspace, delete
- History: up/down arrows, persisted to ~/.bare_history
- Builtins: cd, pwd, exit, export, unset, history
- External commands via PATH search
- Pipes: `cmd1 | cmd2`
- Redirections: `>`, `>>`, `<`
- Quoting: single and double quotes
- Tilde expansion: `~`, `~/path`
- Variable expansion: `$VAR`, `${VAR}`, `$?`, `$$`
- Glob expansion: `*`, `?` patterns
- Command chaining: `;`, `&&`, `||`
- Background execution: `&`
- Tab completion: commands (PATH search) and files
- Signal handling: SIGINT ignored in shell, children restore SIG_DFL
- TTY detection: works with piped input

## Key data structures (BSS)

- `line_buf` (4096): current input line
- `argv_ptrs` (128 entries): parsed argument pointers
- `env_array` (256 entries): custom environment (copied from envp at startup, modified by export/unset)
- `env_storage` (8192): storage for exported variables
- `hist_lines` (512 entries): history line pointers
- `hist_buf` (64KB): history content storage
- `expand_buf` (4096): temporary buffer for variable/tilde expansion
- `glob_results` (256 entries): glob match pointers
- `glob_buf` (8192): glob match filename storage
- `comp_matches` (64 entries): tab completion match pointers
- `comp_buf` (4096): tab completion match storage

## Syscalls used

READ, WRITE, OPEN, CLOSE, STAT, IOCTL, PIPE, DUP2, FORK, EXECVE, EXIT, WAIT4, GETCWD, CHDIR, GETDENTS64, GETPID, RT_SIGACTION

## Key code sections

- `_start`: entry point, saves envp, initializes env_array, sets up signals
- `read_line`: raw-mode line editor with escape sequence parsing
- `execute_line`: splits by chains (`;`, `&&`, `||`), delegates to execute_segment
- `execute_segment`: handles pipes, background `&`, delegates to parse_and_exec_simple
- `parse_argv`: tokenizer with quote handling, redirect detection
- `expand_line`: tilde + variable expansion
- `expand_globs`: glob pattern matching via getdents64
- `tab_complete`: PATH search for commands, dir scan for files
- `check_builtin`: cd, pwd, exit, export, unset, history

## Future features

- Multi-pipe (currently only single pipe)
- Here documents (`<<EOF`)
- Subcommand substitution (`$(cmd)` or backticks)
- Job control (fg, bg, jobs)
- Aliases
- .barerc config file
- Prompt customization
