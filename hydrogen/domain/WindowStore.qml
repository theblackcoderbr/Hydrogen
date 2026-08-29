import QtQml
import "../logic/WindowNavigation.js" as Navigation

QtObject {
    id: root

    property string providerState: "initializing"
    property var windows: []
    property var orderByWorkspace: ({})
    property int generation: 0

    signal published(int generation)

    function publish(nextWindows) {
        const activeKeys = {};
        const nextOrder = JSON.parse(JSON.stringify(root.orderByWorkspace));
        (nextWindows || []).forEach(window => {
            const location = window.output + "|" + window.workspace;
            const groupKey = window.identity.key;
            if (!activeKeys[location])
                activeKeys[location] = {};
            activeKeys[location][groupKey] = true;
            if (!nextOrder[location])
                nextOrder[location] = [];
            if (nextOrder[location].indexOf(groupKey) < 0)
                nextOrder[location].push(groupKey);
        });
        Object.keys(nextOrder).forEach(location => {
            nextOrder[location] = nextOrder[location].filter(key => activeKeys[location] && activeKeys[location][key]);
            if (nextOrder[location].length === 0)
                delete nextOrder[location];
        });
        root.windows = nextWindows || [];
        root.orderByWorkspace = nextOrder;
        root.providerState = "ready";
        root.generation += 1;
        root.published(root.generation);
    }

    function groups(output, workspaceName) {
        const location = output + "|" + workspaceName;
        return Navigation.groupWindows(root.windows, output, workspaceName, root.orderByWorkspace[location] || []);
    }

    function windowsForGroup(output, workspaceName, groupKey) {
        return root.windows.filter(window => window.output === output && window.workspace === workspaceName && window.identity.key === groupKey);
    }

    function disconnect() {
        root.providerState = "failed";
    }
}
