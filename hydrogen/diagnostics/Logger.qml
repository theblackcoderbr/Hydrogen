import QtQml

QtObject {
    id: root

    property var clock
    property int suppressionWindowMs: 30000
    property int suppressedCount: 0
    property var lastEmissionByFingerprint: ({})

    function safeFields(fields) {
        const allowed = ["operation", "state", "component", "duration_ms", "exit_code", "generation", "correlation_id"];
        const safe = {};
        Object.keys(fields || {}).forEach(key => {
            if (allowed.indexOf(key) >= 0)
                safe[key] = fields[key];
        });
        return safe;
    }

    function emit(level, category, code, message, fields) {
        const now = root.clock ? root.clock.nowMs() : Date.now();
        const fingerprint = [category, code, fields && fields.component || "", fields && fields.operation || ""].join("|");
        const last = root.lastEmissionByFingerprint[fingerprint];
        if (last !== undefined && now - last < root.suppressionWindowMs) {
            root.suppressedCount += 1;
            return false;
        }
        const emissions = Object.assign({}, root.lastEmissionByFingerprint);
        emissions[fingerprint] = now;
        root.lastEmissionByFingerprint = emissions;
        const record = `[${category}] ${code}: ${message} ${JSON.stringify(root.safeFields(fields))}`;
        if (level === "error" || level === "fatal")
            console.error(record);
        else if (level === "warning")
            console.warn(record);
        else if (level === "debug")
            console.debug(record);
        else
            console.info(record);
        return true;
    }
}
