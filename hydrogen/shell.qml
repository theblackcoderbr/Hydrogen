//@ pragma ShellId hydrogen
//@ pragma StateDir $BASE/hydrogen

pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import "core" as Core
import "domain" as Domain
import "config" as Config
import "persistence" as Persistence
import "providers/sway" as Sway
import "features/panel" as Panel
import "diagnostics" as Diagnostics
import "ipc" as Ipc

ShellRoot {
    id: root

    property int surfaceCount: 0
    property int overlaySurfaceCount: 0
    property bool shutdownFlushRequested: false
    property bool surfacesEnabled: false

    Core.Clock {
        id: clock
    }
    Core.EventBus {
        id: events
    }
    Core.LifecycleManager {
        id: lifecycle
    }
    Core.ErrorRegistry {
        id: errors
    }
    Domain.ConfigurationStore {
        id: configuration
    }
    Domain.SwayStore {
        id: swayStore
    }
    Domain.WindowStore {
        id: windowStore
    }
    Domain.CapabilitiesStore {
        id: capabilities
    }
    Domain.OverlayStore {
        id: overlayStore
    }
    Domain.OverlayCoordinator {
        id: overlayCoordinator
        lifecycle: lifecycle
        overlayStore: overlayStore
        swayStore: swayStore
    }
    Domain.WindowNavigationController {
        id: windowController
        lifecycle: lifecycle
        swayProvider: swayProvider
    }

    Diagnostics.Logger {
        id: logger
        clock: clock
    }

    Persistence.StateRepository {
        id: persistence
        errors: errors
        onRestored: foundationController.persistenceRestored()
        onFlushed: success => {
            if (root.shutdownFlushRequested)
                root.finishShutdown();
        }
    }

    Config.ConfigurationRepository {
        id: configurationRepository
        store: configuration
        errors: errors
        onInitialLoadFinished: valid => foundationController.configurationLoaded(valid)
        onReloadFinished: (changed, previousGeneration, currentGeneration) => foundationController.configurationReloaded(changed, previousGeneration, currentGeneration)
    }

    Sway.SwayProvider {
        id: swayProvider
        store: swayStore
        windowStore: windowStore
        configuration: configuration
        errors: errors
        onReady: foundationController.swayReady()
        onFailed: code => foundationController.swayFailed(code)
        onCompositorExited: foundationController.requestShutdown("compositor_exit")
    }

    Domain.FoundationController {
        id: foundationController
        lifecycle: lifecycle
        configuration: configuration
        configurationRepository: configurationRepository
        persistence: persistence
        swayStore: swayStore
        swayProvider: swayProvider
        capabilities: capabilities
        errors: errors
        events: events
        onSurfacesRequested: root.surfacesEnabled = true
        onCoordinatedShutdownRequested: {
            root.surfacesEnabled = false;
            swayProvider.stop();
            root.shutdownFlushRequested = true;
            shutdownTimeout.start();
            persistence.flushNow();
        }
        onQuitRequested: Qt.quit()
    }

    Core.AppContext {
        id: context
        lifecycle: lifecycle
        errors: errors
        configuration: configuration
        sway: swayStore
        windows: windowStore
        capabilities: capabilities
        persistence: persistence
    }

    Diagnostics.DiagnosticSnapshot {
        id: diagnosticSnapshot
        lifecycle: lifecycle
        configuration: configuration
        sway: swayStore
        windowStore: windowStore
        errors: errors
        capabilities: capabilities
        persistence: persistence
        logger: logger
        surfaceCount: root.surfaceCount
        overlaySurfaceCount: root.overlaySurfaceCount
        overlayStore: overlayStore
    }

    Ipc.PublicIpcV1 {
        lifecycle: lifecycle
        foundationController: foundationController
        diagnosticsProvider: diagnosticSnapshot
        capabilityStore: capabilities
        overlayCoordinator: overlayCoordinator
    }

    Variants {
        model: root.surfacesEnabled ? Quickshell.screens : []

        Panel.BarSurface {
            configuration: configuration
            overlayCoordinator: overlayCoordinator
            swayStore: swayStore
            windowStore: windowStore
            windowController: windowController
            onSurfaceReady: root.surfaceWasCreated()
            onSurfaceRemoved: root.surfaceCount = Math.max(0, root.surfaceCount - 1)
        }
    }

    Variants {
        model: root.menuScreens()

        Panel.WindowMenuSurface {
            configuration: configuration
            overlayStore: overlayStore
            overlayCoordinator: overlayCoordinator
            windowStore: windowStore
            windowController: windowController
            Component.onCompleted: root.overlaySurfaceCount += 1
            Component.onDestruction: root.overlaySurfaceCount = Math.max(0, root.overlaySurfaceCount - 1)
        }
    }

    Variants {
        model: root.launcherScreens()

        Panel.LauncherSurface {
            configuration: configuration
            overlayCoordinator: overlayCoordinator
            Component.onCompleted: root.overlaySurfaceCount += 1
            Component.onDestruction: root.overlaySurfaceCount = Math.max(0, root.overlaySurfaceCount - 1)
        }
    }

    Connections {
        target: swayStore
        function onSnapshotPublished() {
            overlayCoordinator.reconcileOutputs();
        }
    }

    Timer {
        id: surfaceReadyTimer
        interval: 0
        repeat: false
        onTriggered: {
            foundationController.surfaceCreated();
        }
    }

    Timer {
        id: shutdownTimeout
        interval: 2000
        repeat: false
        onTriggered: root.finishShutdown()
    }

    function startShutdown(reason) {
        foundationController.requestShutdown(reason);
    }

    function surfaceWasCreated() {
        root.surfaceCount += 1;
        surfaceReadyTimer.restart();
    }

    function finishShutdown() {
        if (lifecycle.state !== "shutting_down")
            return;
        shutdownTimeout.stop();
        root.shutdownFlushRequested = false;
        foundationController.finishShutdown();
    }

    function launcherScreens() {
        const screenCount = Quickshell.screens.length;
        if (!overlayStore.open || overlayStore.panel !== "launcher")
            return [];
        for (let index = 0; index < screenCount; ++index) {
            const candidate = Quickshell.screens[index];
            if (candidate.name === overlayStore.output)
                return [candidate];
        }
        return [];
    }

    function menuScreens() {
        const screenCount = Quickshell.screens.length;
        if (!overlayStore.open || (overlayStore.panel !== "window_group" && overlayStore.panel !== "overflow"))
            return [];
        for (let index = 0; index < screenCount; ++index) {
            const candidate = Quickshell.screens[index];
            if (candidate.name === overlayStore.output)
                return [candidate];
        }
        return [];
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        logger.emit("info", "hydrogen.lifecycle", "startup_started", "Inicialização iniciada.", {
            state: lifecycle.state
        });
        foundationController.start();
    }
}
