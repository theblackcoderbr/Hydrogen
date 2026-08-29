.pragma library

function text(value) {
    return value === undefined || value === null ? "" : String(value);
}

function normalized(value) {
    return text(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase();
}

function normalizeCatalog(entries) {
    return (entries || []).filter(function(entry) {
        return entry && !entry.noDisplay && text(entry.id) !== "" && text(entry.name) !== "";
    }).map(function(entry) {
        return {
            id: text(entry.id),
            name: text(entry.name),
            genericName: text(entry.genericName),
            comment: text(entry.comment),
            icon: text(entry.icon) || "application-x-executable",
            keywords: (entry.keywords || []).map(text),
            command: (entry.command || []).map(text).filter(function(part) { return part !== ""; }),
            workingDirectory: text(entry.workingDirectory),
            runInTerminal: Boolean(entry.runInTerminal),
            executable: (entry.command || []).length > 0
        };
    });
}

function matchTier(entry, query) {
    var wanted = normalized(query).trim();
    if (wanted === "")
        return -1;
    var name = normalized(entry.name);
    if (name === wanted)
        return 0;
    if (name.indexOf(wanted) === 0)
        return 1;
    if (name.split(/\s+/).some(function(word) { return word.indexOf(wanted) === 0; }))
        return 2;
    if (name.indexOf(wanted) >= 0)
        return 3;
    var secondary = [entry.genericName, entry.comment].concat(entry.keywords || []).map(normalized).join(" ");
    return secondary.indexOf(wanted) >= 0 ? 4 : -1;
}

function historyIndex(items) {
    var index = {};
    (items || []).forEach(function(item) {
        if (item && item.kind === "application" && text(item.desktop_entry) !== "")
            index[item.desktop_entry] = item;
    });
    return index;
}

function compareUsage(left, right) {
    var count = Number(right.use_count || 0) - Number(left.use_count || 0);
    if (count !== 0)
        return count;
    var recent = text(right.last_used_at).localeCompare(text(left.last_used_at));
    if (recent !== 0)
        return recent;
    return normalized(left.name).localeCompare(normalized(right.name)) || left.id.localeCompare(right.id);
}

function searchApplications(catalog, history, query, limit) {
    var maximum = Math.max(1, Math.min(20, Number(limit || 20)));
    var usage = historyIndex(history);
    var wanted = normalized(query).trim();
    var results = [];
    (catalog || []).forEach(function(entry) {
        var record = usage[entry.id] || {};
        var tier = wanted === "" ? -1 : matchTier(entry, wanted);
        if (wanted !== "" && tier < 0)
            return;
        if (wanted === "" && !usage[entry.id])
            return;
        var copy = JSON.parse(JSON.stringify(entry));
        copy.matchTier = tier;
        copy.use_count = Number(record.use_count || 0);
        copy.last_used_at = text(record.last_used_at);
        results.push(copy);
    });
    results.sort(function(left, right) {
        if (wanted !== "" && left.matchTier !== right.matchTier)
            return left.matchTier - right.matchTier;
        return compareUsage(left, right);
    });
    return results.slice(0, maximum);
}

function recordApplicationUse(items, desktopEntry, now) {
    var id = text(desktopEntry);
    var result = JSON.parse(JSON.stringify(items || []));
    var index = result.findIndex(function(item) { return item.kind === "application" && item.desktop_entry === id; });
    if (index < 0) {
        result.push({ kind: "application", desktop_entry: id, use_count: 1, last_used_at: text(now) });
    } else {
        result[index].use_count = Math.max(0, Number(result[index].use_count || 0)) + 1;
        result[index].last_used_at = text(now);
    }
    return result;
}

function pruneApplicationHistory(items, validIds, nowMs, maximum, days) {
    var valid = {};
    (validIds || []).forEach(function(id) { valid[text(id)] = true; });
    var cutoff = Number(nowMs) - Math.max(1, Number(days || 30)) * 86400000;
    return (items || []).filter(function(item) {
        var timestamp = Date.parse(text(item.last_used_at));
        return item && item.kind === "application" && valid[item.desktop_entry]
            && Number(item.use_count) > 0 && isFinite(timestamp) && timestamp >= cutoff;
    }).sort(function(left, right) {
        return Number(right.use_count) - Number(left.use_count)
            || text(right.last_used_at).localeCompare(text(left.last_used_at))
            || text(left.desktop_entry).localeCompare(text(right.desktop_entry));
    }).slice(0, Math.max(1, Number(maximum || 100)));
}

function parseHistory(raw, supportedVersion) {
    if (text(raw).trim() === "")
        return { ok: true, empty: true, items: [] };
    try {
        var envelope = JSON.parse(raw);
        if (!Number.isInteger(envelope.schema_version))
            return { ok: false, code: "launcher_history_schema_missing" };
        if (envelope.schema_version !== supportedVersion)
            return { ok: false, code: "launcher_history_schema_incompatible", preserve: envelope.schema_version > supportedVersion };
        if (!Array.isArray(envelope.items))
            return { ok: false, code: "launcher_history_invalid" };
        return { ok: true, empty: false, items: envelope.items };
    } catch (error) {
        return { ok: false, code: "launcher_history_corrupt" };
    }
}

function serializeHistory(items, now) {
    return JSON.stringify({ schema_version: 1, updated_at: text(now), items: items || [] });
}
