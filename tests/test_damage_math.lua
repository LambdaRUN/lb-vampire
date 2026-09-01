LBVampire = {}

dofile('shared/damage_math.lua')

local function approx(actual, expected, epsilon, label)
    epsilon = epsilon or 0.001
    if math.abs(actual - expected) > epsilon then
        error(('%s expected %.3f got %.3f'):format(label or 'value', expected, actual))
    end
end

local function assertEq(actual, expected, label)
    if actual ~= expected then
        error(('%s expected %s got %s'):format(label or 'value', tostring(expected), tostring(actual)))
    end
end

local a = LBVampire.DamageMath.Calculate(95, 0, 80, 100, 1.0)
approx(a.finalDamage, 95, nil, 'finalDamage')
approx(a.bloodDamage, 80, nil, 'bloodDamage')
approx(a.healthDamage, 15, nil, 'healthDamage')
approx(a.remainingBlood, 0, nil, 'remainingBlood')
approx(a.remainingHealth, 85, nil, 'remainingHealth')
assertEq(a.bloodDepleted, true, 'bloodDepleted')
assertEq(a.lethal, false, 'lethal')

local b = LBVampire.DamageMath.Calculate(30, 10, 80, 100, 0.25)
approx(b.finalDamage, 7.5, nil, 'resisted final')
approx(b.armorDamage, 7.5, nil, 'armor first')
approx(b.remainingArmor, 2.5, nil, 'remaining armor')
approx(b.remainingBlood, 80, nil, 'blood untouched')

local c = LBVampire.DamageMath.Calculate(30, 0, 80, 100, 3.0)
approx(c.finalDamage, 90, nil, 'deadblood final')
approx(c.bloodDamage, 80, nil, 'deadblood blood')
approx(c.healthDamage, 10, nil, 'deadblood overflow')
approx(c.remainingHealth, 90, nil, 'deadblood hp')

local d = LBVampire.DamageMath.Calculate(90, 0, 20, 50, 1.0)
assertEq(d.lethal, true, 'lethal overflow')
approx(d.remainingHealth, 0, nil, 'lethal health')

local e = LBVampire.DamageMath.Calculate(-10, -5, -2, -1, -3)
approx(e.finalDamage, 0, nil, 'clamped damage')
approx(e.remainingArmor, 0, nil, 'clamped armor')
approx(e.remainingBlood, 0, nil, 'clamped blood')
approx(e.remainingHealth, 0, nil, 'clamped health')

print('damage_math: 5 cases passed')
