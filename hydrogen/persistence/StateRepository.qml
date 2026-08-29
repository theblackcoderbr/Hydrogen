import QtQml
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../logic/Foundation.js" as Foundation
import "../logic/Launcher.js" as Launcher

QtObject {
    id: root

    required property var errors
    required property var launcherStore
    property string stateRoot: Quickshell.stateDir
    property int schemaVersion: 1
    property string state: "initializing"
    property bool doNotDisturb: false
    property bool dirty: false
    property bool writePending: false
    property bool launcherDirty: false
    property bool launcherWritePending: false
    property bool launcherPersistenceSuspended: false
    property bool stateLoaded: false
    property bool launcherLoaded: false
    property bool restorationEmitted: false
    property bool flushRequested: false
    property bool flushSucceeded: true
    property bool persistenceSuspended: false
    property string lastWriteAt: ""
    property int pendingWrites: (writePending ? 1 : 0) + (launcherWritePending ? 1 : 0)
    property string corruptStatePath: ""
    property var corruptRemovalQueue: []

    signal restored
    signal flushed(bool success)

    function start() {
        ensureDirectory.exec(["mkdir", "-p", root.stateRoot]);
    }

    function loadState() {
        stateFile.path = root.stateRoot + "/state.json";
        launcherFile.path = root.stateRoot + "/launcher-history.json";
        notificationFile.path = root.stateRoot + "/notification-history.json";
    }

    function applyStateText(text) {
        const parsed = Foundation.parseState(text, root.schemaVersion);
        if (parsed.ok) {
            root.doNotDisturb = parsed.data.do_not_disturb;
            root.state = "ready";
            if (parsed.empty) {
                root.dirty = true;
                root.flushNow();
            }
            root.stateLoaded = true;
            root.maybeRestored();
            return;
        }
        if (parsed.preserve) {
            root.persistenceSuspended = true;
            root.state = "degraded";
            root.errors.add({
                code: parsed.code,
                category: "hydrogen.persistence",
                severity: "warning",
                component: "state",
                action: "upgrade_hydrogen",
                message: "O estado usa uma versão incompatível e foi preservado."
            });
            root.stateLoaded = true;
            root.maybeRestored();
            return;
        }
        root.state = "degraded";
        root.errors.add({
            code: "state_corrupt",
            category: "hydrogen.persistence",
            severity: "warning",
            component: "state",
            action: "inspect_corrupt_state",
            message: "O estado salvo estava corrompido e foi isolado."
        });
        root.doNotDisturb = false;
        root.dirty = true;
        const stamp = new Date().toISOString().replace(/[:.]/g, "-");
        root.corruptStatePath = root.stateRoot + "/state.corrupt-" + stamp + ".json";
        quarantineState.exec(["mv", "--", root.stateRoot + "/state.json", root.corruptStatePath]);
    }

    function setDoNotDisturb(value) {
        if (root.doNotDisturb === Boolean(value))
            return;
        root.doNotDisturb = Boolean(value);
        root.dirty = true;
        writeDebounce.restart();
    }

    function maybeRestored() {
        if (!root.restorationEmitted && root.stateLoaded && root.launcherLoaded) {
            root.restorationEmitted = true;
            root.restored();
        }
    }

    function applyLauncherText(text) {
        const parsed = Launcher.parseHistory(text, root.schemaVersion);
        if (parsed.ok) {
            root.launcherStore.restoreHistory(parsed.items);
            root.launcherLoaded = true;
            if (parsed.empty) {
                root.launcherDirty = true;
                launcherWriteDebounce.restart();
            }
            root.maybeRestored();
            return;
        }
        root.launcherStore.restoreHistory([]);
        root.launcherLoaded = true;
        root.launcherPersistenceSuspended = Boolean(parsed.preserve);
        root.errors.add({
            code: parsed.code,
            category: "hydrogen.persistence",
            severity: "warning",
            component: "launcher_history",
            action: parsed.preserve ? "upgrade_hydrogen" : "inspect_launcher_history",
            message: parsed.preserve ? "O histórico do launcher usa uma versão incompatível e foi preservado." : "O histórico do launcher estava inválido e foi reiniciado."
        });
        if (!parsed.preserve) {
            root.launcherDirty = true;
            root.launcherWriteDebounce.restart();
        }
        root.maybeRestored();
    }

    function flushNow() {
        writeDebounce.stop();
        launcherWriteDebounce.stop();
        root.flushRequested = true;
        root.flushSucceeded = true;
        if (root.dirty && !root.persistenceSuspended) {
            root.writePending = true;
            stateFile.setText(Foundation.serializeState({
                do_not_disturb: root.doNotDisturb
            }, new Date().toISOString()));
        } else if (root.dirty) {
            root.flushSucceeded = false;
        }
        if (root.launcherDirty && !root.launcherPersistenceSuspended) {
            root.launcherWritePending = true;
            launcherFile.setText(Launcher.serializeHistory(root.launcherStore.history, new Date().toISOString()));
        } else if (root.launcherDirty) {
            root.flushSucceeded = false;
        }
        root.finishFlushIfReady();
    }

    function finishFlushIfReady() {
        if (!root.flushRequested || root.writePending || root.launcherWritePending)
            return;
        const success = root.flushSucceeded;
        root.flushRequested = false;
        root.flushed(success);
    }

    function pruneCorruptCopies() {
        if (removeCorruptCopy.running || root.corruptRemovalQueue.length > 0)
            return;
        const names = [];
        for (let index = 0; index < corruptFiles.count; ++index)
            names.push(corruptFiles.get(index, "fileName"));
        root.corruptRemovalQueue = Foundation.corruptCopiesToDelete(names, 3);
        root.removeNextCorruptCopy();
    }

    function removeNextCorruptCopy() {
        if (removeCorruptCopy.running || root.corruptRemovalQueue.length === 0)
            return;
        const queue = root.corruptRemovalQueue.slice();
        const fileName = queue.shift();
        root.corruptRemovalQueue = queue;
        removeCorruptCopy.exec(["rm", "--", root.stateRoot + "/" + fileName]);
    }

    property Process ensureDirectory: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.errors.add({
                    code: "state_directory_failed",
                    category: "hydrogen.persistence",
                    severity: "error",
                    component: "state",
                    action: "check_permissions",
                    message: "Não foi possível preparar o diretório de estado."
                });
                root.stateLoaded = true;
                root.launcherLoaded = true;
                root.maybeRestored();
                return;
            }
            root.permissions.exec(["chmod", "0700", root.stateRoot]);
        }
    }

    property Process permissions: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.stateLoaded = true;
                root.launcherLoaded = true;
                root.maybeRestored();
                return;
            }
            root.touchFiles.exec(["touch", root.stateRoot + "/state.json", root.stateRoot + "/launcher-history.json", root.stateRoot + "/notification-history.json"]);
        }
    }

    property Process touchFiles: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.stateLoaded = true;
                root.launcherLoaded = true;
                root.maybeRestored();
                return;
            }
            root.initialFilePermissions.exec(["chmod", "0600", root.stateRoot + "/state.json", root.stateRoot + "/launcher-history.json", root.stateRoot + "/notification-history.json"]);
        }
    }

    property Process initialFilePermissions: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.stateLoaded = true;
                root.launcherLoaded = true;
                root.maybeRestored();
                return;
            }
            root.loadState();
        }
    }

    property Process quarantineState: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.persistenceSuspended = true;
                root.state = "failed";
                root.stateLoaded = true;
                root.maybeRestored();
                return;
            }
            root.corruptRetentionDebounce.restart();
            root.flushNow();
            root.stateLoaded = true;
            root.maybeRestored();
        }
    }

    property Process removeCorruptCopy: Process {
        onExited: exitCode => {
            const retentionError = Foundation.corruptRetentionError(exitCode);
            if (retentionError)
                root.errors.add(retentionError);
            root.removeNextCorruptCopy();
        }
    }

    property FolderListModel corruptFiles: FolderListModel {
        folder: "file://" + root.stateRoot
        nameFilters: ["state.corrupt-*.json"]
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Name
        onCountChanged: root.corruptRetentionDebounce.restart()
    }

    property FileView stateFile: FileView {
        atomicWrites: true
        blockWrites: false
        printErrors: false
        onLoaded: root.applyStateText(text())
        onLoadFailed: error => {
            root.state = "ready";
            root.doNotDisturb = false;
            root.dirty = true;
            root.flushNow();
            root.stateLoaded = true;
            root.maybeRestored();
        }
        onSaved: {
            root.dirty = false;
            root.writePending = false;
            root.lastWriteAt = new Date().toISOString();
            root.statePermissions.command = ["chmod", "0600", root.stateRoot + "/state.json"];
            root.statePermissions.running = true;
            root.finishFlushIfReady();
        }
        onSaveFailed: error => {
            root.writePending = false;
            root.flushSucceeded = false;
            root.state = "degraded";
            root.errors.add({
                code: "state_write_failed",
                category: "hydrogen.persistence",
                severity: "error",
                component: "state",
                action: "check_permissions",
                message: "Não foi possível gravar o estado; a memória foi preservada."
            });
            root.finishFlushIfReady();
        }
    }

    property FileView launcherFile: FileView {
        atomicWrites: true
        blockWrites: false
        printErrors: false
        onLoaded: root.applyLauncherText(text())
        onLoadFailed: error => root.applyLauncherText("")
        onSaved: {
            root.launcherDirty = false;
            root.launcherWritePending = false;
            root.launcherPermissions.command = ["chmod", "0600", root.stateRoot + "/launcher-history.json"];
            root.launcherPermissions.running = true;
            root.finishFlushIfReady();
        }
        onSaveFailed: error => {
            root.launcherWritePending = false;
            root.flushSucceeded = false;
            root.errors.add({
                code: "launcher_history_write_failed",
                category: "hydrogen.persistence",
                severity: "error",
                component: "launcher_history",
                action: "check_permissions",
                message: "Não foi possível gravar o histórico do launcher; a memória foi preservada."
            });
            root.finishFlushIfReady();
        }
    }

    property FileView notificationFile: FileView {
        atomicWrites: true
        blockWrites: false
        printErrors: false
        onLoaded: {
            if (text().trim() === "")
                setText(JSON.stringify({
                    schema_version: 1,
                    updated_at: new Date().toISOString(),
                    items: []
                }));
        }
        onLoadFailed: error => setText(JSON.stringify({
                schema_version: 1,
                updated_at: new Date().toISOString(),
                items: []
            }))
        onSaved: {
            root.notificationPermissions.command = ["chmod", "0600", root.stateRoot + "/notification-history.json"];
            root.notificationPermissions.running = true;
        }
    }

    property Process statePermissions: Process {}
    property Process launcherPermissions: Process {}
    property Process notificationPermissions: Process {}

    property Timer writeDebounce: Timer {
        interval: 250
        repeat: false
        onTriggered: root.flushNow()
    }

    property Timer launcherWriteDebounce: Timer {
        interval: 250
        repeat: false
        onTriggered: root.flushNow()
    }

    property Connections launcherHistoryConnection: Connections {
        target: root.launcherStore
        function onHistoryMutated() {
            root.launcherDirty = true;
            root.launcherWriteDebounce.restart();
        }
    }

    property Timer corruptRetentionDebounce: Timer {
        interval: 100
        repeat: false
        onTriggered: root.pruneCorruptCopies()
    }
}
