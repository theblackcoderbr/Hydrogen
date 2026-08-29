import QtQml

QtObject {
    id: root
    required property var store
    property string nextState: "ready"
    property int startCalls: 0
    property int stopCalls: 0
    property var initialOutputs: [
        {
            name: "HEADLESS-1",
            width: 1920,
            height: 1080,
            scale: 1,
            focused: true
        }
    ]
    property var initialWorkspaces: [
        {
            id: 1,
            name: "1",
            number: 1,
            output: "HEADLESS-1",
            focused: true,
            active: true,
            urgent: false
        }
    ]

    signal ready
    signal failed(string code)
    signal compositorExited

    function start() {
        root.startCalls += 1;
        if (root.nextState === "ready") {
            root.store.publishSnapshot(root.initialOutputs, root.initialWorkspaces, root.initialOutputs[0].name, "fake-sway-ipc.sock");
            root.ready();
        } else if (root.nextState === "unavailable") {
            root.store.providerState = "unavailable";
            root.failed("sway_unavailable");
        } else {
            root.store.providerState = "failed";
            root.failed("sway_backend_failure");
        }
    }

    function stop() {
        root.stopCalls += 1;
    }
    function disconnect() {
        root.store.disconnect();
        root.compositorExited();
    }
}
