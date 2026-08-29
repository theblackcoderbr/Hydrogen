import QtQml
import Quickshell.Io
import "../logic/Foundation.js" as Foundation

QtObject {
    id: root

    required property var lifecycle
    required property var foundationController
    required property var diagnosticsProvider
    required property var capabilityStore
    required property var overlayCoordinator

    property IpcHandler handler: IpcHandler {
        target: "hydrogen.v1"
        enabled: root.lifecycle.state === "running" || root.lifecycle.state === "degraded"

        function version(): string {
            return Foundation.response(true, "success", "Versões do Hydrogen.", {
                hydrogen: root.diagnosticsProvider.hydrogenVersion,
                ipc: "1",
                quickshell: root.diagnosticsProvider.quickshellVersion
            });
        }

        function status(): string {
            return Foundation.response(true, "success", "Estado atual do Hydrogen.", root.diagnosticsProvider.status());
        }

        function diagnostics(): string {
            return Foundation.response(true, "success", "Diagnóstico sanitizado do Hydrogen.", root.diagnosticsProvider.diagnostics());
        }

        function capabilities(): string {
            return Foundation.response(true, "success", "Capacidades disponíveis.", {
                capabilities: root.capabilityStore.names()
            });
        }

        function reload(scope: string): string {
            if (scope !== "config")
                return Foundation.response(false, "invalid_arguments", "Use: reload config.", {});
            const result = root.foundationController.requestConfigReload();
            return Foundation.response(result.ok, result.code, result.message, {
                configuration_generation: result.generation === undefined ? root.lifecycle.configurationGeneration : result.generation
            });
        }

        function panel(action: string): string {
            let result;
            if (action === "show" || action === "open")
                result = root.overlayCoordinator.showLauncher("");
            else if (action === "toggle")
                result = root.overlayCoordinator.toggleLauncher("");
            else if (action === "hide" || action === "close")
                result = root.overlayCoordinator.close();
            else
                return Foundation.response(false, "invalid_arguments", "Use: panel open|close|toggle. Somente o launcher estrutural está disponível neste marco.", {});
            return Foundation.response(result.ok, result.code, result.message, { output: result.output || null });
        }
    }
}
