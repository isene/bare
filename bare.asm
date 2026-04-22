; bare - interactive shell in x86_64 Linux assembly
; No libc. Pure syscalls. Bare metal.
;
; Build: nasm -f elf64 bare.asm -o bare.o && ld bare.o -o bare

BITS 64
DEFAULT REL

; ── Syscall numbers ──────────────────────────────────────────────────
%define SYS_READ      0
%define SYS_WRITE     1
%define SYS_OPEN      2
%define SYS_CLOSE     3
%define SYS_STAT      4
%define SYS_FSTAT     5
%define SYS_LSEEK     8
%define SYS_MMAP      9
%define SYS_MPROTECT  10
%define SYS_MUNMAP    11
%define SYS_BRK       12
%define SYS_IOCTL     16
%define SYS_POLL      7
%define POLLIN        1
%define SYS_PIPE      22
%define SYS_DUP2      33
%define SYS_FORK      57
%define SYS_EXECVE    59
%define SYS_EXIT      60
%define SYS_WAIT4     61
%define SYS_KILL      62
%define SYS_GETCWD    79
%define SYS_CHDIR     80
%define SYS_GETDENTS64 217
%define SYS_GETPID    39
%define SYS_GETUID    102
%define SYS_GETGID    104
%define SYS_SETPGID   109
%define SYS_GETPGID   121
%define SYS_GETPPID   110
%define SYS_TCSETPGRP 0  ; via ioctl
%define SYS_RT_SIGACTION 13
%define SYS_RT_SIGPROCMASK 14

; ioctl constants
%define TCGETS     0x5401
%define TCSETS     0x5402
%define TCSETSW    0x5403
%define TIOCSPGRP  0x5410
%define TIOCGPGRP  0x5411

; termios flags
%define ICANON  0x2
%define ECHO    0x8
%define ISIG    0x1
%define ECHOCTL 0x200
%define VMIN   6
%define VTIME  5

; open flags
%define O_RDONLY  0
%define O_WRONLY  1
%define O_RDWR    2
%define O_CREAT   0x40
%define O_TRUNC   0x200
%define O_APPEND  0x400
%define O_DIRECTORY 0x10000

; signal constants
%define SIGINT  2
%define SIGQUIT 3
%define SIGWINCH 28
%define SA_RESTORER 0x04000000
%define SYS_RT_SIGRETURN 15
%define SIGCONT 18
%define SIGTSTP 20
%define SIGTTIN 21
%define SIGTTOU 22
%define SIGCHLD 17
%define SIGHUP  1
%define SIGTERM 15
%define SIG_IGN 1
%define SIG_DFL 0

; wait flags
%define WUNTRACED 2
%define WNOHANG   1

; dirent64 structure offsets
%define DIRENT64_D_INO     0
%define DIRENT64_D_OFF     8
%define DIRENT64_D_RECLEN  16
%define DIRENT64_D_TYPE    18
%define DIRENT64_D_NAME    19

; Max constants
%define MAX_ENV_ENTRIES 256
%define MAX_ENV_STORAGE 16384
%define MAX_GLOB_RESULTS 256
%define MAX_GLOB_BUF 16384
%define MAX_TAB_RESULTS 128
%define MAX_NICKS 64
%define MAX_NICK_STORAGE 8192
%define MAX_GNICKS 64
%define MAX_GNICK_STORAGE 4096
%define MAX_ABBREVS 64
%define MAX_ABBREV_STORAGE 4096
%define MAX_BOOKMARKS 64
%define MAX_BM_STORAGE 8192
%define MAX_DIR_HISTORY 64
%define MAX_PIPE_SEGMENTS 16
%define MAX_JOBS 32

; Color setting indices
%define C_USER     0
%define C_HOST     1
%define C_CWD      2
%define C_PROMPT   3
%define C_CMD      4
%define C_NICK     5
%define C_GNICK    6
%define C_PATH     7
%define C_SWITCH   8
%define C_BOOKMARK 9
%define C_COLON    10
%define C_GIT      11
%define C_STAMP    12
%define C_TABSEL   13
%define C_TABOPT   14
%define C_SUGGEST  15
%define C_USER_ROOT 16
%define C_HOST_ROOT 17
%define NUM_COLORS 18

; Config flag bits
%define CFG_AUTO_CORRECT      0
%define CFG_COMPLETION_FUZZY  1
%define CFG_RPROMPT           2
%define CFG_AUTO_PAIR         3
%define CFG_SHOW_TIPS         4
%define CFG_SHOW_CMD          5
%define CFG_HIST_DEDUP_FULL   6
%define CFG_HIST_DEDUP_SMART  7
%define CFG_SHOW_GIT_BRANCH   8
%define CFG_GIT_STATUS_FORK   9

; Syscalls for timing and terminal size
%define SYS_CLOCK_GETTIME 228
%define CLOCK_MONOTONIC   1

; TIOCGWINSZ ioctl
%define TIOCGWINSZ 0x5413

; ── Data section ─────────────────────────────────────────────────────
section .data

prompt_str:     db 27, '[1m', 27, '[38;5;39m'  ; bold + blue
prompt_user:    db 'bare', 27, '[0m'            ; reset
prompt_sep:     db 27, '[38;5;245m', '> ', 27, '[0m'  ; gray >
prompt_len      equ $ - prompt_str

newline:        db 10
space_char:     db ' '
err_fork:       db "bare: fork failed", 10
err_fork_len    equ $ - err_fork
err_exec:       db "bare: command not found: "
err_exec_len    equ $ - err_exec
err_usage_bare:
    db "Usage: bare [-l|--login] [-c command] [--bench] [--help]", 10
    db "Interactive shell in x86_64 Linux assembly. No libc, pure syscalls.", 10
err_usage_bare_len equ $ - err_usage_bare
err_cd:         db "bare: cd: no such directory", 10
err_cd_len      equ $ - err_cd
err_pipe:       db "bare: pipe failed", 10
err_pipe_len    equ $ - err_pipe
err_export:     db "bare: export: invalid format", 10
err_export_len  equ $ - err_export

; Builtin command strings
str_cd:         db "cd", 0
str_exit:       db "exit", 0
str_pwd:        db "pwd", 0
str_export:     db "export", 0
str_unset:      db "unset", 0
str_history:    db "history", 0

; Colon command strings
str_nick:       db ":nick", 0
str_gnick:      db ":gnick", 0
str_abbrev:     db ":abbrev", 0
str_bm:         db ":bm", 0
str_dirs:       db ":dirs", 0
str_rmhistory:  db ":rmhistory", 0
str_rehash:     db ":rehash", 0
str_reload:     db ":reload", 0
str_theme:      db ":theme", 0
str_calc:       db ":calc", 0
str_stats:      db ":stats", 0
str_jobs:       db ":jobs", 0
str_fg:         db ":fg", 0
str_bg:         db ":bg", 0
str_env:        db ":env", 0
str_config:     db ":config", 0
str_validate:   db ":validate", 0
str_save_sess:  db ":save_session", 0
str_load_sess:  db ":load_session", 0
str_list_sess:  db ":list_sessions", 0
str_del_sess:   db ":delete_session", 0
str_record:     db ":record", 0
str_replay:     db ":replay", 0
str_save:       db ":save", 0
str_backup:     db ":backup", 0
str_restore:    db ":restore", 0
str_version:    db ":version", 0
str_info:       db ":info", 0
str_help:       db ":help", 0
str_time:       db "time", 0
str_pushd:      db "pushd", 0
str_popd:       db "popd", 0

; Colon command dispatch table: pairs of (string_ptr, handler_ptr), sentinel (0,0)
colon_dispatch_table:
    dq str_nick, handle_nick
    dq str_gnick, handle_gnick
    dq str_abbrev, handle_abbrev
    dq str_bm, handle_bm
    dq str_dirs, handle_dirs
    dq str_rmhistory, handle_rmhistory
    dq str_rehash, handle_rehash
    dq str_reload, handle_reload
    dq str_version, handle_version
    dq str_help, handle_help
    dq str_jobs, handle_jobs
    dq str_fg, handle_fg
    dq str_bg, handle_bg
    dq str_theme, handle_theme
    dq str_env, handle_env
    dq str_config, handle_config
    dq str_calc, handle_calc
    dq str_stats, handle_stats
    dq str_validate, handle_validate
    dq str_info, handle_info
    dq str_save, handle_save
    dq str_backup, handle_backup
    dq str_restore, handle_restore
    dq str_save_sess, handle_save_session
    dq str_load_sess, handle_load_session
    dq str_list_sess, handle_list_sessions
    dq 0, 0

; Version string
version_str:    db "bare 0.2.21", 10, 0
version_str_len equ $ - version_str - 1

; Config file suffix
config_suffix:  db "/.barerc", 0

; State file suffix
state_suffix:   db "/.barestate", 0

; PATH executable cache file (persists exe_cache between sessions so we
; can skip the ~600ms PATH directory scan on every shell startup).
exec_cache_suffix: db "/.bare_exe_cache", 0

; Error messages for new features
err_nick:       db "bare: nick: usage: :nick name = value", 10
err_nick_len    equ $ - err_nick
err_bm:         db "bare: bm: usage: :bm [name] [path] [#tags]", 10
err_bm_len      equ $ - err_bm

; Prompt components
prompt_at:      db "@", 0
prompt_colon:   db ": ", 0
prompt_arrow:   db "> ", 0
prompt_git_open: db " (", 0
prompt_git_close: db ")", 0
prompt_tilde:   db "~", 0
git_head_prefix: db "ref: refs/heads/", 0
git_head_file:  db "/.git/HEAD", 0
dot_git_dir:    db ".git", 0
etc_hostname:   db "/etc/hostname", 0

; Nick display
nick_arrow:     db " = ", 0

; Clear screen sequence
clear_screen_seq: db 27, "[2J", 27, "[H"
clear_screen_len equ $ - clear_screen_seq

; Clear to end of line (used for suggestion cleanup)
clr_eol_global: db 27, "[K"
clr_eol_len equ $ - clr_eol_global

; Color themes: each is NUM_COLORS bytes in order of C_* constants
; Indices: user, host, cwd, prompt, cmd, nick, gnick, path, switch, bookmark, colon, git, stamp, tabsel, tabopt, suggest
theme_names:
    dq .tn_default, .tn_solarized, .tn_dracula, .tn_gruvbox, .tn_nord, .tn_monokai
    dq 0
.tn_default:   db "default", 0
.tn_solarized: db "solarized", 0
.tn_dracula:   db "dracula", 0
.tn_gruvbox:   db "gruvbox", 0
.tn_nord:      db "nord", 0
.tn_monokai:   db "monokai", 0

theme_data:
; default:    user host cwd  prompt cmd nick gnick path switch bm  colon git stamp tabsel tabopt suggest
; Indices: user host cwd prompt cmd nick gnick path switch bm colon git stamp tabsel tabopt suggest user_root host_root
.td_default:   db 2,  2,  81, 208, 48,  6,  33,   3,   6,    5,  4,   208, 245,  7,   245,  240, 196, 196
.td_solarized: db 64, 64, 37, 136, 33,  37, 33,   136, 37,   125,33,  166, 245,  7,   245,  240, 196, 196
.td_dracula:   db 84, 84, 141,212, 84,  117,189,  228, 117,  212,189, 215, 245,  7,   245,  240, 196, 196
.td_gruvbox:   db 142,142,214,208, 142, 108,109,  223, 108,  175,109, 208, 245,  7,   245,  240, 196, 196
.td_nord:      db 110,110,111,173, 110, 110,111,  222, 110,  139,111, 173, 245,  7,   245,  240, 196, 196
.td_monokai:   db 148,148,81, 208, 148, 81, 141,  228, 81,   197,141, 208, 245,  7,   245,  240, 196, 196

; :info text
info_text:
    db 27, "[38;5;48m"
    db "  _                       ", 10
    db " | |__   __ _ _ __ ___    ", 10
    db " | '_ \ / _` | '__/ _ \   ", 10
    db " | |_) | (_| | | |  __/   ", 10
    db " |_.__/ \__,_|_|  \___|   ", 10
    db 27, "[0m", 10
    db "  Interactive shell in x86_64 Linux assembly", 10
    db "  No libc, no runtime, pure syscalls. Part of CHasm.", 10, 10
    db "  Features: dynamic prompt with git dirty indicator, multi-pipe, command substitution,", 10
    db "  brace/history/glob expansion (including **), nick/gnick/abbrev aliases, bookmarks,", 10
    db "  interactive tab cycling with LS_COLORS, switch completion from --help, Ctrl-R search,", 10
    db "  inline suggestions, job control, 6 color themes, syntax highlighting, here-strings,", 10
    db "  auto-pair brackets, multi-line editing, calculator, backslash-space file escaping,", 10
    db "  SIGWINCH resize handling, UTF-8 cursor movement, config persistence, and more.", 10, 10
    db "  Config: ~/.barerc    History: ~/.bare_history    Plugins: ~/.bare/plugins/", 10
    db "  Companion: bareconf (TUI configurator)    Website: https://isene.org", 10, 10
info_text_len equ $ - info_text

; Startup tips
tip_count equ 8
tip_table:
    dq .tip0, .tip1, .tip2, .tip3, .tip4, .tip5, .tip6, .tip7
.tip0: db "Tip: Use :nick to create command aliases", 10, 0
.tip1: db "Tip: Ctrl-R searches history interactively", 10, 0
.tip2: db "Tip: Type a directory name to auto-cd into it", 10, 0
.tip3: db "Tip: :bm name saves a bookmark, type its name to jump", 10, 0
.tip4: db "Tip: :theme dracula/gruvbox/nord/solarized/monokai", 10, 0
.tip5: db "Tip: $(cmd) for command substitution, {a,b,c} for braces", 10, 0
.tip6: db "Tip: :abbrev gs = git status (expands on space)", 10, 0
.tip7: db "Tip: Ctrl-Z suspends, :jobs lists, :fg resumes", 10, 0

; Plugin path suffix
plugin_suffix:  db "/.bare/plugins/", 0

; Default PATH for searching executables
default_path:   db "/usr/local/bin:/usr/bin:/bin", 0

; Shell name for display
shell_name:     db "bare", 0

; History file path suffix
hist_suffix:    db "/.bare_history", 0

; Background job message
bg_open:        db "[", 0
bg_close:       db "]", 10, 0
bg_jobsep:      db "] ", 0

; Dot and dotdot for filtering directory entries
dot_name:       db ".", 0
dotdot_name:    db "..", 0

section .bss

; TTY flag (1 if stdin is a terminal, 0 if pipe)
is_tty:         resq 1

; Input buffer
input_buf:      resb 4096
input_len:      resq 1

; Line editing buffer (16KB to handle large exports like LS_COLORS)
line_buf:       resb 16384
line_len:       resq 1
cursor_pos:     resq 1

; Argument parsing
argv_ptrs:      resq 128        ; max 128 args

; Leading-env prefix support: `VAR=val [VAR2=val2 ...] cmd args`.
; Detected after parse_argv; applied in the child between fork and
; execve so the parent's env stays clean (matches bash semantics).
env_prefix_ptrs: resq 16
env_prefix_count: resq 1
argc:           resq 1

; Working directory
cwd_buf:        resb 4096

; Path search buffer
path_buf:       resb 4096
exec_path:      resb 4096

; Environment pointer (saved from stack at entry)
envp:           resq 1

; Original termios (for raw mode toggle)
orig_termios:   resb 60
raw_termios:    resb 60

; History
hist_buf:       resb 524288     ; 512KB history buffer
hist_lines:     resq 8192       ; pointers to history lines
hist_count:     resq 1
hist_persisted: resq 1          ; entries already written to disk; save
                                ; appends only newer ones so concurrent
                                ; bare instances don't overwrite each
                                ; other's history
hist_pos:       resq 1          ; current position when browsing
hist_path:      resb 256        ; full path to history file

; Pipe file descriptors
pipe_fds:       resd 2

; Temp buffers
tmp_buf:        resb 4096
num_buf:        resb 32

; Redirect filenames
redir_out:      resq 1          ; pointer to output redirect filename
redir_in:       resq 1          ; pointer to input redirect filename
redir_herestring: resq 1       ; pointer to here-string content (<<<)
redir_append:   resq 1          ; 1 if >>, 0 if >

; Signal handling
child_pid:      resq 1

; ── New BSS for added features ───────────────────────────────────────

; Last exit status for $? and && / ||
last_status:    resq 1

; Expand buffer (tilde + env var expansion)
expand_buf:     resb 4096

; Custom environment array and storage (for export/unset)
env_array:      resq MAX_ENV_ENTRIES    ; pointers to "VAR=VALUE" strings
env_count:      resq 1                  ; number of entries
env_storage:    resb MAX_ENV_STORAGE    ; storage for new entries
env_storage_pos: resq 1                ; next free byte in env_storage
env_inited:     resq 1                 ; 1 if env_array has been initialized

; Glob expansion
glob_results:   resq MAX_GLOB_RESULTS  ; pointers to matched filenames
glob_count:     resq 1
glob_buf:       resb MAX_GLOB_BUF      ; storage for matched filenames
glob_buf_pos:   resq 1
glob_dir_buf:   resb 4096              ; buffer for getdents64
glob_path_buf:  resb 4096              ; temp for building paths
glob_queue:     resb 32768             ; BFS queue for ** glob (null-separated dir paths)
glob_queue_wpos: resq 1               ; write position in queue
glob_queue_rpos: resq 1               ; read position in queue

; Expanded argv (after glob expansion)
expanded_argv:  resq 512               ; expanded argv array
expanded_argc:  resq 1

; Tab completion
tab_results:    resq MAX_TAB_RESULTS   ; matching completions
tab_types:      resb MAX_TAB_RESULTS   ; file type for each match (d_type)
tab_count:      resq 1
tab_buf:        resb 8192              ; storage for tab matches
tab_buf_pos:    resq 1
tab_word_buf:   resb 256               ; current word being completed
csi_params:     resb 32                ; collected CSI parameter bytes
csi_param_len:  resq 1                 ; live count (rcx is clobbered by syscall)
tab_saved_dtype: resb 1               ; d_type from last file match
tab_dir_buf:    resb 4096              ; directory listing buffer

; Chain parsing
chain_cmds:     resq 64                ; pointers to individual commands
chain_ops:      resb 64                ; operator: 0=none, 1=;, 2=&&, 3=||
chain_count:    resq 1

; PID cache
my_pid:         resq 1

; ── Config system BSS ───────────────────────────────────────────────

; Config file buffer
config_buf:     resb 16384

; Nick aliases (command aliases)
nick_names:     resq MAX_NICKS          ; pointers to name strings
nick_values:    resq MAX_NICKS          ; pointers to expansion strings
nick_count:     resq 1
nick_storage:   resb MAX_NICK_STORAGE
nick_storage_pos: resq 1               ; next free byte in storage

; Global nick aliases
gnick_names:    resq MAX_GNICKS
gnick_values:   resq MAX_GNICKS
gnick_count:    resq 1
gnick_storage:  resb MAX_GNICK_STORAGE
gnick_storage_pos: resq 1

; Abbreviations
abbrev_names:   resq MAX_ABBREVS
abbrev_values:  resq MAX_ABBREVS
abbrev_count:   resq 1
abbrev_storage: resb MAX_ABBREV_STORAGE
abbrev_storage_pos: resq 1

; Bookmarks
bm_names:       resq MAX_BOOKMARKS      ; name strings
bm_paths:       resq MAX_BOOKMARKS      ; path strings
bm_tags:        resq MAX_BOOKMARKS      ; tag strings (space-separated)
bm_count:       resq 1
bm_storage:     resb MAX_BM_STORAGE

; Color settings (256-color codes, one byte each)
color_settings: resb NUM_COLORS

; Config flags (bitfield)
config_flags:   resq 1

; Completion limit
completion_limit: resq 1

; Slow command threshold (seconds, 0 = disabled)
slow_cmd_threshold: resq 1

; Directory history
dir_history:    resq MAX_DIR_HISTORY    ; pointers to path strings
dir_hist_count: resq 1
dir_hist_storage: resb 8192
dir_hist_pos:   resq 1                 ; next free byte in storage

; Directory stack (pushd/popd)
dir_stack:      resq 32
dir_stack_count: resq 1
dir_stack_storage: resb 4096

; Multi-pipe support
pipe_segments:  resq MAX_PIPE_SEGMENTS  ; pointers to pipe segments
pipe_seg_count: resq 1
pipe_fds_array: resd 32                 ; 16 pipes x 2 fds
pipe_child_pids: resq MAX_PIPE_SEGMENTS

; Job control
job_pids:       resq MAX_JOBS
job_pgids:      resq MAX_JOBS
job_status:     resq MAX_JOBS           ; 0=running, 1=stopped, 2=done
job_cmds:       resq MAX_JOBS           ; pointers to command strings
job_count:      resq 1
job_cmd_storage: resb 4096

; Prompt building
hostname_buf:   resb 256
username_buf:   resb 64
prompt_build_buf: resb 1024
git_branch_buf: resb 128
git_head_buf:   resb 256
term_width:     resq 1
rprompt_buf:    resb 256

; Command timing
cmd_start_time: resq 2                  ; tv_sec, tv_nsec
cmd_end_time:   resq 2

; Command frequency tracking
cmd_freq_names: resq 128
cmd_freq_counts: resq 128
cmd_freq_count: resq 1
cmd_freq_storage: resb 8192

; Config file path
config_path:    resb 256

; PATH exe cache file path
exec_cache_path: resb 256

; Command-line flags
login_flag:     resq 1              ; 1 if -l/--login
cmd_flag:       resq 1              ; pointer to -c command string
time_flag:      resq 1              ; 1 if "time" prefix was used
git_status_cached: resb 1           ; cached git dirty result (0=clean, 1=dirty)
git_status_cache_time: resq 1       ; monotonic time of last fork check
git_root_buf:   resb 4096           ; path to git repo root (where .git/ is)
git_root_prev:  resb 4096           ; previous git root (to detect repo change)

; Previous directory for cd -
prev_dir:       resb 4096

; Prompt visible width (characters, excluding ANSI escapes)
prompt_visible_width: resq 1

; Nick expansion buffer
nick_expand_buf: resb 4096

; Command substitution
subst_buf:      resb 8192
subst_tmp:      resb 4096

; Brace expansion
brace_buf:      resb 4096

; History search
search_buf:     resb 256
search_len:     resq 1
rs_skip_count:  resq 1              ; how many matches to skip (Ctrl-R again)

; Prefix history search (Up/Down with typed prefix)
hist_prefix_buf: resb 256           ; saved prefix for Up/Down search
hist_prefix_len: resq 1             ; length of prefix (0 = no prefix search)

; Inline suggestion
suggestion_buf: resb 4096
suggestion_ptr: resq 1              ; pointer to suggestion remainder
suggestion_len: resq 1              ; length of suggestion

; Undo stack (4 snapshots of line_buf)
undo_stack:     resb 16384
undo_lens:      resq 4
undo_positions: resq 4
undo_count:     resq 1

; Validation rules
valid_patterns: resq 32
valid_actions:  resb 32                 ; 0=warn, 1=confirm, 2=block
valid_count:    resq 1
valid_storage:  resb 4096

; Config save timestamp (to prevent overwriting newer config from another terminal)
config_save_time: resq 1

; Switch completion buffers
switch_cmd_buf:  resb 256               ; command name extracted from line
switch_help_buf: resb 16384             ; captured --help output
switch_tmp_buf:  resb 64                ; temp buffer for switch dedup

; Executable cache for syntax highlighting
exe_cache:      resb 65536              ; cached executable names (null-separated)
exe_cache_pos:  resq 1                  ; current write position
exe_cache_count: resq 1                 ; number of cached names

; Render buffer for batched screen output (single write per redraw)
render_buf:     resb 16384
render_pos:     resq 1
render_to_buf:  resq 1              ; flag: 1 = write prompt to render_buf
sigwinch_flag:  resq 1              ; set by SIGWINCH handler
tz_offset:      resq 1              ; timezone offset in seconds from UTC
shl_output_len: resq 1              ; syntax_highlight_line output length

; Session buffer
session_buf:    resb 16384

section .text
global _start

; ══════════════════════════════════════════════════════════════════════
; Entry point
; ══════════════════════════════════════════════════════════════════════
_start:
    ; Record startup time for --bench
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    mov rsi, rsp
    syscall
    mov rax, [rsp]
    mov [cmd_start_time], rax     ; reuse cmd_start_time for startup
    mov rax, [rsp + 8]
    mov [cmd_start_time + 8], rax
    add rsp, 16

    ; Save environment pointer from stack
    ; Stack layout: [argc] [argv...] [NULL] [envp...] [NULL]
    mov rdi, [rsp]          ; argc
    lea rsi, [rsp + 8]      ; argv
    ; Skip past argv to envp
    lea rax, [rdi + 1]
    lea rcx, [rsi + rax*8]  ; envp
    mov [envp], rcx

    ; Parse command-line flags (-l/--login, -c "cmd")
    mov qword [login_flag], 0
    mov qword [cmd_flag], 0
    cmp rdi, 1
    jle .no_args
    ; Check argv[1]
    mov rax, [rsi + 8]       ; argv[1]
    test rax, rax
    jz .no_args
    cmp word [rax], '-l'
    jne .check_login_long
    cmp byte [rax + 2], 0
    je .set_login
.check_login_long:
    cmp dword [rax], '--lo'
    jne .check_help
    mov qword [login_flag], 1
    jmp .no_args
.check_help:
    cmp dword [rax], '--he'
    jne .check_bench
    ; Print help text and exit (no config save)
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [err_usage_bare]
    mov rdx, err_usage_bare_len
    syscall
    xor edi, edi
    mov rax, SYS_EXIT
    syscall

.check_bench:
    cmp dword [rax], '--be'
    jne .check_c_flag
    cmp word [rax+4], 'nc'
    jne .check_c_flag
    cmp byte [rax+6], 'h'
    jne .check_c_flag
    ; Benchmark mode: measure and print startup time
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    mov rsi, rsp
    syscall
    ; Calculate elapsed: (end_sec - start_sec) * 1000000 + (end_nsec - start_nsec) / 1000
    mov rax, [rsp]
    sub rax, [cmd_start_time]
    imul rax, 1000000         ; seconds to microseconds
    mov rcx, [rsp + 8]
    sub rcx, [cmd_start_time + 8]
    push rax
    mov rax, rcx
    xor edx, edx
    mov rcx, 1000
    cqo
    idiv rcx                  ; nanoseconds to microseconds
    pop rcx
    add rax, rcx              ; total microseconds
    add rsp, 16
    ; Print result
    push rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.bench_pre]
    mov rdx, .bench_pre_len
    syscall
    pop rax
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.bench_post]
    mov rdx, .bench_post_len
    syscall
    xor edi, edi
    mov rax, SYS_EXIT
    syscall
.bench_pre: db "bare startup: "
.bench_pre_len equ $ - .bench_pre
.bench_post: db " microseconds", 10
.bench_post_len equ $ - .bench_post

.check_c_flag:
    cmp word [rax], '-c'
    jne .no_args
    cmp byte [rax + 2], 0
    jne .no_args
    ; -c mode: argv[2] is the command
    mov rax, [rsi + 16]
    mov [cmd_flag], rax
    jmp .no_args
.set_login:
    mov qword [login_flag], 1
.no_args:

    ; Get and cache PID
    mov rax, SYS_GETPID
    syscall
    mov [my_pid], rax

    ; Initialize custom environment
    call init_env_array

    ; Initialize default colors
    call init_default_colors

    ; Build config file path and load config
    call build_config_path
    call load_config

    ; Initialize username and hostname for prompt
    call init_username
    call init_hostname
    call init_timezone

    ; Check if stdin is a TTY (ioctl TCGETS succeeds only on ttys)
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCGETS
    lea rdx, [orig_termios]
    syscall
    test rax, rax
    js .not_tty
    mov qword [is_tty], 1
    jmp .tty_done
.not_tty:
    mov qword [is_tty], 0
.tty_done:

    ; Save original terminal settings
    call save_termios

    ; Ignore SIGINT in the shell process (children will restore it)
    call setup_signals

    ; Build history file path
    call build_hist_path

    ; Load history from file
    call load_history

    ; Get initial working directory
    call update_cwd

    ; PATH executable cache: try the persistent cache first (~few ms).
    ; Fall back to a full PATH scan only if the cache file is missing
    ; or invalid; init_exe_cache writes the cache so this happens at
    ; most once per machine (and on `:rehash`).
    call build_exec_cache_path
    call load_exec_cache
    test rax, rax
    jnz .have_exe_cache
    call init_exe_cache
.have_exe_cache:

    ; Initialize last_status
    mov qword [last_status], 0

    ; Handle -c command mode
    cmp qword [cmd_flag], 0
    je .no_cmd_mode
    ; Execute the command and exit
    mov rsi, [cmd_flag]
    lea rdi, [line_buf]
    xor rcx, rcx
.cmd_copy:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .cmd_exec
    inc rcx
    jmp .cmd_copy
.cmd_exec:
    mov [line_len], rcx
    call expand_cmd_subst
    call expand_line
    call expand_braces
    call expand_gnicks
    mov rdi, line_buf
    call execute_chained_line
    mov rdi, [last_status]
    mov rax, SYS_EXIT
    syscall

.no_cmd_mode:
    ; Handle login shell: source ~/.bare_profile (simple export lines only)
    ; Skips /etc/profile and ~/.profile (bash scripts with if/then/for)
    cmp qword [login_flag], 0
    je .no_login
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .no_login
    lea rdi, [suggestion_buf]
    mov rsi, rax
    call strcpy_rsi_rdi
    lea rdi, [suggestion_buf + rax]
    lea rsi, [.bare_profile_suffix]
    call strcpy_rsi_rdi
    lea rdi, [suggestion_buf]
    call source_file
.no_login:
    jmp .past_login_data
.bare_profile_suffix: db "/.bare_profile", 0
.time_real: db 10, "real    "
.time_real_len equ $ - .time_real
.time_dot: db "."
.time_suffix: db "s", 10
.time_suffix_len equ $ - .time_suffix

.past_login_data:

    ; Show random tip on startup (~30% chance)
    cmp qword [is_tty], 0
    je .no_tip
    test qword [config_flags], (1 << CFG_SHOW_TIPS)
    jz .no_tip
    ; Use PID as pseudo-random source
    mov rax, [my_pid]
    xor rdx, rdx
    mov rcx, 10
    div rcx                  ; rdx = pid % 10
    cmp rdx, 3               ; show if remainder < 3 (~30%)
    jge .no_tip
    ; Pick tip: pid % tip_count
    mov rax, [my_pid]
    xor rdx, rdx
    mov rcx, tip_count
    div rcx
    mov rsi, [tip_table + rdx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
.no_tip:

; ── Main loop ────────────────────────────────────────────────────────
    ; Make sure we're in raw mode before the first prompt so the
    ; ensure_col_zero DSR query response stays out of the terminal echo.
    cmp qword [is_tty], 0
    je .main_loop
    call enable_raw_mode
.main_loop:
    ; Print prompt (tty only)
    cmp qword [is_tty], 0
    je .no_prompt
    ; Check if stdin has buffered data (multiline paste detection)
    ; If data is waiting, skip prompt to avoid clutter during paste
    sub rsp, 8
    mov qword [rsp], 0
    mov rax, SYS_IOCTL
    xor edi, edi             ; stdin
    mov esi, 0x541B          ; FIONREAD
    mov rdx, rsp
    syscall
    mov rax, [rsp]
    add rsp, 8
    test rax, rax
    jnz .no_prompt           ; data waiting = paste in progress, skip prompt
    ; ensure_col_zero (ESC[6n cursor query) removed: response can arrive
    ; after our poll timeout and leak into the next read as ^[[N;MR. The
    ; cost is that commands without a trailing newline let the prompt
    ; share their last line; almost everything ends with \n anyway.
    call print_prompt
.no_prompt:

    ; Read a line of input (with line editing)
    call read_line
    test rax, rax
    js .eof                 ; negative = EOF (Ctrl-D)

    ; Skip empty lines
    mov rsi, line_buf
    call skip_spaces
    cmp byte [rsi], 0
    je .main_loop
    cmp byte [rsi], 10
    je .main_loop

    ; History expansion (!!, !N, !-N) - must be before add_history
    ; so the expanded form is stored, not the raw "!!" text
    call expand_history

    ; Add to history
    call add_history

    ; Command substitution $(cmd)
    call expand_cmd_subst

    ; Expand tilde and environment variables
    call expand_line

    ; Brace expansion {a,b,c}
    call expand_braces

    ; Global alias (gnick) expansion
    call expand_gnicks

    ; Check for "time " prefix
    mov qword [time_flag], 0
    cmp dword [line_buf], 'time'
    jne .no_time_prefix
    cmp byte [line_buf + 4], ' '
    jne .no_time_prefix
    mov qword [time_flag], 1
    ; Shift line_buf left by 5 to remove "time "
    lea rsi, [line_buf + 5]
    lea rdi, [line_buf]
    call strcpy_rsi_rdi
    mov [line_len], rax
.no_time_prefix:

    ; Record start time
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [cmd_start_time]
    syscall

    ; Execute the line (handles chains, pipes, background)
    mov rdi, line_buf
    call execute_chained_line

    ; If "time" was used, print elapsed
    cmp qword [time_flag], 0
    je .no_time_output
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [cmd_end_time]
    syscall
    ; Calculate and print
    mov rax, [cmd_end_time]
    sub rax, [cmd_start_time]
    mov rcx, [cmd_end_time + 8]
    sub rcx, [cmd_start_time + 8]
    test rcx, rcx
    jns .time_no_borrow
    dec rax
    add rcx, 1000000000
.time_no_borrow:
    push rcx
    push rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.time_real]
    mov rdx, .time_real_len
    syscall
    pop rax
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.time_dot]
    mov rdx, 1
    syscall
    pop rax                   ; nanoseconds
    xor edx, edx
    mov rcx, 1000000
    div rcx                   ; milliseconds
    ; Pad to 3 digits
    lea rdi, [num_buf]
    mov byte [num_buf], '0'
    mov byte [num_buf+1], '0'
    mov byte [num_buf+2], '0'
    cmp rax, 100
    jge .time_ms3
    cmp rax, 10
    jge .time_ms2
    lea rdi, [num_buf + 2]
    jmp .time_ms3
.time_ms2:
    lea rdi, [num_buf + 1]
.time_ms3:
    call itoa
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    mov rdx, 3
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.time_suffix]
    mov rdx, .time_suffix_len
    syscall
.no_time_output:

    ; Record end time and show duration
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [cmd_end_time]
    syscall
    call show_cmd_duration
    cmp qword [is_tty], 0
    je .skip_rprompt
    call show_rprompt
.skip_rprompt:

    ; Check ~/.pointer/lastdir for file manager auto-cd
    call check_lastdir

    jmp .main_loop

.eof:
    ; Save config and history
    call save_config
    call save_history
    ; Restore terminal
    call restore_termios
    ; Print newline and exit
    call write_nl
    xor edi, edi
    mov rax, SYS_EXIT
    syscall

; ══════════════════════════════════════════════════════════════════════
; ensure_col_zero: ensure the next prompt starts at column 0 even when
; the previous command's output didn't end with a newline. Sends a
; DSR cursor-position query (ESC[6n), reads back the response with a
; short poll timeout, parses the column out of "ESC[<row>;<col>R" and
; emits a newline if col != 1.
;
; Trade-off: in raw mode we read whatever stdin currently holds, so a
; user keystroke that happens in the microsecond gap can end up in
; this read. The bytes we don't recognise as part of the response are
; dropped — annoying in the worst case, never wrong in the common
; case (no key pressed between command exit and next prompt).
;
; Skipped when we are not on a TTY (eg. running under a pipe) since
; the response would never come.
; ══════════════════════════════════════════════════════════════════════
ensure_col_zero:
    cmp qword [is_tty], 0
    je .ecz_done
    push rbx
    push r12
    ; Send ESC[6n
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ecz_query]
    mov rdx, 4
    syscall
    ; Poll stdin briefly for the response
    sub rsp, 16
    mov dword [rsp], 0
    mov word [rsp + 4], POLLIN
    mov word [rsp + 6], 0
    mov rax, SYS_POLL
    lea rdi, [rsp]
    mov rsi, 1
    mov rdx, 50               ; 50 ms is plenty for a local terminal
    syscall
    add rsp, 16
    test rax, rax
    jle .ecz_pop
    ; Read what arrived (cap at 32 bytes — we only need the response)
    sub rsp, 40
    mov rax, SYS_READ
    xor edi, edi
    mov rsi, rsp
    mov rdx, 32
    syscall
    test rax, rax
    jle .ecz_pop_buf
    mov rcx, rax              ; bytes read
    xor rbx, rbx              ; scan position
.ecz_find_esc:
    cmp rbx, rcx
    jge .ecz_pop_buf
    cmp byte [rsp + rbx], 27
    je .ecz_check_lbr
    inc rbx
    jmp .ecz_find_esc
.ecz_check_lbr:
    inc rbx
    cmp rbx, rcx
    jge .ecz_pop_buf
    cmp byte [rsp + rbx], '['
    jne .ecz_find_esc
    inc rbx
    ; Walk past the row digits to ';'
.ecz_skip_row:
    cmp rbx, rcx
    jge .ecz_pop_buf
    cmp byte [rsp + rbx], ';'
    je .ecz_at_col
    inc rbx
    jmp .ecz_skip_row
.ecz_at_col:
    inc rbx
    xor eax, eax
.ecz_col_digit:
    cmp rbx, rcx
    jge .ecz_have_col
    movzx edx, byte [rsp + rbx]
    cmp dl, '0'
    jb .ecz_have_col
    cmp dl, '9'
    ja .ecz_have_col
    imul eax, 10
    sub edx, '0'
    add eax, edx
    inc rbx
    jmp .ecz_col_digit
.ecz_have_col:
    cmp eax, 1
    jle .ecz_pop_buf
    add rsp, 40
    call write_nl
    pop r12
    pop rbx
    ret
.ecz_pop_buf:
    add rsp, 40
.ecz_pop:
    pop r12
    pop rbx
.ecz_done:
    ret
.ecz_query: db 27, "[6n"

; ══════════════════════════════════════════════════════════════════════
; Print prompt: "bare> " with colors
; ══════════════════════════════════════════════════════════════════════
print_prompt:
    jmp print_prompt_dynamic

; ══════════════════════════════════════════════════════════════════════
; Read line with basic editing (backspace, Ctrl-C, Ctrl-D, history, tab)
; Returns: rax = length (negative on EOF)
; Line stored in line_buf, null-terminated
; ══════════════════════════════════════════════════════════════════════
read_line:
    push rbx
    push r12
    push r13

    ; If not a tty, read a full line at once
    cmp qword [is_tty], 0
    jne .rl_interactive

    ; Non-interactive: read until newline or EOF
    xor r12, r12
.rl_pipe_read:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [line_buf + r12]
    mov rdx, 1
    syscall
    test rax, rax
    jle .rl_pipe_eof
    cmp byte [line_buf + r12], 10
    je .rl_pipe_done
    inc r12
    cmp r12, 16382
    jl .rl_pipe_read
.rl_pipe_done:
    mov byte [line_buf + r12], 0
    mov [line_len], r12
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    ret
.rl_pipe_eof:
    test r12, r12
    jnz .rl_pipe_done
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

.rl_interactive:
    ; Enable raw mode for char-by-char input
    call enable_raw_mode

    xor r12, r12            ; cursor position
    mov qword [line_len], 0
    ; Reset history browsing position
    mov rax, [hist_count]
    mov [hist_pos], rax

.read_char:
    ; Read one byte
    mov rax, SYS_READ
    xor edi, edi            ; stdin
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    ; Check for EINTR from SIGWINCH
    cmp rax, -4              ; EINTR
    jne .not_eintr
    cmp qword [sigwinch_flag], 0
    je .read_char            ; spurious EINTR, retry
    mov qword [sigwinch_flag], 0
    ; Terminal resized: clear screen, home, save cursor, redraw
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.winch_seq]
    mov rdx, .winch_seq_len
    syscall
    call full_redraw
    jmp .read_char
.winch_seq: db 27, "[2J", 27, "[H" ; clear screen + home
.winch_seq_len equ $ - .winch_seq
.not_eintr:
    test rax, rax
    jle .read_eof

    movzx eax, byte [tmp_buf]

    ; Clear any displayed suggestion (erase gray text)
    ; But NOT on ESC (27) - right arrow (ESC[C) needs suggestion intact
    cmp qword [suggestion_len], 0
    je .no_clear_suggest
    cmp al, 27
    je .no_clear_suggest
    push rax
    mov qword [suggestion_len], 0
    ; Clear from cursor to end of display line
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    pop rax
.no_clear_suggest:

    ; Ctrl-D on empty line = EOF
    cmp al, 4
    je .check_eof

    ; Ctrl-C = cancel line
    cmp al, 3
    je .cancel_line

    ; Enter = done
    cmp al, 10
    je .read_done
    cmp al, 13
    je .read_done

    ; Backspace (127 or 8)
    cmp al, 127
    je .backspace
    cmp al, 8
    je .backspace

    ; Ctrl-W = delete word back
    cmp al, 23
    je .delete_word

    ; Ctrl-U = clear line
    cmp al, 21
    je .clear_line

    ; Ctrl-L = clear screen
    cmp al, 12
    je .clear_screen

    ; Ctrl-K = kill to end of line
    cmp al, 11
    je .kill_to_end

    ; Ctrl-Z = ignore at prompt (job control only during child exec)
    cmp al, 26
    je .read_char

    ; Ctrl-R = reverse history search
    cmp al, 18
    je .reverse_search

    ; Ctrl-G = edit in $EDITOR
    cmp al, 7
    je .edit_in_editor

    ; Ctrl-Y = copy line to clipboard
    cmp al, 25
    je .copy_clipboard

    ; Ctrl-_ = undo
    cmp al, 31
    je .undo_action

    ; Ctrl-A = home
    cmp al, 1
    je .home

    ; Ctrl-E = end
    cmp al, 5
    je .end_of_line

    ; Escape sequence (arrows, etc.)
    cmp al, 27
    je .escape_seq

    ; Tab = completion
    cmp al, 9
    je .handle_tab

    ; Space: check for abbreviation expansion
    cmp al, ' '
    jne .not_space
    call try_expand_abbrev
    test rax, rax
    jnz .read_char           ; abbreviation was expanded, skip normal insert
.not_space:

    ; Clear prefix history search on any typed character
    mov qword [hist_prefix_len], 0

    ; Regular character: insert at cursor
    cmp r12, 16382
    jge .read_char          ; buffer full

    ; Shift chars right if cursor not at end
    mov rcx, [line_len]
    cmp r12, rcx
    jge .insert_at_end

    ; Shift right from end to cursor
    lea rdi, [line_buf + rcx]
    lea rsi, [line_buf + rcx - 1]
    mov rcx, [line_len]
    sub rcx, r12
.shift_right:
    mov al, [rsi]
    mov [rdi], al
    dec rsi
    dec rdi
    dec rcx
    jnz .shift_right

.insert_at_end:
    movzx eax, byte [tmp_buf]
    mov [line_buf + r12], al
    inc r12
    inc qword [line_len]

    ; Save undo state on significant edits
    call save_undo_state

    ; Auto-pair: insert closing bracket/quote after cursor
    test qword [config_flags], (1 << CFG_AUTO_PAIR)
    jz .no_auto_pair
    movzx eax, byte [tmp_buf]
    cmp al, '('
    je .auto_pair_close
    cmp al, '['
    je .auto_pair_close
    cmp al, '{'
    je .auto_pair_close
    cmp al, 0x27             ; single quote
    je .auto_pair_quote
    cmp al, '"'
    je .auto_pair_quote
    jmp .no_auto_pair

.auto_pair_close:
    ; Map ( -> ), [ -> ], { -> }
    movzx eax, byte [tmp_buf]
    cmp al, '('
    jne .apc_not_paren
    mov byte [tmp_buf + 1], ')'
    jmp .apc_insert
.apc_not_paren:
    cmp al, '['
    jne .apc_not_bracket
    mov byte [tmp_buf + 1], ']'
    jmp .apc_insert
.apc_not_bracket:
    mov byte [tmp_buf + 1], '}'
.apc_insert:
    ; Insert closing char at cursor (which is now after opening char)
    movzx eax, byte [tmp_buf + 1]
    ; Shift chars right if not at end
    mov rcx, [line_len]
    cmp r12, rcx
    jge .apc_at_end
    push rcx
    lea rdi, [line_buf + rcx]
    lea rsi, [line_buf + rcx - 1]
    mov rcx, [line_len]
    sub rcx, r12
.apc_shift:
    mov al, [rsi]
    mov [rdi], al
    dec rsi
    dec rdi
    dec rcx
    jnz .apc_shift
    pop rcx
.apc_at_end:
    movzx eax, byte [tmp_buf + 1]
    mov [line_buf + r12], al
    inc qword [line_len]
    ; Don't advance cursor - leave it between the pair
    jmp .no_auto_pair

.auto_pair_quote:
    ; Insert same char as closing
    mov rcx, [line_len]
    cmp r12, rcx
    jge .apq_at_end
    push rcx
    lea rdi, [line_buf + rcx]
    lea rsi, [line_buf + rcx - 1]
    mov rcx, [line_len]
    sub rcx, r12
.apq_shift:
    mov al, [rsi]
    mov [rdi], al
    dec rsi
    dec rdi
    dec rcx
    jnz .apq_shift
    pop rcx
.apq_at_end:
    movzx eax, byte [tmp_buf]
    mov [line_buf + r12], al
    inc qword [line_len]

.no_auto_pair:
    ; Redraw full line with syntax highlighting after each edit
    call full_redraw

    ; If cursor is at end, show inline suggestion
    mov rcx, [line_len]
    cmp r12, rcx
    jl .read_char

.show_suggestion:
    ; Show inline history suggestion (gray text after cursor)
    call find_history_suggestion
    test rax, rax
    jz .read_char
    ; rax = pointer to suggestion remainder, rdx = length
    ; Save suggestion for right-arrow acceptance
    mov [suggestion_ptr], rax
    mov [suggestion_len], rdx
    ; Write gray color
    push rax
    push rdx
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.suggest_color]
    mov rdx, .suggest_color_len
    syscall
    pop rdx
    pop rax
    ; Write suggestion text
    push rdx
    mov rsi, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    pop rdx
    syscall
    ; Reset color + move cursor back
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.suggest_reset]
    mov rdx, 4
    syscall
    ; Reposition cursor back to actual position
    call reposition_cursor
    jmp .read_char

.suggest_color: db 27, "[38;5;240m"
.suggest_color_len equ $ - .suggest_color
.suggest_reset: db 27, "[0m"

.backspace:
    test r12, r12
    jz .read_char           ; nothing to delete
    ; Shift chars left
    dec r12
    mov rcx, [line_len]
    dec rcx
    mov [line_len], rcx
    ; Shift left
    lea rdi, [line_buf + r12]
    lea rsi, [line_buf + r12 + 1]
    mov rcx, [line_len]
    sub rcx, r12
    test rcx, rcx
    jz .bs_redraw
.shift_left:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .shift_left
.bs_redraw:
    ; Move cursor back, redraw, clear trailing char
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.bs_seq]
    mov rdx, 4
    syscall
    call redraw_from_cursor
    jmp .read_char
.bs_seq: db 8, 27, '[K'       ; backspace + clear to end

.delete_word:
    ; Delete back to previous space
    test r12, r12
    jz .read_char
    ; Skip spaces
.dw_skip:
    test r12, r12
    jz .dw_done
    cmp byte [line_buf + r12 - 1], ' '
    jne .dw_word
    dec r12
    dec qword [line_len]
    jmp .dw_skip
.dw_word:
    test r12, r12
    jz .dw_done
    cmp byte [line_buf + r12 - 1], ' '
    je .dw_done
    dec r12
    dec qword [line_len]
    jmp .dw_word
.dw_done:
    ; Null terminate and redraw
    mov rcx, [line_len]
    mov byte [line_buf + rcx], 0
    call full_redraw
    jmp .read_char

.clear_screen:
    ; Clear screen and redraw prompt + current line
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clear_screen_seq]
    mov rdx, clear_screen_len
    syscall
    call print_prompt
    call full_redraw
    jmp .read_char

.clear_line:
    xor r12, r12
    mov qword [line_len], 0
    mov byte [line_buf], 0
    call full_redraw
    jmp .read_char

.kill_to_end:
    mov [line_len], r12
    mov byte [line_buf + r12], 0
    ; Clear from cursor to end of line
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.clr_eol]
    mov rdx, 4
    syscall
    jmp .read_char
.clr_eol: db 27, '[', '0', 'K'

.home:
    xor r12, r12
    call reposition_cursor
    jmp .read_char

.end_of_line:
    mov r12, [line_len]
    call reposition_cursor
    jmp .read_char

.copy_clipboard:
    ; Ctrl-Y: copy line to clipboard via xclip
    cmp qword [line_len], 0
    je .read_char
    ; Fork xclip -selection clipboard, write line to its stdin
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    jnz .read_char
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .cc_child
    js .read_char
    ; Parent: write line to pipe, close
    push rax
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]      ; close read end
    syscall
    mov rax, SYS_WRITE
    mov edi, [pipe_fds + 4]  ; write end
    lea rsi, [line_buf]
    mov rdx, [line_len]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    ; Don't wait (fire and forget)
    pop rax
    jmp .read_char
.cc_child:
    ; stdin = pipe read end
    mov rax, SYS_DUP2
    mov edi, [pipe_fds]
    xor esi, esi
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    ; exec xclip
    sub rsp, 32
    lea rax, [.cc_xclip]
    mov [rsp], rax
    lea rax, [.cc_sel_flag]
    mov [rsp + 8], rax
    lea rax, [.cc_sel_clip]
    mov [rsp + 16], rax
    mov qword [rsp + 24], 0
    mov rax, SYS_EXECVE
    lea rdi, [.cc_xclip]
    mov rsi, rsp
    lea rdx, [env_array]
    syscall
    mov rax, SYS_EXIT
    xor edi, edi
    syscall
.cc_xclip: db "/usr/bin/xclip", 0
.cc_sel_flag: db "-selection", 0
.cc_sel_clip: db "clipboard", 0

.undo_action:
    ; Ctrl-_: restore previous undo state
    mov rax, [undo_count]
    test rax, rax
    jz .read_char
    dec rax
    mov [undo_count], rax
    ; Restore line_buf from undo_stack[undo_count]
    imul rcx, rax, 4096
    lea rsi, [undo_stack + rcx]
    lea rdi, [line_buf]
    xor rcx, rcx
.ua_copy:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .ua_done
    inc rcx
    jmp .ua_copy
.ua_done:
    mov [line_len], rcx
    mov r12, [undo_positions + rax*8]
    call full_redraw
    jmp .read_char

.edit_in_editor:
    ; Ctrl-G: write line_buf to temp file, open in $EDITOR, read back
    call restore_termios
    ; Build temp file path: /tmp/bare_edit_<pid>
    lea rdi, [suggestion_buf]     ; reuse as temp path buffer
    mov dword [rdi], '/tmp'
    mov dword [rdi+4], '/bar'
    mov dword [rdi+8], 'e_ed'
    mov byte [rdi+12], 0
    ; Create/open temp file
    mov rax, SYS_OPEN
    lea rdi, [suggestion_buf]
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 0o644
    syscall
    test rax, rax
    js .eie_fail
    mov rbx, rax             ; fd
    ; Write line_buf contents
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [line_buf]
    mov rdx, [line_len]
    syscall
    ; Write newline
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [newline]
    mov rdx, 1
    syscall
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    ; Fork + exec $EDITOR
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .eie_child
    js .eie_fail
    ; Parent: wait
    mov rbx, rax
    sub rsp, 16
    mov rax, SYS_WAIT4
    mov rdi, rbx
    lea rsi, [rsp]
    xor edx, edx
    xor r10d, r10d
    syscall
    add rsp, 16
    ; Read file back into line_buf
    mov rax, SYS_OPEN
    lea rdi, [suggestion_buf]
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .eie_fail
    mov rbx, rax
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [line_buf]
    mov rdx, 16382
    syscall
    push rax
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax
    test rax, rax
    jle .eie_fail
    ; Strip trailing newlines
    mov rcx, rax
.eie_strip:
    dec rcx
    js .eie_empty
    cmp byte [line_buf + rcx], 10
    je .eie_strip
    inc rcx
.eie_empty:
    mov byte [line_buf + rcx], 0
    mov [line_len], rcx
    mov r12, rcx             ; cursor at end
    ; Re-enable raw mode and redraw
    call enable_raw_mode
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.eie_cr]
    mov rdx, 1
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    call print_prompt
    call full_redraw
    jmp .read_char
.eie_fail:
    call enable_raw_mode
    jmp .read_char
.eie_child:
    ; Look up EDITOR env var
    mov rdi, [envp]
    call .eie_find_editor
    test rax, rax
    jnz .eie_have_editor
    lea rax, [.eie_vi]       ; fallback to vi
.eie_have_editor:
    ; execve(editor, [editor, tmpfile, NULL], envp)
    sub rsp, 32
    mov [rsp], rax            ; argv[0] = editor path
    lea rcx, [suggestion_buf]
    mov [rsp + 8], rcx        ; argv[1] = temp file
    mov qword [rsp + 16], 0   ; argv[2] = NULL
    mov rdi, rax
    mov rsi, rsp
    lea rdx, [env_array]
    mov rax, SYS_EXECVE
    syscall
    mov rax, SYS_EXIT
    mov edi, 127
    syscall
.eie_find_editor:
    ; Search env_array for EDITOR=
    push rbx
    xor rcx, rcx
.eie_fe_loop:
    cmp rcx, [env_count]
    jge .eie_fe_none
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .eie_fe_next
    cmp dword [rsi], 'EDIT'
    jne .eie_fe_next
    cmp word [rsi+4], 'OR'
    jne .eie_fe_next
    cmp byte [rsi+6], '='
    jne .eie_fe_next
    lea rax, [rsi+7]
    pop rbx
    ret
.eie_fe_next:
    inc rcx
    jmp .eie_fe_loop
.eie_fe_none:
    xor eax, eax
    pop rbx
    ret
.eie_cr: db 13
.eie_vi: db "/usr/bin/vi", 0

.reverse_search:
    ; Ctrl-R: incremental reverse history search
    ; Show "(reverse-i-search)': " prompt, read chars, filter history
    push r12                 ; save cursor pos
    mov qword [search_len], 0
    mov byte [search_buf], 0

.rs_redraw:
    ; Move to beginning of line and clear
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rs_cr]
    mov rdx, 1
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    ; Print search prompt
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rs_prompt]
    mov rdx, .rs_prompt_len
    syscall
    ; Print search string
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [search_buf]
    mov rdx, [search_len]
    syscall
    ; Print ': and matching history entry
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rs_sep]
    mov rdx, 3
    syscall
    ; Find matching history entry
    call find_reverse_match
    test rax, rax
    jz .rs_no_match
    ; Print the match
    push rax
    mov rdi, rax
    call strlen
    mov rdx, rax
    pop rsi
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
.rs_no_match:

.rs_read_key:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .rs_cancel

    movzx eax, byte [tmp_buf]

    ; Enter: accept the match
    cmp al, 10
    je .rs_accept
    cmp al, 13
    je .rs_accept

    ; Ctrl-G or Escape: cancel
    cmp al, 7
    je .rs_cancel
    cmp al, 27
    je .rs_cancel

    ; Ctrl-C: cancel
    cmp al, 3
    je .rs_cancel

    ; Backspace: remove last search char
    cmp al, 127
    je .rs_backspace
    cmp al, 8
    je .rs_backspace

    ; Ctrl-R again: search for next match (older)
    cmp al, 18
    je .rs_next

    ; Regular char: add to search
    cmp al, 32
    jl .rs_read_key          ; ignore other control chars
    mov rcx, [search_len]
    cmp rcx, 250
    jge .rs_read_key
    mov [search_buf + rcx], al
    inc rcx
    mov [search_len], rcx
    mov byte [search_buf + rcx], 0
    mov qword [rs_skip_count], 0  ; reset skip on new char
    jmp .rs_redraw

.rs_backspace:
    mov rcx, [search_len]
    test rcx, rcx
    jz .rs_read_key
    dec rcx
    mov [search_len], rcx
    mov byte [search_buf + rcx], 0
    mov qword [rs_skip_count], 0
    jmp .rs_redraw

.rs_next:
    ; Search for next older match
    inc qword [rs_skip_count]
    jmp .rs_redraw

.rs_accept:
    ; Copy matching history entry to line_buf
    call find_reverse_match
    test rax, rax
    jz .rs_cancel
    mov rsi, rax
    lea rdi, [line_buf]
    xor rcx, rcx
.rs_copy:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .rs_copy_done
    inc rcx
    jmp .rs_copy
.rs_copy_done:
    mov [line_len], rcx
    pop r12                  ; restore saved cursor
    mov r12, rcx             ; cursor at end
    ; Redraw normal prompt + line
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rs_cr]
    mov rdx, 1
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    call print_prompt
    call full_redraw
    jmp .read_char

.rs_cancel:
    pop r12                  ; restore cursor
    ; Redraw normal prompt + line
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rs_cr]
    mov rdx, 1
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    call print_prompt
    call full_redraw
    jmp .read_char

.rs_cr: db 13
.rs_prompt: db "(reverse-i-search)`"
.rs_prompt_len equ $ - .rs_prompt
.rs_sep: db "': "

.escape_seq:
    ; Read next two bytes for arrow keys etc.
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .read_char
    cmp byte [tmp_buf], '['
    je .esc_bracket
    ; ESC O = application mode cursor keys (same as ESC [)
    cmp byte [tmp_buf], 'O'
    je .esc_bracket
    ; Alt+key: ESC followed by a letter (not [ or O)
    cmp byte [tmp_buf], 'f'
    je .word_forward
    cmp byte [tmp_buf], 'b'
    je .word_backward
    cmp byte [tmp_buf], 'd'
    je .read_char             ; Alt-d: ignore (kitty split)
    ; OSC / DCS / SOS / PM / APC: drain until ESC \ (ST) or BEL (0x07).
    ; Background commands like vim emit OSC titles whose payload would
    ; otherwise leak into the line buffer.
    cmp byte [tmp_buf], ']'
    je .esc_drain_st
    cmp byte [tmp_buf], 'P'
    je .esc_drain_st
    cmp byte [tmp_buf], 'X'
    je .esc_drain_st
    cmp byte [tmp_buf], '^'
    je .esc_drain_st
    cmp byte [tmp_buf], '_'
    je .esc_drain_st
    ; Unknown ESC sequence: discard
    jmp .read_char

.esc_drain_st:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .read_char
    cmp byte [tmp_buf], 0x07          ; BEL also terminates OSC
    je .read_char
    cmp byte [tmp_buf], 27            ; ESC \ (ST)?
    jne .esc_drain_st
    ; Saw ESC inside the payload; consume the following byte ('\\' or other)
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    jmp .read_char

.esc_bracket:
    ; Read first byte after ESC[. If it is a final byte (0x40..0x7E),
    ; the sequence is parameter-less (e.g. plain arrows). Otherwise it
    ; is a parameter byte and we must collect until a final byte arrives,
    ; then dispatch on the params + final byte. This is required so that
    ; multi-digit responses from background commands (cursor position
    ; reports, Device Attributes, etc.) are fully drained instead of
    ; spilling the tail into the line buffer.
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .read_char

    movzx eax, byte [tmp_buf]
    cmp al, 0x40
    jb .esc_collect_params       ; param/intermediate byte
    ; Final byte with no params
    mov qword [csi_param_len], 0
    jmp .esc_dispatch

.esc_collect_params:
    ; First param byte is in tmp_buf; copy it and read until final byte.
    ; Track length in memory because syscall clobbers rcx.
    mov [csi_params], al
    mov qword [csi_param_len], 1
.esc_collect_loop:
    mov rax, [csi_param_len]
    cmp rax, 31
    jge .esc_collect_oversized
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .read_char
    mov rcx, [csi_param_len]
    movzx eax, byte [tmp_buf]
    mov [csi_params + rcx], al
    inc rcx
    mov [csi_param_len], rcx
    cmp al, 0x40
    jb .esc_collect_loop
    ; Final byte landed in csi_params[csi_param_len-1]; dispatch
    jmp .esc_dispatch

.esc_collect_oversized:
    ; Too many params; consume until final byte and bail.
.esc_collect_drain:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .read_char
    cmp byte [tmp_buf], 0x40
    jb .esc_collect_drain
    jmp .read_char

.esc_dispatch:
    mov rcx, [csi_param_len]
    test rcx, rcx
    jnz .esc_dispatch_have_final
    ; No params: tmp_buf still holds the final byte
    movzx eax, byte [tmp_buf]
    jmp .esc_final_check
.esc_dispatch_have_final:
    movzx eax, byte [csi_params + rcx - 1]
.esc_final_check:
    cmp rcx, 0
    jne .esc_check_modified
    cmp al, 'A'
    je .hist_prev
    cmp al, 'B'
    je .hist_next
    cmp al, 'C'
    je .cursor_right
    cmp al, 'D'
    je .cursor_left
    cmp al, 'H'
    je .home
    cmp al, 'F'
    je .end_of_line
    jmp .read_char

.esc_check_modified:
    ; ESC[3~ (Delete key) — params="3~"
    cmp al, '~'
    jne .esc_check_arrow_mod
    cmp byte [csi_params], '3'
    je .delete_key_dispatch
    jmp .read_char

.esc_check_arrow_mod:
    ; ESC[1;Mx where M is modifier digit and x is C/D/A/B.
    cmp byte [csi_params], '1'
    jne .read_char
    cmp byte [csi_params + 1], ';'
    jne .read_char
    movzx ebx, byte [csi_params + 2]
    cmp bl, '5'                   ; Ctrl
    je .esc_mod_ctrl
    cmp bl, '2'                   ; Shift
    je .esc_mod_shift
    jmp .read_char
.esc_mod_ctrl:
    cmp al, 'C'
    je .word_forward
    cmp al, 'D'
    je .word_backward
    cmp al, 'A'
    je .hist_prev
    cmp al, 'B'
    je .hist_next
    jmp .read_char
.esc_mod_shift:
    cmp al, 'C'
    je .cursor_right
    cmp al, 'D'
    je .cursor_left
    jmp .read_char

.delete_key_dispatch:
    jmp .delete_key_action

.cursor_right:
    cmp r12, [line_len]
    jge .accept_suggestion
    inc r12
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.right_seq]
    mov rdx, 3
    syscall
    jmp .read_char
.right_seq: db 27, '[', 'C'

.accept_suggestion:
    ; Accept inline suggestion if available
    mov rax, [suggestion_len]
    test rax, rax
    jz .read_char
    ; Clear the gray suggestion text first
    push rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    pop rax
    mov rsi, [suggestion_ptr]
    ; Append suggestion to line_buf
    mov rcx, rax
    mov rdi, r12             ; cursor (= line_len)
.as_copy:
    test rcx, rcx
    jz .as_done
    cmp rdi, 16382
    jge .as_done
    movzx eax, byte [rsi]
    mov [line_buf + rdi], al
    inc rsi
    inc rdi
    inc r12
    dec rcx
    jmp .as_copy
.as_done:
    mov [line_len], r12
    mov byte [line_buf + r12], 0
    mov qword [suggestion_len], 0
    ; Clear suggestion and redraw line
    call full_redraw
    jmp .read_char

.cursor_left:
    test r12, r12
    jz .read_char
    dec r12
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.left_seq]
    mov rdx, 3
    syscall
    jmp .read_char
.left_seq: db 27, '[', 'D'

.word_forward:
    ; Alt-F / Ctrl-Right: move cursor forward to end of next word
.wf_skip_spaces:
    cmp r12, [line_len]
    jge .wf_done
    cmp byte [line_buf + r12], ' '
    jne .wf_word
    inc r12
    jmp .wf_skip_spaces
.wf_word:
    cmp r12, [line_len]
    jge .wf_done
    cmp byte [line_buf + r12], ' '
    je .wf_done
    inc r12
    ; Skip UTF-8 continuation bytes (10xxxxxx = 0x80-0xBF)
.wf_utf8:
    cmp r12, [line_len]
    jge .wf_done
    movzx eax, byte [line_buf + r12]
    and al, 0xC0
    cmp al, 0x80
    jne .wf_word
    inc r12
    jmp .wf_utf8
.wf_done:
    call full_redraw
    jmp .read_char

.word_backward:
    ; Alt-B / Ctrl-Left: move cursor backward to start of previous word
    test r12, r12
    jz .read_char
    dec r12
    ; Skip back past UTF-8 continuation bytes
.wb_utf8_back:
    test r12, r12
    jz .wb_skip_spaces
    movzx eax, byte [line_buf + r12]
    and al, 0xC0
    cmp al, 0x80
    jne .wb_skip_spaces
    dec r12
    jmp .wb_utf8_back
.wb_skip_spaces:
    test r12, r12
    jz .wb_done
    cmp byte [line_buf + r12 - 1], ' '
    jne .wb_word
    dec r12
    ; Skip back past continuation bytes after space skip
.wb_sp_utf8:
    test r12, r12
    jz .wb_done
    movzx eax, byte [line_buf + r12]
    and al, 0xC0
    cmp al, 0x80
    jne .wb_skip_spaces
    dec r12
    jmp .wb_sp_utf8
.wb_word:
    test r12, r12
    jz .wb_done
    cmp byte [line_buf + r12 - 1], ' '
    je .wb_done
    dec r12
    ; Skip back past continuation bytes
.wb_wd_utf8:
    test r12, r12
    jz .wb_done
    movzx eax, byte [line_buf + r12]
    and al, 0xC0
    cmp al, 0x80
    jne .wb_word
    dec r12
    jmp .wb_wd_utf8
.wb_done:
    call full_redraw
    jmp .read_char

.delete_key:
.delete_key_action:
    ; Delete char at cursor (like forward-delete)
    mov rcx, [line_len]
    cmp r12, rcx
    jge .read_char
    ; Shift left from cursor+1
    lea rdi, [line_buf + r12]
    lea rsi, [line_buf + r12 + 1]
    mov rcx, [line_len]
    dec rcx
    mov [line_len], rcx
    sub rcx, r12
    test rcx, rcx
    jz .del_redraw
.del_shift:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .del_shift
.del_redraw:
    call redraw_from_cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.space_clr]
    mov rdx, 1
    syscall
    call reposition_cursor
    jmp .read_char
.space_clr: db ' '

.hist_prev:
    ; If line has content and prefix not yet saved, save it for prefix search
    ; But only if we haven't started navigating history yet (hist_pos == hist_count)
    cmp qword [hist_prefix_len], 0
    jne .hp_have_prefix
    mov rax, [hist_pos]
    cmp rax, [hist_count]
    jne .hp_no_prefix         ; already navigating, don't save prefix
    mov rax, [line_len]
    test rax, rax
    jz .hp_no_prefix
    ; Save current line as prefix
    cmp rax, 255
    jg .hp_no_prefix
    mov [hist_prefix_len], rax
    lea rsi, [line_buf]
    lea rdi, [hist_prefix_buf]
    mov rcx, rax
.hp_save_prefix:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .hp_save_prefix
    mov byte [rdi], 0
.hp_have_prefix:
    ; Search backward for entry matching prefix
    mov rax, [hist_pos]
.hp_search_back:
    test rax, rax
    jz .read_char            ; no more history
    dec rax
    mov rsi, [hist_lines + rax*8]
    test rsi, rsi
    jz .hp_search_back
    ; Compare prefix
    lea rdi, [hist_prefix_buf]
    xor rcx, rcx
    mov rdx, [hist_prefix_len]
.hp_cmp:
    cmp rcx, rdx
    jge .hp_match             ; all prefix chars matched
    movzx ebx, byte [rdi + rcx]
    cmp bl, [rsi + rcx]
    jne .hp_search_back       ; mismatch, try older
    inc rcx
    jmp .hp_cmp
.hp_match:
    mov [hist_pos], rax
    call load_hist_line
    jmp .read_char

.hp_no_prefix:
    ; No prefix: plain history navigation
    cmp qword [hist_pos], 0
    je .read_char
    dec qword [hist_pos]
    call load_hist_line
    jmp .read_char

.hist_next:
    ; Check if we're doing prefix search
    cmp qword [hist_prefix_len], 0
    je .hn_no_prefix

    ; Search forward for entry matching prefix
    mov rax, [hist_pos]
.hn_search_fwd:
    inc rax
    cmp rax, [hist_count]
    jge .hn_restore_prefix    ; past end, restore original prefix
    mov rsi, [hist_lines + rax*8]
    test rsi, rsi
    jz .hn_search_fwd
    ; Compare prefix
    lea rdi, [hist_prefix_buf]
    xor rcx, rcx
    mov rdx, [hist_prefix_len]
.hn_cmp:
    cmp rcx, rdx
    jge .hn_match
    movzx ebx, byte [rdi + rcx]
    cmp bl, [rsi + rcx]
    jne .hn_search_fwd
    inc rcx
    jmp .hn_cmp
.hn_match:
    mov [hist_pos], rax
    call load_hist_line
    jmp .read_char

.hn_restore_prefix:
    ; Past end of history: restore the original typed prefix
    mov [hist_pos], rax
    lea rsi, [hist_prefix_buf]
    lea rdi, [line_buf]
    mov rcx, [hist_prefix_len]
    xor rax, rax
.hn_restore:
    cmp rax, rcx
    jge .hn_restored
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .hn_restore
.hn_restored:
    mov byte [rdi + rax], 0
    mov [line_len], rax
    mov r12, rax
    mov qword [hist_prefix_len], 0  ; clear prefix search
    call full_redraw
    jmp .read_char

.hn_no_prefix:
    ; No prefix: plain history navigation
    mov rax, [hist_pos]
    cmp rax, [hist_count]
    jge .read_char
    inc qword [hist_pos]
    mov rax, [hist_pos]
    cmp rax, [hist_count]
    jl .hn_load
    ; At end: clear line
    xor r12, r12
    mov qword [line_len], 0
    mov byte [line_buf], 0
    call full_redraw
    jmp .read_char
.hn_load:
    call load_hist_line
    jmp .read_char

.check_eof:
    cmp qword [line_len], 0
    jne .read_char          ; Ctrl-D with content: ignore
    call restore_termios
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

.cancel_line:
    ; Leave cancelled text visible, print newline, fresh prompt
    call write_nl
    xor r12, r12
    mov qword [line_len], 0
    mov byte [line_buf], 0
    mov qword [suggestion_len], 0
    call print_prompt
    jmp .read_char

.read_done:
    ; Strip trailing \r if present, then null-terminate
    mov rcx, [line_len]
    test rcx, rcx
    jz .rd_nullterm
    cmp byte [line_buf + rcx - 1], 13
    jne .rd_nullterm
    dec rcx
    mov [line_len], rcx
.rd_nullterm:
    mov byte [line_buf + rcx], 0

    ; Multi-line continuation: check if line ends with \ | && || or has unclosed quotes
    call check_continuation
    test rax, rax
    jz .rd_finish

    ; Continuation needed: print newline, show "> " prompt, keep reading
    call write_nl
    ; Print continuation prompt
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.cont_prompt]
    mov rdx, 2
    syscall
    ; Append a space to line_buf (replace the trailing \ with space if backslash continuation)
    mov rcx, [line_len]
    cmp byte [line_buf + rcx - 1], '\'
    jne .rd_no_strip_bs
    dec rcx                  ; remove trailing backslash
    mov byte [line_buf + rcx], ' '
    inc rcx
    mov [line_len], rcx
    jmp .rd_cont_read
.rd_no_strip_bs:
    ; For | && || continuation, add a space
    mov byte [line_buf + rcx], ' '
    inc rcx
    mov [line_len], rcx
.rd_cont_read:
    mov r12, rcx             ; cursor at end
    jmp .read_char

.cont_prompt: db "> "

.rd_finish:
    ; Print newline
    call write_nl
    call restore_termios
    mov rax, [line_len]
    pop r13
    pop r12
    pop rbx
    ret

.read_eof:
    call restore_termios
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    ret

; ── Tab completion handler ──────────────────────────────────────────
.handle_tab:
    ; Extract current word (from last space or beginning to cursor)
    ; Find start of current word
    mov rcx, r12
    dec rcx
.tab_find_start:
    cmp rcx, 0
    jl .tab_start_found
    cmp byte [line_buf + rcx], ' '
    je .tab_start_at
    dec rcx
    jmp .tab_find_start
.tab_start_at:
    inc rcx                 ; skip past the space
.tab_start_found:
    test rcx, rcx
    jns .tab_start_ok
    xor rcx, rcx
.tab_start_ok:
    ; rcx = start of word, r12 = cursor (end of word)
    push r14
    push r15
    mov r14, rcx            ; r14 = word start index in line_buf
    ; Copy current word to tab_word_buf
    lea rdi, [tab_word_buf]
    lea rsi, [line_buf + rcx]
    mov rdx, r12
    sub rdx, rcx
    cmp rdx, 250
    jg .tab_no_word
    ; Allow zero-length word (for subcommand completion like "git <TAB>")
    test rdx, rdx
    jnz .tab_has_word
    mov byte [tab_word_buf], 0
    jmp .tab_word_ready
.tab_has_word:
    mov rcx, rdx
.tab_copy_word:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .tab_copy_word
    mov byte [rdi], 0
.tab_word_ready:

    ; Determine if this is a command (first word) or file completion
    ; Check if r14 == 0 and no previous non-space characters
    mov rax, r14
    test rax, rax
    jz .tab_command_completion

    ; Check if everything before r14 is spaces
    xor rdi, rdi
.tab_check_prev:
    cmp rdi, r14
    jge .tab_command_completion
    cmp byte [line_buf + rdi], ' '
    jne .tab_file_completion
    inc rdi
    jmp .tab_check_prev

.tab_command_completion:
    ; Check for $VAR even in command position
    cmp byte [tab_word_buf], 0x24
    je .tab_var_completion
    ; Check for :command completion
    cmp byte [tab_word_buf], ':'
    je .tab_colon_completion
    ; If word contains '/', use file completion (./cmd, ../dir, /path)
    lea rsi, [tab_word_buf]
.tab_cmd_slash_check:
    movzx eax, byte [rsi]
    test al, al
    jz .tab_cmd_no_slash
    cmp al, '/'
    je .tab_file_completion
    inc rsi
    jmp .tab_cmd_slash_check
.tab_cmd_no_slash:
    ; Search PATH directories for matches
    lea rdi, [tab_word_buf]
    call tab_complete_command
    ; If PATH yielded nothing, fall back to cwd entries so things like
    ; "Main<TAB>" work when there is a Main/ directory in the cwd.
    cmp qword [tab_count], 0
    jne .tab_process_results
    lea rdi, [tab_word_buf]
    call tab_complete_file
    jmp .tab_process_results

.tab_colon_completion:
    lea rdi, [tab_word_buf]
    call tab_complete_colon
    jmp .tab_process_results

.tab_file_completion:
    ; Check for $VAR completion (0x24 = ASCII dollar sign; '$' in NASM means current address)
    cmp byte [tab_word_buf], 0x24
    je .tab_var_completion

    ; Check for switch completion (-<TAB> or --<TAB>)
    cmp byte [tab_word_buf], '-'
    jne .tab_not_switch
    call tab_complete_switch
    cmp qword [tab_count], 0
    jnz .tab_process_results
.tab_not_switch:

    ; Check for subcommand completion (git, apt, cargo, etc.)
    call check_subcommand_completion
    test rax, rax
    jnz .tab_process_results

    ; Search current directory for file matches
    lea rdi, [tab_word_buf]
    call tab_complete_file
    jmp .tab_process_results

.tab_var_completion:
    lea rdi, [tab_word_buf]
    call tab_complete_var
    jmp .tab_process_results

.tab_process_results:
    ; Sort results alphabetically
    call sort_tab_results

    mov rax, [tab_count]
    test rax, rax
    jz .tab_done            ; no matches

    cmp rax, 1
    jne .tab_multiple

    ; Exactly one match: complete the word
    ; Find the common prefix length (match length) beyond what user typed
    mov rsi, [tab_results]  ; pointer to the match
    lea rdi, [tab_word_buf]
    ; Find length of the match
    push rsi
    mov rdi, rsi
    call strlen
    mov rcx, rax            ; match length
    pop rsi

    ; Find the prefix (word) length
    lea rdi, [tab_word_buf]
    push rcx
    call strlen
    mov rdx, rax            ; prefix length
    pop rcx

    ; Insert remaining chars: match[prefix_len..match_len]
    sub rcx, rdx            ; chars to insert
    test rcx, rcx
    jle .tab_add_space
    add rsi, rdx            ; point to remaining chars ("ME" for $HOME)
    ; Insert chars into line_buf at cursor
.tab_insert_loop:
    test rcx, rcx
    jz .tab_add_space
    movzx eax, byte [rsi]
    ; Escape spaces with backslash
    cmp al, ' '
    jne .tab_no_escape
    cmp r12, 16380
    jge .tab_add_space
    mov byte [line_buf + r12], '\'
    inc r12
    inc qword [line_len]
.tab_no_escape:
    mov [line_buf + r12], al
    inc r12
    inc qword [line_len]
    inc rsi
    dec rcx
    jmp .tab_insert_loop

.tab_add_space:
    ; Check if match is a directory: add '/' instead of ' '
    movzx eax, byte [tab_types]
    cmp al, 4
    je .tab_add_slash
    ; d_type unknown (0) or symlink (10): stat to check if directory
    cmp al, 10
    je .tab_stat_check
    test al, al
    jnz .tab_add_sp
.tab_stat_check:
    ; Stat the completed word to see if it's a directory
    mov byte [line_buf + r12], 0  ; null-terminate temporarily
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [line_buf + r14]     ; full word from word start
    mov rsi, rsp
    syscall
    test rax, rax
    js .tab_stat_fail
    mov eax, [rsp + 24]          ; st_mode
    and eax, 0o170000            ; S_IFMT mask
    cmp eax, 0o040000            ; S_IFDIR
    je .tab_stat_dir
.tab_stat_fail:
    add rsp, 144
    jmp .tab_add_sp
.tab_stat_dir:
    add rsp, 144
.tab_add_slash:
    mov byte [line_buf + r12], '/'
    inc r12
    inc qword [line_len]
    jmp .tab_space_done
.tab_add_sp:
    ; Add a trailing space
    mov byte [line_buf + r12], ' '
    inc r12
    inc qword [line_len]
.tab_space_done:
    ; Null-terminate and redraw with highlighting
    mov rcx, [line_len]
    mov byte [line_buf + rcx], 0
    call full_redraw
    jmp .tab_done

.tab_multiple:
    ; ── Interactive tab cycling ──
    xor r15, r15             ; r15 = current selection index

.tab_cycle_redraw:
    ; Refresh prompt + previewed line FIRST so the candidate list
    ; that follows isn't wiped by full_redraw's ESC[J. Then save
    ; cursor at end of prompt, drop a newline, print candidates
    ; underneath, and restore cursor back to the prompt line.
    call .tab_preview_selection
    call full_redraw
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_save_cur]
    mov rdx, 3
    syscall
    call write_nl
    xor rcx, rcx
.tab_cycle_print:
    ; Limit display to completion_limit
    mov rax, [completion_limit]
    test rax, rax
    jz .tab_cycle_use_count
    cmp rcx, rax
    jge .tab_cycle_printed
.tab_cycle_use_count:
    cmp rcx, [tab_count]
    jge .tab_cycle_printed
    push rcx
    ; Check if this is the selected item
    cmp rcx, r15
    jne .tab_cycle_normal
    ; Highlight: reverse video
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_hl_on]
    mov rdx, .tab_hl_on_len
    syscall
    jmp .tab_cycle_name
.tab_cycle_normal:
    ; Color based on file type (LS_COLORS style)
    mov rcx, [rsp]           ; peek at saved rcx without pop
    movzx eax, byte [tab_types + rcx]
    ; DT_DIR=4: blue+bold, DT_LNK=10: cyan, DT_REG+exec: green, default: gray
    cmp al, 4               ; directory
    je .tab_color_dir
    cmp al, 10              ; symlink
    je .tab_color_link
    ; Default: dim gray
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_hl_dim]
    mov rdx, .tab_hl_dim_len
    syscall
    jmp .tab_cycle_name
.tab_color_dir:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_color_dir_seq]
    mov rdx, .tab_color_dir_len
    syscall
    jmp .tab_cycle_name
.tab_color_link:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_color_link_seq]
    mov rdx, .tab_color_link_len
    syscall
.tab_cycle_name:
    mov rcx, [rsp]
    mov rsi, [tab_results + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [tab_results + rcx*8]
    syscall
    ; Reset color
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_hl_off]
    mov rdx, 4
    syscall
    ; Space separator
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_sep]
    mov rdx, 2
    syscall
    pop rcx
    inc rcx
    jmp .tab_cycle_print
.tab_hl_on: db 27, "[7m"            ; reverse video
.tab_hl_on_len equ $ - .tab_hl_on
.tab_hl_dim: db 27, "[38;5;245m"    ; gray
.tab_hl_dim_len equ $ - .tab_hl_dim
.tab_hl_off: db 27, "[0m"
.tab_sep: db "  "
.tab_color_dir_seq: db 27, "[38;5;111;1m"    ; blue bold (matching LS_COLORS di=)
.tab_color_dir_len equ $ - .tab_color_dir_seq
.tab_color_link_seq: db 27, "[38;5;248;1m"   ; gray bold (matching LS_COLORS ln=)
.tab_color_link_len equ $ - .tab_color_link_seq

.tab_cycle_printed:
    ; Restore cursor to the prompt line. Preview + redraw already
    ; happened above; the candidate list stays visible below us.
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_restore_cur]
    mov rdx, 3
    syscall

.tab_cycle_key:
    ; Read next key
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .tab_cycle_cancel

    movzx eax, byte [tmp_buf]

    ; Tab = next match
    cmp al, 9
    je .tab_cycle_next

    ; Enter or Space = accept current selection
    cmp al, 10
    je .tab_cycle_accept
    cmp al, 13
    je .tab_cycle_accept
    cmp al, ' '
    je .tab_cycle_accept_space

    ; Escape = might be Shift-TAB (ESC[Z) or cancel
    cmp al, 27
    je .tab_cycle_esc

    ; Any other key = cancel and process that key
    jmp .tab_cycle_cancel_reprocess

.tab_cycle_next:
    inc r15
    cmp r15, [tab_count]
    jl .tab_cycle_erase
    xor r15, r15             ; wrap around
    jmp .tab_cycle_erase

.tab_cycle_prev:
    dec r15
    test r15, r15
    jns .tab_cycle_erase
    mov r15, [tab_count]
    dec r15                  ; wrap to last

.tab_cycle_erase:
    ; Restore cursor to prompt line, clear everything below
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_restore_cur]
    mov rdx, 3
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_clr_below]
    mov rdx, .tab_clr_below_len
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    jmp .tab_cycle_redraw

.tab_cycle_esc:
    ; Check for Shift-TAB (ESC[Z) with timeout
    ; Set VMIN=0 VTIME=1 for non-blocking read (100ms timeout)
    mov byte [raw_termios + 17 + VMIN], 0
    mov byte [raw_termios + 17 + VTIME], 1
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [raw_termios]
    syscall
    ; Try to read next byte
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    ; Restore VMIN=1 VTIME=0
    mov byte [raw_termios + 17 + VMIN], 1
    mov byte [raw_termios + 17 + VTIME], 0
    push rax
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [raw_termios]
    syscall
    pop rax
    ; Check result
    test rax, rax
    jle .tab_cycle_cancel     ; timeout or error = bare ESC = cancel
    cmp byte [tmp_buf], '['
    jne .tab_cycle_cancel
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .tab_cycle_cancel
    cmp byte [tmp_buf], 'Z'  ; Shift-TAB
    je .tab_cycle_prev
    jmp .tab_cycle_cancel

.tab_cycle_accept:
    ; Accept: apply the selected match permanently
    call .tab_apply_selection
    jmp .tab_cycle_cleanup

.tab_cycle_accept_space:
    ; Accept and add trailing space (or / for directories)
    call .tab_apply_selection
    ; Check d_type of selected match
    movzx eax, byte [tab_types + r15]
    cmp al, 4                ; DT_DIR
    je .tab_cycle_add_slash
    ; If d_type unknown (0) or symlink (10), stat to check
    cmp al, 10
    je .tab_cyc_stat_check
    test al, al
    jnz .tab_cycle_add_sp
.tab_cyc_stat_check:
    mov byte [line_buf + r12], 0
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [line_buf + r14]
    mov rsi, rsp
    syscall
    test rax, rax
    js .tab_cyc_stat_fail
    mov eax, [rsp + 24]
    and eax, 0o170000
    cmp eax, 0o040000
    je .tab_cyc_stat_dir
.tab_cyc_stat_fail:
    add rsp, 144
    jmp .tab_cycle_add_sp
.tab_cyc_stat_dir:
    add rsp, 144
.tab_cycle_add_slash:
    mov byte [line_buf + r12], '/'
    jmp .tab_cycle_sp_done
.tab_cycle_add_sp:
    mov byte [line_buf + r12], ' '
.tab_cycle_sp_done:
    inc r12
    inc qword [line_len]
    mov byte [line_buf + r12], 0  ; null-terminate
    jmp .tab_cycle_cleanup

.tab_cycle_cancel:
    ; Restore original line
    call .tab_restore_original
    jmp .tab_cycle_cleanup

.tab_cycle_cancel_reprocess:
    ; Restore original line, then re-inject the typed key
    call .tab_restore_original
    jmp .tab_cycle_cleanup_noread

.tab_cycle_cleanup:
.tab_cycle_cleanup_noread:
    ; Restore cursor to prompt line, clear everything below
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_restore_cur]
    mov rdx, 3
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.tab_clr_below]
    mov rdx, .tab_clr_below_len
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_eol_global]
    mov rdx, clr_eol_len
    syscall
    ; Redraw prompt + final line with syntax highlighting
    call full_redraw
    jmp .tab_done

.tab_up_cr: db 27, "[A", 13        ; cursor up + carriage return
.tab_cr: db 13
.tab_save_cur: db 27, '[', 's'     ; save cursor (ANSI, separate from ESC7)
.tab_restore_cur: db 27, '[', 'u'  ; restore cursor (ANSI)
.tab_clr_below: db 13, 27, "[J"   ; CR + clear from cursor to end of screen
.tab_clr_below_len equ $ - .tab_clr_below

; Preview selection: save original line, replace word with selected match
.tab_preview_selection:
    ; Save original word bounds for restore
    ; (r14 = word start in line_buf, tab_word_buf = original word)
    ; Replace from r14 to current word end with selected match
    mov rsi, [tab_results + r15*8]
    mov rdi, rsi
    call strlen
    mov rcx, rax             ; match length

    ; Rebuild: line_buf[0..r14] + match + rest after original cursor
    ; Copy line prefix (before word) to suggestion_buf as temp
    lea rdi, [suggestion_buf]
    lea rsi, [line_buf]
    xor rax, rax
.tps_copy_pre:
    cmp rax, r14
    jge .tps_copy_match
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .tps_copy_pre
.tps_copy_match:
    ; Copy match
    push rax                 ; save output position
    mov rsi, [tab_results + r15*8]
    xor rcx, rcx
.tps_cm:
    movzx edx, byte [rsi + rcx]
    test dl, dl
    jz .tps_match_done
    ; Escape spaces with backslash
    cmp dl, ' '
    jne .tps_no_esc
    mov byte [rdi + rax], '\'
    inc rax
.tps_no_esc:
    mov [rdi + rax], dl
    inc rax
    inc rcx
    jmp .tps_cm
.tps_match_done:
    mov byte [rdi + rax], 0
    mov r12, rax             ; cursor at end of replacement
    mov [line_len], rax
    ; Copy back to line_buf
    lea rsi, [suggestion_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.tps_cb:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .tps_done
    inc rcx
    jmp .tps_cb
.tps_done:
    pop rax                  ; discard
    ret

; Apply selection permanently (same as preview, already in line_buf)
.tab_apply_selection:
    call .tab_preview_selection
    ret

; Restore original line from tab_word_buf
.tab_restore_original:
    ; Rebuild: line_buf[0..r14] + tab_word_buf
    lea rdi, [line_buf]
    ; prefix is already there (line_buf[0..r14] unchanged structurally)
    lea rsi, [tab_word_buf]
    mov rax, r14
.tro_copy:
    movzx edx, byte [rsi]
    test dl, dl
    jz .tro_done
    mov [rdi + rax], dl
    inc rax
    inc rsi
    jmp .tro_copy
.tro_done:
    mov byte [rdi + rax], 0
    mov r12, rax
    mov [line_len], rax
    ret

.tab_done:
    pop r15
    pop r14
    jmp .read_char

.tab_no_word:
    pop r15
    pop r14
    jmp .read_char

; ── Load history line into line_buf ──────────────────────────────────
load_hist_line:
    mov rax, [hist_pos]
    mov rsi, [hist_lines + rax*8]
    test rsi, rsi
    jz .lhl_ret
    ; Copy to line_buf
    lea rdi, [line_buf]
    xor rcx, rcx
.lhl_copy:
    mov al, [rsi + rcx]
    test al, al
    jz .lhl_done
    mov [rdi + rcx], al
    inc rcx
    cmp rcx, 16382
    jge .lhl_done
    jmp .lhl_copy
.lhl_done:
    mov [rdi + rcx], byte 0
    mov [line_len], rcx
    mov r12, rcx            ; cursor at end
    call full_redraw
.lhl_ret:
    ret

; ── Redraw helpers ───────────────────────────────────────────────────
; Redraw from cursor position to end of line
redraw_from_cursor:
    push r12
    mov rcx, [line_len]
    sub rcx, r12
    test rcx, rcx
    jle .rfc_done
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [line_buf + r12]
    mov rdx, rcx
    syscall
    ; Move cursor back to position
    call reposition_cursor
.rfc_done:
    pop r12
    ret

; Calculate display width of line_buf[0..r12] (skipping UTF-8 continuation bytes)
; Returns display width in rax
cursor_display_width:
    push rbx
    xor eax, eax             ; display width
    xor ebx, ebx             ; byte index
.cdw_loop:
    cmp rbx, r12
    jge .cdw_done
    movzx ecx, byte [line_buf + rbx]
    inc rbx
    ; Skip continuation bytes (10xxxxxx = 0x80-0xBF)
    mov edx, ecx
    and edx, 0xC0
    cmp edx, 0x80
    je .cdw_loop              ; continuation byte, don't count
    inc eax                   ; leading byte or ASCII, count as 1 column
    jmp .cdw_loop
.cdw_done:
    pop rbx
    ret

; Reposition cursor (move to start of input, then forward r12 positions)
reposition_cursor:
    push r12
    ; Carriage return
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.cr]
    mov rdx, 1
    syscall
    ; Move forward past prompt (dynamic width)
    ; Use absolute column positioning
    mov rax, r12
    add rax, [prompt_visible_width]
    ; Write ESC[{n}G to set cursor column
    lea rdi, [tmp_buf]
    mov byte [rdi], 27
    mov byte [rdi+1], '['
    add rax, 1              ; 1-indexed
    push rdi
    lea rdi, [tmp_buf + 2]
    call itoa
    pop rdi
    add rdi, rax
    add rdi, 2
    mov byte [rdi], 'G'
    inc rdi
    ; Write
    mov rax, SYS_WRITE
    mov rdx, rdi
    lea rsi, [tmp_buf]
    sub rdx, rsi
    mov rdi, 1
    syscall
    pop r12
    ret
.cr: db 13

; Full redraw: CR, clear line, print prompt, print line
; All output batched into render_buf for single write (no flicker)
full_redraw:
    push r12
    push rbx

    ; Initialize render buffer
    mov qword [render_pos], 0

    ; 1. Reposition + clear. If the previous render wrapped across
    ; multiple visual rows we need to move the cursor back to the
    ; prompt's first row before clearing, otherwise only the current
    ; visual row gets wiped and stale prompt rewrites accumulate.
    ; Compute current cursor's visual-row offset from the prompt's
    ; first row using the cursor's position within line_buf.
    mov qword [render_pos], 0
    mov rcx, [term_width]
    cmp rcx, 1
    jle .fd_clear_simple
    push r12
    call cursor_display_width   ; rax = display width of line_buf[0..r12]
    pop r12
    add rax, [prompt_visible_width]
    xor edx, edx
    mov rcx, [term_width]
    div rcx                     ; rax = cursor row offset, edx = col
    test rax, rax
    jz .fd_clear_no_up
    ; Emit ESC[<rows>A then CR.  CSI NA = cursor up N rows; many
    ; minimal terminal parsers (incl. our glass) implement A but not
    ; F (CPL), so the explicit CR keeps us portable.
    mov rdi, [render_pos]
    lea rdi, [render_buf + rdi]
    mov byte [rdi], 27
    mov byte [rdi + 1], '['
    add rdi, 2
    push rdi
    lea rdi, [num_buf]
    call itoa                   ; rax = digit count
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.fd_cp_up_init:
    cmp ecx, eax
    jge .fd_cp_up_init_done
    movzx ebx, byte [rsi + rcx]
    mov [rdi + rcx], bl
    inc ecx
    jmp .fd_cp_up_init
.fd_cp_up_init_done:
    add rdi, rax
    mov byte [rdi], 'A'
    mov byte [rdi + 1], 13      ; CR to col 0
    add rdi, 2
    lea rax, [render_buf]
    sub rdi, rax
    mov [render_pos], rdi
    jmp .fd_clear_to_eos
.fd_clear_no_up:
    ; Already on the prompt's first visual row: just CR
    mov rdi, [render_pos]
    mov byte [render_buf + rdi], 13
    inc rdi
    mov [render_pos], rdi
    jmp .fd_clear_to_eos
.fd_clear_simple:
    ; Unknown term width: fall back to old behavior (CR + ESC[2K)
    mov rdi, [render_pos]
    mov byte [render_buf + rdi], 13
    mov byte [render_buf + rdi + 1], 27
    mov byte [render_buf + rdi + 2], '['
    mov byte [render_buf + rdi + 3], '2'
    mov byte [render_buf + rdi + 4], 'K'
    add rdi, 5
    mov [render_pos], rdi
    jmp .fd_after_clear
.fd_clear_to_eos:
    ; Append ESC[J (clear from cursor to end of screen)
    mov rdi, [render_pos]
    mov byte [render_buf + rdi], 27
    mov byte [render_buf + rdi + 1], '['
    mov byte [render_buf + rdi + 2], 'J'
    add rdi, 3
    mov [render_pos], rdi
.fd_after_clear:

    ; Set batching flag for all sub-calls
    mov qword [render_to_buf], 1

    ; 2. Print prompt into render buffer
    call print_prompt

    ; 3. Syntax highlighted line content
    mov rcx, [line_len]
    test rcx, rcx
    jz .fd_repos
    cmp qword [is_tty], 0
    je .fd_plain_buf
    ; syntax_highlight_line writes to suggestion_buf (skips write when render_to_buf=1)
    call syntax_highlight_line
    ; Copy suggestion_buf output into render_buf
    mov rcx, [shl_output_len]
    test rcx, rcx
    jz .fd_repos
    lea rsi, [suggestion_buf]
    mov rdi, [render_pos]
    lea rdi, [render_buf + rdi]
    xor rax, rax
.fd_copy_hl:
    cmp rax, rcx
    jge .fd_copy_done
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .fd_copy_hl
.fd_copy_done:
    add [render_pos], rcx
    jmp .fd_repos

.fd_plain_buf:
    ; Copy plain line_buf into render_buf
    mov rcx, [line_len]
    lea rsi, [line_buf]
    mov rdi, [render_pos]
    lea rdi, [render_buf + rdi]
    xor rax, rax
.fd_plain_copy:
    cmp rax, rcx
    jge .fd_plain_done
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .fd_plain_copy
.fd_plain_done:
    add [render_pos], rcx

.fd_repos:
    ; 4. Reposition cursor for wrapped lines
    ; After writing all content, cursor is at prompt_width + line_len
    ; We want it at prompt_width + r12
    ; Calculate rows/cols for both positions
    mov rdi, [render_pos]
    lea rdi, [render_buf + rdi]

    ; Current position (end of content) using display width
    ; Save r12, temporarily set it to line_len for display width calc
    push r12
    mov r12, [line_len]
    call cursor_display_width  ; rax = display width of entire line
    pop r12
    add rax, [prompt_visible_width]
    xor edx, edx
    mov rcx, [term_width]
    test rcx, rcx
    jz .fd_repos_simple
    cmp rcx, 1
    jle .fd_repos_simple
    push rax
    div rcx                    ; rax = end_row, edx = end_col
    mov rbx, rax               ; rbx = end_row

    ; Target position (cursor) using display width
    call cursor_display_width  ; rax = display width of line_buf[0..r12]
    add rax, [prompt_visible_width]
    xor edx, edx
    mov rcx, [term_width]
    div rcx                    ; rax = target_row, edx = target_col
    pop rcx                    ; discard saved end position

    ; Move up (end_row - target_row) rows
    sub rbx, rax               ; rows to move up
    test rbx, rbx
    jz .fd_repos_col
    mov byte [rdi], 27
    mov byte [rdi + 1], '['
    add rdi, 2
    mov rax, rbx
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.fd_cp_up2:
    cmp ecx, eax
    jge .fd_cp_up2_done
    movzx ebx, byte [rsi + rcx]
    mov [rdi + rcx], bl
    inc ecx
    jmp .fd_cp_up2
.fd_cp_up2_done:
    add rdi, rax
    mov byte [rdi], 'A'
    inc rdi

.fd_repos_col:
    ; Set column: ESC[{col+1}G
    mov byte [rdi], 13         ; CR first
    inc rdi
    inc edx                    ; 1-indexed column
    test edx, edx
    jz .fd_repos_done
    mov byte [rdi], 27
    mov byte [rdi + 1], '['
    add rdi, 2
    mov rax, rdx
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.fd_cp_col2:
    cmp ecx, eax
    jge .fd_cp_col2_done
    movzx ebx, byte [rsi + rcx]
    mov [rdi + rcx], bl
    inc ecx
    jmp .fd_cp_col2
.fd_cp_col2_done:
    add rdi, rax
    mov byte [rdi], 'G'
    inc rdi
    jmp .fd_repos_done

.fd_repos_simple:
    ; No term_width, fallback to simple CR + col
    mov byte [rdi], 13
    mov byte [rdi + 1], 27
    mov byte [rdi + 2], '['
    add rdi, 3
    call cursor_display_width  ; rax = display width of line_buf[0..r12]
    add rax, [prompt_visible_width]
    inc rax
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.fd_cp_simple:
    cmp ecx, eax
    jge .fd_cp_simple_done
    movzx ebx, byte [rsi + rcx]
    mov [rdi + rcx], bl
    inc ecx
    jmp .fd_cp_simple
.fd_cp_simple_done:
    add rdi, rax
    mov byte [rdi], 'G'
    inc rdi

.fd_repos_done:
    ; Update render_pos
    sub rdi, render_buf
    mov [render_pos], rdi

    ; 5. Clear batching flag and single write of entire render buffer
    mov qword [render_to_buf], 0
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [render_buf]
    mov rdx, [render_pos]
    syscall

    pop rbx
    pop r12
    ret

; ══════════════════════════════════════════════════════════════════════
; Tilde expansion + Environment variable expansion
; Operates on line_buf in-place (uses expand_buf as temp)
; ══════════════════════════════════════════════════════════════════════
expand_line:
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rsi, [line_buf]     ; source
    lea rdi, [expand_buf]   ; destination
    xor r12, r12            ; output position
    mov r14, 4090           ; max output size

.exp_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .exp_done

    ; Check for single-quoted string (no expansion inside)
    cmp al, 0x27            ; single quote
    je .exp_single_quote

    ; Check for tilde at start of word
    cmp al, '~'
    jne .exp_check_dollar
    ; Check if this is start of a word (beginning of line or after space)
    cmp rsi, line_buf
    je .exp_tilde
    cmp byte [rsi - 1], ' '
    je .exp_tilde
    cmp byte [rsi - 1], 9   ; tab
    je .exp_tilde
    cmp byte [rsi - 1], '='
    je .exp_tilde
    cmp byte [rsi - 1], ':'
    je .exp_tilde
    jmp .exp_copy_char

.exp_tilde:
    ; Check next char: must be / or null or space for simple tilde
    movzx eax, byte [rsi + 1]
    test al, al
    jz .exp_tilde_expand
    cmp al, '/'
    je .exp_tilde_expand
    cmp al, ' '
    je .exp_tilde_expand
    cmp al, 9
    je .exp_tilde_expand
    ; Not a simple tilde, copy literally
    jmp .exp_copy_char

.exp_tilde_expand:
    ; Replace ~ with HOME value
    push rsi
    push rdi
    lea rdi, [env_array]
    mov rdi, [envp]
    call find_env_home
    pop rdi
    pop rsi
    test rax, rax
    jz .exp_copy_char       ; HOME not found, copy ~ literally
    ; Copy HOME value to output
    mov rcx, rax
.exp_tilde_copy:
    movzx eax, byte [rcx]
    test al, al
    jz .exp_tilde_copied
    cmp r12, r14
    jge .exp_done
    mov [rdi + r12], al
    inc r12
    inc rcx
    jmp .exp_tilde_copy
.exp_tilde_copied:
    inc rsi                 ; skip the ~
    jmp .exp_loop

.exp_check_dollar:
    cmp al, '$'
    jne .exp_copy_char

    ; Check for $? (last exit status)
    cmp byte [rsi + 1], '?'
    je .exp_dollar_question
    ; Check for $$ (PID)
    cmp byte [rsi + 1], '$'
    je .exp_dollar_dollar
    ; Check for ${VAR}
    cmp byte [rsi + 1], '{'
    je .exp_dollar_brace
    ; Check for $VAR (alphanumeric or _)
    movzx eax, byte [rsi + 1]
    call is_var_char
    test al, al
    jz .exp_copy_char       ; not a var name char, copy $ literally
    jmp .exp_dollar_var

.exp_dollar_question:
    ; Expand $? to last exit status
    inc rsi                 ; skip $
    inc rsi                 ; skip ?
    push rsi
    push rdi
    mov rax, [last_status]
    lea rdi, [num_buf]
    call itoa
    mov rcx, rax            ; length
    lea rsi, [num_buf]
    pop rdi
    ; Copy number to output
.exp_dq_copy:
    test rcx, rcx
    jz .exp_dq_done
    movzx eax, byte [rsi]
    cmp r12, r14
    jge .exp_dq_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    dec rcx
    jmp .exp_dq_copy
.exp_dq_done:
    pop rsi
    jmp .exp_loop

.exp_dollar_dollar:
    ; Expand $$ to PID
    inc rsi
    inc rsi
    push rsi
    push rdi
    mov rax, [my_pid]
    lea rdi, [num_buf]
    call itoa
    mov rcx, rax
    lea rsi, [num_buf]
    pop rdi
.exp_dd_copy:
    test rcx, rcx
    jz .exp_dd_done
    movzx eax, byte [rsi]
    cmp r12, r14
    jge .exp_dd_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    dec rcx
    jmp .exp_dd_copy
.exp_dd_done:
    pop rsi
    jmp .exp_loop

.exp_dollar_brace:
    ; ${VAR} syntax
    inc rsi                 ; skip $
    inc rsi                 ; skip {
    ; Find closing }
    mov r13, rsi            ; start of var name
.exp_brace_scan:
    cmp byte [rsi], 0
    je .exp_copy_char_back  ; unterminated, copy literally
    cmp byte [rsi], '}'
    je .exp_brace_found
    inc rsi
    jmp .exp_brace_scan
.exp_brace_found:
    ; Null-terminate var name temporarily
    mov byte [rsi], 0
    push rsi
    ; Look up variable
    mov rdi, r13
    call lookup_env_var
    pop rsi
    mov byte [rsi], '}'     ; restore
    inc rsi                 ; skip past }
    lea rdi, [expand_buf]   ; restore output pointer
    test rax, rax
    jz .exp_loop            ; var not found, replace with nothing
    ; Copy value
    mov rcx, rax
.exp_brace_copy:
    movzx eax, byte [rcx]
    test al, al
    jz .exp_loop
    cmp r12, r14
    jge .exp_done
    mov [rdi + r12], al
    inc r12
    inc rcx
    jmp .exp_brace_copy

.exp_copy_char_back:
    ; We moved rsi past the $ and {, put $ back
    mov byte [rdi + r12], '$'
    inc r12
    jmp .exp_loop

.exp_dollar_var:
    ; $VAR syntax
    inc rsi                 ; skip $
    mov r13, rsi            ; start of var name
.exp_var_scan:
    movzx eax, byte [rsi]
    call is_var_char
    test al, al
    jz .exp_var_end
    inc rsi
    jmp .exp_var_scan
.exp_var_end:
    ; Save the char at end, null-terminate
    movzx r15d, byte [rsi]
    mov byte [rsi], 0
    push rsi
    mov rdi, r13
    call lookup_env_var
    pop rsi
    mov [rsi], r15b         ; restore
    lea rdi, [expand_buf]   ; restore output pointer after lookup
    test rax, rax
    jz .exp_loop            ; var not found, expand to nothing
    ; Copy value
    mov rcx, rax
.exp_var_copy:
    movzx eax, byte [rcx]
    test al, al
    jz .exp_loop
    cmp r12, r14
    jge .exp_done
    mov [rdi + r12], al
    inc r12
    inc rcx
    jmp .exp_var_copy

.exp_single_quote:
    ; Copy everything until closing single quote literally
    cmp r12, r14
    jge .exp_done
    mov [rdi + r12], al
    inc r12
    inc rsi
.exp_sq_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .exp_done
    cmp r12, r14
    jge .exp_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    cmp al, 0x27            ; closing quote
    je .exp_loop
    jmp .exp_sq_loop

.exp_copy_char:
    cmp r12, r14
    jge .exp_done
    movzx eax, byte [rsi]
    mov [rdi + r12], al
    inc r12
    inc rsi
    jmp .exp_loop

.exp_done:
    ; Null-terminate output
    mov byte [rdi + r12], 0
    ; Copy expand_buf back to line_buf
    lea rsi, [expand_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.exp_copyback:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .exp_copyback_done
    inc rcx
    jmp .exp_copyback
.exp_copyback_done:
    mov [line_len], rcx

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Check if al is a valid variable name character (a-z, A-Z, 0-9, _)
; Input: eax = character
; Output: al = 1 if valid, 0 if not
; Clobbers only eax
is_var_char:
    cmp al, '_'
    je .ivc_yes
    cmp al, 'a'
    jl .ivc_check_upper
    cmp al, 'z'
    jle .ivc_yes
.ivc_check_upper:
    cmp al, 'A'
    jl .ivc_check_digit
    cmp al, 'Z'
    jle .ivc_yes
.ivc_check_digit:
    cmp al, '0'
    jl .ivc_no
    cmp al, '9'
    jle .ivc_yes
.ivc_no:
    xor eax, eax
    ret
.ivc_yes:
    mov eax, 1
    ret

; Look up a variable name in the environment
; rdi = pointer to null-terminated variable name
; Returns: rax = pointer to value (after =), or 0 if not found
lookup_env_var:
    push rbx
    push r12
    push r13
    mov r12, rdi            ; save var name

    ; First search env_array (custom env)
    xor rcx, rcx
.lev_loop:
    cmp rcx, [env_count]
    jge .lev_notfound
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .lev_next
    ; Compare var name against beginning of this entry
    mov rdi, r12
    mov rbx, rsi
.lev_cmp:
    movzx eax, byte [rdi]
    test al, al
    jz .lev_check_eq
    movzx edx, byte [rbx]
    cmp al, dl
    jne .lev_next
    inc rdi
    inc rbx
    jmp .lev_cmp
.lev_check_eq:
    cmp byte [rbx], '='
    jne .lev_next
    ; Found it
    lea rax, [rbx + 1]
    pop r13
    pop r12
    pop rbx
    ret
.lev_next:
    inc rcx
    jmp .lev_loop

    ; env_array is initialized from envp, so no fallback needed.
    ; This ensures unset works correctly.

.lev_notfound:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Command chaining: split by ;, &&, || and execute sequentially
; rdi = pointer to null-terminated line
; ══════════════════════════════════════════════════════════════════════
execute_chained_line:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp

    mov r15, rdi             ; save line pointer

    ; Parse the line into chain_cmds[] and chain_ops[]
    call parse_chain

    ; Execute each command in sequence
    xor r12, r12             ; chain index
.chain_loop:
    cmp r12, [chain_count]
    jge .chain_done

    ; Check the operator before this command (if not first)
    test r12, r12
    jz .chain_exec           ; first command always runs

    ; Get the operator before this command
    movzx eax, byte [chain_ops + r12 - 1]
    cmp al, 2                ; &&
    je .chain_check_and
    cmp al, 3                ; ||
    je .chain_check_or
    ; Operator is ; (1) or none (0): always execute
    jmp .chain_exec

.chain_check_and:
    ; Only execute if last_status == 0
    cmp qword [last_status], 0
    jne .chain_skip
    jmp .chain_exec

.chain_check_or:
    ; Only execute if last_status != 0
    cmp qword [last_status], 0
    je .chain_skip
    jmp .chain_exec

.chain_skip:
    inc r12
    jmp .chain_loop

.chain_exec:
    ; Get command pointer
    mov rdi, [chain_cmds + r12*8]
    ; Skip leading spaces
    mov rsi, rdi
    call skip_spaces
    mov rdi, rsi
    ; Check if empty
    cmp byte [rdi], 0
    je .chain_next

    ; Check for background execution (&)
    push rdi
    call check_background
    pop rdi
    ; rax = 1 if background, 0 if not

    test rax, rax
    jnz .chain_exec_bg

    ; Normal execution (may contain pipes)
    call execute_line
    jmp .chain_next

.chain_exec_bg:
    ; Background execution
    call execute_line_bg
    jmp .chain_next

.chain_next:
    inc r12
    jmp .chain_loop

.chain_done:
    mov rsp, rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Parse line into chain commands and operators
; r15 = line pointer
parse_chain:
    push rbx
    push r12

    mov rsi, r15
    xor ecx, ecx            ; command count
    mov [chain_cmds], rsi    ; first command starts at beginning

    ; Skip chain splitting for alias definitions (value may contain ;)
    cmp byte [rsi], ':'
    jne .pc_scan
    ; Check for :nick, :gnick, :abbrev
    push rsi
    inc rsi                  ; skip ':'
    lea rdi, [.pc_str_nick]
    call .pc_prefix_check
    test rax, rax
    jnz .pc_no_split
    lea rdi, [.pc_str_gnick]
    call .pc_prefix_check
    test rax, rax
    jnz .pc_no_split
    lea rdi, [.pc_str_abbrev]
    call .pc_prefix_check
    test rax, rax
    jnz .pc_no_split
    pop rsi
    jmp .pc_scan

.pc_no_split:
    pop rsi
    ; Treat entire line as one command
    mov qword [chain_count], 1
    pop r12
    pop rbx
    ret

.pc_prefix_check:
    ; rsi = source (after ':'), rdi = target string
    ; Returns rax=1 if prefix matches followed by space/null, rax=0 otherwise
    push rsi
.pc_pc_loop:
    movzx eax, byte [rdi]
    test al, al
    jz .pc_pc_end
    movzx ebx, byte [rsi]
    cmp al, bl
    jne .pc_pc_fail
    inc rsi
    inc rdi
    jmp .pc_pc_loop
.pc_pc_end:
    ; Check that next char is space or null (word boundary)
    movzx eax, byte [rsi]
    cmp al, ' '
    je .pc_pc_yes
    test al, al
    jz .pc_pc_yes
.pc_pc_fail:
    pop rsi
    xor eax, eax
    ret
.pc_pc_yes:
    pop rsi
    mov eax, 1
    ret

.pc_str_nick: db "nick", 0
.pc_str_gnick: db "gnick", 0
.pc_str_abbrev: db "abbrev", 0

.pc_scan:
    movzx eax, byte [rsi]
    test al, al
    jz .pc_end_cmd

    ; Check for single quotes (skip contents)
    cmp al, 0x27
    je .pc_skip_squote
    ; Check for double quotes (skip contents)
    cmp al, '"'
    je .pc_skip_dquote

    ; Check for || (must check before single |)
    cmp al, '|'
    jne .pc_check_amp
    cmp byte [rsi + 1], '|'
    jne .pc_check_pipe
    ; Found ||
    mov byte [rsi], 0       ; null-terminate previous command
    mov [chain_ops + rcx], byte 3  ; ||
    inc ecx
    add rsi, 2              ; skip ||
    ; Skip spaces
.pc_skip_sp1:
    cmp byte [rsi], ' '
    jne .pc_store1
    inc rsi
    jmp .pc_skip_sp1
.pc_store1:
    mov [chain_cmds + rcx*8], rsi
    jmp .pc_scan

.pc_check_pipe:
    ; Single | is NOT a chain operator, it's a pipe
    ; Let execute_line handle it
    inc rsi
    jmp .pc_scan

.pc_check_amp:
    cmp al, '&'
    jne .pc_check_semi
    cmp byte [rsi + 1], '&'
    jne .pc_not_chain_amp
    ; Found &&
    mov byte [rsi], 0
    mov [chain_ops + rcx], byte 2  ; &&
    inc ecx
    add rsi, 2
.pc_skip_sp2:
    cmp byte [rsi], ' '
    jne .pc_store2
    inc rsi
    jmp .pc_skip_sp2
.pc_store2:
    mov [chain_cmds + rcx*8], rsi
    jmp .pc_scan

.pc_not_chain_amp:
    ; Single & is background operator, don't split here
    inc rsi
    jmp .pc_scan

.pc_check_semi:
    cmp al, ';'
    jne .pc_advance
    ; Found ;
    mov byte [rsi], 0
    mov [chain_ops + rcx], byte 1  ; ;
    inc ecx
    inc rsi
.pc_skip_sp3:
    cmp byte [rsi], ' '
    jne .pc_store3
    inc rsi
    jmp .pc_skip_sp3
.pc_store3:
    mov [chain_cmds + rcx*8], rsi
    jmp .pc_scan

.pc_advance:
    inc rsi
    jmp .pc_scan

.pc_skip_squote:
    inc rsi
.pc_sq_loop:
    cmp byte [rsi], 0
    je .pc_end_cmd
    cmp byte [rsi], 0x27
    je .pc_sq_done
    inc rsi
    jmp .pc_sq_loop
.pc_sq_done:
    inc rsi
    jmp .pc_scan

.pc_skip_dquote:
    inc rsi
.pc_dq_loop:
    cmp byte [rsi], 0
    je .pc_end_cmd
    cmp byte [rsi], '"'
    je .pc_dq_done
    inc rsi
    jmp .pc_dq_loop
.pc_dq_done:
    inc rsi
    jmp .pc_scan

.pc_end_cmd:
    inc ecx
    mov [chain_count], rcx

    pop r12
    pop rbx
    ret

; Check if line ends with & (background execution)
; rdi = command string
; Returns: rax = 1 if background, 0 if not
; If background, removes the & from the string
check_background:
    push rbx
    mov rsi, rdi
    call strlen
    test rax, rax
    jz .cb_no
    mov rcx, rax
    dec rcx
    ; Skip trailing spaces
.cb_skip_space:
    cmp rcx, 0
    jl .cb_no
    cmp byte [rdi + rcx], ' '
    jne .cb_check
    dec rcx
    jmp .cb_skip_space
.cb_check:
    cmp byte [rdi + rcx], '&'
    jne .cb_no
    ; Make sure it's not && (look at char before)
    test rcx, rcx
    jz .cb_found
    cmp byte [rdi + rcx - 1], '&'
    je .cb_no               ; it's &&, not background &
.cb_found:
    ; Remove the &
    mov byte [rdi + rcx], 0
    ; Trim trailing spaces
    dec rcx
.cb_trim:
    cmp rcx, 0
    jl .cb_yes
    cmp byte [rdi + rcx], ' '
    jne .cb_yes
    mov byte [rdi + rcx], 0
    dec rcx
    jmp .cb_trim
.cb_yes:
    mov rax, 1
    pop rbx
    ret
.cb_no:
    xor eax, eax
    pop rbx
    ret

; Execute a command in background (fork but don't wait)
; rdi = command string
execute_line_bg:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    mov r15, rdi

    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .bg_child
    js .bg_fork_err

    ; Parent: register the bg job and print "[N] PID" like bash.
    mov r12, rax             ; save pid
    mov rdi, r12
    mov rsi, r15             ; command string
    call add_bg_job          ; returns rax = job number (1-based), 0 on overflow
    mov r13, rax             ; save job num
    ; Print "["
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [bg_open]
    mov rdx, 1
    syscall
    ; Print job number
    mov rax, r13
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    ; Print "] "
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [bg_jobsep]
    mov rdx, 2
    syscall
    ; Print pid
    mov rax, r12
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    ; Print newline
    call write_nl

    mov qword [last_status], 0
    jmp .bg_done

.bg_child:
    ; Child process: execute the command.
    ; Move the bg child into its own process group so that any tty I/O
    ; the command attempts (e.g. vim opening /dev/tty) raises
    ; SIGTTIN/SIGTTOU. The kernel suspends the offender instead of
    ; letting it race bare for keystrokes.
    mov rax, SYS_SETPGID
    xor edi, edi             ; pid 0 = self
    xor esi, esi             ; pgid 0 = use own pid
    syscall
    ; Pretend we're not on a TTY so enable_cooked_mode / enable_raw_mode
    ; in execute_line don't reach behind the parent's back and reset
    ; bare's own termios while it is reading the next line.
    mov qword [is_tty], 0
    ; Restore default signal handling
    call restore_child_signals
    mov rdi, r15
    call execute_line
    ; If the inner child suspended (SIGTTIN etc.), execute_line returned
    ; without reaping it. Keep blocking on wait4(-1) so bg_child does
    ; NOT exit while a stopped child is alive — otherwise the kernel
    ; orphans the stopped child's pgrp and delivers SIGHUP + SIGCONT,
    ; which vim treats as fatal.
.bg_wait_remaining:
    mov rax, SYS_WAIT4
    mov rdi, -1
    xor esi, esi
    xor edx, edx             ; no WUNTRACED -> only return on real exit
    xor r10d, r10d
    syscall
    test rax, rax
    jg .bg_wait_remaining
    mov rax, SYS_EXIT
    mov rdi, [last_status]
    syscall

.bg_fork_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_fork]
    mov rdx, err_fork_len
    syscall

.bg_done:
    mov rsp, rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Restore default signal handlers (for child processes)
restore_child_signals:
    sub rsp, 160
    xor eax, eax
    mov rdi, rsp
    mov rcx, 160
    rep stosb
    mov qword [rsp], SIG_DFL
    ; Restore SIGINT to default
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGINT
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Restore SIGTSTP to default
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTSTP
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Restore SIGQUIT to default
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGQUIT
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Restore SIGTTIN to default so background readers stop instead of
    ; getting EIO (vim & must suspend, not die).
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTTIN
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Restore SIGTTOU to default for the same reason on output to tty
    ; from a background pgrp under TOSTOP.
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTTOU
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    add rsp, 160
    ret

; ══════════════════════════════════════════════════════════════════════
; Execute a command line (may contain pipes)
; rdi = pointer to null-terminated line
; ══════════════════════════════════════════════════════════════════════
execute_line:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp

    mov r15, rdi            ; save line pointer

    ; Check for pipes
    mov rsi, r15
    xor ecx, ecx            ; pipe count
.count_pipes:
    mov al, [rsi]
    test al, al
    jz .pipes_counted
    ; Skip quoted strings
    cmp al, 0x27
    je .cp_skip_sq
    cmp al, '"'
    je .cp_skip_dq
    cmp al, '|'
    jne .cp_next
    ; Make sure it's not ||
    cmp byte [rsi + 1], '|'
    je .cp_skip_dblpipe
    inc ecx
.cp_next:
    inc rsi
    jmp .count_pipes
.cp_skip_sq:
    inc rsi
.cp_sq_l:
    cmp byte [rsi], 0
    je .pipes_counted
    cmp byte [rsi], 0x27
    je .cp_next
    inc rsi
    jmp .cp_sq_l
.cp_skip_dq:
    inc rsi
.cp_dq_l:
    cmp byte [rsi], 0
    je .pipes_counted
    cmp byte [rsi], '"'
    je .cp_next
    inc rsi
    jmp .cp_dq_l
.cp_skip_dblpipe:
    add rsi, 2
    jmp .count_pipes
.pipes_counted:
    test ecx, ecx
    jnz .handle_pipes

    ; No pipes: simple command
    mov rdi, r15
    call parse_and_exec_simple

    mov rsp, rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.handle_pipes:
    ; ── Multi-pipe: split by '|' into segments, fork N+1 children ──
    ; Step 1: split line by '|' (respecting quotes) into pipe_segments[]
    mov rdi, r15
    mov qword [pipe_seg_count], 0
    mov rax, [pipe_seg_count]
    mov [pipe_segments + rax*8], rdi     ; first segment
    inc qword [pipe_seg_count]
    mov rsi, rdi

.mp_scan:
    mov al, [rsi]
    test al, al
    jz .mp_scan_done
    cmp al, 0x27             ; single quote
    je .mp_skip_sq
    cmp al, '"'
    je .mp_skip_dq
    cmp al, '|'
    jne .mp_scan_next
    ; Check for || (logical OR, not pipe)
    cmp byte [rsi + 1], '|'
    je .mp_skip_or
    ; Found pipe separator
    mov byte [rsi], 0        ; null-terminate previous segment
    inc rsi
    ; Skip leading spaces of next segment
.mp_skip_ws:
    cmp byte [rsi], ' '
    jne .mp_add_seg
    inc rsi
    jmp .mp_skip_ws
.mp_add_seg:
    mov rax, [pipe_seg_count]
    cmp rax, MAX_PIPE_SEGMENTS
    jge .mp_scan_done
    mov [pipe_segments + rax*8], rsi
    inc qword [pipe_seg_count]
    jmp .mp_scan
.mp_skip_or:
    add rsi, 2
    jmp .mp_scan
.mp_skip_sq:
    inc rsi
.mp_sq_loop:
    cmp byte [rsi], 0
    je .mp_scan_done
    cmp byte [rsi], 0x27
    je .mp_scan_next
    inc rsi
    jmp .mp_sq_loop
.mp_skip_dq:
    inc rsi
.mp_dq_loop:
    cmp byte [rsi], 0
    je .mp_scan_done
    cmp byte [rsi], '"'
    je .mp_scan_next
    inc rsi
    jmp .mp_dq_loop
.mp_scan_next:
    inc rsi
    jmp .mp_scan
.mp_scan_done:

    ; Step 2: create N-1 pipes (N = pipe_seg_count)
    mov rcx, [pipe_seg_count]
    dec rcx                  ; number of pipes needed
    test rcx, rcx
    jz .mp_single            ; shouldn't happen but safety
    mov r12, rcx             ; r12 = num pipes
    xor r13, r13             ; pipe index
.mp_create_pipes:
    cmp r13, r12
    jge .mp_pipes_created
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds_array + r13*8]
    syscall
    test rax, rax
    jnz .pipe_error
    inc r13
    jmp .mp_create_pipes
.mp_pipes_created:

    ; Step 3: fork children for each segment
    xor r13, r13             ; segment index
.mp_fork_loop:
    cmp r13, [pipe_seg_count]
    jge .mp_parent_cleanup

    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .mp_child
    js .pipe_error
    ; Parent: save child pid
    mov [pipe_child_pids + r13*8], rax
    inc r13
    jmp .mp_fork_loop

.mp_child:
    ; Child process for segment r13
    ; Set up stdin from previous pipe (if not first segment)
    test r13, r13
    jz .mp_child_no_stdin
    ; stdin = read end of pipe[r13-1]
    lea rax, [r13 - 1]
    mov edi, [pipe_fds_array + rax*8]    ; read end
    mov rax, SYS_DUP2
    xor esi, esi             ; fd 0 = stdin
    syscall

.mp_child_no_stdin:
    ; Set up stdout to next pipe (if not last segment)
    mov rax, [pipe_seg_count]
    dec rax
    cmp r13, rax
    jge .mp_child_no_stdout
    ; stdout = write end of pipe[r13]
    mov edi, [pipe_fds_array + r13*8 + 4]  ; write end
    mov rax, SYS_DUP2
    mov esi, 1               ; fd 1 = stdout
    syscall

.mp_child_no_stdout:
    ; Close ALL pipe fds in child
    xor r14, r14
.mp_child_close:
    cmp r14, r12
    jge .mp_child_exec
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds_array + r14*8]     ; read end
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds_array + r14*8 + 4] ; write end
    syscall
    inc r14
    jmp .mp_child_close

.mp_child_exec:
    ; Execute the command for this segment
    mov rdi, [pipe_segments + r13*8]
    call parse_and_exec_child
    mov rax, SYS_EXIT
    xor edi, edi
    syscall

.mp_parent_cleanup:
    ; Parent: close all pipe fds
    xor r13, r13
.mp_close_all:
    cmp r13, r12
    jge .mp_wait_all
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds_array + r13*8]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds_array + r13*8 + 4]
    syscall
    inc r13
    jmp .mp_close_all

.mp_wait_all:
    ; Wait for all children
    sub rsp, 16
    mov r14, [pipe_seg_count]
    xor r13, r13
.mp_wait_loop:
    cmp r13, r14
    jge .mp_wait_done
.mp_wait_retry:
    mov rax, SYS_WAIT4
    mov rdi, [pipe_child_pids + r13*8]
    lea rsi, [rsp]
    xor edx, edx
    xor r10d, r10d
    syscall
    cmp rax, -4              ; EINTR (e.g. SIGWINCH while child owns terminal)
    je .mp_wait_retry
    inc r13
    jmp .mp_wait_loop
.mp_wait_done:
    ; Get exit status of last child
    mov eax, [rsp]
    shr eax, 8
    and eax, 0xFF
    mov [last_status], rax
    add rsp, 16
    jmp .pipe_done

.mp_single:
    mov rdi, r15
    call parse_and_exec_simple
    jmp .pipe_done

.pipe_error:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_pipe]
    mov rdx, err_pipe_len
    syscall

.pipe_done:
.single_cmd:
    mov rsp, rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Parse args and execute a simple command (no pipes)
; rdi = command string
; ══════════════════════════════════════════════════════════════════════
; Detect leading "IDENT=value" tokens in argv_ptrs and stash them in
; env_prefix_ptrs[]. Shifts argv_ptrs left so argv[0] becomes the
; first non-assignment token. argc is decremented accordingly.
;
; The assignments are applied in the child (post-fork) via
; apply_env_prefix; the parent's env_array stays untouched so the
; semantics match bash (the assignments only affect this one command).
extract_env_prefix:
    push rbx
    push r12
    mov qword [env_prefix_count], 0
    xor r12, r12                          ; index into argv
.eep_loop:
    cmp r12, [argc]
    jge .eep_done
    mov rbx, [argv_ptrs + r12*8]
    test rbx, rbx
    jz .eep_done
    ; Identifier: first char must be A-Z, a-z, or _.
    movzx eax, byte [rbx]
    cmp al, '_'
    je .eep_check_rest
    cmp al, 'A'
    jb .eep_done
    cmp al, 'Z'
    jbe .eep_check_rest
    cmp al, 'a'
    jb .eep_done
    cmp al, 'z'
    ja .eep_done
.eep_check_rest:
    mov rdi, rbx
    inc rdi
.eep_id_chars:
    movzx eax, byte [rdi]
    cmp al, '='
    je .eep_assignment
    cmp al, 0
    je .eep_done                          ; no '=' → not an assignment
    cmp al, '_'
    je .eep_id_ok
    cmp al, '0'
    jb .eep_done
    cmp al, '9'
    jbe .eep_id_ok
    cmp al, 'A'
    jb .eep_done
    cmp al, 'Z'
    jbe .eep_id_ok
    cmp al, 'a'
    jb .eep_done
    cmp al, 'z'
    ja .eep_done
.eep_id_ok:
    inc rdi
    jmp .eep_id_chars
.eep_assignment:
    ; Got VAR=...; record the pointer.
    mov rax, [env_prefix_count]
    cmp rax, 16
    jge .eep_done                         ; cap reached
    mov [env_prefix_ptrs + rax*8], rbx
    inc qword [env_prefix_count]
    inc r12
    jmp .eep_loop
.eep_done:
    test r12, r12
    jz .eep_ret                           ; nothing to shift
    ; Shift argv_ptrs left by r12 entries; argc -= r12.
    mov rcx, [argc]
    sub rcx, r12
    mov [argc], rcx
    xor edx, edx
.eep_shift:
    cmp rdx, rcx
    jge .eep_term
    mov rax, rdx
    add rax, r12
    mov rsi, [argv_ptrs + rax*8]
    mov [argv_ptrs + rdx*8], rsi
    inc rdx
    jmp .eep_shift
.eep_term:
    mov qword [argv_ptrs + rdx*8], 0
.eep_ret:
    pop r12
    pop rbx
    ret

; Apply the recorded env_prefix assignments by calling env_set_entry
; on each. Called from the CHILD just before execve so the parent's
; env_array is untouched.
apply_env_prefix:
    push rbx
    push r12
    xor r12, r12
.aep_loop:
    cmp r12, [env_prefix_count]
    jge .aep_done
    mov rdi, [env_prefix_ptrs + r12*8]
    call env_set_entry
    inc r12
    jmp .aep_loop
.aep_done:
    pop r12
    pop rbx
    ret

parse_and_exec_simple:
    push rbx
    push r12
    push r13

    ; Reset redirects
    mov qword [redir_out], 0
    mov qword [redir_in], 0
    mov qword [redir_herestring], 0
    mov qword [redir_append], 0

    ; Parse into argv
    mov rsi, rdi
    call parse_argv
    cmp qword [argc], 0
    je .paes_done

    ; Strip leading "VAR=val" tokens; saved in env_prefix_ptrs[].
    call extract_env_prefix
    cmp qword [argc], 0
    je .paes_done

    ; Perform glob expansion on argv
    call glob_expand_argv

    ; Nick expansion: check if argv[0] is an alias
    lea rdi, [expanded_argv]
    cmp qword [expanded_argv], 0
    jne .paes_nick_expanded
    lea rdi, [argv_ptrs]
.paes_nick_expanded:
    call expand_nicks
    test rax, rax
    jz .paes_no_nick
    ; Nick was expanded, re-parse argv from updated line_buf
    mov qword [redir_out], 0
    mov qword [redir_in], 0
    mov qword [redir_herestring], 0
    mov qword [redir_append], 0
    lea rsi, [line_buf]
    call parse_argv
    cmp qword [argc], 0
    je .paes_done
    call glob_expand_argv
    ; Don't expand nicks again (prevents recursion)
.paes_no_nick:

    ; Check builtins (use expanded_argv if glob expanded)
    mov rdi, [expanded_argv]
    test rdi, rdi
    jnz .paes_use_expanded
    mov rdi, [argv_ptrs]
.paes_use_expanded:
    call check_builtin
    test rax, rax
    jnz .paes_done          ; was a builtin

    ; Check if command is a bookmark name (auto-cd)
    lea r13, [expanded_argv]
    cmp qword [expanded_argv], 0
    jne .paes_chk_bm
    lea r13, [argv_ptrs]
.paes_chk_bm:
    mov rdi, [r13]
    test rdi, rdi
    jz .paes_done
    xor rcx, rcx
.paes_bm_loop:
    cmp rcx, [bm_count]
    jge .paes_not_bm
    push rcx
    push rdi
    mov rsi, [bm_names + rcx*8]
    call strcmp
    pop rdi
    pop rcx
    test rax, rax
    jz .paes_bm_cd
    inc rcx
    jmp .paes_bm_loop
.paes_bm_cd:
    ; cd to bookmark path
    mov rdi, [bm_paths + rcx*8]
    mov rax, SYS_CHDIR
    syscall
    test rax, rax
    js .paes_not_bm
    call update_cwd
    call add_dir_history
    mov qword [last_status], 0
    jmp .paes_done
.paes_not_bm:

    ; Check if command is a directory (auto-cd)
    mov rdi, [r13]
    sub rsp, 144            ; stat buffer
    mov rax, SYS_STAT
    mov rsi, rsp
    syscall
    test rax, rax
    js .paes_not_dir
    ; Check if it's a directory (mode & S_IFMT == S_IFDIR)
    mov eax, [rsp + 24]     ; st_mode
    and eax, 0xF000
    cmp eax, 0x4000         ; S_IFDIR
    jne .paes_not_dir
    add rsp, 144
    mov rdi, [r13]
    mov rax, SYS_CHDIR
    syscall
    test rax, rax
    js .paes_cd_fail
    call update_cwd
    call add_dir_history
    mov qword [last_status], 0
    jmp .paes_done
.paes_cd_fail:
    mov qword [last_status], 1
    jmp .paes_done
.paes_not_dir:
    add rsp, 144

    ; External command: fork and exec
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .child_exec
    js .fork_error

    ; Parent: set cooked mode so child gets normal terminal, then block wait
    mov [child_pid], rax
    mov r13, rax             ; save child pid
    ; Foreground job control: put child in its own process group and
    ; hand the controlling terminal to that pgrp. Both setpgid calls
    ; race-free (parent + child both call it; whichever wins, the
    ; result is the same). Without this, the controlling tty's tpgid
    ; stays as bare's pgrp, which breaks tools that read /proc/PID/stat
    ; to find the foreground process (e.g. tile's exec-here action).
    mov rax, SYS_SETPGID
    mov rdi, r13             ; child pid
    mov rsi, r13             ; pgid = child pid
    syscall                  ; ignore errors (race with child's own setpgid is fine)
    mov rdi, r13
    call tty_set_fg_pgrp     ; tcsetpgrp(0, child_pid)
    call enable_cooked_mode  ; ICANON + ECHO + ISIG for child
    sub rsp, 16
    ; Blocking wait with WUNTRACED (detect Ctrl-Z via ISIG)
.paes_wait_retry:
    mov rdi, r13
    lea rsi, [rsp]
    mov edx, WUNTRACED
    xor r10d, r10d
    mov rax, SYS_WAIT4
    syscall
    cmp rax, -4              ; EINTR (e.g. SIGWINCH while child owns terminal)
    je .paes_wait_retry

    ; Check if child was stopped (WIFSTOPPED: status & 0xFF == 0x7F)
    mov eax, [rsp]
    mov ecx, eax
    and ecx, 0xFF
    cmp ecx, 0x7F
    je .paes_stopped
    ; Normal exit: extract status
    shr eax, 8
    and eax, 0xFF
    mov [last_status], rax
    add rsp, 16
    ; Take the terminal back before restoring raw mode.
    mov rdi, [my_pid]
    call tty_set_fg_pgrp
    call post_child_restore
    call enable_raw_mode
    jmp .paes_done

.paes_stopped:
    ; Child was stopped by Ctrl-Z, add to job table
    add rsp, 16
    mov rdi, [my_pid]
    call tty_set_fg_pgrp
    call post_child_restore
    call enable_raw_mode
    mov rdi, r13             ; pid
    lea rsi, [line_buf]      ; command string
    call add_job
    ; Print job notification
    call write_nl
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.stopped_msg]
    mov rdx, .stopped_msg_len
    syscall
    mov qword [last_status], 148  ; 128 + SIGTSTP(20)
    jmp .paes_done

.stopped_msg: db 10, "[stopped]", 10
.stopped_msg_len equ $ - .stopped_msg

.child_exec:
    ; Race-free pair with parent's setpgid: whichever side wins, the
    ; child ends up in its own pgrp == its own pid.
    mov rax, SYS_SETPGID
    xor edi, edi             ; pid 0 = self
    xor esi, esi             ; pgid 0 = use own pid
    syscall
    ; Restore default signals in child (SIG_DFL for SIGTSTP etc.)
    call restore_child_signals
    call parse_and_exec_child_argv
    ; If we get here, exec failed
    mov rax, SYS_EXIT
    mov edi, 127
    syscall

.fork_error:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_fork]
    mov rdx, err_fork_len
    syscall
    mov qword [last_status], 1

.paes_done:
    pop r13
    pop r12
    pop rbx
    ret

; Parse and exec for pipe children (needs to parse argv first)
parse_and_exec_child:
    push rbx
    push r12
    mov qword [redir_out], 0
    mov qword [redir_in], 0
    mov qword [redir_herestring], 0
    mov qword [redir_append], 0
    mov r12, rdi                     ; remember original segment text
    mov rsi, rdi
    call parse_argv
    cmp qword [argc], 0
    je .paec_done
    call glob_expand_argv
    ; Nick expansion: pipe segments deserve the same alias treatment
    ; as a bare command. Without this, `apts chrome | less` failed
    ; with "command not found: apts" even though `apts` exists in
    ; ~/.barerc. Mirror parse_and_exec_simple: feed argv to
    ; expand_nicks, and on hit re-parse the rewritten segment.
    lea rdi, [expanded_argv]
    cmp qword [expanded_argv], 0
    jne .paec_nick_use_expanded
    lea rdi, [argv_ptrs]
.paec_nick_use_expanded:
    call expand_nicks
    test rax, rax
    jz .paec_no_nick
    mov qword [redir_out], 0
    mov qword [redir_in], 0
    mov qword [redir_herestring], 0
    mov qword [redir_append], 0
    mov rsi, r12                     ; expand_nicks rewrote our segment in place
    call parse_argv
    cmp qword [argc], 0
    je .paec_done
    call glob_expand_argv
.paec_no_nick:
    call parse_and_exec_child_argv
.paec_done:
    pop r12
    pop rbx
    ret

; Execute argv (already parsed). Called in child process.
parse_and_exec_child_argv:
    ; Handle redirections
    cmp qword [redir_out], 0
    je .no_redir_out
    ; Open output file
    mov rax, SYS_OPEN
    mov rdi, [redir_out]
    mov rsi, O_WRONLY | O_CREAT
    cmp qword [redir_append], 0
    je .trunc_out
    or rsi, O_APPEND
    jmp .open_out
.trunc_out:
    or rsi, O_TRUNC
.open_out:
    mov rdx, 0o644
    syscall
    test rax, rax
    js .no_redir_out
    mov rdi, rax
    mov rax, SYS_DUP2
    mov esi, 1              ; stdout
    syscall
    mov rax, SYS_CLOSE
    syscall
.no_redir_out:
    cmp qword [redir_in], 0
    je .no_redir_in
    mov rax, SYS_OPEN
    mov rdi, [redir_in]
    xor esi, esi            ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .no_redir_in
    mov rdi, rax
    mov rax, SYS_DUP2
    xor esi, esi            ; stdin
    syscall
    mov rax, SYS_CLOSE
    syscall
.no_redir_in:
    ; Handle here-string (<<<)
    cmp qword [redir_herestring], 0
    je .no_herestring
    ; Create pipe, write string to it, dup2 read end to stdin
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    jnz .no_herestring
    ; Write string + newline to write end
    mov rdi, [redir_herestring]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov edi, [pipe_fds + 4]  ; write end
    mov rsi, [redir_herestring]
    syscall
    ; Write newline
    mov rax, SYS_WRITE
    mov edi, [pipe_fds + 4]
    lea rsi, [newline]
    mov rdx, 1
    syscall
    ; Close write end
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    ; Dup read end to stdin
    mov rax, SYS_DUP2
    mov edi, [pipe_fds]
    xor esi, esi             ; stdin = 0
    syscall
    ; Close original read end
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
.no_herestring:

    ; Use expanded_argv if available, otherwise argv_ptrs
    lea rbx, [expanded_argv]
    cmp qword [expanded_argv], 0
    jne .use_expanded_exec
    lea rbx, [argv_ptrs]
.use_expanded_exec:

    ; Try to find the command
    mov rdi, [rbx]

    ; If it contains '/', use as-is
    mov rsi, rdi
.check_slash:
    mov al, [rsi]
    test al, al
    jz .search_path
    cmp al, '/'
    je .do_exec
    inc rsi
    jmp .check_slash

.search_path:
    ; Search PATH for the command
    call find_in_path
    test rax, rax
    jz .exec_notfound
    lea rdi, [exec_path]

.do_exec:
    ; Apply any "VAR=val ..." prefix collected by extract_env_prefix
    ; in the child only — parent's env_array stays untouched. Save
    ; rdi (path) across the call.
    push rdi
    call apply_env_prefix
    pop rdi
    ; execve(path, argv, envp)
    mov rax, SYS_EXECVE
    ; rdi = path (already set)
    mov rsi, rbx             ; argv array (expanded or original)
    lea rdx, [env_array]     ; use custom env
    syscall
    ; If we get here, exec failed

    ; Auto-edit: typed path (contains '/') to a regular non-executable
    ; file → open in $EDITOR (fallback /usr/bin/vim) instead of erroring.
    mov r12, [rbx]                ; argv[0]
    mov rsi, r12
.ae_scan_slash:
    mov al, [rsi]
    test al, al
    jz .exec_notfound             ; no '/', not a path
    cmp al, '/'
    je .ae_stat
    inc rsi
    jmp .ae_scan_slash
.ae_stat:
    sub rsp, 144
    mov rax, SYS_STAT
    mov rdi, r12
    mov rsi, rsp
    syscall
    test rax, rax
    js .ae_drop_stat
    mov eax, [rsp + 24]           ; st_mode
    add rsp, 144
    and eax, 0o170000             ; S_IFMT
    cmp eax, 0o100000             ; S_IFREG
    jne .exec_notfound
    ; Find $EDITOR
    xor r13, r13
    xor rcx, rcx
.ae_find_editor:
    cmp rcx, [env_count]
    jge .ae_editor_fallback
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .ae_fe_next
    cmp dword [rsi], 'EDIT'
    jne .ae_fe_next
    cmp word [rsi+4], 'OR'
    jne .ae_fe_next
    cmp byte [rsi+6], '='
    jne .ae_fe_next
    lea r13, [rsi+7]
    cmp byte [r13], 0
    jne .ae_have_editor
    xor r13, r13
    jmp .ae_editor_fallback
.ae_fe_next:
    inc rcx
    jmp .ae_find_editor
.ae_editor_fallback:
    lea r13, [.ae_vim_path]
.ae_have_editor:
    ; If editor path has no '/', resolve via PATH; on miss fall back to vim
    mov rsi, r13
.ae_ed_slash_scan:
    mov al, [rsi]
    test al, al
    jz .ae_ed_search
    cmp al, '/'
    je .ae_exec_editor
    inc rsi
    jmp .ae_ed_slash_scan
.ae_ed_search:
    mov rdi, r13
    call find_in_path
    test rax, rax
    jz .ae_ed_use_vim
    lea r13, [exec_path]
    jmp .ae_exec_editor
.ae_ed_use_vim:
    lea r13, [.ae_vim_path]
.ae_exec_editor:
    sub rsp, 32
    mov [rsp], r13
    mov [rsp + 8], r12
    mov qword [rsp + 16], 0
    mov rdi, r13
    mov rsi, rsp
    lea rdx, [env_array]
    mov rax, SYS_EXECVE
    syscall
    add rsp, 32
    jmp .exec_notfound
.ae_drop_stat:
    add rsp, 144
    jmp .exec_notfound
.ae_vim_path: db "/usr/bin/vim", 0

.exec_notfound:
    ; Print error
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_exec]
    mov rdx, err_exec_len
    syscall
    ; Print command name
    mov rsi, [rbx]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, [rbx]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [newline]
    mov rdx, 1
    syscall
    ; Suggest similar commands (TTY only)
    cmp qword [is_tty], 0
    je .exec_nf_skip
    mov rdi, [rbx]
    call suggest_correction
.exec_nf_skip:
    ret

; ══════════════════════════════════════════════════════════════════════
; Parse a command string into argv_ptrs array
; rsi = string to parse
; Handles: spaces, single/double quotes, >, >>, <
; ══════════════════════════════════════════════════════════════════════
parse_argv:
    push rbx
    xor ecx, ecx            ; argc
    mov rdi, rsi

.pa_skip:
    cmp byte [rdi], ' '
    je .pa_skip_inc
    cmp byte [rdi], 9       ; tab
    je .pa_skip_inc
    jmp .pa_check

.pa_skip_inc:
    inc rdi
    jmp .pa_skip

.pa_check:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], 10
    je .pa_done

    ; Check for redirections
    cmp byte [rdi], '>'
    je .pa_redir_out
    cmp byte [rdi], '<'
    je .pa_redir_in

    ; Start of argument
    cmp byte [rdi], '"'
    je .pa_dquote
    cmp byte [rdi], 0x27    ; single quote
    je .pa_squote

    ; Unquoted arg
    mov [argv_ptrs + rcx*8], rdi
    inc ecx
    ; Use rbx as write pointer (for in-place backslash removal)
    mov rbx, rdi
.pa_unquoted:
    cmp byte [rdi], 0
    je .pa_done_compact
    cmp byte [rdi], 10
    je .pa_term_compact
    ; Backslash escape: '\' followed by space means literal space
    cmp byte [rdi], '\'
    jne .pa_not_escape
    cmp byte [rdi + 1], ' '
    jne .pa_not_escape
    ; Skip the backslash, copy the space
    inc rdi
    mov al, [rdi]
    mov [rbx], al
    inc rdi
    inc rbx
    jmp .pa_unquoted
.pa_not_escape:
    cmp byte [rdi], ' '
    je .pa_term_compact
    cmp byte [rdi], 9
    je .pa_term_compact
    cmp byte [rdi], '>'
    je .pa_term_compact_nordi
    cmp byte [rdi], '<'
    je .pa_term_compact_nordi
    ; Copy char (may be same position if no escapes removed)
    mov al, [rdi]
    mov [rbx], al
    inc rdi
    inc rbx
    jmp .pa_unquoted

.pa_term_compact:
    mov byte [rbx], 0
    inc rdi
    jmp .pa_skip

.pa_done_compact:
    mov byte [rbx], 0
    jmp .pa_done

.pa_term_compact_nordi:
    mov byte [rbx], 0
    jmp .pa_check              ; re-check for redirect without advancing

.pa_term:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip

.pa_term_nordi:
    mov byte [rdi], 0
    jmp .pa_check

.pa_dquote:
    inc rdi                  ; skip opening quote
    mov [argv_ptrs + rcx*8], rdi
    inc ecx
.pa_dq_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], '"'
    je .pa_dq_end
    inc rdi
    jmp .pa_dq_scan
.pa_dq_end:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip

.pa_squote:
    inc rdi
    mov [argv_ptrs + rcx*8], rdi
    inc ecx
.pa_sq_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], 0x27
    je .pa_sq_end
    inc rdi
    jmp .pa_sq_scan
.pa_sq_end:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip

.pa_redir_out:
    inc rdi
    mov qword [redir_append], 0
    cmp byte [rdi], '>'
    jne .pa_redir_out_file
    inc rdi
    mov qword [redir_append], 1
.pa_redir_out_file:
    ; Skip spaces
    cmp byte [rdi], ' '
    jne .pa_ro_set
    inc rdi
    jmp .pa_redir_out_file
.pa_ro_set:
    mov [redir_out], rdi
    ; Skip to end of filename
.pa_ro_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], ' '
    je .pa_ro_term
    cmp byte [rdi], 10
    je .pa_ro_term
    inc rdi
    jmp .pa_ro_scan
.pa_ro_term:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip

.pa_redir_in:
    inc rdi
    ; Check for <<< (here-string)
    cmp byte [rdi], '<'
    jne .pa_ri_skip
    inc rdi
    cmp byte [rdi], '<'
    jne .pa_ri_skip           ; just << (here-doc, treat as regular)
    inc rdi                   ; skip third <
    ; Skip spaces after <<<
.pa_hs_skip:
    cmp byte [rdi], ' '
    jne .pa_hs_set
    inc rdi
    jmp .pa_hs_skip
.pa_hs_set:
    mov [redir_herestring], rdi
    ; Handle quoted or unquoted string
    cmp byte [rdi], '"'
    je .pa_hs_dquote
    cmp byte [rdi], 0x27
    je .pa_hs_squote
    ; Unquoted: read until space/null/newline
.pa_hs_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], ' '
    je .pa_hs_term
    cmp byte [rdi], 10
    je .pa_hs_term
    inc rdi
    jmp .pa_hs_scan
.pa_hs_term:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip
.pa_hs_dquote:
    inc rdi
    mov [redir_herestring], rdi
.pa_hs_dq_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], '"'
    je .pa_hs_dq_end
    inc rdi
    jmp .pa_hs_dq_scan
.pa_hs_dq_end:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip
.pa_hs_squote:
    inc rdi
    mov [redir_herestring], rdi
.pa_hs_sq_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], 0x27
    je .pa_hs_sq_end
    inc rdi
    jmp .pa_hs_sq_scan
.pa_hs_sq_end:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip

.pa_ri_skip:
    cmp byte [rdi], ' '
    jne .pa_ri_set
    inc rdi
    jmp .pa_ri_skip
.pa_ri_set:
    mov [redir_in], rdi
.pa_ri_scan:
    cmp byte [rdi], 0
    je .pa_done
    cmp byte [rdi], ' '
    je .pa_ri_term
    cmp byte [rdi], 10
    je .pa_ri_term
    inc rdi
    jmp .pa_ri_scan
.pa_ri_term:
    mov byte [rdi], 0
    inc rdi
    jmp .pa_skip

.pa_done:
    ; Null-terminate argv
    mov qword [argv_ptrs + rcx*8], 0
    mov [argc], rcx
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Check and execute builtin commands
; rdi = command name (from expanded_argv or argv_ptrs)
; Returns: rax = 1 if builtin was handled, 0 if not
; ══════════════════════════════════════════════════════════════════════
check_builtin:
    push rbx
    push r12

    ; Use expanded_argv if available for builtins
    lea r12, [expanded_argv]
    cmp qword [expanded_argv], 0
    jne .bi_use_expanded
    lea r12, [argv_ptrs]
.bi_use_expanded:

    mov rdi, [r12]

    ; "cd"
    lea rsi, [str_cd]
    call strcmp
    test rax, rax
    jz .bi_cd

    ; "exit"
    mov rdi, [r12]
    lea rsi, [str_exit]
    call strcmp
    test rax, rax
    jz .bi_exit

    ; "pwd"
    mov rdi, [r12]
    lea rsi, [str_pwd]
    call strcmp
    test rax, rax
    jz .bi_pwd

    ; "export"
    mov rdi, [r12]
    lea rsi, [str_export]
    call strcmp
    test rax, rax
    jz .bi_export

    ; "unset"
    mov rdi, [r12]
    lea rsi, [str_unset]
    call strcmp
    test rax, rax
    jz .bi_unset

    ; "history"
    mov rdi, [r12]
    lea rsi, [str_history]
    call strcmp
    test rax, rax
    jz .bi_history

    ; "pushd"
    mov rdi, [r12]
    lea rsi, [str_pushd]
    call strcmp
    test rax, rax
    jz .bi_pushd

    ; "popd"
    mov rdi, [r12]
    lea rsi, [str_popd]
    call strcmp
    test rax, rax
    jz .bi_popd

    ; Check for colon commands (starts with ':')
    mov rdi, [r12]
    cmp byte [rdi], ':'
    je .bi_colon

    ; Not a builtin
    xor eax, eax
    pop r12
    pop rbx
    ret

.bi_cd:
    mov rdi, [r12 + 8]       ; arg1
    test rdi, rdi
    jnz .cd_check_dash
    ; No arg: go to HOME
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .cd_done
    mov rdi, rax
    jmp .cd_dir
.cd_check_dash:
    ; Check for "cd -" (go to previous directory)
    cmp byte [rdi], '-'
    jne .cd_check_num
    jmp .cd_is_dash
.cd_check_num:
    ; Check for "cd N" (jump to Nth entry from :dirs)
    movzx eax, byte [rdi]
    sub al, '0'
    cmp al, 9
    ja .cd_dir
    ; It's a number, parse and look up in dir_history
    push rdi
    call parse_int
    pop rdi
    cmp rax, [dir_hist_count]
    jge .cd_dir              ; out of range, treat as path
    mov rdi, [dir_history + rax*8]
    test rdi, rdi
    jz .cd_done
    jmp .cd_dir
.cd_is_dash:
    cmp byte [rdi + 1], 0
    jne .cd_dir
    ; cd -: swap cwd and prev_dir
    cmp byte [prev_dir], 0
    je .cd_done              ; no previous dir
    ; Copy prev_dir to tmp_buf (target)
    lea rsi, [prev_dir]
    lea rdi, [path_buf]
    xor rcx, rcx
.cd_dash_cp:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .cd_dash_ready
    inc rcx
    jmp .cd_dash_cp
.cd_dash_ready:
    ; Save current cwd to prev_dir
    lea rsi, [cwd_buf]
    lea rdi, [prev_dir]
    call strcpy_rsi_rdi
    lea rdi, [path_buf]     ; target dir
    jmp .cd_do_chdir

.cd_dir:
    ; Save current dir before changing
    push rdi
    lea rdi, [prev_dir]
    lea rsi, [cwd_buf]
    call strcpy_rsi_rdi
    pop rdi
.cd_do_chdir:
    mov rax, SYS_CHDIR
    syscall
    test rax, rax
    jns .cd_ok
    ; Error
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_cd]
    mov rdx, err_cd_len
    syscall
    mov qword [last_status], 1
    jmp .cd_done
.cd_ok:
    call update_cwd
    call add_dir_history
    mov qword [last_status], 0
.cd_done:
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_exit:
    call save_config
    call save_history
    call restore_termios
    mov rdi, [last_status]
    mov rax, SYS_EXIT
    syscall

.bi_pwd:
    call update_cwd
    lea rdi, [cwd_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [cwd_buf]
    syscall
    call write_nl
    mov qword [last_status], 0
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_export:
    ; export VAR=VALUE
    mov rdi, [r12 + 8]       ; arg1
    test rdi, rdi
    jz .export_no_arg
    ; Find '=' in the argument
    mov rsi, rdi
.export_find_eq:
    cmp byte [rsi], 0
    je .export_invalid
    cmp byte [rsi], '='
    je .export_do
    inc rsi
    jmp .export_find_eq
.export_do:
    ; rdi = "VAR=VALUE", this is the full string to add
    call env_set_entry
    mov qword [last_status], 0
    jmp .export_done
.export_no_arg:
    ; Just "export" with no args: print all env vars
    xor rcx, rcx
.export_print_loop:
    cmp rcx, [env_count]
    jge .export_done
    push rcx
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .export_print_next
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [env_array + rcx*8]
    syscall
    call write_nl
.export_print_next:
    pop rcx
    inc rcx
    jmp .export_print_loop
.export_invalid:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_export]
    mov rdx, err_export_len
    syscall
    mov qword [last_status], 1
.export_done:
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_unset:
    ; unset VAR
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .unset_done
    call env_remove_entry
    mov qword [last_status], 0
.unset_done:
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_history:
    ; Print all history entries with line numbers
    xor rcx, rcx
.hist_print_loop:
    cmp rcx, [hist_count]
    jge .hist_print_done
    push rcx
    ; Print line number
    mov rax, rcx
    inc rax                 ; 1-based
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    ; Print space
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [space_char]
    mov rdx, 1
    syscall
    ; Print history line
    mov rcx, [rsp]
    mov rsi, [hist_lines + rcx*8]
    test rsi, rsi
    jz .hist_skip_entry
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [hist_lines + rcx*8]
    syscall
.hist_skip_entry:
    ; Print newline
    call write_nl
    pop rcx
    inc rcx
    jmp .hist_print_loop
.hist_print_done:
    mov qword [last_status], 0
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_pushd:
    mov rdi, r12
    call handle_pushd
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_popd:
    mov rdi, r12
    call handle_popd
    mov rax, 1
    pop r12
    pop rbx
    ret

.bi_colon:
    ; Table-driven colon command dispatch
    lea rbx, [colon_dispatch_table]
.cc_loop:
    mov rsi, [rbx]           ; string pointer
    test rsi, rsi
    jz .cc_not_found          ; sentinel reached
    mov rdi, [r12]            ; command name
    call strcmp
    test rax, rax
    jnz .cc_next
    ; Match found: call handler with rdi = argv array
    mov rdi, r12
    call [rbx + 8]
    jmp .cc_done
.cc_next:
    add rbx, 16              ; next table entry
    jmp .cc_loop
.cc_not_found:
    ; Try plugin: check ~/.bare/plugins/<cmd_without_colon>
    mov rdi, [r12]           ; ":something"
    inc rdi                  ; skip ':'
    call try_run_plugin
    test rax, rax
    jnz .cc_done             ; plugin handled it

    ; Unknown colon command
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.cc_unknown]
    mov rdx, .cc_unknown_len
    syscall
    mov rdi, [r12]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, [r12]
    syscall
    call write_nl
    mov qword [last_status], 1

.cc_done:
    mov rax, 1
    pop r12
    pop rbx
    ret

.cc_unknown: db "bare: unknown command: "
.cc_unknown_len equ $ - .cc_unknown

; ══════════════════════════════════════════════════════════════════════
; Environment management (custom env_array)
; ══════════════════════════════════════════════════════════════════════

; Initialize env_array by copying pointers from envp
init_env_array:
    push rbx
    push r12
    cmp qword [env_inited], 1
    je .iea_done

    mov rbx, [envp]
    xor r12, r12             ; count
.iea_loop:
    mov rax, [rbx]
    test rax, rax
    jz .iea_end
    cmp r12, MAX_ENV_ENTRIES - 2
    jge .iea_end
    mov [env_array + r12*8], rax
    inc r12
    add rbx, 8
    jmp .iea_loop
.iea_end:
    mov qword [env_array + r12*8], 0  ; null terminate
    mov [env_count], r12
    mov qword [env_storage_pos], 0
    mov qword [env_inited], 1
.iea_done:
    pop r12
    pop rbx
    ret

; Add or replace an environment entry
; rdi = "VAR=VALUE" string (null-terminated)
env_set_entry:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi             ; save entry string

    ; Find '=' to determine var name length
    mov rsi, rdi
    xor rcx, rcx
.ese_find_eq:
    cmp byte [rsi + rcx], '='
    je .ese_found_eq
    cmp byte [rsi + rcx], 0
    je .ese_done             ; no = found
    inc rcx
    jmp .ese_find_eq
.ese_found_eq:
    mov r13, rcx             ; var name length (before =)

    ; Copy entry to env_storage
    mov rdi, r12
    call strlen
    mov r14, rax             ; entry length
    inc r14                  ; include null
    ; Check space
    mov rax, [env_storage_pos]
    add rax, r14
    cmp rax, MAX_ENV_STORAGE
    jge .ese_done            ; no space

    lea rdi, [env_storage]
    add rdi, [env_storage_pos]
    mov rsi, r12
    mov rcx, r14
.ese_copy:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .ese_copy

    lea r14, [env_storage]
    add r14, [env_storage_pos]  ; r14 = pointer to new copy
    mov rax, [env_storage_pos]
    add rax, r14
    sub rax, [env_storage_pos]
    ; Update storage pos
    mov rdi, r12
    call strlen
    inc rax
    add [env_storage_pos], rax

    ; Search for existing entry with same var name
    xor rcx, rcx
.ese_search:
    cmp rcx, [env_count]
    jge .ese_add_new
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .ese_search_next
    ; Compare first r13 bytes + check for '='
    push rcx
    mov rdi, r12
    mov rbx, rsi
    mov rcx, r13
.ese_cmp:
    test rcx, rcx
    jz .ese_cmp_eq
    movzx eax, byte [rdi]
    movzx edx, byte [rbx]
    cmp al, dl
    jne .ese_no_match
    inc rdi
    inc rbx
    dec rcx
    jmp .ese_cmp
.ese_cmp_eq:
    cmp byte [rbx], '='
    jne .ese_no_match
    ; Found existing entry, replace it
    pop rcx
    mov [env_array + rcx*8], r14
    jmp .ese_done
.ese_no_match:
    pop rcx
.ese_search_next:
    inc rcx
    jmp .ese_search

.ese_add_new:
    ; Add new entry
    mov rcx, [env_count]
    cmp rcx, MAX_ENV_ENTRIES - 2
    jge .ese_done
    mov [env_array + rcx*8], r14
    inc rcx
    mov qword [env_array + rcx*8], 0  ; null terminate
    mov [env_count], rcx

.ese_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Remove an environment entry by variable name
; rdi = variable name (null-terminated)
env_remove_entry:
    push rbx
    push r12
    push r13

    mov r12, rdi
    call strlen
    mov r13, rax             ; var name length

    xor rcx, rcx
.ere_search:
    cmp rcx, [env_count]
    jge .ere_done
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .ere_next
    ; Compare var name
    push rcx
    mov rdi, r12
    mov rbx, rsi
    mov rcx, r13
.ere_cmp:
    test rcx, rcx
    jz .ere_check_eq
    movzx eax, byte [rdi]
    movzx edx, byte [rbx]
    cmp al, dl
    jne .ere_no_match
    inc rdi
    inc rbx
    dec rcx
    jmp .ere_cmp
.ere_check_eq:
    cmp byte [rbx], '='
    jne .ere_no_match
    ; Found it, remove by shifting remaining entries down
    pop rcx
    mov rbx, rcx
.ere_shift:
    mov rax, rcx
    inc rax
    cmp rax, [env_count]
    jge .ere_shifted
    mov rax, [env_array + rax*8]
    mov [env_array + rcx*8], rax
    inc rcx
    jmp .ere_shift
.ere_shifted:
    dec qword [env_count]
    mov rcx, [env_count]
    mov qword [env_array + rcx*8], 0
    jmp .ere_done
.ere_no_match:
    pop rcx
.ere_next:
    inc rcx
    jmp .ere_search
.ere_done:
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Glob expansion
; After argv is parsed, check each arg for * or ? and expand
; ══════════════════════════════════════════════════════════════════════
glob_expand_argv:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Initialize expanded argv
    mov qword [expanded_argc], 0
    mov qword [expanded_argv], 0
    mov qword [glob_buf_pos], 0

    xor r12, r12             ; source argv index
    xor r13, r13             ; dest expanded index
    mov r14, 0               ; flag: did any expansion happen?

.gea_loop:
    cmp r12, [argc]
    jge .gea_finish
    mov rsi, [argv_ptrs + r12*8]
    test rsi, rsi
    jz .gea_finish

    ; Check if this arg contains * or ?
    push rsi
    call has_glob_chars
    pop rsi
    test rax, rax
    jz .gea_no_glob

    ; This arg needs glob expansion
    push r13
    mov rdi, rsi
    call glob_expand_single
    pop r13
    ; glob_results has matches, glob_count has count
    cmp qword [glob_count], 0
    je .gea_no_match

    ; Add all matches to expanded_argv
    mov r14, 1               ; expansion happened
    xor rcx, rcx
.gea_add_matches:
    cmp rcx, [glob_count]
    jge .gea_next
    cmp r13, 510
    jge .gea_next
    mov rax, [glob_results + rcx*8]
    mov [expanded_argv + r13*8], rax
    inc r13
    inc rcx
    jmp .gea_add_matches

.gea_no_match:
    ; No matches: keep original arg
    cmp r13, 510
    jge .gea_next
    mov rax, [argv_ptrs + r12*8]
    mov [expanded_argv + r13*8], rax
    inc r13
    jmp .gea_next

.gea_no_glob:
    ; No glob chars: copy arg as-is
    cmp r13, 510
    jge .gea_next
    mov rax, [argv_ptrs + r12*8]
    mov [expanded_argv + r13*8], rax
    inc r13

.gea_next:
    inc r12
    jmp .gea_loop

.gea_finish:
    ; Null-terminate expanded_argv
    mov qword [expanded_argv + r13*8], 0
    mov [expanded_argc], r13

    ; If no expansion happened, signal that by leaving expanded_argv[0] as-is
    ; (we always populate it so it's always usable)

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Check if a string contains glob characters (* or ?)
; rsi = string
; Returns: rax = 1 if has glob chars, 0 if not
; ══════════════════════════════════════════════════════════════════════
; Recursive glob using BFS queue: handle ** patterns
; rdi = full pattern (e.g., "**/*.txt" or "src/**/*.rs")
; Results added to glob_results/glob_count
; ══════════════════════════════════════════════════════════════════════
glob_recursive:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi             ; save full pattern

    ; Find ** position, extract prefix dir and suffix pattern
    mov rsi, r12
.gr_find_dstar:
    cmp byte [rsi], 0
    je .gr_done
    cmp word [rsi], 0x2A2A
    je .gr_found_dstar
    inc rsi
    jmp .gr_find_dstar
.gr_found_dstar:
    mov r13, rsi             ; r13 points to **
    ; Suffix: skip ** and optional /
    lea r14, [r13 + 2]
    cmp byte [r14], '/'
    jne .gr_have_suffix
    inc r14
.gr_have_suffix:
    ; r14 = suffix pattern (e.g., "*.txt"), store in glob_path_buf+3072
    lea rdi, [glob_path_buf + 3072]
    mov rsi, r14
    call strcpy_rsi_rdi

    ; Build starting directory in glob_queue
    mov qword [glob_queue_wpos], 0
    mov qword [glob_queue_rpos], 0
    cmp r13, r12
    je .gr_prefix_dot
    ; Copy prefix (before **)
    lea rdi, [glob_queue]
    mov rsi, r12
    mov rcx, r13
    sub rcx, r12
    cmp byte [r12 + rcx - 1], '/'
    jne .gr_cp_pre
    dec rcx
.gr_cp_pre:
    test rcx, rcx
    jz .gr_prefix_dot
    xor rax, rax
.gr_cp_pre_loop:
    cmp rax, rcx
    jge .gr_cp_pre_done
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .gr_cp_pre_loop
.gr_cp_pre_done:
    mov byte [rdi + rax], 0
    inc rax
    mov [glob_queue_wpos], rax
    jmp .gr_bfs_loop

.gr_prefix_dot:
    mov byte [glob_queue], '.'
    mov byte [glob_queue + 1], 0
    mov qword [glob_queue_wpos], 2

.gr_bfs_loop:
    ; Process directories from queue until empty
    mov rax, [glob_queue_rpos]
    cmp rax, [glob_queue_wpos]
    jge .gr_done

    ; Get current directory path from queue
    lea r15, [glob_queue + rax]  ; r15 = current dir path
    ; Advance rpos past this entry
    mov rdi, r15
    call strlen
    inc rax                  ; skip null
    add [glob_queue_rpos], rax

    ; Scan this directory
    mov rax, SYS_OPEN
    mov rdi, r15
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .gr_bfs_loop          ; can't open, skip
    mov rbx, rax             ; fd

.gr_scan:
    mov rax, SYS_GETDENTS64
    mov rdi, rbx
    lea rsi, [glob_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .gr_close

    xor rcx, rcx
.gr_entry:
    cmp rcx, rax
    jge .gr_scan

    push rax                 ; save bytes_read
    push rcx                 ; save offset

    lea rsi, [glob_dir_buf + rcx]
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    push rdx                 ; save reclen
    lea rdi, [rsi + DIRENT64_D_NAME]
    movzx r13d, byte [rsi + DIRENT64_D_TYPE]

    ; Skip . and ..
    cmp byte [rdi], '.'
    jne .gr_not_dot
    cmp byte [rdi + 1], 0
    je .gr_skip_entry
    cmp byte [rdi + 1], '.'
    jne .gr_check_hidden
    cmp byte [rdi + 2], 0
    je .gr_skip_entry
.gr_check_hidden:
    ; Skip hidden unless pattern starts with .
    lea rsi, [glob_path_buf + 3072]
    cmp byte [rsi], '.'
    je .gr_not_dot
    jmp .gr_skip_entry
.gr_not_dot:
    push rdi                 ; save d_name

    ; Check if entry matches suffix pattern
    lea rsi, [glob_path_buf + 3072]  ; suffix pattern
    call glob_match
    test rax, rax
    jz .gr_no_file_match

    ; Match! Build full path: dir/name -> glob_buf
    cmp qword [glob_count], MAX_GLOB_RESULTS - 1
    jge .gr_no_file_match
    mov rdi, [rsp]           ; d_name
    ; Build path in glob_path_buf
    push rdi
    lea rdi, [glob_path_buf]
    mov rsi, r15             ; dir path
    call strcpy_rsi_rdi
    lea rdi, [glob_path_buf + rax]
    mov byte [rdi], '/'
    inc rdi
    pop rsi                  ; d_name
    call strcpy_rsi_rdi
    ; Copy to glob_buf
    lea rsi, [glob_path_buf]
    mov rdi, rsi
    call strlen
    mov rcx, rax
    inc rcx                  ; include null
    mov rdx, [glob_buf_pos]
    cmp rdx, MAX_GLOB_BUF - 256
    jge .gr_no_file_match
    lea rdi, [glob_buf + rdx]
    lea rsi, [glob_path_buf]
    push rcx
    xor rax, rax
.gr_cp_result:
    cmp rax, rcx
    jge .gr_cp_result_done
    movzx r8d, byte [rsi + rax]  ; use r8 (caller-saved), NOT rbx (holds dir fd!)
    mov [rdi + rax], r8b
    inc rax
    jmp .gr_cp_result
.gr_cp_result_done:
    pop rcx
    mov rax, [glob_count]
    lea rdi, [glob_buf + rdx]
    mov [glob_results + rax*8], rdi
    inc qword [glob_count]
    add rdx, rcx
    mov [glob_buf_pos], rdx

.gr_no_file_match:
    pop rdi                  ; d_name

    ; If directory, add to BFS queue
    cmp r13d, 4              ; DT_DIR
    jne .gr_skip_entry
    ; Build subdir path: dir/name
    lea rdi, [glob_path_buf]
    mov rsi, r15
    call strcpy_rsi_rdi
    lea rdi, [glob_path_buf + rax]
    mov byte [rdi], '/'
    inc rdi
    ; rdi = after slash, now copy entry name from d_name
    ; We need d_name again, reconstruct from stack
    mov rcx, [rsp + 8]      ; offset (second item on stack)
    lea rsi, [glob_dir_buf + rcx + DIRENT64_D_NAME]
    call strcpy_rsi_rdi
    ; Add to queue if space
    lea rdi, [glob_path_buf]
    call strlen
    inc rax                  ; include null
    mov rcx, [glob_queue_wpos]
    add rcx, rax
    cmp rcx, 32000
    jge .gr_skip_entry       ; queue full
    lea rdi, [glob_queue]
    add rdi, [glob_queue_wpos]
    lea rsi, [glob_path_buf]
    push rax
    xor rcx, rcx
.gr_cp_queue:
    cmp rcx, rax
    jge .gr_cp_queue_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rcx], dl
    inc rcx
    jmp .gr_cp_queue
.gr_cp_queue_done:
    pop rax
    add [glob_queue_wpos], rax

.gr_skip_entry:
    pop rdx                  ; reclen
    pop rcx                  ; offset
    pop rax                  ; bytes_read
    add rcx, rdx
    jmp .gr_entry

.gr_close:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    jmp .gr_bfs_loop

.gr_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

has_glob_chars:
    mov rdi, rsi
.hgc_loop:
    movzx eax, byte [rdi]
    test al, al
    jz .hgc_no
    cmp al, '*'
    je .hgc_yes
    cmp al, '?'
    je .hgc_yes
    cmp al, '['
    je .hgc_yes
    inc rdi
    jmp .hgc_loop
.hgc_yes:
    mov eax, 1
    ret
.hgc_no:
    xor eax, eax
    ret

; Expand a single glob pattern
; rdi = pattern string (may contain path like "dir/*.txt")
glob_expand_single:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi             ; save pattern
    mov qword [glob_count], 0

    ; Check for ** (recursive glob)
    mov rsi, rdi
.ges_check_dstar:
    cmp byte [rsi], 0
    je .ges_no_dstar
    cmp word [rsi], 0x2A2A   ; '**' as little-endian word
    je .ges_do_recursive
    inc rsi
    jmp .ges_check_dstar
.ges_do_recursive:
    mov rdi, r12
    call glob_recursive
    jmp .ges_done
.ges_no_dstar:

    ; Split into directory and pattern parts
    ; Find last '/' in pattern
    mov rsi, r12
    xor r13, r13             ; last slash position (0 = none)
    xor rcx, rcx
.ges_find_slash:
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .ges_slash_done
    cmp al, '/'
    jne .ges_slash_next
    lea r13, [rcx + 1]      ; position after slash
.ges_slash_next:
    inc rcx
    jmp .ges_find_slash
.ges_slash_done:

    test r13, r13
    jz .ges_current_dir

    ; Has directory part: copy dir to glob_path_buf
    lea rdi, [glob_path_buf]
    mov rsi, r12
    mov rcx, r13
    dec rcx                  ; don't include the slash in dir for opening
    test rcx, rcx
    jz .ges_root_dir
.ges_copy_dir:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .ges_copy_dir
    mov byte [rdi], 0
    lea r14, [glob_path_buf] ; dir to open
    ; Pattern starts after the last slash
    lea r15, [r12 + r13]     ; pattern part
    jmp .ges_open_dir

.ges_root_dir:
    mov byte [glob_path_buf], '/'
    mov byte [glob_path_buf + 1], 0
    lea r14, [glob_path_buf]
    lea r15, [r12 + r13]
    jmp .ges_open_dir

.ges_current_dir:
    ; Use "." as directory
    mov byte [glob_path_buf], '.'
    mov byte [glob_path_buf + 1], 0
    lea r14, [glob_path_buf]
    mov r15, r12             ; entire pattern is the filename pattern

.ges_open_dir:
    ; Open directory
    mov rax, SYS_OPEN
    mov rdi, r14
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .ges_done
    mov rbx, rax             ; fd

.ges_read_loop:
    ; Read directory entries
    mov rax, SYS_GETDENTS64
    mov rdi, rbx
    lea rsi, [glob_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .ges_close

    ; Process entries
    xor rcx, rcx             ; offset into buffer
.ges_entry_loop:
    cmp rcx, rax
    jge .ges_read_loop

    ; Get entry
    lea rsi, [glob_dir_buf + rcx]
    ; d_reclen at offset 16 (2 bytes)
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    ; d_name at offset 19
    lea rdi, [rsi + DIRENT64_D_NAME]

    ; Skip . and .. entries
    push rax
    push rcx
    push rdx

    ; Check if first char of pattern is not '.', and name starts with '.'
    ; If so, skip (hidden files only match if pattern starts with '.')
    cmp byte [r15], '.'
    je .ges_no_hide_check
    cmp byte [rdi], '.'
    je .ges_skip_entry

.ges_no_hide_check:
    ; Match pattern against this entry
    push rdi
    mov rsi, r15             ; pattern
    ; rdi already = entry name
    call glob_match
    pop rdi
    test rax, rax
    jz .ges_skip_entry

    ; Match found, add to results
    cmp qword [glob_count], MAX_GLOB_RESULTS - 1
    jge .ges_skip_entry

    ; Build full path if there's a directory prefix
    cmp r13, 0
    je .ges_just_name

    ; Copy "dir/" + name to glob_buf
    push rbx                 ; save fd
    push rdi                 ; save d_name pointer
    mov rcx, [glob_buf_pos]
    lea rbx, [glob_buf + rcx]
    mov rdi, rbx             ; dest = glob_buf write position
    ; Copy directory prefix
    mov rsi, r12
    mov rcx, r13
.ges_copy_prefix:
    test rcx, rcx
    jz .ges_prefix_done
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jmp .ges_copy_prefix
.ges_prefix_done:
    ; Copy entry name after prefix
    pop rsi                  ; restore d_name as source
    xor rcx, rcx
.ges_copy_prefixed_name:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .ges_prefixed_done
    inc rcx
    cmp rcx, 255
    jge .ges_prefixed_done
    jmp .ges_copy_prefixed_name
.ges_prefixed_done:
    mov byte [rdi + rcx], 0
    ; Calculate total length: prefix + name + null
    add rcx, r13
    inc rcx
    ; Record in glob_results
    mov rax, [glob_count]
    mov [glob_results + rax*8], rbx
    inc qword [glob_count]
    add rcx, [glob_buf_pos]
    mov [glob_buf_pos], rcx
    pop rbx                  ; restore fd
    jmp .ges_skip_entry

.ges_just_name:
    ; Copy just the name to glob_buf
    push rbx                 ; save fd
    mov rcx, [glob_buf_pos]
    lea rbx, [glob_buf + rcx]
    ; rdi = name pointer
    mov rsi, rdi
    mov rdi, rbx
    xor rcx, rcx
.ges_copy_name:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .ges_name_copied
    inc rcx
    cmp rcx, 255
    jge .ges_name_copied
    jmp .ges_copy_name
.ges_name_copied:
    mov byte [rdi + rcx], 0
    inc rcx
    ; Record in glob_results
    mov rax, [glob_count]
    mov [glob_results + rax*8], rbx
    inc qword [glob_count]
    add rcx, [glob_buf_pos]
    mov [glob_buf_pos], rcx
    pop rbx                  ; restore fd

.ges_skip_entry:
    pop rdx
    pop rcx
    pop rax
    add rcx, rdx
    jmp .ges_entry_loop

.ges_close:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall

.ges_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Pattern matching for glob
; rdi = string to match (filename)
; rsi = pattern (may contain * and ?)
; Returns: rax = 1 if match, 0 if not
glob_match:
    push rbx
    push r12
    push r13

    mov r12, rdi             ; string
    mov r13, rsi             ; pattern

.gm_loop:
    movzx eax, byte [r13]
    test al, al
    jz .gm_check_end

    cmp al, '*'
    je .gm_star
    cmp al, '?'
    je .gm_question
    cmp al, '['
    je .gm_bracket

    ; Literal character
    movzx ecx, byte [r12]
    cmp al, cl
    jne .gm_fail
    inc r12
    inc r13
    jmp .gm_loop

.gm_question:
    ; Match any single character
    cmp byte [r12], 0
    je .gm_fail
    inc r12
    inc r13
    jmp .gm_loop

.gm_star:
    ; Skip consecutive stars
    inc r13
    cmp byte [r13], '*'
    je .gm_star

    ; If * is at end of pattern, match everything
    cmp byte [r13], 0
    je .gm_succeed

    ; Try matching rest of pattern at every position
.gm_star_try:
    cmp byte [r12], 0
    je .gm_fail
    ; Try matching from current position
    push r12
    push r13
    mov rdi, r12
    mov rsi, r13
    call glob_match
    pop r13
    pop r12
    test rax, rax
    jnz .gm_succeed
    inc r12
    jmp .gm_star_try

.gm_bracket:
    ; Character class [abc] or [a-z] or [!abc] (negation)
    cmp byte [r12], 0
    je .gm_fail              ; no char to match
    inc r13                  ; skip '['
    movzx ecx, byte [r12]   ; char to match
    xor ebx, ebx            ; match found flag
    xor edx, edx            ; negation flag
    cmp byte [r13], '!'
    jne .gm_br_loop
    mov edx, 1
    inc r13
.gm_br_loop:
    cmp byte [r13], 0
    je .gm_fail              ; unterminated bracket
    cmp byte [r13], ']'
    je .gm_br_done
    ; Check for range: a-z
    cmp byte [r13 + 1], '-'
    jne .gm_br_literal
    cmp byte [r13 + 2], ']'
    je .gm_br_literal        ; treat - before ] as literal
    cmp byte [r13 + 2], 0
    je .gm_br_literal
    ; Range: [r13] to [r13+2]
    movzx eax, byte [r13]
    cmp cl, al
    jl .gm_br_range_no
    movzx eax, byte [r13 + 2]
    cmp cl, al
    jg .gm_br_range_no
    mov ebx, 1              ; match
.gm_br_range_no:
    add r13, 3               ; skip x-y
    jmp .gm_br_loop
.gm_br_literal:
    cmp cl, [r13]
    jne .gm_br_next
    mov ebx, 1              ; match
.gm_br_next:
    inc r13
    jmp .gm_br_loop
.gm_br_done:
    inc r13                  ; skip ']'
    ; Apply negation
    xor ebx, edx            ; if negated, flip match
    test ebx, ebx
    jz .gm_fail
    inc r12                  ; consume matched char
    jmp .gm_loop

.gm_check_end:
    cmp byte [r12], 0
    jne .gm_fail

.gm_succeed:
    mov eax, 1
    pop r13
    pop r12
    pop rbx
    ret

.gm_fail:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Tab completion
; ══════════════════════════════════════════════════════════════════════

; Complete command names from PATH
; rdi = partial command name
tab_complete_command:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi             ; partial name
    mov rdi, r12
    call strlen
    mov r13, rax             ; prefix length

    mov qword [tab_count], 0
    mov qword [tab_buf_pos], 0

    ; Get PATH
    push r12
    push r13
    mov rdi, [envp]
    call find_env_path
    pop r13
    pop r12
    test rax, rax
    jnz .tcc_have_path
    lea rax, [default_path]
.tcc_have_path:
    mov r14, rax             ; PATH value

.tcc_next_dir:
    cmp byte [r14], 0
    je .tcc_done

    ; Extract next directory from PATH
    lea rdi, [path_buf]
    mov rsi, r14
.tcc_copy_dir:
    movzx eax, byte [rsi]
    test al, al
    jz .tcc_dir_end
    cmp al, ':'
    je .tcc_dir_end
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .tcc_copy_dir
.tcc_dir_end:
    mov byte [rdi], 0
    mov r14, rsi
    cmp byte [r14], ':'
    jne .tcc_scan_dir
    inc r14

.tcc_scan_dir:
    ; Open directory
    mov rax, SYS_OPEN
    lea rdi, [path_buf]
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .tcc_next_dir
    mov r15, rax             ; fd

.tcc_read_entries:
    mov rax, SYS_GETDENTS64
    mov rdi, r15
    lea rsi, [tab_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .tcc_close_dir

    xor rcx, rcx
.tcc_entry_loop:
    cmp rcx, rax
    jge .tcc_read_entries

    lea rsi, [tab_dir_buf + rcx]
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    lea rdi, [rsi + DIRENT64_D_NAME]

    ; Check if name starts with our prefix
    push rax
    push rcx
    push rdx
    push rdi

    ; Compare prefix
    mov rsi, r12
    mov rcx, r13
    test rcx, rcx
    jz .tcc_matches          ; empty prefix matches everything
.tcc_prefix_cmp:
    movzx eax, byte [rsi]
    movzx ebx, byte [rdi]
    cmp al, bl
    jne .tcc_no_match
    inc rsi
    inc rdi
    dec rcx
    jnz .tcc_prefix_cmp

.tcc_matches:
    ; This entry matches the prefix
    pop rdi
    cmp qword [tab_count], MAX_TAB_RESULTS - 1
    jge .tcc_skip

    ; Dedup: check if this name already exists in tab_results
    push rdi
    xor rcx, rcx
.tcc_dedup:
    cmp rcx, [tab_count]
    jge .tcc_dedup_ok
    push rcx
    push rdi
    mov rsi, [tab_results + rcx*8]
    call strcmp
    pop rdi
    pop rcx
    test rax, rax
    jz .tcc_dedup_skip        ; duplicate found, skip
    inc rcx
    jmp .tcc_dedup
.tcc_dedup_skip:
    pop rdi
    jmp .tcc_skip
.tcc_dedup_ok:
    pop rdi

    ; Copy name to tab_buf
    mov rcx, [tab_buf_pos]
    lea rbx, [tab_buf + rcx]
    mov rsi, rdi
    xor rcx, rcx
.tcc_copy_match:
    mov al, [rsi + rcx]
    mov [rbx + rcx], al
    test al, al
    jz .tcc_match_copied
    inc rcx
    cmp rcx, 255
    jge .tcc_match_copied
    jmp .tcc_copy_match
.tcc_match_copied:
    mov byte [rbx + rcx], 0
    inc rcx
    mov rax, [tab_count]
    mov [tab_results + rax*8], rbx
    inc qword [tab_count]
    add rcx, [tab_buf_pos]
    mov [tab_buf_pos], rcx
    jmp .tcc_skip

.tcc_no_match:
    pop rdi
.tcc_skip:
    pop rdx
    pop rcx
    pop rax
    add rcx, rdx
    jmp .tcc_entry_loop

.tcc_close_dir:
    mov rax, SYS_CLOSE
    mov rdi, r15
    syscall
    jmp .tcc_next_dir

.tcc_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Sort tab_results array alphabetically (insertion sort)
; Also keeps tab_types in sync with tab_results
sort_tab_results:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, [tab_count]
    cmp r12, 2
    jl .str_done              ; 0 or 1 items, nothing to sort

    mov r13, 1                ; i = 1
.str_outer:
    cmp r13, r12
    jge .str_done

    mov r14, [tab_results + r13*8]  ; key_ptr = tab_results[i]
    movzx r15d, byte [tab_types + r13] ; key_type = tab_types[i]
    mov rbx, r13                     ; j = i

.str_inner:
    test rbx, rbx
    jz .str_insert
    ; Compare tab_results[j-1] with key (case-insensitive)
    mov rdi, [tab_results + rbx*8 - 8]
    mov rsi, r14
    call strcasecmp_sort
    test eax, eax
    jle .str_insert           ; tab_results[j-1] <= key, stop

    ; Shift tab_results[j-1] and tab_types[j-1] right
    mov rax, [tab_results + rbx*8 - 8]
    mov [tab_results + rbx*8], rax
    movzx eax, byte [tab_types + rbx - 1]
    mov byte [tab_types + rbx], al
    dec rbx
    jmp .str_inner

.str_insert:
    mov [tab_results + rbx*8], r14
    mov byte [tab_types + rbx], r15b
    inc r13
    jmp .str_outer

.str_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Case-insensitive string compare for sorting
; rdi = string a, rsi = string b
; Returns: <0 if a<b, 0 if a==b, >0 if a>b
strcasecmp_sort:
    push rbx
.scs_loop:
    movzx eax, byte [rdi]
    movzx ebx, byte [rsi]
    ; Lowercase both
    cmp al, 'A'
    jb .scs_no_lower_a
    cmp al, 'Z'
    ja .scs_no_lower_a
    add al, 32
.scs_no_lower_a:
    cmp bl, 'A'
    jb .scs_no_lower_b
    cmp bl, 'Z'
    ja .scs_no_lower_b
    add bl, 32
.scs_no_lower_b:
    cmp al, bl
    jne .scs_diff
    test al, al
    jz .scs_equal
    inc rdi
    inc rsi
    jmp .scs_loop
.scs_diff:
    movzx eax, al
    movzx ebx, bl
    sub eax, ebx
    pop rbx
    ret
.scs_equal:
    xor eax, eax
    pop rbx
    ret

; Complete filenames in current directory (or specified directory)
; rdi = partial filename (may include path prefix)
tab_complete_file:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi             ; partial name/path

    mov qword [tab_count], 0
    mov qword [tab_buf_pos], 0

    ; Check for directory prefix in the partial name
    mov rsi, r12
    xor r14, r14             ; last slash pos (0 = none)
    xor rcx, rcx
.tcf_find_slash:
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .tcf_slash_done
    cmp al, '/'
    jne .tcf_slash_next
    lea r14, [rcx + 1]
.tcf_slash_next:
    inc rcx
    jmp .tcf_find_slash
.tcf_slash_done:

    test r14, r14
    jz .tcf_cwd

    ; Has directory prefix
    lea rdi, [path_buf]
    mov rsi, r12
    mov rcx, r14
    dec rcx
    test rcx, rcx
    jz .tcf_root
.tcf_copy_dir:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .tcf_copy_dir
    mov byte [rdi], 0
    lea r15, [r12 + r14]     ; filename prefix
    jmp .tcf_open

.tcf_root:
    mov byte [path_buf], '/'
    mov byte [path_buf + 1], 0
    lea r15, [r12 + r14]
    jmp .tcf_open

.tcf_cwd:
    mov byte [path_buf], '.'
    mov byte [path_buf + 1], 0
    mov r15, r12             ; entire input is filename prefix

.tcf_open:
    ; Get prefix length
    mov rdi, r15
    call strlen
    mov r13, rax

    ; Open directory
    mov rax, SYS_OPEN
    lea rdi, [path_buf]
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .tcf_done
    mov rbx, rax             ; fd

.tcf_read_entries:
    mov rax, SYS_GETDENTS64
    mov rdi, rbx
    lea rsi, [tab_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .tcf_close

    xor rcx, rcx
.tcf_entry_loop:
    cmp rcx, rax
    jge .tcf_read_entries

    lea rsi, [tab_dir_buf + rcx]
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    lea rdi, [rsi + DIRENT64_D_NAME]

    push rax
    push rcx
    push rdx
    push rdi

    ; Skip . and .. (but allow .. if prefix is "..")
    cmp byte [rdi], '.'
    jne .tcf_check_prefix
    cmp byte [rdi + 1], 0
    je .tcf_no_match_f
    cmp byte [rdi + 1], '.'
    jne .tcf_check_dot_prefix
    cmp byte [rdi + 2], 0
    jne .tcf_check_dot_prefix
    ; Entry is ".." - allow it if prefix starts with ".."
    cmp byte [r15], '.'
    jne .tcf_no_match_f
    cmp byte [r15 + 1], '.'
    jne .tcf_no_match_f
    jmp .tcf_check_prefix    ; allow ".." to be matched
.tcf_check_dot_prefix:
    ; Only show dot files if prefix starts with dot
    cmp byte [r15], '.'
    jne .tcf_no_match_f

.tcf_check_prefix:
    ; Compare prefix
    mov rsi, r15
    mov rcx, r13
    test rcx, rcx
    jz .tcf_match_f
.tcf_cmp:
    movzx eax, byte [rsi]
    movzx r8d, byte [rdi]      ; do NOT clobber rbx (it holds the dir fd)
    cmp al, r8b
    jne .tcf_no_match_f
    inc rsi
    inc rdi
    dec rcx
    jnz .tcf_cmp

.tcf_match_f:
    pop rdi
    ; Save d_type from dirent (1 byte before d_name)
    movzx eax, byte [rdi - 1]
    mov [tab_saved_dtype], al
    cmp qword [tab_count], MAX_TAB_RESULTS - 1
    jge .tcf_skip_f

    ; Copy name to tab_buf. Use r9 (not rbx) as the destination cursor:
    ; rbx holds the directory fd, needed for the next getdents64 call.
    mov rcx, [tab_buf_pos]
    lea r9, [tab_buf + rcx]
    ; If there's a directory prefix, include it
    test r14, r14
    jz .tcf_copy_name_only

    ; Copy dir prefix first
    push rdi
    mov rsi, r12
    mov rdi, r9
    mov rcx, r14
.tcf_copy_dir_prefix:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .tcf_copy_dir_prefix
    mov r9, rdi              ; continue from here
    pop rdi

.tcf_copy_name_only:
    mov rsi, rdi
    xor rcx, rcx
.tcf_copy_match:
    mov al, [rsi + rcx]
    mov [r9 + rcx], al
    test al, al
    jz .tcf_match_copied
    inc rcx
    cmp rcx, 255
    jge .tcf_match_copied
    jmp .tcf_copy_match
.tcf_match_copied:
    mov byte [r9 + rcx], 0
    ; Calculate total size added to tab_buf
    lea rax, [tab_buf]
    add rax, [tab_buf_pos]
    ; The entry starts at tab_buf + old tab_buf_pos
    mov rdx, [tab_buf_pos]
    lea rax, [tab_buf + rdx]
    mov rcx, [tab_count]
    mov [tab_results + rcx*8], rax
    ; Store d_type
    movzx eax, byte [tab_saved_dtype]
    mov byte [tab_types + rcx], al
    mov rdi, [tab_results + rcx*8]  ; restore entry pointer for strlen
    inc qword [tab_count]
    ; Calculate new buf_pos: find end of what we wrote
    call strlen
    inc rax
    add [tab_buf_pos], rax
    jmp .tcf_skip_f

.tcf_no_match_f:
    pop rdi
.tcf_skip_f:
    pop rdx
    pop rcx
    pop rax
    add rcx, rdx
    jmp .tcf_entry_loop

.tcf_close:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall

.tcf_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Find longest common prefix among all tab results
; Returns: rax = length of common prefix
tab_find_common_prefix:
    push rbx
    push r12

    cmp qword [tab_count], 0
    je .tfcp_zero

    ; Start with length of first result
    mov rdi, [tab_results]
    call strlen
    mov r12, rax             ; max possible prefix length

    mov rcx, 1              ; start from second result
.tfcp_loop:
    cmp rcx, [tab_count]
    jge .tfcp_done
    push rcx
    ; Compare tab_results[0] with tab_results[rcx]
    mov rsi, [tab_results]
    mov rdi, [tab_results + rcx*8]
    xor rbx, rbx
.tfcp_cmp:
    cmp rbx, r12
    jge .tfcp_cmp_done
    movzx eax, byte [rsi + rbx]
    movzx edx, byte [rdi + rbx]
    test al, al
    jz .tfcp_cmp_done
    test dl, dl
    jz .tfcp_cmp_done
    cmp al, dl
    jne .tfcp_cmp_done
    inc rbx
    jmp .tfcp_cmp
.tfcp_cmp_done:
    cmp rbx, r12
    jge .tfcp_no_shrink
    mov r12, rbx
.tfcp_no_shrink:
    pop rcx
    inc rcx
    jmp .tfcp_loop

.tfcp_done:
    mov rax, r12
    pop r12
    pop rbx
    ret

.tfcp_zero:
    xor eax, eax
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Search PATH for a command
; rdi = command name
; Returns: rax = 1 if found (path in exec_path), 0 if not
; ══════════════════════════════════════════════════════════════════════
find_in_path:
    push rbx
    push r12
    push r13
    mov r12, rdi             ; command name

    ; Find PATH in environment
    mov rdi, [envp]
    call find_env_path
    test rax, rax
    jnz .fip_search
    lea rax, [default_path]
.fip_search:
    mov r13, rax             ; PATH value

.fip_next_dir:
    cmp byte [r13], 0
    je .fip_notfound

    ; Copy dir to exec_path
    lea rdi, [exec_path]
    mov rsi, r13
.fip_copy_dir:
    mov al, [rsi]
    test al, al
    jz .fip_dir_done
    cmp al, ':'
    je .fip_dir_done
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .fip_copy_dir
.fip_dir_done:
    ; Advance r13 past this dir
    mov r13, rsi
    cmp byte [r13], ':'
    jne .fip_add_slash
    inc r13
.fip_add_slash:
    mov byte [rdi], '/'
    inc rdi
    ; Append command name
    mov rsi, r12
.fip_copy_cmd:
    mov al, [rsi]
    test al, al
    jz .fip_copy_done
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .fip_copy_cmd
.fip_copy_done:
    mov byte [rdi], 0

    ; Check if file exists (stat)
    mov rax, SYS_STAT
    lea rdi, [exec_path]
    lea rsi, [tmp_buf]       ; stat buffer
    syscall
    test rax, rax
    jns .fip_found

    jmp .fip_next_dir

.fip_found:
    mov rax, 1
    pop r13
    pop r12
    pop rbx
    ret

.fip_notfound:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Environment helpers
; ══════════════════════════════════════════════════════════════════════

; Find HOME= in envp, return pointer to value (after =)
find_env_home:
    push rbx
    mov rbx, rdi             ; envp array
.feh_loop:
    mov rdi, [rbx]
    test rdi, rdi
    jz .feh_notfound
    cmp dword [rdi], 'HOME'
    jne .feh_next
    cmp byte [rdi+4], '='
    jne .feh_next
    lea rax, [rdi+5]
    pop rbx
    ret
.feh_next:
    add rbx, 8
    jmp .feh_loop
.feh_notfound:
    xor eax, eax
    pop rbx
    ret

; Find PATH= in envp, return pointer to value
find_env_path:
    push rbx
    mov rbx, rdi
.fep_loop:
    mov rdi, [rbx]
    test rdi, rdi
    jz .fep_notfound
    cmp dword [rdi], 'PATH'
    jne .fep_next
    cmp byte [rdi+4], '='
    jne .fep_next
    lea rax, [rdi+5]
    pop rbx
    ret
.fep_next:
    add rbx, 8
    jmp .fep_loop
.fep_notfound:
    xor eax, eax
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Terminal / termios
; ══════════════════════════════════════════════════════════════════════
save_termios:
    cmp qword [is_tty], 0
    je .st_ret
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCGETS
    lea rdx, [orig_termios]
    syscall
.st_ret:
    ret

restore_termios:
    cmp qword [is_tty], 0
    je .rt_ret
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [orig_termios]
    syscall
.rt_ret:
    ret

; Call after child process exit to restore terminal state
; before re-enabling raw mode
post_child_restore:
    cmp qword [is_tty], 0
    je .pcr_ret
    ; Re-read current termios (child may have changed terminal state)
    call save_termios
    ; Reset application cursor keys mode (SSH/tmux may set DECCKM)
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [reset_ckm_seq]
    mov rdx, 5
    syscall
.pcr_ret:
    ret

reset_ckm_seq: db 27, "[?1l"    ; Reset DECCKM (normal cursor keys)

enable_raw_mode:
    cmp qword [is_tty], 0
    je .erm_ret
    ; Copy orig to raw
    lea rsi, [orig_termios]
    lea rdi, [raw_termios]
    mov rcx, 60
    rep movsb
    ; Clear ICANON and ECHO in c_lflag (offset 12 in termios)
    mov eax, [raw_termios + 12]
    and eax, ~(ICANON | ECHO | ISIG)  ; raw: no canon, no echo, no signals
    mov [raw_termios + 12], eax
    ; Set VMIN=1, VTIME=0
    mov byte [raw_termios + 17 + VMIN], 1
    mov byte [raw_termios + 17 + VTIME], 0
    ; Apply
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [raw_termios]
    syscall
.erm_ret:
    ret

; Enable cooked mode with ISIG for child process execution
; Takes orig_termios and ensures ICANON, ECHO, ISIG are set
enable_cooked_mode:
    cmp qword [is_tty], 0
    je .ecm_ret
    ; Copy orig_termios to raw_termios as temp
    lea rsi, [orig_termios]
    lea rdi, [raw_termios]
    mov rcx, 60
    rep movsb
    ; Ensure ICANON, ECHO, ISIG are set; clear ECHOCTL so the kernel
    ; does not echo Ctrl+C / Ctrl+\ etc. as ^C / ^\ before the next prompt.
    mov eax, [raw_termios + 12]
    or eax, (ICANON | ECHO | ISIG)
    and eax, ~ECHOCTL
    mov [raw_termios + 12], eax
    ; Apply
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [raw_termios]
    syscall
.ecm_ret:
    ret

; ══════════════════════════════════════════════════════════════════════
; Signal setup: ignore SIGINT in shell
; ══════════════════════════════════════════════════════════════════════
setup_signals:
    ; struct sigaction on stack (152 bytes)
    sub rsp, 160
    ; Zero it
    xor eax, eax
    mov rdi, rsp
    mov rcx, 160
    rep stosb
    ; sa_handler = SIG_IGN (1)
    mov qword [rsp], SIG_IGN
    ; Ignore SIGINT
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGINT
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Ignore SIGTSTP (Ctrl-Z) in shell
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTSTP
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Ignore SIGQUIT
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGQUIT
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Ignore SIGTTOU (so shell can do terminal I/O as background group)
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTTOU
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    ; Ignore SIGTTIN
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTTIN
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall

    ; Handle SIGWINCH (terminal resize)
    ; Zero struct again for a fresh sigaction
    xor eax, eax
    mov rdi, rsp
    mov rcx, 160
    rep stosb
    mov qword [rsp], sigwinch_handler    ; sa_handler
    mov qword [rsp + 8], SA_RESTORER     ; sa_flags
    mov qword [rsp + 16], sigwinch_restorer ; sa_restorer (offset 16 for x86_64)
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGWINCH
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall

    ; Handle SIGHUP and SIGTERM: persist config + history before exit so
    ; closing the terminal window (which delivers SIGHUP via the kernel)
    ; doesn't drop nicks/bookmarks/etc set during the session.
    xor eax, eax
    mov rdi, rsp
    mov rcx, 160
    rep stosb
    mov qword [rsp], sighup_handler
    mov qword [rsp + 8], SA_RESTORER
    mov qword [rsp + 16], sigwinch_restorer
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGHUP
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall
    mov rax, SYS_RT_SIGACTION
    mov edi, SIGTERM
    mov rsi, rsp
    xor edx, edx
    mov r10, 8
    syscall

    add rsp, 160
    ret

; SIGHUP/SIGTERM handler: best-effort save and exit. Async-signal-safety
; is dicey here (we touch the file system), but the alternative is
; losing user state.
sighup_handler:
    call save_config
    call save_history
    xor edi, edi
    mov rax, SYS_EXIT
    syscall

; SIGWINCH signal handler (async-signal-safe: only sets a flag)
sigwinch_handler:
    mov qword [sigwinch_flag], 1
    ret

; Signal restorer trampoline (required by kernel for sa_restorer)
sigwinch_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall

; ══════════════════════════════════════════════════════════════════════
; History management
; ══════════════════════════════════════════════════════════════════════
build_hist_path:
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .bhp_done
    ; Copy home to hist_path
    lea rdi, [hist_path]
    mov rsi, rax
    call strcpy_rsi_rdi
.bhp_suffix:
    lea rsi, [hist_suffix]
    call strcpy_rsi_rdi
.bhp_done:
    ret

add_history:
    ; History deduplication check
    mov rax, [config_flags]

    ; Smart dedup: skip if same as last command
    test rax, (1 << CFG_HIST_DEDUP_SMART)
    jz .ah_check_full_dedup
    mov rcx, [hist_count]
    test rcx, rcx
    jz .ah_no_dedup
    dec rcx
    mov rdi, [hist_lines + rcx*8]
    test rdi, rdi
    jz .ah_no_dedup
    lea rsi, [line_buf]
    call strcmp
    test rax, rax
    jz .ah_skip_dup           ; same as last, skip
    jmp .ah_no_dedup

.ah_check_full_dedup:
    ; Full dedup: skip if anywhere in history
    test rax, (1 << CFG_HIST_DEDUP_FULL)
    jz .ah_no_dedup
    xor rcx, rcx
.ah_full_scan:
    cmp rcx, [hist_count]
    jge .ah_no_dedup
    push rcx
    mov rdi, [hist_lines + rcx*8]
    test rdi, rdi
    jz .ah_full_next
    lea rsi, [line_buf]
    call strcmp
    test rax, rax
    jz .ah_skip_dup_pop       ; found duplicate
.ah_full_next:
    pop rcx
    inc rcx
    jmp .ah_full_scan
.ah_skip_dup_pop:
    pop rcx
.ah_skip_dup:
    ret

.ah_no_dedup:
    mov rcx, [hist_count]
    cmp rcx, 8190
    jge .ah_shift            ; history full, shift down

    ; Store pointer to a copy in hist_buf
    ; Find end of hist_buf content
    mov rdi, hist_buf
    test rcx, rcx
    jz .ah_store
    ; Find end: scan past existing entries
    mov rax, rcx
    dec rax
    mov rdi, [hist_lines + rax*8]
    ; Skip to end of last entry
.ah_find_end:
    cmp byte [rdi], 0
    je .ah_found_end
    inc rdi
    jmp .ah_find_end
.ah_found_end:
    inc rdi                  ; past null terminator
    jmp .ah_store

.ah_shift:
    ; History array exhausted (>8190 entries this session). Drop the
    ; in-memory entries and start fresh — disk file keeps everything
    ; via the append-only save path. The new entry goes at slot 0.
    mov qword [hist_count], 0
    mov qword [hist_persisted], 0
    xor rcx, rcx
    mov rdi, hist_buf

.ah_store:
    mov [hist_lines + rcx*8], rdi
    ; Copy line_buf to hist_buf at rdi
    lea rsi, [line_buf]
    call strcpy_rsi_rdi
    inc qword [hist_count]
    ret

load_history:
    push rbx
    push r12
    push r13
    ; Open history file
    mov rax, SYS_OPEN
    lea rdi, [hist_path]
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .lh_no_file           ; file doesn't exist
    mov r12, rax             ; fd

    ; Read into hist_buf (capped to slightly under buffer size).
    mov rax, SYS_READ
    mov rdi, r12
    lea rsi, [hist_buf]
    mov rdx, 524000
    syscall
    mov r13, rax             ; bytes read

    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall

    test r13, r13
    jle .lh_done

    ; Parse lines
    lea rsi, [hist_buf]
    xor ecx, ecx
.lh_parse:
    cmp rsi, hist_buf
    jb .lh_done
    lea rax, [hist_buf + r13]
    cmp rsi, rax
    jge .lh_done
    cmp ecx, 8190
    jge .lh_done

    mov [hist_lines + rcx*8], rsi
    inc ecx
    ; Find end of line
.lh_find_nl:
    cmp byte [rsi], 0
    je .lh_done
    cmp byte [rsi], 10
    je .lh_nl
    lea rax, [hist_buf + r13]
    cmp rsi, rax
    jge .lh_done
    inc rsi
    jmp .lh_find_nl
.lh_nl:
    mov byte [rsi], 0
    inc rsi
    jmp .lh_parse

.lh_no_file:
    xor ecx, ecx
.lh_done:
    mov [hist_count], rcx
    mov [hist_persisted], rcx
    pop r13
    pop r12
    pop rbx
    ret

save_history:
    push rbx
    push r12
    push r13
    ; Append-only: open with O_APPEND (no O_TRUNC) and write only the
    ; entries added since the last save. Concurrent bare instances
    ; can both write without clobbering each other's additions.
    mov rax, SYS_OPEN
    lea rdi, [hist_path]
    mov esi, O_WRONLY | O_CREAT | O_APPEND
    mov edx, 0o644
    syscall
    test rax, rax
    js .sh_done
    mov r12, rax             ; fd

    mov r13, [hist_persisted]
.sh_loop:
    cmp r13, [hist_count]
    jge .sh_close
    mov rsi, [hist_lines + r13*8]
    test rsi, rsi
    jz .sh_next
    push r13
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [hist_lines + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    pop r13
.sh_next:
    inc r13
    jmp .sh_loop

.sh_close:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    mov rax, [hist_count]
    mov [hist_persisted], rax
.sh_done:
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Utility functions
; ══════════════════════════════════════════════════════════════════════

; Update current working directory
update_cwd:
    mov rax, SYS_GETCWD
    lea rdi, [cwd_buf]
    mov rsi, 4096
    syscall
    ret

; strlen: rdi = string, returns rax = length
strlen:
    push rdi
    xor eax, eax
.sl_loop:
    cmp byte [rdi], 0
    je .sl_done
    inc rdi
    inc eax
    jmp .sl_loop
.sl_done:
    pop rdi
    ret

; strcmp: rdi, rsi = strings. Returns rax=0 if equal, nonzero if not
strcmp:
.sc_loop:
    mov al, [rdi]
    mov cl, [rsi]
    cmp al, cl
    jne .sc_neq
    test al, al
    jz .sc_eq
    inc rdi
    inc rsi
    jmp .sc_loop
.sc_eq:
    xor eax, eax
    ret
.sc_neq:
    mov eax, 1
    ret

; write_stdout: rsi = buffer, rdx = length. Writes to stdout.
; Preserves: rdi, rsi, rdx, rbx, r12-r15. Clobbers: rax, rcx, r11.
write_stdout:
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
    ret

; write_stderr: rsi = buffer, rdx = length. Writes to stderr.
; Preserves: rdi, rsi, rdx, rbx, r12-r15. Clobbers: rax, rcx, r11.
write_stderr:
    mov rax, SYS_WRITE
    mov rdi, 2
    syscall
    ret

; write_nl: writes newline to stdout. No arguments.
; Preserves: rdi, rbx, r12-r15. Clobbers: rax, rcx, r11, rsi, rdx.
write_nl:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall
    ret

; write_str_stdout: writes null-terminated string from rsi to stdout.
; Preserves: rdi, rsi, rbx, r12-r15. Clobbers: rax, rcx, rdx, r11.
write_str_stdout:
    push rdi
    push rsi
    mov rdi, rsi
    call strlen
    mov rdx, rax
    pop rsi
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
    pop rdi
    ret

; strcpy_rsi_rdi: copies null-terminated string from rsi to rdi.
; Returns bytes copied (excluding null) in rax. Null terminator IS copied.
; Advances rdi and rsi past the copied content (pointing at the null).
strcpy_rsi_rdi:
    xor eax, eax
.scrd_loop:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .scrd_done
    inc rsi
    inc rdi
    inc eax
    jmp .scrd_loop
.scrd_done:
    ret

; skip_spaces: rsi = string, advances past spaces
skip_spaces:
.ss_loop:
    cmp byte [rsi], ' '
    je .ss_inc
    cmp byte [rsi], 9
    je .ss_inc
    ret
.ss_inc:
    inc rsi
    jmp .ss_loop

; itoa: convert rax to decimal string at rdi, returns length in rax
itoa:
    push rbx
    push rcx
    mov rbx, rdi
    xor ecx, ecx
    mov r8, 10
.itoa_div:
    xor edx, edx
    div r8
    add dl, '0'
    push rdx
    inc ecx
    test rax, rax
    jnz .itoa_div
    ; Pop digits in order
    xor eax, eax
.itoa_pop:
    pop rdx
    mov [rbx + rax], dl
    inc eax
    dec ecx
    jnz .itoa_pop
    mov byte [rbx + rax], 0
    pop rcx
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Cache all executables in PATH for syntax highlighting
; Scans each PATH directory and stores names in exe_cache
; ══════════════════════════════════════════════════════════════════════
init_exe_cache:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov qword [exe_cache_pos], 0
    mov qword [exe_cache_count], 0

    ; Get PATH
    mov rdi, [envp]
    call find_env_path
    test rax, rax
    jnz .iec_have_path
    lea rax, [default_path]
.iec_have_path:
    mov r14, rax             ; PATH string

.iec_next_dir:
    cmp byte [r14], 0
    je .iec_done

    ; Extract next directory from PATH
    lea rdi, [path_buf]
    mov rsi, r14
.iec_copy_dir:
    movzx eax, byte [rsi]
    test al, al
    jz .iec_dir_end
    cmp al, ':'
    je .iec_dir_end
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .iec_copy_dir
.iec_dir_end:
    mov byte [rdi], 0
    mov r14, rsi
    cmp byte [r14], ':'
    jne .iec_scan_dir
    inc r14

.iec_scan_dir:
    mov rax, SYS_OPEN
    lea rdi, [path_buf]
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .iec_next_dir
    mov r15, rax             ; fd

.iec_read_entries:
    mov rax, SYS_GETDENTS64
    mov rdi, r15
    lea rsi, [tab_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .iec_close_dir

    xor r12, r12
.iec_entry_loop:
    cmp r12, rax
    jge .iec_read_entries

    lea rsi, [tab_dir_buf + r12]
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    lea rdi, [rsi + DIRENT64_D_NAME]

    ; Skip . and ..
    cmp byte [rdi], '.'
    jne .iec_not_dot
    cmp byte [rdi + 1], 0
    je .iec_skip
    cmp byte [rdi + 1], '.'
    jne .iec_not_dot
    cmp byte [rdi + 2], 0
    je .iec_skip
.iec_not_dot:
    ; Check buffer space
    mov rcx, [exe_cache_pos]
    cmp rcx, 64000
    jge .iec_close_dir       ; cache full

    ; Check for duplicates
    push rax
    push rdx
    push rdi
    call .iec_is_dup
    test rax, rax
    pop rdi
    pop rdx
    pop rax
    jnz .iec_skip            ; duplicate, skip

    ; Copy name to cache
    push rax
    push rdx
    mov rcx, [exe_cache_pos]
    lea r13, [exe_cache + rcx]
    mov rsi, rdi
.iec_copy_name:
    movzx ebx, byte [rsi]
    mov [r13], bl
    test bl, bl
    jz .iec_name_done
    inc rsi
    inc r13
    jmp .iec_copy_name
.iec_name_done:
    mov byte [r13], 0
    inc r13
    sub r13, exe_cache
    mov [exe_cache_pos], r13
    inc qword [exe_cache_count]
    pop rdx
    pop rax

.iec_skip:
    add r12, rdx
    jmp .iec_entry_loop

.iec_close_dir:
    push r14
    mov rax, SYS_CLOSE
    mov rdi, r15
    syscall
    pop r14
    jmp .iec_next_dir

.iec_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ; Persist the freshly-built cache so the next bare instance can
    ; skip the PATH scan entirely and start instantly.
    call save_exec_cache
    ret

; Check if name (rdi) is already in exe_cache. Returns rax=1 if dup, 0 if not.
.iec_is_dup:
    push rbx
    push rcx
    push rsi
    lea rsi, [exe_cache]
    mov rcx, [exe_cache_pos]
    test rcx, rcx
    jz .iec_dup_no
    lea rbx, [exe_cache + rcx]  ; end of cache
.iec_dup_scan:
    cmp rsi, rbx
    jge .iec_dup_no
    ; Compare rdi with rsi
    push rdi
    push rsi
.iec_dup_cmp:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    cmp al, cl
    jne .iec_dup_next
    test al, al
    jz .iec_dup_yes
    inc rdi
    inc rsi
    jmp .iec_dup_cmp
.iec_dup_next:
    pop rsi
    pop rdi
    ; Advance rsi to next null
.iec_dup_skip:
    cmp byte [rsi], 0
    je .iec_dup_adv
    inc rsi
    jmp .iec_dup_skip
.iec_dup_adv:
    inc rsi                  ; skip null
    jmp .iec_dup_scan
.iec_dup_yes:
    pop rsi
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    mov eax, 1
    ret
.iec_dup_no:
    pop rsi
    pop rcx
    pop rbx
    xor eax, eax
    ret

; ══════════════════════════════════════════════════════════════════════
; Persistent exe_cache: load on startup (instant), rebuild on first
; tab if missing (lazy). save_exec_cache is called from the end of
; init_exe_cache so a successful rebuild is durable.
; ══════════════════════════════════════════════════════════════════════

build_exec_cache_path:
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .becp_done
    lea rdi, [exec_cache_path]
    mov rsi, rax
    call strcpy_rsi_rdi
    lea rsi, [exec_cache_suffix]
    call strcpy_rsi_rdi
.becp_done:
    ret

; load_exec_cache: read ~/.bare_exe_cache into exe_cache.
; File format: 8-byte count + 8-byte size + raw cache bytes.
; Returns rax=1 on success, 0 if missing/invalid OR if the cache
; is stale (any PATH directory has been modified more recently than
; the cache file's mtime). Caller then falls back to init_exe_cache.
load_exec_cache:
    push rbx
    push r12
    push r13
    mov rax, SYS_OPEN
    lea rdi, [exec_cache_path]
    xor esi, esi
    xor edx, edx
    syscall
    test rax, rax
    js .lec_fail
    mov r12, rax
    ; Capture cache mtime via fstat — used downstream for staleness.
    sub rsp, 144
    mov rax, SYS_FSTAT
    mov rdi, r12
    mov rsi, rsp
    syscall
    test rax, rax
    js .lec_fstat_fail
    mov r13, [rsp + 88]                  ; st_mtime
    add rsp, 144
    sub rsp, 16
    mov rax, SYS_READ
    mov rdi, r12
    mov rsi, rsp
    mov rdx, 16
    syscall
    cmp rax, 16
    jne .lec_close_fail
    mov rax, [rsp]
    mov rbx, [rsp + 8]
    add rsp, 16
    cmp rbx, 65000
    ja .lec_close_fail2
    mov [exe_cache_count], rax
    mov [exe_cache_pos], rbx
    mov rax, SYS_READ
    mov rdi, r12
    lea rsi, [exe_cache]
    mov rdx, rbx
    syscall
    cmp rax, rbx
    jne .lec_close_fail2
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    ; Cache loaded. Now check freshness vs PATH dir mtimes.
    mov rdi, r13
    call exec_cache_stale
    test rax, rax
    jnz .lec_stale
    pop r13
    pop r12
    pop rbx
    mov eax, 1
    ret
.lec_stale:
    ; Discard the loaded data so the caller falls back to a rebuild.
    mov qword [exe_cache_count], 0
    mov qword [exe_cache_pos], 0
    pop r13
    pop r12
    pop rbx
    xor eax, eax
    ret
.lec_fstat_fail:
    add rsp, 144
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    jmp .lec_fail
.lec_close_fail:
    add rsp, 16
.lec_close_fail2:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
.lec_fail:
    mov qword [exe_cache_count], 0
    mov qword [exe_cache_pos], 0
    pop r13
    pop r12
    pop rbx
    xor eax, eax
    ret

; rdi = cache file mtime (st_mtime, seconds since epoch).
; Returns rax = 1 if any directory in $PATH has been modified more
; recently than the cache (so the cache may have stale entries),
; else 0. PATH is parsed from env_array; missing or unreadable dirs
; are skipped (no false positives).
exec_cache_stale:
    push rbx
    push r12
    push r13
    push r14
    mov r13, rdi                          ; cache mtime
    lea rdi, [env_array]
    call find_env_path
    test rax, rax
    jz .ecs_fresh                         ; no PATH → can't stale
    mov r12, rax                          ; PATH cursor
    sub rsp, 4096
.ecs_dir_loop:
    ; Copy the next ':'-separated directory into stack scratch.
    mov rdi, rsp
    xor ecx, ecx
.ecs_copy:
    mov al, [r12]
    test al, al
    jz .ecs_dir_done
    cmp al, ':'
    je .ecs_dir_done
    cmp ecx, 4094
    jge .ecs_advance
    mov [rdi + rcx], al
    inc ecx
.ecs_advance:
    inc r12
    jmp .ecs_copy
.ecs_dir_done:
    mov byte [rdi + rcx], 0
    test ecx, ecx
    jz .ecs_skip
    sub rsp, 144
    mov rax, SYS_STAT
    mov rdi, rsp
    add rdi, 144                          ; path lives just above stat buf
    lea rsi, [rsp]
    syscall
    test rax, rax
    js .ecs_skip_stat
    mov r14, [rsp + 88]                   ; st_mtime
    add rsp, 144
    cmp r14, r13
    jbe .ecs_skip
    add rsp, 4096
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 1
    ret
.ecs_skip_stat:
    add rsp, 144
.ecs_skip:
    mov al, [r12]
    test al, al
    jz .ecs_path_done
    cmp al, ':'
    jne .ecs_dir_loop
    inc r12
    jmp .ecs_dir_loop
.ecs_path_done:
    add rsp, 4096
.ecs_fresh:
    pop r14
    pop r13
    pop r12
    pop rbx
    xor eax, eax
    ret

; save_exec_cache: best-effort write of exe_cache to disk.
save_exec_cache:
    push rbx
    push r12
    mov rax, SYS_OPEN
    lea rdi, [exec_cache_path]
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0o644
    syscall
    test rax, rax
    js .sec_done
    mov r12, rax
    sub rsp, 16
    mov rax, [exe_cache_count]
    mov [rsp], rax
    mov rax, [exe_cache_pos]
    mov [rsp + 8], rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, rsp
    mov rdx, 16
    syscall
    add rsp, 16
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [exe_cache]
    mov rdx, [exe_cache_pos]
    syscall
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
.sec_done:
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Check if a null-terminated word is a cached executable
; rdi = word to check. Returns rax=1 if found, 0 if not.
; ══════════════════════════════════════════════════════════════════════
is_exe_cached:
    push rbx
    push rcx
    push rsi
    push rdi
    lea rsi, [exe_cache]
    mov rcx, [exe_cache_pos]
    test rcx, rcx
    jz .ixc_no
    lea rbx, [exe_cache + rcx]
.ixc_scan:
    cmp rsi, rbx
    jge .ixc_no
    mov rdi, [rsp]           ; reload original word
.ixc_cmp:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    cmp al, cl
    jne .ixc_next
    test al, al
    jz .ixc_yes
    inc rdi
    inc rsi
    jmp .ixc_cmp
.ixc_next:
    ; Advance rsi past current entry
.ixc_skip:
    cmp byte [rsi], 0
    je .ixc_adv
    inc rsi
    jmp .ixc_skip
.ixc_adv:
    inc rsi
    jmp .ixc_scan
.ixc_yes:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    mov eax, 1
    ret
.ixc_no:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    xor eax, eax
    ret

; ══════════════════════════════════════════════════════════════════════
; Check if a null-terminated word is a nick name
; rdi = word. Returns rax=1 if found, 0 if not.
; ══════════════════════════════════════════════════════════════════════
is_nick_name:
    push rbx
    push rcx
    push rdi
    xor ecx, ecx
.inn_loop:
    cmp rcx, [nick_count]
    jge .inn_no
    mov rsi, [nick_names + rcx*8]
    test rsi, rsi
    jz .inn_next
    mov rdi, [rsp]           ; reload word
    push rcx
    call strcmp
    pop rcx
    test rax, rax
    jz .inn_yes
.inn_next:
    inc rcx
    jmp .inn_loop
.inn_yes:
    pop rdi
    pop rcx
    pop rbx
    mov eax, 1
    ret
.inn_no:
    pop rdi
    pop rcx
    pop rbx
    xor eax, eax
    ret

; ══════════════════════════════════════════════════════════════════════
; Initialize default color settings
; ══════════════════════════════════════════════════════════════════════
init_default_colors:
    lea rdi, [color_settings]
    mov byte [rdi + C_USER], 2        ; green
    mov byte [rdi + C_HOST], 2        ; green
    mov byte [rdi + C_CWD], 81        ; light blue
    mov byte [rdi + C_PROMPT], 208    ; orange
    mov byte [rdi + C_CMD], 48        ; teal
    mov byte [rdi + C_NICK], 6        ; cyan
    mov byte [rdi + C_GNICK], 33      ; bright blue
    mov byte [rdi + C_PATH], 3        ; yellow
    mov byte [rdi + C_SWITCH], 6      ; cyan
    mov byte [rdi + C_BOOKMARK], 5    ; magenta
    mov byte [rdi + C_COLON], 4       ; blue
    mov byte [rdi + C_GIT], 208       ; orange
    mov byte [rdi + C_STAMP], 245     ; gray
    mov byte [rdi + C_TABSEL], 7      ; white (reverse)
    mov byte [rdi + C_TABOPT], 245    ; gray
    mov byte [rdi + C_SUGGEST], 240   ; dark gray
    mov byte [rdi + C_USER_ROOT], 196 ; red
    mov byte [rdi + C_HOST_ROOT], 196 ; red
    ; Default config flags: rprompt on, hist_dedup smart
    mov qword [config_flags], (1 << CFG_RPROMPT) | (1 << CFG_HIST_DEDUP_SMART) | (1 << CFG_AUTO_PAIR) | (1 << CFG_SHOW_TIPS) | (1 << CFG_GIT_STATUS_FORK)
    mov qword [completion_limit], 10
    mov qword [slow_cmd_threshold], 0
    ret

; ══════════════════════════════════════════════════════════════════════
; Build config file path (~/.barerc)
; ══════════════════════════════════════════════════════════════════════
build_config_path:
    push rbx
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .bcp_default
    mov rsi, rax
    lea rdi, [config_path]
    ; Copy HOME
    call strcpy_rsi_rdi
.bcp_append:
    ; Append /.barerc
    lea rsi, [config_suffix]
    call strcpy_rsi_rdi
.bcp_default:
.bcp_done:
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Initialize username from $USER
; ══════════════════════════════════════════════════════════════════════
init_username:
    push rbx
    ; Look for USER= in env_array
    xor rcx, rcx
.iu_loop:
    cmp rcx, [env_count]
    jge .iu_default
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .iu_next
    ; Check if starts with "USER="
    cmp byte [rsi], 'U'
    jne .iu_next
    cmp byte [rsi+1], 'S'
    jne .iu_next
    cmp byte [rsi+2], 'E'
    jne .iu_next
    cmp byte [rsi+3], 'R'
    jne .iu_next
    cmp byte [rsi+4], '='
    jne .iu_next
    ; Found USER=, copy value
    add rsi, 5
    lea rdi, [username_buf]
    mov rcx, 62
.iu_copy:
    mov al, [rsi]
    test al, al
    jz .iu_copy_done
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .iu_copy
.iu_copy_done:
    mov byte [rdi], 0
    pop rbx
    ret
.iu_next:
    inc rcx
    jmp .iu_loop
.iu_default:
    lea rdi, [username_buf]
    mov dword [rdi], 'bare'
    mov byte [rdi+4], 0
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Initialize hostname from /etc/hostname
; ══════════════════════════════════════════════════════════════════════
; Detect timezone offset by running "date +%z" and parsing output
init_timezone:
    push rbx
    push r12
    mov qword [tz_offset], 0

    ; Create pipe
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    jnz .itz_done

    ; Fork
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .itz_child
    js .itz_close

    ; Parent: read output
    mov r12, rax             ; child pid
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]  ; close write end
    syscall

    sub rsp, 16
    mov rax, SYS_READ
    mov edi, [pipe_fds]
    mov rsi, rsp
    mov rdx, 10
    syscall
    mov rbx, rax             ; bytes read

    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall

    ; Wait for child
    sub rsp, 16
    mov rax, SYS_WAIT4
    mov rdi, r12
    mov rsi, rsp
    xor edx, edx
    xor r10d, r10d
    syscall
    add rsp, 16

    ; Parse "+HHMM" or "-HHMM" from stack
    cmp rbx, 5
    jl .itz_parse_done
    movzx eax, byte [rsp]   ; sign
    mov r12, 1               ; positive
    cmp al, '-'
    jne .itz_pos
    mov r12, -1
.itz_pos:
    ; Parse HH
    movzx eax, byte [rsp + 1]
    sub al, '0'
    imul eax, 10
    movzx ecx, byte [rsp + 2]
    sub cl, '0'
    add eax, ecx
    imul eax, 3600           ; hours to seconds
    mov rbx, rax
    ; Parse MM
    movzx eax, byte [rsp + 3]
    sub al, '0'
    imul eax, 10
    movzx ecx, byte [rsp + 4]
    sub cl, '0'
    add eax, ecx
    imul eax, 60             ; minutes to seconds
    add rbx, rax
    imul rbx, r12            ; apply sign
    mov [tz_offset], rbx
.itz_parse_done:
    add rsp, 16
.itz_done:
    pop r12
    pop rbx
    ret

.itz_close:
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    jmp .itz_done

.itz_child:
    ; Close read end
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
    ; Dup write end to stdout
    mov rax, SYS_DUP2
    mov edi, [pipe_fds + 4]
    mov esi, 1
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    ; exec date +%z
    sub rsp, 32
    lea rax, [.itz_date]
    mov [rsp], rax
    lea rax, [.itz_fmt]
    mov [rsp + 8], rax
    mov qword [rsp + 16], 0
    mov rdi, [rsp]
    mov rsi, rsp
    mov rdx, [envp]
    mov rax, SYS_EXECVE
    syscall
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall
.itz_date: db "/usr/bin/date", 0
.itz_fmt: db "+%z", 0

init_hostname:
    push rbx
    mov rax, SYS_OPEN
    lea rdi, [etc_hostname]
    xor esi, esi            ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .ih_default
    mov rbx, rax            ; fd
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [hostname_buf]
    mov rdx, 254
    syscall
    push rax
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax
    test rax, rax
    jle .ih_default
    ; Strip trailing newline
    lea rdi, [hostname_buf]
    add rdi, rax
    dec rdi
    cmp byte [rdi], 10
    jne .ih_no_strip
    mov byte [rdi], 0
    pop rbx
    ret
.ih_no_strip:
    mov byte [rdi+1], 0
    pop rbx
    ret
.ih_default:
    lea rdi, [hostname_buf]
    mov dword [rdi], 'host'
    mov byte [rdi+4], 0
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Load config from ~/.barerc
; Line format: key = value (or key.subkey = value)
; Lines starting with # are comments
; ══════════════════════════════════════════════════════════════════════
load_config:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Reset alias/bookmark counts (prevent duplicates on reload)
    mov qword [nick_count], 0
    mov qword [nick_storage_pos], 0
    mov qword [gnick_count], 0
    mov qword [gnick_storage_pos], 0
    mov qword [abbrev_count], 0
    mov qword [abbrev_storage_pos], 0
    mov qword [bm_count], 0

    ; Open config file
    mov rax, SYS_OPEN
    lea rdi, [config_path]
    xor esi, esi            ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .lc_done             ; no config file, use defaults

    mov rbx, rax            ; fd
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [config_buf]
    mov rdx, 16383
    syscall
    push rax                ; save bytes read
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax
    test rax, rax
    jle .lc_done

    ; Null-terminate
    mov byte [config_buf + rax], 0

    ; Parse line by line
    lea r12, [config_buf]   ; current position

.lc_next_line:
    cmp byte [r12], 0
    je .lc_done

    ; Skip whitespace
    cmp byte [r12], ' '
    je .lc_skip_ws
    cmp byte [r12], 9       ; tab
    je .lc_skip_ws
    jmp .lc_check_line

.lc_skip_ws:
    inc r12
    jmp .lc_next_line

.lc_check_line:
    ; Skip comments
    cmp byte [r12], '#'
    je .lc_skip_line
    ; Skip empty lines
    cmp byte [r12], 10
    je .lc_skip_newline

    ; Find '=' separator
    mov rsi, r12
.lc_find_eq:
    cmp byte [rsi], 0
    je .lc_skip_line
    cmp byte [rsi], 10
    je .lc_skip_line
    cmp byte [rsi], '='
    je .lc_found_eq
    inc rsi
    jmp .lc_find_eq

.lc_found_eq:
    ; r12 = key start, rsi = '=' position
    ; Trim trailing spaces from key
    mov r13, rsi            ; save '=' pos
    dec rsi
.lc_trim_key:
    cmp rsi, r12
    jle .lc_key_trimmed
    cmp byte [rsi], ' '
    jne .lc_key_trimmed
    dec rsi
    jmp .lc_trim_key
.lc_key_trimmed:
    inc rsi
    mov byte [rsi], 0       ; null-terminate key
    ; r12 = key (null-terminated)

    ; Skip '=' and leading spaces of value
    lea r14, [r13 + 1]
.lc_skip_val_ws:
    cmp byte [r14], ' '
    jne .lc_val_start
    inc r14
    jmp .lc_skip_val_ws
.lc_val_start:
    ; Find end of value (newline or null)
    mov r15, r14
.lc_find_val_end:
    cmp byte [r15], 0
    je .lc_val_end
    cmp byte [r15], 10
    je .lc_val_end
    inc r15
    jmp .lc_find_val_end
.lc_val_end:
    ; Save original end-of-line char and its position for later advance
    movzx ebx, byte [r15]    ; save \n or \0
    ; Trim trailing spaces from value
    mov rsi, r15
    dec rsi
.lc_trim_val:
    cmp rsi, r14
    jl .lc_val_trimmed
    cmp byte [rsi], ' '
    jne .lc_val_trimmed
    dec rsi
    jmp .lc_trim_val
.lc_val_trimmed:
    inc rsi
    push qword 0            ; save whether we stopped at \n or \0
    cmp byte [r15], 10
    jne .lc_no_nl
    mov qword [rsp], 1
.lc_no_nl:
    mov byte [rsi], 0       ; null-terminate value

    ; r12 = key, r14 = value
    ; Route based on key prefix
    ; Check for "nick."
    cmp dword [r12], 'nick'
    jne .lc_not_nick
    cmp byte [r12+4], '.'
    jne .lc_not_nick
    ; Nick: key = nick.NAME, value = expansion
    lea rdi, [r12 + 5]      ; name starts after "nick."
    mov rsi, r14             ; value
    call config_add_nick
    jmp .lc_advance

.lc_not_nick:
    ; Check for "gnick."
    cmp dword [r12], 'gnic'
    jne .lc_not_gnick
    cmp word [r12+4], 'k.'
    jne .lc_not_gnick
    lea rdi, [r12 + 6]
    mov rsi, r14
    call config_add_gnick
    jmp .lc_advance

.lc_not_gnick:
    ; Check for "abbrev."
    cmp dword [r12], 'abbr'
    jne .lc_not_abbrev
    cmp word [r12+4], 'ev'
    jne .lc_not_abbrev
    cmp byte [r12+6], '.'
    jne .lc_not_abbrev
    lea rdi, [r12 + 7]
    mov rsi, r14
    call config_add_abbrev
    jmp .lc_advance

.lc_not_abbrev:
    ; Check for "bm."
    cmp word [r12], 'bm'
    jne .lc_not_bm
    cmp byte [r12+2], '.'
    jne .lc_not_bm
    lea rdi, [r12 + 3]
    mov rsi, r14
    call config_add_bookmark
    jmp .lc_advance

.lc_not_bm:
    ; Check for color settings "c_"
    cmp word [r12], 'c_'
    jne .lc_not_color
    lea rdi, [r12 + 2]
    mov rsi, r14
    call config_set_color
    jmp .lc_advance

.lc_not_color:
    ; Check for "completion_limit"
    mov rdi, r12
    lea rsi, [.str_comp_limit]
    call strcmp
    test rax, rax
    jnz .lc_not_complimit
    ; Parse integer value
    mov rdi, r14
    call parse_int
    mov [completion_limit], rax
    jmp .lc_advance
.str_comp_limit: db "completion_limit", 0

.lc_not_complimit:
    ; Check for "slow_command_threshold"
    mov rdi, r12
    lea rsi, [.str_slow_thresh]
    call strcmp
    test rax, rax
    jnz .lc_not_slowthresh
    mov rdi, r14
    call parse_int
    mov [slow_cmd_threshold], rax
    jmp .lc_advance
.str_slow_thresh: db "slow_command_threshold", 0

.lc_not_slowthresh:
    ; Check for boolean config flags
    mov rdi, r12
    lea rsi, [.str_hist_dedup]
    call strcmp
    test rax, rax
    jnz .lc_not_histdedup
    ; Value: "off", "full", "smart"
    cmp byte [r14], 'f'
    jne .lc_hd_not_full
    ; "full"
    and qword [config_flags], ~(1 << CFG_HIST_DEDUP_SMART)
    or qword [config_flags], (1 << CFG_HIST_DEDUP_FULL)
    jmp .lc_advance
.lc_hd_not_full:
    cmp byte [r14], 's'
    jne .lc_hd_off
    ; "smart"
    and qword [config_flags], ~(1 << CFG_HIST_DEDUP_FULL)
    or qword [config_flags], (1 << CFG_HIST_DEDUP_SMART)
    jmp .lc_advance
.lc_hd_off:
    ; "off"
    and qword [config_flags], ~((1 << CFG_HIST_DEDUP_FULL) | (1 << CFG_HIST_DEDUP_SMART))
    jmp .lc_advance
.str_hist_dedup: db "history_dedup", 0

.lc_not_histdedup:
    ; Check boolean flags: show_tips, auto_correct, completion_fuzzy, rprompt, auto_pair
    mov rdi, r12
    lea rsi, [.str_show_tips]
    call strcmp
    test rax, rax
    jnz .lc_not_st
    mov rdi, r14
    mov rsi, CFG_SHOW_TIPS
    call config_set_bool
    jmp .lc_advance
.str_show_tips: db "show_tips", 0

.lc_not_st:
    mov rdi, r12
    lea rsi, [.str_auto_correct]
    call strcmp
    test rax, rax
    jnz .lc_not_ac
    mov rdi, r14
    mov rsi, CFG_AUTO_CORRECT
    call config_set_bool
    jmp .lc_advance
.str_auto_correct: db "auto_correct", 0

.lc_not_ac:
    mov rdi, r12
    lea rsi, [.str_comp_fuzzy]
    call strcmp
    test rax, rax
    jnz .lc_not_cf
    mov rdi, r14
    mov rsi, CFG_COMPLETION_FUZZY
    call config_set_bool
    jmp .lc_advance
.str_comp_fuzzy: db "completion_fuzzy", 0

.lc_not_cf:
    mov rdi, r12
    lea rsi, [.str_rprompt]
    call strcmp
    test rax, rax
    jnz .lc_not_rp
    mov rdi, r14
    mov rsi, CFG_RPROMPT
    call config_set_bool
    jmp .lc_advance
.str_rprompt: db "rprompt", 0

.lc_not_rp:
    mov rdi, r12
    lea rsi, [.str_auto_pair]
    call strcmp
    test rax, rax
    jnz .lc_not_ap
    mov rdi, r14
    mov rsi, CFG_AUTO_PAIR
    call config_set_bool

.lc_advance:
    pop rax                  ; discard old newline flag
    ; r15 = original end position, bl = saved original char (\n or \0)
    lea r12, [r15 + 1]       ; skip past original end char
    cmp bl, 10               ; was it a newline?
    je .lc_next_line
    jmp .lc_done             ; was \0, end of file

.str_auto_pair: db "auto_pair", 0

.lc_not_ap:
    mov rdi, r12
    lea rsi, [.str_show_git_branch]
    call strcmp
    test rax, rax
    jnz .lc_not_sgb
    mov rdi, r14
    mov rsi, CFG_SHOW_GIT_BRANCH
    call config_set_bool
    jmp .lc_advance
.str_show_git_branch: db "show_git_branch", 0

.lc_not_sgb:
    mov rdi, r12
    lea rsi, [.str_git_status_fork]
    call strcmp
    test rax, rax
    jnz .lc_advance
    mov rdi, r14
    mov rsi, CFG_GIT_STATUS_FORK
    call config_set_bool
    jmp .lc_advance
.str_git_status_fork: db "git_status_fork", 0

.lc_skip_newline:
    inc r12
    jmp .lc_next_line

.lc_skip_line:
    ; Skip to next line
.lc_skip_to_nl:
    cmp byte [r12], 0
    je .lc_done
    cmp byte [r12], 10
    je .lc_skip_newline
    inc r12
    jmp .lc_skip_to_nl

.lc_done:
    ; Record config file mtime as our baseline
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [config_path]
    mov rsi, rsp
    syscall
    test rax, rax
    js .lc_no_stat
    mov rax, [rsp + 88]
    mov [config_save_time], rax
.lc_no_stat:
    add rsp, 144
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ── Config helpers ──────────────────────────────────────────────────

; config_add_nick: rdi = name, rsi = value
config_add_nick:
    push rbx
    push r12
    push r13
    mov r12, rdi            ; name
    mov r13, rsi            ; value
    mov rax, [nick_count]
    cmp rax, MAX_NICKS
    jge .can_done
    ; Get storage position
    lea rbx, [nick_storage]
    add rbx, [nick_storage_pos]
.can_store:
    ; Copy name
    mov [nick_names + rax*8], rbx
    mov rsi, r12
.can_copy_name:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .can_name_done
    inc rsi
    inc rbx
    jmp .can_copy_name
.can_name_done:
    inc rbx                 ; past null
    ; Copy value
    mov rax, [nick_count]
    mov [nick_values + rax*8], rbx
    mov rsi, r13
.can_copy_val:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .can_val_done
    inc rsi
    inc rbx
    jmp .can_copy_val
.can_val_done:
    ; Update storage position
    inc rbx                  ; past null
    lea rax, [rbx]
    sub rax, nick_storage
    mov [nick_storage_pos], rax
    inc qword [nick_count]
.can_done:
    pop r13
    pop r12
    pop rbx
    ret

; config_add_gnick: rdi = name, rsi = value
config_add_gnick:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    mov rax, [gnick_count]
    cmp rax, MAX_GNICKS
    jge .cag_done
    lea rbx, [gnick_storage]
    add rbx, [gnick_storage_pos]
.cag_store:
    mov rax, [gnick_count]
    mov [gnick_names + rax*8], rbx
    mov rsi, r12
.cag_copy_name:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .cag_name_done
    inc rsi
    inc rbx
    jmp .cag_copy_name
.cag_name_done:
    inc rbx
    mov rax, [gnick_count]
    mov [gnick_values + rax*8], rbx
    mov rsi, r13
.cag_copy_val:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .cag_val_done
    inc rsi
    inc rbx
    jmp .cag_copy_val
.cag_val_done:
    inc rbx
    lea rax, [rbx]
    sub rax, gnick_storage
    mov [gnick_storage_pos], rax
    inc qword [gnick_count]
.cag_done:
    pop r13
    pop r12
    pop rbx
    ret

; config_add_abbrev: rdi = name, rsi = value
config_add_abbrev:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    mov rax, [abbrev_count]
    cmp rax, MAX_ABBREVS
    jge .cab_done
    lea rbx, [abbrev_storage]
    add rbx, [abbrev_storage_pos]
.cab_store:
    mov rax, [abbrev_count]
    mov [abbrev_names + rax*8], rbx
    mov rsi, r12
.cab_copy_name:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .cab_name_done
    inc rsi
    inc rbx
    jmp .cab_copy_name
.cab_name_done:
    inc rbx
    mov rax, [abbrev_count]
    mov [abbrev_values + rax*8], rbx
    mov rsi, r13
.cab_copy_val:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .cab_val_done
    inc rsi
    inc rbx
    jmp .cab_copy_val
.cab_val_done:
    inc rbx
    lea rax, [rbx]
    sub rax, abbrev_storage
    mov [abbrev_storage_pos], rax
    inc qword [abbrev_count]
.cab_done:
    pop r13
    pop r12
    pop rbx
    ret

; config_add_bookmark: rdi = name, rsi = value (path [#tag1 #tag2])
config_add_bookmark:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi            ; name
    mov r13, rsi            ; value (path + optional tags)
    mov rax, [bm_count]
    cmp rax, MAX_BOOKMARKS
    jge .cabm_done

    lea rbx, [bm_storage]
    mov rcx, rax
    test rcx, rcx
    jz .cabm_store
    ; Find end of storage (after last tag string or path)
    mov rdi, [bm_paths + rcx*8 - 8]
    call strlen
    add rdi, rax
    inc rdi
    ; Check if there's a tag string too
    mov rsi, [bm_tags + rcx*8 - 8]
    test rsi, rsi
    jz .cabm_use_path_end
    mov rdi, rsi
    call strlen
    add rdi, rax
    inc rdi
.cabm_use_path_end:
    mov rbx, rdi
.cabm_store:
    mov rax, [bm_count]
    ; Copy name
    mov [bm_names + rax*8], rbx
    mov rsi, r12
.cabm_cn:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .cabm_cn_done
    inc rsi
    inc rbx
    jmp .cabm_cn
.cabm_cn_done:
    inc rbx

    ; Parse value: path is before first #, tags after
    mov rax, [bm_count]
    mov [bm_paths + rax*8], rbx
    mov rsi, r13
    mov qword [bm_tags + rax*8], 0
.cabm_cp:
    mov cl, [rsi]
    test cl, cl
    jz .cabm_path_done
    cmp cl, '#'
    je .cabm_tags_start
    mov [rbx], cl
    inc rsi
    inc rbx
    jmp .cabm_cp
.cabm_tags_start:
    ; Trim trailing space from path
    dec rbx
    cmp byte [rbx], ' '
    jne .cabm_no_trim_path
    mov byte [rbx], 0
    inc rbx
    jmp .cabm_save_tags
.cabm_no_trim_path:
    inc rbx
    mov byte [rbx], 0
    inc rbx
.cabm_save_tags:
    ; Copy tags
    mov rax, [bm_count]
    mov [bm_tags + rax*8], rbx
.cabm_ct:
    mov cl, [rsi]
    mov [rbx], cl
    test cl, cl
    jz .cabm_tags_done
    inc rsi
    inc rbx
    jmp .cabm_ct
.cabm_tags_done:
    inc rbx
    jmp .cabm_inc
.cabm_path_done:
    mov byte [rbx], 0
    inc rbx
.cabm_inc:
    inc qword [bm_count]
.cabm_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; config_set_color: rdi = color name (after "c_"), rsi = value string
; config_set_color: rdi = color name (after "c_"), rsi = value string
; Table-driven: searches color_name_table for match
config_set_color:
    push rbx
    push r12
    push r13
    mov r12, rsi            ; value string
    mov r13, rdi            ; color name

    ; Search color_name_table for matching name
    xor rbx, rbx
.cs_search:
    cmp rbx, NUM_COLORS
    jge .cs_done
    push rbx
    mov rdi, r13
    mov rsi, [color_name_table + rbx*8]
    call strcmp
    pop rbx
    test rax, rax
    jz .cs_found
    inc rbx
    jmp .cs_search

.cs_found:
    ; rbx = color index, r12 = value string
    mov rdi, r12
    call parse_int
    mov byte [color_settings + rbx], al
.cs_done:
    pop r13
    pop r12
    pop rbx
    ret

; config_set_bool: rdi = value string ("true"/"false"), rsi = bit index
config_set_bool:
    cmp byte [rdi], 't'
    je .csb_true
    cmp byte [rdi], '1'
    je .csb_true
    ; false: clear bit
    mov rcx, rsi
    mov rax, 1
    shl rax, cl
    not rax
    and [config_flags], rax
    ret
.csb_true:
    mov rcx, rsi
    mov rax, 1
    shl rax, cl
    or [config_flags], rax
    ret

; parse_int: rdi = string, returns rax = integer
parse_int:
    xor rax, rax
    xor rcx, rcx
.pi_loop:
    movzx ecx, byte [rdi]
    test cl, cl
    jz .pi_done
    sub cl, '0'
    js .pi_done
    cmp cl, 9
    ja .pi_done
    imul rax, 10
    add rax, rcx
    inc rdi
    jmp .pi_loop
.pi_done:
    ret

; ══════════════════════════════════════════════════════════════════════
; Dynamic prompt: user@host: ~/cwd (git-branch) >
; ══════════════════════════════════════════════════════════════════════
print_prompt_dynamic:
    push rbx
    push r12

    ; Get terminal width
    sub rsp, 8
    mov rax, SYS_IOCTL
    mov rdi, 1              ; stdout
    mov rsi, TIOCGWINSZ
    lea rdx, [rsp]
    syscall
    movzx eax, word [rsp + 2]  ; ws_col
    test eax, eax
    jnz .ppd_got_width
    mov eax, 80
.ppd_got_width:
    mov [term_width], rax
    add rsp, 8

    ; Set window title: bare: /cwd
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ppd_osc]
    mov rdx, 4
    syscall
    ; Write cwd
    lea rdi, [cwd_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [cwd_buf]
    syscall
    ; Write BEL to end OSC
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ppd_bel]
    mov rdx, 1
    syscall

    ; Emit OSC 7 (cwd) so terminal can track working directory
    ; Format: ESC]7;file://hostname/path ESC backslash
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ppd_osc7]
    mov rdx, .ppd_osc7_len
    syscall
    lea rdi, [hostname_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hostname_buf]
    syscall
    lea rdi, [cwd_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [cwd_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ppd_st]
    mov rdx, 2
    syscall

    ; Print username with color (use root colors if UID=0)
    mov rax, SYS_GETUID
    syscall
    test eax, eax
    jnz .ppd_not_root
    movzx eax, byte [color_settings + C_USER_ROOT]
    jmp .ppd_user_color
.ppd_not_root:
    movzx eax, byte [color_settings + C_USER]
.ppd_user_color:
    lea rdi, [tmp_buf]
    call write_fg_color
    mov r12, rax            ; length of color escape
    ; Write color + username
    lea rdi, [username_buf]
    call strlen
    mov rcx, rax
    ; Copy username after color escape
    lea rsi, [username_buf]
    lea rdi, [tmp_buf + r12]
    mov rdx, rcx
.ppd_copy_user:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rdx
    jnz .ppd_copy_user
    add r12, rcx

    ; @
    mov byte [tmp_buf + r12], '@'
    inc r12

    ; hostname with color (root check cached from username)
    mov rax, SYS_GETUID
    syscall
    test eax, eax
    jnz .ppd_host_not_root
    movzx eax, byte [color_settings + C_HOST_ROOT]
    jmp .ppd_host_color
.ppd_host_not_root:
    movzx eax, byte [color_settings + C_HOST]
.ppd_host_color:
    lea rdi, [tmp_buf + r12]
    call write_fg_color
    add r12, rax
    lea rsi, [hostname_buf]
    lea rdi, [tmp_buf + r12]
.ppd_copy_host:
    mov al, [rsi]
    test al, al
    jz .ppd_host_done
    mov [rdi], al
    inc rsi
    inc rdi
    inc r12
    jmp .ppd_copy_host
.ppd_host_done:

    ; Reset + ": "
    lea rdi, [tmp_buf + r12]
    mov dword [rdi], 0x5b1b     ; ESC [
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add r12, 4
    mov word [tmp_buf + r12], ': '
    add r12, 2

    ; CWD with tilde substitution and color
    movzx eax, byte [color_settings + C_CWD]
    lea rdi, [tmp_buf + r12]
    call write_fg_color
    add r12, rax

    ; Check if cwd starts with HOME for tilde substitution
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .ppd_no_tilde
    mov rsi, rax            ; HOME
    lea rdi, [cwd_buf]
    ; Compare HOME prefix
.ppd_cmp_home:
    mov cl, [rsi]
    test cl, cl
    jz .ppd_home_match
    cmp cl, [rdi]
    jne .ppd_no_tilde
    inc rsi
    inc rdi
    jmp .ppd_cmp_home
.ppd_home_match:
    ; cwd starts with HOME, replace with ~
    mov byte [tmp_buf + r12], '~'
    inc r12
    ; Copy rest of cwd after HOME prefix
.ppd_copy_cwd_rest:
    mov al, [rdi]
    test al, al
    jz .ppd_cwd_done
    mov [tmp_buf + r12], al
    inc rdi
    inc r12
    jmp .ppd_copy_cwd_rest

.ppd_no_tilde:
    ; Copy full cwd
    lea rsi, [cwd_buf]
.ppd_copy_full_cwd:
    mov al, [rsi]
    test al, al
    jz .ppd_cwd_done
    mov [tmp_buf + r12], al
    inc rsi
    inc r12
    jmp .ppd_copy_full_cwd
.ppd_cwd_done:
    ; Add trailing / to indicate directory
    cmp r12, 1
    jle .ppd_skip_slash       ; don't add to bare "/" root
    cmp byte [tmp_buf + r12 - 1], '/'
    je .ppd_skip_slash        ; already has slash
    mov byte [tmp_buf + r12], '/'
    inc r12
.ppd_skip_slash:

    ; Try to detect git branch
    call detect_git_branch
    test rax, rax
    jz .ppd_no_git

    ; Git indicator: " (branch)" or just dirty marker
    ; Reset color first
    lea rdi, [tmp_buf + r12]
    mov dword [rdi], 0x5b1b
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add r12, 4
    mov byte [tmp_buf + r12], ' '
    inc r12

    ; Check if branch name should be shown
    test qword [config_flags], (1 << CFG_SHOW_GIT_BRANCH)
    jz .ppd_git_dirty_only

    ; Show "(branch)" with color
    mov byte [tmp_buf + r12], '('
    inc r12
    movzx eax, byte [color_settings + C_GIT]
    lea rdi, [tmp_buf + r12]
    call write_fg_color
    add r12, rax
    lea rsi, [git_branch_buf]
.ppd_copy_git:
    mov al, [rsi]
    test al, al
    jz .ppd_git_branch_done
    cmp al, 10
    je .ppd_git_branch_done
    mov [tmp_buf + r12], al
    inc rsi
    inc r12
    jmp .ppd_copy_git
.ppd_git_branch_done:
    lea rdi, [tmp_buf + r12]
    mov dword [rdi], 0x5b1b
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add r12, 4
    mov byte [tmp_buf + r12], ')'
    inc r12

.ppd_git_dirty_only:
    ; Check git dirty status: stat .git/index and compare with HEAD ref
    ; If .git/index mtime > .git/refs/heads/<branch> mtime, show red dot
    ; Otherwise show green dot
    call check_git_dirty
    test rax, rax
    jz .ppd_git_clean
    ; Dirty: red middle dot
    mov byte [tmp_buf + r12], 27
    mov byte [tmp_buf + r12 + 1], '['
    mov byte [tmp_buf + r12 + 2], '3'
    mov byte [tmp_buf + r12 + 3], '1'
    mov byte [tmp_buf + r12 + 4], 'm'
    add r12, 5
    mov byte [tmp_buf + r12], 0xC2
    mov byte [tmp_buf + r12 + 1], 0xB7
    add r12, 2
    jmp .ppd_git_reset
.ppd_git_clean:
    ; Clean: green middle dot
    mov byte [tmp_buf + r12], 27
    mov byte [tmp_buf + r12 + 1], '['
    mov byte [tmp_buf + r12 + 2], '3'
    mov byte [tmp_buf + r12 + 3], '2'
    mov byte [tmp_buf + r12 + 4], 'm'
    add r12, 5
    mov byte [tmp_buf + r12], 0xC2
    mov byte [tmp_buf + r12 + 1], 0xB7
    add r12, 2
.ppd_git_reset:
    lea rdi, [tmp_buf + r12]
    mov dword [rdi], 0x5b1b
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add r12, 4

.ppd_no_git:
    ; Reset + " > "
    lea rdi, [tmp_buf + r12]
    mov dword [rdi], 0x5b1b
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add r12, 4
    mov byte [tmp_buf + r12], ' '
    inc r12
    ; Prompt char with color
    movzx eax, byte [color_settings + C_PROMPT]
    lea rdi, [tmp_buf + r12]
    call write_fg_color
    add r12, rax
    mov byte [tmp_buf + r12], '>'
    inc r12
    ; Reset
    lea rdi, [tmp_buf + r12]
    mov dword [rdi], 0x5b1b
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add r12, 4
    mov byte [tmp_buf + r12], ' '
    inc r12

    ; Calculate visible prompt width (scan tmp_buf, skip ANSI escapes)
    xor rbx, rbx            ; visible char count
    xor rcx, rcx            ; position in buffer
.ppd_vis_count:
    cmp rcx, r12
    jge .ppd_vis_done
    movzx eax, byte [tmp_buf + rcx]
    cmp al, 27                ; ESC
    je .ppd_skip_esc
    ; Skip UTF-8 continuation bytes (10xxxxxx = 0x80-0xBF)
    cmp al, 0x80
    jb .ppd_vis_ascii
    cmp al, 0xBF
    jbe .ppd_vis_cont         ; continuation byte, don't count
.ppd_vis_ascii:
    inc rbx                   ; count as 1 visible character
.ppd_vis_cont:
    inc rcx
    jmp .ppd_vis_count
.ppd_skip_esc:
    inc rcx                  ; skip ESC
.ppd_skip_esc_inner:
    cmp rcx, r12
    jge .ppd_vis_done
    movzx eax, byte [tmp_buf + rcx]
    inc rcx
    ; ESC sequences end at a letter (A-Z, a-z) but not [
    cmp al, '['
    je .ppd_skip_esc_inner
    cmp al, ';'
    je .ppd_skip_esc_inner
    cmp al, '0'
    jl .ppd_esc_end
    cmp al, '9'
    jle .ppd_skip_esc_inner
.ppd_esc_end:
    jmp .ppd_vis_count
.ppd_vis_done:
    mov [prompt_visible_width], rbx

    ; Write or buffer the prompt
    cmp qword [render_to_buf], 0
    jne .ppd_to_buf
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [tmp_buf]
    mov rdx, r12
    syscall
    jmp .ppd_write_done
.ppd_to_buf:
    ; Copy prompt from tmp_buf into render_buf
    lea rsi, [tmp_buf]
    mov rcx, r12
    mov rdi, [render_pos]
    lea rdi, [render_buf + rdi]
    xor rax, rax
.ppd_buf_copy:
    cmp rax, rcx
    jge .ppd_buf_done
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .ppd_buf_copy
.ppd_buf_done:
    add [render_pos], rcx
.ppd_write_done:

    pop r12
    pop rbx
    ret

.ppd_osc: db 27, "]2;"         ; OSC set title
.ppd_bel: db 7                  ; BEL (end OSC)
.ppd_osc7: db 27, "]7;file://" ; OSC 7 cwd notification
.ppd_osc7_len equ $ - .ppd_osc7
.ppd_st: db 27, "\"            ; ST (string terminator)

; write_fg_color: al = 256-color code, rdi = buffer
; Returns: rax = bytes written
; Writes ESC[38;5;XXXm
; write_fg_color: eax = 256-color code, rdi = buffer
; Returns: rax = bytes written
; Writes ESC[38;5;XXXm
write_fg_color:
    push rbx
    push r12
    mov rbx, rdi
    movzx r12d, al          ; save color code
    mov byte [rdi], 27
    mov byte [rdi+1], '['
    mov byte [rdi+2], '3'
    mov byte [rdi+3], '8'
    mov byte [rdi+4], ';'
    mov byte [rdi+5], '5'
    mov byte [rdi+6], ';'
    lea rdi, [rbx + 7]
    mov rax, r12
    call itoa
    add rax, 7
    mov byte [rbx + rax], 'm'
    inc rax
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Detect git branch by reading .git/HEAD
; Returns: rax = 1 if found (branch in git_branch_buf), 0 if not
; ══════════════════════════════════════════════════════════════════════
detect_git_branch:
    push rbx
    push r12
    push r13

    ; Try current dir and up to 10 parents
    lea r12, [cwd_buf]
    mov r13, 10

.dgb_try:
    ; Build path: cwd + /.git/HEAD
    lea rdi, [git_head_buf]
    mov rsi, r12
    call strcpy_rsi_rdi
.dgb_append_git:
    lea rsi, [git_head_file]
    call strcpy_rsi_rdi

.dgb_try_open:
    mov rax, SYS_OPEN
    lea rdi, [git_head_buf]
    xor esi, esi
    xor edx, edx
    syscall
    test rax, rax
    jns .dgb_found_file

    ; Go up one directory
    dec r13
    jz .dgb_not_found

    ; Find last / in path and truncate
    lea rdi, [git_head_buf]
    ; Actually, we need to modify the path we're checking
    ; Find last / in current search path
    mov rsi, r12
    call strlen
    add rsi, rax
    dec rsi
.dgb_find_slash:
    cmp rsi, r12
    jle .dgb_not_found
    cmp byte [rsi], '/'
    je .dgb_truncate
    dec rsi
    jmp .dgb_find_slash
.dgb_truncate:
    ; Copy truncated path to git_head_buf temporarily
    mov rcx, rsi
    sub rcx, r12
    test rcx, rcx
    jz .dgb_not_found
    lea rdi, [git_head_buf]
    mov rsi, r12
    rep movsb
    mov byte [rdi], 0
    lea r12, [git_head_buf]
    jmp .dgb_try

.dgb_found_file:
    ; Save git root path (r12 points to the dir containing .git)
    push rax
    ; Save git root: git_head_buf has "<root>/.git/HEAD"
    ; Copy to git_root_buf, then strip "/.git/HEAD" (10 chars)
    lea rdi, [git_root_buf]
    lea rsi, [git_head_buf]
    call strcpy_rsi_rdi
    ; Strip /.git/HEAD from end (10 chars)
    sub rax, 10
    test rax, rax
    js .dgb_root_ok
    mov byte [git_root_buf + rax], 0
.dgb_root_ok:
    pop rax
    mov rbx, rax            ; fd
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [git_branch_buf]
    mov rdx, 126
    syscall
    push rax
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax
    test rax, rax
    jle .dgb_not_found

    mov byte [git_branch_buf + rax], 0

    ; Check if it starts with "ref: refs/heads/"
    lea rsi, [git_branch_buf]
    lea rdi, [git_head_prefix]
.dgb_cmp_prefix:
    mov cl, [rdi]
    test cl, cl
    jz .dgb_prefix_match
    cmp cl, [rsi]
    jne .dgb_detached
    inc rsi
    inc rdi
    jmp .dgb_cmp_prefix

.dgb_prefix_match:
    ; rsi points to branch name, copy to start of git_branch_buf
    lea rdi, [git_branch_buf]
.dgb_copy_branch:
    mov al, [rsi]
    test al, al
    jz .dgb_branch_done
    cmp al, 10
    je .dgb_branch_done
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .dgb_copy_branch
.dgb_branch_done:
    mov byte [rdi], 0
    mov rax, 1
    pop r13
    pop r12
    pop rbx
    ret

.dgb_detached:
    ; Detached HEAD, show first 8 chars of hash
    lea rsi, [git_branch_buf]
    mov byte [rsi + 8], 0
    mov rax, 1
    pop r13
    pop r12
    pop rbx
    ret

.dgb_not_found:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Nick expansion: check if argv[0] matches a nick, expand if so
; rdi = pointer to argv array (e.g., expanded_argv or argv_ptrs)
; Modifies the line_buf with expanded command before re-parsing
; Returns: rax = 1 if expanded, 0 if not
; ══════════════════════════════════════════════════════════════════════
expand_nicks:
    push rbx
    push r12
    push r13

    mov r12, rdi            ; argv array
    mov rdi, [r12]          ; argv[0]
    test rdi, rdi
    jz .en_no

    ; Search nick_names
    xor rcx, rcx
.en_search:
    cmp rcx, [nick_count]
    jge .en_no
    push rcx
    mov rsi, [nick_names + rcx*8]
    call strcmp
    pop rcx
    test rax, rax
    jz .en_found
    mov rdi, [r12]          ; restore rdi for next compare
    inc rcx
    jmp .en_search

.en_found:
    ; No guard needed: the caller (parse_and_exec_simple) already
    ; skips nick expansion on the re-parsed result, preventing recursion.
    ; Build expanded line: nick_value + rest of original args
    lea rdi, [nick_expand_buf]
    mov rsi, [nick_values + rcx*8]
    ; Copy nick expansion
    call strcpy_rsi_rdi
    ; Append remaining args from argv[1..]
    mov rcx, 1
.en_append_args:
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .en_apply
    mov byte [rdi], ' '
    inc rdi
.en_copy_arg:
    mov al, [rsi]
    test al, al
    jz .en_arg_done
    ; Re-escape spaces with backslash
    cmp al, ' '
    jne .en_no_esc
    mov byte [rdi], '\'
    inc rdi
.en_no_esc:
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .en_copy_arg
.en_arg_done:
    inc rcx
    jmp .en_append_args

.en_apply:
    mov byte [rdi], 0
    ; Copy expanded line back to line_buf
    lea rsi, [nick_expand_buf]
    lea rdi, [line_buf]
    call strcpy_rsi_rdi
    mov [line_len], rax
    mov rax, 1
    pop r13
    pop r12
    pop rbx
    ret

.en_no:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Colon command handlers
; ══════════════════════════════════════════════════════════════════════

; :nick [name = value | -name]
handle_nick:
    push rbx
    push r12
    mov r12, rdi            ; argv array

    ; No args: list all nicks
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hn_list

    ; Check for -name (delete)
    cmp byte [rdi], '-'
    je .hn_delete

    ; Otherwise: name = value
    ; Find '=' in remaining args
    ; Reconstruct: argv[1] = name, argv[2] = "=", argv[3..] = value
    mov rdi, [r12 + 8]      ; name
    mov rsi, [r12 + 16]     ; should be "="
    test rsi, rsi
    jz .hn_error
    cmp byte [rsi], '='
    jne .hn_error
    mov rsi, [r12 + 24]     ; value start
    test rsi, rsi
    jz .hn_error

    ; Build the full value from argv[3..]
    push rdi                ; save name
    lea rbx, [nick_expand_buf]
    mov rcx, 3
.hn_build_val:
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .hn_val_built
    cmp rcx, 3
    je .hn_no_space
    mov byte [rbx], ' '
    inc rbx
.hn_no_space:
    ; Copy arg
.hn_copy_varg:
    mov al, [rsi]
    test al, al
    jz .hn_varg_done
    mov [rbx], al
    inc rsi
    inc rbx
    jmp .hn_copy_varg
.hn_varg_done:
    inc rcx
    jmp .hn_build_val
.hn_val_built:
    mov byte [rbx], 0
    pop rdi                 ; name
    lea rsi, [nick_expand_buf]
    call config_add_nick
    jmp .hn_done

.hn_delete:
    ; Delete nick by name (skip the '-')
    lea rdi, [rdi + 1]
    xor rcx, rcx
.hn_del_search:
    cmp rcx, [nick_count]
    jge .hn_done
    push rcx
    mov rsi, [nick_names + rcx*8]
    call strcmp
    pop rcx
    test rax, rax
    jz .hn_del_found
    mov rdi, [r12 + 8]
    inc rdi                 ; skip '-'
    inc rcx
    jmp .hn_del_search
.hn_del_found:
    ; Shift remaining entries down
    mov rdx, [nick_count]
    dec rdx
    mov [nick_count], rdx
.hn_del_shift:
    cmp rcx, rdx
    jge .hn_done
    mov rax, [nick_names + rcx*8 + 8]
    mov [nick_names + rcx*8], rax
    mov rax, [nick_values + rcx*8 + 8]
    mov [nick_values + rcx*8], rax
    inc rcx
    jmp .hn_del_shift

.hn_list:
    xor rcx, rcx
.hn_list_loop:
    cmp rcx, [nick_count]
    jge .hn_done
    push rcx
    ; Print name
    mov rsi, [nick_names + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [nick_names + rcx*8]
    syscall
    ; Print " = "
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    ; Print value
    mov rcx, [rsp]
    mov rsi, [nick_values + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [nick_values + rcx*8]
    syscall
    ; Newline
    call write_nl
    pop rcx
    inc rcx
    jmp .hn_list_loop

.hn_error:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_nick]
    mov rdx, err_nick_len
    syscall
.hn_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

; :gnick handler (same structure as :nick but uses gnick arrays)
handle_gnick:
    push rbx
    push r12
    mov r12, rdi

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hg_list

    cmp byte [rdi], '-'
    je .hg_delete

    ; name = value
    mov rdi, [r12 + 8]
    mov rsi, [r12 + 16]
    test rsi, rsi
    jz .hg_done
    cmp byte [rsi], '='
    jne .hg_done
    mov rsi, [r12 + 24]
    test rsi, rsi
    jz .hg_done
    push rdi
    lea rbx, [nick_expand_buf]
    mov rcx, 3
.hg_build_val:
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .hg_val_built
    cmp rcx, 3
    je .hg_no_space
    mov byte [rbx], ' '
    inc rbx
.hg_no_space:
.hg_copy_varg:
    mov al, [rsi]
    test al, al
    jz .hg_varg_done
    mov [rbx], al
    inc rsi
    inc rbx
    jmp .hg_copy_varg
.hg_varg_done:
    inc rcx
    jmp .hg_build_val
.hg_val_built:
    mov byte [rbx], 0
    pop rdi
    lea rsi, [nick_expand_buf]
    call config_add_gnick
    jmp .hg_done

.hg_delete:
    lea rdi, [rdi + 1]
    xor rcx, rcx
.hg_del_search:
    cmp rcx, [gnick_count]
    jge .hg_done
    push rcx
    mov rsi, [gnick_names + rcx*8]
    call strcmp
    pop rcx
    test rax, rax
    jz .hg_del_found
    mov rdi, [r12 + 8]
    inc rdi
    inc rcx
    jmp .hg_del_search
.hg_del_found:
    mov rdx, [gnick_count]
    dec rdx
    mov [gnick_count], rdx
.hg_del_shift:
    cmp rcx, rdx
    jge .hg_done
    mov rax, [gnick_names + rcx*8 + 8]
    mov [gnick_names + rcx*8], rax
    mov rax, [gnick_values + rcx*8 + 8]
    mov [gnick_values + rcx*8], rax
    inc rcx
    jmp .hg_del_shift

.hg_list:
    xor rcx, rcx
.hg_list_loop:
    cmp rcx, [gnick_count]
    jge .hg_done
    push rcx
    mov rsi, [gnick_names + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [gnick_names + rcx*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rcx, [rsp]
    mov rsi, [gnick_values + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [gnick_values + rcx*8]
    syscall
    call write_nl
    pop rcx
    inc rcx
    jmp .hg_list_loop

.hg_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

; :version
; :abbrev handler (same structure as :nick but uses abbrev arrays)
handle_abbrev:
    push rbx
    push r12
    mov r12, rdi

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hab_list

    cmp byte [rdi], '-'
    je .hab_delete

    ; name = value
    mov rdi, [r12 + 8]
    mov rsi, [r12 + 16]
    test rsi, rsi
    jz .hab_error
    cmp byte [rsi], '='
    jne .hab_error
    mov rsi, [r12 + 24]
    test rsi, rsi
    jz .hab_error
    push rdi
    lea rbx, [nick_expand_buf]
    mov rcx, 3
.hab_build_val:
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .hab_val_built
    cmp rcx, 3
    je .hab_no_space
    mov byte [rbx], ' '
    inc rbx
.hab_no_space:
.hab_copy_varg:
    mov al, [rsi]
    test al, al
    jz .hab_varg_done
    mov [rbx], al
    inc rsi
    inc rbx
    jmp .hab_copy_varg
.hab_varg_done:
    inc rcx
    jmp .hab_build_val
.hab_val_built:
    mov byte [rbx], 0
    pop rdi
    lea rsi, [nick_expand_buf]
    call config_add_abbrev
    jmp .hab_done

.hab_delete:
    lea rdi, [rdi + 1]
    xor rcx, rcx
.hab_del_search:
    cmp rcx, [abbrev_count]
    jge .hab_done
    push rcx
    mov rsi, [abbrev_names + rcx*8]
    call strcmp
    pop rcx
    test rax, rax
    jz .hab_del_found
    mov rdi, [r12 + 8]
    inc rdi
    inc rcx
    jmp .hab_del_search
.hab_del_found:
    mov rdx, [abbrev_count]
    dec rdx
    mov [abbrev_count], rdx
.hab_del_shift:
    cmp rcx, rdx
    jge .hab_done
    mov rax, [abbrev_names + rcx*8 + 8]
    mov [abbrev_names + rcx*8], rax
    mov rax, [abbrev_values + rcx*8 + 8]
    mov [abbrev_values + rcx*8], rax
    inc rcx
    jmp .hab_del_shift

.hab_list:
    xor rcx, rcx
.hab_list_loop:
    cmp rcx, [abbrev_count]
    jge .hab_done
    push rcx
    mov rsi, [abbrev_names + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [abbrev_names + rcx*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rcx, [rsp]
    mov rsi, [abbrev_values + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [abbrev_values + rcx*8]
    syscall
    call write_nl
    pop rcx
    inc rcx
    jmp .hab_list_loop

.hab_error:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hab_usage]
    mov rdx, .hab_usage_len
    syscall
.hab_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret
.hab_usage: db "usage: :abbrev [name = value | -name]", 10
.hab_usage_len equ $ - .hab_usage

handle_info:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [info_text]
    mov rdx, info_text_len
    syscall
    mov qword [last_status], 0
    ret

; :save
; :rehash - rebuild PATH executable cache
handle_rehash:
    call init_exe_cache
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hr_msg]
    mov rdx, .hr_msg_len
    syscall
    mov qword [last_status], 0
    ret
.hr_msg: db "PATH cache rebuilt", 10
.hr_msg_len equ $ - .hr_msg

handle_save:
    call save_config
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hs_msg]
    mov rdx, .hs_msg_len
    syscall
    mov qword [last_status], 0
    ret
.hs_msg: db "Config saved", 10
.hs_msg_len equ $ - .hs_msg

; :backup [name] - backup ~/.barerc and ~/.bare_history
; Default suffix is ".bak", with arg it's ".<name>"
handle_backup:
    push rbx
    push r12
    push r13
    mov r12, rdi             ; argv array

    ; Save config first
    call save_config
    call save_history

    ; Get suffix: argv[1] or "bak"
    mov rdi, [r12 + 8]
    test rdi, rdi
    jnz .hb_have_name
    lea rdi, [hbr_default_suffix]
.hb_have_name:
    mov r13, rdi             ; suffix

    ; Copy config: config_path -> config_path.suffix
    lea rdi, [config_path]
    lea rsi, [path_buf]
    call hbr_copy_path
    lea rdi, [path_buf]
    call hbr_append_suffix
    lea rdi, [config_path]
    lea rsi, [path_buf]
    call hbr_copy_file
    test rax, rax
    js .hb_error

    ; Copy history: hist_path -> hist_path.suffix
    lea rdi, [hist_path]
    lea rsi, [path_buf]
    call hbr_copy_path
    lea rdi, [path_buf]
    call hbr_append_suffix
    lea rdi, [hist_path]
    lea rsi, [path_buf]
    call hbr_copy_file
    test rax, rax
    js .hb_error

    ; Print success
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hb_ok_msg]
    mov rdx, hb_ok_len
    syscall
    ; Print suffix name
    mov rdi, r13
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, r13
    syscall
    call write_nl
    mov qword [last_status], 0
    jmp .hb_done
.hb_error:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hb_err_msg]
    mov rdx, hb_err_len
    syscall
    mov qword [last_status], 1
.hb_done:
    pop r13
    pop r12
    pop rbx
    ret
hbr_default_suffix: db "bak", 0
hb_ok_msg: db "Backed up to .", 0
hb_ok_len equ $ - hb_ok_msg
hb_err_msg: db "bare: backup failed", 10, 0
hb_err_len equ 20

; :restore [name] - restore ~/.barerc and ~/.bare_history from backup
handle_restore:
    push rbx
    push r12
    push r13
    mov r12, rdi             ; argv array

    ; Get suffix: argv[1] or "bak"
    mov rdi, [r12 + 8]
    test rdi, rdi
    jnz .hr_have_name
    lea rdi, [hbr_default_suffix]
.hr_have_name:
    mov r13, rdi             ; suffix

    ; Copy config: config_path.suffix -> config_path
    lea rdi, [config_path]
    lea rsi, [path_buf]
    call hbr_copy_path
    lea rdi, [path_buf]
    call hbr_append_suffix
    lea rdi, [path_buf]
    lea rsi, [config_path]
    call hbr_copy_file
    test rax, rax
    js .hr_error

    ; Copy history: hist_path.suffix -> hist_path
    lea rdi, [hist_path]
    lea rsi, [path_buf]
    call hbr_copy_path
    lea rdi, [path_buf]
    call hbr_append_suffix
    lea rdi, [path_buf]
    lea rsi, [hist_path]
    call hbr_copy_file
    test rax, rax
    js .hr_error

    ; Reload config and history
    call load_config
    call load_history

    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hr_ok_msg]
    mov rdx, .hr_ok_len
    syscall
    mov rdi, r13
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rsi, r13
    syscall
    call write_nl
    mov qword [last_status], 0
    jmp .hr_done
.hr_error:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hr_err_msg]
    mov rdx, .hr_err_len
    syscall
    mov qword [last_status], 1
.hr_done:
    pop r13
    pop r12
    pop rbx
    ret
.hr_ok_msg: db "Restored from .", 0
.hr_ok_len equ $ - .hr_ok_msg
.hr_err_msg: db "bare: restore failed (backup not found?)", 10, 0
.hr_err_len equ 41

; Helper: copy path string from [rdi] to [rsi]
hbr_copy_path:
    push rdi
    mov rdi, rsi
    mov rsi, [rsp]
    call strcpy_rsi_rdi
    pop rdi
    ret

; Helper: append ".suffix" to path at [rdi], using r13 as suffix
hbr_append_suffix:
    push rdi
    call strlen
    pop rdi
    add rdi, rax
    mov byte [rdi], '.'
    inc rdi
    mov rsi, r13
.hbr_as_copy:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .hbr_as_done
    inc rsi
    inc rdi
    jmp .hbr_as_copy
.hbr_as_done:
    ret

; Helper: copy file [rdi] -> [rsi] using read/write loop
; Returns rax=0 on success, rax=-1 on failure
hbr_copy_file:
    push rbx
    push r14
    push r15
    mov r14, rdi             ; source path
    mov r15, rsi             ; dest path

    ; Open source
    mov rax, SYS_OPEN
    mov rdi, r14
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .hbr_cf_fail
    mov rbx, rax             ; source fd

    ; Open dest (create/truncate)
    mov rax, SYS_OPEN
    mov rdi, r15
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0o644
    syscall
    test rax, rax
    js .hbr_cf_close_src
    mov r14, rax             ; dest fd

    ; Read/write loop using expand_buf
.hbr_cf_loop:
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [expand_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .hbr_cf_done

    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r14
    lea rsi, [expand_buf]
    syscall
    jmp .hbr_cf_loop

.hbr_cf_done:
    mov rax, SYS_CLOSE
    mov rdi, r14
    syscall
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    xor eax, eax
    pop r15
    pop r14
    pop rbx
    ret

.hbr_cf_close_src:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
.hbr_cf_fail:
    mov rax, -1
    pop r15
    pop r14
    pop rbx
    ret

handle_version:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [version_str]
    mov rdx, version_str_len
    syscall
    mov qword [last_status], 0
    ret

; :help
handle_help:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.help_text]
    mov rdx, .help_text_len
    syscall
    mov qword [last_status], 0
    ret
.help_text:
    db "bare shell commands:", 10
    db "  :nick [name = val | -name]      Aliases", 10
    db "  :gnick [name = val | -name]     Global aliases", 10
    db "  :abbrev [name = val | -name]    Abbreviations", 10
    db "  :bm [name [path] [#tags]]       Bookmarks (:bm ?tag to search)", 10
    db "  :dirs                           Directory history (cd N to jump)", 10
    db "  :theme [name]                   Color themes (6 built-in)", 10
    db "  :config [key [value]]           View/set config", 10
    db "  :save                           Save config now", 10
    db "  :backup [name] / :restore       Backup/restore config+history", 10
    db "  :rehash                         Rebuild PATH cache", 10
    db "  :reload                         Reload ~/.barerc", 10
    db "  :calc expr                      Calculator (+, -, *, /, %)", 10
    db "  :stats                          Command frequency stats", 10
    db "  :validate pattern = action      Safety rules (warn/confirm/block)", 10
    db "  :save_session / :load_session   Session management", 10
    db "  :jobs / :fg [N] / :bg [N]       Job control", 10
    db "  :env [VAR]                      Environment variables", 10
    db "  :info / :version / :help        Shell information", 10
    db 10
    db "  Builtins: cd, pwd, exit, export, unset, history, pushd, popd, time", 10
    db "  Expansion: ~, $VAR, $(cmd), {a,b,c}, **, !!, <<<", 10
    db 10
    db "  Ctrl-R=search  Ctrl-L=clear  Ctrl-A/E=home/end  Ctrl-C=cancel", 10
    db "  Ctrl-K=kill    Ctrl-U=clear  Ctrl-W=del-word    Ctrl-Z=suspend", 10
    db "  Ctrl-G=editor  Ctrl-Y=copy   Alt-F/B=word-jump  Ctrl-Left/Right", 10
    db 10
.help_text_len equ $ - .help_text

; :reload
handle_reload:
    call load_config
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.reload_msg]
    mov rdx, .reload_msg_len
    syscall
    mov qword [last_status], 0
    ret
.reload_msg: db "Config reloaded", 10
.reload_msg_len equ $ - .reload_msg

; :bm handler
handle_bm:
    push rbx
    push r12
    mov r12, rdi            ; argv array

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hbm_list

    ; Check for -name (delete)
    cmp byte [rdi], '-'
    je .hbm_delete

    ; Check for ?tag (search)
    cmp byte [rdi], '?'
    je .hbm_search

    ; :bm name [path] [#tags]
    mov rdi, [r12 + 8]      ; name
    mov rsi, [r12 + 16]     ; path (optional)
    test rsi, rsi
    jnz .hbm_add_with_path
    ; No path: use cwd
    lea rsi, [cwd_buf]
.hbm_add_with_path:
    call config_add_bookmark
    jmp .hbm_done

.hbm_delete:
    lea rdi, [rdi + 1]      ; skip '-'
    xor rcx, rcx
.hbm_del_search:
    cmp rcx, [bm_count]
    jge .hbm_done
    push rcx
    mov rsi, [bm_names + rcx*8]
    call strcmp
    pop rcx
    test rax, rax
    jz .hbm_del_found
    mov rdi, [r12 + 8]
    inc rdi
    inc rcx
    jmp .hbm_del_search
.hbm_del_found:
    mov rdx, [bm_count]
    dec rdx
    mov [bm_count], rdx
.hbm_del_shift:
    cmp rcx, rdx
    jge .hbm_done
    mov rax, [bm_names + rcx*8 + 8]
    mov [bm_names + rcx*8], rax
    mov rax, [bm_paths + rcx*8 + 8]
    mov [bm_paths + rcx*8], rax
    mov rax, [bm_tags + rcx*8 + 8]
    mov [bm_tags + rcx*8], rax
    inc rcx
    jmp .hbm_del_shift

.hbm_search:
    ; Search by tag
    lea rbx, [rdi + 1]      ; tag to search for (skip '?')
    xor rcx, rcx
.hbm_tag_loop:
    cmp rcx, [bm_count]
    jge .hbm_done
    mov rsi, [bm_tags + rcx*8]
    test rsi, rsi
    jz .hbm_tag_next
    ; Simple substring search for tag in tag string
    push rcx
    mov rdi, rsi
    mov rsi, rbx
    call strstr_simple
    pop rcx
    test rax, rax
    jz .hbm_tag_next
    ; Found, print it
    push rcx
    jmp .hbm_print_entry
.hbm_tag_next:
    inc rcx
    jmp .hbm_tag_loop

.hbm_list:
    xor rcx, rcx
.hbm_list_loop:
    cmp rcx, [bm_count]
    jge .hbm_done
    push rcx
.hbm_print_entry:
    ; Print name
    mov rsi, [bm_names + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [bm_names + rcx*8]
    syscall
    ; Print " -> "
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    ; Print path
    mov rcx, [rsp]
    mov rsi, [bm_paths + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [bm_paths + rcx*8]
    syscall
    ; Print tags if any
    mov rcx, [rsp]
    mov rsi, [bm_tags + rcx*8]
    test rsi, rsi
    jz .hbm_no_tags
    mov rdi, rsi
    call strlen
    test rax, rax
    jz .hbm_no_tags
    push rcx
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [space_char]
    push rdx
    mov rdx, 1
    syscall
    pop rdx
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [bm_tags + rcx*8]
    syscall
    mov rcx, [rsp]
.hbm_no_tags:
    call write_nl
    pop rcx
    inc rcx
    jmp .hbm_list_loop

.hbm_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

; Simple substring search: rdi = haystack, rsi = needle
; Returns rax = pointer to match or 0
strstr_simple:
    push rbx
    push r12
    mov rbx, rdi            ; haystack
    mov r12, rsi            ; needle
.ss_outer:
    cmp byte [rbx], 0
    je .ss_not_found
    mov rdi, rbx
    mov rsi, r12
.ss_inner:
    cmp byte [rsi], 0
    je .ss_found
    mov al, [rdi]
    test al, al
    jz .ss_not_found
    cmp al, [rsi]
    jne .ss_next
    inc rdi
    inc rsi
    jmp .ss_inner
.ss_next:
    inc rbx
    jmp .ss_outer
.ss_found:
    mov rax, rbx
    pop r12
    pop rbx
    ret
.ss_not_found:
    xor eax, eax
    pop r12
    pop rbx
    ret

; :dirs handler
handle_dirs:
    xor rcx, rcx
.hd_loop:
    cmp rcx, [dir_hist_count]
    jge .hd_done
    push rcx
    ; Print index
    mov rax, rcx
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [space_char]
    mov rdx, 1
    syscall
    ; Print path
    mov rcx, [rsp]
    mov rsi, [dir_history + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [dir_history + rcx*8]
    syscall
    call write_nl
    pop rcx
    inc rcx
    jmp .hd_loop
.hd_done:
    mov qword [last_status], 0
    ret

; :rmhistory handler
handle_rmhistory:
    mov qword [hist_count], 0
    mov qword [hist_pos], 0
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rmh_msg]
    mov rdx, .rmh_msg_len
    syscall
    mov qword [last_status], 0
    ret
.rmh_msg: db "History cleared", 10
.rmh_msg_len equ $ - .rmh_msg

; pushd handler
handle_pushd:
    push r12
    mov r12, rdi            ; argv array

    ; Push current dir onto stack
    mov rax, [dir_stack_count]
    cmp rax, 32
    jge .hpd_full
    ; Store cwd
    lea rdi, [cwd_buf]
    call strlen
    ; Copy cwd to dir_stack_storage
    lea rsi, [cwd_buf]
    ; Find end of storage
    lea rdi, [dir_stack_storage]
    mov rcx, [dir_stack_count]
    test rcx, rcx
    jz .hpd_store
    mov rdi, [dir_stack + rcx*8 - 8]
    call strlen
    add rdi, rax
    inc rdi
.hpd_store:
    mov rax, [dir_stack_count]
    mov [dir_stack + rax*8], rdi
    lea rsi, [cwd_buf]
.hpd_copy:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .hpd_stored
    inc rsi
    inc rdi
    jmp .hpd_copy
.hpd_stored:
    inc qword [dir_stack_count]

    ; cd to argument (or HOME if none)
    mov rdi, [r12 + 8]
    test rdi, rdi
    jnz .hpd_cd
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .hpd_done
    mov rdi, rax
.hpd_cd:
    mov rax, SYS_CHDIR
    syscall
    test rax, rax
    js .hpd_err
    call update_cwd
    call add_dir_history
    ; Print new dir
    lea rdi, [cwd_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [cwd_buf]
    syscall
    call write_nl
    mov qword [last_status], 0
    jmp .hpd_done
.hpd_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_cd]
    mov rdx, err_cd_len
    syscall
    mov qword [last_status], 1
    jmp .hpd_done
.hpd_full:
    ; Stack full, just cd
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hpd_done
    mov rax, SYS_CHDIR
    syscall
    call update_cwd
.hpd_done:
    pop r12
    ret

; popd handler
handle_popd:
    mov rax, [dir_stack_count]
    test rax, rax
    jz .hpopd_empty
    dec rax
    mov [dir_stack_count], rax
    mov rdi, [dir_stack + rax*8]
    mov rax, SYS_CHDIR
    syscall
    test rax, rax
    js .hpopd_err
    call update_cwd
    call add_dir_history
    lea rdi, [cwd_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [cwd_buf]
    syscall
    call write_nl
    mov qword [last_status], 0
    ret
.hpopd_empty:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.popd_empty_msg]
    mov rdx, .popd_empty_len
    syscall
    mov qword [last_status], 1
    ret
.popd_empty_msg: db "bare: popd: directory stack empty", 10
.popd_empty_len equ $ - .popd_empty_msg
.hpopd_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_cd]
    mov rdx, err_cd_len
    syscall
    mov qword [last_status], 1
    ret

; Add to directory history (called on cd)
add_dir_history:
    push rbx
    push r12

    ; Check if storage has room (leave 256 bytes margin)
    mov rax, [dir_hist_pos]
    cmp rax, 7936
    jge .adh_done            ; storage full, skip

    mov rax, [dir_hist_count]
    cmp rax, MAX_DIR_HISTORY
    jl .adh_ok
    ; Full: shift pointers down, reuse storage (don't reclaim, just drop oldest pointer)
    xor rcx, rcx
.adh_shift:
    mov rdx, rcx
    inc rdx
    cmp rdx, MAX_DIR_HISTORY
    jge .adh_shifted
    mov rbx, [dir_history + rdx*8]
    mov [dir_history + rcx*8], rbx
    inc rcx
    jmp .adh_shift
.adh_shifted:
    dec qword [dir_hist_count]
    mov rax, [dir_hist_count]
.adh_ok:
    ; Store cwd at current storage position
    lea rdi, [dir_hist_storage]
    add rdi, [dir_hist_pos]
    mov [dir_history + rax*8], rdi
    lea rsi, [cwd_buf]
    xor r12, r12             ; byte counter
.adh_copy:
    mov cl, [rsi]
    mov [rdi], cl
    inc r12
    test cl, cl
    jz .adh_stored
    inc rsi
    inc rdi
    jmp .adh_copy
.adh_stored:
    add [dir_hist_pos], r12  ; advance position past string + null
    inc qword [dir_hist_count]
.adh_done:
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Find history entry matching search_buf (substring match, reverse order)
; Skips rs_skip_count matches for Ctrl-R cycling
; Returns: rax = pointer to matching history string, or 0
; ══════════════════════════════════════════════════════════════════════
find_reverse_match:
    push rbx
    push r12
    push r13

    mov rax, [search_len]
    test rax, rax
    jz .frm_none             ; empty search, no match

    mov r12, [hist_count]
    dec r12                  ; start from most recent
    xor r13, r13             ; matches skipped so far

.frm_loop:
    test r12, r12
    js .frm_none             ; exhausted history

    mov rdi, [hist_lines + r12*8]
    test rdi, rdi
    jz .frm_next

    ; Substring search: search_buf in hist_lines[r12]
    lea rsi, [search_buf]
    call strstr_simple
    test rax, rax
    jz .frm_next

    ; Found a match, check if we should skip it
    cmp r13, [rs_skip_count]
    jge .frm_found
    inc r13
.frm_next:
    dec r12
    jmp .frm_loop

.frm_found:
    mov rax, [hist_lines + r12*8]
    pop r13
    pop r12
    pop rbx
    ret

.frm_none:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Find history suggestion for current line_buf (prefix match)
; Returns: rax = pointer to remainder (past the prefix), rdx = length
;          or rax = 0 if no match
; ══════════════════════════════════════════════════════════════════════
find_history_suggestion:
    push rbx
    push r12
    push r13

    mov r12, [line_len]
    test r12, r12
    jz .fhs_none             ; empty line, no suggestion

    ; Search history from most recent backwards
    mov r13, [hist_count]
    dec r13

.fhs_loop:
    test r13, r13
    js .fhs_none

    mov rdi, [hist_lines + r13*8]
    test rdi, rdi
    jz .fhs_next

    ; Check if this entry starts with line_buf content
    lea rsi, [line_buf]
    xor rcx, rcx
.fhs_prefix_cmp:
    cmp rcx, r12
    jge .fhs_prefix_match
    movzx eax, byte [rsi + rcx]
    cmp al, [rdi + rcx]
    jne .fhs_next
    inc rcx
    jmp .fhs_prefix_cmp

.fhs_prefix_match:
    ; Match found - check it's not identical to current input
    cmp byte [rdi + r12], 0
    je .fhs_next             ; same string, skip

    ; Return pointer to remainder
    lea rax, [rdi + r12]     ; start of suggestion (past prefix)
    ; Calculate length of remainder
    push rax
    mov rdi, rax
    call strlen
    mov rdx, rax             ; length of suggestion
    pop rax
    pop r13
    pop r12
    pop rbx
    ret

.fhs_next:
    dec r13
    jmp .fhs_loop

.fhs_none:
    xor eax, eax
    xor edx, edx
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; History expansion: !!, !N, !-N
; Scans line_buf for ! patterns and replaces with history entries
; ══════════════════════════════════════════════════════════════════════
expand_history:
    push rbx
    push r12
    push r13
    push r14

    lea rsi, [line_buf]
    lea rdi, [expand_buf]
    xor r12, r12            ; output position
    mov r14, 4090

.eh_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .eh_done

    ; Skip single-quoted strings
    cmp al, 0x27
    je .eh_single_quote

    ; Check for !
    cmp al, '!'
    jne .eh_copy

    ; Check what follows !
    movzx ecx, byte [rsi + 1]

    ; !! = last command
    cmp cl, '!'
    je .eh_bang_bang

    ; !- = relative (negative offset)
    cmp cl, '-'
    je .eh_bang_minus

    ; !N = absolute index (digit)
    cmp cl, '0'
    jl .eh_copy              ; not a pattern, copy ! literally
    cmp cl, '9'
    jg .eh_copy
    jmp .eh_bang_num

.eh_bang_bang:
    ; Replace !! with last command
    add rsi, 2              ; skip !!
    mov rax, [hist_count]
    test rax, rax
    jz .eh_loop             ; no history
    ; expand_history runs BEFORE add_history, so last cmd is at count-1
    dec rax
    js .eh_loop
    mov rcx, [hist_lines + rax*8]
    test rcx, rcx
    jz .eh_loop
    jmp .eh_splice

.eh_bang_minus:
    ; !-N = Nth from end
    add rsi, 2              ; skip !-
    ; Parse number
    xor rax, rax
.eh_bm_parse:
    movzx ecx, byte [rsi]
    sub cl, '0'
    js .eh_bm_got_num
    cmp cl, 9
    ja .eh_bm_got_num
    imul rax, 10
    movzx ecx, cl
    add rax, rcx
    inc rsi
    jmp .eh_bm_parse
.eh_bm_got_num:
    ; Index = hist_count - N (expand runs before add_history)
    mov rcx, [hist_count]
    sub rcx, rax
    js .eh_loop
    mov rcx, [hist_lines + rcx*8]
    test rcx, rcx
    jz .eh_loop
    jmp .eh_splice

.eh_bang_num:
    ; !N = absolute history number (1-based)
    inc rsi                 ; skip !
    xor rax, rax
.eh_bn_parse:
    movzx ecx, byte [rsi]
    sub cl, '0'
    js .eh_bn_got_num
    cmp cl, 9
    ja .eh_bn_got_num
    imul rax, 10
    movzx ecx, cl
    add rax, rcx
    inc rsi
    jmp .eh_bn_parse
.eh_bn_got_num:
    ; Convert 1-based to 0-based
    dec rax
    js .eh_loop
    cmp rax, [hist_count]
    jge .eh_loop
    mov rcx, [hist_lines + rax*8]
    test rcx, rcx
    jz .eh_loop
    jmp .eh_splice

.eh_splice:
    ; rcx = pointer to history string, copy to output
.eh_splice_copy:
    movzx eax, byte [rcx]
    test al, al
    jz .eh_loop
    cmp r12, r14
    jge .eh_done
    mov [rdi + r12], al
    inc r12
    inc rcx
    jmp .eh_splice_copy

.eh_single_quote:
    ; Copy including quotes, no expansion
    cmp r12, r14
    jge .eh_done
    mov [rdi + r12], al
    inc r12
    inc rsi
.eh_sq_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .eh_done
    cmp r12, r14
    jge .eh_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    cmp al, 0x27
    je .eh_loop
    jmp .eh_sq_loop

.eh_copy:
    cmp r12, r14
    jge .eh_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    jmp .eh_loop

.eh_done:
    mov byte [rdi + r12], 0
    ; Copy back to line_buf
    lea rsi, [expand_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.eh_copyback:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .eh_copyback_done
    inc rcx
    jmp .eh_copyback
.eh_copyback_done:
    mov [line_len], rcx

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Command substitution: $(cmd)
; Scans line_buf for $(...), executes cmd, replaces with output
; ══════════════════════════════════════════════════════════════════════
expand_cmd_subst:
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rsi, [line_buf]
    lea rdi, [subst_buf]
    xor r12, r12            ; output position
    mov r14, 8190

.ecs_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .ecs_done

    ; Skip single-quoted strings
    cmp al, 0x27
    je .ecs_single_quote

    ; Check for $(
    cmp al, '$'
    jne .ecs_copy
    cmp byte [rsi + 1], '('
    jne .ecs_copy

    ; Found $(, find matching )
    add rsi, 2              ; skip $(
    mov r13, rsi            ; start of command
    xor r15, r15            ; paren depth
    inc r15                 ; depth = 1
.ecs_find_close:
    cmp byte [rsi], 0
    je .ecs_copy_dollar     ; unterminated, copy literally
    cmp byte [rsi], '('
    je .ecs_inc_depth
    cmp byte [rsi], ')'
    je .ecs_dec_depth
    inc rsi
    jmp .ecs_find_close
.ecs_inc_depth:
    inc r15
    inc rsi
    jmp .ecs_find_close
.ecs_dec_depth:
    dec r15
    jnz .ecs_not_closing
    ; Found matching )
    mov byte [rsi], 0       ; null-terminate command
    inc rsi                 ; skip past )
    push rsi                ; save position after )
    push rdi                ; save output buffer

    ; Execute command and capture output
    ; Create pipe
    sub rsp, 8              ; alignment
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    jnz .ecs_pipe_fail

    ; Fork
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .ecs_child
    js .ecs_pipe_fail

    ; Parent: close write end, read from pipe
    mov rbx, rax            ; child pid
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall

    ; Read output into subst_tmp
    lea r15, [subst_tmp]
    xor r13, r13            ; bytes read total
.ecs_read_loop:
    mov rax, SYS_READ
    mov edi, [pipe_fds]
    lea rsi, [subst_tmp + r13]
    mov rdx, 4095
    sub rdx, r13
    jle .ecs_read_done
    syscall
    test rax, rax
    jle .ecs_read_done
    add r13, rax
    jmp .ecs_read_loop
.ecs_read_done:
    mov byte [subst_tmp + r13], 0

    ; Close read end
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall

    ; Wait for child
    sub rsp, 8
    mov rax, SYS_WAIT4
    mov rdi, rbx
    lea rsi, [rsp]
    xor edx, edx
    xor r10d, r10d
    syscall
    add rsp, 8

    ; Strip trailing newlines from output
    test r13, r13
    jz .ecs_splice_done
.ecs_strip_nl:
    dec r13
    js .ecs_splice_done
    cmp byte [subst_tmp + r13], 10
    je .ecs_strip_nl
    inc r13                 ; keep the non-newline char
.ecs_splice_done:
    mov byte [subst_tmp + r13], 0

    add rsp, 8              ; remove alignment padding
    pop rdi                 ; restore output buffer
    pop rsi                 ; restore input position

    ; Copy captured output to subst_buf
    lea rcx, [subst_tmp]
.ecs_copy_output:
    movzx eax, byte [rcx]
    test al, al
    jz .ecs_loop
    cmp r12, r14
    jge .ecs_done
    mov [rdi + r12], al
    inc r12
    inc rcx
    jmp .ecs_copy_output

.ecs_child:
    ; Child: redirect stdout to pipe write end
    mov rax, SYS_DUP2
    mov edi, [pipe_fds + 4]
    mov esi, 1
    syscall
    ; Also redirect stderr to pipe
    mov rax, SYS_DUP2
    mov edi, [pipe_fds + 4]
    mov esi, 2
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall

    ; Execute the command via /bin/sh -c "cmd"
    ; Build argv: ["/bin/sh", "-c", cmd, NULL]
    sub rsp, 32
    lea rax, [.ecs_sh_path]
    mov [rsp], rax
    lea rax, [.ecs_sh_c]
    mov [rsp + 8], rax
    mov [rsp + 16], r13     ; command string
    mov qword [rsp + 24], 0

    mov rax, SYS_EXECVE
    lea rdi, [.ecs_sh_path]
    mov rsi, rsp
    lea rdx, [env_array]
    syscall
    ; If exec fails, exit
    mov rax, SYS_EXIT
    mov edi, 127
    syscall

.ecs_pipe_fail:
    add rsp, 8
    pop rdi
    pop rsi
    jmp .ecs_loop

.ecs_not_closing:
    inc rsi
    jmp .ecs_find_close

.ecs_copy_dollar:
    ; Unterminated $(, copy $( literally
    cmp r12, r14
    jge .ecs_done
    mov byte [rdi + r12], '$'
    inc r12
    lea rsi, [r13 - 1]      ; back to after $
    jmp .ecs_loop

.ecs_single_quote:
    cmp r12, r14
    jge .ecs_done
    mov [rdi + r12], al
    inc r12
    inc rsi
.ecs_sq_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .ecs_done
    cmp r12, r14
    jge .ecs_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    cmp al, 0x27
    je .ecs_loop
    jmp .ecs_sq_loop

.ecs_copy:
    cmp r12, r14
    jge .ecs_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    jmp .ecs_loop

.ecs_done:
    mov byte [rdi + r12], 0
    ; Copy back to line_buf
    lea rsi, [subst_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.ecs_copyback:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .ecs_cb_done
    inc rcx
    jmp .ecs_copyback
.ecs_cb_done:
    mov [line_len], rcx

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.ecs_sh_path: db "/bin/sh", 0
.ecs_sh_c: db "-c", 0

; ══════════════════════════════════════════════════════════════════════
; Brace expansion: prefix{a,b,c}suffix -> prefixasuffix prefixbsuffix prefixcsuffix
; Operates on line_buf, expands to brace_buf, copies back
; Only handles simple single-level braces (no nesting)
;
; Strategy: scan char by char, copying to output. When we find a valid
; {x,y,...} within a word, identify prefix/suffix boundaries, then emit
; each expansion. Uses subst_tmp to store prefix and suffix pointers.
; ══════════════════════════════════════════════════════════════════════
expand_braces:
    push rbx
    push r12
    push r13
    push r14
    push r15

    lea rsi, [line_buf]
    lea rdi, [brace_buf]
    xor r12, r12            ; output position

.eb_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .eb_done

    ; Skip single-quoted strings
    cmp al, 0x27
    je .eb_single_quote
    cmp al, '"'
    je .eb_double_quote

    ; Look for {
    cmp al, '{'
    jne .eb_copy

    ; Validate: must contain comma and closing }
    mov rcx, rsi
    inc rcx
    xor r15, r15
.eb_validate:
    cmp byte [rcx], 0
    je .eb_copy
    cmp byte [rcx], ','
    jne .eb_val_no_comma
    mov r15, 1
.eb_val_no_comma:
    cmp byte [rcx], '}'
    je .eb_val_end
    inc rcx
    jmp .eb_validate
.eb_val_end:
    test r15, r15
    jz .eb_copy              ; no comma, copy literally

    ; r13 = } position, rbx = { position
    mov r13, rcx
    mov rbx, rsi

    ; Find prefix start: walk back to space or line start
    mov r14, rbx
.eb_pfx_back:
    cmp r14, line_buf
    jle .eb_pfx_at_start
    dec r14
    cmp byte [r14], ' '
    je .eb_pfx_after_space
    cmp byte [r14], 9
    je .eb_pfx_after_space
    jmp .eb_pfx_back
.eb_pfx_after_space:
    inc r14
    jmp .eb_pfx_set
.eb_pfx_at_start:
    lea r14, [line_buf]
.eb_pfx_set:
    ; r14 = prefix start, rbx = { position

    ; Find suffix end: from } to space or end
    lea r15, [r13 + 1]      ; suffix start (after })
    mov rcx, r15
.eb_sfx_fwd:
    cmp byte [rcx], 0
    je .eb_sfx_set
    cmp byte [rcx], ' '
    je .eb_sfx_set
    cmp byte [rcx], 9
    je .eb_sfx_set
    inc rcx
    jmp .eb_sfx_fwd
.eb_sfx_set:
    ; rcx = suffix end (exclusive)
    ; Save suffix end for resuming after expansion
    mov [subst_tmp], rcx     ; borrow subst_tmp[0..7] for this pointer
    ; Save suffix start
    mov [subst_tmp + 8], r15

    ; Rewind output: undo prefix chars already copied
    mov rax, rbx
    sub rax, r14             ; prefix length
    sub r12, rax             ; rewind output

    ; Iterate through brace items
    lea rsi, [rbx + 1]      ; first item (after {)
    xor ecx, ecx            ; item counter (0 = first)

.eb_item:
    cmp rsi, r13
    jge .eb_items_done

    ; Space separator between items
    test ecx, ecx
    jz .eb_no_sep
    cmp r12, 4090
    jge .eb_items_done
    mov byte [rdi + r12], ' '
    inc r12
.eb_no_sep:
    inc ecx
    push rcx

    ; Emit prefix (r14 to rbx)
    mov rax, r14
.eb_emit_pfx:
    cmp rax, rbx
    jge .eb_emit_item
    cmp r12, 4090
    jge .eb_emit_item
    movzx edx, byte [rax]
    mov [rdi + r12], dl
    inc r12
    inc rax
    jmp .eb_emit_pfx

.eb_emit_item:
    ; Emit item chars (rsi to comma or })
.eb_emit_item_ch:
    cmp rsi, r13
    jge .eb_emit_sfx
    cmp byte [rsi], ','
    je .eb_emit_sfx
    cmp r12, 4090
    jge .eb_emit_sfx
    movzx edx, byte [rsi]
    mov [rdi + r12], dl
    inc r12
    inc rsi
    jmp .eb_emit_item_ch

.eb_emit_sfx:
    ; Skip comma if present
    cmp rsi, r13
    jge .eb_sfx_go
    inc rsi                  ; skip comma
.eb_sfx_go:
    ; Emit suffix (r15 to suffix_end)
    push rsi
    mov rsi, [subst_tmp + 8] ; suffix start
    mov rax, [subst_tmp]     ; suffix end
.eb_emit_sfx_ch:
    cmp rsi, rax
    jge .eb_sfx_done
    cmp r12, 4090
    jge .eb_sfx_done
    movzx edx, byte [rsi]
    mov [rdi + r12], dl
    inc r12
    inc rsi
    jmp .eb_emit_sfx_ch
.eb_sfx_done:
    pop rsi

    pop rcx
    jmp .eb_item

.eb_items_done:
    ; Resume scanning from suffix end
    mov rsi, [subst_tmp]
    jmp .eb_loop

.eb_single_quote:
    cmp r12, 4090
    jge .eb_done
    mov [rdi + r12], al
    inc r12
    inc rsi
.eb_sq:
    movzx eax, byte [rsi]
    test al, al
    jz .eb_done
    cmp r12, 4090
    jge .eb_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    cmp al, 0x27
    je .eb_loop
    jmp .eb_sq

.eb_double_quote:
    cmp r12, 4090
    jge .eb_done
    mov [rdi + r12], al
    inc r12
    inc rsi
.eb_dq:
    movzx eax, byte [rsi]
    test al, al
    jz .eb_done
    cmp r12, 4090
    jge .eb_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    cmp al, '"'
    je .eb_loop
    jmp .eb_dq

.eb_copy:
    cmp r12, 4090
    jge .eb_done
    mov [rdi + r12], al
    inc r12
    inc rsi
    jmp .eb_loop

.eb_done:
    mov byte [rdi + r12], 0
    ; Copy back to line_buf
    lea rsi, [brace_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.eb_cb:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .eb_cb_done
    inc rcx
    jmp .eb_cb
.eb_cb_done:
    mov [line_len], rcx

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Try to expand abbreviation at cursor position
; Called when space is pressed. Checks if the word before cursor matches
; an abbreviation, replaces it if so, adds space, redraws.
; Returns: rax = 1 if expanded, 0 if not
; ══════════════════════════════════════════════════════════════════════
try_expand_abbrev:
    push rbx
    ; NOTE: r12 is NOT saved - we intentionally update the caller's cursor
    push r13
    push r14

    cmp qword [abbrev_count], 0
    je .tea_no

    ; Find start of current word
    mov rax, r12
    dec rax
.tea_find_start:
    test rax, rax
    js .tea_at_start
    cmp byte [line_buf + rax], ' '
    je .tea_found_start
    dec rax
    jmp .tea_find_start
.tea_found_start:
    inc rax
.tea_at_start:
    xor eax, eax             ; word starts at position 0
    mov r13, rax             ; word start index

    ; Extract word
    mov rcx, r12
    sub rcx, r13
    test rcx, rcx
    jz .tea_no
    cmp rcx, 250
    jg .tea_no

    ; Copy word to search_buf
    lea rsi, [line_buf + r13]
    lea rdi, [search_buf]
    mov rdx, rcx
    push rcx
.tea_copy_word:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rdx
    jnz .tea_copy_word
    mov byte [rdi], 0
    pop rcx

    ; Search abbreviations
    xor r14, r14
.tea_search:
    cmp r14, [abbrev_count]
    jge .tea_no
    push r14
    lea rdi, [search_buf]
    mov rsi, [abbrev_names + r14*8]
    call strcmp
    pop r14
    test rax, rax
    jz .tea_found
    inc r14
    jmp .tea_search

.tea_found:
    ; Get expansion length
    mov rdi, [abbrev_values + r14*8]
    call strlen
    mov rcx, rax             ; expansion length

    ; Rebuild line in suggestion_buf
    lea rdi, [suggestion_buf]
    lea rsi, [line_buf]
    xor rax, rax
    ; Copy prefix (before word)
.tea_cp_pre:
    cmp rax, r13
    jge .tea_cp_exp
    movzx edx, byte [rsi + rax]
    mov [rdi + rax], dl
    inc rax
    jmp .tea_cp_pre
.tea_cp_exp:
    ; Copy expansion
    push rax
    mov rsi, [abbrev_values + r14*8]
    xor rdx, rdx
.tea_cp_exp_ch:
    cmp rdx, rcx
    jge .tea_cp_space
    movzx ebx, byte [rsi + rdx]
    mov [rdi + rax], bl
    inc rax
    inc rdx
    jmp .tea_cp_exp_ch
.tea_cp_space:
    mov byte [rdi + rax], ' '
    inc rax
    mov r12, rax             ; cursor after expansion + space
    ; Copy rest after original cursor
    lea rsi, [line_buf]
    mov rdx, [rsp]           ; saved rax (prefix end) from stack
    ; Actually need original r12 (cursor before expansion)
    pop rdx                  ; discard saved rax
    ; Rest starts at the old cursor position in original line
    push r12                 ; save new cursor
    mov r12, [line_len]      ; use original line_len
    mov rdx, rcx             ; expansion length (not needed here)
    ; The original word went from r13 to old-cursor
    ; old cursor = r13 + word_len. word_len is in search_buf
    lea rsi, [search_buf]
    push rax
    mov rdi, rsi
    call strlen
    mov rdx, rax             ; word length
    pop rax
    add rdx, r13             ; rdx = position after original word
    lea rsi, [line_buf]
.tea_cp_rest:
    cmp rdx, [line_len]
    jge .tea_cp_done
    movzx ebx, byte [rsi + rdx]
    mov [rdi + rax], bl
    inc rax
    inc rdx
    jmp .tea_cp_rest
.tea_cp_done:
    mov byte [rdi + rax], 0
    mov [line_len], rax
    pop r12                  ; restore new cursor

    ; Copy back to line_buf
    lea rsi, [suggestion_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.tea_cb:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .tea_cb_done
    inc rcx
    jmp .tea_cb
.tea_cb_done:
    call full_redraw
    mov rax, 1
    pop r14
    pop r13
    pop rbx
    ret

.tea_no:
    xor eax, eax
    pop r14
    pop r13
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Expand global nicks (gnicks) in line_buf
; Scans all tokens for gnick matches and replaces them
; ══════════════════════════════════════════════════════════════════════
expand_gnicks:
    push rbx
    push r12
    push r13
    push r14

    cmp qword [gnick_count], 0
    je .eg_done

    ; Up to 3 expansion passes
    xor r14, r14
.eg_pass:
    cmp r14, 3
    jge .eg_done
    xor r13, r13             ; found-any flag

    xor r12, r12
.eg_nick_loop:
    cmp r12, [gnick_count]
    jge .eg_pass_done

    lea rdi, [line_buf]
    mov rsi, [gnick_names + r12*8]
    call strstr_simple
    test rax, rax
    jz .eg_next_nick

    ; Found match at rax
    push rax
    mov rdi, [gnick_names + r12*8]
    call strlen
    mov rbx, rax             ; name length
    mov rdi, [gnick_values + r12*8]
    call strlen
    mov rcx, rax             ; value length
    pop rax                  ; match position

    ; Build new line in suggestion_buf
    lea rdi, [suggestion_buf]
    lea rsi, [line_buf]
    mov rdx, rax
    sub rdx, rsi             ; prefix length
    push rdx
    push rcx
    xor rcx, rcx
    test rdx, rdx
    jz .eg_cp_val
.eg_cp_pre:
    cmp rcx, rdx
    jge .eg_cp_val
    movzx eax, byte [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp .eg_cp_pre
.eg_cp_val:
    pop rax                  ; value length
    pop rdx                  ; prefix length was in rcx, now rdx = output pos
    mov rcx, rdx             ; output position
    push rcx
    mov rsi, [gnick_values + r12*8]
    xor rdx, rdx
.eg_cv:
    cmp rdx, rax
    jge .eg_cp_suf
    movzx r8d, byte [rsi + rdx]
    mov [rdi + rcx], r8b
    inc rcx
    inc rdx
    jmp .eg_cv
.eg_cp_suf:
    pop rax                  ; original prefix length
    lea rsi, [line_buf + rax]
    add rsi, rbx             ; skip matched name
.eg_cs:
    movzx eax, byte [rsi]
    mov [rdi + rcx], al
    test al, al
    jz .eg_replace_done
    inc rsi
    inc rcx
    jmp .eg_cs
.eg_replace_done:
    lea rsi, [suggestion_buf]
    lea rdi, [line_buf]
    xor rcx, rcx
.eg_rcb:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .eg_rcb_done
    inc rcx
    jmp .eg_rcb
.eg_rcb_done:
    mov [line_len], rcx
    mov r13, 1

.eg_next_nick:
    inc r12
    jmp .eg_nick_loop

.eg_pass_done:
    test r13, r13
    jz .eg_done
    inc r14
    jmp .eg_pass

.eg_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Show command duration if above threshold
; Uses cmd_start_time and cmd_end_time (tv_sec, tv_nsec)
; ══════════════════════════════════════════════════════════════════════
show_cmd_duration:
    push rbx
    push r12

    mov rax, [slow_cmd_threshold]
    test rax, rax
    jz .scd_done              ; threshold = 0, disabled

    ; Calculate elapsed seconds
    mov rbx, [cmd_end_time]        ; end tv_sec
    sub rbx, [cmd_start_time]      ; start tv_sec
    ; Adjust for nanoseconds
    mov rcx, [cmd_end_time + 8]    ; end tv_nsec
    cmp rcx, [cmd_start_time + 8]
    jge .scd_no_borrow
    dec rbx
.scd_no_borrow:

    ; Compare with threshold
    cmp rbx, [slow_cmd_threshold]
    jl .scd_done

    ; Print "[bare] Command took Xs"
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.scd_prefix]
    mov rdx, .scd_prefix_len
    syscall

    ; Convert seconds to string
    mov rax, rbx
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall

    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.scd_suffix]
    mov rdx, .scd_suffix_len
    syscall

.scd_done:
    pop r12
    pop rbx
    ret

.scd_prefix: db 27, "[38;5;245m[bare] Command took "
.scd_prefix_len equ $ - .scd_prefix
.scd_suffix: db "s", 27, "[0m", 10
.scd_suffix_len equ $ - .scd_suffix

; ══════════════════════════════════════════════════════════════════════
; Job control
; ══════════════════════════════════════════════════════════════════════

; Add a stopped/background job to the job table
; rdi = pid, rsi = command string
; Register a running background job. rdi=pid, rsi=command string.
; Returns 1-based job number in rax (0 if table is full).
add_bg_job:
    push rbx
    push r12
    push r13
    mov r12, rdi             ; pid
    mov r13, rsi             ; command string
    mov rax, [job_count]
    cmp rax, MAX_JOBS
    jge .abj_full
    mov [job_pids + rax*8], r12
    mov qword [job_status + rax*8], 0       ; 0 = running
    ; Allocate command storage just like add_job does
    lea rdi, [job_cmd_storage]
    test rax, rax
    jz .abj_store
    mov rdi, [job_cmds + rax*8 - 8]
    push rax
    call strlen
    add rdi, rax
    inc rdi
    pop rax
.abj_store:
    mov [job_cmds + rax*8], rdi
    mov rsi, r13
.abj_copy:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .abj_copied
    inc rsi
    inc rdi
    jmp .abj_copy
.abj_copied:
    inc qword [job_count]
    mov rax, [job_count]     ; 1-based job number
    pop r13
    pop r12
    pop rbx
    ret
.abj_full:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    ret

; tty_set_fg_pgrp: ioctl(0, TIOCSPGRP, &pgid). rdi = pgid.
; SIGTTOU is already ignored by bare so this won't suspend us.
tty_set_fg_pgrp:
    cmp qword [is_tty], 0
    je .tsfp_ret
    push rdi
    mov rax, SYS_IOCTL
    xor edi, edi             ; stdin
    mov esi, TIOCSPGRP
    mov rdx, rsp             ; pointer to pgid on stack
    syscall
    pop rdi
.tsfp_ret:
    ret

add_job:
    push rbx
    push r12
    mov r12, rdi             ; pid
    mov rax, [job_count]
    cmp rax, MAX_JOBS
    jge .aj_done

    mov [job_pids + rax*8], r12
    mov qword [job_status + rax*8], 1  ; 1 = stopped

    ; Copy command to job_cmd_storage
    lea rdi, [job_cmd_storage]
    ; Find end of storage
    test rax, rax
    jz .aj_store
    mov rdi, [job_cmds + rax*8 - 8]
    push rax
    call strlen
    add rdi, rax
    inc rdi
    pop rax
.aj_store:
    mov [job_cmds + rax*8], rdi
    ; Copy command string
.aj_copy:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .aj_copied
    inc rsi
    inc rdi
    jmp .aj_copy
.aj_copied:
    inc qword [job_count]
.aj_done:
    pop r12
    pop rbx
    ret

; :jobs - list all jobs
handle_jobs:
    push rbx
    push r12

    ; First, reap any finished background jobs
    call reap_jobs

    xor r12, r12
.hj_loop:
    cmp r12, [job_count]
    jge .hj_done
    ; Skip done jobs
    cmp qword [job_status + r12*8], 2
    je .hj_next

    ; Print [N] Status PID : cmd
    push r12
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hj_bracket_open]
    mov rdx, 1
    syscall
    mov r12, [rsp]
    mov rax, r12
    inc rax
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hj_bracket_close]
    mov rdx, 2
    syscall
    ; Status
    mov r12, [rsp]
    cmp qword [job_status + r12*8], 1
    je .hj_stopped
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hj_running]
    mov rdx, .hj_running_len
    syscall
    jmp .hj_pid
.hj_stopped:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hj_stopped_str]
    mov rdx, .hj_stopped_len
    syscall
.hj_pid:
    ; Print PID
    mov r12, [rsp]
    mov rax, [job_pids + r12*8]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    ; Print " : "
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hj_colon]
    mov rdx, 3
    syscall
    ; Print command
    mov r12, [rsp]
    mov rsi, [job_cmds + r12*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov r12, [rsp]
    mov rsi, [job_cmds + r12*8]
    syscall
    call write_nl
    pop r12
.hj_next:
    inc r12
    jmp .hj_loop
.hj_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

.hj_bracket_open: db "["
.hj_bracket_close: db "] "
.hj_stopped_str: db "Stopped  "
.hj_stopped_len equ $ - .hj_stopped_str
.hj_running: db "Running  "
.hj_running_len equ $ - .hj_running
.hj_colon: db " : "

; :fg N - bring job to foreground
handle_fg:
    push rbx
    push r12
    mov r12, rdi             ; argv array

    mov rdi, [r12 + 8]       ; job number argument
    test rdi, rdi
    jz .hfg_last             ; no arg: use last job

    ; Parse job number
    call parse_int
    dec rax                   ; 1-based to 0-based
    jmp .hfg_resume
.hfg_last:
    mov rax, [job_count]
    dec rax
    test rax, rax
    js .hfg_no_job

.hfg_resume:
    cmp rax, [job_count]
    jge .hfg_no_job
    cmp qword [job_status + rax*8], 2
    je .hfg_no_job            ; job already done

    mov rbx, rax              ; job index

    ; Send SIGCONT to the whole process group of the job (negative pid).
    ; Bg children were placed in their own pgrp via setpgid(0,0), so the
    ; pgid equals the wrapper's pid. Signaling the pgrp wakes the actual
    ; payload (vim, etc.), not just the wrapper that is stuck in wait4.
    mov rdi, [job_pids + rbx*8]
    neg rdi
    mov rax, SYS_KILL
    mov rsi, SIGCONT
    syscall

    ; Hand the controlling terminal to the job's pgrp so it can read
    ; keystrokes without re-tripping SIGTTIN.
    mov rdi, [job_pids + rbx*8]
    call tty_set_fg_pgrp

    ; Wait for the wrapper (with WUNTRACED so we still see suspends)
    sub rsp, 16
    mov rdi, [job_pids + rbx*8]
    lea rsi, [rsp]
    mov edx, WUNTRACED
    xor r10d, r10d
    mov rax, SYS_WAIT4
    syscall

    ; Take the terminal back regardless of how the wait ended.
    push rax
    push rcx
    mov rax, SYS_GETPGID
    xor edi, edi
    syscall
    mov rdi, rax
    call tty_set_fg_pgrp
    pop rcx
    pop rax
    ; Check if stopped again
    mov eax, [rsp]
    mov ecx, eax
    and ecx, 0xFF
    cmp ecx, 0x7F
    je .hfg_stopped_again
    ; Finished: mark job as done
    mov qword [job_status + rbx*8], 2
    shr eax, 8
    and eax, 0xFF
    mov [last_status], rax
    add rsp, 16
    pop r12
    pop rbx
    ret
.hfg_stopped_again:
    mov qword [job_status + rbx*8], 1
    add rsp, 16
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hfg_stopped_msg]
    mov rdx, .hfg_stopped_len
    syscall
    pop r12
    pop rbx
    ret
.hfg_no_job:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hfg_no_msg]
    mov rdx, .hfg_no_len
    syscall
    mov qword [last_status], 1
    pop r12
    pop rbx
    ret
.hfg_stopped_msg: db 10, "[stopped]", 10
.hfg_stopped_len equ $ - .hfg_stopped_msg
.hfg_no_msg: db "bare: no such job", 10
.hfg_no_len equ $ - .hfg_no_msg

; :bg N - resume a stopped job in background
handle_bg:
    push rbx
    push r12
    mov r12, rdi

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hbg_last
    call parse_int
    dec rax
    jmp .hbg_resume
.hbg_last:
    mov rax, [job_count]
    dec rax
    test rax, rax
    js .hbg_no_job
.hbg_resume:
    cmp rax, [job_count]
    jge .hbg_no_job
    mov rbx, rax
    ; Send SIGCONT
    mov rdi, [job_pids + rbx*8]
    mov rax, SYS_KILL
    mov rsi, SIGCONT
    syscall
    ; Mark as running
    mov qword [job_status + rbx*8], 0
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret
.hbg_no_job:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hbg_no_msg]
    mov rdx, .hbg_no_len
    syscall
    mov qword [last_status], 1
    pop r12
    pop rbx
    ret
.hbg_no_msg: db "bare: no such job", 10
.hbg_no_len equ $ - .hbg_no_msg

; Reap finished background jobs (non-blocking waitpid)
reap_jobs:
    push rbx
    push r12
    sub rsp, 16

    xor r12, r12
.rj_loop:
    cmp r12, [job_count]
    jge .rj_done
    ; Only check running jobs
    cmp qword [job_status + r12*8], 0
    jne .rj_next

    mov rdi, [job_pids + r12*8]
    lea rsi, [rsp]
    mov edx, WNOHANG
    xor r10d, r10d
    mov rax, SYS_WAIT4
    syscall
    test rax, rax
    jle .rj_next             ; not finished yet
    ; Job finished, mark as done
    mov qword [job_status + r12*8], 2
.rj_next:
    inc r12
    jmp .rj_loop
.rj_done:
    add rsp, 16
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; :theme [name] - list or apply color theme
; ══════════════════════════════════════════════════════════════════════
handle_theme:
    push rbx
    push r12
    push r13
    mov r12, rdi             ; argv array

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .ht_list

    ; Find theme by name
    lea r13, [theme_names]
    xor rcx, rcx
.ht_search:
    mov rsi, [r13 + rcx*8]
    test rsi, rsi
    jz .ht_not_found
    push rcx
    push rdi
    call strcmp
    pop rdi
    pop rcx
    test rax, rax
    jz .ht_found
    inc rcx
    jmp .ht_search

.ht_found:
    ; Copy theme_data[rcx*16] to color_settings
    imul rax, rcx, NUM_COLORS
    lea rsi, [theme_data + rax]
    lea rdi, [color_settings]
    mov rcx, NUM_COLORS
    rep movsb
    mov qword [last_status], 0
    jmp .ht_done

.ht_not_found:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.ht_err]
    mov rdx, .ht_err_len
    syscall
    mov qword [last_status], 1
    jmp .ht_done

.ht_list:
    ; Print available themes
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ht_avail]
    mov rdx, .ht_avail_len
    syscall
    lea r13, [theme_names]
    xor rcx, rcx
.ht_list_loop:
    mov rsi, [r13 + rcx*8]
    test rsi, rsi
    jz .ht_list_done
    push rcx
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [r13 + rcx*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.ht_sep]
    mov rdx, 2
    syscall
    pop rcx
    inc rcx
    jmp .ht_list_loop
.ht_list_done:
    call write_nl
    mov qword [last_status], 0

.ht_done:
    pop r13
    pop r12
    pop rbx
    ret

.ht_err: db "bare: unknown theme", 10
.ht_err_len equ $ - .ht_err
.ht_avail: db "Themes: "
.ht_avail_len equ $ - .ht_avail
.ht_sep: db "  "

; ══════════════════════════════════════════════════════════════════════
; :env [VAR | set VAR val | unset VAR] - environment management
; ══════════════════════════════════════════════════════════════════════
handle_env:
    push rbx
    push r12
    mov r12, rdi             ; argv array

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .henv_list

    ; Check for "set"
    lea rsi, [.henv_set_str]
    call strcmp
    test rax, rax
    jz .henv_set

    ; Check for "unset"
    mov rdi, [r12 + 8]
    lea rsi, [.henv_unset_str]
    call strcmp
    test rax, rax
    jz .henv_unset

    ; Single arg: show specific variable
    mov rdi, [r12 + 8]
    call lookup_env_var
    test rax, rax
    jz .henv_not_found
    mov rsi, rax
    mov rdi, rax
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall
    call write_nl
    jmp .henv_done

.henv_set:
    ; :env set VAR value
    mov rdi, [r12 + 16]     ; VAR
    test rdi, rdi
    jz .henv_done
    mov rsi, [r12 + 24]     ; value
    test rsi, rsi
    jz .henv_done
    ; Build "VAR=value" string in nick_expand_buf
    lea rbx, [nick_expand_buf]
    ; Copy VAR
.henv_set_var:
    mov al, [rdi]
    test al, al
    jz .henv_set_eq
    mov [rbx], al
    inc rdi
    inc rbx
    jmp .henv_set_var
.henv_set_eq:
    mov byte [rbx], '='
    inc rbx
    ; Copy value
.henv_set_val:
    mov al, [rsi]
    test al, al
    jz .henv_set_apply
    mov [rbx], al
    inc rsi
    inc rbx
    jmp .henv_set_val
.henv_set_apply:
    mov byte [rbx], 0
    lea rdi, [nick_expand_buf]
    call env_set_entry
    jmp .henv_done

.henv_unset:
    mov rdi, [r12 + 16]
    test rdi, rdi
    jz .henv_done
    call env_remove_entry
    jmp .henv_done

.henv_not_found:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.henv_nf_msg]
    mov rdx, .henv_nf_len
    syscall
    mov qword [last_status], 1
    jmp .henv_ret

.henv_list:
    ; Print first 30 env vars
    xor rcx, rcx
.henv_list_loop:
    cmp rcx, [env_count]
    jge .henv_done
    cmp rcx, 30
    jge .henv_done
    push rcx
    mov rsi, [env_array + rcx*8]
    test rsi, rsi
    jz .henv_list_next
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [env_array + rcx*8]
    syscall
    call write_nl
.henv_list_next:
    pop rcx
    inc rcx
    jmp .henv_list_loop

.henv_done:
    mov qword [last_status], 0
.henv_ret:
    pop r12
    pop rbx
    ret

.henv_set_str: db "set", 0
.henv_unset_str: db "unset", 0
.henv_nf_msg: db "bare: variable not found", 10
.henv_nf_len equ $ - .henv_nf_msg

; ══════════════════════════════════════════════════════════════════════
; :config [key [value]] - view/change settings
; ══════════════════════════════════════════════════════════════════════
handle_config:
    push rbx
    push r12
    mov r12, rdi

    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hcfg_list

    ; key provided, check for value
    mov rsi, [r12 + 16]
    test rsi, rsi
    jz .hcfg_show_key

    ; Set key = value (delegate to config parser logic)
    ; For now, handle known keys
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_slow]
    call strcmp
    test rax, rax
    jnz .hcfg_check_dedup
    mov rdi, [r12 + 16]
    call parse_int
    mov [slow_cmd_threshold], rax
    jmp .hcfg_done

.hcfg_check_dedup:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_dedup]
    call strcmp
    test rax, rax
    jnz .hcfg_check_limit
    mov rdi, [r12 + 16]
    cmp byte [rdi], 'f'
    jne .hcfg_ded_smart
    and qword [config_flags], ~(1 << CFG_HIST_DEDUP_SMART)
    or qword [config_flags], (1 << CFG_HIST_DEDUP_FULL)
    jmp .hcfg_done
.hcfg_ded_smart:
    cmp byte [rdi], 's'
    jne .hcfg_ded_off
    and qword [config_flags], ~(1 << CFG_HIST_DEDUP_FULL)
    or qword [config_flags], (1 << CFG_HIST_DEDUP_SMART)
    jmp .hcfg_done
.hcfg_ded_off:
    and qword [config_flags], ~((1 << CFG_HIST_DEDUP_FULL) | (1 << CFG_HIST_DEDUP_SMART))
    jmp .hcfg_done

.hcfg_check_limit:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_climit]
    call strcmp
    test rax, rax
    jnz .hcfg_check_color
    mov rdi, [r12 + 16]
    call parse_int
    mov [completion_limit], rax
    jmp .hcfg_done

.hcfg_check_color:
    ; Check for c_* color keys
    mov rdi, [r12 + 8]
    cmp word [rdi], 'c_'
    jne .hcfg_check_bool
    lea rdi, [rdi + 2]
    mov rsi, [r12 + 16]
    call config_set_color
    jmp .hcfg_done

.hcfg_check_bool:
    ; Boolean toggles: show_tips, auto_correct, auto_pair, rprompt
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_show_tips]
    call strcmp
    test rax, rax
    jnz .hcfg_cb2
    mov rdi, [r12 + 16]
    mov rsi, CFG_SHOW_TIPS
    call config_set_bool
    jmp .hcfg_done
.hcfg_cb2:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_auto_correct]
    call strcmp
    test rax, rax
    jnz .hcfg_cb3
    mov rdi, [r12 + 16]
    mov rsi, CFG_AUTO_CORRECT
    call config_set_bool
    jmp .hcfg_done
.hcfg_cb3:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_auto_pair_str]
    call strcmp
    test rax, rax
    jnz .hcfg_cb4
    mov rdi, [r12 + 16]
    mov rsi, CFG_AUTO_PAIR
    call config_set_bool
    jmp .hcfg_done
.hcfg_cb4:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_rprompt_str]
    call strcmp
    test rax, rax
    jnz .hcfg_cb5
    mov rdi, [r12 + 16]
    mov rsi, CFG_RPROMPT
    call config_set_bool
    jmp .hcfg_done
.hcfg_cb5:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_show_git_branch]
    call strcmp
    test rax, rax
    jnz .hcfg_cb6
    mov rdi, [r12 + 16]
    mov rsi, CFG_SHOW_GIT_BRANCH
    call config_set_bool
    jmp .hcfg_done
.hcfg_cb6:
    mov rdi, [r12 + 8]
    lea rsi, [hcfg_git_status_fork]
    call strcmp
    test rax, rax
    jnz .hcfg_done
    mov rdi, [r12 + 16]
    mov rsi, CFG_GIT_STATUS_FORK
    call config_set_bool

.hcfg_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

.hcfg_show_key:
    ; Show value of a specific key
    jmp .hcfg_done

.hcfg_list:
    ; Print current config
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hcfg_header]
    mov rdx, hcfg_header_len
    syscall
    ; slow_command_threshold
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hcfg_slow_label]
    mov rdx, hcfg_slow_label_len
    syscall
    mov rax, [slow_cmd_threshold]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    call write_nl
    ; completion_limit
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hcfg_climit_label]
    mov rdx, hcfg_climit_label_len
    syscall
    mov rax, [completion_limit]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    call write_nl
    ; Print all colors with preview
    push rbx
    lea rbx, [.hcfg_color_names]
    xor rcx, rcx
.hcfg_color_loop:
    cmp rcx, NUM_COLORS
    jge .hcfg_colors_done
    push rcx
    ; Print "  c_<name> = "
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hcfg_c_prefix]
    mov rdx, 4
    syscall
    mov rcx, [rsp]
    ; Get color name string
    mov rsi, [rbx + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [rbx + rcx*8]
    syscall
    ; " = "
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    ; Print color value
    mov rcx, [rsp]
    movzx eax, byte [color_settings + rcx]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    ; Print color preview: colored block
    mov rcx, [rsp]
    movzx eax, byte [color_settings + rcx]
    lea rdi, [tmp_buf]
    call write_fg_color
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [tmp_buf]
    syscall
    ; Print colored sample text
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hcfg_sample]
    mov rdx, .hcfg_sample_len
    syscall
    ; Reset
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hcfg_reset]
    mov rdx, 4
    syscall
    call write_nl
    pop rcx
    inc rcx
    jmp .hcfg_color_loop
.hcfg_colors_done:
    pop rbx
    jmp .hcfg_done

.hcfg_c_prefix: db "  c_"
.hcfg_sample: db " sample"
.hcfg_sample_len equ $ - .hcfg_sample
.hcfg_reset: db 27, "[0m"
.hcfg_color_names:  ; alias for global color_name_table
color_name_table:
    dq cn_user, cn_host, cn_cwd, cn_prompt
    dq cn_cmd, cn_nick, cn_gnick, cn_path
    dq cn_switch, cn_bookmark, cn_colon, cn_git
    dq cn_stamp, cn_tabsel, cn_tabopt, cn_suggest
    dq cn_user_root, cn_host_root
cn_user: db "user", 0
cn_host: db "host", 0
cn_cwd: db "cwd", 0
cn_prompt: db "prompt", 0
cn_cmd: db "cmd", 0
cn_nick: db "nick", 0
cn_gnick: db "gnick", 0
cn_path: db "path", 0
cn_switch: db "switch", 0
cn_bookmark: db "bookmark", 0
cn_colon: db "colon", 0
cn_git: db "git", 0
cn_stamp: db "stamp", 0
cn_tabsel: db "tabsel", 0
cn_tabopt: db "tabopt", 0
cn_suggest: db "suggest", 0
cn_user_root: db "user_root", 0
cn_host_root: db "host_root", 0

hcfg_header: db "Configuration:", 10
hcfg_header_len equ $ - hcfg_header
hcfg_slow: db "slow_command_threshold", 0
hcfg_slow_label: db "  slow_command_threshold = "
hcfg_slow_label_len equ $ - hcfg_slow_label
hcfg_dedup: db "history_dedup", 0
hcfg_climit: db "completion_limit", 0
hcfg_climit_label: db "  completion_limit = "
hcfg_climit_label_len equ $ - hcfg_climit_label
hcfg_show_tips: db "show_tips", 0
hcfg_auto_correct: db "auto_correct", 0
hcfg_auto_pair_str: db "auto_pair", 0
hcfg_rprompt_str: db "rprompt", 0
hcfg_show_git_branch: db "show_git_branch", 0
hcfg_git_status_fork: db "git_status_fork", 0

; ══════════════════════════════════════════════════════════════════════
; Save config to ~/.barerc
; ══════════════════════════════════════════════════════════════════════
save_config:
    push rbx
    push r12
    push r13

    ; Check if config file on disk is newer than our last save
    ; (another terminal may have saved a newer config)
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [config_path]
    mov rsi, rsp
    syscall
    test rax, rax
    js .sc_no_stat            ; file doesn't exist yet, safe to write
    mov rax, [rsp + 88]       ; file mtime
    cmp rax, [config_save_time]
    jle .sc_no_stat           ; file is older or same, safe to write
    ; File is newer than our last save, skip to avoid overwriting
    cmp qword [config_save_time], 0
    je .sc_no_stat            ; first save (time=0), always write
    add rsp, 144
    jmp .sc_done
.sc_no_stat:
    add rsp, 144

    ; Open config file for writing
    mov rax, SYS_OPEN
    lea rdi, [config_path]
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 0o644
    syscall
    test rax, rax
    js .sc_done
    mov r12, rax             ; fd

    ; Write nicks
    xor r13, r13
.sc_nick_loop:
    cmp r13, [nick_count]
    jge .sc_gnicks
    ; Write "nick.<name> = <value>\n"
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_nick_pre]
    mov rdx, 5
    syscall
    mov rdi, [nick_names + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [nick_names + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rdi, [nick_values + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [nick_values + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    inc r13
    jmp .sc_nick_loop

.sc_gnicks:
    xor r13, r13
.sc_gnick_loop:
    cmp r13, [gnick_count]
    jge .sc_abbrevs
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_gnick_pre]
    mov rdx, 6
    syscall
    mov rdi, [gnick_names + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [gnick_names + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rdi, [gnick_values + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [gnick_values + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    inc r13
    jmp .sc_gnick_loop

.sc_abbrevs:
    xor r13, r13
.sc_abbrev_loop:
    cmp r13, [abbrev_count]
    jge .sc_bookmarks
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_abbrev_pre]
    mov rdx, 7
    syscall
    mov rdi, [abbrev_names + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [abbrev_names + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rdi, [abbrev_values + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [abbrev_values + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    inc r13
    jmp .sc_abbrev_loop

.sc_bookmarks:
    xor r13, r13
.sc_bm_loop:
    cmp r13, [bm_count]
    jge .sc_colors
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_bm_pre]
    mov rdx, 3
    syscall
    mov rdi, [bm_names + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [bm_names + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rdi, [bm_paths + r13*8]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov rsi, [bm_paths + r13*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    inc r13
    jmp .sc_bm_loop

.sc_colors:
    ; Write color settings
    xor r13, r13
    lea rbx, [color_name_table]
.sc_color_loop:
    cmp r13, NUM_COLORS
    jge .sc_settings
    ; "c_<name> = <value>\n"
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_c_pre]
    mov rdx, 2
    syscall
    ; Write color name
    push r13
    mov rsi, [rbx + r13*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    mov r13, [rsp]
    mov rsi, [rbx + r13*8]
    syscall
    ; " = "
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    ; Write value
    mov r13, [rsp]
    movzx eax, byte [color_settings + r13]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    pop r13
    inc r13
    jmp .sc_color_loop

.sc_c_pre: db "c_"

.sc_settings:
    ; Write boolean/numeric settings
    ; show_tips
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_SHOW_TIPS)
    jz .sc_tips_false
    lea rsi, [.sc_show_tips_true]
    mov rdx, .sc_show_tips_true_len
    jmp .sc_tips_write
.sc_tips_false:
    lea rsi, [.sc_show_tips_false]
    mov rdx, .sc_show_tips_false_len
.sc_tips_write:
    syscall
    ; auto_correct
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_AUTO_CORRECT)
    jz .sc_ac_false
    lea rsi, [.sc_auto_correct_true]
    mov rdx, .sc_auto_correct_true_len
    jmp .sc_ac_write
.sc_ac_false:
    lea rsi, [.sc_auto_correct_false]
    mov rdx, .sc_auto_correct_false_len
.sc_ac_write:
    syscall
    ; auto_pair
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_AUTO_PAIR)
    jz .sc_ap_false
    lea rsi, [.sc_auto_pair_true]
    mov rdx, .sc_auto_pair_true_len
    jmp .sc_ap_write
.sc_ap_false:
    lea rsi, [.sc_auto_pair_false]
    mov rdx, .sc_auto_pair_false_len
.sc_ap_write:
    syscall
    ; rprompt
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_RPROMPT)
    jz .sc_rp_false
    lea rsi, [.sc_rprompt_true]
    mov rdx, .sc_rprompt_true_len
    jmp .sc_rp_write
.sc_rp_false:
    lea rsi, [.sc_rprompt_false]
    mov rdx, .sc_rprompt_false_len
.sc_rp_write:
    syscall
    ; show_git_branch
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_SHOW_GIT_BRANCH)
    jz .sc_gb_false
    lea rsi, [.sc_git_branch_true]
    mov rdx, .sc_git_branch_true_len
    jmp .sc_gb_write
.sc_gb_false:
    lea rsi, [.sc_git_branch_false]
    mov rdx, .sc_git_branch_false_len
.sc_gb_write:
    syscall
    ; git_status_fork
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_GIT_STATUS_FORK)
    jz .sc_gsf_false
    lea rsi, [.sc_gsf_true_str]
    mov rdx, .sc_gsf_true_str_len
    jmp .sc_gsf_write
.sc_gsf_false:
    lea rsi, [.sc_gsf_false_str]
    mov rdx, .sc_gsf_false_str_len
.sc_gsf_write:
    syscall
    ; completion_fuzzy
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_COMPLETION_FUZZY)
    jz .sc_cf_false
    lea rsi, [.sc_comp_fuzzy_true]
    mov rdx, .sc_comp_fuzzy_true_len
    jmp .sc_cf_write
.sc_cf_false:
    lea rsi, [.sc_comp_fuzzy_false]
    mov rdx, .sc_comp_fuzzy_false_len
.sc_cf_write:
    syscall
    ; history_dedup
    mov rax, SYS_WRITE
    mov rdi, r12
    test qword [config_flags], (1 << CFG_HIST_DEDUP_FULL)
    jnz .sc_hd_full
    test qword [config_flags], (1 << CFG_HIST_DEDUP_SMART)
    jnz .sc_hd_smart
    lea rsi, [.sc_hd_off]
    mov rdx, .sc_hd_off_len
    jmp .sc_hd_write
.sc_hd_full:
    lea rsi, [.sc_hd_full_str]
    mov rdx, .sc_hd_full_len
    jmp .sc_hd_write
.sc_hd_smart:
    lea rsi, [.sc_hd_smart_str]
    mov rdx, .sc_hd_smart_len
.sc_hd_write:
    syscall
    ; slow_command_threshold
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_slow_pre]
    mov rdx, .sc_slow_pre_len
    syscall
    mov rax, [slow_cmd_threshold]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall
    ; completion_limit
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [.sc_climit_pre]
    mov rdx, .sc_climit_pre_len
    syscall
    mov rax, [completion_limit]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, r12
    lea rsi, [newline]
    mov rdx, 1
    syscall

.sc_close:
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    ; Record save time
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    mov rsi, rsp
    syscall
    mov rax, [rsp]
    add rsp, 16
    ; Stat the file to get its mtime (filesystem time, not monotonic)
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [config_path]
    mov rsi, rsp
    syscall
    mov rax, [rsp + 88]
    mov [config_save_time], rax
    add rsp, 144

.sc_done:
    pop r13
    pop r12
    pop rbx
    ret

.sc_nick_pre: db "nick."
.sc_gnick_pre: db "gnick."
.sc_abbrev_pre: db "abbrev."
.sc_bm_pre: db "bm."
.sc_show_tips_true: db "show_tips = true", 10
.sc_show_tips_true_len equ $ - .sc_show_tips_true
.sc_show_tips_false: db "show_tips = false", 10
.sc_show_tips_false_len equ $ - .sc_show_tips_false
.sc_auto_correct_true: db "auto_correct = true", 10
.sc_auto_correct_true_len equ $ - .sc_auto_correct_true
.sc_auto_correct_false: db "auto_correct = false", 10
.sc_auto_correct_false_len equ $ - .sc_auto_correct_false
.sc_auto_pair_true: db "auto_pair = true", 10
.sc_auto_pair_true_len equ $ - .sc_auto_pair_true
.sc_auto_pair_false: db "auto_pair = false", 10
.sc_auto_pair_false_len equ $ - .sc_auto_pair_false
.sc_rprompt_true: db "rprompt = true", 10
.sc_rprompt_true_len equ $ - .sc_rprompt_true
.sc_rprompt_false: db "rprompt = false", 10
.sc_rprompt_false_len equ $ - .sc_rprompt_false
.sc_git_branch_true: db "show_git_branch = true", 10
.sc_git_branch_true_len equ $ - .sc_git_branch_true
.sc_git_branch_false: db "show_git_branch = false", 10
.sc_git_branch_false_len equ $ - .sc_git_branch_false
.sc_gsf_true_str: db "git_status_fork = true", 10
.sc_gsf_true_str_len equ $ - .sc_gsf_true_str
.sc_gsf_false_str: db "git_status_fork = false", 10
.sc_gsf_false_str_len equ $ - .sc_gsf_false_str
.sc_comp_fuzzy_true: db "completion_fuzzy = true", 10
.sc_comp_fuzzy_true_len equ $ - .sc_comp_fuzzy_true
.sc_comp_fuzzy_false: db "completion_fuzzy = false", 10
.sc_comp_fuzzy_false_len equ $ - .sc_comp_fuzzy_false
.sc_hd_off: db "history_dedup = off", 10
.sc_hd_off_len equ $ - .sc_hd_off
.sc_hd_full_str: db "history_dedup = full", 10
.sc_hd_full_len equ $ - .sc_hd_full_str
.sc_hd_smart_str: db "history_dedup = smart", 10
.sc_hd_smart_len equ $ - .sc_hd_smart_str
.sc_slow_pre: db "slow_command_threshold = "
.sc_slow_pre_len equ $ - .sc_slow_pre
.sc_climit_pre: db "completion_limit = "
.sc_climit_pre_len equ $ - .sc_climit_pre

; ══════════════════════════════════════════════════════════════════════
; Save undo state (snapshot of line_buf)
; Stores up to 4 snapshots in a circular buffer
; ══════════════════════════════════════════════════════════════════════
save_undo_state:
    push rbx
    push r12
    mov rax, [undo_count]
    cmp rax, 4
    jl .sus_ok
    ; Shift snapshots down (drop oldest)
    lea rdi, [undo_stack]
    lea rsi, [undo_stack + 4096]
    mov rcx, 4096 * 3
    rep movsb
    ; Shift positions
    mov rax, [undo_positions + 8]
    mov [undo_positions], rax
    mov rax, [undo_positions + 16]
    mov [undo_positions + 8], rax
    mov rax, [undo_positions + 24]
    mov [undo_positions + 16], rax
    mov qword [undo_count], 3
    mov rax, 3
.sus_ok:
    ; Copy line_buf to undo_stack[undo_count]
    imul rcx, rax, 4096
    lea rdi, [undo_stack + rcx]
    lea rsi, [line_buf]
    xor rcx, rcx
.sus_copy:
    mov bl, [rsi + rcx]
    mov [rdi + rcx], bl
    test bl, bl
    jz .sus_done
    inc rcx
    cmp rcx, 4095
    jge .sus_done
    jmp .sus_copy
.sus_done:
    mov byte [rdi + rcx], 0
    mov [undo_positions + rax*8], r12
    inc qword [undo_count]
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Check if line needs continuation (multi-line editing)
; Returns: rax = 1 if continuation needed, 0 if not
; Checks for: trailing \, trailing |, trailing &&, trailing ||,
; unclosed single/double quotes
; ══════════════════════════════════════════════════════════════════════
check_continuation:
    mov rcx, [line_len]
    test rcx, rcx
    jz .cc_no

    ; Check for trailing backslash
    dec rcx
    cmp byte [line_buf + rcx], '\'
    je .cc_yes

    ; Skip trailing spaces
.cc_skip_trail:
    test rcx, rcx
    jz .cc_check_quotes
    cmp byte [line_buf + rcx], ' '
    jne .cc_check_trail
    dec rcx
    jmp .cc_skip_trail

.cc_check_trail:
    ; Check for trailing |
    cmp byte [line_buf + rcx], '|'
    je .cc_yes
    ; Check for trailing && (need at least 2 chars)
    test rcx, rcx
    jz .cc_check_quotes
    cmp byte [line_buf + rcx], '&'
    jne .cc_check_quotes
    cmp byte [line_buf + rcx - 1], '&'
    je .cc_yes

.cc_check_quotes:
    ; Count unmatched quotes
    xor rcx, rcx             ; position
    xor edx, edx             ; single quote count
    xor r8d, r8d             ; double quote count
.cc_quote_loop:
    cmp rcx, [line_len]
    jge .cc_quote_done
    cmp byte [line_buf + rcx], 0x27
    jne .cc_not_sq
    inc edx
    jmp .cc_quote_next
.cc_not_sq:
    cmp byte [line_buf + rcx], '"'
    jne .cc_quote_next
    inc r8d
.cc_quote_next:
    inc rcx
    jmp .cc_quote_loop
.cc_quote_done:
    ; Odd number of either quote type means unclosed
    test edx, 1
    jnz .cc_yes
    test r8d, 1
    jnz .cc_yes

.cc_no:
    xor eax, eax
    ret
.cc_yes:
    mov eax, 1
    ret

; ══════════════════════════════════════════════════════════════════════
; Syntax highlighting: write line_buf with colors to stdout
; Colors the first word as command (check nick/builtin), switches as
; cyan, paths as yellow, and the rest as default command color.
; ══════════════════════════════════════════════════════════════════════
; Syntax highlighting: process line_buf char by char
; Colors: commands, colon commands, nicks, switches (-x), pipe chars
; Handles pipe segments (each | starts a new command context)
syntax_highlight_line:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r13, [line_len]
    test r13, r13
    jz .shl_done

    lea rdi, [suggestion_buf]
    xor rbx, rbx             ; output position
    xor rcx, rcx             ; input position
    mov r15, 1               ; r15 = 1 means "next word is a command"

.shl_char:
    cmp rcx, r13
    jge .shl_write_output
    movzx eax, byte [line_buf + rcx]

    ; Pipe: reset command flag for next segment
    cmp al, '|'
    jne .shl_not_pipe
    ; Check for || (not a pipe, it's OR)
    cmp rcx, r13
    jge .shl_copy_pipe
    cmp byte [line_buf + rcx + 1], '|'
    je .shl_copy_pipe
    ; Single pipe: copy it, set command flag
    mov [rdi + rbx], al
    inc rbx
    inc rcx
    ; Skip spaces after pipe
.shl_pipe_skip:
    cmp rcx, r13
    jge .shl_write_output
    cmp byte [line_buf + rcx], ' '
    jne .shl_pipe_cmd
    mov byte [rdi + rbx], ' '
    inc rbx
    inc rcx
    jmp .shl_pipe_skip
.shl_pipe_cmd:
    mov r15, 1               ; next word is command
    jmp .shl_char
.shl_copy_pipe:
    mov [rdi + rbx], al
    inc rbx
    inc rcx
    jmp .shl_char

.shl_not_pipe:
    ; Semicolon: also starts new command
    cmp al, ';'
    jne .shl_not_semi
    mov [rdi + rbx], al
    inc rbx
    inc rcx
    mov r15, 1
    jmp .shl_char
.shl_not_semi:

    ; Space: just copy
    cmp al, ' '
    jne .shl_not_space
    mov [rdi + rbx], al
    inc rbx
    inc rcx
    jmp .shl_char
.shl_not_space:

    ; If this is a command position (r15=1), color the word
    test r15, r15
    jz .shl_not_cmd

    ; Determine command color
    mov r14, rcx             ; save word start
    ; Find word end
.shl_cmd_end:
    cmp rcx, r13
    jge .shl_cmd_color
    cmp byte [line_buf + rcx], ' '
    je .shl_cmd_color
    cmp byte [line_buf + rcx], '|'
    je .shl_cmd_color
    cmp byte [line_buf + rcx], ';'
    je .shl_cmd_color
    inc rcx
    jmp .shl_cmd_end
.shl_cmd_color:
    ; rcx = word end, r14 = word start
    push rcx
    ; Determine command color by type
    ; First, copy the word to num_buf for null-terminated lookup
    push rcx
    mov rdx, r14
    lea rdi, [num_buf]
.shl_cmd_extract:
    cmp rdx, [rsp]
    jge .shl_cmd_null
    movzx eax, byte [line_buf + rdx]
    mov [rdi], al
    inc rdi
    inc rdx
    jmp .shl_cmd_extract
.shl_cmd_null:
    mov byte [rdi], 0
    pop rcx

    ; Check type: colon command, nick, builtin, executable, or unknown
    cmp byte [line_buf + r14], ':'
    je .shl_cmd_is_colon

    ; Check if it's a nick
    push rcx
    lea rdi, [num_buf]
    call is_nick_name
    pop rcx
    test rax, rax
    jnz .shl_cmd_is_nick

    ; Check if it's a builtin (cd, exit, pwd, export, unset, history, time, pushd, popd)
    push rcx
    lea rdi, [num_buf]
    call .shl_is_builtin
    pop rcx
    test rax, rax
    jnz .shl_cmd_is_exe

    ; Check if it's in exe cache
    push rcx
    lea rdi, [num_buf]
    call is_exe_cached
    pop rcx
    test rax, rax
    jnz .shl_cmd_is_exe

    ; If path contains '/', check if file is executable via stat
    lea rsi, [num_buf]
.shl_check_path_slash:
    movzx eax, byte [rsi]
    test al, al
    jz .shl_cmd_no_color         ; no slash, unknown command
    cmp al, '/'
    je .shl_check_stat
    inc rsi
    jmp .shl_check_path_slash
.shl_check_stat:
    ; stat the file to check if it exists and is executable
    push rcx
    sub rsp, 144                 ; struct stat
    mov rax, SYS_STAT
    lea rdi, [num_buf]
    mov rsi, rsp
    syscall
    test rax, rax
    js .shl_stat_fail
    ; Check it's a regular file (not directory) and executable
    mov eax, [rsp + 24]         ; st_mode
    mov ecx, eax
    and ecx, 0xF000             ; S_IFMT mask
    cmp ecx, 0x8000             ; S_IFREG (regular file)
    jne .shl_stat_fail
    test eax, 0o100             ; S_IXUSR
    jz .shl_stat_fail
    add rsp, 144
    pop rcx
    jmp .shl_cmd_is_exe
.shl_stat_fail:
    add rsp, 144
    pop rcx

    ; Unknown command: copy without color
    jmp .shl_cmd_no_color

.shl_cmd_is_colon:
    movzx eax, byte [color_settings + C_COLON]
    jmp .shl_cmd_apply_color
.shl_cmd_is_nick:
    movzx eax, byte [color_settings + C_NICK]
    jmp .shl_cmd_apply_color
.shl_cmd_is_exe:
    movzx eax, byte [color_settings + C_CMD]

.shl_cmd_apply_color:
    push rax
    lea rdi, [suggestion_buf + rbx]
    call write_fg_color
    add rbx, rax
    pop rax
    lea rdi, [suggestion_buf]
    mov rcx, [rsp]
    mov rdx, r14
.shl_cmd_copy:
    cmp rdx, rcx
    jge .shl_cmd_reset
    movzx eax, byte [line_buf + rdx]
    mov [rdi + rbx], al
    inc rbx
    inc rdx
    jmp .shl_cmd_copy
.shl_cmd_reset:
    mov byte [rdi + rbx], 27
    mov byte [rdi + rbx + 1], '['
    mov byte [rdi + rbx + 2], '0'
    mov byte [rdi + rbx + 3], 'm'
    add rbx, 4
    pop rcx
    mov r15, 0
    jmp .shl_char

.shl_cmd_no_color:
    lea rdi, [suggestion_buf]
    mov rcx, [rsp]
    mov rdx, r14
.shl_plain_copy:
    cmp rdx, rcx
    jge .shl_plain_done
    movzx eax, byte [line_buf + rdx]
    mov [rdi + rbx], al
    inc rbx
    inc rdx
    jmp .shl_plain_copy
.shl_plain_done:
    pop rcx
    mov r15, 0
    jmp .shl_char

; Check if num_buf is a builtin command. rdi = word. Returns rax=1/0.
.shl_is_builtin:
    push rsi
    lea rsi, [str_cd]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_exit]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_pwd]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_export]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_unset]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_history]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_time]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_pushd]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    lea rsi, [str_popd]
    call strcmp
    test rax, rax
    jz .shl_bi_yes
    pop rsi
    xor eax, eax
    ret
.shl_bi_yes:
    pop rsi
    mov eax, 1
    ret

.shl_not_cmd:
    ; Switch coloring (-x or --x)
    cmp al, '-'
    jne .shl_not_switch
    test rcx, rcx
    jz .shl_not_switch
    cmp byte [line_buf + rcx - 1], ' '
    jne .shl_not_switch
    ; Color switch
    push rcx
    movzx eax, byte [color_settings + C_SWITCH]
    lea rdi, [suggestion_buf + rbx]
    call write_fg_color
    add rbx, rax
    pop rcx
    lea rdi, [suggestion_buf]
.shl_sw_ch:
    cmp rcx, r13
    jge .shl_sw_reset
    movzx eax, byte [line_buf + rcx]
    cmp al, ' '
    je .shl_sw_reset
    mov [rdi + rbx], al
    inc rbx
    inc rcx
    jmp .shl_sw_ch
.shl_sw_reset:
    mov byte [rdi + rbx], 27
    mov byte [rdi + rbx + 1], '['
    mov byte [rdi + rbx + 2], '0'
    mov byte [rdi + rbx + 3], 'm'
    add rbx, 4
    jmp .shl_char

.shl_not_switch:
    ; Default: copy character as-is
    lea rdi, [suggestion_buf]
    mov [rdi + rbx], al
    inc rbx
    inc rcx
    jmp .shl_char

.shl_write_output:
    lea rdi, [suggestion_buf]
    ; Final reset
    mov byte [rdi + rbx], 27
    mov byte [rdi + rbx + 1], '['
    mov byte [rdi + rbx + 2], '0'
    mov byte [rdi + rbx + 3], 'm'
    add rbx, 4
    ; Save output length for batched callers
    mov [shl_output_len], rbx
    ; Write (unless caller will batch)
    cmp qword [render_to_buf], 0
    jnz .shl_done
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [suggestion_buf]
    mov rdx, rbx
    syscall

.shl_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Tab complete $VAR from environment
; ══════════════════════════════════════════════════════════════════════
; Tab complete switches by running "command --help" and parsing output
; Reads first word from line_buf as the command name.
; Matches switches starting with tab_word_buf prefix.
; ══════════════════════════════════════════════════════════════════════
tab_complete_switch:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov qword [tab_count], 0
    mov qword [tab_buf_pos], 0

    ; Extract command name (first word of line_buf)
    lea rsi, [line_buf]
    lea rdi, [switch_cmd_buf]
    xor ecx, ecx
.tcs_copy_cmd:
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .tcs_cmd_done
    cmp al, ' '
    je .tcs_cmd_done
    mov [rdi + rcx], al
    inc rcx
    cmp rcx, 250
    jge .tcs_cmd_done
    jmp .tcs_copy_cmd
.tcs_cmd_done:
    mov byte [rdi + rcx], 0
    test rcx, rcx
    jz .tcs_done

    ; Get prefix length
    lea rdi, [tab_word_buf]
    call strlen
    mov r13, rax             ; prefix length

    ; Create pipe
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    jnz .tcs_done

    ; Fork
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .tcs_child
    js .tcs_close_pipe

    ; Parent: close write end, read output
    mov r15, rax             ; child pid
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall

    ; Read help output into switch_help_buf
    xor r12, r12             ; total bytes read
.tcs_read_loop:
    mov rax, SYS_READ
    mov edi, [pipe_fds]
    lea rsi, [switch_help_buf + r12]
    mov rdx, 4096
    mov rcx, 16384
    sub rcx, r12
    cmp rdx, rcx
    jle .tcs_read_ok
    mov rdx, rcx
    test rdx, rdx
    jle .tcs_read_done
.tcs_read_ok:
    syscall
    test rax, rax
    jle .tcs_read_done
    add r12, rax
    jmp .tcs_read_loop
.tcs_read_done:
    mov byte [switch_help_buf + r12], 0

    ; Close read end
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall

    ; Wait for child
    sub rsp, 16
    mov rax, SYS_WAIT4
    mov rdi, r15
    lea rsi, [rsp]
    xor edx, edx
    xor r10d, r10d
    syscall
    add rsp, 16

    ; Parse help output for switches
    lea rsi, [switch_help_buf]
    mov r14, r12             ; total bytes
.tcs_parse:
    ; Find next '-' that follows whitespace or start-of-line
    cmp rsi, switch_help_buf
    jl .tcs_done
    lea rax, [switch_help_buf + r14]
    cmp rsi, rax
    jge .tcs_done
.tcs_scan_dash:
    lea rax, [switch_help_buf + r14]
    cmp rsi, rax
    jge .tcs_done
    cmp byte [rsi], '-'
    jne .tcs_scan_next
    ; Check previous char is whitespace or start
    cmp rsi, switch_help_buf
    je .tcs_found_switch
    movzx eax, byte [rsi - 1]
    cmp al, ' '
    je .tcs_found_switch
    cmp al, 9
    je .tcs_found_switch
    cmp al, 10
    je .tcs_found_switch
    cmp al, ','
    je .tcs_found_switch
    cmp al, '['
    je .tcs_found_switch
    cmp al, '('
    je .tcs_found_switch
.tcs_scan_next:
    inc rsi
    jmp .tcs_scan_dash

.tcs_found_switch:
    ; Validate: char after initial dash(es) must be a letter
    ; Skip leading dashes
    push rsi
    mov rdi, rsi
    xor ecx, ecx
    cmp byte [rdi], '-'
    jne .tcs_sw_invalid
    inc ecx
    cmp byte [rdi + 1], '-'
    jne .tcs_sw_check_alpha
    inc ecx
.tcs_sw_check_alpha:
    movzx eax, byte [rdi + rcx]
    ; Must be a letter after the dashes
    cmp al, 'a'
    jb .tcs_sw_check_upper
    cmp al, 'z'
    jbe .tcs_sw_valid
.tcs_sw_check_upper:
    cmp al, 'A'
    jb .tcs_sw_invalid
    cmp al, 'Z'
    jbe .tcs_sw_valid
.tcs_sw_invalid:
    pop rsi
    inc rsi
    jmp .tcs_parse
.tcs_sw_valid:
    pop rsi
    ; Extract switch word (until space, comma, =, ], ), <, newline, or null)
    push rsi                 ; save start
    mov rdi, rsi
    xor ecx, ecx
.tcs_sw_len:
    movzx eax, byte [rdi + rcx]
    test al, al
    jz .tcs_sw_end
    cmp al, ' '
    je .tcs_sw_end
    cmp al, ','
    je .tcs_sw_end
    cmp al, '='
    je .tcs_sw_end
    cmp al, '['
    je .tcs_sw_end
    cmp al, ']'
    je .tcs_sw_end
    cmp al, '('
    je .tcs_sw_end
    cmp al, ')'
    je .tcs_sw_end
    cmp al, '<'
    je .tcs_sw_end
    cmp al, 10
    je .tcs_sw_end
    cmp al, 9
    je .tcs_sw_end
    inc rcx
    cmp rcx, 60
    jge .tcs_sw_end
    jmp .tcs_sw_len
.tcs_sw_end:
    ; rcx = switch length, rdi = switch start
    pop rsi                  ; restore scan position
    test rcx, rcx
    jz .tcs_sw_skip
    cmp rcx, 1
    jle .tcs_sw_skip         ; just "-" alone, skip

    ; Check if it matches our prefix
    push rcx
    push rsi
    xor ebx, ebx
.tcs_prefix_cmp:
    cmp rbx, r13
    jge .tcs_prefix_match
    cmp rbx, rcx
    jge .tcs_prefix_no
    movzx eax, byte [tab_word_buf + rbx]
    cmp al, [rdi + rbx]
    jne .tcs_prefix_no
    inc rbx
    jmp .tcs_prefix_cmp

.tcs_prefix_match:
    ; Check for duplicates
    push rdi
    push rcx
    ; Null-terminate switch in a temp buffer
    lea rdi, [switch_tmp_buf]
    pop r12                  ; rcx = length
    push r12
    mov rsi, [rsp + 16]      ; original rdi (switch start, from stack)
    ; Actually, let me simplify: copy to temp, null-terminate
    xor ebx, ebx
.tcs_cp_sw:
    cmp rbx, r12
    jge .tcs_cp_sw_done
    movzx eax, byte [rsi + rbx]
    mov [rdi + rbx], al
    inc rbx
    jmp .tcs_cp_sw
.tcs_cp_sw_done:
    mov byte [rdi + rbx], 0
    ; Check dedup
    lea rdi, [switch_tmp_buf]
    xor ebx, ebx
.tcs_dedup_loop:
    cmp rbx, [tab_count]
    jge .tcs_dedup_ok
    push rbx
    push rdi
    mov rsi, [tab_results + rbx*8]
    call strcmp
    pop rdi
    pop rbx
    test rax, rax
    jz .tcs_dedup_skip
    inc rbx
    jmp .tcs_dedup_loop

.tcs_dedup_ok:
    ; Add to results
    cmp qword [tab_count], MAX_TAB_RESULTS - 1
    jge .tcs_dedup_skip
    mov rcx, [tab_buf_pos]
    lea rbx, [tab_buf + rcx]
    lea rsi, [switch_tmp_buf]
    mov rdi, rbx
.tcs_store_copy:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .tcs_store_done
    inc rsi
    inc rdi
    jmp .tcs_store_copy
.tcs_store_done:
    mov byte [rdi], 0
    ; Calculate new buf_pos
    lea rdi, [switch_tmp_buf]
    call strlen
    inc rax
    add rax, [tab_buf_pos]
    mov [tab_buf_pos], rax
    mov rax, [tab_count]
    mov [tab_results + rax*8], rbx
    mov byte [tab_types + rax], 0    ; no d_type for switches
    inc qword [tab_count]

.tcs_dedup_skip:
    pop rcx
    pop rdi
    pop rsi
    pop rcx
    jmp .tcs_sw_advance

.tcs_prefix_no:
    pop rsi
    pop rcx

.tcs_sw_skip:
.tcs_sw_advance:
    add rsi, rcx
    test rcx, rcx
    jz .tcs_sw_inc1
    jmp .tcs_parse
.tcs_sw_inc1:
    inc rsi
    jmp .tcs_parse

.tcs_close_pipe:
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
.tcs_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.tcs_child:
    ; Child: redirect stdout and stderr to write end of pipe
    ; Close stdin so commands without --help exit immediately
    mov rax, SYS_OPEN
    lea rdi, [.tcs_devnull]
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .tcs_child_skip_stdin
    mov rbx, rax             ; save /dev/null fd
    mov rax, SYS_DUP2
    mov edi, ebx
    xor esi, esi             ; stdin = 0
    syscall
    mov rax, SYS_CLOSE
    mov edi, ebx             ; close original /dev/null fd
    syscall
.tcs_child_skip_stdin:
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]      ; close read end
    syscall
    ; dup2(write_fd, 1)
    mov rax, SYS_DUP2
    mov edi, [pipe_fds + 4]
    mov esi, 1
    syscall
    ; dup2(write_fd, 2) - merge stderr
    mov rax, SYS_DUP2
    mov edi, [pipe_fds + 4]
    mov esi, 2
    syscall
    ; close original write fd
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    ; exec command with --help
    ; Build argv: [cmd_path, "--help", NULL]
    lea rdi, [switch_cmd_buf]
    call find_in_path
    test rax, rax
    jz .tcs_child_exit
    ; Path is in exec_path buffer
    ; argv on stack
    sub rsp, 32
    lea rax, [exec_path]
    mov [rsp], rax           ; argv[0] = full path
    lea rax, [.tcs_help_str]
    mov [rsp + 8], rax       ; argv[1] = "--help"
    mov qword [rsp + 16], 0  ; argv[2] = NULL
    ; execve
    mov rdi, [rsp]           ; path
    mov rsi, rsp             ; argv
    mov rdx, [envp]          ; envp
    mov rax, SYS_EXECVE
    syscall
.tcs_child_exit:
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall
.tcs_help_str: db "--help", 0
.tcs_devnull: db "/dev/null", 0

; rdi = word starting with $
; ══════════════════════════════════════════════════════════════════════
; Tab complete $VAR: search env_array for vars matching prefix
; rdi = tab_word_buf containing "$PREFIX"
tab_complete_var:
    push rbx
    push r12
    push r13
    push r14

    ; Extract prefix after $
    mov r12, rdi             ; r12 = tab_word_buf ("$HO")
    lea r13, [rdi + 1]       ; r13 = prefix ("HO")
    mov rdi, r13
    call strlen
    mov r14, rax             ; r14 = prefix length (2 for "HO")

    mov qword [tab_count], 0
    mov qword [tab_buf_pos], 0

    xor r12, r12             ; loop counter
.tcv_loop:
    cmp r12, [env_count]
    jge .tcv_done
    mov rsi, [env_array + r12*8]
    test rsi, rsi
    jz .tcv_next

    ; Compare prefix against env var name
    xor rcx, rcx
.tcv_cmp:
    cmp rcx, r14
    jge .tcv_prefix_match    ; all prefix chars matched
    movzx eax, byte [r13 + rcx]  ; prefix char
    movzx edx, byte [rsi + rcx]  ; env var char
    cmp dl, '='              ; hit = before prefix ended = no match
    je .tcv_next
    test dl, dl              ; hit null before prefix ended = no match
    jz .tcv_next
    cmp al, dl
    jne .tcv_next
    inc rcx
    jmp .tcv_cmp

.tcv_prefix_match:
    ; env var at rsi starts with our prefix
    ; Extract var name (up to '=') and store as "$VARNAME"
    cmp qword [tab_count], MAX_TAB_RESULTS - 1
    jge .tcv_next

    ; Write "$" + varname to tab_buf at current position
    mov rax, [tab_buf_pos]
    lea rdi, [tab_buf + rax]
    ; Store pointer in tab_results
    mov rbx, [tab_count]
    mov [tab_results + rbx*8], rdi

    ; Write $
    mov byte [rdi], 0x24     ; '$'
    inc rdi

    ; Copy var name from env entry until '='
    xor rcx, rcx
.tcv_copy:
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .tcv_copied
    cmp al, '='
    je .tcv_copied
    mov [rdi + rcx], al
    inc rcx
    jmp .tcv_copy
.tcv_copied:
    mov byte [rdi + rcx], 0  ; null terminate
    ; Update tab_buf_pos: $ + name + null = rcx + 2
    lea rax, [rcx + 2]
    add [tab_buf_pos], rax
    inc qword [tab_count]

.tcv_next:
    inc r12
    jmp .tcv_loop

.tcv_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Check for subcommand completion (git, apt, cargo)
; Returns rax=1 if handled (results in tab_results), 0 if not
; ══════════════════════════════════════════════════════════════════════
check_subcommand_completion:
    push rbx
    push r12
    lea rdi, [line_buf]
    xor rcx, rcx
.csc_find_end:
    cmp rcx, [line_len]
    jge .csc_no
    cmp byte [line_buf + rcx], ' '
    je .csc_got_cmd
    inc rcx
    jmp .csc_find_end
.csc_got_cmd:
    test rcx, rcx
    jz .csc_no
    cmp rcx, 3
    jne .csc_not3
    cmp word [line_buf], 'gi'
    jne .csc_try_apt
    cmp byte [line_buf + 2], 't'
    jne .csc_try_apt
    lea rsi, [.git_subcmds]
    jmp .csc_complete
.csc_try_apt:
    cmp word [line_buf], 'ap'
    jne .csc_not3
    cmp byte [line_buf + 2], 't'
    jne .csc_not3
    lea rsi, [.apt_subcmds]
    jmp .csc_complete
.csc_not3:
    cmp rcx, 5
    jne .csc_no
    cmp dword [line_buf], 'carg'
    jne .csc_no
    cmp byte [line_buf + 4], 'o'
    jne .csc_no
    lea rsi, [.cargo_subcmds]
.csc_complete:
    mov qword [tab_count], 0
    mov qword [tab_buf_pos], 0
    lea rdi, [tab_word_buf]
    push rdi
    call strlen
    mov r12, rax
    pop rdi
.csc_scan:
    cmp byte [rsi], 0
    je .csc_end_list
    push rsi
    xor rcx, rcx
    test r12, r12
    jz .csc_match
.csc_cmp:
    cmp rcx, r12
    jge .csc_match
    movzx eax, byte [rdi + rcx]
    cmp al, [rsi + rcx]
    jne .csc_skip
    inc rcx
    jmp .csc_cmp
.csc_match:
    cmp qword [tab_count], MAX_TAB_RESULTS - 1
    jge .csc_skip
    mov rsi, [rsp]
    mov rax, [tab_buf_pos]
    lea rbx, [tab_buf + rax]
    mov rcx, [tab_count]
    mov [tab_results + rcx*8], rbx
    push rsi
.csc_copy:
    movzx eax, byte [rsi]
    mov [rbx], al
    test al, al
    jz .csc_copied
    inc rsi
    inc rbx
    jmp .csc_copy
.csc_copied:
    pop rsi
    inc qword [tab_count]
    lea rax, [rbx + 1]
    sub rax, tab_buf
    mov [tab_buf_pos], rax
.csc_skip:
    pop rsi
.csc_adv:
    cmp byte [rsi], 0
    je .csc_past_null
    inc rsi
    jmp .csc_adv
.csc_past_null:
    inc rsi
    cmp byte [rsi], 0
    jne .csc_scan
.csc_end_list:
    cmp qword [tab_count], 0
    je .csc_no
    mov rax, 1
    pop r12
    pop rbx
    ret
.csc_no:
    xor eax, eax
    pop r12
    pop rbx
    ret

.git_subcmds: db "add",0,"branch",0,"checkout",0,"clone",0,"commit",0,"diff",0,"fetch",0
              db "init",0,"log",0,"merge",0,"pull",0,"push",0,"rebase",0,"remote",0
              db "reset",0,"restore",0,"show",0,"stash",0,"status",0,"switch",0,"tag",0,0
.apt_subcmds: db "install",0,"remove",0,"update",0,"upgrade",0,"search",0,"show",0
              db "list",0,"autoremove",0,"purge",0,0
.cargo_subcmds: db "build",0,"check",0,"clean",0,"doc",0,"init",0,"new",0,"run",0
                db "test",0,"bench",0,"update",0,"publish",0,"install",0,"fmt",0,"clippy",0,0

; ══════════════════════════════════════════════════════════════════════
; :calc - integer calculator
; ══════════════════════════════════════════════════════════════════════
handle_calc:
    push rbx
    push r12
    mov r12, rdi
    lea rdi, [nick_expand_buf]
    mov rcx, 1
    xor rbx, rbx
.hcalc_build:
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .hcalc_eval
    cmp rcx, 1
    je .hcalc_no_sp
    mov byte [rdi + rbx], ' '
    inc rbx
.hcalc_no_sp:
.hcalc_copy:
    movzx eax, byte [rsi]
    test al, al
    jz .hcalc_next
    mov [rdi + rbx], al
    inc rbx
    inc rsi
    jmp .hcalc_copy
.hcalc_next:
    inc rcx
    jmp .hcalc_build
.hcalc_eval:
    mov byte [rdi + rbx], 0
    test rbx, rbx
    jz .hcalc_done
    lea rsi, [nick_expand_buf]
    call calc_eval
    push rax
    lea rdi, [num_buf]
    test rax, rax
    jns .hcalc_pos
    neg rax
    mov byte [num_buf], '-'
    lea rdi, [num_buf + 1]
.hcalc_pos:
    call itoa
    pop rdx
    test rdx, rdx
    jns .hcalc_pr
    inc rax
.hcalc_pr:
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    call write_nl
.hcalc_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

; Left-to-right integer eval: num op num op ...
; rsi = expression, returns rax
calc_eval:
    push rbx
    push r12
    push r13
    mov r12, rsi
    call .ce_num
    mov r13, rax
.ce_op:
    cmp byte [r12], ' '
    jne .ce_check
    inc r12
    jmp .ce_op
.ce_check:
    cmp byte [r12], 0
    je .ce_ret
    movzx ebx, byte [r12]
    inc r12
.ce_skip:
    cmp byte [r12], ' '
    jne .ce_num2
    inc r12
    jmp .ce_skip
.ce_num2:
    call .ce_num
    cmp bl, '+'
    je .ce_add
    cmp bl, '-'
    je .ce_sub
    cmp bl, '*'
    je .ce_mul
    cmp bl, '/'
    je .ce_div
    cmp bl, '%'
    je .ce_mod
    jmp .ce_ret
.ce_add: add r13, rax
    jmp .ce_op
.ce_sub: sub r13, rax
    jmp .ce_op
.ce_mul: imul r13, rax
    jmp .ce_op
.ce_div:
    test rax, rax
    jz .ce_ret
    xchg rax, r13
    cqo
    idiv r13
    mov r13, rax
    jmp .ce_op
.ce_mod:
    test rax, rax
    jz .ce_ret
    xchg rax, r13
    cqo
    idiv r13
    mov r13, rdx
    jmp .ce_op
.ce_ret:
    mov rax, r13
    pop r13
    pop r12
    pop rbx
    ret
.ce_num:
    xor rax, rax
    xor ecx, ecx
    cmp byte [r12], '-'
    jne .cen_loop
    mov ecx, 1
    inc r12
.cen_loop:
    movzx edx, byte [r12]
    sub dl, '0'
    js .cen_done
    cmp dl, 9
    ja .cen_done
    imul rax, 10
    movzx edx, dl
    add rax, rdx
    inc r12
    jmp .cen_loop
.cen_done:
    test ecx, ecx
    jz .cen_ret
    neg rax
.cen_ret:
    ret

; ══════════════════════════════════════════════════════════════════════
; :stats - command frequency from history
; ══════════════════════════════════════════════════════════════════════
handle_stats:
    push rbx
    push r12
    push r13
    mov qword [cmd_freq_count], 0
    xor r12, r12
.hs_loop:
    cmp r12, [hist_count]
    jge .hs_display
    mov rsi, [hist_lines + r12*8]
    test rsi, rsi
    jz .hs_next
    lea rdi, [search_buf]
    xor rcx, rcx
.hs_cmd:
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .hs_got
    cmp al, ' '
    je .hs_got
    mov [rdi + rcx], al
    inc rcx
    cmp rcx, 250
    jge .hs_got
    jmp .hs_cmd
.hs_got:
    mov byte [rdi + rcx], 0
    test rcx, rcx
    jz .hs_next
    xor r13, r13
.hs_find:
    cmp r13, [cmd_freq_count]
    jge .hs_add
    push r13
    mov rdi, [cmd_freq_names + r13*8]
    lea rsi, [search_buf]
    call strcmp
    pop r13
    test rax, rax
    jz .hs_inc
    inc r13
    jmp .hs_find
.hs_inc:
    inc qword [cmd_freq_counts + r13*8]
    jmp .hs_next
.hs_add:
    cmp r13, 127
    jge .hs_next
    lea rdi, [cmd_freq_storage]
    test r13, r13
    jz .hs_store
    mov rdi, [cmd_freq_names + r13*8 - 8]
    push rax
    call strlen
    add rdi, rax
    inc rdi
    pop rax
.hs_store:
    mov [cmd_freq_names + r13*8], rdi
    lea rsi, [search_buf]
    call strcpy_rsi_rdi
    mov qword [cmd_freq_counts + r13*8], 1
    inc qword [cmd_freq_count]
.hs_next:
    inc r12
    jmp .hs_loop
.hs_display:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hs_hdr]
    mov rdx, .hs_hdr_len
    syscall
    xor r12, r12
.hs_show:
    cmp r12, 20
    jge .hs_end
    xor r13, r13
    mov rbx, -1
    xor rcx, rcx
.hs_max:
    cmp r13, [cmd_freq_count]
    jge .hs_best
    mov rax, [cmd_freq_counts + r13*8]
    cmp rax, rcx
    jle .hs_mx_next
    mov rcx, rax
    mov rbx, r13
.hs_mx_next:
    inc r13
    jmp .hs_max
.hs_best:
    cmp rbx, -1
    je .hs_end
    push rbx
    mov rax, [cmd_freq_counts + rbx*8]
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hs_sp]
    mov rdx, 2
    syscall
    mov rbx, [rsp]
    mov rsi, [cmd_freq_names + rbx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rbx, [rsp]
    mov rsi, [cmd_freq_names + rbx*8]
    syscall
    call write_nl
    pop rbx
    mov qword [cmd_freq_counts + rbx*8], 0
    inc r12
    jmp .hs_show
.hs_end:
    mov qword [last_status], 0
    pop r13
    pop r12
    pop rbx
    ret
.hs_hdr: db "Top commands:", 10
.hs_hdr_len equ $ - .hs_hdr
.hs_sp: db "  "

; ══════════════════════════════════════════════════════════════════════
; :validate [pattern = action | -N | --templates]
; ══════════════════════════════════════════════════════════════════════
handle_validate:
    push rbx
    push r12
    mov r12, rdi
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hv_list
    cmp byte [rdi], '-'
    je .hv_delete
    ; Add: pattern = action
    lea rbx, [nick_expand_buf]
    mov rcx, 1
    xor rax, rax
.hv_build:
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .hv_done
    cmp byte [rsi], '='
    je .hv_eq
    test rax, rax
    jz .hv_nsp
    mov byte [rbx + rax], ' '
    inc rax
.hv_nsp:
.hv_cpa:
    movzx edx, byte [rsi]
    test dl, dl
    jz .hv_cpa_d
    mov [rbx + rax], dl
    inc rax
    inc rsi
    jmp .hv_cpa
.hv_cpa_d:
    inc rcx
    jmp .hv_build
.hv_eq:
    mov byte [rbx + rax], 0
    inc rcx
    mov rsi, [r12 + rcx*8]
    test rsi, rsi
    jz .hv_done
    mov rax, [valid_count]
    cmp rax, 31
    jge .hv_done
    ; Store pattern
    lea rdi, [valid_storage]
    test rax, rax
    jz .hv_sp
    mov rdi, [valid_patterns + rax*8 - 8]
    push rax
    call strlen
    add rdi, rax
    inc rdi
    pop rax
.hv_sp:
    mov [valid_patterns + rax*8], rdi
    push rsi
    push rax
    lea rsi, [nick_expand_buf]
.hv_cpp:
    movzx edx, byte [rsi]
    mov [rdi], dl
    test dl, dl
    jz .hv_cpd
    inc rsi
    inc rdi
    jmp .hv_cpp
.hv_cpd:
    pop rax
    pop rsi
    cmp byte [rsi], 'b'
    je .hv_blk
    cmp byte [rsi], 'c'
    je .hv_cfm
    mov byte [valid_actions + rax], 0
    jmp .hv_vinc
.hv_cfm: mov byte [valid_actions + rax], 1
    jmp .hv_vinc
.hv_blk: mov byte [valid_actions + rax], 2
.hv_vinc:
    inc qword [valid_count]
    jmp .hv_done
.hv_delete:
    inc rdi
    cmp byte [rdi], '-'
    je .hv_tmpl
    call parse_int
    dec rax
    cmp rax, [valid_count]
    jge .hv_done
    mov rcx, rax
    mov rdx, [valid_count]
    dec rdx
    mov [valid_count], rdx
.hv_ds:
    cmp rcx, rdx
    jge .hv_done
    mov rbx, [valid_patterns + rcx*8 + 8]
    mov [valid_patterns + rcx*8], rbx
    movzx ebx, byte [valid_actions + rcx + 1]
    mov [valid_actions + rcx], bl
    inc rcx
    jmp .hv_ds
.hv_tmpl:
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hv_tt]
    mov rdx, .hv_tt_len
    syscall
    jmp .hv_done
.hv_list:
    xor rcx, rcx
.hv_ll:
    cmp rcx, [valid_count]
    jge .hv_done
    push rcx
    mov rax, rcx
    inc rax
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [num_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hv_dot]
    mov rdx, 2
    syscall
    mov rcx, [rsp]
    mov rsi, [valid_patterns + rcx*8]
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    mov rsi, [valid_patterns + rcx*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [nick_arrow]
    mov rdx, 3
    syscall
    mov rcx, [rsp]
    movzx eax, byte [valid_actions + rcx]
    lea rsi, [.hv_w]
    test al, al
    jz .hv_pa
    lea rsi, [.hv_c]
    cmp al, 1
    je .hv_pa
    lea rsi, [.hv_b]
.hv_pa:
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 1
    mov rcx, [rsp]
    syscall
    call write_nl
    pop rcx
    inc rcx
    jmp .hv_ll
.hv_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret
.hv_dot: db ". "
.hv_w: db "warn", 0
.hv_c: db "confirm", 0
.hv_b: db "block", 0
.hv_tt: db "Examples:", 10, "  :validate rm -rf = confirm", 10
        db "  :validate DROP TABLE = block", 10
.hv_tt_len equ $ - .hv_tt

; ══════════════════════════════════════════════════════════════════════
; Source a file: read it, execute each line
; rdi = path to file
; ══════════════════════════════════════════════════════════════════════
source_file:
    push rbx
    push r12
    push r13

    ; Open file
    mov rax, SYS_OPEN
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .sf_done              ; file not found, skip silently

    mov rbx, rax             ; fd
    ; Read into session_buf (reuse)
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [session_buf]
    mov rdx, 16383
    syscall
    push rax                 ; bytes read
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax
    test rax, rax
    jle .sf_done

    mov byte [session_buf + rax], 0

    ; Execute line by line
    lea r12, [session_buf]
.sf_next_line:
    cmp byte [r12], 0
    je .sf_done
    ; Skip blank lines and comments
    cmp byte [r12], 10
    je .sf_skip_nl
    cmp byte [r12], '#'
    je .sf_skip_comment

    ; Find end of line
    mov r13, r12
.sf_find_eol:
    cmp byte [r13], 0
    je .sf_got_line
    cmp byte [r13], 10
    je .sf_got_line
    inc r13
    jmp .sf_find_eol
.sf_got_line:
    ; Save and null-terminate
    movzx ebx, byte [r13]
    mov byte [r13], 0
    ; Copy line to line_buf
    lea rdi, [line_buf]
    mov rsi, r12
    xor rcx, rcx
.sf_copy:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .sf_exec
    inc rcx
    jmp .sf_copy
.sf_exec:
    mov [line_len], rcx
    ; Check if line starts with "export " - handle directly to avoid ; splitting
    cmp dword [line_buf], 'expo'
    jne .sf_normal_exec
    cmp word [line_buf + 4], 'rt'
    jne .sf_normal_exec
    cmp byte [line_buf + 6], ' '
    jne .sf_normal_exec
    ; Direct export: pass VAR=VALUE to env_set_entry
    lea rdi, [line_buf + 7]
    push r12
    push r13
    push rbx
    call env_set_entry
    jmp .sf_exec_done

.sf_normal_exec:
    ; Expand and execute
    push r12
    push r13
    push rbx
    call expand_line
    mov rdi, line_buf
    call execute_chained_line
.sf_exec_done:
    pop rbx
    pop r13
    pop r12
    ; Restore newline
    mov [r13], bl
    cmp bl, 10
    jne .sf_done
    lea r12, [r13 + 1]
    jmp .sf_next_line

.sf_skip_nl:
    inc r12
    jmp .sf_next_line
.sf_skip_comment:
    ; Skip to next line
.sf_skip_to_nl:
    cmp byte [r12], 0
    je .sf_done
    cmp byte [r12], 10
    je .sf_skip_nl
    inc r12
    jmp .sf_skip_to_nl

.sf_done:
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Right prompt: show command duration on the right side of the terminal
; Called after command execution if rprompt is enabled
; ══════════════════════════════════════════════════════════════════════
show_rprompt:
    push rbx
    push r12
    push r13

    cmp qword [is_tty], 0
    je .rp_done
    test qword [config_flags], (1 << CFG_RPROMPT)
    jz .rp_done
    cmp qword [term_width], 0
    je .rp_done
    cmp qword [term_width], 60
    jl .rp_done

    ; Get current time (epoch seconds)
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    xor edi, edi             ; CLOCK_REALTIME = 0
    mov rsi, rsp
    syscall
    mov rax, [rsp]           ; epoch seconds
    add rsp, 16

    ; Convert to HH:MM (UTC+local via TZ offset)
    ; Get timezone offset from TZ or default to UTC
    ; Simple approach: use /etc/localtime via libc... too complex
    ; Instead: read the current offset from the file system
    ; Simpler: compute UTC time, users can set TZ
    ; Actually, just compute hours and minutes from epoch
    ; seconds_today = epoch % 86400
    xor edx, edx
    mov rcx, 86400
    div rcx                  ; rdx = seconds since midnight UTC
    mov rax, rdx

    ; Apply local timezone offset (check TZ env var for offset)
    ; For simplicity, check for a cached tz_offset
    add rax, [tz_offset]
    ; Handle negative/overflow
    cmp rax, 86400
    jl .rp_tz_ok
    sub rax, 86400
.rp_tz_ok:
    test rax, rax
    jns .rp_tz_pos
    add rax, 86400
.rp_tz_pos:

    ; hours = secs / 3600, minutes = (secs % 3600) / 60
    xor edx, edx
    mov rcx, 3600
    div rcx                  ; rax = hours, rdx = remaining seconds
    mov r12, rax             ; hours
    mov rax, rdx
    xor edx, edx
    mov rcx, 60
    div rcx                  ; rax = minutes
    mov r13, rax             ; minutes

    ; Build rprompt string in rprompt_buf
    lea rdi, [rprompt_buf]
    xor rbx, rbx             ; output position

    ; HH:MM
    mov rax, r12
    cmp rax, 10
    jge .rp_h2
    mov byte [rdi + rbx], '0'
    inc rbx
.rp_h2:
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.rp_cp_h:
    cmp ecx, eax
    jge .rp_cp_h_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rbx], dl
    inc rbx
    inc ecx
    jmp .rp_cp_h
.rp_cp_h_done:
    mov byte [rdi + rbx], ':'
    inc rbx
    mov rax, r13
    cmp rax, 10
    jge .rp_m2
    mov byte [rdi + rbx], '0'
    inc rbx
.rp_m2:
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.rp_cp_m:
    cmp ecx, eax
    jge .rp_cp_m_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rbx], dl
    inc rbx
    inc ecx
    jmp .rp_cp_m
.rp_cp_m_done:

    ; Add duration if command took > 1 second
    mov rax, [cmd_end_time]
    sub rax, [cmd_start_time]
    cmp rax, 1
    jl .rp_display
    mov r12, rax
    ; Add space + duration
    mov byte [rdi + rbx], ' '
    inc rbx
    cmp r12, 60
    jl .rp_dur_secs
    ; Minutes + seconds
    mov rax, r12
    xor edx, edx
    mov rcx, 60
    div rcx
    push rdx
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.rp_cp_dm:
    cmp ecx, eax
    jge .rp_cp_dm_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rbx], dl
    inc rbx
    inc ecx
    jmp .rp_cp_dm
.rp_cp_dm_done:
    mov byte [rdi + rbx], 'm'
    inc rbx
    pop rax
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.rp_cp_ds:
    cmp ecx, eax
    jge .rp_cp_ds_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rbx], dl
    inc rbx
    inc ecx
    jmp .rp_cp_ds
.rp_cp_ds_done:
    mov byte [rdi + rbx], 's'
    inc rbx
    jmp .rp_display
.rp_dur_secs:
    mov rax, r12
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.rp_cp_s:
    cmp ecx, eax
    jge .rp_cp_s_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rbx], dl
    inc rbx
    inc ecx
    jmp .rp_cp_s
.rp_cp_s_done:
    mov byte [rdi + rbx], 's'
    inc rbx

.rp_display:
    ; Save cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.rp_save]
    mov rdx, 3                   ; ESC[s = 3 bytes
    syscall
    ; Build positioning + color + text + reset + restore in rprompt_buf area
    ; Move content to after the positioning escape
    ; First, calculate column: term_width - rbx
    mov rax, [term_width]
    sub rax, rbx
    ; Build ESC[{col}G + color + content + reset + restore
    lea rdi, [rprompt_buf + 128] ; use second half as final output
    mov byte [rdi], 27
    mov byte [rdi + 1], '['
    add rdi, 2
    push rbx
    push rdi
    lea rdi, [num_buf]
    call itoa
    pop rdi
    lea rsi, [num_buf]
    xor ecx, ecx
.rp_cp_col:
    cmp ecx, eax
    jge .rp_cp_col_done
    movzx edx, byte [rsi + rcx]
    mov [rdi + rcx], dl
    inc ecx
    jmp .rp_cp_col
.rp_cp_col_done:
    add rdi, rax
    mov byte [rdi], 'G'
    inc rdi
    ; Stamp color from settings
    mov byte [rdi], 27
    mov byte [rdi+1], '['
    mov byte [rdi+2], '3'
    mov byte [rdi+3], '8'
    mov byte [rdi+4], ';'
    mov byte [rdi+5], '5'
    mov byte [rdi+6], ';'
    add rdi, 7
    ; Convert color_settings[C_STAMP] to digits
    movzx eax, byte [color_settings + C_STAMP]
    push rdi
    call itoa
    pop rdi
    add rdi, rax
    mov byte [rdi], 'm'
    inc rdi
    ; Copy rprompt text
    pop rbx
    lea rsi, [rprompt_buf]
    xor rcx, rcx
.rp_copy_text:
    cmp rcx, rbx
    jge .rp_copy_text_done
    movzx eax, byte [rsi + rcx]
    mov [rdi], al
    inc rdi
    inc rcx
    jmp .rp_copy_text
.rp_copy_text_done:
    ; Reset + restore cursor (ESC[u, not ESC8, to avoid clobbering prompt save)
    mov byte [rdi], 27
    mov byte [rdi+1], '['
    mov byte [rdi+2], '0'
    mov byte [rdi+3], 'm'
    add rdi, 4
    mov byte [rdi], 27
    mov byte [rdi+1], '['
    mov byte [rdi+2], 'u'
    add rdi, 3
    ; Write it all
    mov rdx, rdi
    lea rsi, [rprompt_buf + 128]
    sub rdx, rsi
    mov rax, SYS_WRITE
    mov rdi, 1
    syscall

.rp_done:
    pop r13
    pop r12
    pop rbx
    ret

.rp_save: db 27, '[', 's'   ; ESC[s = save cursor (ANSI, separate from ESC7)

; ══════════════════════════════════════════════════════════════════════
; Auto-correct: suggest similar commands on "command not found"
; Uses simple Levenshtein-like comparison (first char match + length)
; rdi = command that was not found
; ══════════════════════════════════════════════════════════════════════
suggest_correction:
    push rbx
    push r12
    push r13
    push r14
    push r15

    test qword [config_flags], (1 << CFG_AUTO_CORRECT)
    jz .sugc_done

    mov r12, rdi             ; failed command
    mov rdi, r12
    call strlen
    mov r13, rax             ; failed cmd length
    cmp r13, 1
    jle .sugc_done           ; too short to suggest

    ; Search PATH for similar commands
    ; Simple heuristic: same first char, length within 2
    mov rdi, [envp]
    call find_env_path
    test rax, rax
    jnz .sugc_have_path
    lea rax, [default_path]
.sugc_have_path:
    mov r14, rax             ; PATH
    xor r15, r15             ; found count

    ; Print "bare: command not found, did you mean:"
    ; (caller already printed the error)

.sugc_next_dir:
    cmp byte [r14], 0
    je .sugc_end
    ; Extract dir from PATH
    lea rdi, [path_buf]
    mov rsi, r14
.sugc_cp_dir:
    movzx eax, byte [rsi]
    test al, al
    jz .sugc_dir_end
    cmp al, ':'
    je .sugc_dir_end
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .sugc_cp_dir
.sugc_dir_end:
    mov byte [rdi], 0
    mov r14, rsi
    cmp byte [r14], ':'
    jne .sugc_scan_dir
    inc r14

.sugc_scan_dir:
    mov rax, SYS_OPEN
    lea rdi, [path_buf]
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .sugc_next_dir
    push rax                 ; fd

.sugc_read:
    mov rax, SYS_GETDENTS64
    mov rdi, [rsp]
    lea rsi, [tab_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .sugc_close

    xor rcx, rcx
.sugc_entry:
    cmp rcx, rax
    jge .sugc_read
    lea rsi, [tab_dir_buf + rcx]
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    lea rdi, [rsi + DIRENT64_D_NAME]
    push rax
    push rcx
    push rdx
    ; Check: first char matches and length within 2
    movzx eax, byte [rdi]
    movzx ebx, byte [r12]
    cmp al, bl
    jne .sugc_skip
    ; Check length
    push rdi
    call strlen
    pop rdi
    mov rbx, rax
    sub rbx, r13             ; length diff
    ; abs(diff)
    test rbx, rbx
    jns .sugc_pos
    neg rbx
.sugc_pos:
    cmp rbx, 2
    jg .sugc_skip
    ; Potential match, print it
    cmp r15, 3
    jge .sugc_skip           ; max 3 suggestions
    test r15, r15
    jnz .sugc_not_first
    ; Print header
    push rdi
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.sugc_header]
    mov rdx, .sugc_header_len
    syscall
    pop rdi
.sugc_not_first:
    push rdi
    mov rdi, rdi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 2
    mov rsi, [rsp]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.sugc_sep]
    mov rdx, 2
    syscall
    pop rdi
    inc r15
.sugc_skip:
    pop rdx
    pop rcx
    pop rax
    add rcx, rdx
    jmp .sugc_entry

.sugc_close:
    mov rax, SYS_CLOSE
    pop rdi
    syscall
    jmp .sugc_next_dir

.sugc_end:
    test r15, r15
    jz .sugc_done
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [newline]
    mov rdx, 1
    syscall
.sugc_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.sugc_header: db "  Did you mean: "
.sugc_header_len equ $ - .sugc_header
.sugc_sep: db "  "

; ══════════════════════════════════════════════════════════════════════
; Fuzzy match: check if all chars of query appear in order in candidate
; rdi = candidate string, rsi = query string
; Returns rax = 1 if fuzzy match, 0 if not
; ══════════════════════════════════════════════════════════════════════
fuzzy_match:
    push rbx
.fm_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .fm_yes               ; all query chars matched
    movzx ebx, byte [rdi]
    test bl, bl
    jz .fm_no                ; candidate ended before query
    cmp al, bl
    jne .fm_skip
    inc rsi                  ; matched, advance query
.fm_skip:
    inc rdi                  ; always advance candidate
    jmp .fm_loop
.fm_yes:
    mov rax, 1
    pop rbx
    ret
.fm_no:
    xor eax, eax
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Session management: :save_session, :load_session, :list_sessions, :delete_session
; Sessions stored as ~/.bare/sessions/<name>.bare
; ══════════════════════════════════════════════════════════════════════

; :save_session name - save current state
handle_save_session:
    push rbx
    push r12
    mov r12, rdi             ; argv array
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hss_usage

    ; Build path: ~/.bare/sessions/<name>.bare
    call build_session_path
    ; rax = path in suggestion_buf

    ; Create directories (~/.bare/sessions/)
    push rax
    call ensure_dir
    pop rax

    ; Open file for writing
    mov rdi, rax
    mov rax, SYS_OPEN
    mov rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov rdx, 0o644
    syscall
    test rax, rax
    js .hss_err
    mov rbx, rax             ; fd

    ; Write current directory
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [.hss_cwd_tag]
    mov rdx, 4
    syscall
    lea rdi, [cwd_buf]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [cwd_buf]
    syscall
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [newline]
    mov rdx, 1
    syscall

    ; Write last 50 history entries
    mov rax, [hist_count]
    mov rcx, rax
    sub rcx, 50
    test rcx, rcx
    jns .hss_hist_start
    xor rcx, rcx
.hss_hist_start:
.hss_hist_loop:
    cmp rcx, [hist_count]
    jge .hss_close
    push rcx
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [.hss_hist_tag]
    mov rdx, 5
    syscall
    mov rcx, [rsp]
    mov rsi, [hist_lines + rcx*8]
    test rsi, rsi
    jz .hss_hist_next
    mov rdi, rsi
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, rbx
    mov rcx, [rsp]
    mov rsi, [hist_lines + rcx*8]
    syscall
    mov rax, SYS_WRITE
    mov rdi, rbx
    lea rsi, [newline]
    mov rdx, 1
    syscall
.hss_hist_next:
    pop rcx
    inc rcx
    jmp .hss_hist_loop

.hss_close:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hss_saved_msg]
    mov rdx, .hss_saved_len
    syscall
    jmp .hss_done

.hss_usage:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hss_usage_msg]
    mov rdx, .hss_usage_len
    syscall
    jmp .hss_done
.hss_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hss_err_msg]
    mov rdx, .hss_err_len
    syscall
.hss_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret

.hss_cwd_tag: db "cwd="
.hss_hist_tag: db "hist="
.hss_saved_msg: db "Session saved", 10
.hss_saved_len equ $ - .hss_saved_msg
.hss_usage_msg: db "usage: :save_session <name>", 10
.hss_usage_len equ $ - .hss_usage_msg
.hss_err_msg: db "bare: failed to save session", 10
.hss_err_len equ $ - .hss_err_msg

; Build session file path: ~/.bare/sessions/<name>.bare -> suggestion_buf
; rdi = session name
; Returns rax = pointer to path in suggestion_buf
build_session_path:
    push rbx
    push r12
    mov r12, rdi             ; name
    ; Get HOME
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .bsp_fail
    ; Build path
    lea rdi, [suggestion_buf]
    mov rsi, rax
.bsp_cp_home:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .bsp_append
    inc rsi
    inc rdi
    jmp .bsp_cp_home
.bsp_append:
    ; /.bare/sessions/
    ; Write char by char to avoid NASM string size issues
    mov byte [rdi], '/'
    mov byte [rdi+1], '.'
    mov byte [rdi+2], 'b'
    mov byte [rdi+3], 'a'
    mov byte [rdi+4], 'r'
    mov byte [rdi+5], 'e'
    mov byte [rdi+6], '/'
    mov byte [rdi+7], 's'
    mov byte [rdi+8], 'e'
    mov byte [rdi+9], 's'
    mov byte [rdi+10], 's'
    mov byte [rdi+11], 'i'
    mov byte [rdi+12], 'o'
    mov byte [rdi+13], 'n'
    mov byte [rdi+14], 's'
    mov byte [rdi+15], '/'
    add rdi, 16
    ; Copy name
    mov rsi, r12
.bsp_cp_name:
    mov cl, [rsi]
    test cl, cl
    jz .bsp_suffix
    mov [rdi], cl
    inc rsi
    inc rdi
    jmp .bsp_cp_name
.bsp_suffix:
    ; .bare extension
    mov dword [rdi], '.bar'
    mov byte [rdi+4], 'e'
    mov byte [rdi+5], 0
    lea rax, [suggestion_buf]
    pop r12
    pop rbx
    ret
.bsp_fail:
    xor eax, eax
    pop r12
    pop rbx
    ret

; Ensure directory exists (mkdir -p simple)
; rdi = path (must be absolute)
ensure_dir:
    push rbx
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .ed_done
    ; Build ~/.bare
    lea rdi, [path_buf]
    mov rsi, rax
.ed_cp:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .ed_mk1
    inc rsi
    inc rdi
    jmp .ed_cp
.ed_mk1:
    mov dword [rdi], '/.ba'
    mov word [rdi+4], 're'
    mov byte [rdi+6], 0
    mov rax, 83              ; SYS_MKDIR
    lea rdi, [path_buf]
    mov rsi, 0o755
    syscall
    ; ~/.bare/sessions
    lea rdi, [path_buf]
    call strlen
    lea rdi, [path_buf + rax]
    mov rax, '/sess'
    mov [rdi], rax
    mov dword [rdi+5], 'ions'
    mov byte [rdi+9], 0
    mov rax, 83
    lea rdi, [path_buf]
    mov rsi, 0o755
    syscall
.ed_done:
    pop rbx
    ret

; :load_session name
handle_load_session:
    push rbx
    push r12
    mov r12, rdi
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .hls_usage
    call build_session_path
    test rax, rax
    jz .hls_err
    ; Source the session file
    mov rdi, rax
    call source_file
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.hls_loaded]
    mov rdx, .hls_loaded_len
    syscall
    jmp .hls_done
.hls_usage:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hls_usage_msg]
    mov rdx, .hls_usage_len
    syscall
    jmp .hls_done
.hls_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [.hls_err_msg]
    mov rdx, .hls_err_len
    syscall
.hls_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret
.hls_loaded: db "Session loaded", 10
.hls_loaded_len equ $ - .hls_loaded
.hls_usage_msg: db "usage: :load_session <name>", 10
.hls_usage_len equ $ - .hls_usage_msg
.hls_err_msg: db "bare: session not found", 10
.hls_err_len equ $ - .hls_err_msg

; :list_sessions - list saved sessions by scanning ~/.bare/sessions/
handle_list_sessions:
    push rbx
    push r12
    ; Build path
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .hlss_done
    lea rdi, [path_buf]
    mov rsi, rax
.hlss_cp:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .hlss_append
    inc rsi
    inc rdi
    jmp .hlss_cp
.hlss_append:
    lea rsi, [.hlss_suffix]
.hlss_cps:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .hlss_open
    inc rsi
    inc rdi
    jmp .hlss_cps
.hlss_open:
    mov rax, SYS_OPEN
    lea rdi, [path_buf]
    mov rsi, O_RDONLY | O_DIRECTORY
    xor edx, edx
    syscall
    test rax, rax
    js .hlss_done
    mov rbx, rax             ; fd
.hlss_read:
    mov rax, SYS_GETDENTS64
    mov rdi, rbx
    lea rsi, [tab_dir_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .hlss_close
    mov r12, rax             ; bytes read
    xor rcx, rcx
.hlss_entry:
    cmp rcx, r12
    jge .hlss_read
    lea rsi, [tab_dir_buf + rcx]
    movzx edx, word [rsi + DIRENT64_D_RECLEN]
    push rcx
    push rdx
    lea rdi, [rsi + DIRENT64_D_NAME]
    ; Skip . and ..
    cmp byte [rdi], '.'
    je .hlss_skip
    ; Print name (strip .bare extension if present)
    call strlen
    mov rdx, rax
    cmp rdx, 5
    jl .hlss_print
    ; Check if ends with .bare
    sub rdx, 5
.hlss_print:
    mov rax, SYS_WRITE
    push rdi
    mov rsi, rdi
    mov rdi, 1
    syscall
    pop rdi
    call write_nl
.hlss_skip:
    pop rdx
    pop rcx
    add rcx, rdx
    jmp .hlss_entry
.hlss_close:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
.hlss_done:
    mov qword [last_status], 0
    pop r12
    pop rbx
    ret
.hlss_suffix: db "/.bare/sessions", 0

; ══════════════════════════════════════════════════════════════════════
; Plugin system: try to run ~/.bare/plugins/<name>
; rdi = command name (without leading ':')
; r12 = argv array (from check_builtin)
; Returns rax = 1 if plugin was found and executed, 0 if not
; ══════════════════════════════════════════════════════════════════════
try_run_plugin:
    push rbx
    push r12
    push r13
    push r14
    mov r13, rdi             ; command name
    mov r14, r12             ; argv array

    ; Build path: $HOME/.bare/plugins/<name>
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .trp_no

    ; Copy HOME to path_buf
    lea rdi, [path_buf]
    mov rsi, rax
    call strcpy_rsi_rdi

    ; Append /.bare/plugins/
    lea rdi, [path_buf]
    call strlen
    lea rdi, [path_buf + rax]
    lea rsi, [plugin_suffix]
    call strcpy_rsi_rdi

    ; Append command name
    lea rdi, [path_buf]
    call strlen
    lea rdi, [path_buf + rax]
    mov rsi, r13
    call strcpy_rsi_rdi

    ; Check if file exists (stat)
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [path_buf]
    mov rsi, rsp
    syscall
    add rsp, 144
    test rax, rax
    js .trp_no                ; file doesn't exist

    ; File exists. Fork and exec it.
    ; Build argv: [path, arg1, arg2, ..., NULL]
    ; argv[0] = path_buf, argv[1..] = r14[8..] (skip the :cmd)
    call enable_cooked_mode

    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .trp_child
    js .trp_no

    ; Parent: wait for child
    mov rbx, rax
    sub rsp, 16
    mov rdi, rbx
    lea rsi, [rsp]
    mov edx, WUNTRACED
    xor r10d, r10d
    mov rax, SYS_WAIT4
    syscall
    ; Extract exit status
    mov eax, [rsp]
    shr eax, 8
    and eax, 0xFF
    mov [last_status], rax
    add rsp, 16
    call post_child_restore
    call enable_raw_mode
    mov rax, 1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.trp_child:
    ; Restore signals
    call restore_child_signals
    ; Build argv on stack: [path, original_args..., NULL]
    ; Count args from r14 (skip argv[0] which is the :cmd)
    xor rcx, rcx
    mov rsi, r14
.trp_count:
    mov rax, [rsi + rcx*8]
    test rax, rax
    jz .trp_counted
    inc rcx
    jmp .trp_count
.trp_counted:
    ; rcx = total original args (including :cmd)
    ; New argv: path + args[1..] + NULL = rcx entries
    ; Allocate on stack
    lea rax, [rcx + 1]       ; +1 for NULL
    shl rax, 3
    sub rsp, rax
    ; argv[0] = path
    lea rax, [path_buf]
    mov [rsp], rax
    ; Copy remaining args (skip :cmd which is argv[0])
    mov rdx, 1               ; source index (skip :cmd)
    mov rbx, 1               ; dest index
.trp_copy_args:
    cmp rdx, rcx
    jge .trp_args_done
    mov rax, [r14 + rdx*8]
    mov [rsp + rbx*8], rax
    inc rdx
    inc rbx
    jmp .trp_copy_args
.trp_args_done:
    mov qword [rsp + rbx*8], 0  ; NULL terminator

    ; execve(path, argv, env)
    mov rax, SYS_EXECVE
    lea rdi, [path_buf]
    mov rsi, rsp
    lea rdx, [env_array]
    syscall
    ; exec failed
    mov rax, SYS_EXIT
    mov edi, 127
    syscall

.trp_no:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Check if git working tree is dirty (uncommitted changes)
; Compares .git/index mtime with HEAD commit ref mtime
; Returns: rax = 1 if dirty, 0 if clean
; ══════════════════════════════════════════════════════════════════════
; check_git_dirty: hybrid approach
; 1. Quick stat check (index vs ref mtime) - always
; 2. Fork "git status --porcelain" every 5 seconds - if git_status_fork enabled
; Returns: rax = 1 if dirty, 0 if clean
check_git_dirty:
    push rbx
    push r12
    sub rsp, 288

    ; Invalidate cache if repo root changed
    lea rdi, [git_root_buf]
    lea rsi, [git_root_prev]
    call strcmp
    test rax, rax
    jz .cgd_same_repo
    ; Different repo: reset cache, save new root
    mov byte [git_status_cached], 0
    mov qword [git_status_cache_time], 0
    lea rdi, [git_root_prev]
    lea rsi, [git_root_buf]
    call strcpy_rsi_rdi
.cgd_same_repo:

    ; Quick stat check first (free, no fork)
    ; Build full path: git_root_buf + /.git/index
    lea rdi, [path_buf]
    lea rsi, [git_root_buf]
    cmp byte [rsi], 0
    je .cgd_clean             ; no git root known
    call strcpy_rsi_rdi
    lea rdi, [path_buf + rax]
    lea rsi, [.cgd_index]
    call strcpy_rsi_rdi
    lea rdi, [path_buf]
    mov rsi, rsp
    mov rax, SYS_STAT
    syscall
    test rax, rax
    js .cgd_clean

    mov r12, [rsp + 88]       ; index mtime

    ; Build ref path: git_root_buf + /.git/refs/heads/<branch>
    lea rdi, [path_buf]
    lea rsi, [git_root_buf]
    call strcpy_rsi_rdi
    lea rdi, [path_buf + rax]
    lea rsi, [.cgd_refs_prefix]
    call strcpy_rsi_rdi
    lea rdi, [path_buf + rax]
    ; recalculate full offset
    lea rdi, [path_buf]
    call strlen
    lea rdi, [path_buf + rax]
    lea rsi, [git_branch_buf]
.cgd_cp_branch:
    mov al, [rsi]
    test al, al
    jz .cgd_branch_done
    cmp al, 10
    je .cgd_branch_done
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .cgd_cp_branch
.cgd_branch_done:
    mov byte [rdi], 0

    lea rdi, [path_buf]
    lea rsi, [rsp + 144]
    mov rax, SYS_STAT
    syscall
    test rax, rax
    js .cgd_try_fork          ; no ref, check via fork

    mov rbx, [rsp + 144 + 88]
    cmp r12, rbx
    jg .cgd_dirty             ; index newer = staged changes, definitely dirty

    ; Stat says clean. Check fork cache if enabled.
.cgd_try_fork:
    ; Free stat frame first
    add rsp, 288

    test qword [config_flags], (1 << CFG_GIT_STATUS_FORK)
    jz .cgd_use_cache2

    ; Check if 5 seconds have passed since last fork
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    mov rsi, rsp
    syscall
    mov rax, [rsp]
    add rsp, 16
    mov rbx, [git_status_cache_time]
    sub rax, rbx
    cmp rax, 5
    jl .cgd_use_cache2

    ; Time to re-check: fork "git status --porcelain"
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    mov rsi, rsp
    syscall
    mov rax, [rsp]
    mov [git_status_cache_time], rax
    add rsp, 16

    ; Create pipe
    mov rax, SYS_PIPE
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    jnz .cgd_use_cache2

    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .cgd_child
    js .cgd_use_cache2

    ; Parent: close write end, read 1 byte
    mov rbx, rax
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall

    sub rsp, 16
    mov rax, SYS_READ
    mov edi, [pipe_fds]
    mov rsi, rsp
    mov rdx, 1
    syscall
    mov r12, rax              ; bytes read
    add rsp, 16

    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall

    ; Wait for child
    sub rsp, 16
    mov rax, SYS_WAIT4
    mov rdi, rbx
    lea rsi, [rsp]
    xor edx, edx
    xor r10d, r10d
    syscall
    add rsp, 16

    ; Cache result
    test r12, r12
    jz .cgd_fork_clean
    mov byte [git_status_cached], 1
    mov eax, 1
    pop r12
    pop rbx
    ret
.cgd_fork_clean:
    mov byte [git_status_cached], 0
    xor eax, eax
    pop r12
    pop rbx
    ret

.cgd_use_cache2:
    cmp byte [git_status_cached], 0
    jne .cgd_dirty2
    xor eax, eax
    pop r12
    pop rbx
    ret
.cgd_dirty2:
    mov eax, 1
    pop r12
    pop rbx
    ret

.cgd_child:
    ; cd to git root so git status works from subdirectories
    mov rax, SYS_CHDIR
    lea rdi, [git_root_buf]
    syscall
    ; Redirect stdout to pipe write end
    mov rax, SYS_DUP2
    mov edi, [pipe_fds + 4]
    mov esi, 1
    syscall
    ; Redirect stderr to /dev/null
    mov rax, SYS_OPEN
    lea rdi, [.cgd_devnull]
    mov rsi, O_WRONLY
    xor edx, edx
    syscall
    mov edi, eax
    mov rax, SYS_DUP2
    mov esi, 2
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [pipe_fds + 4]
    syscall
    ; exec git status --porcelain
    sub rsp, 40
    lea rax, [.cgd_git]
    mov [rsp], rax
    lea rax, [.cgd_status]
    mov [rsp + 8], rax
    lea rax, [.cgd_porcelain]
    mov [rsp + 16], rax
    mov qword [rsp + 24], 0
    mov rax, SYS_EXECVE
    lea rdi, [.cgd_git]
    mov rsi, rsp
    lea rdx, [env_array]
    syscall
    mov rax, SYS_EXIT
    xor edi, edi
    syscall

.cgd_use_cache:
    cmp byte [git_status_cached], 0
    jne .cgd_dirty

.cgd_clean:
    xor eax, eax
    add rsp, 288
    pop r12
    pop rbx
    ret

.cgd_dirty:
    mov eax, 1
    add rsp, 288
    pop r12
    pop rbx
    ret

.cgd_index: db "/.git/index", 0
.cgd_refs_prefix: db "/.git/refs/heads/", 0
.cgd_git: db "/usr/bin/git", 0
.cgd_status: db "status", 0
.cgd_porcelain: db "--porcelain", 0
.cgd_devnull: db "/dev/null", 0

; ══════════════════════════════════════════════════════════════════════
; Check ~/.pointer/lastdir after command execution
; If file was modified within last 2 seconds, cd to its content
; ══════════════════════════════════════════════════════════════════════
check_lastdir:
    push rbx
    push r12

    ; Build path: $HOME/.pointer/lastdir
    mov rdi, [envp]
    call find_env_home
    test rax, rax
    jz .cld_done

    lea rdi, [path_buf]
    mov rsi, rax
    call strcpy_rsi_rdi
    lea rdi, [path_buf + rax]
    lea rsi, [.cld_suffix]
    call strcpy_rsi_rdi

    ; Stat the file
    sub rsp, 144
    mov rax, SYS_STAT
    lea rdi, [path_buf]
    mov rsi, rsp
    syscall
    test rax, rax
    js .cld_no_file

    ; Check mtime: compare with current time
    mov r12, [rsp + 88]       ; st_mtim.tv_sec
    add rsp, 144

    ; Get current time
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rsp]
    syscall
    ; Use realtime clock instead for file mtime comparison
    mov rax, 228              ; SYS_CLOCK_GETTIME
    xor edi, edi              ; CLOCK_REALTIME = 0
    lea rsi, [rsp]
    syscall
    mov rbx, [rsp]            ; current time
    add rsp, 16

    ; Age = current - mtime
    sub rbx, r12
    cmp rbx, 2
    jg .cld_done              ; older than 2 seconds, skip

    ; Read the file content
    mov rax, SYS_OPEN
    lea rdi, [path_buf]
    xor esi, esi              ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .cld_done
    mov rbx, rax              ; fd

    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [suggestion_buf]
    mov rdx, 4095
    syscall
    push rax
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    pop rax
    test rax, rax
    jle .cld_done

    ; Null-terminate and strip trailing newline
    mov byte [suggestion_buf + rax], 0
    dec rax
    cmp byte [suggestion_buf + rax], 10
    jne .cld_no_strip
    mov byte [suggestion_buf + rax], 0
.cld_no_strip:

    ; cd to the directory
    mov rax, SYS_CHDIR
    lea rdi, [suggestion_buf]
    syscall
    test rax, rax
    js .cld_done
    call update_cwd
    call add_dir_history
    jmp .cld_done

.cld_no_file:
    add rsp, 144
.cld_done:
    pop r12
    pop rbx
    ret

.cld_suffix: db "/.pointer/lastdir", 0

; ══════════════════════════════════════════════════════════════════════
; Tab complete colon commands (:th -> :theme, etc.)
; rdi = word starting with ':'
; ══════════════════════════════════════════════════════════════════════
tab_complete_colon:
    push rbx
    push r12
    push r13

    mov r12, rdi             ; prefix (":th" etc.)
    call strlen
    mov r13, rax             ; prefix length

    mov qword [tab_count], 0
    mov qword [tab_buf_pos], 0

    ; Scan colon_dispatch_table
    lea rbx, [colon_dispatch_table]
.tcc_loop:
    mov rsi, [rbx]           ; string pointer
    test rsi, rsi
    jz .tcc_done             ; sentinel

    ; Compare prefix against this command name
    xor rcx, rcx
.tcc_cmp:
    cmp rcx, r13
    jge .tcc_match           ; prefix fully matched
    movzx eax, byte [r12 + rcx]
    cmp al, [rsi + rcx]
    jne .tcc_next
    inc rcx
    jmp .tcc_cmp

.tcc_match:
    cmp qword [tab_count], MAX_TAB_RESULTS - 1
    jge .tcc_next
    ; Copy command name to tab_buf
    mov rax, [tab_buf_pos]
    lea rdi, [tab_buf + rax]
    mov rcx, [tab_count]
    mov [tab_results + rcx*8], rdi
    push rsi
    call strcpy_rsi_rdi
    pop rsi
    inc rax                  ; past null
    add [tab_buf_pos], rax
    inc qword [tab_count]

.tcc_next:
    add rbx, 16              ; next entry (2 qwords: string + handler)
    jmp .tcc_loop

.tcc_done:
    pop r13
    pop r12
    pop rbx
    ret
