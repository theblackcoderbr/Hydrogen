import assert from "node:assert/strict";
import test from "node:test";
import { loadQmlJavaScript } from "../helpers/load-qml-js.mjs";

const Panel = loadQmlJavaScript(new URL("../../hydrogen/logic/Panel.js", import.meta.url));

test("panel layout remains usable at compact and wide dimensions", () => {
    const compact = Panel.layoutForWidth(320);
    const wide = Panel.layoutForWidth(1920);
    assert.equal(compact.compact, true);
    assert.equal(wide.compact, false);
    assert.ok(compact.sectionWidth < wide.sectionWidth);
    assert.ok(compact.launcherSize > 0);
});

test("clock formatting is deterministic and uses two digits", () => {
    assert.equal(Panel.formatClock(new Date(2026, 7, 28, 7, 5)), "07:05");
});

test("an explicit valid output wins, then focus, then the first output", () => {
    const outputs = [{ name: "one" }, { name: "two" }];
    assert.equal(Panel.outputForRequest("two", "one", outputs), "two");
    assert.equal(Panel.outputForRequest("missing", "one", outputs), "one");
    assert.equal(Panel.outputForRequest("", "missing", outputs), "one");
    assert.equal(Panel.outputForRequest("", "", []), "");
});
