import QtQuick
import QtTest
import "../../hydrogen/core" as Core
import "../../hydrogen/diagnostics" as Diagnostics
import "../../hydrogen/domain" as Domain
import "../../hydrogen/providers/fakes" as Fakes

TestCase {
    id: testCase
    name: "FoundationComponents"

    property Component lifecycleComponent: Component {
        Core.LifecycleManager {}
    }

    property Domain.SwayStore swayStore: Domain.SwayStore {}

    property Fakes.FakeSwayProvider fakeSway: Fakes.FakeSwayProvider {
        store: testCase.swayStore
    }

    property Core.ErrorRegistry errors: Core.ErrorRegistry {}

    property Fakes.FakeClock fakeClock: Fakes.FakeClock {}

    property Diagnostics.Logger logger: Diagnostics.Logger {
        clock: testCase.fakeClock
    }

    function init() {
        swayStore.providerState = "initializing";
        swayStore.initialSynchronized = false;
        swayStore.outputs = [];
        swayStore.snapshotGeneration = 0;
        fakeSway.nextState = "ready";
        fakeSway.startCalls = 0;
        fakeSway.stopCalls = 0;
        errors.entries = [];
        fakeClock.currentMs = 0;
        logger.lastEmissionByFingerprint = ({});
        logger.suppressedCount = 0;
    }

    function test_lifecycleObjectFollowsExplicitPhases() {
        const lifecycle = createTemporaryObject(lifecycleComponent, testCase);
        verify(lifecycle !== null);
        verify(lifecycle.transition("loading_configuration"));
        verify(lifecycle.transition("starting_core"));
        verify(lifecycle.transition("starting_providers"));
        verify(lifecycle.transition("creating_surfaces"));
        verify(lifecycle.transition("running"));
        verify(lifecycle.beginShutdown("process_signal"));
        verify(!lifecycle.mayMutate("reload_config"));
        verify(lifecycle.transition("stopped"));
    }

    function test_fakeSwayPublishesOneNormalizedSnapshot() {
        fakeSway.start();
        compare(fakeSway.startCalls, 1);
        compare(swayStore.providerState, "ready");
        verify(swayStore.initialSynchronized);
        compare(swayStore.outputs.length, 1);
        compare(swayStore.snapshotGeneration, 1);
        fakeSway.stop();
        compare(fakeSway.stopCalls, 1);
    }

    function test_fakeSwayFailureIsLocalAndRecoverable() {
        fakeSway.nextState = "unavailable";
        fakeSway.start();
        compare(swayStore.providerState, "unavailable");
        fakeSway.nextState = "ready";
        fakeSway.start();
        compare(swayStore.providerState, "ready");
        verify(swayStore.initialSynchronized);
    }

    function test_errorRegistryAndLoggerDeduplicate() {
        const error = {
            code: "backend_failure",
            category: "hydrogen.sway",
            component: "sway",
            action: "connect"
        };
        errors.add(error);
        errors.add(error);
        compare(errors.entries.length, 1);
        compare(errors.entries[0].count, 2);

        verify(logger.emit("info", "hydrogen.sway", "backend_failure", "Falha.", {
            component: "sway",
            operation: "connect",
            secret: "not logged"
        }));
        verify(!logger.emit("info", "hydrogen.sway", "backend_failure", "Falha.", {
            component: "sway",
            operation: "connect"
        }));
        compare(logger.suppressedCount, 1);
        fakeClock.advance(30001);
        verify(logger.emit("info", "hydrogen.sway", "backend_failure", "Recorrência.", {
            component: "sway",
            operation: "connect"
        }));
    }
}
