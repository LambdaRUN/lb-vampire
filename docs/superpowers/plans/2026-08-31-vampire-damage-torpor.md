# Vampire Damage & Torpor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the 5D vampire damage router, Deadblood ammo bridge, persistent two-stage Torpor, Kin Call area blip, and Torpor UI on top of the user's uploaded resource.

**Architecture:** Keep damage math pure and configurable, route runtime state through server modules, and keep GTA/NUI side effects in focused client modules. Existing Blood APIs remain the single way to mutate vampire Blood so Torpor transitions also react to feeding, blood bags, sunlight, and future abilities.

**Tech Stack:** FiveM Lua, QBCore, qb-inventory adapter, qb-ambulancejob event compatibility, vanilla NUI HTML/CSS/JS, MySQL/oxmysql.

**Spec:** `docs/superpowers/specs/2026-08-31-vampire-damage-torpor-design.md`

## Global Constraints
- Use the uploaded `lb-vampire (1).zip` as source of truth.
- Preserve existing Config values unless 5D introduces a new block.
- No full-screen CEF backdrop-filter or full-screen box-shadow.
- Kin Call uses an approximate radius blip, never a precise point.
- EMS uses stock qb-ambulancejob alert handling rather than a new dispatch bridge.

---

### Task 1: Pure damage math and config
**Files:** Create `shared/damage_math.lua`; modify `config/config.lua`, `fxmanifest.lua`; test `tests/test_damage_math.lua`.
**Produces:** `LBVampire.DamageMath.Calculate(rawDamage, armor, blood, effectiveHealth, multiplier)`.

### Task 2: Persistent Torpor state machine
**Files:** Create `server/torpor.lua`, `client/torpor.lua`; modify `server/blood.lua`, `server/vampires.lua`, `server/persistence.lua`, `sql/lb-vampire.sql`, `fxmanifest.lua`.
**Produces:** server-authoritative Stage 0/1/2 transitions, recovery thresholds, reconnect persistence, Stage 2 health drain, state sync.

### Task 3: Damage router and exemptions
**Files:** Create `server/damage.lua`, `client/damage.lua`; modify `fxmanifest.lua`.
**Produces:** normalized damage routing, Blood/HP overflow, generic FALL exemption API, client health/armor reconciliation.

### Task 4: Deadblood ammo adapter
**Files:** Create `server/ammo.lua`, `client/ammo.lua`; modify `config/config.lua`, `fxmanifest.lua`.
**Produces:** `ammo_deadblood`, weapon metadata tracking, mixed-ammo rejection, last-shot variant cache.

### Task 5: Torpor UI and Kin Call
**Files:** Create `web/standalone-hud/torpor.css`, `web/standalone-hud/torpor.js`; modify `web/standalone-hud/index.html`, `fxmanifest.lua`, `server/torpor.lua`, `client/torpor.lua`.
**Produces:** local Stage 1/2 card, countdown, H Kin Call, approximate radius blip, stock EMS alert on G in Stage 2.

### Task 6: Ability and sunlight integration
**Files:** Modify `client/ability_menu.lua`, `server/sun.lua`.
**Produces:** ability menu disabled during Torpor; sunlight consumes HP once Blood is 0.

### Task 7: Verification and packaging
**Files:** Add static/regression tests under `tests/`; package full resource and changed-files ZIP.
**Produces:** syntax checks, damage-math tests, manifest/file checks, package artifacts.
