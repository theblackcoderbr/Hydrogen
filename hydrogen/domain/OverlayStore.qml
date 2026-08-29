import QtQml

QtObject {
    id: root

    readonly property bool open: panel !== "none"
    property string panel: "none"
    property string output: ""
    property var context: ({})
    property int generation: 0

    signal published(string panel, string output, int generation)

    function show(nextPanel, nextOutput, nextContext) {
        const normalizedPanel = String(nextPanel || "none");
        const normalizedOutput = String(nextOutput || "");
        if (normalizedPanel === "none" || normalizedOutput === "")
            return false;
        const normalizedContext = nextContext || {};
        if (root.panel === normalizedPanel && root.output === normalizedOutput && JSON.stringify(root.context) === JSON.stringify(normalizedContext))
            return true;
        root.panel = normalizedPanel;
        root.output = normalizedOutput;
        root.context = normalizedContext;
        root.generation += 1;
        root.published(root.panel, root.output, root.generation);
        return true;
    }

    function close() {
        if (!root.open)
            return false;
        root.panel = "none";
        root.output = "";
        root.context = ({});
        root.generation += 1;
        root.published(root.panel, root.output, root.generation);
        return true;
    }
}
