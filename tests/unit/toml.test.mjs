import assert from "node:assert/strict";
import test from "node:test";
import { loadQmlJavaScript } from "../helpers/load-qml-js.mjs";

const Toml = loadQmlJavaScript(new URL("../../hydrogen/logic/Toml.js", import.meta.url));

test("parses Hydrogen scalar, table, array and rule syntax", () => {
    const result = Toml.parse(`
        # English configuration comment
        [general]
        debug = true
        values = [1, 2, 3]

        [[bar.app_matching.rules]]
        app_id = "org.example.App"
        desktop_entry = 'org.example.App'
    `);
    assert.equal(result.ok, true);
    assert.equal(result.data.general.debug, true);
    assert.deepEqual(Array.from(result.data.general.values), [1, 2, 3]);
    assert.equal(result.data.bar.app_matching.rules[0].app_id, "org.example.App");
});

test("comments inside strings are preserved", () => {
    const result = Toml.parse('[value]\ntext = "color #ffffff" # comment');
    assert.equal(result.ok, true);
    assert.equal(result.data.value.text, "color #ffffff");
});

test("duplicate keys and unsupported values fail closed with a line", () => {
    const duplicate = Toml.parse("value = 1\nvalue = 2");
    assert.equal(duplicate.ok, false);
    assert.equal(duplicate.code, "duplicate_key");
    assert.equal(duplicate.line, 2);

    const date = Toml.parse("created = 2026-08-28");
    assert.equal(date.ok, false);
    assert.equal(date.code, "unsupported_value");
});
