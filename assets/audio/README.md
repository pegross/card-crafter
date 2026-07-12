# Dead Air internal MVP audio

This directory contains only selected, runtime-facing candidates copied from
`demos/audio_source_library/selected_mvp/`. Their provenance and licenses remain
in the source-library manifest; no runtime code references that library.

All assets carry `DEMO_ONLY` because they are audition copies rather than
mastered production audio. Several MP3 files are Freesound public previews and
must be replaced with original-quality downloads before release.

`alarm_clock_ring_PIXABAY_LICENSE_DEMO_ONLY.mp3` is SoundsForYou's recorded
"Old Mechanic Alarm Clock" from Pixabay. Runtime limits the 22-second source to
a 2.5-second wake burst. Its source and license are recorded in
`demos/sourced_audio/SOURCE_LICENSES.md`.

`alarm_clock_wind_01_CC0_DEMO_ONLY.wav` and
`alarm_clock_wind_02_CC0_DEMO_ONLY.wav` are BMacZero's CC0 recordings of winding
a small clock. They rotate when the player sets the alarm; provenance is in the
same source manifest.

`amb_cellar_loop_FALLBACK_DEMO_ONLY.mp3` is temporarily the approved Manor bed.
The selected cellar candidate is FLAC and cannot be imported by Godot 4.7; no
local FLAC converter is available in this worktree. Replace this fallback with
a converted/cut cellar loop during final audio production.
