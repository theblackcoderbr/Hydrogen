import QtQml
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../logic/Foundation.js" as Foundation

QtObject {
    id: root

    required property var errors
    property string stateRoot: Quickshell.stateDir
    property int schemaVersion: 1
    property string state: "initializing"
    property bool doNotDisturb: false
    property bool dirty: false
    property bool writePending: false
    property bool persistenceSuspended: false
    property string lastWriteAt: ""
    property int pendingWrites: writePending ? 1 : 0
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
            root.restored();
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
            root.restored();
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

    function flushNow() {
        writeDebounce.stop();
        if (root.persistenceSuspended) {
            root.flushed(false);
            return;
        }
        if (!root.dirty) {
            root.flushed(true);
            return;
        }
        root.writePending = true;
        stateFile.setText(Foundation.serializeState({
            do_not_disturb: root.doNotDisturb
        }, new Date().toISOString()));
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
                root.restored();
                return;
            }
            root.permissions.exec(["chmod", "0700", root.stateRoot]);
        }
    }

    property Process permissions: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.restored();
                return;
            }
            root.touchFiles.exec(["touch", root.stateRoot + "/state.json", root.stateRoot + "/launcher-history.json", root.stateRoot + "/notification-history.json"]);
        }
    }

    property Process touchFiles: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.restored();
                return;
            }
            root.initialFilePermissions.exec(["chmod", "0600", root.stateRoot + "/state.json", root.stateRoot + "/launcher-history.json", root.stateRoot + "/notification-history.json"]);
        }
    }

    property Process initialFilePermissions: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.state = "failed";
                root.restored();
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
                root.restored();
                return;
            }
            root.corruptRetentionDebounce.restart();
            root.flushNow();
            root.restored();
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
            root.restored();
        }
        onSaved: {
            root.dirty = false;
            root.writePending = false;
            root.lastWriteAt = new Date().toISOString();
            root.statePermissions.command = ["chmod", "0600", root.stateRoot + "/state.json"];
            root.statePermissions.running = true;
            root.flushed(true);
        }
        onSaveFailed: error => {
            root.writePending = false;
            root.state = "degraded";
            root.errors.add({
                code: "state_write_failed",
                category: "hydrogen.persistence",
                severity: "error",
                component: "state",
                action: "check_permissions",
                message: "Não foi possível gravar o estado; a memória foi preservada."
            });
            root.flushed(false);
        }
    }

    property FileView launcherFile: FileView {
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
            root.launcherPermissions.command = ["chmod", "0600", root.stateRoot + "/launcher-history.json"];
            root.launcherPermissions.running = true;
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

    property Timer corruptRetentionDebounce: Timer {
        interval: 100
        repeat: false
        onTriggered: root.pruneCorruptCopies()
    }
}
