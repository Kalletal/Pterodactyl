# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: User description: "$ARGUMENTS"

> Specs must prove compliance with the Synology DS920+ constitution before tasks are generated.

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements (panel, wings, DSM hooks)

- **FR-001**: SPK build MUST update `spk/pterodactyl/` metadata / service scripts to deliver [capability].
- **FR-002**: Runtime MUST write/read configuration through `/var/packages/pterodactyl/var` (panel.env, wings config) with correct ownership.
- **FR-003**: Docker stack MUST expose ports [list] and register them through `.sc` files / DSM firewall.
- **FR-004**: Upgrade/uninstall scripts (`service_pre*`, `service_post*`) MUST preserve user data and docker volumes.
- **FR-005**: SECURITY: Secrets (DB, tokens) MUST remain in files with `600` permission; document how they are rotated.

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Synology-Specific Requirements

- **SR-001**: `scripts/package/*.sh` MUST [e.g., fetch toolchains, enforce docker availability].
- **SR-002**: `cross/` or `native/` packages MUST [e.g., pin upstream tag, add digests].
- **SR-003**: `spk/scripts/verify-perms.sh` MUST cover any new files/dirs introduced.
- **SR-004**: Document operator action in `docs/` (panel.env fields, TLS expectations, backup changes).
- **SR-005**: Resource plan MUST confirm CPU/RAM budget (<2 GB / 70% CPU) and disk usage for DS920+.

### Key Entities / Artifacts

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Synology Constraints & Security Notes

- **Service User / Permissions**: [Describe changes to `sc-pterodactyl`, docker group membership, ACL updates]
- **Secrets**: [List `.env` keys, certificate files, token rotation steps]
- **Networking**: [Ports, TLS cert handling, reverse proxy guidance]
- **Compliance**: [Firewalls, DSM package dependencies (`php83`, `Docker`), additional approvals]

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes (tie back to constitution)

- **SC-001**: Build reproducibility – `make package` succeeds locally + CI with documented toolchain hash.
- **SC-002**: Runtime smoke – docker-compose stack starts, `spk/scripts/verify-perms.sh` passes, resource usage within target.
- **SC-003**: Security – no secrets world-readable, TLS expectations documented, lint/checklist complete.
- **SC-004**: Upgrade – `synopkg upgrade` path exercised with panel env + wings config preserved.

## Upgrade & Support Considerations

- **DSM Compatibility**: [List DSM/arch combos validated]
- **Upgrade Steps**: [Pre/post upgrade actions, data migrations, wizard prompts]
- **Rollback Plan**: [How to restore previous SPK / docker volumes]
- **Docs to Update**: [README, operator guide, CHANGELOG, release notes]
