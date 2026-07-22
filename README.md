# remote-LAN-service

Own your remote access. A **wizard-installed**, self-hosted way to reach your machines
(remote desktop over a relay/VLAN you control) — you bring a cloud server and your own
devices, the installer sets everything up. No TeamViewer/Sunlogin-style public service.

**Pick a tier, the installer does the rest:**

| Tier | You get | Server needs |
|---|---|---|
| **A — Simple** | Self-hosted RustDesk server; connect by ID | 1 Linux box |
| **B — Multi-line** | A + optional WireGuard / ZeroTier / Headscale — direct-IP, multi-path, survives one path dying | 1 box |
| **C — Dual-server** | B + a second region for zero-single-point failover | 2 boxes |

Start at A. Grow to B/C later by turning modules on — no redo.

> **Why WireGuard when RustDesk already has its own server?** Tier A (connect by ID) works,
> but depends on the signaling server, gives you one path, and only carries RustDesk. Tier B's
> WireGuard puts your machines on a private VLAN so RustDesk connects by direct IP touching no
> server at all — and that VLAN carries *anything* (RDP/SMB/SSH), over *multiple* swappable
> tunnels for resilience. See [docs/why-wireguard.md](docs/why-wireguard.md).

## Install

**Server (Linux):**
```bash
curl -fsSL <your-host>/install.sh -o install.sh   # or clone this repo
sudo bash install.sh
```
A text wizard asks role → tier → modules → values, pre-checks, then installs only what you picked.

**Client (Windows):** run `setup.exe` (GUI wizard), or:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\install.ps1
```

Unattended / batch: feed a plan and skip the wizard —
`sudo bash install.sh --plan install-plan.json` / `installer.exe /plan=install-plan.json`.

## How it works

Three front-ends (Linux TUI · Windows GUI · unattended plan file), **one back-end**: the wizard
only produces an `install-plan.json`; a platform-agnostic executor runs the selected **modules**.
Each module (`installer/modules/<name>/`) is self-describing — `preflight / up / down / verify` —
so adding a channel is adding a module directory. See [SPEC.md](SPEC.md).

## Security

Private keys are generated on the machine that uses them and never traverse the network. The
installer never edits your cloud security group (no API creds) — it prints which ports to open.
See [docs/SECURITY.md](docs/SECURITY.md).

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — free for noncommercial use. Commercial use requires a
separate arrangement with the author.

## Status

Early. **Tier A (Linux server + Windows client) is the current working target**; B/C modules are
scaffolded. See [SPEC.md](SPEC.md) for the roadmap.
