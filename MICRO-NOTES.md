# Micro editor notes

Companion notes for `setup-micro.sh`.

## Plugin system caveat

Micro's plugin system has changed between versions. If `micro -plugin install` errors, run:

```bash
micro -plugin list
```

and adjust the plugin names in `setup-micro.sh` to match what that version exposes.

For SSHing into the Lenovo server / Proxmox boxes / Docker hosts, this is about the closest
terminal editor to "VS Code without VS Code".

## Autocomplete / LSP

Micro is a lightweight editor, so it has no VS Code-level IntelliSense built in, but it
supports LSP through a plugin.

### Install the LSP plugin

Inside Micro, press `Ctrl+E` for command mode, then:

```
plugin install lsp
```

Restart Micro.

### Configure language servers

Micro uses the normal language servers you already use elsewhere.

Python:

```bash
pip install python-lsp-server
```

Or the more VS Code-like one:

```bash
pip install pyright
# or
npm install -g pyright
```

For FastAPI/Python work, pyright is the better pick.

### Settings

```bash
micro ~/.config/micro/settings.json
```

Add:

```json
{
    "lsp": true,
    "lsp.autocomplete": true,
    "lsp.formatOnSave": true,
    "lsp.diagnostics": true
}
```

> Note: the exact `lsp.*` key names vary by plugin fork/version. After installing, confirm
> against the plugin's own README — if the keys are wrong Micro silently ignores them.

### What you get

- autocomplete
- go to definition
- error checking
- hover documentation
- rename symbol
- formatting

So for:

```python
app = FastAPI()

@app.get("/")
def home():
    return {"hello": "world"}
```

Micro understands FastAPI, functions, imports, types, and errors.
