import QtQuick
import QtTest
import "../../hydrogen/config/Defaults.js" as Defaults
import "../../hydrogen/logic/Toml.js" as Toml

TestCase {
    name: "Defaults"

    function test_allGeneratedTomlParses() {
        const templates = Defaults.templates();
        compare(Object.keys(templates).length, 7);
        Object.keys(templates).forEach(path => verify(Toml.parse(templates[path]).ok, path));
    }

    function test_requiredFoundationDefaults() {
        const configuration = Defaults.configuration();
        compare(configuration.logging.deduplication_seconds, 30);
        compare(configuration.persistence.write_debounce_ms, 250);
        compare(configuration.persistence.shutdown_timeout_ms, 2000);
        compare(configuration.launcher.history_limit, 100);
        compare(configuration.notifications.history_limit, 50);
    }
}
