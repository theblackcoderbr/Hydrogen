.pragma library

function clamp(value, minimum, maximum) {
    return Math.min(maximum, Math.max(minimum, Number(value)));
}

function layoutForWidth(width) {
    var available = Math.max(1, Number(width || 0));
    var compact = available < 720;
    return {
        compact: compact,
        horizontalPadding: compact ? 8 : 12,
        sectionWidth: compact ? 76 : clamp(Math.floor(available * 0.18), 112, 260),
        launcherSize: compact ? 32 : 34
    };
}

function formatClock(date) {
    var hours = String(date.getHours()).padStart(2, "0");
    var minutes = String(date.getMinutes()).padStart(2, "0");
    return hours + ":" + minutes;
}

function hasOutput(name, outputs) {
    var wanted = String(name || "");
    return (outputs || []).some(function(output) {
        return String(output.name || "") === wanted;
    });
}

function outputForRequest(requested, focused, outputs) {
    if (hasOutput(requested, outputs))
        return String(requested);
    if (hasOutput(focused, outputs))
        return String(focused);
    return outputs && outputs.length > 0 ? String(outputs[0].name || "") : "";
}
