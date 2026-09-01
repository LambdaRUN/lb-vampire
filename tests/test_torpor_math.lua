LBVampire = {}

dofile('shared/torpor_math.lua')

local function approx(actual, expected, epsilon, label)
    epsilon = epsilon or 0.001
    if math.abs(actual - expected) > epsilon then
        error(('%s expected %.3f got %.3f'):format(label or 'value', expected, actual))
    end
end

approx(LBVampire.TorporMath.GetDrainRate(300, 100), 1 / 3, nil, 'five minute drain rate')
approx(LBVampire.TorporMath.GetSecondsRemaining(100, 300, 100), 300, nil, '100 hp five minutes')
approx(LBVampire.TorporMath.GetSecondsRemaining(80, 300, 100), 240, nil, '80 hp four minutes')
approx(LBVampire.TorporMath.GetSecondsRemaining(50, 300, 100), 150, nil, '50 hp two and a half minutes')
approx(LBVampire.TorporMath.GetSecondsRemaining(100, 240, 100), 240, nil, 'config change to four minutes')
approx(LBVampire.TorporMath.GetDrainIntervalMs(300, 100), 3000, 1, 'one hp every three seconds')
approx(LBVampire.TorporMath.GetScheduledSecondsRemaining(100, 300, 100, 2000), 299, 0.01, 'smooth countdown between drain ticks')

print('torpor_math: 7 cases passed')
