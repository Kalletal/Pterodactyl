---
description: Align the Synology DS920+ Pterodactyl package constitution with project goals and keep all Speckit templates in sync
---

## Project Context

The repo focuses on producing a reliable Synology `.spk` package so DS920+ owners can run the
Pterodactyl panel (and its system services) with minimal manual work. The constitution must lock in:

- Package reproducibility (cross-compiling, start/stop scripts, DSM service permissions).
- Hardware/DSM compatibility (x86_64, DSM 7+, limited RAM/CPU footprint).
- Security for NAS exposure (least-privilege service user, TLS/reverse proxy expectations, secret
  storage).
- Operability on a consumer NAS (logging, upgrades, recovery paths).
- Alignment with upstream Pterodactyl releases while keeping Synology quirks documented.

Keep these priorities visible whenever you reason about principles or governance.

## User Input

```text
$ARGUMENTS
```

Always incorporate user-provided instructions first. When the user is silent, fall back to repo
artifacts (README, `docs/*.md`, `.specify/memory/constitution.md`, build scripts, DSM service files).

## Execution Flow

1. **Load the template**  
   Open `.specify/memory/constitution.md`, list every `[PLACEHOLDER]`, and confirm whether the user
   expects a different number of principles/sections. If extra or fewer principles are required,
   adjust headings accordingly but keep the same ordering semantics.

2. **Collect concrete values**  
   - Prefer explicit facts from repository docs or scripts. Key sources: Synology packaging notes,
     SPK build tooling, upstream Pterodactyl requirements, changelog files, and any existing
     constitution text.  
   - Map values to placeholders (`[PROJECT_NAME]`, `[PRINCIPLE_*]`, `[SECTION_*]`, governance fields).
   - If a fact is unknown and cannot be inferred, leave a `TODO(<FIELD_NAME>): reason` marker.

3. **Define principle themes tailored to the NAS target**  
   Use (and adapt) the following focus areas unless the user overrides them:
   - **Synology Build Integrity**: deterministic SPK builds, architecture targets, DSM services.  
   - **Pterodactyl Fidelity**: stay API/config compatible with upstream panels and wings, version
     pinning strategy, migration policy.  
   - **Security & Isolation**: service user privileges, firewall/reverse proxy expectations, secrets
     handling, sandboxing guidelines.  
   - **Resource & Observability Discipline**: CPU/RAM limits, background daemons, logging/metrics,
     backup strategy for NAS users.  
   - **Support & Upgrade Path**: release cadence, DSM update compatibility, rollback procedures.
   Replace/add/remove principles when evidence justifies it and document renames in the impact report.

4. **Draft the constitution**  
   - Replace every placeholder; no stray bracket tokens unless explicitly flagged as TODO items.  
   - Keep headings exactly as provided by the template.  
   - Principle body text must be prescriptive, testable, and include rationale or acceptance criteria
     (e.g., “Service scripts MUST run under synopkg-generated users to keep DSM permissions intact”).  
   - Additional sections should cover Synology-specific constraints (e.g., package layout, required
     dependencies, release gates) and development workflow specifics (QA on DSM VMs, cross-compilation
     pipelines, etc.).  
   - Governance must state amendment process, semantic versioning rules, required reviewers, and how
     Synology/Pterodactyl releases trigger reviews.

5. **Versioning and dating**  
   - `RATIFICATION_DATE`: first adoption date; keep existing value unless truly unknown.  
   - `LAST_AMENDED_DATE`: today (UTC).  
   - `CONSTITUTION_VERSION`: bump via SemVer:  
     * MAJOR = incompatible principle/governance change.  
     * MINOR = new principle/section or significant expansion.  
     * PATCH = clarifications only.  
   Explain the bump choice inside the final summary.

6. **Sync Impact Report**  
   Prepend an HTML comment at the top of the constitution capturing: `old_version → new_version`,
   principle changes (renames, additions, removals), added/removed sections, and template sync status
   (✅ updated / ⚠ pending for `plan-template.md`, `spec-template.md`, `tasks-template.md`,
   `checklist-template.md`, and any other touched files). Include outstanding TODOs.

7. **Template & guidance alignment**  
   After drafting, verify that the updated principles are reflected wherever enforced:  
   - `.specify/templates/plan-template.md` (planning checkpoints, build gates).  
   - `.specify/templates/spec-template.md` (scope/acceptance requirements).  
   - `.specify/templates/tasks-template.md` and `checklist-template.md` (task/granularity guidance).  
   - Any other `.codex/prompts/speckit.*.md` files referencing the constitution.  
   Update them immediately when the constitution introduces or removes obligations; otherwise flag as
   ⚠ pending in the impact report.

8. **Validation**  
   - No unexplained placeholders remain.  
   - Dates use `YYYY-MM-DD`.  
   - Principles avoid fuzzy language (“should”) unless paired with explicit rationale.  
   - Governance states how compliance is checked before shipping an SPK release.  
   - File stays Markdown, max ~100-character lines where practical, no trailing whitespace.

9. **Write & summarize**  
   Overwrite `.specify/memory/constitution.md`, then report back with:  
   - New version number + bump rationale.  
   - Files updated or still pending.  
   - Suggested commit message (e.g., `docs: refresh Synology constitution to vX.Y.Z`).

If core data is missing, document the gap, mark TODOs, and highlight them in both the impact report
and final response. The goal is to keep the Synology Pterodactyl package constitution actionable for
contributors who ship an installable NAS build.
