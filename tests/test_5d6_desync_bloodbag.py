from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def test_server_does_not_cancel_weapon_damage_events():
    text = read('server/damage.lua')
    assert "AddEventHandler('weaponDamageEvent'" not in text, 'server weaponDamageEvent interception must be removed'
    assert 'CancelEvent()' not in text, 'PVP damage must not be canceled server-side; it desyncs the shooter'


def test_damage_uses_qb_ambulancejob_bridge_for_lethal_and_revive():
    manifest = read('fxmanifest.lua')
    bridge = read('bridge/death/qb.lua')
    damage = read('client/damage.lua')
    assert "bridge/death/qb.lua" in manifest
    assert "hospital:client:KillPlayer" in bridge
    assert "hospital:client:Revive" in bridge
    assert "NetworkResurrectLocalPlayer" in bridge
    assert "gameEventTriggered" in bridge, 'QB death bridge needs a guarded fallback when KillPlayer does not emit the native death event'
    assert "metadata.inlaststand" in bridge, 'fallback must not double-trigger if qb-ambulancejob already owns Laststand'
    assert "ApplyDamageToPed(ped, 1000" not in damage
    assert "LBVampire.DeathBridge.RequestDeath" in damage


def test_victim_side_entity_damage_remains_primary_pvp_router():
    text = read('client/damage.lua')
    assert "AddEventHandler('entityDamaged'" in text
    assert "RouteObservedDamage(" in text
    assert "SetPedSuffersCriticalHits(ped, false)" in text
    assert "lb-vampire:client:damage:interceptWeapon" not in text


def test_bloodbag_usable_starts_progress_session_not_direct_administer():
    text = read('server/items.lua')
    marker = "QBCore.Functions.CreateUseableItem("
    assert "lb-vampire:client:bloodbag:startUse" in text
    assert "lb-vampire:server:bloodbag:completeUse" in text
    assert "BloodBags.UseSessions" in text
    # Administer must happen in completion handler, not immediately inside usable callback.
    usable_idx = text.index(marker, text.index('BloodBags.UseSessions'))
    complete_idx = text.index("RegisterNetEvent('lb-vampire:server:bloodbag:completeUse'", usable_idx)
    usable_block = text[usable_idx:complete_idx]
    assert 'BloodBags.Administer(' not in usable_block


def test_bloodbag_prop_is_owned_by_lb_client_and_fx_tracks_prop():
    text = read('client/bloodbag.lua')
    assert 'CreateObject' in text
    assert 'AttachEntityToEntity' in text
    assert 'BloodBag.propEntity' in text
    assert 'GetOffsetFromEntityInWorldCoords' in text
    assert 'StartParticleFxNonLoopedAtCoord' in text
    assert 'StartParticleFxNonLoopedOnPedBone' not in text
    assert "QBCore.Functions.Progressbar" in text


def test_config_documents_no_server_cancel_and_prop_fx():
    text = read('config/config.lua')
    assert 'InterceptLethalWeaponHits' not in text
    assert 'VictimSideRouting' in text
    assert 'FollowProp' in text
