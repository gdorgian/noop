# Draft: message to @ryanbr about the fork

Post as a comment on #1118, or open a Discussion. Not an issue — it isn't a bug report.

---

Hi — context on where the 5.0/MG reports I've been filing are coming from, since it's turning
into a steady stream and it seems fairer to say so up front than to keep dropping findings
without explaining the source.

I maintain a personal fork (`gdorgian/noop`, branch `whoop5-fork`) narrowed to a single
configuration: **one WHOOP 5.0/MG, one iPhone, feeding Apple Health**. No Android, no macOS
app, no 4.0 paths, no watch. It exists because that is the only setup I actually use, and a
narrow target makes it cheap to instrument things a general build has to be careful about.

**It is not a competing distribution.** I'm not publishing releases, not inviting users, and
not looking to split effort. Everything general I find, I'd rather send here — which is what
#1363, #1365, #1366 and #1331 have been.

What the fork has that might be useful upstream:

- **A live diagnostic path.** The strap log mirrors to stderr behind an env flag, so a cabled
  device streams `hrv diag`, funnels and BLE state in real time via
  `devicectl … --console --environment-variables '{"NOOP_LOG_STDOUT":"1"}'`. This is what
  turned the clock finding from a guess into a measurement — I could watch rows land under
  the IDENTITY ref as it happened. Happy to send it as a PR if you want it; it's off by
  default and costs one Bool test per log line.

- **A 5.0/MG GET_CLOCK correlation.** The 4.0 notify branch parses the reply; the 5/MG branch
  never did, so GET_CLOCK was sent and retried and its answer dropped. Every historical
  offload on my strap decoded under IDENTITY for ~14 nights. Frame layout came from
  `b-nnett/goose`'s decoder (cmd @10, seq @11, result @12, u32 LE seconds then u32 LE
  subseconds @32768/s from @13) — the same shape NOOP already *sends* in SET_CLOCK. Verified
  on device: correlation lands on the first retry with a 2 s offset, and rows now land
  `clock ref in sync`.

  I have not sent this as a PR yet because I want a night of data behind it first, and
  because it touches a path I can only test on one strap. If you'd rather have it early and
  imperfect, say so and I'll open it.

- **A 5.0 vs 4.0 divergence on #1118.** Details in my comment there, but the short version:
  my over-count looks like yours and isn't the same mechanism, so a de-dup validated only on
  4.0 data may not generalise.

What I'd find useful from you, whenever convenient — no urgency:

1. Whether you want 5.0-specific findings on #1118 or split into their own issues. I've been
   piling onto #1118 and it may be getting crowded.
2. Whether the stderr log mirror is something you'd take, or whether you'd rather diagnostics
   stayed file-export only.
3. Whether there's 5.0/MG work you'd like a second pair of hands and a real strap on. I have
   continuous wear and can capture more or less anything on request.

Thanks for the project, and for the review on the PRs so far — the 4.0 column trace on #1367
and the read-only write-set guard on #1371 were both better than what I sent you.
