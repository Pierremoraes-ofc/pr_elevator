
function setDisplay(selector, value) {
    document.querySelectorAll(selector).forEach(function (element) {
        element.style.display = value;
    });
}

let currentDisplayText = 'ENTER CODE';

function setDisplayText(value) {
    currentDisplayText = value == null ? '' : String(value);
    document.querySelectorAll('.display').forEach(function (element) {
        element.textContent = currentDisplayText;
    });
}

document.addEventListener('DOMContentLoaded', function () {
    setDisplayText(currentDisplayText);
    setDisplay('.keypad', 'none');
    setDisplay('.mouse', 'none');
});

window.addEventListener('message', function (event) {
    const e = event.data;
    switch (e.action) {
        case "KEYPAD":
            if (!e.value) {
                setDisplay('.keypad', 'none');
            }else {
                setDisplay('.keypad', 'flex');
            }
            break;
        case "MOUSE":
            if (!e.value) {
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
