import QtQml

QtObject {
    id: root

    property string providerState: "initializing"
    property bool initialSynchronized: false
    property var outputs: []
    property var workspaces: []
    property string focusedOutput: ""
    property string socketPath: ""
    property int snapshotGeneration: 0

    signal snapshotPublished(int generation)

    function publishSnapshot(nextOutputs, nextWorkspaces, nextFocusedOutput, nextSocketPath) {
        root.outputs = nextOutputs;
        root.workspaces = nextWorkspaces;
        root.focusedOutput = nextFocusedOutput || "";
        root.socketPath = nextSocketPath || "";
        root.initialSynchronized = true;
        root.providerState = nextOutputs.length > 0 ? "ready" : "degraded";
        root.snapshotGeneration += 1;
        root.snapshotPublished(root.snapshotGeneration);
    }

    function disconnect() {
        root.providerState = "failed";
        root.initialSynchronized = false;
    }
}
