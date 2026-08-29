import QtQuick
import QtTest
import "../../hydrogen/logic/Toml.js" as Toml

TestCase {
    name: "Toml"

    function test_parsesHydrogenSyntax() {
        const result = Toml.parse("[general]\ndebug = true\nvalues = [1, 2, 3]\n\n[[bar.app_matching.rules]]\napp_id = \"org.example.App\"");
        verify(result.ok);
        compare(result.data.general.debug, true);
        compare(result.data.general.values.length, 3);
        compare(result.data.bar.app_matching.rules[0].app_id, "org.example.App");
    }

    function test_preservesCommentCharactersInsideStrings() {
        const result = Toml.parse("[value]\ntext = \"color #ffffff\" # comment");
        verify(result.ok);
        compare(result.data.value.text, "color #ffffff");
    }

    function test_rejectsDuplicateKeys() {
        const result = Toml.parse("value = 1\nvalue = 2");
        verify(!result.ok);
        compare(result.code, "duplicate_key");
        compare(result.line, 2);
    }

    function test_rejectsUnsupportedValues() {
        const result = Toml.parse("created = 2026-08-28");
        verify(!result.ok);
        compare(result.code, "unsupported_value");
    }
}
