import QtQml

QtObject {
    id: root
    property var available: ({
            sway: false,
            configuration: false,
            persistence: false
        })

    function setCapability(name, value) {
        const copy = Object.assign({}, root.available);
        copy[name] = Boolean(value);
        root.available = copy;
    }

    function names() {
        return Object.keys(root.available).filter(name => root.available[name]).sort();
    }
}
