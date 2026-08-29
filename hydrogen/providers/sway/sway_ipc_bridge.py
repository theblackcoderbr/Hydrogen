#!/usr/bin/env python3
"""Small persistent Sway IPC transport for the QML provider.

The bridge owns one Unix socket, publishes normalized protocol envelopes on
stdout and accepts only structured JSON actions on stdin. It never invokes a
shell or swaymsg.
"""

import json
import os
import selectors
import socket
import struct
import sys

MAGIC = b"i3-ipc"
RUN_COMMAND = 0
GET_WORKSPACES = 1
SUBSCRIBE = 2
GET_OUTPUTS = 3
GET_TREE = 4
EVENT_MASK = 0x80000000
EVENT_WORKSPACE = EVENT_MASK | 0
EVENT_OUTPUT = EVENT_MASK | 1
EVENT_WINDOW = EVENT_MASK | 3
EVENT_SHUTDOWN = EVENT_MASK | 6


def packet(message_type, payload=b""):
    return MAGIC + struct.pack("<II", len(payload), message_type) + payload


def emit(kind, data=None):
    message = {"type": kind}
    if data is not None:
        message["data"] = data
    sys.stdout.write(json.dumps(message, separators=(",", ":"), ensure_ascii=False) + "\n")
    sys.stdout.flush()


class Bridge:
    def __init__(self, socket_path):
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.connect(socket_path)
        self.socket.setblocking(False)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.socket, selectors.EVENT_READ, "sway")
        self.selector.register(sys.stdin, selectors.EVENT_READ, "stdin")
        self.buffer = bytearray()
        self.outputs = None
        self.workspaces = None
        self.tree = None
        self.refresh_outstanding = set()
        self.refresh_pending = False

    def send(self, message_type, data=None):
        payload = b"" if data is None else json.dumps(data, separators=(",", ":")).encode("utf-8")
        self.socket.sendall(packet(message_type, payload))

    def refresh(self):
        if self.refresh_outstanding:
            self.refresh_pending = True
            return
        self.refresh_outstanding = {GET_OUTPUTS, GET_WORKSPACES, GET_TREE}
        self.send(GET_OUTPUTS)
        self.send(GET_WORKSPACES)
        self.send(GET_TREE)

    def publish_if_ready(self):
        if self.refresh_outstanding or self.outputs is None or self.workspaces is None or self.tree is None:
            return
        emit("snapshot", {"outputs": self.outputs, "workspaces": self.workspaces, "tree": self.tree})
        if self.refresh_pending:
            self.refresh_pending = False
            self.refresh()

    def parse_packets(self):
        while len(self.buffer) >= 14:
            if self.buffer[:6] != MAGIC:
                raise RuntimeError("invalid_ipc_magic")
            length, message_type = struct.unpack("<II", self.buffer[6:14])
            end = 14 + length
            if len(self.buffer) < end:
                return
            payload = bytes(self.buffer[14:end])
            del self.buffer[:end]
            data = json.loads(payload.decode("utf-8")) if payload else None
            self.handle_message(message_type, data)

    def handle_message(self, message_type, data):
        if message_type == GET_OUTPUTS:
            self.outputs = data
            self.refresh_outstanding.discard(GET_OUTPUTS)
        elif message_type == GET_WORKSPACES:
            self.workspaces = data
            self.refresh_outstanding.discard(GET_WORKSPACES)
        elif message_type == GET_TREE:
            self.tree = data
            self.refresh_outstanding.discard(GET_TREE)
        elif message_type in (EVENT_WORKSPACE, EVENT_OUTPUT, EVENT_WINDOW):
            self.refresh()
        elif message_type == EVENT_SHUTDOWN:
            emit("shutdown", data)
            raise SystemExit(0)
        elif message_type == RUN_COMMAND:
            emit("command_result", data)
        self.publish_if_ready()

    def handle_stdin(self):
        line = sys.stdin.readline()
        if line == "":
            raise SystemExit(0)
        try:
            request = json.loads(line)
            action = request.get("action")
            if action == "command" and isinstance(request.get("command"), str):
                self.send(RUN_COMMAND, request["command"])
            elif action == "refresh":
                self.refresh()
            elif action == "stop":
                raise SystemExit(0)
            else:
                emit("error", {"code": "invalid_bridge_action"})
        except (TypeError, ValueError, json.JSONDecodeError):
            emit("error", {"code": "invalid_bridge_request"})

    def run(self):
        self.send(SUBSCRIBE, ["workspace", "output", "window", "shutdown"])
        self.refresh()
        while True:
            for key, _ in self.selector.select():
                if key.data == "stdin":
                    self.handle_stdin()
                else:
                    chunk = self.socket.recv(65536)
                    if not chunk:
                        emit("disconnected")
                        return 1
                    self.buffer.extend(chunk)
                    self.parse_packets()


def main():
    socket_path = os.environ.get("SWAYSOCK") or os.environ.get("I3SOCK")
    if not socket_path:
        emit("error", {"code": "sway_socket_missing"})
        return 2
    try:
        return Bridge(socket_path).run() or 0
    except (OSError, RuntimeError, json.JSONDecodeError) as error:
        emit("error", {"code": "sway_bridge_failed", "detail": type(error).__name__})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
