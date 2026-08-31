import assert from "node:assert/strict";
import test from "node:test";
import { loadQmlJavaScript } from "../helpers/load-qml-js.mjs";

const Launcher = loadQmlJavaScript(new URL("../../hydrogen/logic/Launcher.js", import.meta.url));

const catalog = Launcher.normalizeCatalog([
    { id: "editor", name: "Éditeur de Texto", genericName: "Editor", comment: "Documentos", icon: "edit", keywords: ["escrever"], command: ["editor"], noDisplay: false },
    { id: "edit-pro", name: "Editor Pro", genericName: "", comment: "", icon: "", keywords: [], command: ["edit-pro"], noDisplay: false },
    { id: "terminal", name: "Terminal", command: ["terminal"], runInTerminal: false, noDisplay: false },
    { id: "hidden", name: "Oculto", command: ["hidden"], noDisplay: true },
    { id: "broken", name: "Quebrado", command: [], noDisplay: false }
]);

test("catalog respects NoDisplay while retaining safely searchable inexecutable entries", () => {
    assert.deepEqual(catalog.map(entry => entry.id), ["editor", "edit-pro", "terminal", "broken"]);
    assert.equal(catalog.find(entry => entry.id === "broken").executable, false);
});

test("representative common, Flatpak and Steam desktop ids remain searchable", () => {
    const representatives = Launcher.normalizeCatalog([
        { id: "org.example.Common", name: "Common App", command: ["true"] },
        { id: "org.flatpak.Example", name: "Flatpak App", command: ["flatpak", "run", "org.flatpak.Example"] },
        { id: "steam_app_123", name: "Steam Game", command: ["steam", "-applaunch", "123"] }
    ]);
    assert.equal(Launcher.searchApplications(representatives, [], "common", 20)[0].id, "org.example.Common");
    assert.equal(Launcher.searchApplications(representatives, [], "flatpak", 20)[0].id, "org.flatpak.Example");
    assert.equal(Launcher.searchApplications(representatives, [], "steam", 20)[0].id, "steam_app_123");
});

test("search ignores case and accents without changing displayed names", () => {
    const results = Launcher.searchApplications(catalog, [], "EDITEUR", 20);
    assert.equal(results[0].id, "editor");
    assert.equal(results[0].name, "Éditeur de Texto");
});

test("name match tier precedes frequency and recency with deterministic ties", () => {
    const history = [
        { kind: "application", desktop_entry: "edit-pro", use_count: 99, last_used_at: "2026-08-29T10:00:00.000Z" },
        { kind: "application", desktop_entry: "editor", use_count: 1, last_used_at: "2026-08-28T10:00:00.000Z" }
    ];
    const results = Launcher.searchApplications(catalog, history, "éditeur de texto", 20);
    assert.equal(results[0].id, "editor");
    const prefixResults = Launcher.searchApplications(catalog, history, "edit", 20);
    assert.equal(prefixResults[0].id, "edit-pro");
});

test("empty query returns only most-used applications and result limit never exceeds twenty", () => {
    const many = Array.from({ length: 25 }, (_, index) => ({
        id: `app-${index}`, name: `App ${index}`, command: ["true"], executable: true
    }));
    const history = many.map((entry, index) => ({
        kind: "application", desktop_entry: entry.id, use_count: index + 1, last_used_at: "2026-08-29T10:00:00.000Z"
    }));
    const results = Launcher.searchApplications(many, history, "", 99);
    assert.equal(results.length, 20);
    assert.equal(results[0].id, "app-24");
});

test("empty normal query combines used applications and files but never commands", () => {
    const history = [
        { kind: "application", desktop_entry: "editor", use_count: 2, last_used_at: "2026-08-29T10:00:00.000Z" },
        { kind: "file", path: "/tmp/used.txt", use_count: 5, last_used_at: "2026-08-29T11:00:00.000Z" },
        { kind: "command", command: "printf hidden", terminal: false, use_count: 9, last_used_at: "2026-08-29T12:00:00.000Z" }
    ];
    const results = Launcher.launcherResults(catalog, [], [], ["printf"], history, "", 20);
    assert.deepEqual(Array.from(results, result => result.kind), ["application", "file"]);
    assert.equal(results[1].path, "/tmp/used.txt");
});

test("application usage updates one record and pruning applies age validity and bound", () => {
    let history = Launcher.recordApplicationUse([], "editor", "2026-08-29T10:00:00.000Z");
    history = Launcher.recordApplicationUse(history, "editor", "2026-08-29T11:00:00.000Z");
    history.push({ kind: "application", desktop_entry: "removed", use_count: 8, last_used_at: "2026-08-29T11:00:00.000Z" });
    history.push({ kind: "application", desktop_entry: "old", use_count: 4, last_used_at: "2020-01-01T00:00:00.000Z" });
    const pruned = Launcher.pruneApplicationHistory(history, ["editor", "old"], Date.parse("2026-08-29T12:00:00.000Z"), 1, 30);
    assert.deepEqual(JSON.parse(JSON.stringify(pruned)), [{ kind: "application", desktop_entry: "editor", use_count: 2, last_used_at: "2026-08-29T11:00:00.000Z" }]);
});

test("history parser preserves future schema and serialization excludes presentation data", () => {
    const future = Launcher.parseHistory('{"schema_version":2,"items":[]}', 1);
    assert.equal(future.ok, false);
    assert.equal(future.preserve, true);
    const serialized = JSON.parse(Launcher.serializeHistory([
        { kind: "application", desktop_entry: "editor", use_count: 2, last_used_at: "2026-08-29T11:00:00.000Z" }
    ], "2026-08-29T12:00:00.000Z"));
    assert.equal(serialized.items[0].desktop_entry, "editor");
    assert.equal(serialized.items[0].name, undefined);
});

test("normal results reserve all remaining positions for files after applications", () => {
    const files = Array.from({ length: 25 }, (_, index) => ({
        path: `/tmp/document-${index}.txt`,
        name: `SpecialFile ${index}`,
        url: `file:///tmp/document-${index}.txt`
    }));
    const results = Launcher.launcherResults(catalog, files, [], [], [], "specialfile", 20);
    assert.equal(results.length, 20);
    assert.equal(results.every(result => result.kind === "file"), true);
    const mixed = Launcher.launcherResults(catalog, files, [], [], [], "edit", 20);
    assert.equal(mixed[0].kind, "application");
    assert.equal(mixed.length <= 20, true);
});

test("file URLs escape spaces, hashes and unicode by path segment", () => {
    const result = Launcher.searchFiles([
        { path: "/tmp/ação # final.txt" }
    ], [], "ação", 20)[0];
    assert.equal(result.name, "ação # final.txt");
    assert.equal(result.url, "file:///tmp/a%C3%A7%C3%A3o%20%23%20final.txt");
});

test("command modifiers work in either order and operators remain command text", () => {
    assert.deepEqual({ ...Launcher.parseCommandMode(">!_printf 'a b' | tee *.txt") }, {
        active: true,
        private: true,
        terminal: true,
        commandLine: "printf 'a b' | tee *.txt"
    });
    assert.deepEqual({ ...Launcher.parseCommandMode(">_!true") }, {
        active: true,
        private: true,
        terminal: true,
        commandLine: "true"
    });
});

test("command suggestions combine input, actions, history and PATH executables", () => {
    const history = [
        { kind: "command", command: "printf old", terminal: false, use_count: 4, last_used_at: "2026-08-29T10:00:00.000Z" },
        { kind: "command", command: "most-used", terminal: false, use_count: 8, last_used_at: "2026-08-29T09:00:00.000Z" }
    ];
    const actions = [{ id: "reload_config", name: "Recarregar configuração", keywords: "reload", available: true }];
    const empty = Launcher.commandResults(actions, ["printf", "python3"], history, ">", 20);
    assert.equal(empty.some(result => result.kind === "action"), true);
    assert.equal(empty.some(result => result.commandLine === "printf old"), true);
    const commandSuggestions = empty.filter(result => result.kind === "command");
    assert.deepEqual(Array.from(commandSuggestions, result => result.commandLine), ["most-used", "printf old"]);
    const queried = Launcher.commandResults(actions, ["printf", "python3"], history, ">pri", 20);
    assert.equal(queried[0].commandLine, "pri");
    assert.equal(queried.some(result => result.commandLine === "printf"), true);
});

test("shared history ignores private commands and prunes all kinds globally", () => {
    const now = "2026-08-29T12:00:00.000Z";
    let history = Launcher.recordUse([], { kind: "file", path: "/tmp/current" }, now);
    history = Launcher.recordUse(history, { kind: "command", commandLine: "echo public", terminal: false, private: false }, now);
    history = Launcher.recordUse(history, { kind: "command", commandLine: "echo private", terminal: false, private: true }, now);
    history.push({ kind: "application", desktop_entry: "removed", use_count: 2, last_used_at: now });
    history.push({ kind: "file", path: "/tmp/missing", use_count: 2, last_used_at: now });
    const pruned = Launcher.pruneHistory(history, [], ["/tmp/current"], true, true, Date.parse(now), 2, 30);
    assert.equal(pruned.length, 2);
    assert.equal(pruned.some(item => item.command === "echo private"), false);
    assert.equal(pruned.some(item => item.desktop_entry === "removed"), false);
    assert.equal(pruned.some(item => item.path === "/tmp/missing"), false);
});

test("history parser removes private, relative and malformed restored entries", () => {
    const parsed = Launcher.parseHistory(JSON.stringify({
        schema_version: 1,
        items: [
            { kind: "command", command: "valid", terminal: false, use_count: 1, last_used_at: "2026-08-29T10:00:00.000Z" },
            { kind: "command", command: "private", terminal: false, private: true, use_count: 1, last_used_at: "2026-08-29T10:00:00.000Z" },
            { kind: "file", path: "relative", use_count: 1, last_used_at: "2026-08-29T10:00:00.000Z" }
        ]
    }), 1);
    assert.equal(parsed.ok, true);
    assert.deepEqual(JSON.parse(JSON.stringify(parsed.items)), [{ kind: "command", command: "valid", terminal: false, use_count: 1, last_used_at: "2026-08-29T10:00:00.000Z" }]);
});
