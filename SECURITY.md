# Security Policy

gPTP Studio is a PTP analysis and qualification studio for Linux: it
captures network traffic through libpcap, drives the linuxptp daemons
(`ptp4l`, `phc2sys`, `pmc`) and reports on the timing path. Its own
surface is analysis — it observes traffic and supervises processes;
reports are taken seriously and handled quickly.

## Reporting a vulnerability

Email **security@jrtx.site** (or open a GitHub security advisory on this
repository). Include reproduction steps, affected versions, and your
assessment of impact. You will get an acknowledgment within 72 hours.

Please do not open public issues for security problems.

## Scope

In scope:

- The capture/analysis data plane: opening libpcap handles on a chosen
  NIC, the decoded-frame store, pcap file reading and writing, and what
  the application learns from captured frames
  (`capture/live.rkt`, `capture/manager.rkt`, `capture/store.rkt`,
  `capture/pcap-io.rkt`). Privilege handling for capture is part of this
  surface: a capture the process is not entitled to open must fail with
  an actionable message, not fall back silently.
- Privilege posture: how the app obtains capture and clock access
  (root, file capabilities or a `pkexec`-confirmed handoff) and the
  packaging guarantee that installers never grant privileges behind the
  operator's back — no `postinst` `setcap`, no sudoers edits
  (`docs/architecture.md`, `support/doctor.rkt` shows the active path).
- Process supervision of the linuxptp tooling: spawning, restarting and
  reporting `ptp4l` / `phc2sys` / `pmc` (`engine/supervisor.rkt`,
  `engine/process-runtime.rkt`). Arguments must come from configuration,
  never from analyzed traffic.
- Update trust: verification of the Ed25519-signed `update-stable.json`
  feed and the downloaded artifact, key handling and rotation
  (`support/updates.rkt`, `scripts/make-update-manifest.rkt`,
  `scripts/check-update-signing-key.sh`; key id `gptp-studio-2026-10`,
  pinned against the shipped anchor `app/keys/updater/public.pem`).
  Contract: [docs/update-contract.md](docs/update-contract.md).
- The entitlement gate over updates: a Pro install stages exactly the
  releases its signed entitlement covers, and an unreadable candidate
  `published_at` refuses staging (fail-closed)
  (`support/entitlement.rkt`, `support/updates.rkt`).
- The host/backend boundary: the GTK4 host renders and interacts; the
  Racket backend (`app/backend.rkt`) decides. Crypto, capture policy or
  privilege logic sneaking into the C++ host is a bug.

Out of scope: vulnerabilities in libpcap, in the linuxptp daemons, in
the kernel's PTP/timestamping stack, or in the PTP networks under
analysis — those belong to their upstream projects. Also out of scope:
social engineering and physical access attacks.

## Design notes reviewers should know

- **Privilege is explicit, never silent.** Capture and clock work need
  elevated privileges on Linux; official packages do not `setcap`,
  modify sudoers or otherwise pre-grant them at install time. The doctor
  and GUI preflight show the active path (root, file capabilities, or
  `pkexec` for the optional update-install handoff), and each elevation
  goes through the system authentication dialog — nothing installs or
  captures without the operator's explicit consent.
- **Hosts never implement crypto.** Every signature check, digest
  computation and trust decision lives in the Racket backend (Rivet's
  distribution layer); the native host only carries out steps the
  backend has already verified.
- **Update trust is anchored in the shipped key.** The feed is
  Ed25519-signed; the client pins key id `gptp-studio-2026-10` and the
  embedded anchor `app/keys/updater/public.pem`; manifests that fail
  verification are rejected before anything is offered. The release job
  signs the feed with `--verify-public-key app/keys/updater/public.pem`,
  re-verifying the written bytes against the shipped anchor before
  anything is committed. Rotation means shipping a build with a new
  anchor (docs/update-contract.md).
- **Update application is consent-gated, per install shape.** A staged
  deb is installed only through the operator-confirmed
  `sudo apt-get install` handoff (optionally via `pkexec`); a tarball
  install swaps in place with a `<root>.old` backup and a failed swap
  attempts to restore it. The updater writes only under
  `~/.local/share/gptp-studio/updates`.
- **Analyzed traffic is data, not control.** Captured frames feed the
  analysis pages and reports; they never feed process arguments,
  configuration or privilege decisions.
- **Capture data stays local.** Captures, stores and reports live on
  disk under the user's control; there is no account, no telemetry and
  no upload path.
- Failure text is redacted and selectable: it names ports, interfaces
  and remediation — never credentials or entitlement material — and the
  About dialog's copy-diagnostics report is safe to paste into a public
  issue.

## Supported versions

Security fixes land on `main` first and ship with the next tagged release.
During the 0.x preview there is no LTS branch.
