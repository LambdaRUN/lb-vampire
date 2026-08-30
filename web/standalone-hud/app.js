/* =========================================================
   DOM ELEMENTS
========================================================= */

const bloodHud =
    document.getElementById(
        'bloodHud'
    );


const sunHud =
    document.getElementById(
        'sunHud'
    );


const humanBloodHud =
    document.getElementById(
        'humanBloodHud'
    );


const bloodValue =
    document.getElementById(
        'bloodValue'
    );


const bloodProgress =
    document.getElementById(
        'bloodProgress'
    );


const humanBloodProgress =
    document.getElementById(
        'humanBloodProgress'
    );


const editorPanel =
    document.getElementById(
        'editorPanel'
    );


const elementSelector =
    document.getElementById(
        'elementSelector'
    );


const scaleRange =
    document.getElementById(
        'scaleRange'
    );


const opacityRange =
    document.getElementById(
        'opacityRange'
    );


const scaleValue =
    document.getElementById(
        'scaleValue'
    );


const opacityValue =
    document.getElementById(
        'opacityValue'
    );


const resetButton =
    document.getElementById(
        'resetButton'
    );


const cancelButton =
    document.getElementById(
        'cancelButton'
    );


const saveButton =
    document.getElementById(
        'saveButton'
    );


const closeEditorButton =
    document.getElementById(
        'closeEditorButton'
    );


/* =========================================================
   RING VALUES
========================================================= */

/*
    Vampire Blood ring radius = 30
*/
const bloodCircumference =
    2 * Math.PI * 30;


if (bloodProgress) {

    bloodProgress.style
        .strokeDasharray =
        bloodCircumference
            .toString();
}


/*
    HumanBlood ring radius = 44
*/
const humanBloodCircumference =
    2 * Math.PI * 44;


if (humanBloodProgress) {

    humanBloodProgress.style
        .strokeDasharray =
        humanBloodCircumference
            .toString();


    /*
        İlk render sırasında full görünüm.
    */
    humanBloodProgress.style
        .strokeDashoffset =
        '0';
}


/* =========================================================
   EDITOR STATE
========================================================= */

let editorActive =
    false;


let workingLayout =
    {};


let defaultLayout =
    {};


let availableElements =
    [];


let selectedElementId =
    null;


let editorLimits = {

    minScale:
        0.65,

    maxScale:
        1.50,

    minOpacity:
        0.35,

    maxOpacity:
        1.00
};


let dragState =
    null;


/* =========================================================
   UTILS
========================================================= */

function clamp(
    value,
    minimum,
    maximum
) {
    return Math.min(

        Math.max(
            value,
            minimum
        ),

        maximum
    );
}


function clone(
    value
) {
    return JSON.parse(
        JSON.stringify(
            value
        )
    );
}


function getElementNode(
    elementId
) {
    return document.querySelector(
        `[data-hud-element="${elementId}"]`
    );
}


/*
    Lua tarafı:

    [
        "Blood",
        "Sun"
    ]

    veya:

    [
        "HumanBlood"
    ]

    gönderebilir.

    Eski object formatını da destekliyoruz.
*/
function normalizeAvailableElements(
    elements
) {
    if (
        !Array.isArray(
            elements
        )
    ) {
        return [];
    }


    return elements
        .map(
            (element) => {

                if (
                    typeof element ===
                    'string'
                ) {

                    let label =
                        element;


                    if (
                        element ===
                        'HumanBlood'
                    ) {

                        label =
                            'Human Blood';
                    }


                    return {

                        id:
                            element,

                        label:
                            label
                    };
                }


                if (
                    element &&
                    typeof element ===
                        'object' &&
                    element.id
                ) {

                    return {

                        id:
                            String(
                                element.id
                            ),

                        label:
                            String(
                                element.label ||
                                element.id
                            )
                    };
                }


                return null;
            }
        )
        .filter(
            Boolean
        );
}


/* =========================================================
   BLOOD HUD VISIBILITY
========================================================= */

function hideBloodHud() {

    if (!bloodHud) {
        return;
    }


    bloodHud.classList.add(
        'hidden'
    );


    bloodHud.classList.remove(
        'low',
        'critical'
    );
}


function showBloodHud() {

    if (!bloodHud) {
        return;
    }


    bloodHud.classList.remove(
        'hidden'
    );
}


/* =========================================================
   SUN HUD VISIBILITY
========================================================= */

function hideSunHud() {

    if (!sunHud) {
        return;
    }


    sunHud.classList.add(
        'hidden'
    );


    sunHud.classList.remove(
        'sun-safe',
        'sun-reduced',
        'sun-direct'
    );
}


function showSunHud() {

    if (!sunHud) {
        return;
    }


    sunHud.classList.remove(
        'hidden'
    );
}


/* =========================================================
   HUMAN BLOOD HUD VISIBILITY
========================================================= */

function hideHumanBloodHud() {

    if (!humanBloodHud) {
        return;
    }


    humanBloodHud.classList.add(
        'hidden'
    );


    humanBloodHud.classList.remove(
        'human-loss',
        'human-low',
        'human-critical',
        'human-severe'
    );
}


function showHumanBloodHud() {

    if (!humanBloodHud) {
        return;
    }


    humanBloodHud.classList.remove(
        'hidden'
    );
}


/* =========================================================
   GENERIC ELEMENT LAYOUT
========================================================= */

function applyElementLayout(
    elementId,
    layout
) {

    const element =
        getElementNode(
            elementId
        );


    if (
        !element ||
        !layout
    ) {

        return;
    }


    const left =
        Number(
            layout.left
        ) || 0;


    const bottom =
        Number(
            layout.bottom
        ) || 0;


    const scale =
        Number(
            layout.scale
        ) || 1;


    const opacity =
        Number(
            layout.opacity
        ) || 1;


    element.style.left =
        `${left}vw`;


    element.style.bottom =
        `${bottom}vh`;


    element.style.setProperty(
        '--hud-scale',
        scale.toString()
    );


    element.style.setProperty(
        '--hud-opacity',
        opacity.toString()
    );
}


function applyWorkingLayout() {

    for (
        const [
            elementId,
            layout
        ]
        of Object.entries(
            workingLayout
        )
    ) {

        applyElementLayout(
            elementId,
            layout
        );
    }
}


/* =========================================================
   VAMPIRE BLOOD UPDATE
========================================================= */

function updateBlood(
    data
) {

    if (
        !bloodHud ||
        !bloodValue ||
        !bloodProgress
    ) {

        return;
    }


    const blood =
        Number(
            data.blood
        ) || 0;


    const maxBlood =
        Number(
            data.maxBlood
        ) || 100;


    const lowThreshold =
        Number(
            data.lowThreshold
        ) || 25;


    const criticalThreshold =
        Number(
            data.criticalThreshold
        ) || 10;


    const percentage =
        clamp(

            blood /
                maxBlood,

            0,
            1
        );


    const offset =
        bloodCircumference -
        (
            percentage *
            bloodCircumference
        );


    bloodProgress.style
        .strokeDashoffset =
        offset.toString();


    bloodValue.textContent =
        Math.round(
            blood
        ).toString();


    bloodHud.classList.remove(
        'low',
        'critical'
    );


    if (
        blood > 0 &&
        blood <=
            criticalThreshold
    ) {

        bloodHud.classList.add(
            'critical'
        );


    } else if (
        blood >
            criticalThreshold &&
        blood <=
            lowThreshold
    ) {

        bloodHud.classList.add(
            'low'
        );
    }


    /*
        Editor açıkken Lua tarafından gelen
        layout sürüklediğimiz konumu ezmesin.
    */
    if (
        !editorActive &&
        data.layout
    ) {

        applyElementLayout(
            'Blood',
            data.layout
        );
    }


    showBloodHud();
}


/* =========================================================
   SUN UPDATE
========================================================= */

function updateSun(
    data
) {

    if (!sunHud) {
        return;
    }


    const state =
        String(
            data?.state ||
            'SAFE'
        ).toUpperCase();


    sunHud.classList.remove(
        'sun-safe',
        'sun-reduced',
        'sun-direct'
    );


    if (
        state ===
        'DIRECT'
    ) {

        sunHud.classList.add(
            'sun-direct'
        );


    } else if (
        state ===
        'REDUCED'
    ) {

        sunHud.classList.add(
            'sun-reduced'
        );


    } else {

        sunHud.classList.add(
            'sun-safe'
        );
    }


    if (
        !editorActive &&
        data?.layout
    ) {

        applyElementLayout(
            'Sun',
            data.layout
        );
    }


    showSunHud();
}


/* =========================================================
   HUMAN BLOOD UPDATE
========================================================= */

function updateHumanBlood(
    data
) {

    if (
        !humanBloodHud ||
        !humanBloodProgress
    ) {

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


    const lowThreshold =
        Number(
            data.lowThreshold
        ) || 70;


    const criticalThreshold =
        Number(
            data.criticalThreshold
        ) || 40;


    const severeThreshold =
        Number(
            data.severeThreshold
        ) || 20;


    const percentage =
        clamp(

            safeBlood /
                maxBlood,

            0,
            1
        );


    /*
        Ring küçüldükçe insan kan kaybediyor.
    */
    const offset =
        humanBloodCircumference -
        (
            percentage *
            humanBloodCircumference
        );


    humanBloodProgress.style
        .strokeDashoffset =
        offset.toString();


    humanBloodHud.classList.remove(
        'human-loss',
        'human-low',
        'human-critical',
        'human-severe'
    );


    if (
        safeBlood <=
        severeThreshold
    ) {

        humanBloodHud.classList.add(
            'human-severe'
        );


    } else if (
        safeBlood <=
        criticalThreshold
    ) {

        humanBloodHud.classList.add(
            'human-critical'
        );


    } else if (
        safeBlood <=
        lowThreshold
    ) {

        humanBloodHud.classList.add(
            'human-low'
        );


    } else {

        humanBloodHud.classList.add(
            'human-loss'
        );
    }


    /*
        Editor açıkken Lua'nın layout'u
        sürüklediğimiz değeri ezmemeli.
    */
    if (
        !editorActive &&
        data.layout
    ) {

        applyElementLayout(
            'HumanBlood',
            data.layout
        );
    }


    showHumanBloodHud();
}


/* =========================================================
   EDITOR CONTROL VALUES
========================================================= */

function updateControlValues() {

    if (
        !selectedElementId ||
        !workingLayout[
            selectedElementId
        ]
    ) {

        return;
    }


    const layout =
        workingLayout[
            selectedElementId
        ];


    scaleRange.value =
        layout.scale;


    opacityRange.value =
        layout.opacity;


    scaleValue.textContent =
        `${Math.round(
            layout.scale *
            100
        )}%`;


    opacityValue.textContent =
        `${Math.round(
            layout.opacity *
            100
        )}%`;
}


/* =========================================================
   SELECT ELEMENT
========================================================= */

function selectElement(
    elementId
) {

    if (
        !workingLayout[
            elementId
        ]
    ) {

        return;
    }


    selectedElementId =
        elementId;


    document
        .querySelectorAll(
            '.hud-element'
        )
        .forEach(
            (element) => {

                element.classList.remove(
                    'selected'
                );
            }
        );


    const selectedNode =
        getElementNode(
            elementId
        );


    if (selectedNode) {

        selectedNode.classList.add(
            'selected'
        );
    }


    document
        .querySelectorAll(
            '.element-button'
        )
        .forEach(
            (button) => {

                button.classList.toggle(
                    'active',

                    button.dataset
                        .elementId ===
                        elementId
                );
            }
        );


    updateControlValues();
}


/* =========================================================
   ELEMENT SELECTOR
========================================================= */

function buildElementSelector() {

    if (!elementSelector) {
        return;
    }


    elementSelector.innerHTML =
        '';


    for (
        const element
        of availableElements
    ) {

        const button =
            document.createElement(
                'button'
            );


        button.type =
            'button';


        button.className =
            'element-button';


        button.dataset.elementId =
            element.id;


        button.textContent =
            element.label;


        button.addEventListener(
            'click',
            () => {

                selectElement(
                    element.id
                );
            }
        );


        elementSelector.appendChild(
            button
        );
    }
}


/* =========================================================
   OPEN EDITOR
========================================================= */

function openEditor(
    data
) {

    editorActive =
        true;


    workingLayout =
        clone(
            data.layout ||
            {}
        );


    defaultLayout =
        clone(
            data.defaults ||
            {}
        );


    availableElements =
        normalizeAvailableElements(
            data.elements
        );


    if (data.limits) {

        editorLimits = {

            ...editorLimits,
            ...data.limits
        };
    }


    if (scaleRange) {

        scaleRange.min =
            editorLimits.minScale;

        scaleRange.max =
            editorLimits.maxScale;
    }


    if (opacityRange) {

        opacityRange.min =
            editorLimits.minOpacity;

        opacityRange.max =
            editorLimits.maxOpacity;
    }


    document.body.classList.add(
        'editor-active'
    );


    if (editorPanel) {

        editorPanel.classList.remove(
            'hidden'
        );
    }


    applyWorkingLayout();


    /*
        Yalnızca bu karakter için editlenebilir
        HUD elementlerini göster.
    */

    hideBloodHud();
    hideSunHud();
    hideHumanBloodHud();


    for (
        const element
        of availableElements
    ) {

        if (
            element.id === 'Blood'
        ) {

            showBloodHud();

        } else if (
            element.id === 'Sun'
        ) {

            showSunHud();

        } else if (
            element.id === 'HumanBlood'
        ) {

            showHumanBloodHud();
        }
    }


    buildElementSelector();


    if (
        availableElements.length >
        0
    ) {

        selectElement(
            availableElements[0].id
        );
    }
}


/* =========================================================
   CLOSE EDITOR VISUALS
========================================================= */

function closeEditorVisuals() {

    editorActive =
        false;


    dragState =
        null;


    selectedElementId =
        null;


    document.body.classList.remove(
        'editor-active'
    );


    if (editorPanel) {

        editorPanel.classList.add(
            'hidden'
        );
    }


    document
        .querySelectorAll(
            '.hud-element'
        )
        .forEach(
            (element) => {

                element.classList.remove(
                    'selected'
                );
            }
        );


    document
        .querySelectorAll(
            '.element-button'
        )
        .forEach(
            (button) => {

                button.classList.remove(
                    'active'
                );
            }
        );
}


/* =========================================================
   NUI POST
========================================================= */

async function postNui(
    callbackName,
    body = {}
) {

    try {

        const response =
            await fetch(

                `https://${GetParentResourceName()}/${callbackName}`,

                {

                    method:
                        'POST',

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


    } catch (
        error
    ) {

        console.error(
            `[LB-VAMPIRE HUD] NUI callback failed: ${callbackName}`,
            error
        );


        return null;
    }
}


/* =========================================================
   SAVE
========================================================= */

async function saveEditor() {

    await postNui(
        'hudSave',
        {

            layout:
                workingLayout
        }
    );


    closeEditorVisuals();
}


/* =========================================================
   CANCEL
========================================================= */

async function cancelEditor() {

    await postNui(
        'hudCancel'
    );


    closeEditorVisuals();
}


/* =========================================================
   RESET
========================================================= */

function resetEditor() {

    workingLayout =
        clone(
            defaultLayout
        );


    applyWorkingLayout();


    updateControlValues();
}


/* =========================================================
   SCALE
========================================================= */

if (scaleRange) {

    scaleRange.addEventListener(

        'input',

        () => {

            if (
                !selectedElementId ||
                !workingLayout[
                    selectedElementId
                ]
            ) {

                return;
            }


            const value =
                clamp(

                    Number(
                        scaleRange.value
                    ),

                    editorLimits.minScale,
                    editorLimits.maxScale
                );


            workingLayout[
                selectedElementId
            ].scale =
                value;


            applyElementLayout(

                selectedElementId,

                workingLayout[
                    selectedElementId
                ]
            );


            updateControlValues();
        }
    );
}


/* =========================================================
   OPACITY
========================================================= */

if (opacityRange) {

    opacityRange.addEventListener(

        'input',

        () => {

            if (
                !selectedElementId ||
                !workingLayout[
                    selectedElementId
                ]
            ) {

                return;
            }


            const value =
                clamp(

                    Number(
                        opacityRange.value
                    ),

                    editorLimits.minOpacity,
                    editorLimits.maxOpacity
                );


            workingLayout[
                selectedElementId
            ].opacity =
                value;


            applyElementLayout(

                selectedElementId,

                workingLayout[
                    selectedElementId
                ]
            );


            updateControlValues();
        }
    );
}


/* =========================================================
   BUTTONS
========================================================= */

if (resetButton) {

    resetButton.addEventListener(
        'click',
        resetEditor
    );
}


if (cancelButton) {

    cancelButton.addEventListener(
        'click',
        cancelEditor
    );
}


if (closeEditorButton) {

    closeEditorButton.addEventListener(
        'click',
        cancelEditor
    );
}


if (saveButton) {

    saveButton.addEventListener(
        'click',
        saveEditor
    );
}


/* =========================================================
   ESCAPE
========================================================= */

document.addEventListener(

    'keydown',

    (event) => {

        if (
            editorActive &&
            event.key ===
                'Escape'
        ) {

            event.preventDefault();


            cancelEditor();
        }
    }
);


/* =========================================================
   DRAG & DROP
========================================================= */

document
    .querySelectorAll(
        '.hud-element'
    )
    .forEach(
        (element) => {

            element.addEventListener(

                'mousedown',

                (event) => {

                    if (
                        !editorActive
                    ) {

                        return;
                    }


                    if (
                        event.button !==
                        0
                    ) {

                        return;
                    }


                    const elementId =
                        element.dataset
                            .hudElement;


                    if (
                        !workingLayout[
                            elementId
                        ]
                    ) {

                        return;
                    }


                    selectElement(
                        elementId
                    );


                    const rect =
                        element
                            .getBoundingClientRect();


                    dragState = {

                        elementId,

                        offsetX:
                            event.clientX -
                            rect.left,

                        offsetY:
                            event.clientY -
                            rect.top
                    };


                    event.preventDefault();
                }
            );
        }
    );


document.addEventListener(

    'mousemove',

    (event) => {

        if (
            !editorActive ||
            !dragState
        ) {

            return;
        }


        const element =
            getElementNode(
                dragState.elementId
            );


        if (!element) {
            return;
        }


        const rect =
            element
                .getBoundingClientRect();


        const viewportWidth =
            window.innerWidth;


        const viewportHeight =
            window.innerHeight;


        let leftPx =
            event.clientX -
            dragState.offsetX;


        let topPx =
            event.clientY -
            dragState.offsetY;


        leftPx =
            clamp(

                leftPx,
                0,

                viewportWidth -
                    rect.width
            );


        topPx =
            clamp(

                topPx,
                0,

                viewportHeight -
                    rect.height
            );


        const leftPercent =
            (
                leftPx /
                viewportWidth
            ) * 100;


        const bottomPercent =
            (
                (
                    viewportHeight -
                    (
                        topPx +
                        rect.height
                    )
                ) /
                viewportHeight
            ) * 100;


        workingLayout[
            dragState.elementId
        ].left =
            Number(
                leftPercent.toFixed(
                    4
                )
            );


        workingLayout[
            dragState.elementId
        ].bottom =
            Number(
                bottomPercent.toFixed(
                    4
                )
            );


        applyElementLayout(

            dragState.elementId,

            workingLayout[
                dragState.elementId
            ]
        );
    }
);


document.addEventListener(

    'mouseup',

    () => {

        dragState =
            null;
    }
);


/* =========================================================
   NUI MESSAGES
========================================================= */

window.addEventListener(

    'message',

    (event) => {

        const data =
            event.data ||
            {};


        /* -------------------------------------------------
           VAMPIRE BLOOD
        ------------------------------------------------- */

        if (
            data.action ===
            'blood:update'
        ) {

            if (
                data.visible !==
                true
            ) {

                hideBloodHud();

                return;
            }


            updateBlood(
                data
            );


            return;
        }


        if (
            data.action ===
            'blood:hide'
        ) {

            hideBloodHud();

            return;
        }


        /* -------------------------------------------------
           SUN
        ------------------------------------------------- */

        if (
            data.action ===
            'sun:update'
        ) {

            /*
                Hem root payload:

                {
                    action: "sun:update",
                    state: "DIRECT"
                }

                hem eski nested payload:

                {
                    action: "sun:update",
                    data: {...}
                }

                destekleniyor.
            */

            const payload =
                (
                    data.data &&
                    typeof data.data ===
                        'object'
                )
                    ? data.data
                    : data;


            updateSun(
                payload
            );


            return;
        }


        if (
            data.action ===
            'sun:hide'
        ) {

            hideSunHud();

            return;
        }


        /* -------------------------------------------------
           HUMAN BLOOD
        ------------------------------------------------- */

        if (
            data.action ===
            'humanblood:update'
        ) {

            const payload =
                (
                    data.data &&
                    typeof data.data ===
                        'object'
                )
                    ? data.data
                    : data;


            updateHumanBlood(
                payload
            );


            return;
        }


        if (
            data.action ===
            'humanblood:hide'
        ) {

            hideHumanBloodHud();

            return;
        }


        /* -------------------------------------------------
           HUD EDITOR OPEN
        ------------------------------------------------- */

        if (
            data.action ===
            'hud:editor:open'
        ) {

            openEditor(
                data
            );


            return;
        }


        /* -------------------------------------------------
           HUD EDITOR CLOSE
        ------------------------------------------------- */

        if (
            data.action ===
            'hud:editor:close'
        ) {

            closeEditorVisuals();


            return;
        }
    }
);


/* =========================================================
   NUI READY
========================================================= */

window.addEventListener(

    'DOMContentLoaded',

    async () => {

        /*
            Başlangıçta hiçbir HUD flash yapmasın.
        */

        hideBloodHud();

        hideSunHud();

        hideHumanBloodHud();


        await postNui(
            'hudReady'
        );
    }
);