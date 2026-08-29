import QtQml
import "../logic/Panel.js" as Panel

QtObject {
    id: root

    required property var lifecycle
    required property var overlayStore
    required property var swayStore

    function mayOpen() {
        return root.lifecycle.state === "running" || root.lifecycle.state === "degraded";
    }

    function showLauncher(requestedOutput) {
        if (!root.mayOpen())
            return {
                ok: false,
                code: "lifecycle_unavailable",
                message: "O painel não está disponível durante esta fase."
            };
        const output = Panel.outputForRequest(requestedOutput, root.swayStore.focusedOutput, root.swayStore.outputs);
        if (output === "")
            return {
                ok: false,
                code: "output_unavailable",
                message: "Nenhuma saída ativa está disponível."
            };
        root.overlayStore.show("launcher", output, {});
        return {
            ok: true,
            code: "success",
            message: "Launcher aberto.",
            output: output
        };
    }

    function toggleLauncher(requestedOutput) {
        if (root.overlayStore.panel === "launcher") {
            root.overlayStore.close();
            return {
                ok: true,
                code: "success",
                message: "Launcher fechado.",
                output: ""
            };
        }
        return root.showLauncher(requestedOutput);
    }

    function close() {
        root.overlayStore.close();
        return {
            ok: true,
            code: "success",
            message: "Painel fechado.",
            output: ""
        };
    }

    function showWindowGroup(output, workspace, groupKey) {
        if (!root.mayOpen())
            return false;
        const target = Panel.outputForRequest(output, root.swayStore.focusedOutput, root.swayStore.outputs);
        return target !== "" && root.overlayStore.show("window_group", target, {
            workspace: String(workspace),
            groupKey: String(groupKey)
        });
    }

    function showOverflow(output, workspace) {
        if (!root.mayOpen())
            return false;
        const target = Panel.outputForRequest(output, root.swayStore.focusedOutput, root.swayStore.outputs);
        return target !== "" && root.overlayStore.show("overflow", target, {
            workspace: String(workspace)
        });
    }

    function reconcileOutputs() {
        if (root.overlayStore.open && !Panel.hasOutput(root.overlayStore.output, root.swayStore.outputs))
            root.overlayStore.close();
    }
}
