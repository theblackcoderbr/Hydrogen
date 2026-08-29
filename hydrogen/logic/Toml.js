.pragma library

// A deliberately small TOML 1.0 reader for Hydrogen's own schema. It supports
// tables, arrays of tables, strings, booleans, integers, floats and arrays.
// Unsupported TOML constructs fail closed instead of being guessed.

function stripComment(line) {
    var quote = "";
    var escaped = false;
    for (var i = 0; i < line.length; ++i) {
        var ch = line[i];
        if (escaped) {
            escaped = false;
        } else if (quote === '"' && ch === "\\") {
            escaped = true;
        } else if (quote !== "") {
            if (ch === quote)
                quote = "";
        } else if (ch === '"' || ch === "'") {
            quote = ch;
        } else if (ch === "#") {
            return line.slice(0, i);
        }
    }
    return line;
}

function splitTopLevel(value, separator) {
    var result = [];
    var start = 0;
    var quote = "";
    var escaped = false;
    var depth = 0;
    for (var i = 0; i < value.length; ++i) {
        var ch = value[i];
        if (escaped) {
            escaped = false;
        } else if (quote === '"' && ch === "\\") {
            escaped = true;
        } else if (quote !== "") {
            if (ch === quote)
                quote = "";
        } else if (ch === '"' || ch === "'") {
            quote = ch;
        } else if (ch === "[" || ch === "{") {
            ++depth;
        } else if (ch === "]" || ch === "}") {
            --depth;
        } else if (ch === separator && depth === 0) {
            result.push(value.slice(start, i).trim());
            start = i + 1;
        }
    }
    result.push(value.slice(start).trim());
    return result;
}

function parseString(value) {
    if (value[0] === "'")
        return value.slice(1, -1);
    try {
        return JSON.parse(value);
    } catch (error) {
        throw new Error("invalid_string");
    }
}

function parseValue(value) {
    value = value.trim();
    if (value.length === 0)
        throw new Error("missing_value");
    if ((value[0] === '"' && value[value.length - 1] === '"')
            || (value[0] === "'" && value[value.length - 1] === "'"))
        return parseString(value);
    if (value === "true")
        return true;
    if (value === "false")
        return false;
    if (/^[+-]?\d(?:_?\d)*$/.test(value))
        return Number(value.replace(/_/g, ""));
    if (/^[+-]?(?:\d(?:_?\d)*)?\.\d(?:_?\d)*(?:[eE][+-]?\d+)?$/.test(value))
        return Number(value.replace(/_/g, ""));
    if (value[0] === "[" && value[value.length - 1] === "]") {
        var body = value.slice(1, -1).trim();
        if (body === "")
            return [];
        return splitTopLevel(body, ",").filter(function(item) { return item !== ""; }).map(parseValue);
    }
    throw new Error("unsupported_value");
}

function assignPath(root, path, value) {
    var target = root;
    for (var i = 0; i < path.length - 1; ++i) {
        var part = path[i];
        if (target[part] === undefined)
            target[part] = {};
        if (target[part] === null || Array.isArray(target[part]) || typeof target[part] !== "object")
            throw new Error("path_collision");
        target = target[part];
    }
    var key = path[path.length - 1];
    if (Object.prototype.hasOwnProperty.call(target, key))
        throw new Error("duplicate_key");
    target[key] = value;
}

function ensureTable(root, path) {
    var target = root;
    for (var i = 0; i < path.length; ++i) {
        var part = path[i];
        if (target[part] === undefined)
            target[part] = {};
        if (Array.isArray(target[part]))
            target = target[part][target[part].length - 1];
        else if (target[part] !== null && typeof target[part] === "object")
            target = target[part];
        else
            throw new Error("table_collision");
    }
    return target;
}

function appendTable(root, path) {
    var parent = ensureTable(root, path.slice(0, -1));
    var key = path[path.length - 1];
    if (parent[key] === undefined)
        parent[key] = [];
    if (!Array.isArray(parent[key]))
        throw new Error("table_collision");
    var table = {};
    parent[key].push(table);
    return table;
}

function parse(text) {
    var root = {};
    var current = root;
    var lines = String(text).replace(/\r\n?/g, "\n").split("\n");
    for (var lineNumber = 0; lineNumber < lines.length; ++lineNumber) {
        var line = stripComment(lines[lineNumber]).trim();
        if (line === "")
            continue;
        try {
            if (line.slice(0, 2) === "[[" && line.slice(-2) === "]]" ) {
                var arrayPath = line.slice(2, -2).trim().split(".");
                current = appendTable(root, arrayPath);
                continue;
            }
            if (line[0] === "[" && line[line.length - 1] === "]") {
                var tablePath = line.slice(1, -1).trim().split(".");
                current = ensureTable(root, tablePath);
                continue;
            }
            var pieces = splitTopLevel(line, "=");
            if (pieces.length !== 2 || pieces[0] === "")
                throw new Error("invalid_assignment");
            assignPath(current, pieces[0].split(".").map(function(part) { return part.trim(); }), parseValue(pieces[1]));
        } catch (error) {
            return { ok: false, code: error.message, line: lineNumber + 1, data: null };
        }
    }
    return { ok: true, code: "success", line: 0, data: root };
}
