import QtQml
import Quickshell.Io

FileView {
    id: root

    required property var repository
    required property string sourcePath
    property bool initialize: false
    property string initializeText: ""
    property bool participates: true
    property bool wroteInitial: false

    path: sourcePath
    blockLoading: false
    blockWrites: false
    atomicWrites: true
    watchChanges: true
    printErrors: !initialize

    function tryInitialize() {
        if (root.initialize && root.path.length > 0 && !root.wroteInitial) {
            root.wroteInitial = true;
            root.setText(root.initializeText);
        }
    }

    Component.onCompleted: root.tryInitialize()
    onInitializeChanged: root.tryInitialize()
    onPathChanged: root.tryInitialize()

    onLoaded: {
        if (root.participates)
            root.repository.acceptFile(root.sourcePath, root.text());
    }
    onSaved: {
        const wasInitializing = root.initialize;
        const savedText = wasInitializing ? root.initializeText : root.text();
        if (wasInitializing)
            root.repository.initialWriteSaved(root.sourcePath);
        if (root.participates)
            root.repository.acceptFile(root.sourcePath, savedText);
    }
    onFileChanged: root.reload()
    onLoadFailed: error => {
        if (!root.initialize && root.path.length > 0)
            root.repository.fileLoadFailed(root.sourcePath, error);
    }
    onSaveFailed: error => root.repository.fileSaveFailed(root.sourcePath, error)
}
