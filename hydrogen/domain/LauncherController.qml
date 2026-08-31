import QtQml
import "../logic/Launcher.js" as Launcher

QtObject {
    id: root

    required property var lifecycle
    required property var configuration
    required property var launcherStore
    required property var provider
    required property var launcherBackend
    required property var overlayCoordinator
    required property var foundationController
    required property var persistence
    required property var errors
    required property var logger
    property var pendingCommand: null

    function internalActions() {
        return [
            { id: "reload_config", name: "Recarregar configuração", description: "Recarrega os arquivos TOML", keywords: "reload config", icon: "view-refresh", available: true },
            { id: "toggle_dnd", name: root.persistence.doNotDisturb ? "Desativar não perturbe" : "Ativar não perturbe", description: "Alterna o modo não perturbe", keywords: "dnd notificações", icon: "notifications-disabled", available: true },
            { id: "clear_history", name: "Limpar histórico do launcher", description: "Remove aplicativos, arquivos e comandos usados", keywords: "clear history", icon: "edit-clear-history", available: true },
            { id: "logout", name: "Sair do Sway", description: "Requer confirmação no menu de sessão", keywords: "logout sessão", icon: "system-log-out", available: false },
            { id: "reboot", name: "Reiniciar", description: "Requer confirmação no menu de sessão", keywords: "restart reboot", icon: "system-reboot", available: false },
            { id: "poweroff", name: "Desligar", description: "Requer confirmação no menu de sessão", keywords: "shutdown poweroff", icon: "system-shutdown", available: false }
        ];
    }

    function refreshActions() {
        root.launcherStore.publishActions(root.internalActions());
    }

    function setQuery(query) {
        const value = String(query || "");
        root.launcherStore.query = value;
        root.launcherStore.clearFailure();
        const mode = Launcher.parseCommandMode(value);
        if (!mode.active && value.trim().length >= 3) {
            const requestId = root.launcherStore.beginFileSearch();
            root.launcherBackend.searchFiles(value.trim(), requestId, root.launcherStore.resultLimit);
        } else {
            const requestId = root.launcherStore.cancelFileSearch();
            root.launcherBackend.cancelFileSearch(requestId);
        }
    }

    function activate(result) {
        if (root.lifecycle.state !== "running" && root.lifecycle.state !== "degraded")
            return false;
        root.launcherStore.clearFailure();
        if (!result)
            return false;
        if (result.kind === "application")
            return root.launchApplication(result);
        if (result.kind === "file")
            return root.openFile(result);
        if (result.kind === "command")
            return root.runCommand(result);
        if (result.kind === "action")
            return root.runAction(result);
        return false;
    }

    function launch(application) {
        return root.launchApplication(application);
    }

    function launchApplication(application) {
        if (!application.executable) {
            root.fail("desktop_entry_inexecutable", "launch_application");
            return false;
        }
        root.launcherStore.launching = true;
        if (!root.provider.launch(application, root.configuration.effective.terminal.command)) {
            root.launcherStore.launching = false;
            root.fail("desktop_entry_busy", "launch_application");
            return false;
        }
        return true;
    }

    function openFile(file) {
        if (!root.launcherBackend.openFile(file.url)) {
            root.fail("file_open_failed", "open_file");
            return false;
        }
        root.launcherStore.recordResult(file, new Date().toISOString());
        root.pruneHistory();
        root.overlayCoordinator.close();
        return true;
    }

    function runCommand(command) {
        root.launcherStore.launching = true;
        root.pendingCommand = {
            kind: "command",
            commandLine: String(command.commandLine),
            terminal: Boolean(command.terminal),
            private: Boolean(command.private)
        };
        if (!root.launcherBackend.runCommand(command.commandLine, command.terminal, root.configuration.effective.terminal.command)) {
            root.pendingCommand = null;
            root.launcherStore.launching = false;
            root.fail("command_busy", "run_command");
            return false;
        }
        return true;
    }

    function runAction(action) {
        if (!action.available) {
            root.fail("session_confirmation_unavailable", "run_internal_action");
            return false;
        }
        if (action.actionId === "reload_config") {
            const result = root.foundationController.requestConfigReload();
            if (!result.ok) {
                root.fail(result.code, "reload_config");
                return false;
            }
        } else if (action.actionId === "toggle_dnd") {
            root.persistence.setDoNotDisturb(!root.persistence.doNotDisturb);
            root.refreshActions();
        } else if (action.actionId === "clear_history") {
            root.launcherStore.clearHistory();
        } else {
            root.fail("internal_action_unavailable", "run_internal_action");
            return false;
        }
        root.overlayCoordinator.close();
        return true;
    }

    function applicationAccepted(desktopEntry) {
        root.launcherStore.launching = false;
        root.launcherStore.recordResult({ kind: "application", id: desktopEntry }, new Date().toISOString());
        root.pruneHistory();
        root.overlayCoordinator.close();
    }

    function commandAccepted() {
        root.launcherStore.launching = false;
        if (root.pendingCommand)
            root.launcherStore.recordResult(root.pendingCommand, new Date().toISOString());
        root.pruneHistory();
        root.pendingCommand = null;
        root.overlayCoordinator.close();
    }

    function fail(code, operation) {
        root.launcherStore.launching = false;
        root.launcherStore.failureCode = String(code);
        if (code === "terminal_unavailable")
            root.launcherStore.failureMessage = "Nenhum terminal compatível está disponível; configure terminal.command.";
        else if (code === "desktop_entry_inexecutable" || code === "executable_unavailable")
            root.launcherStore.failureMessage = "O executável solicitado não está disponível.";
        else if (code === "file_search_failed" || code === "fd_unavailable")
            root.launcherStore.failureMessage = "A pesquisa de arquivos não está disponível; verifique a instalação do fd.";
        else if (code === "file_open_failed")
            root.launcherStore.failureMessage = "O manipulador padrão não aceitou a abertura do arquivo.";
        else if (code === "command_invalid")
            root.launcherStore.failureMessage = "O comando possui aspas ou argumentos inválidos.";
        else if (code === "session_confirmation_unavailable")
            root.launcherStore.failureMessage = "Esta ação será habilitada junto ao menu de sessão com confirmação.";
        else
            root.launcherStore.failureMessage = "Não foi possível concluir a ação solicitada.";
        const error = {
            code: String(code),
            category: "hydrogen.launcher",
            severity: "warning",
            component: "launcher",
            action: code === "terminal_unavailable" ? "configure_terminal" : code === "fd_unavailable" ? "install_fd" : "inspect_launcher_action",
            message: root.launcherStore.failureMessage
        };
        root.errors.add(error);
        root.logger.emit("warning", error.category, error.code, error.message, {
            component: "launcher",
            operation: String(operation || "activate")
        });
    }

    function validateHistoryFiles() {
        root.launcherStore.fileValidationReady = false;
        root.launcherBackend.validateFiles(root.launcherStore.history.filter(item => item.kind === "file").map(item => item.path));
    }

    function pruneHistory() {
        root.launcherStore.pruneHistory(Date.now(), root.configuration.effective.launcher.history_limit, root.configuration.effective.launcher.history_days);
    }

    Component.onCompleted: root.refreshActions()

    property Connections providerConnections: Connections {
        target: root.provider
        function onLaunchAccepted(desktopEntry) {
            root.applicationAccepted(desktopEntry);
        }
        function onLaunchFailed(desktopEntry, code) {
            root.fail(code, "launch_application");
        }
    }

    property Connections backendConnections: Connections {
        target: root.launcherBackend
        function onFileSearchCompleted(requestId, files) {
            root.launcherStore.publishFileResults(requestId, files);
        }
        function onFileSearchFailed(requestId, code) {
            if (root.launcherStore.publishFileResults(requestId, []))
                root.fail(code, "search_files");
        }
        function onFileValidationCompleted(paths) {
            root.launcherStore.publishValidFilePaths(paths);
            root.pruneHistory();
        }
        function onExecutablesReady(executables) {
            root.launcherStore.publishExecutables(executables);
        }
        function onCommandAccepted() {
            root.commandAccepted();
        }
        function onCommandFailed(code) {
            root.pendingCommand = null;
            root.fail(code, "run_command");
        }
    }

    property Connections storeConnections: Connections {
        target: root.launcherStore
        function onApplicationsChanged() {
            root.pruneHistory();
        }
        function onHistoryRestored() {
            root.validateHistoryFiles();
        }
    }

    property Connections configurationConnections: Connections {
        target: root.configuration
        function onPublished() {
            root.pruneHistory();
        }
    }

    property Connections persistenceConnections: Connections {
        target: root.persistence
        function onDoNotDisturbChanged() {
            root.refreshActions();
        }
    }
}
