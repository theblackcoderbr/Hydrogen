import QtQuick
import QtTest
import "../../hydrogen/logic/Foundation.js" as Foundation
import "../../hydrogen/config/Defaults.js" as Defaults

TestCase {
    name: "Foundation"

    function test_lifecycleTransitions() {
        verify(Foundation.canTransition("starting", "loading_configuration"));
        verify(!Foundation.canTransition("starting", "running"));
        verify(!Foundation.canTransition("shutting_down", "running"));
        verify(Foundation.isMutationAllowed("running"));
        verify(!Foundation.isMutationAllowed("shutting_down"));
    }

    function test_configurationValidation() {
        const defaults = Defaults.configuration();
        const result = Foundation.validateConfiguration({
            general: {
                debug: true,
                secret_option: "ignored"
            },
            persistence: {
                write_debounce_ms: -1
            },
            bar: {
                height: 12
            }
        }, defaults);
        verify(result.ok);
        compare(result.effective.general.debug, true);
        compare(result.effective.general.secret_option, undefined);
        compare(result.effective.persistence.write_debounce_ms, 250);
        compare(result.effective.bar.height, 44);
        compare(result.warnings.length, 3);
    }

    function test_errorRegistry() {
        let errors = [];
        const error = {
            code: "backend_failure",
            category: "hydrogen.sway",
            component: "sway",
            action: "connect"
        };
        errors = Foundation.registerError(errors, error, "2026-08-28T00:00:00.000Z", 50);
        errors = Foundation.registerError(errors, error, "2026-08-28T00:00:01.000Z", 50);
        compare(errors.length, 1);
        compare(errors[0].count, 2);
        errors = Foundation.recoverError(errors, Foundation.errorFingerprint(errors[0]), "2026-08-28T00:00:02.000Z");
        verify(errors[0].recovered);
    }

    function test_persistenceSchemas() {
        compare(Foundation.parseState('{"schema_version":2}', 1).code, "state_schema_future");
        compare(Foundation.parseState('{broken', 1).code, "state_corrupt");
        const serialized = Foundation.serializeState({
            do_not_disturb: true
        }, "2026-08-28T00:00:00.000Z");
        const parsed = Foundation.parseState(serialized, 1);
        verify(parsed.ok);
        verify(parsed.data.do_not_disturb);
    }

    function test_corruptStateRetentionKeepsNewestThree() {
        const files = ["state.corrupt-2026-08-27T00-00-01-000Z.json", "state.corrupt-2026-08-27T00-00-05-000Z.json", "unrelated.json", "state.corrupt-2026-08-27T00-00-03-000Z.json", "state.corrupt-2026-08-27T00-00-02-000Z.json", "state.corrupt-2026-08-27T00-00-04-000Z.json", "state.corrupt-2026-08-27T00-00-05-000Z.json"];
        compare(Foundation.corruptCopiesToDelete(files, 3), ["state.corrupt-2026-08-27T00-00-02-000Z.json", "state.corrupt-2026-08-27T00-00-01-000Z.json"]);
    }

    function test_corruptRetentionFailureIsActionableAndNonTerminal() {
        compare(Foundation.corruptRetentionError(0), null);
        const error = Foundation.corruptRetentionError(1);
        compare(error.code, "corrupt_retention_failed");
        compare(error.severity, "warning");
        compare(error.action, "check_permissions");
    }

    function test_diagnosticsAreSanitized() {
        const context = {
            lifecycle: "running",
            configurationGeneration: 2,
            focusedOutput: "HEADLESS-1",
            surfaceCount: 2,
            providers: [
                {
                    name: "sway",
                    state: "ready",
                    essential: true,
                    synchronized: true
                }
            ],
            errors: [
                {
                    code: "x",
                    category: "hydrogen.config",
                    severity: "warning",
                    component: "config",
                    action: "edit",
                    count: 1,
                    recovered: false,
                    dismissed: false,
                    message: "safe",
                    secret: "must-not-leak"
                }
            ],
            versions: {
                hydrogen: "0.1.0",
                ipc: "1",
                quickshell: "0.3.1"
            },
            uptimeMs: 100,
            outputs: [
                {
                    name: "HEADLESS-1",
                    width: 1920,
                    height: 1080,
                    scale: 1,
                    focused: true,
                    windows: ["private"]
                }
            ],
            persistence: {
                state: "ready",
                pending_writes: 0
            },
            suppressedLogCount: 0,
            commandHistory: ["private"],
            notifications: [
                {
                    body: "private"
                }
            ]
        };
        const status = JSON.stringify(Foundation.statusSnapshot(context));
        const diagnostics = JSON.stringify(Foundation.diagnosticsSnapshot(context));
        verify(status.indexOf("private") < 0);
        verify(diagnostics.indexOf("private") < 0);
        verify(diagnostics.indexOf("must-not-leak") < 0);
    }

    function test_responseEnvelope() {
        const payload = JSON.parse(Foundation.response(false, "invalid_arguments", "Inválido.", {
            field: "scope"
        }));
        compare(payload.ok, false);
        compare(payload.code, "invalid_arguments");
        verify(payload.data.field === "scope");
    }
}
