.pragma library

function configuration() {
    return {
        general: { language: "pt_BR", debug: false },
        terminal: { command: [] },
        logging: { deduplication_seconds: 30, summary_seconds: 300, error_limit: 50 },
        persistence: { write_debounce_ms: 250, shutdown_timeout_ms: 2000 },
        appearance: { opacity: 0.92, animation_duration_ms: 150 },
        bar: { height: 44, app_matching: { rules: [] } },
        integrations: { session: { reboot_command: [], poweroff_command: [] } },
        launcher: { result_limit: 20, history_limit: 100, history_days: 30 },
        notifications: { history_limit: 50, history_days: 7 },
        osd: { timeout_ms: 3000, volume_step: 5, brightness_step: 5 }
    };
}

function templates() {
    return {
        "config.toml": "# Hydrogen global configuration. Keys and comments are intentionally in English.\n[general]\nlanguage = \"pt_BR\"\ndebug = false\n\n[terminal]\n# Empty enables automatic terminal selection.\ncommand = []\n\n[logging]\ndeduplication_seconds = 30\nsummary_seconds = 300\nerror_limit = 50\n\n[persistence]\nwrite_debounce_ms = 250\nshutdown_timeout_ms = 2000\n",
        "components/appearance.toml": "# Visual defaults.\n[appearance]\nopacity = 0.92\nanimation_duration_ms = 150\n",
        "components/bar.toml": "# Bottom bar and exact application identity rules.\n[bar]\nheight = 44\n\n# Rules are evaluated in declaration order and use exact matches.\n# [[bar.app_matching.rules]]\n# app_id = \"example-app\"\n# desktop_entry = \"org.example.Application\"\n# Accepted match keys: sandbox_app_id, app_id, wm_class, wm_instance.\n# Accepted identity keys: desktop_entry, name, icon.\n",
        "components/integrations.toml": "# Empty arrays enable automatic backend selection.\n[integrations.session]\nreboot_command = []\npoweroff_command = []\n",
        "components/launcher.toml": "# Launcher limits and retention.\n[launcher]\nresult_limit = 20\nhistory_limit = 100\nhistory_days = 30\n",
        "components/notifications.toml": "# Notification history retention.\n[notifications]\nhistory_limit = 50\nhistory_days = 7\n",
        "components/osd.toml": "# On-screen display behavior.\n[osd]\ntimeout_ms = 3000\nvolume_step = 5\nbrightness_step = 5\n"
    };
}

function example() {
    var files = templates();
    return "# Complete Hydrogen configuration example.\n\n" + files["config.toml"]
        + "\n" + files["components/appearance.toml"]
        + "\n" + files["components/bar.toml"]
        + "\n" + files["components/integrations.toml"]
        + "\n" + files["components/launcher.toml"]
        + "\n" + files["components/notifications.toml"]
        + "\n" + files["components/osd.toml"];
}
