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

test("application usage updates one record and pruning applies age validity and bound", () => {
    let history = Launcher.recordApplicationUse([], "editor", "2026-08-29T10:00:00.000Z");
    history = Launcher.recordApplicationUse(history, "editor", "2026-08-29T11:00:00.000Z");
    history.push({ kind: "application", desktop_entry: "removed", use_count: 8, last_used_at: "2026-08-29T11:00:00.000Z" });
    history.push({ kind: "application", desktop_entry: "old", use_count: 4, last_used_at: "2020-01-01T00:00:00.000Z" });
    const pruned = Launcher.pruneApplicationHistory(history, ["editor", "old"], Date.parse("2026-08-29T12:00:00.000Z"), 1, 30);
    assert.deepEqual(pruned, [{ kind: "application", desktop_entry: "editor", use_count: 2, last_used_at: "2026-08-29T11:00:00.000Z" }]);
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
