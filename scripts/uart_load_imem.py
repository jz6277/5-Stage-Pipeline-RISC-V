#!/usr/bin/env python3
"""
Send an instruction-memory image to the Basys3 UART RX loader.

Protocol on the wire:
1. 32-bit little-endian word count
2. That many 32-bit little-endian instruction words

Input formats:
- text hex bytes, like the existing `imem_program.hex`
- raw binary
"""

from __future__ import annotations

import argparse
import math
import pathlib
import re
import struct
import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError as exc:  # pragma: no cover - runtime dependency guard
    raise SystemExit(
        "pyserial is required. Install it with: python -m pip install pyserial"
    ) from exc


HEX_BYTE_RE = re.compile(r"^[0-9a-fA-F]{1,2}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send an instruction image to the Basys3 UART loader."
    )
    parser.add_argument(
        "image",
        nargs="?",
        type=pathlib.Path,
        help="Input image file (.hex byte file or raw binary).",
    )
    parser.add_argument(
        "--port",
        help="Serial port name, for example COM4.",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=115200,
        help="UART baud rate. Must match the FPGA bitstream. Default: 115200.",
    )
    parser.add_argument(
        "--format",
        choices=("auto", "hex", "bin"),
        default="auto",
        help="Input file format. Default: auto.",
    )
    parser.add_argument(
        "--list-ports",
        action="store_true",
        help="List available serial ports and exit.",
    )
    parser.add_argument(
        "--startup-delay",
        type=float,
        default=0.2,
        help="Seconds to wait after opening the port before sending. Default: 0.2.",
    )
    return parser.parse_args()


def list_ports() -> int:
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return 0

    for port in ports:
        desc = f" - {port.description}" if port.description else ""
        print(f"{port.device}{desc}")
    return 0


def detect_format(path: pathlib.Path, requested: str) -> str:
    if requested != "auto":
        return requested

    suffix = path.suffix.lower()
    if suffix in {".hex", ".mem", ".txt"}:
        return "hex"
    return "bin"


def load_hex_bytes(path: pathlib.Path) -> bytes:
    tokens: list[str] = []
    for raw_line in path.read_text(encoding="ascii").splitlines():
        line = raw_line.split("//", 1)[0].split("#", 1)[0].strip()
        if not line:
            continue
        tokens.extend(line.split())

    if not tokens:
        raise ValueError(f"No hex byte data found in {path}")

    data = bytearray()
    for token in tokens:
        if not HEX_BYTE_RE.fullmatch(token):
            raise ValueError(f"Invalid hex byte token: {token}")
        data.append(int(token, 16))
    return bytes(data)


def load_image(path: pathlib.Path, image_format: str) -> bytes:
    if image_format == "hex":
        return load_hex_bytes(path)
    if image_format == "bin":
        return path.read_bytes()
    raise ValueError(f"Unsupported format: {image_format}")


def build_payload(image_bytes: bytes) -> bytes:
    word_count = math.ceil(len(image_bytes) / 4)
    padded = image_bytes + bytes(word_count * 4 - len(image_bytes))
    return struct.pack("<I", word_count) + padded


def main() -> int:
    args = parse_args()

    if args.list_ports:
        return list_ports()

    if args.image is None:
        raise SystemExit("Missing image path. Use --list-ports or provide an input file.")

    if not args.port:
        raise SystemExit("Missing --port. Use --list-ports to see available ports.")

    if not args.image.is_file():
        raise SystemExit(f"Image file not found: {args.image}")

    image_format = detect_format(args.image, args.format)
    image_bytes = load_image(args.image, image_format)
    payload = build_payload(image_bytes)
    word_count = len(payload[4:]) // 4

    print(f"Image: {args.image}")
    print(f"Format: {image_format}")
    print(f"Data bytes: {len(image_bytes)}")
    print(f"Word count: {word_count}")
    print(f"Port: {args.port} @ {args.baud}")

    with serial.Serial(args.port, args.baud, timeout=1) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(args.startup_delay)
        ser.write(payload)
        ser.flush()

    print("Transfer complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
