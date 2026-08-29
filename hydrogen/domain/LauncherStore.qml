import QtQml
import "../logic/Launcher.js" as Launcher

QtObject {
    id: root

    property var applications: []
    property var history: []
    property string query: ""
    property int resultLimit: 20
    property var results: Launcher.searchApplications(applications, history, query, resultLimit)
    property bool launching: false
    property string failureCode: ""
    property string failureMessage: ""

    signal historyMutated
    signal historyRestored

    function publishApplications(nextApplications) {
        root.applications = nextApplications || [];
    }

    function restoreHistory(items) {
        root.history = items || [];
        root.historyRestored();
    }

    function recordUse(desktopEntry, now) {
        root.history = Launcher.recordApplicationUse(root.history, desktopEntry, now);
        root.historyMutated();
    }

    function pruneHistory(nowMs, maximum, days) {
        const next = Launcher.pruneApplicationHistory(root.history, root.applications.map(entry => entry.id), nowMs, maximum, days);
        if (JSON.stringify(next) === JSON.stringify(root.history))
            return false;
        root.history = next;
        root.historyMutated();
        return true;
    }

    function clearFailure() {
        root.failureCode = "";
        root.failureMessage = "";
    }
}
