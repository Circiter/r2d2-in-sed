# r2d2-in-sed

# Overview

A [gnu] sed script for imitating r2d2 the robot's "voice". The idea to write this strange and
useless code has come to me after I saw Kevin Boone's r2d2-voice project (written in C).

It's not a true speech-synthesizer but it can generate a well-known whisles and random notes,
as the droid form Star Wars do.

# Usage

In theory it would be sufficient to run (on an oss-compatible *nix box):
```bash
cat example.script | ./r2d2.sed > /dev/dsp
```

But in practice, due to some cryptic issue, it cannot generate white noise smoothly, hence I
suggest to use a workaround:
```bash
cat example.script | ./r2d2.sed | tr 10 '~\n' > /dev/dsp
```

(`> /dev/dsp` should be changed to an appropriate thing that works on your system.)

Supported commands (all numbers are in base 1) a sequence of which can be feed to the stdin:
```
seed <random_seed>;
glissando <direction> <initial_frequency> <final_frequency> <duration>;
tone <frequency> <duration>;
buzz <duration>;
silence <duration>;
noise <duration>;
random <lower_frequency> <upper_frequency> <duration>;
```

As usual, see `r2d2.sed` for implementation details.

References:
- [](http://en.wikipedia.org/wiki/R2-D2)
