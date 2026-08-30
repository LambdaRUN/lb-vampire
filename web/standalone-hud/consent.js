(() => {
    let root = null;
    let requesterElement = null;
    let timeElement = null;
    let progressElement = null;
    let acceptButton = null;
    let declineButton = null;

    let active = false;
    let deadline = 0;
    let totalDuration = 15000;
    let animationFrame = null;
    let submitting = false;


    /* =====================================================
       NUI
    ===================================================== */

    async function postNui(
        callbackName,
        body = {}
    ) {
        try {
            const response =
                await fetch(
                    `https://${GetParentResourceName()}/${callbackName}`,
                    {
                        method: 'POST',

                        headers: {
                            'Content-Type':
                                'application/json'
                        },

                        body:
                            JSON.stringify(
                                body
                            )
                    }
                );


            return await response.json();

        } catch (error) {

            console.error(
                `[LB-VAMPIRE Consent] ${callbackName} failed`,
                error
            );

            return null;
        }
    }


    /* =====================================================
       BUILD
    ===================================================== */

    function buildConsentUI() {
        if (
            document.getElementById(
                'feedingConsent'
            )
        ) {
            return;
        }


        root =
            document.createElement(
                'div'
            );


        root.id =
            'feedingConsent';


        root.className =
            'feeding-consent hidden';


        root.innerHTML = `
            <div class="feeding-consent-card">

                <div class="feeding-consent-accent"></div>

                <div class="feeding-consent-header">
                    BESLENME İSTEĞİ
                </div>

                <div class="feeding-consent-title">
                    <span id="feedingConsentRequester">
                        Bir vampir
                    </span>
                    senden beslenmek istiyor.
                </div>

                <div class="feeding-consent-description">
                    Kabul edersen beslenme başlayacaktır.
                    İstediğin zaman işlem kesilebilir.
                </div>

                <div class="feeding-consent-timer">
                    <div
                        id="feedingConsentProgress"
                        class="feeding-consent-progress"
                    ></div>
                </div>

                <div
                    id="feedingConsentTime"
                    class="feeding-consent-time"
                >
                    15 sn
                </div>

                <div class="feeding-consent-actions">

                    <button
                        id="feedingConsentDecline"
                        class="feeding-consent-button decline"
                        type="button"
                    >
                        Reddet
                    </button>

                    <button
                        id="feedingConsentAccept"
                        class="feeding-consent-button accept"
                        type="button"
                    >
                        Kabul Et
                    </button>

                </div>

            </div>
        `;


        document.body.appendChild(
            root
        );


        requesterElement =
            document.getElementById(
                'feedingConsentRequester'
            );


        timeElement =
            document.getElementById(
                'feedingConsentTime'
            );


        progressElement =
            document.getElementById(
                'feedingConsentProgress'
            );


        acceptButton =
            document.getElementById(
                'feedingConsentAccept'
            );


        declineButton =
            document.getElementById(
                'feedingConsentDecline'
            );


        acceptButton.addEventListener(
            'click',
            accept
        );


        declineButton.addEventListener(
            'click',
            decline
        );
    }


    /* =====================================================
       BUTTON STATE
    ===================================================== */

    function setSubmitting(
        value
    ) {
        submitting =
            value === true;


        if (acceptButton) {
            acceptButton.disabled =
                submitting;
        }


        if (declineButton) {
            declineButton.disabled =
                submitting;
        }
    }


    /* =====================================================
       CLOSE
    ===================================================== */

    function closeConsent() {
        active =
            false;


        submitting =
            false;


        if (animationFrame) {
            cancelAnimationFrame(
                animationFrame
            );

            animationFrame =
                null;
        }


        if (root) {
            root.classList.add(
                'hidden'
            );
        }
    }


    /* =====================================================
       TIMER
    ===================================================== */

    function updateTimer() {
        if (!active) {
            return;
        }


        const remaining =
            Math.max(
                0,
                deadline -
                    performance.now()
            );


        const percentage =
            Math.max(
                0,
                Math.min(
                    1,
                    remaining /
                        totalDuration
                )
            );


        if (progressElement) {
            progressElement.style.width =
                `${percentage * 100}%`;
        }


        if (timeElement) {

            timeElement.textContent =
                `${Math.ceil(
                    remaining / 1000
                )} sn`;
        }


        if (remaining <= 0) {

            active =
                false;


            closeConsent();


            postNui(
                'feedingConsentTimeout'
            );


            return;
        }


        animationFrame =
            requestAnimationFrame(
                updateTimer
            );
    }


    /* =====================================================
       OPEN
    ===================================================== */

    function openConsent(
        data
    ) {
        buildConsentUI();


        totalDuration =
            Math.max(
                Number(
                    data.timeout
                ) || 15000,
                1000
            );


        deadline =
            performance.now()
            +
            totalDuration;


        requesterElement.textContent =
            String(
                data.requesterName ||
                'Bir vampir'
            );


        setSubmitting(
            false
        );


        active =
            true;


        root.classList.remove(
            'hidden'
        );


        if (animationFrame) {
            cancelAnimationFrame(
                animationFrame
            );
        }


        animationFrame =
            requestAnimationFrame(
                updateTimer
            );
    }


    /* =====================================================
       ACCEPT
    ===================================================== */

    async function accept() {
        if (
            !active ||
            submitting
        ) {
            return;
        }


        setSubmitting(
            true
        );


        const result =
            await postNui(
                'feedingConsentAccept'
            );


        if (
            !result ||
            result.success !== true
        ) {

            setSubmitting(
                false
            );

            return;
        }


        closeConsent();
    }


    /* =====================================================
       DECLINE
    ===================================================== */

    async function decline() {
        if (
            !active ||
            submitting
        ) {
            return;
        }


        setSubmitting(
            true
        );


        const result =
            await postNui(
                'feedingConsentDecline'
            );


        if (
            !result ||
            result.success !== true
        ) {

            setSubmitting(
                false
            );

            return;
        }


        closeConsent();
    }


    /* =====================================================
       ESC
    ===================================================== */

    document.addEventListener(
        'keydown',
        (event) => {

            if (
                !active ||
                submitting
            ) {
                return;
            }


            if (
                event.key ===
                'Escape'
            ) {

                event.preventDefault();

                decline();
            }
        }
    );


    /* =====================================================
       NUI MESSAGES
    ===================================================== */

    window.addEventListener(
        'message',
        (event) => {

            const data =
                event.data || {};


            if (
                data.action ===
                'feeding-consent:open'
            ) {

                openConsent(
                    data
                );

                return;
            }


            if (
                data.action ===
                'feeding-consent:close'
            ) {

                closeConsent();
            }
        }
    );


    /* =====================================================
       READY
    ===================================================== */

    window.addEventListener(
        'DOMContentLoaded',
        () => {

            buildConsentUI();

            closeConsent();
        }
    );
})();