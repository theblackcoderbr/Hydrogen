import assert from "node:assert/strict";
import test from "node:test";
import { loadQmlJavaScript } from "../helpers/load-qml-js.mjs";

const Defaults = loadQmlJavaScript(new URL("../../hydrogen/config/Defaults.js", import.meta.url));
const Toml = loadQmlJavaScript(new URL("../../hydrogen/logic/Toml.js", import.meta.url));

test("all generated active TOML files parse", () => {
    const templates = Defaults.templates();
    assert.deepEqual(Object.keys(templates).sort(), [
        "components/appearance.toml", "components/bar.toml", "components/integrations.toml",
        "components/launcher.toml", "components/notifications.toml", "components/osd.toml",
        "config.toml"
    ]);
    for (const [path, text] of Object.entries(templates))
        assert.equal(Toml.parse(text).ok, true, path);
});

test("generated configuration uses English keys and required defaults", () => {
    const configuration = Defaults.configuration();
    assert.equal(configuration.logging.deduplication_seconds, 30);
    assert.equal(configuration.persistence.write_debounce_ms, 250);
    assert.equal(configuration.persistence.shutdown_timeout_ms, 2000);
    assert.equal(configuration.launcher.history_limit, 100);
    assert.equal(configuration.notifications.history_limit, 50);
});
