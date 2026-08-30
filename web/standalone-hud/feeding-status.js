(() => {
    let root = null;
    let targetElement = null;
    let stateElement = null;
    let progressElement = null;
    let stopKeyElement = null;

    let active = false;


    /* =====================================================
       NUI POST
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
                `[LB-VAMPIRE Feeding Status] ${callbackName} failed`,
                error
            );


            return null;
        }
    }


    /* =====================================================
       BUILD
    ===================================================== */

    function buildUI() {
        if (
            document.getElementById(
                'feedingStatus'
            )
        ) {

            root =
                document.getElementById(
                    'feedingStatus'
                );


            targetElement =
                document.getElementById(
                    'feedingStatusTarget'
                );


            stateElement =
                document.getElementById(
                    'feedingStatusState'
                );


            progressElement =
                document.getElementById(
                    'feedingStatusProgress'
                );


            stopKeyElement =
                document.getElementById(
                    'feedingStatusStopKey'
                );


            return;
        }


        root =
            document.createElement(
                'div'
            );


        root.id =
            'feedingStatus';


        root.className =
            'feeding-status hidden';


        root.innerHTML = `
            <div class="feeding-status-card">

                <div class="feeding-status-top">

                    <div>
                        <div class="feeding-status-label">
                            BESLENME
                        </div>

                        <div
                            id="feedingStatusTarget"
                            class="feeding-status-target"
                        >
                            Hedef
                        </div>
                    </div>

                    <div
                        id="feedingStatusState"
                        class="feeding-status-state stable"
                    >
                        DENGELİ
                    </div>

                </div>

                <div class="feeding-status-track">
                    <div
                        id="feedingStatusProgress"
                        class="feeding-status-progress stable"
                    ></div>
                </div>

                <div class="feeding-status-bottom">

                    <span>
                        Hedefin kan durumunu takip et.
                    </span>

                    <span class="feeding-status-stop">

                        <kbd
                            id="feedingStatusStopKey"
                        >
                            X
                        </kbd>

                        BESLENMEYİ BIRAK

                    </span>

                </div>

            </div>
        `;


        document.body.appendChild(
            root
        );


        targetElement =
            document.getElementById(
                'feedingStatusTarget'
            );


        stateElement =
            document.getElementById(
                'feedingStatusState'
            );


        progressElement =
            document.getElementById(
                'feedingStatusProgress'
            );


        stopKeyElement =
            document.getElementById(
                'feedingStatusStopKey'
            );
    }


    /* =====================================================
       CLOSE
    ===================================================== */

    function closeUI() {
        active =
            false;


        if (root) {

            root.classList.add(
                'hidden'
            );
        }
    }


    /* =====================================================
       OPEN
    ===================================================== */

    function openUI(
        data
    ) {
        buildUI();


        if (
            !root ||
            !targetElement ||
            !stateElement ||
            !progressElement ||
            !stopKeyElement
        ) {

            console.error(
                '[LB-VAMPIRE Feeding Status] Required DOM nodes missing.'
            );


            return;
        }


        active =
            true;


        targetElement.textContent =
            String(
                data.partnerName
                || 'Hedef'
            );


        stopKeyElement.textContent =
            String(
                data.stopKey
                || 'X'
            );


        root.classList.remove(
            'hidden'
        );
    }


    /* =====================================================
       LEVEL
    ===================================================== */

    function getLevelText(
        level
    ) {
        switch (
            level
        ) {

            case 'LOW':
                return 'KAN KAYBI';

            case 'CRITICAL':
                return 'KRİTİK';

            case 'SEVERE':
                return 'AĞIR';

            default:
                return 'DENGELİ';
        }
    }


    /* =====================================================
       UPDATE
    ===================================================== */

    function updateUI(
        data
    ) {
        if (!active) {
            return;
        }


        const blood =
            Number(
                data.blood
            );


        const maxBlood =
            Number(
                data.maxBlood
            ) || 100;


        const safeBlood =
            Number.isFinite(
                blood
            )
                ? blood
                : maxBlood;


        const percentage =
            Math.max(
                0,
                Math.min(
                    1,
                    safeBlood /
                        maxBlood
                )
            );


        const level =
            String(
                data.level
                || 'STABLE'
            ).toUpperCase();


        const classes = [
            'stable',
            'low',
            'critical',
            'severe'
        ];


        for (
            const className
            of classes
        ) {

            stateElement.classList.remove(
                className
            );


            progressElement.classList.remove(
                className
            );
        }


        let cssClass =
            'stable';


        if (
            level === 'LOW'
        ) {

            cssClass =
                'low';

        } else if (
            level === 'CRITICAL'
        ) {

            cssClass =
                'critical';

        } else if (
            level === 'SEVERE'
        ) {

            cssClass =
                'severe';
        }


        stateElement.classList.add(
            cssClass
        );


        progressElement.classList.add(
            cssClass
        );


        stateElement.textContent =
            getLevelText(
                level
            );


        progressElement.style.width =
            `${percentage * 100}%`;
    }


    /* =====================================================
       MESSAGES
    ===================================================== */

    window.addEventListener(
        'message',
        (event) => {

            const data =
                event.data
                || {};


            if (
                data.action ===
                'feeding-status:open'
            ) {

                openUI(
                    data
                );


                return;
            }


            if (
                data.action ===
                'feeding-status:update'
            ) {

                updateUI(
                    data
                );


                return;
            }


            if (
                data.action ===
                'feeding-status:close'
            ) {

                closeUI();
            }
        }
    );


    /* =====================================================
       READY
    ===================================================== */

    window.addEventListener(
        'DOMContentLoaded',
        async () => {

            buildUI();


            closeUI();


            await postNui(
                'feedingStatusReady'
            );
        }
    );
})();