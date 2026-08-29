import QtQml
import "../logic/Foundation.js" as Foundation

QtObject {
    id: root

    property int limit: 50
    property var entries: []
    readonly property int actionableCount: entries.filter(error => !error.recovered && !error.dismissed).length

    signal changed

    function add(error) {
        root.entries = Foundation.registerError(root.entries, error, new Date().toISOString(), root.limit);
        root.changed();
    }

    function recover(error) {
        const fingerprint = typeof error === "string" ? error : Foundation.errorFingerprint(error);
        root.entries = Foundation.recoverError(root.entries, fingerprint, new Date().toISOString());
        root.changed();
    }

    function dismiss(fingerprint) {
        root.entries = root.entries.map(entry => {
            const copy = Object.assign({}, entry);
            if (Foundation.errorFingerprint(copy) === fingerprint)
                copy.dismissed = true;
            return copy;
        });
        root.changed();
    }
}
