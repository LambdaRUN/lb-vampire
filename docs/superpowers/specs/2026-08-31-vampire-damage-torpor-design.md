# Vampire Damage & Torpor Design (5D)

## Goal
Create the vampire combat/survival foundation where incoming damage is routed through configurable vampire rules, Blood acts as the primary supernatural reserve, Blood 0 triggers a two-stage Torpor flow, special Deadblood ammunition can bypass normal vampire bullet resistance, and future abilities can register damage exemptions such as Super Jump fall immunity.

## Locked gameplay rules
- Damage pipeline: classify -> apply vampire multiplier/ammo variant -> Armor -> Blood -> effective HP.
- Human damage remains untouched.
- Normal bullets are strongly resisted by vampires; Deadblood ammunition uses its own vampire multiplier and is not multiplied by the normal bullet resistance.
- Environmental damage types include FALL, VEHICLE, EXPLOSION, FIRE, DROWNING, SUNLIGHT and UNKNOWN.
- Future Super Jump does zero FALL damage through a generic damage-exemption API; Super Jump itself is not implemented in 5D.
- Stage 1 starts whenever Blood reaches 0 while effective HP remains above 0. Duration: 5 minutes by default.
- Stage 1 restrictions: injured walk, no sprint, jump, melee, aiming/firing, weapon switching, driving, or vampire abilities.
- Stage 1 recovers when Blood reaches a configurable threshold (default 5).
- During Stage 1 Blood is already 0, so subsequent routed damage overflows directly into HP.
- If HP reaches 0 at any time, Stage 2 starts immediately; otherwise Stage 1 becomes Stage 2 when its timer expires.
- Stage 2 uses a downed/death-like animation but remains an LB-Vampire Torpor state until HP finally reaches the GTA/QB death threshold.
- Stage 2 loses effective HP over time and recovers only after a higher Blood threshold (default 15). Recovery restores at least 30% effective HP.
- Kin Call is available in Stage 1. It notifies online vampires and creates a small radius/search-area blip around an intentionally offset approximate location. It never creates a precise point blip.
- EMS uses the server's existing qb-ambulancejob alert event; LB-Vampire does not build a second dispatch system.
- Collapse start timestamp, Torpor stage, and Kin Call usage persist so reconnecting cannot reset the 5-minute Stage 1 timer or regain a used Kin Call.
- Full-screen Torpor atmosphere must not use CEF backdrop-filter or full-screen box-shadow. NUI only renders local cards; optional screen effects use FiveM natives.

## Deadblood ammo
- Item: `ammo_deadblood`, label `Ölü Adamın Kanından Mermi`.
- Dynamically registered in QBCore where supported; uses an existing ammo image by default.
- Loaded into the currently selected firearm only when the weapon has zero normal ammo or already contains Deadblood ammo.
- Weapon item metadata stores `info.lbAmmo = { type = 'deadblood', remaining = N }`.
- Mixed normal/Deadblood ammo is rejected.
- A short server-side last-shot cache prevents the final Deadblood round from being misclassified after metadata reaches zero.
- Inventory logic is behind an ammo adapter so other inventory providers can be added later.

## Technical damage model
- Client observes local damage and immediately restores the pre-hit health/armor snapshot for vampire targets, preventing native damage and LB damage from stacking. If the server rejects or does not answer the routed hit within the configured timeout, the observed native damage is reapplied once so routing failure cannot create invulnerability.
- Client reports observed native damage plus normalized damage type and attacker source to server.
- Server validates vampire state, resolves special ammo variant server-side, calculates final damage, consumes Armor/Blood/HP in order, updates authoritative Blood, then sends the resulting armor/effective-health state to the owning client.
- Effective HP is GTA entity health minus the 100-point ped baseline.
- Damage exemptions are checked client-side before submitting a routed damage event, and only for the matching normalized type.
- The first in-game test pass must specifically exercise headshots, shotguns, automatic weapons and large single-frame damage because FiveM/QB death handlers can be sensitive to event ordering.
