const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'n33s_creator';

const app = document.getElementById('app');
const selectorView = document.getElementById('selector-view');
const creatorView = document.getElementById('creator-view');
const idCardView = document.getElementById('id-card-view');
const slotsElement = document.getElementById('slots');
const slotCount = document.getElementById('slot-count');
const toast = document.getElementById('toast');

let maxCharacters = 3;
let characters = [];
let currentSlot = null;
let currentGender = 'male';
let currentCameraMode = 'body';
let appearanceTimer = null;

const defaultAppearance = {
    male: {
        face: { mother: 21, father: 0, shapeMix: 0.5, skinMix: 0.5 },
        hair: { style: 0, color: 0, highlight: 0 },
        overlays: {
            beard: -1,
            beardOpacity: 0,
            beardColor: 0,
            eyebrows: 0,
            eyebrowsOpacity: 0.8,
            eyebrowsColor: 0,
            makeup: -1,
            makeupOpacity: 0
        },
        eyeColor: 0,
        components: {
            1: { drawable: 0, texture: 0 },
            3: { drawable: 15, texture: 0 },
            4: { drawable: 1, texture: 0 },
            5: { drawable: 0, texture: 0 },
            6: { drawable: 1, texture: 0 },
            7: { drawable: 0, texture: 0 },
            8: { drawable: 15, texture: 0 },
            9: { drawable: 0, texture: 0 },
            10: { drawable: 0, texture: 0 },
            11: { drawable: 0, texture: 0 }
        },
        props: {
            0: { drawable: -1, texture: 0 },
            1: { drawable: -1, texture: 0 },
            2: { drawable: -1, texture: 0 },
            3: { drawable: -1, texture: 0 },
            4: { drawable: -1, texture: 0 },
            5: { drawable: -1, texture: 0 },
            6: { drawable: -1, texture: 0 },
            7: { drawable: -1, texture: 0 }
        }
    },
    female: {
        face: { mother: 21, father: 0, shapeMix: 0.5, skinMix: 0.5 },
        hair: { style: 0, color: 0, highlight: 0 },
        overlays: {
            beard: -1,
            beardOpacity: 0,
            beardColor: 0,
            eyebrows: 0,
            eyebrowsOpacity: 0.8,
            eyebrowsColor: 0,
            makeup: -1,
            makeupOpacity: 0
        },
        eyeColor: 0,
        components: {
            1: { drawable: 0, texture: 0 },
            3: { drawable: 15, texture: 0 },
            4: { drawable: 4, texture: 0 },
            5: { drawable: 0, texture: 0 },
            6: { drawable: 3, texture: 0 },
            7: { drawable: 0, texture: 0 },
            8: { drawable: 14, texture: 0 },
            9: { drawable: 0, texture: 0 },
            10: { drawable: 0, texture: 0 },
            11: { drawable: 5, texture: 0 }
        },
        props: {
            0: { drawable: -1, texture: 0 },
            1: { drawable: -1, texture: 0 },
            2: { drawable: -1, texture: 0 },
            3: { drawable: -1, texture: 0 },
            4: { drawable: -1, texture: 0 },
            5: { drawable: -1, texture: 0 },
            6: { drawable: -1, texture: 0 },
            7: { drawable: -1, texture: 0 }
        }
    }
};

const componentControls = [
    { id: 1, label: 'Maska' },
    { id: 3, label: 'Ręce / rękawice' },
    { id: 4, label: 'Spodnie' },
    { id: 5, label: 'Torba / plecak' },
    { id: 6, label: 'Buty' },
    { id: 7, label: 'Łańcuch / akcesoria' },
    { id: 8, label: 'Koszulka' },
    { id: 9, label: 'Kamizelka' },
    { id: 10, label: 'Naszywki' },
    { id: 11, label: 'Kurtka / torso' }
];

const propControls = [
    { id: 0, label: 'Czapka / hełm' },
    { id: 1, label: 'Okulary' },
    { id: 2, label: 'Kolczyki / uszy' },
    { id: 3, label: 'Prop 3' },
    { id: 4, label: 'Prop 4' },
    { id: 5, label: 'Prop 5' },
    { id: 6, label: 'Zegarek' },
    { id: 7, label: 'Bransoletka' }
];

let creatorLimits = { components: {}, props: {} };

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

let appearance = clone(defaultAppearance.male);

function createRange(label, path, min, max) {
    const wrapper = document.createElement('label');
    wrapper.className = 'range-row';

    const span = document.createElement('span');
    span.textContent = label;

    const output = document.createElement('output');
    output.dataset.output = path;
    output.textContent = '0';

    const input = document.createElement('input');
    input.type = 'range';
    input.min = String(min);
    input.max = String(max);
    input.step = '1';
    input.dataset.appearance = path;

    wrapper.appendChild(span);
    wrapper.appendChild(output);
    wrapper.appendChild(input);
    return wrapper;
}

function buildDynamicControls() {
    const componentHost = document.getElementById('component-controls');
    const propHost = document.getElementById('prop-controls');

    componentHost.innerHTML = '';
    propHost.innerHTML = '';

    componentControls.forEach((item) => {
        componentHost.appendChild(createRange(`${item.label}`, `components.${item.id}.drawable`, 0, 0));
        componentHost.appendChild(createRange(`${item.label} tekstura`, `components.${item.id}.texture`, 0, 0));
    });

    propControls.forEach((item) => {
        propHost.appendChild(createRange(`${item.label}`, `props.${item.id}.drawable`, -1, -1));
        propHost.appendChild(createRange(`${item.label} tekstura`, `props.${item.id}.texture`, 0, 0));
    });
}

function post(name, data = {}) {
    return fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    })
        .then((response) => response.json())
        .catch(() => ({ ok: false, error: 'Brak odpowiedzi NUI.' }));
}

function showToast(message) {
    toast.textContent = message || 'Wystąpił błąd.';
    toast.classList.remove('hidden');
    clearTimeout(showToast.timeout);
    showToast.timeout = setTimeout(() => toast.classList.add('hidden'), 3500);
}

function showView(view) {
    app.classList.remove('hidden');
    selectorView.classList.toggle('hidden', view !== 'selector');
    creatorView.classList.toggle('hidden', view !== 'creator');
}

function hideAll() {
    selectorView.classList.add('hidden');
    creatorView.classList.add('hidden');
    idCardView.classList.add('hidden');
    toast.classList.add('hidden');
    app.classList.add('hidden');
}

function formatGender(gender) {
    return gender === 'female' ? 'Kobieta' : 'Mężczyzna';
}

function renderSlots() {
    slotsElement.innerHTML = '';
    slotCount.textContent = `${characters.length}/${maxCharacters}`;

    for (let slot = 1; slot <= maxCharacters; slot += 1) {
        const character = characters.find((item) => Number(item.slot) === slot);
        const card = document.createElement('article');
        card.className = `slot-card${character ? '' : ' empty'}`;

        const top = document.createElement('div');
        const number = document.createElement('div');
        number.className = 'slot-number';
        number.textContent = `Slot ${slot}`;
        top.appendChild(number);

        const name = document.createElement('div');
        name.className = 'slot-name';
        name.textContent = character ? `${character.firstname} ${character.lastname}` : 'Pusty slot';
        top.appendChild(name);

        const meta = document.createElement('div');
        meta.className = 'slot-meta';
        meta.textContent = character
            ? `${formatGender(character.gender)} | ${character.dateofbirth}`
            : 'Dostępne miejsce';
        top.appendChild(meta);

        const action = document.createElement('button');
        action.type = 'button';
        action.className = character ? 'primary' : 'secondary';
        action.textContent = character ? 'Graj' : 'Stwórz postać';
        action.addEventListener('click', async () => {
            action.disabled = true;
            const response = character
                ? await post('playCharacter', { id: character.id })
                : await post('openCreator', { slot });

            action.disabled = false;

            if (!response.ok) {
                showToast(response.error);
                return;
            }

            if (!character) {
                currentSlot = slot;
                resetCreator('male');
                showView('creator');
            }
        });

        card.appendChild(top);
        card.appendChild(action);
        slotsElement.appendChild(card);
    }
}

function getPath(object, path) {
    return path.split('.').reduce((value, key) => {
        if (!value || value[key] === undefined) {
            return undefined;
        }
        return value[key];
    }, object);
}

function setPath(object, path, value) {
    const parts = path.split('.');
    const last = parts.pop();
    const target = parts.reduce((acc, key) => {
        acc[key] = acc[key] || {};
        return acc[key];
    }, object);
    target[last] = value;
}

function syncAppearanceInputs() {
    document.querySelectorAll('[data-appearance]').forEach((input) => {
        const path = input.dataset.appearance;
        const value = getPath(appearance, path) ?? Number(input.min) ?? 0;
        input.value = value;
        const output = document.querySelector(`[data-output="${path}"]`);
        if (output) {
            output.textContent = Number(value) % 1 === 0 ? String(value) : Number(value).toFixed(2);
        }
    });
}

function clampRangeValue(path, min, max) {
    const input = document.querySelector(`[data-appearance="${path}"]`);
    const output = document.querySelector(`[data-output="${path}"]`);
    if (!input) {
        return;
    }

    input.min = String(min);
    input.max = String(max);

    let value = Number(getPath(appearance, path));
    if (!Number.isFinite(value)) {
        value = min;
    }

    value = Math.max(min, Math.min(value, max));
    input.value = String(value);
    setPath(appearance, path, value);

    if (output) {
        output.textContent = String(value);
    }
}

function applyCreatorLimits(limits) {
    creatorLimits = limits || { components: {}, props: {} };
    creatorLimits.components = creatorLimits.components || {};
    creatorLimits.props = creatorLimits.props || {};

    const hairLimit = creatorLimits.components['2'];
    if (hairLimit) {
        clampRangeValue('hair.style', 0, Math.max(0, Number(hairLimit.drawableMax) || 0));
    }

    componentControls.forEach((item) => {
        const limit = creatorLimits.components[String(item.id)] || {};
        const drawableMax = Math.max(0, Number(limit.drawableMax) || 0);
        const textureMax = Math.max(0, Number(limit.textureMax) || 0);
        clampRangeValue(`components.${item.id}.drawable`, 0, drawableMax);
        clampRangeValue(`components.${item.id}.texture`, 0, textureMax);
    });

    propControls.forEach((item) => {
        const limit = creatorLimits.props[String(item.id)] || {};
        const drawableMax = Math.max(-1, Number(limit.drawableMax) || -1);
        const textureMax = Math.max(0, Number(limit.textureMax) || 0);
        clampRangeValue(`props.${item.id}.drawable`, -1, drawableMax);
        clampRangeValue(`props.${item.id}.texture`, 0, textureMax);
    });
}

function sendAppearanceUpdate() {
    clearTimeout(appearanceTimer);
    appearanceTimer = setTimeout(() => {
        post('updateAppearance', { skin: appearance });
    }, 45);
}

function resetCreator(gender) {
    currentGender = gender;
    appearance = clone(defaultAppearance[gender]);
    document.getElementById('firstname').value = '';
    document.getElementById('lastname').value = '';
    document.getElementById('nationality').value = 'Polska';
    document.getElementById('dateofbirth').value = '';
    document.getElementById('height').value = '180';
    document.getElementById('height-output').textContent = '180 cm';
    document.querySelectorAll('[data-gender]').forEach((button) => {
        button.classList.toggle('active', button.dataset.gender === gender);
    });
    syncAppearanceInputs();
    post('requestCreatorLimits');
}

function collectCharacterPayload() {
    return {
        slot: currentSlot,
        firstname: document.getElementById('firstname').value.trim(),
        lastname: document.getElementById('lastname').value.trim(),
        nationality: document.getElementById('nationality').value.trim(),
        dateofbirth: document.getElementById('dateofbirth').value.trim(),
        height: Number(document.getElementById('height').value),
        gender: currentGender,
        skin: appearance
    };
}

function validatePayload(payload) {
    if (payload.firstname.length < 2 || payload.firstname.length > 32) {
        return 'Imię musi mieć od 2 do 32 znaków.';
    }
    if (payload.lastname.length < 2 || payload.lastname.length > 32) {
        return 'Nazwisko musi mieć od 2 do 32 znaków.';
    }
    if (payload.nationality.length < 2 || payload.nationality.length > 48) {
        return 'Pochodzenie musi mieć od 2 do 48 znaków.';
    }
    if (!/^(\d{4}-\d{2}-\d{2}|\d{2}\.\d{2}\.\d{4})$/.test(payload.dateofbirth)) {
        return 'Data urodzenia musi mieć format YYYY-MM-DD lub DD.MM.YYYY.';
    }
    if (payload.height < 150 || payload.height > 200) {
        return 'Wzrost musi być w zakresie 150-200 cm.';
    }
    return null;
}

buildDynamicControls();

document.getElementById('height').addEventListener('input', (event) => {
    document.getElementById('height-output').textContent = `${event.target.value} cm`;
});

document.querySelectorAll('[data-gender]').forEach((button) => {
    button.addEventListener('click', async () => {
        const gender = button.dataset.gender;
        if (gender === currentGender) {
            return;
        }

        currentGender = gender;
        appearance = clone(defaultAppearance[gender]);
        document.querySelectorAll('[data-gender]').forEach((item) => {
            item.classList.toggle('active', item.dataset.gender === gender);
        });
        syncAppearanceInputs();
        await post('changeGender', { gender, skin: appearance });
    });
});

document.querySelectorAll('[data-appearance]').forEach((input) => {
    input.addEventListener('input', () => {
        const step = Number(input.step);
        const value = step > 0 && step < 1 ? Number(input.value) : parseInt(input.value, 10);
        setPath(appearance, input.dataset.appearance, value);
        const output = document.querySelector(`[data-output="${input.dataset.appearance}"]`);
        if (output) {
            output.textContent = Number(value) % 1 === 0 ? String(value) : Number(value).toFixed(2);
        }
        sendAppearanceUpdate();
    });
});

document.getElementById('tabs').addEventListener('click', (event) => {
    const button = event.target.closest('[data-tab]');
    if (!button) {
        return;
    }

    document.querySelectorAll('.tab').forEach((tab) => tab.classList.toggle('active', tab === button));
    document.querySelectorAll('.tab-panel').forEach((panel) => {
        panel.classList.toggle('active', panel.dataset.panel === button.dataset.tab);
    });
});

document.querySelectorAll('[data-camera]').forEach((button) => {
    button.addEventListener('click', () => {
        currentCameraMode = button.dataset.camera;
        post('cameraMode', { mode: currentCameraMode });
    });
});

document.querySelectorAll('[data-rotate]').forEach((button) => {
    button.addEventListener('click', () => {
        post('rotatePed', { delta: Number(button.dataset.rotate), mode: currentCameraMode });
    });
});

document.getElementById('back-to-selection').addEventListener('click', async () => {
    const response = await post('backToSelection');
    if (!response.ok) {
        showToast(response.error);
        return;
    }
    showView('selector');
});

document.getElementById('save-character').addEventListener('click', async (event) => {
    const button = event.currentTarget;
    const payload = collectCharacterPayload();
    const validationError = validatePayload(payload);

    if (validationError) {
        showToast(validationError);
        return;
    }

    button.disabled = true;
    const response = await post('createCharacter', payload);
    button.disabled = false;

    if (!response.ok) {
        showToast(response.error);
    }
});

document.getElementById('close-id-card').addEventListener('click', async () => {
    idCardView.classList.add('hidden');
    await post('closeIdCard');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !idCardView.classList.contains('hidden')) {
        document.getElementById('close-id-card').click();
    }
});

function renderIdCard(card) {
    document.getElementById('id-avatar').src = card.gender === 'female'
        ? 'assets/avatar_female.svg'
        : 'assets/avatar_male.svg';
    document.getElementById('id-firstname').textContent = card.firstname || '-';
    document.getElementById('id-lastname').textContent = card.lastname || '-';
    document.getElementById('id-nationality').textContent = card.nationality || '-';
    document.getElementById('id-dateofbirth').textContent = card.dateofbirth || '-';
    document.getElementById('id-height').textContent = `${card.height || '-'} cm`;
    document.getElementById('id-gender').textContent = card.labelGender || formatGender(card.gender);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'openSelector') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        maxCharacters = Number(data.maxCharacters) || 3;
        renderSlots();
        showView('selector');
    }

    if (data.action === 'openCreator') {
        currentSlot = data.slot || currentSlot;
        resetCreator('male');
        showView('creator');
    }

    if (data.action === 'closeAll') {
        hideAll();
    }

    if (data.action === 'showIdCard') {
        renderIdCard(data.card || {});
        app.classList.remove('hidden');
        idCardView.classList.remove('hidden');
    }

    if (data.action === 'creatorLimits') {
        applyCreatorLimits(data.limits || {});
    }

    if (data.action === 'hideIdCard') {
        idCardView.classList.add('hidden');
        if (selectorView.classList.contains('hidden') && creatorView.classList.contains('hidden')) {
            app.classList.add('hidden');
        }
    }
});

hideAll();
