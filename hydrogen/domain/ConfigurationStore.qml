import QtQml
import "../config/Defaults.js" as Defaults

QtObject {
    id: root

    property int generation: 0
    property var effective: Defaults.configuration()
    property bool valid: true
    property var warnings: []
    property string lastReloadAt: ""
    property int rejectedReloads: 0

    signal published(int previousGeneration, int currentGeneration, var changedNamespaces)
    signal rejected(string code, string path, int line)

    function publish(candidate, nextWarnings, changedNamespaces) {
        const previous = root.generation;
        root.effective = candidate;
        root.warnings = nextWarnings;
        root.valid = true;
        root.generation = previous + 1;
        root.lastReloadAt = new Date().toISOString();
        root.published(previous, root.generation, changedNamespaces || []);
    }

    function reject(code, path, line) {
        root.valid = root.generation > 0;
        root.rejectedReloads += 1;
        root.lastReloadAt = new Date().toISOString();
        root.rejected(code, path, line);
    }
}
