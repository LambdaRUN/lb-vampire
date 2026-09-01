# Torpor Revision Design

## Goal
Replace the old timed Stage 1 -> custom Stage 2 downed flow with a single active Torpor state whose HP drains immediately and dynamically, followed by normal QB death, then a no-drain Partial Torpor after revive while Blood remains below the recovery threshold.

## State Model
- `0 NORMAL`
- `1 TORPOR_ACTIVE`: Blood below recovery threshold after depletion. Injury movement, controls restricted, Kin Call available, HP drains.
- QB death/laststand is owned by qb-ambulancejob and is not a custom LB state.
- `2 PARTIAL_TORPOR`: entered after a player who died while in TORPOR_ACTIVE is revived and Blood remains below recovery threshold. Same restrictions, no automatic HP drain.

## Recovery
A single `Config.Torpor.RecoveryBlood` threshold is used for both TORPOR_ACTIVE and PARTIAL_TORPOR. Default: 15 Blood. Recovery does not restore HP.

## Dynamic HP Drain
`Config.Torpor.Active.FullHealthDuration` defines how long `ReferenceHealth` HP lasts in active Torpor. Default: 300 seconds for 100 effective HP.

Drain rate: `ReferenceHealth / FullHealthDuration` HP per second.
Remaining UI time: `CurrentEffectiveHealth / DrainRate`.

Healing during active Torpor increases the estimated remaining time but does not end Torpor. Damage decreases it. At death threshold, LB hides Torpor UI and hands control to normal QB death/laststand.

## Revive Detection
A player that enters QB death while `torporStage == 1` keeps that stage persisted. The client hides LB Torpor while QB owns death. When the client transitions from QB dead/laststand back to alive while stage > 0 and Blood remains below recovery, it asks the server to enter stage 2 (PARTIAL_TORPOR). This avoids hard dependence on one specific EMS revive event while still working with stock qb-ambulancejob.

## Partial Torpor
No HP drain. Injury movement and the same combat/movement/ability restrictions remain. Walking, inventory, qb-target/treatment, Blood Bag use, and passenger transport remain possible. Blood >= 15 returns to NORMAL.

## Kin Call
Available in both active and partial Torpor if the per-collapse call allowance has not been used. It creates only an offset radius blip; never a precise point blip.

## EMS
LB-Vampire adds no custom EMS call or custom downed UI. qb-ambulancejob owns normal death/laststand and EMS alert/revive behavior.

## Deadblood Metadata
Remove nested `info.lbAmmo = { ... }` metadata that stock qb-inventory renders as `[object Object]`. Store the user-visible flat key `info['Mermi Türü'] = Config.DeadBloodAmmo.Label`. Remaining round count comes from standard `info.ammo`. Legacy `info.lbAmmo` is migrated on player load and when a weapon is inspected by the ammo bridge.

## Preserved Systems
Do not alter working Armor -> Blood -> HP math, fall multiplier, damage exemptions, or existing Kin Call radius behavior.
