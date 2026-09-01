# Torpor Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement dynamic active Torpor, QB death handoff, revive-to-partial-Torpor, and flat Deadblood metadata without regressing the existing damage pipeline.

**Architecture:** Keep persisted `torpor_stage` as a compact state enum: 0 normal, 1 active Torpor, 2 partial Torpor. Active drain is client-side health application driven by shared deterministic Torpor math, while server owns Blood recovery/state transitions and Kin Call authorization. Ammo metadata is flattened and migrated server-side.

**Tech Stack:** FiveM Lua 5.4, QBCore, qb-inventory/qb-ambulancejob compatibility, vanilla NUI HTML/CSS/JS, Python regression tests.

**Spec:** `docs/superpowers/specs/2026-09-01-torpor-revision-design.md`

## Global Constraints
- Recovery threshold is 15 Blood for active and partial Torpor.
- No custom LB EMS/downed stage after HP depletion.
- Partial Torpor has no automatic HP drain.
- Kin Call remains radius-only and imprecise.
- Armor -> Blood -> HP and fall multiplier behavior must remain unchanged.
- Deadblood metadata must not contain nested `lbAmmo` objects after migration.

---

### Task 1: Torpor math and config
**Files:** Create `shared/torpor_math.lua`; modify `config/config.lua`, `fxmanifest.lua`; test `tests/test_torpor_revision.py`.
- [ ] Add failing regression assertions for shared math/config and removal of legacy Stage1/Stage2/EMS config.
- [ ] Verify failure.
- [ ] Add shared Torpor math and revised config.
- [ ] Verify pass.

### Task 2: Torpor server state machine
**Files:** Modify `server/torpor.lua`, `server/damage.lua`; test `tests/test_torpor_revision.py`.
- [ ] Add failing assertions for active/partial state semantics, unified recovery, no timer promotion, revive event, lethal QB handoff.
- [ ] Verify failure.
- [ ] Implement server transitions and damage handoff.
- [ ] Verify pass.

### Task 3: Torpor client behavior and NUI
**Files:** Modify `client/torpor.lua`, `web/standalone-hud/torpor.js`, `web/standalone-hud/torpor.css`; test `tests/test_torpor_revision.py`.
- [ ] Add failing assertions for dynamic health countdown, active-only drain, dead->alive partial transition, removal of EMS controls.
- [ ] Verify failure.
- [ ] Implement client behavior and UI.
- [ ] Verify pass plus JS syntax check.

### Task 4: Deadblood metadata migration
**Files:** Modify `server/ammo.lua`; test `tests/test_torpor_revision.py`.
- [ ] Add failing assertions that nested `info.lbAmmo` is no longer written and `Mermi Türü` metadata/migration exist.
- [ ] Verify failure.
- [ ] Implement flat metadata and legacy migration.
- [ ] Verify pass.

### Task 5: Package verification
**Files:** Update `5D-TEST-GUIDE.md`; package full and changed-file ZIPs.
- [ ] Run existing and revision regression suites.
- [ ] Run all NUI JavaScript syntax checks.
- [ ] Verify ZIP CRC and re-run tests against an extracted copy.
