```
          oooo   o8o              .o8                                             
          `888   `"'             "888                                             
 .ooooo.   888  oooo  oo.ooooo.   888oooo.   .ooooo.   .oooo.   ooo. .oo.  .oo.   
d88' `"Y8  888  `888   888' `88b  d88' `88b d88' `88b `P  )88b  `888P"Y88bP"Y88b  
888        888   888   888   888  888   888 888ooo888  .oP"888   888   888   888  
888   .o8  888   888   888   888  888   888 888    .o d8(  888   888   888   888  
`Y8bod8P' o888o o888o  888bod8P'  `Y8bod8P' `Y8bod8P' `Y888""8o o888o o888o o888o 
                       888                                                        
                      o888o                                                       
                                                                                  
```

[![WezTerm Plugin](https://img.shields.io/badge/WezTerm-Plugin-purple)](https://wezfurlong.org/wezterm/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20→%20Linux-blue)](https://github.com/christian-gennari/clipbeam)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![SSH Transfer](https://img.shields.io/badge/Transfer-SSH-orange)]()

**WezTerm plugin for instant screenshot-to-SSH delivery (Windows → Linux)**

Beam clipboard screenshots from Windows straight to your remote Linux servers. No file saving, no SCP commands, no context switching — just snap, beam, done.

> ⚠️ **PREREQUISITE: SSH Key Authentication Required**
>
> **clipbeam will NOT work** without passwordless SSH access configured. You must set up SSH key authentication before using this tool.
>
> Run this once to configure:
> ```bash
> ssh-copy-id user@hostname
> ```
>
> [See Troubleshooting → SSH transfer failed](#ssh-transfer-failed) for more details.

## 3-Second Workflow
<pre style="white-space: pre; font-family: monospace; line-height: 1.2;">
```
┌─────────────┐     ┌─────────────┐     ┌──────────────────────┐
│ Screenshot  │ ──► │ Paste in    │ ──► │ Image on remote      │
│ Win+Shift+S │     │ WezTerm     │     │ ~/.clipbeam/paste.png│
└─────────────┘     │ Ctrl+Shift+I│     └──────────────────────┘
                    └─────────────┘
```
</pre>
**That's it.** Your screenshot is now on your remote server, ready to use.

---

## Why clipbeam?

You're SSH'd into a remote Linux server and need to share a screenshot. Here's what that usually looks like:

| Without clipbeam | With clipbeam |
|------------------|---------------|
| 1. Save screenshot to disk | 1. Screenshot (Win+Shift+S) |
| 2. Open file manager | 2. Press Ctrl+Shift+I |
| 3. Find the file | **Done** |
| 4. Open SCP client or drag to upload service | |
| 5. Transfer to server | |
| 6. Type the path manually | |

**clipbeam eliminates 5 steps.** Perfect for:

- Remote development on Linux servers
- Debugging sessions requiring visual context  
- Technical documentation and tutorials
- Incident response and server monitoring
- Technical support and bug reports

---

## Visual Demo

> **Demo GIF coming soon**
>
> Want to see it in action? Here's what happens:
> 1. User presses `Win+Shift+S` and selects an area
> 2. User switches to WezTerm and presses `Ctrl+Shift+I`
> 3. A toast notification confirms the upload
> 4. The remote path `~/.clipbeam/paste.png` appears in the terminal
> 5. User can immediately reference the image in commands

---

## Quick Install (Recommended)

**Prerequisite:** Ensure passwordless SSH is configured (run once):
```bash
ssh-copy-id user@hostname
```

1. Download and extract the [latest release](../../releases/latest)
2. Double-click `installer/install.bat`
3. Enter your SSH destination (e.g., `user@myserver`)
4. Done!

The installer will:
- Check WezTerm and SSH are installed
- Install the clipbeam plugin
- Safely integrate with your existing WezTerm config (with backup)
- Configure everything automatically

### Silent Install (CI/CD & Automation)

```batch
installer\install.bat -SshHost "user@myserver" -Silent
```

---

## Features vs Alternatives

| Feature | clipbeam | Manual SCP | Cloud Uploads |
|---------|----------|------------|----------------|
| **Steps to share screenshot** | 2 | 6+ | 5+ |
| **Works through SSH tunnels** | Yes | Manual | No |
| **Zero remote dependencies** | Yes (just `base64`) | Yes | Requires browser/app |
| **Auto-resize large images** | Yes (4K→reasonable) | No | Varies |
| **Types path into terminal** | Yes | No | No |
| **Native to terminal workflow** | Yes | No | No |
| **Privacy (no third-party)** | Yes | Yes | Uploads to cloud |

**Bottom line:** If you live in WezTerm and SSH into remote servers, clipbeam is built for you.

---

## Use Cases

### Remote Development

You're coding on a remote Linux server via SSH. A teammate asks about a UI bug. Screenshot your local Windows screen, beam it to the server, paste the path into Slack — all without leaving your terminal.

### Debugging Sessions

Debugging a server issue and need to share logs or error states? Screenshot the error, upload instantly, reference the image in your incident channel or documentation.

### Technical Documentation

Creating a deployment guide or runbook? Screenshot each step on Windows, beam to your documentation server, include the images directly in your markdown.

### Incident Response

Monitoring dashboard shows an anomaly? Screenshot it, instantly share the image to your incident response server for team analysis.

### Technical Support

Helping a colleague with a remote server issue? Visual context without the back-and-forth of "can you describe what you see?"

---

## Configuration

The installer sets sensible defaults:

| Setting | Default | Description |
|---------|---------|-------------|
| **Remote path** | `~/.clipbeam/paste.png` | Where images are saved on the server |
| **Max dimension** | 3840px | Auto-resize if larger (keeps transfer fast) |
| **Keybinding** | `Ctrl+Shift+I` | Trigger the beam action |
| **Copy file path** | `true` | Auto-type the path into terminal |

### Custom Configuration

Edit your `wezterm.lua` to customize:

```lua
local clipbeam = require 'plugins.clipbeam'
local clipbeam_keybinding = clipbeam.setup({
  host = "user@myserver",              -- Required: SSH destination
  remote_path = "~/images/debug.png", -- Custom save location
  max_dimension = 1920,               -- Smaller images for speed
  copy_file_path = true,                -- Auto-paste path
  notify_on_success = false,            -- Silent mode
})
if clipbeam_keybinding then
  table.insert(config.keys, clipbeam_keybinding)
end
```

### Multiple Servers

Configure different keybindings for different servers:

```lua
-- Production server
local prod_binding = clipbeam.setup({
  host = "prod@production-server",
  remote_path = "~/incident-images/screenshot.png",
  notify_on_success = true,
})
table.insert(config.keys, {
  key = "I", mods = "CTRL|SHIFT|ALT",  -- Alt for production
  action = prod_binding.action
})

-- Development server (default binding)
local dev_binding = clipbeam.setup({ host = "dev@dev-server" })
table.insert(config.keys, dev_binding)
```

---

## Requirements

**Local (Windows):**
- Windows 10/11
- [WezTerm](https://wezfurlong.org/wezterm/) terminal emulator
- SSH client (included with Windows 10/11 or Git for Windows)

**Remote (Linux):**
- Any Linux server with SSH access
- `base64` utility (installed by default on Ubuntu/Debian/CentOS/Fedora)
- Write permissions to `~/.clipbeam/` (auto-created on first use)

---

## How It Works

1. **Capture** — PowerShell extracts image from Windows clipboard as base64
2. **Resize** — If image > 4K, resize preserving aspect ratio (faster transfer)
3. **Transfer** — SSH pipes base64 data to remote server
4. **Decode** — Remote server runs `base64 -d` to create PNG file
5. **Integrate** — WezTerm types the file path into your active terminal pane

**Zero dependencies on the remote side** — just needs the standard `base64` utility that's already on every Linux distribution.

---

## Troubleshooting

### "WezTerm not found"

Make sure WezTerm is installed: https://wezfurlong.org/wezterm/installation.html

### "SSH transfer failed"

Verify SSH access works without password:
```bash
ssh your-host
```

If it prompts for password, set up SSH keys:
```bash
ssh-copy-id user@hostname
```

### "No image in clipboard"

Take a screenshot first with `Win+Shift+S` before pressing `Ctrl+Shift+I`

### Image not appearing on remote

Check the remote directory exists and you have write permissions:
```bash
ls -la ~/.clipbeam/
```

### Slow transfers

Large screenshots are automatically resized to 3840px max dimension. For even faster transfers on slow connections, reduce this in config:

```lua
max_dimension = 1920  -- Full HD max
```

---

## Uninstallation

To completely remove clipbeam:

1. Double-click `installer/uninstall.bat`
2. The uninstaller will:
   - Remove clipbeam code from your WezTerm config
   - Delete plugin files
   - Offer to restore from backup

### Silent Uninstall

```batch
installer\uninstall.bat -Silent
```

---

## Project Structure

```
clipbeam/
├── clipbeam.lua          # The WezTerm plugin (source of truth)
├── installer/
│   ├── install.bat       # Double-click to install
│   ├── install.ps1       # Installation logic
│   ├── uninstall.bat     # Double-click to uninstall
│   └── uninstall.ps1     # Uninstallation logic
├── LICENSE
└── README.md             # This file
```

---

## Roadmap

- [x] Screenshot capture support
- [x] Self-contained installer
- [ ] Support for copied image files (from Explorer)
- [ ] Custom keybinding configuration in installer
- [ ] GUI installer option
- [ ] Linux → Linux support (for local Linux users)

---

## Contributing

Found a bug or have a feature idea? [Open an issue](../../issues/new) or submit a PR!

**Development workflow:**
1. Clone this repository
2. Edit `clipbeam.lua` for plugin changes
3. Edit files in `installer/` for installer changes
4. Test by running `installer/install.bat`

---

## License

See [LICENSE](LICENSE) file for details.

---

## Credits

Built for developers who need seamless image sharing between Windows workstations and remote Linux development servers.

**If clipbeam saves you time, please star this repo!**
