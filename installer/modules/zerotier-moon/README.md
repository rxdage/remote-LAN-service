# module: zerotier-moon

**Status: scaffold (not yet implemented).** Reserved for the roadmap (see ../../SPEC.md §5).

Each module must provide, when implemented:
- `preflight.sh` / `preflight.ps1` — check, touch nothing, fail early
- `up.sh` / `configure.ps1` — install, idempotent
- `verify.sh` / `verify.ps1` — assert it works, print next-steps
- `down.sh` — reverse (keep data by default)

Reuse source (author's fleet repo, strip fleet-specifics — enrollment/CA):
- wireguard-hub  ← resilient-remote-access/scripts/deploy-wg-hub.sh
- zerotier-moon  ← resilient-remote-access/scripts/deploy-moon.sh + orbit-moon.ps1
- client-overlay ← remote-hq-design mod-wireguard.ps1 / mod-zerotier.ps1 (WITHOUT enroll/CA)
- line-panel     ← resilient-remote-access/scripts/line-panel*.ps1
- headscale      ← headscale deb + config, client mod-tailscale.ps1 (strip CA/enroll)
- second-region  ← a second wireguard-hub + zerotier-moon on VPS #2, hbbs failover
