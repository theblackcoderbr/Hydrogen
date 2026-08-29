import assert from "node:assert/strict";
import test from "node:test";
import { loadQmlJavaScript } from "../helpers/load-qml-js.mjs";

const Navigation = loadQmlJavaScript(new URL("../../hydrogen/logic/WindowNavigation.js", import.meta.url));

const catalog = [
    { id: "org.example.Editor", name: "Editor", icon: "editor", startupClass: "ExampleEditor" },
    { id: "org.example.Flatpak", name: "Flatpak", icon: "flatpak", startupClass: "" },
    { id: "xterm-app", name: "XTerm", icon: "terminal", startupClass: "XTermClass" }
];

function treeFixture() {
    return {
        type: "root", nodes: [
            { type: "output", name: "HEADLESS-1", nodes: [
                { type: "workspace", name: "1", num: 1, nodes: [
                    { type: "con", id: 10, app_id: "org.example.Editor", name: "Mesmo título", pid: 50, focused: true, urgent: false, nodes: [], floating_nodes: [] },
                    { type: "con", id: 11, app_id: "org.example.Editor", name: "Outro", pid: 51, focused: false, urgent: true, nodes: [], floating_nodes: [] },
                    { type: "con", id: 12, app_id: "missing.one", name: "Mesmo título", pid: 50, focused: false, nodes: [], floating_nodes: [] },
                    { type: "con", id: 13, app_id: "missing.two", name: "Mesmo título", pid: 50, focused: false, nodes: [], floating_nodes: [] }
                ], floating_nodes: [
                    { type: "floating_con", id: 14, window: 100, name: "X11", window_properties: { class: "XTermClass", instance: "xterm" }, nodes: [], floating_nodes: [] }
                ] }
            ] },
            { type: "output", name: "__i3", nodes: [
                { type: "workspace", name: "__i3_scratch", num: -1, nodes: [
                    { type: "con", id: 99, app_id: "org.example.Editor", name: "Scratch", nodes: [], floating_nodes: [] }
                ], floating_nodes: [] }
            ] }
        ], floating_nodes: []
    };
}

test("tree extraction covers Wayland and XWayland while excluding scratchpad", () => {
    const windows = Navigation.extractWindows(treeFixture());
    assert.equal(windows.length, 5);
    assert.equal(windows.find(window => window.id === 10).xwayland, false);
    assert.equal(windows.find(window => window.id === 14).xwayland, true);
    assert.equal(windows.some(window => window.id === 99), false);
});

test("confident identities group and unresolved windows remain separate despite title and PID", () => {
    const windows = Navigation.identifyWindows(Navigation.extractWindows(treeFixture()), catalog, []);
    const groups = Navigation.groupWindows(windows, "HEADLESS-1", "1", windows.map(window => window.identity.key));
    assert.equal(groups.find(group => group.key === "desktop:org.example.Editor").windows.length, 2);
    assert.equal(groups.filter(group => group.key.startsWith("unresolved:")).length, 2);
    assert.equal(groups.find(group => group.key === "desktop:xterm-app").windows.length, 1);
});

test("manual rules use exact all-field matching and declaration order", () => {
    const window = { id: 7, sandboxAppId: "", appId: "portable", wmClass: "Portable", wmInstance: "main" };
    const rules = [
        { app_id: "portable", wm_class: "Wrong", name: "Não" },
        { app_id: "portable", wm_class: "Portable", name: "Portátil", icon: "portable" },
        { app_id: "portable", name: "Tarde demais" }
    ];
    const identity = Navigation.resolveIdentity(window, catalog, rules);
    assert.equal(identity.name, "Portátil");
    assert.equal(identity.key, "manual:1");
});

test("sandbox id precedes app id and StartupWMClass resolves XWayland", () => {
    const flatpak = Navigation.resolveIdentity({ id: 1, sandboxAppId: "org.example.Flatpak", appId: "org.example.Editor", wmClass: "", wmInstance: "" }, catalog, []);
    const xwayland = Navigation.resolveIdentity({ id: 2, sandboxAppId: "", appId: "", wmClass: "XTermClass", wmInstance: "xterm" }, catalog, []);
    assert.equal(flatpak.key, "desktop:org.example.Flatpak");
    assert.equal(flatpak.source, "sandbox_app_id");
    assert.equal(xwayland.key, "desktop:xterm-app");
    assert.equal(xwayland.source, "startup_wm_class");
});

test("explicit transient relationship inherits the parent group", () => {
    const windows = Navigation.identifyWindows([
        { id: 1, windowId: 100, transientFor: 0, appId: "org.example.Editor", sandboxAppId: "", wmClass: "", wmInstance: "" },
        { id: 2, windowId: 101, transientFor: 100, appId: "unknown-dialog", sandboxAppId: "", wmClass: "", wmInstance: "" }
    ], catalog, []);
    assert.equal(windows[1].identity.key, windows[0].identity.key);
});

test("overflow keeps the focused application visible", () => {
    const groups = ["a", "b", "c", "d"].map((key, index) => ({ key, focused: index === 3 }));
    const split = Navigation.splitOverflow(groups, 3);
    assert.deepEqual(Array.from(split.visible, group => group.key), ["a", "d"]);
    assert.deepEqual(Array.from(split.overflow, group => group.key), ["b", "c"]);
});

test("workspace projection shows current and occupied workspaces by real output", () => {
    const workspaces = [
        { name: "1", number: 1, output: "A", focused: true, active: true },
        { name: "2", number: 2, output: "A", focused: false, active: false },
        { name: "3", number: 3, output: "A", focused: false, active: false },
        { name: "4", number: 4, output: "B", focused: false, active: true }
    ];
    const windows = [{ output: "A", workspace: "3", urgent: true }];
    const visible = Navigation.visibleWorkspaces(workspaces, windows, "A");
    assert.deepEqual(Array.from(visible, workspace => workspace.number), [1, 3]);
    assert.equal(visible[1].urgent, true);
});

test("invalid manual rules are isolated without rejecting valid siblings", () => {
    const result = Navigation.validateRules([
        { app_id: "ok", name: "Ok" },
        { name: "missing match" },
        { app_id: "bad", unknown: "field" }
    ]);
    assert.equal(result.valid.length, 1);
    assert.deepEqual(Array.from(result.invalid), [1, 2]);
});
