# Micro editor notes

Companion notes for `setup-micro.sh`. Verified against **micro 2.0.13** and
**micro-plugin-lsp 0.6.2**.

## Colorscheme / truecolor

`setup-micro.sh` sets `monokai-dark`, not `monokai`. Both ship with micro, but they
are different things:

- `monokai` — 256-color palette indices (`color-link comment "243,235"`)
- `monokai-dark` — true 24-bit hex (`color-link comment "#75715E"`)

`monokai-dark` only renders correctly if the terminal advertises truecolor. If
`COLORTERM` is unset, micro silently downsamples to the 256-color approximation and
the theme looks washed out and "not quite right". The setup script appends this to
`~/.zshrc`:

```bash
export COLORTERM=truecolor
export MICRO_TRUECOLOR=1
```

Check with `echo $COLORTERM` — if it's empty in a running shell, the profile hasn't
been re-sourced yet.

## Settings file churn

Micro rewrites `~/.config/micro/settings.json` on exit and **strips**:

- any key whose value equals micro's own default
- any key it doesn't recognize

So a settings file that looks shorter than what the script wrote is usually fine —
it's normalized, not broken. Confirm a default with `micro -options | grep -A1 <key>`.

Two keys that older versions of this script wrote are **not valid** in 2.0.13 and get
dropped every time:

| Old key | Reality |
|---|---|
| `autoclose` | Not a micro option at all |
| `status` | Renamed to `statusline` |

## Autocomplete / LSP

Installed by `setup-micro.sh` via `micro -plugin install lsp`.

### Setting keys

⚠️ The plugin's real option names are **not** `lsp`, `lsp.autocomplete`, or
`lsp.diagnostics` — those don't exist and micro will drop them. The actual keys, per
the plugin README:

```json
{
    "lsp.server": "python=pyright-langserver --stdio,rust=rust-analyzer,go=gopls",
    "lsp.formatOnSave": true,
    "lsp.tabcompletion": true,
    "lsp.autocompleteDetails": false,
    "lsp.ignoreMessages": "regex|of|messages|to|suppress"
}
```

Format is `<filetype>=<executable with args>[=<init options JSON>][,...]`.

`MICRO_LSP` as an environment variable overrides `lsp.server` entirely if set.

### What it actually supports

Implemented LSP methods: `hover`, `definition`, `completion`, `formatting`,
`references`.

**No diagnostics.** The plugin does not implement `publishDiagnostics`, so there is no
inline error squiggle / error checking, despite what you might expect from an LSP
client. For that you still need a real IDE.

### Keybindings (registered automatically)

| Key | Action |
|---|---|
| `Ctrl+Space` | Completion |
| `Alt+K` | Hover docs |
| `Alt+D` | Go to definition |
| `Alt+F` | Format |
| `Alt+R` | Find references |

### Language servers

The plugin does not install these — they're separate. Currently on this machine only
`rust-analyzer` is present (via rustup/cargo).

```bash
# Python — pyright is the better pick for FastAPI work
npm install -g pyright
# or the pure-python alternative
pip install python-lsp-server   # binary is `pylsp`

# TypeScript / JavaScript
npm install -g typescript typescript-language-server

# Go
go install golang.org/x/tools/gopls@latest

# C/C++
sudo apt install clangd
```

A filetype whose server isn't installed just fails quietly for that buffer; the rest
of micro keeps working.

### Why bother

For SSHing into the Lenovo server / Proxmox boxes / Docker hosts, this is about the
closest terminal editor to "VS Code without VS Code".

## Plugin system caveat

Micro's plugin system has changed between versions. If `micro -plugin install` errors,
run:

```bash
micro -plugin list
```

and adjust the plugin names in `setup-micro.sh` to match what that version exposes.
