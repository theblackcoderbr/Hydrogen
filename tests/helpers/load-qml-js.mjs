import fs from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

export function loadQmlJavaScript(path) {
    const filename = path instanceof URL ? fileURLToPath(path) : String(path);
    const source = fs.readFileSync(filename, "utf8").replace(/^\.pragma library\s*$/m, "");
    const context = vm.createContext({
        JSON, Object, Array, Number, String, Boolean, Math, Date, RegExp,
        Error, isFinite
    });
    new vm.Script(source, { filename }).runInContext(context);
    return context;
}
