# bare plugins

Plugins are executable files in `~/.bare/plugins/`. Any unknown colon command runs the matching plugin.

## Installation

```bash
cp plugins/* ~/.bare/plugins/
chmod +x ~/.bare/plugins/*
```

## Included plugins

### :ask - Ask AI a question

```
:ask how do I find files larger than 100MB?
:ask what does awk do?
```

### :suggest - Get a command suggestion

```
:suggest find all .log files modified today
:suggest compress this directory
```

### Setup (for :ask and :suggest)

Both plugins use the Anthropic Claude API. Provide your key one of three ways:

1. **Environment variable:** `export ANTHROPIC_API_KEY="sk-ant-..."`
2. **Config file:** `echo "sk-ant-..." > ~/.config/bare/anthropic_key`
3. **Shared file:** Store in `/home/.safe/anthropic.txt`

Get an API key at https://console.anthropic.com/

## Writing your own plugin

A plugin is any executable. It receives command arguments as `$1`, `$2`, etc.

```bash
#!/bin/bash
# ~/.bare/plugins/greet
echo "Hello, ${1:-world}!"
```

```
:greet           -> Hello, world!
:greet Alice     -> Hello, Alice!
```

Plugins can be written in any language: bash, python, rust, ruby, etc.
