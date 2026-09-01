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
damage_server = read('server/damage.lua')
damage_client = read('client/damage.lua')
torpor_client = read('client/torpor.lua')
items_server = read('server/items.lua')
bloodbag_client = read('client/bloodbag.lua')

expect("version '0.7.5-5D'" in manifest, 'manifest version is 5D.5')
expect("bridge/death/qb.lua" in manifest, 'QB death bridge is loaded')
expect('InterceptPlayerWeaponHits = true' in config, 'all PvP weapon hits can be intercepted')
expect("data.willKill ~= true" not in damage_server, 'weapon interception is not limited to willKill')
expect('CancelEvent()' in damage_server and "interceptWeapon" in damage_server, 'vampire PvP weapon hits are canceled and rerouted')
expect('metadata.isdead == true or metadata.inlaststand == true' in damage_server, 'QB-owned death states are excluded from LB weapon interception')
expect('ConsumeWeaponIntercept' in damage_server, 'weapon intercepts are server validated')
expect('attackerSource = attackerSource' in damage_server and 'weaponHash = weaponHash' in damage_server, 'lethal result carries attacker context')
expect('LBVampire.DeathBridge' in damage_client, 'damage client delegates lethal handoff to death bridge')
expect("ApplyDamageToPed(ped, 1000, true)" not in damage_client, 'damage client no longer relies on ApplyDamageToPed for QB handoff')
expect('RestoreLivingState' in torpor_client, 'normal torpor cleanup restores living controls')

death_bridge = read('bridge/death/qb.lua')
expect("TriggerEvent('gameEventTriggered', 'CEventNetworkEntityDamage'" in death_bridge, 'QB handoff synthesizes the event QB ambulance listens for')
expect('NetworkResurrectLocalPlayer' in death_bridge, 'revive watchdog can recover orphan-dead peds')
expect("RegisterNetEvent('hospital:client:Revive'" in death_bridge, 'revive watchdog listens to QB revive')
expect('SetPlayerControl(PlayerId(), true' in death_bridge, 'revive cleanup restores player controls')

expect("lb-vampire:client:bloodbag:startUse" in items_server, 'usable bloodbag starts client presentation')
expect("lb-vampire:server:bloodbag:completeUse" in items_server, 'bloodbag completion is handled server-side')
expect("lb-vampire:server:bloodbag:cancelUse" in items_server, 'bloodbag cancel is handled server-side')
expect('BloodBags.UseSessions' in items_server, 'bloodbag use has server session/token state')
expect("QBCore.Functions.Progressbar" in bloodbag_client, 'bloodbag uses progressbar')
expect("mp_player_intdrink" in config and "loop_bottle" in config, 'bloodbag uses requested animation')
expect("prop_energy_drink" in config and '60309' in config, 'bloodbag uses requested prop and bone')
expect("blood_mist" in config and 'StartParticleFxNonLoopedOnPedBone' in bloodbag_client, 'bloodbag uses blood FX while administering')

print(f'5d5_combat_bloodbag: {len(checks)} checks passed')
