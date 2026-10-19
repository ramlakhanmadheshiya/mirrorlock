# Mirrorlock — Audio

All music and sound effects in `assets/audio/music/` and `assets/audio/sfx/` are
**original and fully synthesized** by `tools/synth_audio.py`, using only the
Python standard library. There are no samples, recordings or third-party
material. They are released with the project under CC0 terms.

Format: 16-bit PCM WAV, mono; effects at 44100 Hz, music at 22050 Hz.

```sh
python3 tools/synth_audio.py
```

The script is deterministic (fixed seeds): every rerun produces identical files.

## Effects

| File | Used for | How it is made |
|---|---|---|
| `zip.wav` | a group escaping | a rising sine sweep (520 → 2,400 Hz) with filtered noise that brightens as it goes |
| `chime.wav` | twins escaping together | two bells a fifth apart (C6 + G6) struck together, a soft octave on top; pitched up the pentatonic as moves add up |
| `bump.wav` | a blocked move | a falling low sine thud with a short noise rattle |
| `heart.wav`, `error.wav` | losing a heart | a falling minor third in a soft triangle wave |
| `crumble.wav` | a stone breaking | seven short bursts of filtered noise, getting quieter |
| `hint.wav` | a hint | a quick run of five bell notes |
| `undo.wav` | Undo | a short falling sine sweep |
| `complete.wav` | a level cleared | a seven-note bell arpeggio over a warm pad |
| `fail.wav` | out of hearts | three falling bells over a minor pad |
| `coin.wav`, `unlock.wav`, `click.wav`, `tap.wav`, `open.wav` | rewards and UI | short bells, plucks and a noise swell |

## Music

`menu.wav` (32 s, 72 BPM, F major I–vi–IV–V) and `play.wav` (40 s, 64 BPM,
C major) are pentatonic bell melodies over detuned pads with a small Schroeder
reverb. Each loop is rendered with a tail that is folded back onto the start,
so ringing notes carry across the loop point seamlessly; `audio.gd` loops the
whole file.
