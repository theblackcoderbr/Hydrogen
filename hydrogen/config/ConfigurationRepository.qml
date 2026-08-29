import QtQml
import QtQml.Models
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../logic/Toml.js" as Toml
import "../logic/Foundation.js" as Foundation
import "Defaults.js" as Defaults

QtObject {
    id: root

    required property var store
    required property var errors
    property string configRoot: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        return (xdg && xdg.length > 0 ? xdg : home + "/.config") + "/hydrogen";
    }
    property bool firstExecution: false
    property bool directoriesReady: false
    property bool loading: false
    property var parsedByPath: ({})
    property var syntaxErrorsByPath: ({})
    property var knownComponentPaths: []
    property int pendingInitialWrites: 0
    property var initialWrittenPaths: ({})

    signal initialLoadFinished(bool valid)
    signal reloadFinished(bool changed, int previousGeneration, int currentGeneration)

    function start() {
        root.loading = true;
        probe.exec(["test", "-d", root.configRoot]);
    }

    function prepareReaders() {
        const wasReady = root.directoriesReady;
        root.directoriesReady = true;
        componentFolder.folder = "file://" + root.configRoot + "/components";
        if (root.firstExecution)
            root.pendingInitialWrites = Object.keys(Defaults.templates()).length + 1;
        if (wasReady && !root.firstExecution) {
            root.mainReader.reload();
            for (let i = 0; i < root.componentReaders.count; ++i) {
                const reader = root.componentReaders.objectAt(i);
                if (reader)
                    reader.reload();
            }
        }
        reloadDebounce.restart();
    }

    function acceptFile(path, text) {
        const parsed = Toml.parse(text);
        if (!parsed.ok) {
            const errors = Object.assign({}, root.syntaxErrorsByPath);
            errors[path] = {
                code: parsed.code,
                line: parsed.line
            };
            root.syntaxErrorsByPath = errors;
            root.store.reject(parsed.code, path, parsed.line);
            root.errors.add({
                code: "configuration_invalid",
                category: "hydrogen.config",
                severity: "warning",
                component: "configuration",
                action: "edit_configuration",
                message: "A configuração contém sintaxe inválida."
            });
            reloadDebounce.restart();
            return;
        }
        const parsedFiles = Object.assign({}, root.parsedByPath);
        parsedFiles[path] = parsed.data;
        root.parsedByPath = parsedFiles;
        const syntaxErrors = Object.assign({}, root.syntaxErrorsByPath);
        delete syntaxErrors[path];
        root.syntaxErrorsByPath = syntaxErrors;
        if (Object.keys(syntaxErrors).length === 0) {
            root.errors.recover({
                code: "configuration_invalid",
                category: "hydrogen.config",
                component: "configuration",
                action: "edit_configuration"
            });
        }
        reloadDebounce.restart();
    }

    function initialWriteSaved(path) {
        if (!root.firstExecution || root.initialWrittenPaths[path])
            return;
        const written = Object.assign({}, root.initialWrittenPaths);
        written[path] = true;
        root.initialWrittenPaths = written;
        if (Object.keys(written).length >= root.pendingInitialWrites)
            root.firstExecution = false;
    }

    function fileRemoved(path) {
        const parsedFiles = Object.assign({}, root.parsedByPath);
        delete parsedFiles[path];
        root.parsedByPath = parsedFiles;
        const syntaxErrors = Object.assign({}, root.syntaxErrorsByPath);
        delete syntaxErrors[path];
        root.syntaxErrorsByPath = syntaxErrors;
        reloadDebounce.restart();
    }

    function fileLoadFailed(path, error) {
        root.errors.add({
            code: "configuration_read_failed",
            category: "hydrogen.config",
            severity: "error",
            component: "configuration",
            action: "check_permissions",
            message: "Não foi possível ler um arquivo de configuração."
        });
    }

    function fileSaveFailed(path, error) {
        root.errors.add({
            code: "configuration_write_failed",
            category: "hydrogen.config",
            severity: "error",
            component: "configuration",
            action: "check_permissions",
            message: "Não foi possível criar a configuração inicial."
        });
    }

    function mergeObjects(target, source) {
        Object.keys(source).forEach(key => {
            const value = source[key];
            if (value !== null && typeof value === "object" && !Array.isArray(value)) {
                if (target[key] === undefined)
                    target[key] = {};
                root.mergeObjects(target[key], value);
            } else {
                target[key] = value;
            }
        });
    }

    function changedNamespaces(previous, current) {
        const names = [];
        Object.keys(current).forEach(name => {
            if (JSON.stringify(previous[name]) !== JSON.stringify(current[name]))
                names.push(name);
        });
        return names;
    }

    function commitCandidate() {
        if (Object.keys(root.syntaxErrorsByPath).length > 0) {
            if (root.store.generation > 0) {
                root.loading = false;
                root.reloadFinished(false, root.store.generation, root.store.generation);
                return;
            }
            // First start is allowed to combine valid files with internal defaults.
            // Later reloads remain all-or-nothing and preserve this generation.
        }
        const merged = {};
        const mainPath = root.configRoot + "/config.toml";
        if (root.parsedByPath[mainPath])
            root.mergeObjects(merged, root.parsedByPath[mainPath]);
        Object.keys(root.parsedByPath).sort().forEach(path => {
            if (path !== mainPath)
                root.mergeObjects(merged, root.parsedByPath[path]);
        });
        const validation = Foundation.validateConfiguration(merged, Defaults.configuration());
        const previousGeneration = root.store.generation;
        const previous = root.store.effective;
        if (Foundation.deepEqual(previous, validation.effective) && previousGeneration > 0) {
            root.loading = false;
            root.reloadFinished(false, previousGeneration, previousGeneration);
            return;
        }
        const changed = root.changedNamespaces(previous, validation.effective);
        root.store.publish(validation.effective, validation.warnings, changed);
        root.loading = false;
        if (previousGeneration === 0)
            root.initialLoadFinished(true);
        root.reloadFinished(true, previousGeneration, root.store.generation);
    }

    property Process probe: Process {
        onExited: exitCode => {
            root.firstExecution = exitCode !== 0;
            if (root.firstExecution)
                mkdir.exec(["mkdir", "-p", root.configRoot + "/components"]);
            else
                root.prepareReaders();
        }
    }

    property Process mkdir: Process {
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.fileSaveFailed(root.configRoot, exitCode);
                root.initialLoadFinished(false);
                return;
            }
            root.prepareReaders();
        }
    }

    property FolderListModel componentFolder: FolderListModel {
        nameFilters: ["*.toml"]
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Name
        onCountChanged: {
            const paths = [];
            for (let i = 0; i < count; ++i)
                paths.push(get(i, "filePath"));
            root.knownComponentPaths.filter(path => paths.indexOf(path) < 0).forEach(root.fileRemoved);
            root.knownComponentPaths = paths;
            reloadDebounce.restart();
        }
    }

    property Instantiator componentReaders: Instantiator {
        active: root.directoriesReady && !root.firstExecution
        model: componentFolder
        delegate: ConfigFileReader {
            required property string filePath
            repository: root
            sourcePath: filePath
        }
    }

    property ConfigFileReader mainReader: ConfigFileReader {
        repository: root
        sourcePath: root.directoriesReady ? root.configRoot + "/config.toml" : ""
        initialize: root.firstExecution
        initializeText: Defaults.templates()["config.toml"]
    }

    property Instantiator initialComponentWriters: Instantiator {
        active: root.directoriesReady && root.firstExecution
        model: Object.keys(Defaults.templates()).filter(path => path.indexOf("components/") === 0)
        delegate: ConfigFileReader {
            required property string modelData
            repository: root
            sourcePath: root.configRoot + "/" + modelData
            initialize: true
            initializeText: Defaults.templates()[modelData]
        }
    }

    property ConfigFileReader exampleWriter: ConfigFileReader {
        repository: root
        sourcePath: root.directoriesReady ? root.configRoot + "/config.example.toml" : ""
        initialize: root.firstExecution
        initializeText: Defaults.example()
        participates: false
    }

    property Timer reloadDebounce: Timer {
        interval: 250
        repeat: false
        onTriggered: root.commitCandidate()
    }
}
