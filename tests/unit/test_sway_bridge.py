import importlib.util
import json
import struct
import unittest
from pathlib import Path


BRIDGE_PATH = Path(__file__).parents[2] / "hydrogen" / "providers" / "sway" / "sway_ipc_bridge.py"
SPEC = importlib.util.spec_from_file_location("hydrogen_sway_bridge", BRIDGE_PATH)
BRIDGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRIDGE)


class SwayBridgeProtocolTests(unittest.TestCase):
    def test_packet_uses_i3_magic_and_little_endian_header(self):
        payload = json.dumps({"test": True}).encode("utf-8")
        encoded = BRIDGE.packet(BRIDGE.GET_TREE, payload)
        self.assertEqual(encoded[:6], b"i3-ipc")
        length, message_type = struct.unpack("<II", encoded[6:14])
        self.assertEqual(length, len(payload))
        self.assertEqual(message_type, BRIDGE.GET_TREE)
        self.assertEqual(encoded[14:], payload)

    def test_event_codes_retain_the_protocol_event_mask(self):
        self.assertEqual(BRIDGE.EVENT_WINDOW, 0x80000003)
        self.assertEqual(BRIDGE.EVENT_SHUTDOWN, 0x80000006)


if __name__ == "__main__":
    unittest.main()
