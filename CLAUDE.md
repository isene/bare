# bare

Interactive shell written in x86_64 Linux assembly. No libc, no runtime, pure syscalls.

## Build

```bash
nasm -f elf64 bare.asm -o bare.o && ld bare.o -o bare
```

## Architecture

- NASM syntax, x86_64 Linux
- Direct syscalls via `syscall` instruction (no libc)
- Static binary (~130KB), no dynamic linking
- All buffers statically allocated in BSS (no heap)
- Raw termios for char-by-char input

## x86_64 Assembly Pitfalls (MUST READ)

These are recurring bugs. Check for them in every change.

### 1. `syscall` clobbers rcx and r11
The `syscall` instruction saves RIP into rcx and RFLAGS into r11. Any value in rcx/r11 before a syscall is destroyed. Never initialize rcx before a syscall and expect it to survive.
```nasm
; WRONG: rcx is destroyed by syscall
xor ecx, ecx
syscall
mov [count], rcx    ; rcx = garbage (saved RIP)

; RIGHT: initialize after syscall, or use a different register
syscall
xor ecx, ecx
mov [count], rcx
```

### 2. 32-bit operations zero-extend to 64-bit
Writing to a 32-bit register (eax, ebx, etc.) zeros the upper 32 bits of the 64-bit register. This affects sign checks: `sub eax, ebx` producing a negative 32-bit result looks positive when checked with `test rax, rax`.
```nasm
; WRONG: negative 32-bit result appears positive in 64-bit
sub eax, ebx
test rax, rax     ; SF=0 even if result was negative
jle .less         ; never taken for negative results

; RIGHT: check the 32-bit result
sub eax, ebx
test eax, eax     ; checks 32-bit sign correctly
jle .less
```

### 3. Callee-saved registers must be preserved
Functions MUST push/pop rbx, rbp, r12-r15 if they use them. Forgetting causes crashes in callers that depend on these values.
```nasm
; WRONG: clobbers caller's r12
my_func:
    mov r12, rax    ; caller's r12 is lost
    ...
    ret

; RIGHT: save and restore
my_func:
    push r12
    mov r12, rax
    ...
    pop r12
    ret
```

### 4. Don't mask function return values
When saving a register across a call, make sure the pop doesn't overwrite the return value you need.
```nasm
; WRONG: strlen result in rax is overwritten by pop
push rax            ; save counter
call strlen         ; rax = string length
pop rax             ; restores counter, strlen result LOST
add rdi, rax        ; adds counter, not length!

; RIGHT: use strlen result before restoring
push rax
call strlen
add rdi, rax        ; use strlen result first
pop rax             ; now restore counter
```

### 5. Use `mov reg, [rsp]` to peek at stack
Don't pop and re-push the same register to read the top of stack.
```nasm
; WRONG: wasteful two-instruction peek
pop rcx
push rcx

; RIGHT: single-instruction peek
mov rcx, [rsp]
```

### 6. NASM `$` means current address, not ASCII 36
The dollar sign character must be written as `0x24` in NASM, not `'$'`.

### 7. Data in .text is read-only
Any `resb`/`resw`/`resd`/`resq` after a `ret` in .text will segfault on write. Writable data must be in .bss.

### 8. Local label scoping
Local labels (`.name`) are scoped to the enclosing global label. A global label between two local labels breaks the scope. Shared helpers between functions must use global labels.

## Key code sections

- `_start`: entry point, envp init, config/history loading, signal setup
- `read_line`: raw-mode line editor with all key handlers
- `print_prompt_dynamic`: prompt with user@host:cwd/ git-indicator >
- `check_builtin`: table-driven colon command dispatch
- `parse_and_exec_simple`: nick expansion, fork/exec with cooked mode
- `execute_line`: multi-pipe handling (up to 16 segments)
- `execute_chained_line`: splits by `;`, `&&`, `||`
- `expand_line`: tilde/variable expansion
- `syntax_highlight_line`: colors by command type (exe/nick/colon/switch)
- `init_exe_cache`: scans PATH at startup for syntax highlighting
- `tab_complete_command/file/var/colon`: with d_type tracking for LS_COLORS
- `sort_tab_results`: case-insensitive insertion sort
- `check_git_dirty`: hybrid stat + cached fork approach
- `save_config` / `load_config`: ~/.barerc persistence with multi-terminal safety
- `handle_backup` / `handle_restore`: config/history snapshots

## Syscalls used

READ, WRITE, OPEN, CLOSE, STAT, IOCTL, PIPE, DUP2, FORK, EXECVE, EXIT, WAIT4, GETCWD, CHDIR, GETDENTS64, GETPID, RT_SIGACTION, CLOCK_GETTIME, GETUID
