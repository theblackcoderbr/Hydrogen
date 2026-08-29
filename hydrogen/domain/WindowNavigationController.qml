import QtQml

QtObject {
    id: root

    required property var lifecycle
    required property var swayProvider

    function mayMutate() {
        return root.lifecycle.state === "running" || root.lifecycle.state === "degraded";
    }

    function focusWindow(containerId) {
        const id = Number(containerId);
        return root.mayMutate() && Number.isInteger(id) && id > 0 && root.swayProvider.dispatch("[con_id=" + id + "] focus");
    }

    function closeWindow(containerId) {
        const id = Number(containerId);
        return root.mayMutate() && Number.isInteger(id) && id > 0 && root.swayProvider.dispatch("[con_id=" + id + "] kill");
    }

    function focusWorkspace(number) {
        const workspace = Number(number);
        return root.mayMutate() && Number.isInteger(workspace) && workspace >= 0 && root.swayProvider.dispatch("workspace number " + workspace);
    }

    function moveFocusedToWorkspace(number, currentNumber) {
        const workspace = Number(number);
        if (workspace === Number(currentNumber))
            return true;
        return root.mayMutate() && Number.isInteger(workspace) && workspace >= 0 && root.swayProvider.dispatch("move container to workspace number " + workspace);
    }
}
