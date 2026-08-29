.pragma library

var lifecycleStates = [
    "starting", "loading_configuration", "starting_core", "starting_providers",
    "creating_surfaces", "running", "reloading", "degraded", "shutting_down",
    "stopped", "failed"
];

var transitions = {
    starting: ["loading_configuration", "failed", "shutting_down"],
    loading_configuration: ["starting_core", "failed", "shutting_down"],
    starting_core: ["starting_providers", "failed", "shutting_down"],
    starting_providers: ["creating_surfaces", "failed", "shutting_down"],
    creating_surfaces: ["running", "degraded", "failed", "shutting_down"],
    running: ["reloading", "degraded", "shutting_down"],
    reloading: ["running", "degraded", "shutting_down"],
    degraded: ["reloading", "running", "shutting_down"],
    shutting_down: ["stopped"],
    stopped: [],
    failed: []
};

function canTransition(from, to) {
    return transitions[from] !== undefined && transitions[from].indexOf(to) !== -1;
}

function isMutationAllowed(state) {
    return state !== "shutting_down" && state !== "stopped" && state !== "failed";
}

function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
}

function deepEqual(left, right) {
    return JSON.stringify(left) === JSON.stringify(right);
}

function mergeKnown(base, incoming, path, warnings) {
    var result = deepClone(base);
    if (incoming === null || typeof incoming !== "object" || Array.isArray(incoming))
        return result;
    Object.keys(incoming).forEach(function(key) {
        var fullPath = path ? path + "." + key : key;
        if (!Object.prototype.hasOwnProperty.call(base, key)) {
            warnings.push({ code: "unknown_option", key: fullPath });
            return;
        }
        var expected = base[key];
        var actual = incoming[key];
        if (expected !== null && typeof expected === "object" && !Array.isArray(expected)) {
            if (actual === null || typeof actual !== "object" || Array.isArray(actual)) {
                warnings.push({ code: "invalid_type", key: fullPath });
                return;
            }
            result[key] = mergeKnown(expected, actual, fullPath, warnings);
        } else if (Array.isArray(expected)) {
            if (!Array.isArray(actual))
                warnings.push({ code: "invalid_type", key: fullPath });
            else
                result[key] = deepClone(actual);
        } else if (typeof expected !== typeof actual || (typeof actual === "number" && !isFinite(actual))) {
            warnings.push({ code: "invalid_type", key: fullPath });
        } else {
            result[key] = actual;
        }
    });
    return result;
}

function boundedInteger(value, minimum, maximum, fallback, key, warnings) {
    if (!Number.isInteger(value) || value < minimum || value > maximum) {
        warnings.push({ code: "invalid_range", key: key });
        return fallback;
    }
    return value;
}

function validateConfiguration(candidate, defaults) {
    var warnings = [];
    var effective = mergeKnown(defaults, candidate || {}, "", warnings);
    effective.logging.deduplication_seconds = boundedInteger(
        effective.logging.deduplication_seconds, 1, 3600,
        defaults.logging.deduplication_seconds, "logging.deduplication_seconds", warnings);
    effective.persistence.write_debounce_ms = boundedInteger(
        effective.persistence.write_debounce_ms, 0, 10000,
        defaults.persistence.write_debounce_ms, "persistence.write_debounce_ms", warnings);
    effective.persistence.shutdown_timeout_ms = boundedInteger(
        effective.persistence.shutdown_timeout_ms, 100, 10000,
        defaults.persistence.shutdown_timeout_ms, "persistence.shutdown_timeout_ms", warnings);
    effective.bar.height = boundedInteger(
        effective.bar.height, 28, 96,
        defaults.bar.height, "bar.height", warnings);
    return { ok: true, effective: effective, warnings: warnings };
}

function normalizeError(error, now) {
    return {
        code: String(error.code || "internal_error"),
        category: String(error.category || "hydrogen.lifecycle"),
        severity: String(error.severity || "error"),
        first_seen_at: error.first_seen_at || now,
        last_seen_at: now,
        count: Number(error.count || 1),
        component: String(error.component || "core"),
        action: String(error.action || ""),
        message: String(error.message || "Erro interno"),
        recovered: Boolean(error.recovered),
        dismissed: Boolean(error.dismissed)
    };
}

function errorFingerprint(error) {
    return [error.category, error.code, error.component, error.action].join("|");
}

function registerError(entries, error, now, limit) {
    var result = deepClone(entries);
    var normalized = normalizeError(error, now);
    var fingerprint = errorFingerprint(normalized);
    var existing = -1;
    for (var i = 0; i < result.length; ++i) {
        if (errorFingerprint(result[i]) === fingerprint && !result[i].recovered) {
            existing = i;
            break;
        }
    }
    if (existing >= 0) {
        result[existing].count += 1;
        result[existing].last_seen_at = now;
        result[existing].message = normalized.message;
    } else {
        result.push(normalized);
    }
    if (result.length > limit)
        result = result.slice(result.length - limit);
    return result;
}

function recoverError(entries, fingerprint, now) {
    return entries.map(function(entry) {
        var copy = deepClone(entry);
        if (errorFingerprint(copy) === fingerprint && !copy.recovered) {
            copy.recovered = true;
            copy.last_seen_at = now;
        }
        return copy;
    });
}

function response(ok, code, message, data) {
    return JSON.stringify({ ok: Boolean(ok), code: String(code), message: String(message), data: data || {} });
}

function sanitizeProvider(provider) {
    return {
        name: String(provider.name || "unknown"),
        state: String(provider.state || "unavailable"),
        essential: Boolean(provider.essential),
        synchronized: Boolean(provider.synchronized)
    };
}

function statusSnapshot(context) {
    return {
        lifecycle: context.lifecycle,
        configuration_generation: context.configurationGeneration,
        reloading: Boolean(context.reloading),
        shutting_down: context.lifecycle === "shutting_down",
        focused_output: context.focusedOutput || null,
        surface_count: Number(context.surfaceCount || 0),
        overlay_surface_count: Number(context.overlaySurfaceCount || 0),
        panel: context.panel || null,
        panel_output: context.panelOutput || null,
        window_count: Number(context.windowCount || 0),
        window_generation: Number(context.windowGeneration || 0),
        group_count: Number(context.groupCount || 0),
        largest_group_size: Number(context.largestGroupSize || 0),
        unresolved_window_count: Number(context.unresolvedWindowCount || 0),
        xwayland_window_count: Number(context.xwaylandWindowCount || 0),
        urgent_window_count: Number(context.urgentWindowCount || 0),
        providers: (context.providers || []).map(sanitizeProvider),
        actionable_error_count: (context.errors || []).filter(function(error) {
            return !error.recovered && !error.dismissed;
        }).length
    };
}

function diagnosticsSnapshot(context) {
    var status = statusSnapshot(context);
    status.versions = deepClone(context.versions || {});
    status.uptime_ms = Math.max(0, Number(context.uptimeMs || 0));
    status.outputs = (context.outputs || []).map(function(output) {
        return {
            name: String(output.name || ""), width: Number(output.width || 0),
            height: Number(output.height || 0), scale: Number(output.scale || 1),
            focused: Boolean(output.focused)
        };
    });
    status.persistence = deepClone(context.persistence || { state: "unavailable", pending_writes: 0 });
    status.errors = (context.errors || []).slice(-50).map(function(error) {
        return {
            code: error.code, category: error.category, severity: error.severity,
            component: error.component, action: error.action, count: error.count,
            recovered: error.recovered, message: error.message
        };
    });
    status.suppressed_log_count = Number(context.suppressedLogCount || 0);
    return status;
}

function parseState(text, supportedVersion) {
    if (String(text).trim() === "")
        return { ok: true, empty: true, data: { do_not_disturb: false } };
    try {
        var envelope = JSON.parse(text);
        if (!Number.isInteger(envelope.schema_version))
            return { ok: false, code: "state_schema_missing" };
        if (envelope.schema_version > supportedVersion)
            return { ok: false, code: "state_schema_future", preserve: true };
        if (envelope.schema_version < supportedVersion)
            return { ok: false, code: "state_migration_required", preserve: true };
        return { ok: true, empty: false, data: { do_not_disturb: Boolean(envelope.do_not_disturb) } };
    } catch (error) {
        return { ok: false, code: "state_corrupt", preserve: false };
    }
}

function serializeState(state, now) {
    return JSON.stringify({ schema_version: 1, updated_at: now, do_not_disturb: Boolean(state.do_not_disturb) });
}

function corruptCopiesToDelete(fileNames, maximum) {
    var limit = Number.isInteger(maximum) && maximum >= 0 ? maximum : 3;
    var seen = {};
    var valid = [];
    (fileNames || []).forEach(function(fileName) {
        var name = String(fileName);
        if (!/^state\.corrupt-[A-Za-z0-9_-]+\.json$/.test(name) || seen[name])
            return;
        seen[name] = true;
        valid.push(name);
    });
    valid.sort().reverse();
    return valid.slice(limit);
}

function corruptRetentionError(exitCode) {
    if (Number(exitCode) === 0)
        return null;
    return {
        code: "corrupt_retention_failed",
        category: "hydrogen.persistence",
        severity: "warning",
        component: "state",
        action: "check_permissions",
        message: "Não foi possível remover uma cópia corrompida antiga."
    };
}
