# Dead Air internal MVP audio

This directory contains only selected, runtime-facing candidates copied from
`demos/audio_source_library/selected_mvp/`. Their provenance and licenses remain
in the source-library manifest; no runtime code references that library.

All assets carry `DEMO_ONLY` because they are audition copies rather than
mastered production audio. Several MP3 files are Freesound public previews and
must be replaced with original-quality downloads before release.

`amb_cellar_loop_FALLBACK_DEMO_ONLY.mp3` is temporarily the approved Manor bed.
The selected cellar candidate is FLAC and cannot be imported by Godot 4.7; no
local FLAC converter is available in this worktree. Replace this fallback with
a converted/cut cellar loop during final audio production.
