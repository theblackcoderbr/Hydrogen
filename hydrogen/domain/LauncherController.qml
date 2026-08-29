import QtQml

QtObject {
    id: root

    required property var lifecycle
    required property var configuration
    required property var launcherStore
    required property var provider
    required property var overlayCoordinator
    required property var errors
    required property var logger

    function setQuery(query) {
        root.launcherStore.query = String(query || "");
        root.launcherStore.clearFailure();
    }

    function launch(application) {
        if (root.lifecycle.state !== "running" && root.lifecycle.state !== "degraded")
            return false;
        root.launcherStore.clearFailure();
        if (!application || !application.executable) {
            root.fail(application ? application.id : "", "desktop_entry_inexecutable");
            return false;
        }
        root.launcherStore.launching = true;
        if (!root.provider.launch(application, root.configuration.effective.terminal.command)) {
            root.launcherStore.launching = false;
            root.fail(application.id, "desktop_entry_busy");
            return false;
        }
        return true;
    }

    function accepted(desktopEntry) {
        root.launcherStore.launching = false;
        root.launcherStore.recordUse(desktopEntry, new Date().toISOString());
        root.overlayCoordinator.close();
    }

    function fail(desktopEntry, code) {
        root.launcherStore.launching = false;
        root.launcherStore.failureCode = String(code);
        root.launcherStore.failureMessage = code === "terminal_unavailable" ? "Nenhum terminal compatível está disponível; configure terminal.command." : code === "desktop_entry_inexecutable" || code === "executable_unavailable" ? "O aplicativo não possui um executável disponível." : "Não foi possível iniciar o aplicativo. Tente novamente ou revise a entrada desktop.";
        const error = {
            code: String(code),
            category: "hydrogen.launcher",
            severity: "warning",
            component: "launcher",
            action: code === "terminal_unavailable" ? "configure_terminal" : "inspect_desktop_entry",
            message: root.launcherStore.failureMessage
        };
        root.errors.add(error);
        root.logger.emit("warning", error.category, error.code, error.message, {
            component: "launcher",
            operation: "launch_application"
        });
    }

    function pruneHistory() {
        if (root.launcherStore.applications.length === 0)
            return false;
        root.launcherStore.pruneHistory(Date.now(), root.configuration.effective.launcher.history_limit, root.configuration.effective.launcher.history_days);
        return true;
    }

    property Connections providerConnections: Connections {
        target: root.provider
        function onLaunchAccepted(desktopEntry) {
            root.accepted(desktopEntry);
        }
        function onLaunchFailed(desktopEntry, code) {
            root.fail(desktopEntry, code);
        }
    }

    property Connections storeConnections: Connections {
        target: root.launcherStore
        function onApplicationsChanged() {
            root.pruneHistory();
        }
        function onHistoryRestored() {
            root.pruneHistory();
        }
    }

    property Connections configurationConnections: Connections {
        target: root.configuration
        function onPublished() {
            root.pruneHistory();
        }
    }
}
