# clipbeam

Beam clipboard images from Windows to a headless Ubuntu server via SSH, landing the remote path directly into any terminal TUI (including OpenCode).

Zero dependencies beyond what Windows and Ubuntu already ship.

---

## Problem

When running an AI coding TUI (like OpenCode) over SSH on a headless Ubuntu server, there is no way to paste a clipboard image from your local Windows machine. Display-server-based tools (clipssh, cc-clip) don't work headless. SCP-based tools (pastehop) require server-side setup and leave files accumulating. No existing tool types the resulting path directly into a TUI.

---

## Solution

1. WezTerm keybind (`Ctrl+Shift+I`) triggers a Lua event
2. PowerShell grabs the clipboard image, resizes if over 1920px, base64-encodes it — all in memory
3. WezTerm SSH's to the remote server as a background process (out-of-band, not through the active pane)
4. The server decodes it to `/tmp/paste_img.png` (always overwriting — no cleanup needed)
5. WezTerm types only the path into the active pane — works in any TUI, shell, or prompt

---

## Stack

- **WezTerm Lua** — keybind, event handling, out-of-band SSH
- **PowerShell + System.Windows.Forms + System.Drawing** — clipboard access, resize, base64 encode (all built into Windows)
- **OpenSSH client** — built into Windows 10/11, used by WezTerm for the background transfer
- **coreutils `base64`** — decode on the Ubuntu server (always present)

---

## Milestones

### M1 — Core working
- [ ] WezTerm Lua event wired to `Ctrl+Shift+I`
- [ ] PowerShell block grabs clipboard image and base64-encodes it
- [ ] Resize logic caps image at 1920px, preserving aspect ratio
- [ ] WezTerm fires out-of-band SSH to decode and save `/tmp/paste_img.png`
- [ ] Path typed into active pane without newline

### M2 — Config and DX
- [ ] `SSH_HOST` variable at top of Lua config (single place to edit)
- [ ] Graceful handling when clipboard has no image (silent no-op or log)
- [ ] Graceful handling when SSH fails (log error, don't type garbage into pane)
- [ ] Optional: configurable `$maxDim` and remote path

### M3 — Repo and docs
- [ ] GitHub repo created (`clipbeam`)
- [ ] `wezterm.lua` snippet as the main deliverable
- [ ] `README.md` with setup steps, requirements, and usage
- [ ] Note on compatibility: Windows 10/11, WezTerm, headless Ubuntu, any SSH-accessible server

---

## Files

```
clipbeam/
├── README.md
└── wezterm.lua        # drop-in config snippet, SSH_HOST configurable at top
```

Intentionally minimal — this is a single-file tool. No build step, no install script, no daemon.

---

## Requirements

| Where | What | Built-in? |
|---|---|---|
| Windows | PowerShell | Yes |
| Windows | System.Windows.Forms | Yes |
| Windows | System.Drawing | Yes |
| Windows | OpenSSH client | Yes (Win 10/11) |
| Windows | WezTerm | Install once |
| Ubuntu | `base64` (coreutils) | Yes |
| Ubuntu | SSH server (`sshd`) | Assumed |

---

## Out of Scope

- macOS or Linux local machines
- Terminals other than WezTerm
- Multiple simultaneous images (one file, always overwritten — by design)
- Automatic cleanup (not needed — single static path)
- Server-side install or daemon
