# Toolbox

**Ship and run internal CLI products as plugins — from a single binary.**

Toolbox is a local-first command launcher for teams that want a clean way to distribute, discover, and execute internal tools without building a custom platform.

It gives you:

- **Plugin install from folder, archive, or URL**
- **Namespace-aware commands** (`toolbox <namespace> <plugin>`)
- **Built-in metadata management** with SQLite
- **Interactive SQLite REPL** for inspection/debug
- **Simple plugin scaffolding** for fast onboarding

---

## Install

### Binary releases

Download the latest release from:

**https://github.com/gfmois/toolbox/releases/latest**

Available assets:

- `toolbox_vX.Y.Z_linux_amd64.tar.gz`
- `toolbox_vX.Y.Z_linux_arm64.tar.gz`
- `toolbox_vX.Y.Z_darwin_amd64.tar.gz`
- `toolbox_vX.Y.Z_darwin_arm64.tar.gz`
- `toolbox_vX.Y.Z_windows_amd64.zip`

Also included:

- `SHA256SUMS.txt`

Archive contents:

- Linux/macOS: `bin/toolbox`
- Windows: `bin/toolbox.exe`

If you install manually, place the binary somewhere on your `PATH`, then run:

```bash
toolbox --version
toolbox help
```

---

## Quick install scripts

Toolbox provides install scripts for Linux, macOS, and Windows.

### Install latest version

#### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.sh | bash
```

#### Windows (PowerShell)

```powershell
& ([ScriptBlock]::Create((Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.ps1).Content))
```

---

### Update existing installation to latest

#### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.sh | bash -s -- --update
```

#### Windows (PowerShell)

```powershell
& ([ScriptBlock]::Create((Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.ps1).Content)) --update
```

---

### Uninstall

#### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.sh | bash -s -- --uninstall
```

#### Windows (PowerShell)

```powershell
& ([ScriptBlock]::Create((Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.ps1).Content)) --uninstall
```

---

### Install a specific version

#### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.sh | bash -s -- --version vX.Y.Z
```

#### Windows (PowerShell)

```powershell
& ([ScriptBlock]::Create((Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.ps1).Content)) --version vX.Y.Z
```

---

### Install to a custom directory

#### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.sh | bash -s -- --install-dir /custom/bin
```

#### Windows (PowerShell)

```powershell
& ([ScriptBlock]::Create((Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/gfmois/toolbox/main/scripts/install-toolbox.ps1).Content)) --install-dir "C:\tools\bin"
```

---

## Why teams use Toolbox

- **Productize scripts** as versioned plugins instead of copy-paste docs
- **Give non-dev users one command surface** for many tools
- **Keep execution local** while maintaining a consistent interface
- **Scale command catalogs** with namespaces

---

## 60-second quick start

```bash
# 1) Add a plugin (directory, archive, or URL)
toolbox plugin add ./my-plugin

# 2) Sync installed plugins to metadata store
toolbox plugin discover

# 3) View catalog
toolbox plugin list

# 4) Execute
toolbox my-plugin

# or namespaced
toolbox dev my-plugin
```

---

## Core commands

```bash
toolbox help
toolbox plugin add <source>
toolbox plugin discover
toolbox plugin list
toolbox plugin remove <plugin-id>
toolbox plugin init <target-dir>
toolbox db repl
toolbox ui palette list
```

Global flags:

- `--quiet`
- `--verbose`

---

## Plugin package format

Minimum structure:

```text
my-plugin/
├── manifest.json
└── bin/
    └── my-plugin
```

Example manifest:

```json
{
  "schemaVersion": "1.0",
  "id": "example-plugin",
  "name": "Example Plugin",
  "version": "1.0.0",
  "namespace": "dev",
  "description": "Describe what your plugin does",
  "runtime": {
    "type": "executable",
    "entrypoint": "bin/example-plugin"
  }
}
```

Supported runtimes:

- `executable` (`runtime.entrypoint`)
- `command` (`runtime.command`)

---

## Storage locations

Toolbox stores data in:

- Linux/macOS: `~/.config/toolbox`
- Windows: `C:\Users\<user>\.config\toolbox`

Important paths:

- Plugins: `~/.config/toolbox/plugins`
- SQLite DB: `~/.config/toolbox/toolbox.db`

---

## License

See [LICENCE.md](./LICENCE.md).