import QtQml
import "../logic/Foundation.js" as Foundation

QtObject {
    id: root

    required property var lifecycle
    required property var configuration
    required property var sway
    required property var windowStore
    required property var errors
    required property var capabilities
    required property var persistence
    required property var logger
    property int surfaceCount: 0
    property int overlaySurfaceCount: 0
    property var overlayStore: null
    property string hydrogenVersion: "0.1.0-dev"
    property string quickshellVersion: "0.3.1"

    function context() {
        const groupSizes = {};
        let unresolvedWindowCount = 0;
        let xwaylandWindowCount = 0;
        let urgentWindowCount = 0;
        root.windowStore.windows.forEach(window => {
            const group = window.output + "|" + window.workspace + "|" + window.identity.key;
            groupSizes[group] = Number(groupSizes[group] || 0) + 1;
            if (!window.identity.confident)
                unresolvedWindowCount += 1;
            if (window.xwayland)
                xwaylandWindowCount += 1;
            if (window.urgent)
                urgentWindowCount += 1;
        });
        const sizes = Object.keys(groupSizes).map(key => groupSizes[key]);
        return {
            lifecycle: root.lifecycle.state,
            configurationGeneration: root.configuration.generation,
            reloading: root.lifecycle.reloadInProgress,
            focusedOutput: root.sway.focusedOutput,
            surfaceCount: root.surfaceCount,
            overlaySurfaceCount: root.overlaySurfaceCount,
            panel: root.overlayStore && root.overlayStore.open ? root.overlayStore.panel : "",
            panelOutput: root.overlayStore && root.overlayStore.open ? root.overlayStore.output : "",
            providers: [
                {
                    name: "sway",
                    state: root.sway.providerState,
                    essential: true,
                    synchronized: root.sway.initialSynchronized
                }
            ],
            errors: root.errors.entries,
            versions: {
                hydrogen: root.hydrogenVersion,
                ipc: "1",
                quickshell: root.quickshellVersion
            },
            uptimeMs: Date.now() - root.lifecycle.startedAtMs,
            outputs: root.sway.outputs,
            windowCount: root.windowStore.windows.length,
            windowGeneration: root.windowStore.generation,
            groupCount: sizes.length,
            largestGroupSize: sizes.length > 0 ? Math.max.apply(Math, sizes) : 0,
            unresolvedWindowCount: unresolvedWindowCount,
            xwaylandWindowCount: xwaylandWindowCount,
            urgentWindowCount: urgentWindowCount,
            persistence: {
                state: root.persistence.state,
                pending_writes: root.persistence.pendingWrites
            },
            suppressedLogCount: root.logger.suppressedCount
        };
    }

    function status() {
        return Foundation.statusSnapshot(root.context());
    }
    function diagnostics() {
        return Foundation.diagnosticsSnapshot(root.context());
    }
}
