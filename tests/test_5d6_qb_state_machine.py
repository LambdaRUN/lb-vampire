from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def test_partial_torpor_only_comes_from_real_qb_revive_event():
    torpor = read('client/torpor.lua')
    bridge = read('bridge/death/qb.lua')
    assert "lb-vampire:client:deathBridge:revived" in torpor
    assert "revivedFromTorpor" in torpor
    assert "Torpor.wasQBDead" not in torpor
    assert "hospital:client:Revive" in bridge


def test_qb_death_bridge_has_delayed_laststand_fallback():
    bridge = read('bridge/death/qb.lua')
    assert "hospital:client:KillPlayer" in bridge
    assert "gameEventTriggered" in bridge
    assert "CEventNetworkEntityDamage" in bridge
    assert "inlaststand" in bridge.lower()
    assert "IsEntityDead" in bridge


def test_revive_watchdog_repairs_dead_or_ragdoll_state():
    bridge = read('bridge/death/qb.lua')
    assert "IsPedDeadOrDying" in bridge
    assert "IsPedRagdoll" in bridge
    assert "NetworkResurrectLocalPlayer" in bridge
    assert "ClearPedTasksImmediately" in bridge
