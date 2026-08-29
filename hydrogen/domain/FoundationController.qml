import QtQml

QtObject {
    id: root

    required property var lifecycle
    required property var configuration
    required property var configurationRepository
    required property var persistence
    required property var swayStore
    required property var swayProvider
    required property var capabilities
    required property var errors
    required property var events

    signal surfacesRequested
    signal coordinatedShutdownRequested(string reason)
    signal quitRequested

    function start() {
        if (!root.lifecycle.transition("loading_configuration"))
            return false;
        root.configurationRepository.start();
        return true;
    }

    function configurationLoaded(valid) {
        root.capabilities.setCapability("configuration", valid);
        if (!valid) {
            root.lifecycle.transition("failed");
            return;
        }
        root.lifecycle.configurationGeneration = root.configuration.generation;
        root.lifecycle.transition("starting_core");
        root.persistence.start();
    }

    function persistenceRestored() {
        root.capabilities.setCapability("persistence", root.persistence.state === "ready");
        root.lifecycle.transition("starting_providers");
        root.swayProvider.start();
    }

    function swayReady() {
        root.capabilities.setCapability("sway", true);
        if (root.lifecycle.state === "starting_providers") {
            root.lifecycle.transition("creating_surfaces");
            root.surfacesRequested();
        }
    }

    function swayFailed(code) {
        root.errors.add({
            code: code,
            category: "hydrogen.sway",
            severity: "fatal",
            component: "sway",
            action: "start_sway_session",
            message: "Não foi possível sincronizar a sessão Sway."
        });
        root.lifecycle.transition("failed");
    }

    function surfaceCreated() {
        if (root.lifecycle.state === "creating_surfaces")
            root.lifecycle.transition(root.swayStore.providerState === "ready" ? "running" : "degraded");
    }

    function requestConfigReload() {
        if (!root.lifecycle.mayMutate("reload_config"))
            return {
                ok: false,
                code: "busy",
                message: "O Hydrogen está encerrando."
            };
        if (root.configurationRepository.loading)
            return {
                ok: false,
                code: "busy",
                message: "Já existe uma recarga em andamento."
            };
        if (!root.lifecycle.transition("reloading"))
            return {
                ok: false,
                code: "busy",
                message: "A configuração não pode ser recarregada agora."
            };
        root.configurationRepository.start();
        return {
            ok: true,
            code: "success",
            message: "Recarga solicitada.",
            generation: root.lifecycle.configurationGeneration
        };
    }

    function configurationReloaded(changed, previousGeneration, currentGeneration) {
        root.lifecycle.configurationGeneration = currentGeneration;
        if (root.lifecycle.state === "reloading")
            root.lifecycle.transition(root.swayStore.providerState === "ready" ? "running" : "degraded");
        if (changed)
            root.events.configurationAccepted(previousGeneration, currentGeneration);
        else if (previousGeneration === currentGeneration)
            root.events.configurationRejected("configuration_unchanged_or_invalid");
    }

    function requestShutdown(reason) {
        if (!root.lifecycle.beginShutdown(reason))
            return false;
        root.events.shutdownStarted(reason);
        root.coordinatedShutdownRequested(reason);
        return true;
    }

    function finishShutdown() {
        if (root.lifecycle.state !== "shutting_down")
            return false;
        const reason = root.lifecycle.shutdownReason;
        root.lifecycle.transition("stopped");
        root.events.shutdownFinished(reason);
        root.quitRequested();
        return true;
    }
}
