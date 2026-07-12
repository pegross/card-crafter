"""Generate two standalone, procedural sound-design demos.

This script intentionally has no connection to the game's audio system.  It only
writes finished WAV files into ``demos/audio`` for auditioning.
"""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 48_000
ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "demos" / "audio"


def one_pole_lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    output = np.empty_like(signal)
    state = 0.0
    for index, value in enumerate(signal):
        state += alpha * (value - state)
        output[index] = state
    return output


def highpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    return signal - one_pole_lowpass(signal, cutoff)


def bandpass(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    return highpass(one_pole_lowpass(signal, high), low)


def pan(mono: np.ndarray, position: float) -> np.ndarray:
    """Equal-power pan, where -1 is left and +1 is right."""
    angle = (position + 1.0) * math.pi / 4.0
    return np.column_stack((mono * math.cos(angle), mono * math.sin(angle)))


def add_at(destination: np.ndarray, source: np.ndarray, start_seconds: float) -> None:
    start = round(start_seconds * SAMPLE_RATE)
    end = min(len(destination), start + len(source))
    if end > start:
        destination[start:end] += source[: end - start]


def sine_sweep(length: int, start_hz: float, end_hz: float) -> np.ndarray:
    frequencies = np.geomspace(start_hz, end_hz, length)
    phase = np.cumsum(2.0 * math.pi * frequencies / SAMPLE_RATE)
    return np.sin(phase)


def soft_clip(signal: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(signal * drive) / np.tanh(drive)


def finish(signal: np.ndarray, peak: float = 0.94) -> np.ndarray:
    fade = min(round(0.018 * SAMPLE_RATE), len(signal) // 4)
    signal[:fade] *= np.linspace(0.0, 1.0, fade)[:, None]
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    signal -= np.mean(signal, axis=0, keepdims=True)
    current_peak = float(np.max(np.abs(signal)))
    if current_peak:
        signal *= peak / current_peak
    return signal


def write_wav(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(signal, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def make_tree_chop() -> np.ndarray:
    rng = np.random.default_rng(1207)
    duration = 0.88
    count = round(duration * SAMPLE_RATE)
    t = np.arange(count) / SAMPLE_RATE

    # Dense wooden body: clustered, inharmonic modes make the object feel solid
    # without giving the impact a recognizable musical pitch.
    body = np.zeros(count)
    modes = (
        (117.0, 0.30, 0.17),
        (183.0, 0.25, 0.12),
        (286.0, 0.18, 0.085),
        (421.0, 0.13, 0.060),
        (677.0, 0.09, 0.040),
        (1038.0, 0.055, 0.026),
    )
    for frequency, amplitude, decay in modes:
        phase = rng.uniform(0, 2 * math.pi)
        detune = 1.0 + 0.004 * np.sin(2 * math.pi * 7.0 * t + phase)
        body += amplitude * np.sin(2 * math.pi * frequency * detune * t + phase) * np.exp(-t / decay)

    # A short descending pressure pulse supplies the weight of the axe head.
    thump_t = t
    thump = 0.42 * sine_sweep(count, 106.0, 53.0) * np.exp(-thump_t / 0.075)

    # Fibrous noise starts bright, then leaves a warmer wooden tail.
    noise = rng.normal(0.0, 1.0, count)
    splinter = bandpass(noise, 650.0, 8200.0) * np.exp(-t / 0.032) * 0.48
    grain = bandpass(noise, 120.0, 1750.0) * np.exp(-t / 0.19) * 0.24

    # Several tiny secondary fractures keep the hit from sounding like a drum.
    cracks = np.zeros(count)
    for delay, strength, width_ms in (
        (0.010, 0.29, 2.5),
        (0.018, 0.22, 2.0),
        (0.031, 0.17, 3.2),
        (0.051, 0.10, 4.0),
    ):
        start = round(delay * SAMPLE_RATE)
        width = round(width_ms * SAMPLE_RATE / 1000.0)
        burst_t = np.arange(width) / SAMPLE_RATE
        burst = rng.normal(0.0, 1.0, width) * np.exp(-burst_t / (width_ms / 4000.0))
        cracks[start : start + width] += burst * strength
    cracks = highpass(cracks, 1100.0)

    # A very short, hard leading edge reads as metal biting into bark.
    bite_length = round(0.012 * SAMPLE_RATE)
    bite_t = np.arange(bite_length) / SAMPLE_RATE
    bite = highpass(rng.normal(0.0, 1.0, bite_length), 2900.0)
    bite *= np.exp(-bite_t / 0.0022) * 0.36

    stereo = pan(body + thump + grain, -0.04)
    stereo += pan(splinter, 0.10)
    stereo += pan(cracks, -0.16)
    add_at(stereo, pan(bite, 0.07), 0.001)

    # A sparse bark scatter adds just enough width after the central impact.
    for delay, position, strength in ((0.073, -0.65, 0.045), (0.108, 0.58, 0.035), (0.151, -0.35, 0.024)):
        length = round(0.025 * SAMPLE_RATE)
        scatter_t = np.arange(length) / SAMPLE_RATE
        scatter = bandpass(rng.normal(0.0, 1.0, length), 750, 5200)
        scatter *= np.exp(-scatter_t / 0.007) * strength
        add_at(stereo, pan(scatter, position), delay)

    return finish(soft_clip(stereo, 1.32))


def make_radio_item() -> np.ndarray:
    rng = np.random.default_rng(1936)
    duration = 3.35
    count = round(duration * SAMPLE_RATE)
    t = np.arange(count) / SAMPLE_RATE
    stereo = np.zeros((count, 2))

    # Physical switch: a hard plastic click and a small springy release.
    click_length = round(0.055 * SAMPLE_RATE)
    click_t = np.arange(click_length) / SAMPLE_RATE
    click_noise = bandpass(rng.normal(0, 1, click_length), 900, 9000)
    click = click_noise * np.exp(-click_t / 0.0032) * 0.55
    click += np.sin(2 * math.pi * 760 * click_t) * np.exp(-click_t / 0.014) * 0.18
    add_at(stereo, pan(click, -0.12), 0.035)

    # AM-like static powers up, searches, then ducks when a station resolves.
    raw_static = rng.normal(0.0, 1.0, count)
    static = bandpass(raw_static, 240.0, 6700.0)
    power_up = np.clip((t - 0.10) / 0.11, 0, 1)
    resolved = 1.0 - 0.72 * np.clip((t - 1.12) / 0.34, 0, 1)
    tail = 1.0 - 0.75 * np.clip((t - 2.92) / 0.25, 0, 1)
    static_env = power_up * resolved * tail
    static *= static_env * (0.13 + 0.035 * np.sin(2 * math.pi * 13.0 * t))
    stereo += pan(static, 0.02)

    # Tuning heterodyne: unstable whistles cross through the static.
    tune_start = round(0.20 * SAMPLE_RATE)
    tune_end = round(1.42 * SAMPLE_RATE)
    tune_count = tune_end - tune_start
    tune_t = np.arange(tune_count) / SAMPLE_RATE
    tune_freq = 520 + 1720 * (tune_t / tune_t[-1]) + 170 * np.sin(2 * math.pi * 2.8 * tune_t)
    tune_phase = np.cumsum(2 * math.pi * tune_freq / SAMPLE_RATE)
    tune_env = np.sin(np.linspace(0, math.pi, tune_count)) ** 1.4
    tune = (np.sin(tune_phase) + 0.23 * np.sin(2.02 * tune_phase)) * tune_env * 0.11
    tune *= 0.72 + 0.28 * np.sin(2 * math.pi * 9.0 * tune_t)
    add_at(stereo, pan(tune, -0.05), 0.20)

    # A tiny fictional station ident emerges: four warm, band-limited notes with
    # wow/flutter and mild saturation, suggesting an old speaker rather than UI music.
    station = np.zeros(count)
    notes = ((1.16, 392.00, 0.34), (1.48, 493.88, 0.30), (1.78, 440.00, 0.28), (2.08, 587.33, 0.58))
    for start_seconds, frequency, note_duration in notes:
        length = round(note_duration * SAMPLE_RATE)
        note_t = np.arange(length) / SAMPLE_RATE
        wow = 1.0 + 0.007 * np.sin(2 * math.pi * 4.4 * note_t + 0.4)
        phase = np.cumsum(2 * math.pi * frequency * wow / SAMPLE_RATE)
        tone = np.sin(phase) + 0.34 * np.sin(2 * phase + 0.2) + 0.12 * np.sin(3 * phase)
        attack = np.clip(note_t / 0.025, 0, 1)
        release = np.clip((note_duration - note_t) / 0.12, 0, 1)
        tone *= attack * release * 0.12
        start = round(start_seconds * SAMPLE_RATE)
        station[start : start + length] += tone
    station = one_pole_lowpass(highpass(soft_clip(station, 2.1), 260), 2900)

    # Quiet 60 Hz electrical hum and imperfect reception sell the radio object.
    reception_env = np.clip((t - 0.92) / 0.35, 0, 1) * (1.0 - np.clip((t - 2.88) / 0.28, 0, 1))
    hum = (np.sin(2 * math.pi * 60 * t) + 0.35 * np.sin(2 * math.pi * 120 * t)) * reception_env * 0.018
    dropout = 1.0 - 0.38 * np.exp(-((t - 2.02) / 0.018) ** 2)
    stereo += pan((station + hum) * dropout, 0.0)

    # Matching switch-off tick.
    off_length = round(0.035 * SAMPLE_RATE)
    off_t = np.arange(off_length) / SAMPLE_RATE
    off = bandpass(rng.normal(0, 1, off_length), 1000, 7500) * np.exp(-off_t / 0.0025) * 0.31
    add_at(stereo, pan(off, 0.10), 3.06)

    return finish(soft_clip(stereo, 1.18), peak=0.91)


def main() -> None:
    outputs = {
        OUTPUT_DIR / "tree_chop_demo.wav": make_tree_chop(),
        OUTPUT_DIR / "radio_item_demo.wav": make_radio_item(),
    }
    for path, signal in outputs.items():
        write_wav(path, signal)
        print(f"Wrote {path.relative_to(ROOT)} ({len(signal) / SAMPLE_RATE:.2f}s)")


if __name__ == "__main__":
    main()
