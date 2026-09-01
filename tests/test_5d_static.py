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
torpor_client = read('client/torpor.lua')
torpor_server = read('server/torpor.lua')
damage_client = read('client/damage.lua')
damage_server = read('server/damage.lua')
ammo_server = read('server/ammo.lua')
ability_menu = read('client/ability_menu.lua')
abilities_client = read('client/abilities.lua')
sun_server = read('server/sun.lua')
css = read('web/standalone-hud/torpor.css')
html = read('web/standalone-hud/index.html')

for required in [
    "shared/damage_math.lua",
    "bridge/death/qb.lua",
    "client/torpor.lua",
    "client/damage.lua",
    "client/ammo.lua",
    "server/torpor.lua",
    "server/damage.lua",
    "server/ammo.lua",
    "web/standalone-hud/torpor.css",
    "web/standalone-hud/torpor.js",
]:
    expect(required in manifest, f'manifest includes {required}')

expect("version '0.7.6-5D'" in manifest, 'manifest version is current 5D revision')
expect('Config.VampireDamage' in config, 'damage config exists')
expect('Config.Torpor' in config, 'torpor config exists')
expect('GetConfig().Enabled ~= true' in torpor_server, 'torpor transitions honor the Torpor enabled switch')
expect('Config.DeadBloodAmmo' in config, 'deadblood ammo config exists')
expect('FullHealthDuration = 5 * 60' in config, 'active torpor 100 HP default is five minutes')
expect("NormalMultiplier = 0.25" in config, 'normal bullet resistance default exists')
expect("FALL = { Multiplier = 1.00 }" in config, 'fall damage multiplier is configurable')
expect("types[damageType]" in damage_server and ".Multiplier" in damage_server, 'non-bullet damage types use configured multipliers')
expect("VampireMultiplier = 3.00" in config, 'deadblood x3 default exists')
expect("ItemName = 'ammo_deadblood'" in config, 'deadblood item name is configured')

expect('AddBlipForRadius' in torpor_client, 'kin call uses radius blip')
expect('AddBlipForCoord' not in torpor_client, 'kin call never creates a precise point blip')
expect('OffsetMin' in torpor_server and 'OffsetMax' in torpor_server, 'kin call center is deliberately offset')
expect('EMS = {' not in config, 'LB-Vampire no longer owns a custom EMS alert stage')
expect('backdrop-filter' not in css, 'torpor CSS does not use backdrop-filter')
expect('box-shadow' not in css, 'torpor CSS does not use box-shadow')
expect('id="torporCard"' in html, 'torpor NUI card is mounted')

expect('torporStage' in ability_menu, 'ability menu is locked by torpor state')
expect('torporStage' in abilities_client and "return false, 'torpor'" in abilities_client, 'generic ability execution is blocked during torpor')
expect('healthOverflow' in sun_server and 'directHealthDamage' in sun_server, 'sunlight overflows from Blood into HP without consuming armor')
expect('SetPedSuffersCriticalHits' in damage_client, 'native critical hits are suppressed for vampire routing')
expect('VampireDamage.Enabled ~= true' in damage_client, 'client does not intercept damage when vampire damage routing is disabled')
expect('Damage.pending' in damage_client and 'damage:reject' in damage_client, 'client keeps pending native snapshots for rejected damage fallback')
expect('ClientFallbackTimeout' in config, 'damage fallback timeout is configurable')
expect("damage:reject" in damage_server, 'server rejects failed routed hits back to the client')
expect("exports('SetDamageExemption'" in damage_client, 'generic damage exemption export exists')
expect("ammoVariant" in damage_server and 'GetDamageVariant' in damage_server, 'server damage resolves ammo variants')
expect("info['Mermi Türü']" in ammo_server, 'deadblood state uses flat user-facing weapon metadata')
expect('currentAmmo > 0' in ammo_server and 'normal mühimmatın tamamen bitmiş olmalı' in ammo_server, 'mixed normal/deadblood ammo is rejected')
expect('LastShot' in ammo_server, 'last-shot variant cache exists')
expect('playerDropped' in ammo_server and 'Ammo.LastShot' in ammo_server, 'deadblood last-shot cache is cleaned on disconnect')
expect('collapse_started_at' in read('server/persistence.lua'), 'torpor collapse identity persists')
expect('torpor_stage' in read('sql/lb-vampire.sql'), 'SQL migration includes torpor stage')
expect('kin_calls' in read('server/persistence.lua'), 'kin call usage persists across reconnects')

print(f'5d_static: {len(checks)} checks passed')
