import QtQml
import Quickshell
import Quickshell.Io
import "../../logic/WindowNavigation.js" as Navigation

QtObject {
    id: root

    required property var store
    required property var windowStore
    required property var configuration
    required property var errors
    property bool started: false
    property bool stopping: false
    property bool receivedSnapshot: false
    property var lastProtocolSnapshot: null
    property var desktopCatalog: []
    property int invalidRuleWarningGeneration: -1

    signal ready
    signal failed(string code)
    signal compositorExited

    function buildDesktopCatalog() {
        const catalog = [];
        for (let index = 0; index < DesktopEntries.applications.values.length; ++index) {
            const entry = DesktopEntries.applications.values[index];
            catalog.push({
                id: entry.id,
                name: entry.name,
                icon: entry.icon,
                startupClass: entry.startupClass
            });
        }
        root.desktopCatalog = catalog;
    }

    function normalizeOutputs(rawOutputs, focusedOutput) {
        return (rawOutputs || []).filter(output => output.active !== false).map(output => ({
                    id: output.id,
                    name: output.name,
                    x: output.rect ? output.rect.x : 0,
                    y: output.rect ? output.rect.y : 0,
                    width: output.rect ? output.rect.width : 0,
                    height: output.rect ? output.rect.height : 0,
                    scale: output.scale || 1,
                    focused: output.name === focusedOutput,
                    power: output.power !== false
                }));
    }

    function normalizeWorkspaces(rawWorkspaces) {
        return (rawWorkspaces || []).map(workspace => ({
                    id: workspace.id,
                    name: workspace.name,
                    number: Number(workspace.num === undefined ? -1 : workspace.num),
                    output: workspace.output || "",
                    focused: Boolean(workspace.focused),
                    active: Boolean(workspace.visible || workspace.focused),
                    urgent: Boolean(workspace.urgent)
                }));
    }

    function publishProtocolSnapshot(snapshot) {
        if (!root.started || root.stopping)
            return;
        root.lastProtocolSnapshot = snapshot;
        const rawWorkspaces = snapshot.workspaces || [];
        const focusedWorkspace = rawWorkspaces.find(workspace => workspace.focused);
        const focusedOutput = focusedWorkspace ? String(focusedWorkspace.output || "") : "";
        const outputs = root.normalizeOutputs(snapshot.outputs, focusedOutput);
        const workspaces = root.normalizeWorkspaces(rawWorkspaces);
        const rules = root.configuration.effective.bar.app_matching.rules;
        const validation = Navigation.validateRules(rules);
        if (validation.invalid.length > 0 && root.invalidRuleWarningGeneration !== root.configuration.generation) {
            root.invalidRuleWarningGeneration = root.configuration.generation;
            validation.invalid.forEach(index => root.errors.add({
                    code: "invalid_app_matching_rule",
                    category: "hydrogen.config",
                    severity: "warning",
                    component: "bar",
                    action: "edit_rule_" + index,
                    message: "Uma regra de identificação de aplicativos foi ignorada."
                }));
        }
        const extracted = Navigation.extractWindows(snapshot.tree || {});
        const identified = Navigation.identifyWindows(extracted, root.desktopCatalog, rules);
        root.store.publishSnapshot(outputs, workspaces, focusedOutput, Quickshell.env("SWAYSOCK") || Quickshell.env("I3SOCK") || "");
        root.windowStore.publish(identified);
        root.receivedSnapshot = true;
        if (outputs.length > 0)
            root.ready();
        else
            root.failed("sway_no_outputs");
    }

    function handleBridgeLine(line) {
        if (String(line).trim() === "")
            return;
        try {
            const envelope = JSON.parse(line);
            if (envelope.type === "snapshot") {
                root.publishProtocolSnapshot(envelope.data);
            } else if (envelope.type === "shutdown" || envelope.type === "disconnected") {
                root.store.disconnect();
                root.windowStore.disconnect();
                root.compositorExited();
            } else if (envelope.type === "error") {
                root.failed(envelope.data && envelope.data.code ? envelope.data.code : "sway_bridge_failed");
            }
        } catch (error) {
            root.failed(error ? "sway_bridge_invalid_response" : "sway_bridge_failed");
        }
    }

    function start() {
        if (root.started)
            return;
        root.started = true;
        root.stopping = false;
        root.buildDesktopCatalog();
        bridge.running = true;
    }

    function stop() {
        root.stopping = true;
        root.started = false;
        if (bridge.running)
            bridge.write(JSON.stringify({
                action: "stop"
            }) + "\n");
        bridge.running = false;
    }

    function dispatch(command) {
        if (!root.started || root.stopping || !bridge.running)
            return false;
        bridge.write(JSON.stringify({
            action: "command",
            command: String(command)
        }) + "\n");
        return true;
    }

    function refreshWindows() {
        if (bridge.running)
            bridge.write(JSON.stringify({
                action: "refresh"
            }) + "\n");
    }

    property Process bridge: Process {
        command: [Quickshell.shellPath("providers/sway/sway_ipc_bridge.py")]
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleBridgeLine(data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (String(data).trim() !== "")
                    console.warn("hydrogen.sway.bridge:", data);
            }
        }
        onExited: exitCode => {
            if (!root.stopping && root.started) {
                root.store.disconnect();
                root.windowStore.disconnect();
                if (root.receivedSnapshot)
                    root.compositorExited();
                else
                    root.failed(exitCode === 0 ? "sway_bridge_stopped" : "sway_bridge_failed");
            }
        }
    }

    property Connections configurationConnection: Connections {
        target: root.configuration
        function onPublished() {
            root.buildDesktopCatalog();
            if (root.lastProtocolSnapshot)
                root.publishProtocolSnapshot(root.lastProtocolSnapshot);
        }
    }

    property Connections desktopEntriesConnection: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.buildDesktopCatalog();
            if (root.lastProtocolSnapshot)
                root.publishProtocolSnapshot(root.lastProtocolSnapshot);
        }
    }
}
