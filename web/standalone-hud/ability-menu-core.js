(function (root, factory) {
    const api = factory();
    if (typeof module !== 'undefined' && module.exports) {
        module.exports = api;
    }
    if (root) {
        root.LBAbilityMenuCore = api;
    }
})(typeof window !== 'undefined' ? window : globalThis, function () {
    function clamp(value, minimum, maximum) {
        return Math.min(Math.max(Number(value) || 0, minimum), maximum);
    }

    function normalizeAngle(angle) {
        let normalized = Number(angle) || 0;
        while (normalized > 180) normalized -= 360;
        while (normalized <= -180) normalized += 360;
        return normalized;
    }

    function buildSlots(abilities, minimumSlots, maximumSlots) {
        const source = Array.isArray(abilities) ? [...abilities] : [];
        source.sort((a, b) => {
            const orderA = Number(a?.order) || 999;
            const orderB = Number(b?.order) || 999;
            if (orderA === orderB) return String(a?.id || '').localeCompare(String(b?.id || ''));
            return orderA - orderB;
        });

        const minSlots = clamp(Math.floor(Number(minimumSlots) || 6), 1, 12);
        const maxSlots = clamp(Math.floor(Number(maximumSlots) || 10), minSlots, 12);
        const slotCount = clamp(Math.max(source.length, minSlots), minSlots, maxSlots);
        const visible = source.slice(0, slotCount);

        return Array.from({ length: slotCount }, (_, index) => ({
            index,
            angle: -90 + ((360 / slotCount) * index),
            ability: visible[index] || null,
            locked: !visible[index]
        }));
    }

    function selectSlotByPointer(pointerX, pointerY, centerX, centerY, deadzone, slots) {
        const dx = Number(pointerX) - Number(centerX);
        const dy = Number(pointerY) - Number(centerY);
        const distance = Math.sqrt((dx * dx) + (dy * dy));

        if (!Number.isFinite(distance) || distance < (Number(deadzone) || 0)) {
            return null;
        }

        const pointerAngle = Math.atan2(dy, dx) * (180 / Math.PI);
        let best = null;
        let bestDistance = Infinity;

        for (const slot of Array.isArray(slots) ? slots : []) {
            const delta = Math.abs(normalizeAngle(pointerAngle - Number(slot.angle || 0)));
            if (delta < bestDistance) {
                bestDistance = delta;
                best = slot;
            }
        }

        return best;
    }

    return {
        clamp,
        normalizeAngle,
        buildSlots,
        selectSlotByPointer
    };
});
