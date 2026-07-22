# Security norms

Inherited from the author's production kit; non-negotiable in this product.

1. **Private keys never traverse the network.** WireGuard/SSH keys are generated on the machine
   that uses them; only public keys are sent. The installer never generates a client's private
   key on a server and mails it over.
2. **No secrets in the repo or in a committed plan.** `install-plan.json` is gitignored; if a
   module needs a secret, it stays in a separate gitignored file, never in the tracked example.
   Run `git check-ignore <file>` before committing anything key-shaped.
3. **The installer does not touch your cloud security group.** It has no cloud API credentials; it
   only *prints* which ports to open. You open them in your provider console.
4. **Minimal exposure + auth by default.** Open only the ports a chosen tier needs. Bind services
   to the interface they need, not `0.0.0.0`, where the module allows it.
5. **No silent overwrite of existing services.** Every module `preflight` checks for port/þservice
   conflicts and aborts rather than clobber. You decide.
6. **Reversible.** Every module has `down` that stops/removes what it added and keeps data (keys)
   by default; purging keys is an explicit opt-in.
7. **Integrity of downloads.** Binaries are fetched over TLS from official sources; where a China
   network can't reach them, the module accepts a pre-staged file in `installer/vendor/` instead
   of silently proceeding.
