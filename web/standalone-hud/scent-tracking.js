/* =========================================================
   BEAST CALL - SCENT TRACKING NUI
========================================================= */

const scentTracking =
    document.getElementById(
        'scentTracking'
    );

const scentPulse =
    document.getElementById(
        'scentPulse'
    );

const scentStrength =
    document.getElementById(
        'scentStrength'
    );

const scentDirection =
    document.getElementById(
        'scentDirection'
    );

let scentPulseTimer = null;

function normalizeScentStrength(value) {
    const key =
        String(value || 'FAINT')
            .toUpperCase();

    if (
        key === 'FAINT' ||
        key === 'DETECTED' ||
        key === 'STRONG' ||
        key === 'NEARBY'
    ) {
        return key;
    }

    return 'FAINT';
}

function showScentTracking() {
    if (!scentTracking) return;

    scentTracking.classList.add(
        'active'
    );

    scentTracking.setAttribute(
        'aria-hidden',
        'false'
    );
}

function hideScentTracking() {
    if (!scentTracking) return;

    if (scentPulseTimer) {
        clearTimeout(
            scentPulseTimer
        );

        scentPulseTimer = null;
    }

    if (scentPulse) {
        scentPulse.classList.remove(
            'pulse-visible'
        );
    }

    scentTracking.classList.remove(
        'active'
    );

    scentTracking.setAttribute(
        'aria-hidden',
        'true'
    );
}

function pulseScent(data) {
    if (
        !scentTracking ||
        !scentPulse ||
        !scentStrength ||
        !scentDirection
    ) {
        return;
    }

    const strengthKey =
        normalizeScentStrength(
            data.strength
        );

    scentTracking.dataset.strength =
        strengthKey;

    scentStrength.textContent =
        String(
            data.label ||
            'KOKU'
        );

    scentDirection.textContent =
        String(
            data.direction ||
            'ÖNÜNDE'
        );

    showScentTracking();

    if (scentPulseTimer) {
        clearTimeout(
            scentPulseTimer
        );
    }

    /*
        CSS pulse animasyonunu her server/client pulse'unda
        gerçekten yeniden başlatmak için class'ı bir frame kaldırıyoruz.
    */
    scentPulse.classList.remove(
        'pulse-visible'
    );

    void scentPulse.offsetWidth;

    scentPulse.classList.add(
        'pulse-visible'
    );

    const duration =
        Math.max(
            Number(data.duration) || 450,
            250
        );

    scentPulseTimer =
        setTimeout(
            () => {
                scentPulse.classList.remove(
                    'pulse-visible'
                );

                scentPulseTimer = null;
            },
            duration + 260
        );
}

window.addEventListener(
    'message',
    (event) => {
        const data =
            event.data || {};

        if (
            data.action ===
            'scent:tracking'
        ) {
            showScentTracking();
            return;
        }

        if (
            data.action ===
            'scent:pulse'
        ) {
            pulseScent(data);
            return;
        }

        if (
            data.action ===
            'scent:hide'
        ) {
            hideScentTracking();
        }
    }
);

window.addEventListener(
    'DOMContentLoaded',
    () => {
        hideScentTracking();
    }
);
