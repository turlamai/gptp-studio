# Contributing to gPTP Studio

Thank you for looking under the hood. gPTP Studio is Apache-2.0 (see
[LICENSE](LICENSE)): by submitting a pull request you agree your
contribution is licensed under Apache-2.0.

## Ground rules

1. **gPTP Studio is Linux-only by design.** Professional gPTP work
   depends on the Linux timing path — PHC, hardware timestamping,
   `SO_TIMESTAMPING`, linuxptp — and the product does not maintain
   reduced-function desktop ports (README, [docs/architecture.md](docs/architecture.md)).
2. **The RPC surface is the contract.** `app/backend.rkt`'s
   `define-rpc` declarations are the host's only data channel; changing
   any signature is a host + backend change in the same commit —
   regenerate with `raco rivet generate` (`linux/GeneratedBackend.hpp`
   is a build input, never hand-edit it). The host renders and
   interacts; capture, the engine, licensing and updates all live in
   the Racket backend.
3. **The update contract is written down — keep it true.**
   [docs/update-contract.md](docs/update-contract.md) is the single
   source of truth for the updater: the Ed25519-signed feed, the pinned
   key id `gptp-studio-2026-10` and the shipped anchor
   `app/keys/updater/public.pem`, the 4 h silent-check throttle, the
   consent dialogs and the per-install-shape apply flows. Hosts never
   implement crypto; every trust decision lives in the backend.
4. **Privilege is explicit.** Capture and clock access follow the
   declared posture: no `postinst` `setcap`, no sudoers edits, no
   silent elevation — the doctor/preflight shows the active path and
   each elevation goes through a system authentication dialog
   (docs/architecture.md). A change that quietly widens privileges is a
   security regression, not a feature.
5. **`rivet-acceptance.rktd` is the executable acceptance gate;**
   [ACCEPTANCE.md](ACCEPTANCE.md) is its manual complement (real
   NIC/PHC/precision claims live in
   [docs/hardware-qualification.md](docs/hardware-qualification.md)). Do
   not delete requirements, weaken assertions, substitute CLI checks
   for GUI behavior, or reuse old evidence to turn a result green.
6. **Fail honestly.** The updater's silent mode ignores network and
   verification failures (never nags) while manual mode reports every
   outcome; a failed tarball swap restores `<root>.old`; error text
   names the failure and the remedy and is selectable/copyable. No
   silent fallbacks.
7. **Tests pin contracts.** If you change behavior a test covers,
   change the test in the same commit and say why
   (`tests/update-test.rkt` alone pins most of the update policy).

## Before you push

```bash
raco test tests/*.rkt                          # backend contract tests
bash scripts/e2e/test-wait-app-exit.sh         # native exit-gate regression
bash scripts/check-update-signing-key.sh --self-test  # offline signer trust-root regression
bash scripts/check-release-version.sh          # VERSION == info.rkt == app-version == rivet.rktd == CHANGELOG
```

These mirror the CI `test` job. Building the GTK4 host additionally
needs the Linux dependency set (`libgtk-4-dev libpcap-dev linuxptp …` —
see `.github/workflows/ci.yml`); Linux developers should run
`raco rivet build` before pushing host changes and say whether the
build was verified locally. The full Linux product acceptance is
`raco rivet acceptance --json`.

## Reporting issues

Include: distribution + version, gPTP Studio version, install shape
(deb / rpm / AppImage / tar.gz), NIC and PTP hardware details for
timing issues, and the About dialog's copy-diagnostics doctor report.
For update failures, include the dialog error text. Security issues go
through [SECURITY.md](SECURITY.md), not public issues.
