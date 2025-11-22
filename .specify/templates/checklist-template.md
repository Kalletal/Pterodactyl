# [CHECKLIST TYPE] Checklist: [FEATURE NAME]

**Purpose**: Verify the [deployment/testing/release] request against the Pterodactyl Synology constitution.
**Created**: [DATE]
**Feature**: [Link to spec.md or tracking issue]

> Replace every placeholder below with concrete Yes/No answers and evidence links/logs.

## Synology Build Integrity

- [ ] CHK-BLD-001 `make package` (or `scripts/package/build-spk.sh`) executed with noted SYNO_SDK_IMAGE + ARCH/TCVERSION.
- [ ] CHK-BLD-002 `dist/*.spk` and `.sha256` artifacts generated, checksums attached to PR or release draft.
- [ ] CHK-BLD-003 `cross/` & `spk/` metadata updated (versions, digests, FW ports) and documented.

## Pterodactyl Fidelity

- [ ] CHK-FID-001 Panel & Wings versions (and docker images) match upstream tags noted in spec/plan.
- [ ] CHK-FID-002 Config templates (`panel.env.example`, `wings.config.example.yml`) updated + instructions for new keys.
- [ ] CHK-FID-003 Wizards/operator docs highlight any behaviour differences vs upstream (paths, ports, TLS).

## Security & Isolation

- [ ] CHK-SEC-001 `panel.env`/secret files verified at `600`, ownership enforced via `service-setup.sh`.
- [ ] CHK-SEC-002 Docker/ACL changes documented (service user in docker group, firewall `.sc` updates, TLS expectations).
- [ ] CHK-SEC-003 `spk/scripts/verify-perms.sh` updated/executed with evidence (log snippet / screenshot).

## Resource & Observability Discipline

- [ ] CHK-RES-001 CPU/RAM/disk impact measured or reasoned for DS920+ (<2 GB RAM idle, <70% CPU).
- [ ] CHK-RES-002 Logging/metrics destinations identified (e.g., `/var/packages/pterodactyl/var/pterodactyl.log`, Docker stats, DSM Log Center notes).
- [ ] CHK-RES-003 Backup/restore implications covered (panel DB, docker volumes, wings config).

## Support & Upgrade Path

- [ ] CHK-SUP-001 `service_pre*`/`service_post*` hooks reviewed for migrations + rollback, notes captured.
- [ ] CHK-SUP-002 DSM compatibility + dependency matrix (`php83`, Docker) documented in release notes.
- [ ] CHK-SUP-003 Manual DSM test (VM or hardware) recorded, or exception + follow-up issue filed.

## Notes

- Use `[x]` once evidence is attached.
- Reference log files, screenshots, or commits for each checked item.
- Add extra rows per category when the feature introduces new gates.
