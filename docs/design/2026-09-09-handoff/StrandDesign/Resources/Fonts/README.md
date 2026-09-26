# Fonts

Goes at `Packages/StrandDesign/Sources/StrandDesign/Resources/Fonts/`.

`Package.swift` already declares `resources: [.process("Resources")]`, so it needs no edit.
**The app project does** — see `spec/13-branch-corrected-foundation.md` §"The fonts", step 1.

## What belongs here

| File | State | Faces it must expose |
| --- | --- | --- |
| `Outfit.ttf` | **binary — drop it in** | Outfit-ExtraLight · Light · Regular · Medium |
| `InstrumentSans.ttf` | **binary — drop it in** | InstrumentSans-Regular · Medium · SemiBold |
| `InstrumentSerif-Regular.ttf` | **binary — drop it in** | InstrumentSerif-Regular |
| `InstrumentSerif-Italic.ttf` | **binary — drop it in** | InstrumentSerif-Italic |
| `OFL-Outfit.txt` | ships with this pack | — |
| `OFL-InstrumentSans.txt` | ships with this pack | — |
| `OFL-InstrumentSerif.txt` | ships with this pack | — |

Four font files, **three licences**: Outfit and Instrument Sans are variable and cover four and
three faces respectively; Instrument Serif has **no variable build** and ships as two static cuts,
which is why it has one licence for two files.

## The licences are not optional and not tidiness

SIL OFL §2 requires the copyright notice and the licence to travel with every copy of the font,
bundled or not. §5 requires the whole distribution to stay under the OFL. A fork that builds from
source with the serif cuts present and `OFL-InstrumentSerif.txt` absent is a redistribution
violation — which is what it was until 7 September, when the file was written. A package resource
bundle is exactly where such a fork looks.

## Why not `StrandiOS/Resources/Fonts`

`NoopSpecType.registerFonts()` looks in `Bundle.module`, which is the **package** bundle: it cannot
see the app target's resources, so registration finds nothing there no matter what the files are
named. And `NOOPiOSWidgets` links `StrandDesign` without linking the app, so a Charge widget built
against app-target fonts renders in San Francisco even once the app itself is fine.

Delete the files from `StrandiOS/Resources/Fonts`, remove their `UIAppFonts` entries from the
`properties:` block in `project.yml`, remove any app-target resource reference to that folder, then
`xcodegen generate`. Leaving the old entries in means the same faces register twice by two
different mechanisms — `UIAppFonts` and `CTFontManagerRegisterFontsForURL` — and which one wins is a
build-order accident.

## Registration happens **twice**

`Bundle.module` is per-process and the widget is a separate process. Call
`NoopSpecType.registerFonts()` from both `StrandiOSApp.init()` and the widget bundle's `@main`
`init()`. It is idempotent and cheap. Skipping the second is how the widget renders in San
Francisco while the app looks right — and widget snapshots are taken by the system when nobody is
watching, so it is not a bug you notice quickly.

## Registration order

Register by **filename**, then validate the **faces** — the order the first version had backwards.
It looked for a `.ttf` named after each of the **nine** declared PostScript names, found none (two of
the four files are variable and none is named after a face), never called
`CTFontManagerRegisterFontsForURL`, and then asserted on a font that had not been given a chance to
register. Nine faces, four files, seven named instances inside the two variable ones — those are
three different counts of three different things, and conflating them is what broke it. Registration is per *file*; `Font.custom` asks per *face*.
