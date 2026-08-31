.pragma library

function text(value) {
    return value === undefined || value === null ? "" : String(value);
}

function normalized(value) {
    return text(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase();
}

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function normalizeCatalog(entries) {
    return (entries || []).filter(function(entry) {
        return entry && !entry.noDisplay && text(entry.id) !== "" && text(entry.name) !== "";
    }).map(function(entry) {
        return {
            kind: "application",
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

function historyKey(item) {
    if (!item)
        return "";
    if (item.kind === "application")
        return "application:" + text(item.desktop_entry);
    if (item.kind === "file")
        return "file:" + text(item.path);
    if (item.kind === "command")
        return "command:" + (item.terminal ? "terminal:" : "direct:") + text(item.command);
    return "";
}

function historyIndex(items) {
    var index = {};
    (items || []).forEach(function(item) {
        var key = historyKey(item);
        if (key !== "")
            index[key] = item;
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
    return normalized(left.name).localeCompare(normalized(right.name)) || text(left.id).localeCompare(text(right.id));
}

function usageFor(index, key) {
    var record = index[key] || {};
    return { use_count: Number(record.use_count || 0), last_used_at: text(record.last_used_at) };
}

function searchApplications(catalog, history, query, limit) {
    var maximum = Math.max(1, Math.min(20, Number(limit || 20)));
    var usage = historyIndex(history);
    var wanted = normalized(query).trim();
    var results = [];
    (catalog || []).forEach(function(entry) {
        var key = "application:" + entry.id;
        var record = usageFor(usage, key);
        var tier = wanted === "" ? -1 : matchTier(entry, wanted);
        if (wanted !== "" && tier < 0)
            return;
        if (wanted === "" && !usage[key])
            return;
        var copy = clone(entry);
        copy.matchTier = tier;
        copy.use_count = record.use_count;
        copy.last_used_at = record.last_used_at;
        results.push(copy);
    });
    results.sort(function(left, right) {
        if (wanted !== "" && left.matchTier !== right.matchTier)
            return left.matchTier - right.matchTier;
        return compareUsage(left, right);
    });
    return results.slice(0, maximum);
}

function fileName(path) {
    var parts = text(path).split("/");
    return parts.length ? parts[parts.length - 1] : text(path);
}

function parentName(path) {
    var value = text(path);
    var index = value.lastIndexOf("/");
    return index > 0 ? value.slice(0, index) : "/";
}

function fileUrl(path) {
    return "file://" + text(path).split("/").map(function(part) { return encodeURIComponent(part); }).join("/");
}

function normalizedFile(entry) {
    var path = text(entry.path);
    return {
        kind: "file",
        id: "file:" + path,
        name: text(entry.name) || fileName(path),
        genericName: text(entry.parent) || parentName(path),
        comment: "",
        icon: text(entry.icon) || "text-x-generic",
        path: path,
        url: text(entry.url) || fileUrl(path),
        executable: true
    };
}

function searchFiles(files, history, query, limit) {
    var maximum = Math.max(0, Math.min(20, Number(limit || 20)));
    var usage = historyIndex(history);
    var wanted = normalized(query).trim();
    var source = files || [];
    if (wanted === "") {
        source = (history || []).filter(function(item) { return item.kind === "file"; }).map(function(item) {
            return { path: item.path, url: item.url || "" };
        });
    }
    var seen = {};
    var results = [];
    source.forEach(function(raw) {
        var entry = normalizedFile(raw);
        if (entry.path === "" || seen[entry.path])
            return;
        seen[entry.path] = true;
        var record = usageFor(usage, "file:" + entry.path);
        var tier = wanted === "" ? -1 : matchTier(entry, wanted);
        if (wanted !== "" && tier < 0)
            return;
        if (wanted === "" && record.use_count <= 0)
            return;
        entry.matchTier = tier;
        entry.use_count = record.use_count;
        entry.last_used_at = record.last_used_at;
        results.push(entry);
    });
    results.sort(function(left, right) {
        if (wanted !== "" && left.matchTier !== right.matchTier)
            return left.matchTier - right.matchTier;
        return compareUsage(left, right);
    });
    return results.slice(0, maximum);
}

function parseCommandMode(query) {
    var source = text(query);
    if (source.indexOf(">") !== 0)
        return { active: false, private: false, terminal: false, commandLine: "" };
    var index = 1;
    var privateMode = false;
    var terminalMode = false;
    while (index < source.length && (source[index] === "!" || source[index] === "_")) {
        if (source[index] === "!")
            privateMode = true;
        else
            terminalMode = true;
        index += 1;
    }
    return { active: true, private: privateMode, terminal: terminalMode, commandLine: source.slice(index).trim() };
}

function commandResults(actions, executables, history, query, limit) {
    var mode = parseCommandMode(query);
    if (!mode.active)
        return [];
    var maximum = Math.max(1, Math.min(20, Number(limit || 20)));
    var wanted = normalized(mode.commandLine);
    var results = [];
    if (mode.commandLine !== "") {
        results.push({
            kind: "command", id: "command:input", name: mode.commandLine,
            genericName: mode.terminal ? "Executar no terminal" : "Executar comando",
            icon: "system-run", commandLine: mode.commandLine,
            terminal: mode.terminal, private: mode.private, executable: true
        });
    }
    (actions || []).filter(function(action) {
        return wanted === "" || normalized(action.name).indexOf(wanted) >= 0 || normalized(action.keywords || "").indexOf(wanted) >= 0;
    }).forEach(function(action) {
        results.push({
            kind: "action", id: "action:" + action.id, actionId: action.id,
            name: action.name, genericName: action.description || "Ação do Hydrogen",
            icon: action.icon || "system-run", available: action.available !== false,
            executable: action.available !== false
        });
    });
    (history || []).filter(function(item) {
        return item.kind === "command" && (wanted === "" || normalized(item.command).indexOf(wanted) >= 0) && item.command !== mode.commandLine;
    }).map(function(item) {
        return {
            kind: "command", id: historyKey(item), name: item.command,
            genericName: item.terminal ? "Histórico · terminal" : "Histórico",
            icon: "document-open-recent", commandLine: item.command,
            terminal: mode.terminal || Boolean(item.terminal), private: mode.private,
            executable: true, use_count: item.use_count, last_used_at: item.last_used_at
        };
    }).sort(compareUsage).forEach(function(item) { results.push(item); });
    (executables || []).filter(function(executable) {
        var candidate = normalized(executable);
        return wanted !== "" && candidate.indexOf(wanted) >= 0 && executable !== mode.commandLine;
    }).sort(function(left, right) {
        var leftPrefix = normalized(left).indexOf(wanted) === 0 ? 0 : 1;
        var rightPrefix = normalized(right).indexOf(wanted) === 0 ? 0 : 1;
        return leftPrefix - rightPrefix || normalized(left).localeCompare(normalized(right));
    }).forEach(function(executable) {
        results.push({
            kind: "command", id: "executable:" + executable, name: executable,
            genericName: mode.terminal ? "Executável · terminal" : "Executável disponível",
            icon: "system-run", commandLine: executable, terminal: mode.terminal,
            private: mode.private, executable: true
        });
    });
    var seen = {};
    return results.filter(function(result) {
        var key = result.kind + ":" + (result.actionId || result.commandLine || result.id);
        if (seen[key])
            return false;
        seen[key] = true;
        return true;
    }).slice(0, maximum);
}

function launcherResults(catalog, files, actions, executables, history, query, limit) {
    var maximum = Math.max(1, Math.min(20, Number(limit || 20)));
    if (parseCommandMode(query).active)
        return commandResults(actions, executables, history, query, maximum);
    var apps = searchApplications(catalog, history, query, maximum);
    return apps.concat(searchFiles(files, history, query, maximum - apps.length)).slice(0, maximum);
}

function normalizeHistory(items) {
    return (items || []).filter(function(item) {
        if (!item || Number(item.use_count) <= 0 || !isFinite(Date.parse(text(item.last_used_at))))
            return false;
        if (item.kind === "application")
            return text(item.desktop_entry) !== "";
        if (item.kind === "file")
            return text(item.path).indexOf("/") === 0;
        if (item.kind === "command")
            return text(item.command).trim() !== "" && typeof item.terminal === "boolean" && item.private !== true;
        return false;
    }).map(function(item) {
        if (item.kind === "application")
            return { kind: "application", desktop_entry: text(item.desktop_entry), use_count: Number(item.use_count), last_used_at: text(item.last_used_at) };
        if (item.kind === "file")
            return { kind: "file", path: text(item.path), use_count: Number(item.use_count), last_used_at: text(item.last_used_at) };
        return { kind: "command", command: text(item.command), terminal: Boolean(item.terminal), use_count: Number(item.use_count), last_used_at: text(item.last_used_at) };
    });
}

function historyRecordFor(result, now) {
    if (!result)
        return null;
    if (result.kind === "application")
        return { kind: "application", desktop_entry: text(result.id), use_count: 1, last_used_at: text(now) };
    if (result.kind === "file" && text(result.path).indexOf("/") === 0)
        return { kind: "file", path: text(result.path), use_count: 1, last_used_at: text(now) };
    if (result.kind === "command" && !result.private && text(result.commandLine).trim() !== "")
        return { kind: "command", command: text(result.commandLine), terminal: Boolean(result.terminal), use_count: 1, last_used_at: text(now) };
    return null;
}

function recordUse(items, result, now) {
    var record = historyRecordFor(result, now);
    var history = normalizeHistory(items);
    if (!record)
        return history;
    var key = historyKey(record);
    var index = history.findIndex(function(item) { return historyKey(item) === key; });
    if (index < 0)
        history.push(record);
    else {
        history[index].use_count += 1;
        history[index].last_used_at = text(now);
    }
    return history;
}

function recordApplicationUse(items, desktopEntry, now) {
    return recordUse(items, { kind: "application", id: desktopEntry }, now);
}

function pruneHistory(items, validApplicationIds, validFilePaths, catalogsReady, filesReady, nowMs, maximum, days) {
    var applications = {};
    var files = {};
    (validApplicationIds || []).forEach(function(id) { applications[text(id)] = true; });
    (validFilePaths || []).forEach(function(path) { files[text(path)] = true; });
    var cutoff = Number(nowMs) - Math.max(1, Number(days || 30)) * 86400000;
    return normalizeHistory(items).filter(function(item) {
        if (Date.parse(item.last_used_at) < cutoff)
            return false;
        if (item.kind === "application" && catalogsReady)
            return Boolean(applications[item.desktop_entry]);
        if (item.kind === "file" && filesReady)
            return Boolean(files[item.path]);
        return true;
    }).sort(function(left, right) {
        return Number(right.use_count) - Number(left.use_count)
            || text(right.last_used_at).localeCompare(text(left.last_used_at))
            || historyKey(left).localeCompare(historyKey(right));
    }).slice(0, Math.max(1, Number(maximum || 100)));
}

function pruneApplicationHistory(items, validIds, nowMs, maximum, days) {
    return pruneHistory(items, validIds, [], true, false, nowMs, maximum, days).filter(function(item) { return item.kind === "application"; });
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
        return { ok: true, empty: false, items: normalizeHistory(envelope.items) };
    } catch (error) {
        return { ok: false, code: "launcher_history_corrupt" };
    }
}

function serializeHistory(items, now) {
    return JSON.stringify({ schema_version: 1, updated_at: text(now), items: normalizeHistory(items) });
}
