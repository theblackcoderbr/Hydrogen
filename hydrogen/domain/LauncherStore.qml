import QtQml
import "../logic/Launcher.js" as Launcher

QtObject {
    id: root

    property var applications: []
    property bool applicationCatalogReady: false
    property var fileResults: []
    property int fileRequestId: 0
    property bool fileSearching: false
    property var validFilePaths: []
    property bool fileValidationReady: false
    property var executables: []
    property var actions: []
    property var history: []
    property string query: ""
    property int resultLimit: 20
    property var results: Launcher.launcherResults(applications, fileResults, actions, executables, history, query, resultLimit)
    property bool launching: false
    property string failureCode: ""
    property string failureMessage: ""

    signal historyMutated(bool immediate)
    signal historyRestored

    function publishApplications(nextApplications) {
        root.applications = nextApplications || [];
        root.applicationCatalogReady = true;
    }

    function publishExecutables(nextExecutables) {
        root.executables = nextExecutables || [];
    }

    function publishActions(nextActions) {
        root.actions = nextActions || [];
    }

    function beginFileSearch() {
        root.fileRequestId += 1;
        root.fileResults = [];
        root.fileSearching = true;
        return root.fileRequestId;
    }

    function cancelFileSearch() {
        root.fileRequestId += 1;
        root.fileResults = [];
        root.fileSearching = false;
        return root.fileRequestId;
    }

    function publishFileResults(requestId, files) {
        if (Number(requestId) !== root.fileRequestId)
            return false;
        root.fileResults = files || [];
        root.fileSearching = false;
        return true;
    }

    function publishValidFilePaths(paths) {
        root.validFilePaths = paths || [];
        root.fileValidationReady = true;
    }

    function restoreHistory(items) {
        root.history = Launcher.normalizeHistory(items || []);
        root.historyRestored();
    }

    function recordResult(result, now) {
        if (result && result.kind === "file" && String(result.path || "").indexOf("/") === 0 && root.validFilePaths.indexOf(result.path) < 0)
            root.validFilePaths = root.validFilePaths.concat([String(result.path)]);
        const next = Launcher.recordUse(root.history, result, now);
        if (JSON.stringify(next) === JSON.stringify(root.history))
            return false;
        root.history = next;
        root.historyMutated(false);
        return true;
    }

    function recordUse(desktopEntry, now) {
        return root.recordResult({ kind: "application", id: desktopEntry }, now);
    }

    function pruneHistory(nowMs, maximum, days) {
        const next = Launcher.pruneHistory(
            root.history,
            root.applications.map(entry => entry.id),
            root.validFilePaths,
            root.applicationCatalogReady,
            root.fileValidationReady,
            nowMs,
            maximum,
            days
        );
        if (JSON.stringify(next) === JSON.stringify(root.history))
            return false;
        root.history = next;
        root.historyMutated(false);
        return true;
    }

    function clearHistory() {
        if (root.history.length === 0)
            return false;
        root.history = [];
        root.historyMutated(true);
        return true;
    }

    function clearFailure() {
        root.failureCode = "";
        root.failureMessage = "";
    }
}
