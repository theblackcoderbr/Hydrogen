import assert from "node:assert/strict";
import test from "node:test";
import { loadQmlJavaScript } from "../helpers/load-qml-js.mjs";

const Foundation = loadQmlJavaScript(new URL("../../hydrogen/logic/Foundation.js", import.meta.url));
const Defaults = loadQmlJavaScript(new URL("../../hydrogen/config/Defaults.js", import.meta.url));

test("lifecycle accepts only documented transitions and blocks mutations on shutdown", () => {
    assert.equal(Foundation.canTransition("starting", "loading_configuration"), true);
    assert.equal(Foundation.canTransition("starting", "running"), false);
    assert.equal(Foundation.canTransition("shutting_down", "running"), false);
    assert.equal(Foundation.isMutationAllowed("running"), true);
    assert.equal(Foundation.isMutationAllowed("shutting_down"), false);
});

test("configuration ignores unknown options and restores invalid ranges", () => {
    const defaults = Defaults.configuration();
    const result = Foundation.validateConfiguration({
        general: { debug: true, secret_option: "ignored" },
        persistence: { write_debounce_ms: -1 },
        bar: { height: 12 }
    }, defaults);
    assert.equal(result.ok, true);
    assert.equal(result.effective.general.debug, true);
    assert.equal(result.effective.general.secret_option, undefined);
    assert.equal(result.effective.persistence.write_debounce_ms, 250);
    assert.equal(result.effective.bar.height, 44);
    assert.deepEqual(Array.from(result.warnings, warning => warning.code).sort(), ["invalid_range", "invalid_range", "unknown_option"]);
});

test("error registry deduplicates, counts, recovers and respects its bound", () => {
    let errors = [];
    const base = { code: "backend_failure", category: "hydrogen.sway", component: "sway", action: "connect" };
    errors = Foundation.registerError(errors, base, "2026-08-28T00:00:00.000Z", 2);
    errors = Foundation.registerError(errors, base, "2026-08-28T00:00:01.000Z", 2);
    assert.equal(errors.length, 1);
    assert.equal(errors[0].count, 2);
    const fingerprint = Foundation.errorFingerprint(errors[0]);
    errors = Foundation.recoverError(errors, fingerprint, "2026-08-28T00:00:02.000Z");
    assert.equal(errors[0].recovered, true);
    errors = Foundation.registerError(errors, { code: "b", category: "hydrogen.config" }, "2026-08-28T00:00:03.000Z", 2);
    errors = Foundation.registerError(errors, { code: "c", category: "hydrogen.config" }, "2026-08-28T00:00:04.000Z", 2);
    assert.equal(errors.length, 2);
});

test("state persistence preserves future schemas and rejects corruption", () => {
    assert.equal(Foundation.parseState('{"schema_version":2}', 1).code, "state_schema_future");
    assert.equal(Foundation.parseState('{broken', 1).code, "state_corrupt");
    const serialized = Foundation.serializeState({ do_not_disturb: true }, "2026-08-28T00:00:00.000Z");
    const parsed = Foundation.parseState(serialized, 1);
    assert.equal(parsed.ok, true);
    assert.equal(parsed.data.do_not_disturb, true);
});

test("corrupt state retention keeps the newest three valid copies", () => {
    const files = [
        "state.corrupt-2026-08-27T00-00-01-000Z.json",
        "state.corrupt-2026-08-27T00-00-05-000Z.json",
        "unrelated.json",
        "state.corrupt-2026-08-27T00-00-03-000Z.json",
        "state.corrupt-2026-08-27T00-00-02-000Z.json",
        "state.corrupt-2026-08-27T00-00-04-000Z.json",
        "state.corrupt-2026-08-27T00-00-05-000Z.json"
    ];
    assert.deepEqual(Array.from(Foundation.corruptCopiesToDelete(files, 3)), [
        "state.corrupt-2026-08-27T00-00-02-000Z.json",
        "state.corrupt-2026-08-27T00-00-01-000Z.json"
    ]);
});

test("corrupt retention failure is actionable and non-terminal", () => {
    assert.equal(Foundation.corruptRetentionError(0), null);
    const error = Foundation.corruptRetentionError(1);
    assert.equal(error.code, "corrupt_retention_failed");
    assert.equal(error.severity, "warning");
    assert.equal(error.action, "check_permissions");
});

test("status and diagnostics expose no personal content", () => {
    const context = {
        lifecycle: "running", configurationGeneration: 2, focusedOutput: "HEADLESS-1",
        surfaceCount: 2, providers: [{ name: "sway", state: "ready", essential: true, synchronized: true }],
        errors: [{ code: "x", category: "hydrogen.config", severity: "warning", component: "config", action: "edit", count: 1, recovered: false, dismissed: false, message: "safe", secret: "must-not-leak" }],
        versions: { hydrogen: "0.1.0", ipc: "1", quickshell: "0.3.1" }, uptimeMs: 100,
        outputs: [{ name: "HEADLESS-1", width: 1920, height: 1080, scale: 1, focused: true, windows: ["private"] }],
        persistence: { state: "ready", pending_writes: 0 }, suppressedLogCount: 0,
        commandHistory: ["private"], notifications: [{ body: "private" }]
    };
    const status = JSON.stringify(Foundation.statusSnapshot(context));
    const diagnostics = JSON.stringify(Foundation.diagnosticsSnapshot(context));
    assert.equal(status.includes("private"), false);
    assert.equal(diagnostics.includes("private"), false);
    assert.equal(diagnostics.includes("must-not-leak"), false);
});

test("IPC responses always use the stable envelope", () => {
    const payload = JSON.parse(Foundation.response(false, "invalid_arguments", "Inválido.", { field: "scope" }));
    assert.deepEqual(Object.keys(payload), ["ok", "code", "message", "data"]);
    assert.equal(payload.ok, false);
    assert.equal(payload.code, "invalid_arguments");
});
