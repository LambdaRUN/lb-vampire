(() => {
    const root = document.getElementById('torporCard');
    const title = document.getElementById('torporTitle');
    const timer = document.getElementById('torporTimer');
    const description = document.getElementById('torporDescription');
    const action = document.getElementById('torporAction');
    const actionKey = document.getElementById('torporActionKey');
    const actionText = document.getElementById('torporActionText');

    if (!root || !title || !timer || !description || !action || !actionKey || !actionText) return;

    const formatTime = (seconds) => {
        const safe = Math.max(0, Math.ceil(Number(seconds) || 0));
        const minutes = Math.floor(safe / 60);
        const remainder = safe % 60;
        return `${String(minutes).padStart(2, '0')}:${String(remainder).padStart(2, '0')}`;
    };

    const hide = () => {
        root.classList.remove('is-visible', 'is-partial');
        root.setAttribute('aria-hidden', 'true');
    };

    const renderKinAction = (data) => {
        actionKey.textContent = 'H';
        actionText.textContent = data.kinAvailable === false
            ? 'Kan bağı bu Torpor’da kullanıldı'
            : 'Soydaşlarla iletişim kur';
        action.classList.toggle('is-used', data.kinAvailable === false);
    };

    const render = (data) => {
        const stage = Number(data.stage) || 0;
        if (stage <= 0) {
            hide();
            return;
        }

        const partial = stage === 2;
        root.classList.toggle('is-partial', partial);
        root.classList.add('is-visible');
        root.setAttribute('aria-hidden', 'false');

        if (!partial) {
            title.textContent = 'TORPOR';
            timer.textContent = formatTime(data.remaining);
            timer.hidden = false;
            description.textContent = `Kan rezervin tükendi. Bedenin çökerken en az ${Number(data.recoveryBlood) || 15} Blood gerekli.`;
        } else {
            title.textContent = 'KISMİ TORPOR';
            timer.textContent = '';
            timer.hidden = true;
            description.textContent = `Bedenin stabilize edildi fakat kan rezervin yetersiz. En az ${Number(data.recoveryBlood) || 15} Blood gerekli.`;
        }

        renderKinAction(data);
    };

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        if (data.action === 'torpor:update') render(data);
        if (data.action === 'torpor:hide') hide();
    });
})();
