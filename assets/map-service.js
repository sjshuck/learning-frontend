const $ = id => document.getElementById(id);

const keyURL = () => 'key/' + encodeURIComponent($('key-input').value);

function setResult(className, message, value) {
    $('result').className = className;

    if (typeof value !== 'undefined') {
        const span = document.createElement('span');
        span.innerText = value;
        span.className = 'data';
        $('result').replaceChildren(message + ': ', span);
    } else {
        const span = document.createElement('span');
        span.innerText = message;
        span.className = 'advice';
        $('result').replaceChildren(span);
    }
}

const keyActions = {
    lookup: async () => {
        const resp = await fetch(keyURL());
        if (resp.ok) {
            const value = await resp.text();
            setResult('happy', 'Current value', value);
        } else if (resp.status === 404) {
            setResult('sad', 'Not found');
        }
    },

    insert: async () => {
        const value = $('value-input').value;

        const resp = await fetch(keyURL(), {method: 'PUT', body: value});
        const o = await resp.json();
        if (o.previous !== null) {
            setResult('neutral', 'Previous value', o.previous);
        } else {
            setResult('neutral', 'No previous value');
        }
    },

    delete: async () => {
        const resp = await fetch(keyURL(), {method: 'DELETE'});
        if (resp.ok) {
            const o = await resp.json();
            setResult('neutral', 'Previous value', o.previous);
        } else if (resp.status === 404) {
            setResult('sad', 'Not found');
        }
    },
}

function updateSubmitDisabled() {
    const visibleKeyValueInputs =
        document.querySelectorAll('#key-value-inputs input:not([hidden])');
    $('submit-button').disabled =
        [...visibleKeyValueInputs].some(input => input.value === '');
}

function handleKeyValueInput(event) {
    if (event.target.value === '') {
        event.target.classList.remove('data');
    } else {
        event.target.classList.add('data');
    }
    updateSubmitDisabled();
}

function handleSelectAction(event) {
    $('value-input').hidden = event.target.value !== 'insert';
    updateSubmitDisabled();
}

async function handleSubmit() {
    const selectedAction =
        document.querySelector('#select-action input:checked').value;
    await keyActions[selectedAction]();

    // Reset everything
    document.querySelectorAll('#key-value-inputs input').forEach(input => {
        input.value = '';
        input.classList.remove('data');
    });
    $('value-input').hidden = true;
    document.querySelector('#select-action input[value="lookup"]')
        .checked = true;
    $('submit-button').disabled = true;
}

function init() {
    document.querySelectorAll('#key-value-inputs input')
        .forEach(input => input.addEventListener('input', handleKeyValueInput));

    document.querySelectorAll('#select-action input')
        .forEach(radio => radio.addEventListener('click', handleSelectAction));

    $('submit-button').addEventListener('click', handleSubmit);
}