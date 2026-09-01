(() => {
    const root = document.getElementById('abilityMenu');
    const stage = document.getElementById('abilitySigil');
    const nodesRoot = document.getElementById('abilityNodes');
    const veinsRoot = document.getElementById('abilityVeins');
    const wisp = document.getElementById('abilityWisp');
    const title = document.getElementById('abilityInspectorTitle');
    const description = document.getElementById('abilityInspectorDescription');
    const costValue = document.getElementById('abilityInspectorCost');
    const cooldownValue = document.getElementById('abilityInspectorCooldown');
    const statusValue = document.getElementById('abilityInspectorStatus');
    const coreBlood = document.getElementById('abilityCoreBlood');
    const coreMaxBlood = document.getElementById('abilityCoreMaxBlood');

    if (!root || !stage || !nodesRoot || !veinsRoot || !window.LBAbilityMenuCore) return;

    const core = window.LBAbilityMenuCore;
    const state = {
        open: false,
        entries: [],
        states: {},
        slots: [],
        hoveredIndex: null,
        hoveredId: null,
        layout: {
            deadzone: 70,
            cursorRadius: 260,
            minimumSlots: 6,
            maxSlots: 10
        },
        cooldownSyncedAt: Date.now(),
        nodeElements: [],
        veinElements: [],
        currentBlood: 0,
        maxBlood: 100
    };

    const icons = {
        beast: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M13 20 7 8l17 8 8-7 8 7 17-8-6 12 5 12-9 17-15 7-15-7-9-17 5-12Zm10 12 7 4 2-5 2 5 7-4-3 10-6 4-6-4-3-10Z" fill="currentColor"/></svg>`,
        blood: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M32 5C22 19 15 27 15 38a17 17 0 0 0 34 0C49 27 42 19 32 5Z" fill="none" stroke="currentColor" stroke-width="4"/><path d="M23 39c1 7 5 10 11 11" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/></svg>`,
        eye: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M5 32s10-16 27-16 27 16 27 16-10 16-27 16S5 32 5 32Z" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="32" cy="32" r="8" fill="currentColor"/></svg>`,
        shadow: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M15 50c2-19 7-35 17-41 10 6 15 22 17 41-7-5-12-7-17-7s-10 2-17 7Z" fill="none" stroke="currentColor" stroke-width="4"/><path d="M24 35c5 3 11 3 16 0" fill="none" stroke="currentColor" stroke-width="3"/></svg>`,
        siphon: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M17 11c2 12 7 18 15 21 8-3 13-9 15-21 5 15 1 28-15 42C16 39 12 26 17 11Z" fill="none" stroke="currentColor" stroke-width="4"/><path d="M32 24v20" stroke="currentColor" stroke-width="3" stroke-linecap="round"/></svg>`,
        frenzy: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="m11 49 15-35M26 52l12-39M41 51l12-31" stroke="currentColor" stroke-width="5" stroke-linecap="round"/></svg>`,
        sigil: `<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M32 7 43 23l-5 9 7 16-13 9-13-9 7-16-5-9L32 7Z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M32 18v27M24 30h16" stroke="currentColor" stroke-width="2"/></svg>`,
        lock: `<svg viewBox="0 0 64 64" aria-hidden="true"><rect x="15" y="27" width="34" height="27" rx="5" fill="none" stroke="currentColor" stroke-width="4"/><path d="M22 27v-7a10 10 0 0 1 20 0v7" fill="none" stroke="currentColor" stroke-width="4"/><circle cx="32" cy="40" r="3" fill="currentColor"/></svg>`
    };

    function post(name, payload = {}) {
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload)
        }).catch(() => {});
    }

    function formatSeconds(value) {
        const seconds = Math.max(Math.ceil(Number(value) || 0), 0);
        if (seconds >= 60) {
            const minutes = Math.floor(seconds / 60);
            const rest = seconds % 60;
            return `${minutes}:${String(rest).padStart(2, '0')}`;
        }
        return `${seconds}s`;
    }

    function getLiveStatus(id) {
        const original = state.states[id] || {};
        const status = { ...original };
        const elapsed = Math.max((Date.now() - state.cooldownSyncedAt) / 1000, 0);
        if ((Number(status.cooldownRemaining) || 0) > 0) {
            status.cooldownRemaining = Math.max(Number(status.cooldownRemaining) - elapsed, 0);
            if (status.cooldownRemaining <= 0 && String(status.reason || '').toLowerCase() === 'cooldown') {
                status.available = true;
                status.reason = '';
            }
        }
        return status;
    }

    function getStatusClass(status, locked) {
        if (locked || status.locked) return 'is-locked';
        if (status.active) return 'is-active';
        if ((Number(status.cooldownRemaining) || 0) > 0) return 'is-cooldown';
        if (String(status.reason || '').toLowerCase().includes('kan')) return 'is-insufficient';
        return '';
    }

    function getNodeStateText(status, locked) {
        if (locked || status.locked) return 'Mühürlü';
        if (status.active) return 'Aktif';
        if ((Number(status.cooldownRemaining) || 0) > 0) return formatSeconds(status.cooldownRemaining);
        if (status.available === false) return String(status.reason || 'Kullanılamaz');
        return 'Hazır';
    }

    function updateInspector(slot) {
        if (!slot || slot.locked || !slot.ability) {
            title.textContent = slot?.locked ? 'Mühürlü' : 'Blood Sigil';
            description.textContent = slot?.locked
                ? 'Bu mühür henüz bir vampire ability ile bağlanmamış.'
                : 'Mouse ile bir mühre yönel. Tuşu bıraktığında seçili ability etkinleşir.';
            costValue.textContent = '—';
            cooldownValue.textContent = '—';
            statusValue.textContent = slot?.locked ? 'Kilitli slot' : 'Merkeze dönerek iptal et';
            return;
        }

        const ability = slot.ability;
        const status = getLiveStatus(ability.id);
        title.textContent = ability.label || ability.id;
        description.textContent = ability.description || '';
        const cost = status.bloodCost ?? ability.bloodCost;
        costValue.textContent = Number.isFinite(Number(cost)) ? String(Number(cost)) : '—';
        cooldownValue.textContent = (Number(status.cooldownRemaining) || 0) > 0
            ? formatSeconds(status.cooldownRemaining)
            : 'Hazır';
        statusValue.textContent = getNodeStateText(status, false);
    }

    function makeNode(slot, radius, center) {
        const angle = slot.angle * (Math.PI / 180);
        const x = center + Math.cos(angle) * radius;
        const y = center + Math.sin(angle) * radius;
        const ability = slot.ability;
        const status = ability ? getLiveStatus(ability.id) : {};
        const effectiveLocked = slot.locked || ability?.hasProvider === false;

        const node = document.createElement('div');
        node.className = `ability-node ${getStatusClass(status, effectiveLocked)}`.trim();
        node.dataset.index = String(slot.index);
        node.style.left = `${x}px`;
        node.style.top = `${y}px`;

        const iconName = effectiveLocked ? 'lock' : String(ability?.icon || 'sigil');
        const cooldownDuration = Math.max(Number(status.cooldownDuration) || Number(status.cooldownRemaining) || 0, 0);
        const cooldownRemaining = Math.max(Number(status.cooldownRemaining) || 0, 0);
        const cooldownProgress = cooldownDuration > 0 ? core.clamp(cooldownRemaining / cooldownDuration, 0, 1) : 0;
        const dashOffset = 289 * (1 - cooldownProgress);

        node.innerHTML = `
            <div class="ability-node-disc"></div>
            <svg class="ability-node-ring" viewBox="0 0 100 100" aria-hidden="true">
                <circle class="track" cx="50" cy="50" r="46"></circle>
                <circle class="cooldown" cx="50" cy="50" r="46" style="stroke-dashoffset:${dashOffset}"></circle>
            </svg>
            <div class="ability-node-icon">${icons[iconName] || icons.sigil}</div>
            <div class="ability-node-label">${slot.locked ? 'Mühürlü' : ability.label}</div>
            <div class="ability-node-state">${getNodeStateText(status, effectiveLocked)}</div>
        `;
        return { node, x, y };
    }

    function render() {
        if (!state.open) return;

        const previousHoveredId = state.hoveredId;
        const previousHoveredIndex = state.hoveredIndex;

        nodesRoot.innerHTML = '';
        veinsRoot.innerHTML = '';
        state.nodeElements = [];
        state.veinElements = [];

        state.slots = core.buildSlots(
            state.entries,
            state.layout.minimumSlots,
            state.layout.maxSlots
        );

        const rect = stage.getBoundingClientRect();
        const size = Math.min(rect.width, rect.height);
        const center = size / 2;
        const radius = Math.min(size * 0.405, Number(state.layout.cursorRadius) || 260);

        state.slots.forEach((slot) => {
            const built = makeNode(slot, radius, center);
            nodesRoot.appendChild(built.node);
            state.nodeElements[slot.index] = built.node;

            const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
            line.setAttribute('x1', String(center));
            line.setAttribute('y1', String(center));
            line.setAttribute('x2', String(built.x));
            line.setAttribute('y2', String(built.y));
            line.classList.add('ability-vein');
            line.dataset.index = String(slot.index);
            veinsRoot.appendChild(line);
            state.veinElements[slot.index] = line;
        });

        let preserved = null;
        if (previousHoveredId) {
            preserved = state.slots.find((slot) => slot?.ability?.id === previousHoveredId) || null;
        } else if (Number.isInteger(previousHoveredIndex)) {
            preserved = state.slots[previousHoveredIndex] || null;
        }

        state.hoveredIndex = null;
        state.hoveredId = null;
        setHovered(preserved);
    }

    function setHovered(slot) {
        const index = slot ? slot.index : null;
        const id = slot?.ability?.id || null;
        if (state.hoveredIndex === index && state.hoveredId === id) return;

        state.hoveredIndex = index;
        state.hoveredId = id;

        state.nodeElements.forEach((node, nodeIndex) => {
            node?.classList.toggle('is-hovered', nodeIndex === index);
        });
        state.veinElements.forEach((line, lineIndex) => {
            line?.classList.toggle('is-hovered', lineIndex === index);
        });

        updateInspector(slot);
        post('ability:hover', { id });
    }

    function updatePointer(event) {
        if (!state.open) return;

        wisp.style.left = `${event.clientX}px`;
        wisp.style.top = `${event.clientY}px`;

        const rect = stage.getBoundingClientRect();
        const centerX = rect.left + (rect.width / 2);
        const centerY = rect.top + (rect.height / 2);
        const slot = core.selectSlotByPointer(
            event.clientX,
            event.clientY,
            centerX,
            centerY,
            Number(state.layout.deadzone) || 70,
            state.slots
        );

        setHovered(slot);
    }

    window.addEventListener('mousemove', updatePointer, { passive: true });

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        if (data.action === 'ability:open') {
            state.entries = Array.isArray(data.entries) ? data.entries : [];
            state.states = data.states && typeof data.states === 'object' ? data.states : {};
            state.layout = { ...state.layout, ...(data.layout || {}) };
            state.currentBlood = Number(data.currentBlood) || 0;
            state.maxBlood = Number(data.maxBlood) || 100;
            if (coreBlood) coreBlood.textContent = String(Math.round(state.currentBlood));
            if (coreMaxBlood) coreMaxBlood.textContent = String(Math.round(state.maxBlood));
            state.cooldownSyncedAt = Date.now();
            state.open = true;
            state.hoveredIndex = null;
            state.hoveredId = null;
            root.classList.add('is-open');
            root.setAttribute('aria-hidden', 'false');
            wisp.style.left = '50vw';
            wisp.style.top = '50vh';
            requestAnimationFrame(render);
            return;
        }

        if (data.action === 'ability:states') {
            state.states = data.states && typeof data.states === 'object' ? data.states : {};
            state.currentBlood = Number(data.currentBlood) || state.currentBlood;
            state.maxBlood = Number(data.maxBlood) || state.maxBlood;
            if (coreBlood) coreBlood.textContent = String(Math.round(state.currentBlood));
            if (coreMaxBlood) coreMaxBlood.textContent = String(Math.round(state.maxBlood));
            state.cooldownSyncedAt = Date.now();
            render();
            return;
        }

        if (data.action === 'ability:close') {
            state.open = false;
            state.hoveredIndex = null;
            state.hoveredId = null;
            root.classList.remove('is-open');
            root.setAttribute('aria-hidden', 'true');
        }
    });

    window.addEventListener('keydown', (event) => {
        if (!state.open) return;
        if (event.key === 'Escape') {
            event.preventDefault();
            post('ability:cancel');
        }
    });

    setInterval(() => {
        if (!state.open) return;
        for (const slot of state.slots) {
            if (!slot?.ability) continue;
            const status = getLiveStatus(slot.ability.id);
            if ((Number(status.cooldownRemaining) || 0) > 0) {
                render();
                break;
            }
        }
    }, 250);
})();
