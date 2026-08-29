import QtQml

QtObject {
    function nowMs() {
        return Date.now();
    }
    function nowIso() {
        return new Date().toISOString();
    }
}
