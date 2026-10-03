
function setDisplay(selector, value) {
    document.querySelectorAll(selector).forEach(function (element) {
        element.style.display = value;
    });
}

// Display strings come exclusively from the resource locale through Lua.
let currentDisplayText = '';
const isDuiPage = new URLSearchParams(window.location.search).get('dui') === '1';
let keypadVisible = isDuiPage;
let mouseVisible = false;

function setDisplayText(value) {
    currentDisplayText = value == null ? '' : String(value);
    document.querySelectorAll('.display').forEach(function (element) {
        element.textContent = currentDisplayText;
        element.style.fontSize = `min(8vh, ${95 / Math.max(1, currentDisplayText.length)}vw)`;
    });
}

document.addEventListener('DOMContentLoaded', function () {
    setDisplayText(currentDisplayText);
    setDisplay('.keypad', keypadVisible ? 'flex' : 'none');
    setDisplay('.mouse', mouseVisible && !isDuiPage ? 'flex' : 'none');
    if (isDuiPage) {
        const resource = typeof GetParentResourceName === 'function'
            ? GetParentResourceName() : window.location.hostname.replace(/^cfx-nui-/, '');
        fetch(`https://${resource}/keypadDuiReady`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}'
        }).catch(error => console.error(error));
    }
});

window.addEventListener('message', function (event) {
    const e = event.data;
    if (!e || typeof e !== 'object') return;
    switch (e.action) {
        case "KEYPAD":
            keypadVisible = e.value === true;
            if (!e.value) {
                setDisplay('.keypad', 'none');
            }else {
                setDisplay('.keypad', 'flex');
            }
            break;
        case "MOUSE":
            mouseVisible = e.value === true;
            if (!mouseVisible || isDuiPage) {
                setDisplay('.mouse', 'none');
            }else {
                setDisplay('.mouse', 'flex');
            }
            break;
        case "DISPLAY":
            setDisplayText(e.value);
            break;
        case "BUTTON":
            HighlightButton(e.value)
            break;
        default: break;
    }
});

let prevBtnID = -1
function HighlightButton(ID) {
    if (prevBtnID > 0 ) {
        const previous = document.getElementById('btn' + prevBtnID);
        if (previous) previous.classList.remove('active');
    }
    if (ID > 0 ) {
        const current = document.getElementById('btn' + ID);
        if (current) current.classList.add('active');
        prevBtnID = ID
    } else {
        prevBtnID = -1
    }
}
