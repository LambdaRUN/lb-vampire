from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding='utf-8')

checks = []

def expect(condition, message):
    if not condition:
        raise AssertionError(message)
    checks.append(message)

manifest = read('fxmanifest.lua')
config = read('config/config.lua')
server_torpor = read('server/torpor.lua')
client_torpor = read('client/torpor.lua')
server_damage = read('server/damage.lua')
ammo_server = read('server/ammo.lua')
ui_js = read('web/standalone-hud/torpor.js')
ui_css = read('web/standalone-hud/torpor.css')

# Shared deterministic torpor math is part of the runtime contract.
expect("shared/torpor_math.lua" in manifest, 'manifest includes shared torpor math')
torpor_math = read('shared/torpor_math.lua')
expect('GetSecondsRemaining' in torpor_math, 'torpor math exposes dynamic remaining-time calculation')
expect('GetDrainIntervalMs' in torpor_math, 'torpor math exposes drain interval calculation')

# Config: one recovery threshold and active/partial state sections.
expect('RecoveryBlood = 15' in config, 'single recovery threshold defaults to 15 Blood')
expect('FullHealthDuration = 5 * 60' in config, '100 HP active torpor defaults to five minutes')
expect('ReferenceHealth = 100' in config, 'torpor reference health defaults to 100')
expect('Active = {' in config and 'Partial = {' in config, 'torpor config uses active and partial sections')
expect('Stage1 = {' not in config and 'Stage2 = {' not in config, 'legacy stage config blocks are removed')
expect('EMS = {' not in config, 'custom LB EMS config is removed')

# Server state semantics: stage 1 active, stage 2 partial, no timer-driven stage promotion.
expect('EnterActive' in server_torpor, 'server exposes active torpor transition')
expect('EnterPartial' in server_torpor, 'server exposes partial torpor transition')
expect('revivedFromTorpor' in server_torpor, 'server handles revive into partial torpor')
expect('stage1_timer_elapsed' not in server_torpor and 'offline_timer_elapsed' not in server_torpor, 'timer-driven custom stage2 promotion is gone')
expect('forceStage2' not in server_torpor, 'legacy force-stage2 event is removed')
expect('RecoveryBlood' in server_torpor and 'Stage1Config' not in server_torpor and 'Stage2Config' not in server_torpor, 'server uses unified recovery threshold')
expect('ClampStage(state.torporStage) <= STAGE_NORMAL' in server_torpor, 'kin call rejects only normal state and therefore supports active and partial torpor')

# Lethal damage now hands directly to QB death while preserving torpor origin state.
expect("EnterActive(source, 'damage_lethal_overflow')" in server_damage, 'lethal Blood depletion enters active torpor before QB death')
expect('enteredStage2' not in server_damage, 'damage router no longer creates custom downed stage2')
expect('kill = true' in server_damage, 'lethal overflow is handed to native/QB death')

# Client: dynamic current-HP countdown, active-only drain, no EMS prompt/downed animation.
expect('GetSecondsRemaining' in client_torpor, 'client countdown is calculated from current HP')
expect('GetDrainIntervalMs' in client_torpor, 'client drain cadence comes from shared torpor math')
expect('Torpor.stage == STAGE_ACTIVE' in client_torpor and 'nextDrainAt' in client_torpor, 'HP drain runs only while active torpor')
expect('revivedFromTorpor' in client_torpor, 'client detects QB dead-to-alive transition')
expect('hospital:server:ambulanceAlert' not in client_torpor, 'client has no custom EMS alert flow')
expect('DisableAllControlActions' not in client_torpor, 'legacy custom downed control lock is removed')
expect('AnimDict' not in client_torpor and 'AnimName' not in client_torpor, 'legacy downed animation path is removed')

# NUI shows active countdown and partial-torpor state; no EMS action.
expect('KISMİ TORPOR' in ui_js, 'NUI renders partial torpor state')
expect('Acil yardım' not in ui_js and 'EMS' not in ui_js, 'NUI no longer exposes LB EMS action')
expect("is-partial" in ui_js and '.torpor-card.is-partial' in ui_css, 'partial torpor has a local visual state')

# Deadblood metadata: flat user-facing key, no nested object writes, legacy migration remains.
expect("['Mermi Türü']" in ammo_server or '[\"Mermi Türü\"]' in ammo_server, 'ammo metadata uses Mermi Türü display key')
expect('MigrateLegacyAmmoInfo' in ammo_server, 'legacy nested ammo metadata is migrated')
expect("info.lbAmmo = {" not in ammo_server, 'server no longer writes nested lbAmmo objects')
expect('remaining = newAmmo' not in ammo_server, 'ammo remaining is no longer duplicated in nested metadata')
expect("return 'deadblood'" in ammo_server, 'flat metadata resolves to internal deadblood variant')

# Existing damage config remains intact.
expect("FALL = { Multiplier = 1.00 }" in config, 'fall multiplier remains configurable')
expect('NormalMultiplier = 0.25' in config, 'normal bullet resistance remains unchanged')
expect('VampireMultiplier = 3.00' in config, 'deadblood vampire multiplier remains unchanged')

print(f'torpor_revision: {len(checks)} checks passed')
