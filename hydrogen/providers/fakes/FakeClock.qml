import QtQml

QtObject {
    property double currentMs: 0
    function nowMs() {
        return currentMs;
    }
    function nowIso() {
        return new Date(currentMs).toISOString();
    }
    function advance(milliseconds) {
        currentMs += milliseconds;
    }
}
