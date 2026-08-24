# WHOOP 5 layout-v18 R-R transport evidence

This note records the reproducible evidence behind the layout-v18 R-R conversion. It is deliberately
separate from the physiological estimator: matching two transports of the same beat can answer the wire
unit question; heart-rate plausibility cannot reliably separate a 2.4% scale difference.

## Public capture

- Release: <https://github.com/digitalerdude/noop/releases/tag/whoop5-hci-capture-2026-07-10>
- Asset: <https://github.com/digitalerdude/noop/releases/download/whoop5-hci-capture-2026-07-10/bluetoothd-hci-2026-07-10_06-09-15.redacted.pklg>
- SHA-256: `92e8fbb3e3091f6769968f1117b9626470fba80bdb348d3a37140347336fd558`

The release is redacted and public. The digest above is also published in GitHub's asset metadata.

## Reproduction

Download the named asset, verify its hash, then run:

```sh
python3 Tools/analyze-whoop5-rr-capture.py \
  bluetoothd-hci-2026-07-10_06-09-15.redacted.pklg \
  --expected-sha256 92e8fbb3e3091f6769968f1117b9626470fba80bdb348d3a37140347336fd558
```

Expected result:

```text
sha256=92e8fbb3e3091f6769968f1117b9626470fba80bdb348d3a37140347336fd558
standard_rr_values=14322
v18_rr_values=14911
v18_records_with_rr=14536
contiguous_match_start=578
matched_values=14322
mismatches=0
lag_seconds_after_clock_offset=1:7044,2:7278
```

The tool reads raw uint16 values from two places in the same PacketLogger capture:

1. the standard Bluetooth Heart Rate Measurement characteristic, where the R-R unit is defined as
   1/1024 second; and
2. WHOOP type-47 layout-v18 historical frames, before NOOP applies any conversion.

All 14,322 standard values equal a contiguous subsequence of the historical values, with no mismatches.
The capture clock is two hours ahead of the embedded strap timestamps; after subtracting that known
offset, the standard delivery lands one or two seconds later in this capture.

## Conclusion and boundary

For layout v18 in this capture, the historical field carries the same raw integers as the standard
Bluetooth R-R field. The version-local conversion in `Interpreter.swift` from 1/1024-second ticks to
rounded milliseconds is therefore supported directly. This result does not establish units for another
historical layout; v20/v21/v26 carry no R-R and WHOOP 4 v24 remains milliseconds.

The one-to-two-second lag is not a universal transport rule. A later field log contains three checkable
equal-value pairs at +3 seconds. The in-app diagnostic consequently searches integer lags from -5 through
+5 seconds and reports the distribution instead of requiring equal timestamps or claiming one fixed lag.
The scoring selector's tolerance must not be changed from these few pairs alone; the nightly census and
several additional nights should establish how often a wider boundary would retain or duplicate beats.
