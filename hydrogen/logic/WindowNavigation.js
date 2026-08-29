.pragma library

var matchFields = ["sandbox_app_id", "app_id", "wm_class", "wm_instance"];
var identityFields = ["desktop_entry", "name", "icon"];

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value);
}

function validRule(rule) {
    if (!rule || typeof rule !== "object" || Array.isArray(rule))
        return false;
    var hasMatch = matchFields.some(function(field) { return stringValue(rule[field]) !== ""; });
    var hasIdentity = identityFields.some(function(field) { return stringValue(rule[field]) !== ""; });
    var known = matchFields.concat(identityFields);
    var onlyKnownStrings = Object.keys(rule).every(function(field) {
        return known.indexOf(field) !== -1 && typeof rule[field] === "string";
    });
    return hasMatch && hasIdentity && onlyKnownStrings;
}

function validateRules(rules) {
    var valid = [];
    var invalid = [];
    (rules || []).forEach(function(rule, index) {
        if (validRule(rule))
            valid.push({ rule: rule, index: index });
        else
            invalid.push(index);
    });
    return { valid: valid, invalid: invalid };
}

function extractWindows(tree) {
    var windows = [];
    function visit(node, output, workspace) {
        if (!node || typeof node !== "object")
            return;
        var nextOutput = node.type === "output" && node.name !== "__i3" ? stringValue(node.name) : output;
        var nextWorkspace = node.type === "workspace" ? {
            name: stringValue(node.name),
            number: Number(node.num === undefined ? -1 : node.num)
        } : workspace;
        var children = (node.nodes || []).concat(node.floating_nodes || []);
        var properties = node.window_properties || {};
        var isWindow = (node.type === "con" || node.type === "floating_con")
            && (stringValue(node.app_id) !== "" || node.window !== null && node.window !== undefined
                || stringValue(properties.class) !== "" || stringValue(node.sandbox_app_id) !== "");
        if (isWindow && nextWorkspace && nextWorkspace.name !== "__i3_scratch") {
            windows.push({
                id: Number(node.id),
                windowId: Number(node.window || 0),
                title: stringValue(node.name) || "Janela sem título",
                appId: stringValue(node.app_id),
                sandboxAppId: stringValue(node.sandbox_app_id),
                wmClass: stringValue(properties.class),
                wmInstance: stringValue(properties.instance),
                transientFor: Number(properties.transient_for || 0),
                pid: Number(node.pid || 0),
                output: nextOutput,
                workspace: nextWorkspace.name,
                workspaceNumber: nextWorkspace.number,
                focused: Boolean(node.focused),
                urgent: Boolean(node.urgent),
                xwayland: node.window !== null && node.window !== undefined && stringValue(node.app_id) === ""
            });
        }
        children.forEach(function(child) { visit(child, nextOutput, nextWorkspace); });
    }
    visit(tree, "", null);
    return windows;
}

function catalogIndex(catalog) {
    var byId = {};
    var byStartup = {};
    (catalog || []).forEach(function(entry) {
        var id = stringValue(entry.id);
        if (id !== "")
            byId[id] = entry;
        var startup = stringValue(entry.startupClass);
        if (startup !== "" && byStartup[startup] === undefined)
            byStartup[startup] = entry;
    });
    return { byId: byId, byStartup: byStartup };
}

function manualMatch(window, rule) {
    var values = {
        sandbox_app_id: window.sandboxAppId,
        app_id: window.appId,
        wm_class: window.wmClass,
        wm_instance: window.wmInstance
    };
    return matchFields.every(function(field) {
        return stringValue(rule[field]) === "" || stringValue(rule[field]) === stringValue(values[field]);
    });
}

function resolvedIdentity(entry, source) {
    return {
        confident: true,
        key: "desktop:" + entry.id,
        desktopEntry: entry.id,
        name: stringValue(entry.name) || entry.id,
        icon: stringValue(entry.icon) || "application-x-executable",
        source: source
    };
}

function resolveIdentity(window, catalog, rules) {
    var index = catalogIndex(catalog);
    var validation = validateRules(rules);
    for (var i = 0; i < validation.valid.length; ++i) {
        var wrapper = validation.valid[i];
        var rule = wrapper.rule;
        if (!manualMatch(window, rule))
            continue;
        var desktop = index.byId[stringValue(rule.desktop_entry)];
        if (desktop)
            return resolvedIdentity(desktop, "manual");
        return {
            confident: true,
            key: "manual:" + wrapper.index,
            desktopEntry: stringValue(rule.desktop_entry),
            name: stringValue(rule.name) || window.appId || window.wmClass || "Aplicativo",
            icon: stringValue(rule.icon) || "application-x-executable",
            source: "manual"
        };
    }
    var entry;
    if (window.sandboxAppId && index.byId[window.sandboxAppId])
        return resolvedIdentity(index.byId[window.sandboxAppId], "sandbox_app_id");
    if (window.appId && index.byId[window.appId])
        return resolvedIdentity(index.byId[window.appId], "app_id");
    var startupCandidates = [window.appId, window.wmClass, window.wmInstance];
    for (var candidateIndex = 0; candidateIndex < startupCandidates.length; ++candidateIndex) {
        entry = index.byStartup[stringValue(startupCandidates[candidateIndex])];
        if (entry)
            return resolvedIdentity(entry, "startup_wm_class");
    }
    if (window.wmClass && index.byId[window.wmClass])
        return resolvedIdentity(index.byId[window.wmClass], "wm_class");
    if (window.wmInstance && index.byId[window.wmInstance])
        return resolvedIdentity(index.byId[window.wmInstance], "wm_instance");
    return {
        confident: false,
        key: "unresolved:" + window.id,
        desktopEntry: "",
        name: window.appId || window.wmClass || window.wmInstance || "Aplicativo desconhecido",
        icon: "application-x-executable",
        source: "unresolved"
    };
}

function identifyWindows(windows, catalog, rules) {
    var result = (windows || []).map(function(window) {
        var copy = JSON.parse(JSON.stringify(window));
        copy.identity = resolveIdentity(copy, catalog, rules);
        return copy;
    });
    var byWindowId = {};
    result.forEach(function(window) {
        if (window.windowId)
            byWindowId[window.windowId] = window;
    });
    result.forEach(function(window) {
        var parent = byWindowId[window.transientFor];
        if (parent)
            window.identity = JSON.parse(JSON.stringify(parent.identity));
    });
    return result;
}

function groupWindows(windows, output, workspaceName, orderKeys) {
    var byKey = {};
    (windows || []).forEach(function(window) {
        if (window.output !== output || window.workspace !== workspaceName)
            return;
        var key = window.identity.key;
        if (!byKey[key]) {
            byKey[key] = {
                key: key,
                name: window.identity.name,
                displayName: window.identity.confident ? window.identity.name : window.title,
                icon: window.identity.icon,
                desktopEntry: window.identity.desktopEntry,
                confident: window.identity.confident,
                windows: [],
                focused: false,
                urgent: false
            };
        }
        byKey[key].windows.push(window);
        byKey[key].focused = byKey[key].focused || window.focused;
        byKey[key].urgent = byKey[key].urgent || window.urgent;
    });
    var order = {};
    (orderKeys || []).forEach(function(key, index) { order[key] = index; });
    return Object.keys(byKey).map(function(key) { return byKey[key]; }).sort(function(left, right) {
        return Number(order[left.key] === undefined ? 1000000 : order[left.key])
            - Number(order[right.key] === undefined ? 1000000 : order[right.key]);
    });
}

function splitOverflow(groups, capacity) {
    var list = groups || [];
    var maximum = Math.max(0, Number(capacity || 0));
    if (list.length <= maximum)
        return { visible: list.slice(), overflow: [] };
    var slots = Math.max(0, maximum - 1);
    var visible = list.slice(0, slots);
    var focusedIndex = list.findIndex(function(group) { return group.focused; });
    if (focusedIndex >= slots && slots > 0)
        visible[slots - 1] = list[focusedIndex];
    var visibleKeys = {};
    visible.forEach(function(group) { visibleKeys[group.key] = true; });
    return {
        visible: visible,
        overflow: list.filter(function(group) { return !visibleKeys[group.key]; })
    };
}

function visibleWorkspaces(workspaces, windows, output) {
    var occupied = {};
    var urgent = {};
    (windows || []).forEach(function(window) {
        if (window.output === output) {
            occupied[window.workspace] = true;
            urgent[window.workspace] = urgent[window.workspace] || window.urgent;
        }
    });
    return (workspaces || []).filter(function(workspace) {
        return workspace.output === output && Number(workspace.number) >= 0
            && (workspace.focused || workspace.active || occupied[workspace.name]);
    }).map(function(workspace) {
        var copy = JSON.parse(JSON.stringify(workspace));
        copy.urgent = Boolean(copy.urgent || urgent[copy.name]);
        return copy;
    }).sort(function(left, right) { return Number(left.number) - Number(right.number); });
}
