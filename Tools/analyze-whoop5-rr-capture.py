#!/usr/bin/env python3
"""Reproduce the WHOOP 5 layout-v18 R-R unit check from an Apple PacketLogger capture.

The tool compares raw uint16 values from the Bluetooth Heart Rate Measurement characteristic
(whose R-R unit is defined as 1/1024 second) with raw uint16 values inside WHOOP layout-v18
historical frames. It does not apply either conversion, infer physiology, or modify the capture.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator


@dataclass(frozen=True)
class AttValue:
    capture_second: int
    handle: int
    value: bytes


def packetlogger_records(data: bytes) -> Iterator[tuple[int, int, bytes]]:
    """Yield (capture second, record type, payload) from Apple's big-endian pklg format."""
    offset = 0
    while offset < len(data):
        if offset + 13 > len(data):
            raise ValueError(f"truncated PacketLogger header at byte {offset}")
        length = struct.unpack_from(">I", data, offset)[0]
        if length < 9 or offset + 4 + length > len(data):
            raise ValueError(f"invalid PacketLogger record length {length} at byte {offset}")
        capture_second = struct.unpack_from(">I", data, offset + 4)[0]
        record_type = data[offset + 12]
        payload = data[offset + 13 : offset + 4 + length]
        yield capture_second, record_type, payload
        offset += 4 + length


def att_values(data: bytes) -> Iterator[AttValue]:
    """Extract ATT notification/indication values from inbound/outbound HCI ACL records."""
    for capture_second, record_type, payload in packetlogger_records(data):
        if record_type not in (2, 3) or len(payload) < 8:
            continue
        acl_length = struct.unpack_from("<H", payload, 2)[0]
        acl = payload[4 : 4 + acl_length]
        if len(acl) < 5:
            continue
        l2cap_length, channel = struct.unpack_from("<HH", acl, 0)
        att = acl[4 : 4 + l2cap_length]
        if channel != 0x0004 or len(att) < 3 or att[0] not in (0x1B, 0x1D):
            continue
        yield AttValue(capture_second, struct.unpack_from("<H", att, 1)[0], att[3:])


def standard_rr_values(value: bytes) -> list[int]:
    """Return raw R-R uint16s from one Bluetooth Heart Rate Measurement value."""
    if len(value) < 2:
        return []
    flags = value[0]
    offset = 1 + (2 if flags & 0x01 else 1)
    if flags & 0x08:  # Energy Expended present.
        offset += 2
    if not flags & 0x10:  # R-R Interval absent.
        return []
    result: list[int] = []
    while offset + 1 < len(value):
        result.append(struct.unpack_from("<H", value, offset)[0])
        offset += 2
    return result


def historical_v18_values(value: bytes) -> tuple[int, list[int]] | None:
    """Return (embedded unix second, raw R-R uint16s) from one WHOOP type-47 v18 frame."""
    if len(value) < 32 or value[0] != 0xAA or value[8] != 47 or value[9] != 18:
        return None
    unix_second = struct.unpack_from("<I", value, 15)[0]
    count = min(value[23], 4)
    result = []
    for index in range(count):
        raw = struct.unpack_from("<H", value, 24 + index * 2)[0]
        if raw > 0:
            result.append(raw)
    return unix_second, result


def contiguous_start(haystack: list[int], needle: list[int]) -> int | None:
    """KMP search so a full-night comparison remains linear."""
    if not needle:
        return 0
    prefix = [0] * len(needle)
    for index in range(1, len(needle)):
        matched = prefix[index - 1]
        while matched and needle[index] != needle[matched]:
            matched = prefix[matched - 1]
        if needle[index] == needle[matched]:
            matched += 1
        prefix[index] = matched

    matched = 0
    for index, value in enumerate(haystack):
        while matched and value != needle[matched]:
            matched = prefix[matched - 1]
        if value == needle[matched]:
            matched += 1
        if matched == len(needle):
            return index - len(needle) + 1
    return None


def parse_int(value: str) -> int:
    return int(value, 0)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--expected-sha256")
    parser.add_argument("--standard-handle", type=parse_int, default=0x22)
    parser.add_argument("--historical-handle", type=parse_int, default=0x9A3)
    parser.add_argument(
        "--capture-clock-offset-seconds",
        type=int,
        default=7200,
        help="capture epoch minus strap epoch in this capture (default: 7200)",
    )
    args = parser.parse_args()

    data = args.capture.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if args.expected_sha256 and digest.lower() != args.expected_sha256.lower():
        raise SystemExit(f"sha256 mismatch: expected {args.expected_sha256}, got {digest}")

    standard: list[tuple[int, int]] = []
    historical: list[tuple[int, int]] = []
    historical_record_count = 0
    for item in att_values(data):
        if item.handle == args.standard_handle:
            standard.extend((item.capture_second, raw) for raw in standard_rr_values(item.value))
        elif item.handle == args.historical_handle:
            parsed = historical_v18_values(item.value)
            if parsed is not None:
                embedded_second, values = parsed
                if values:
                    historical_record_count += 1
                    historical.extend((embedded_second, raw) for raw in values)

    standard_raw = [raw for _, raw in standard]
    historical_raw = [raw for _, raw in historical]
    start = contiguous_start(historical_raw, standard_raw)
    if start is None:
        raise SystemExit("the standard R-R sequence is not a contiguous subsequence of v18 R-R")

    matched_historical = historical[start : start + len(standard)]
    mismatch_count = sum(
        standard_item[1] != historical_item[1]
        for standard_item, historical_item in zip(standard, matched_historical)
    )
    lag_counts = collections.Counter(
        capture_second - embedded_second - args.capture_clock_offset_seconds
        for (capture_second, _), (embedded_second, _) in zip(standard, matched_historical)
    )

    print(f"sha256={digest}")
    print(f"standard_rr_values={len(standard)}")
    print(f"v18_rr_values={len(historical)}")
    print(f"v18_records_with_rr={historical_record_count}")
    print(f"contiguous_match_start={start}")
    print(f"matched_values={len(matched_historical)}")
    print(f"mismatches={mismatch_count}")
    print("lag_seconds_after_clock_offset=" + ",".join(
        f"{lag}:{count}" for lag, count in sorted(lag_counts.items())
    ))
    return 0 if mismatch_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
