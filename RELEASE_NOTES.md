# Parallax 0.1.0 — reconstructed vertical-slice build

This is a private reconstruction milestone, not a claim that every original subsystem is complete.

Playable systems include:

- recovered C64 flight dynamics, altitude, landing gear and landing transition;
- SHIP SUPPLY, disembark and return-to-flight;
- outdoor and interior on-foot movement/collision;
- COMPUTABANK, COMPUTASHOP, KARD and regional password progression;
- natural scientist stun → generated KARD → escort/capture loop;
- recovered transporters;
- progression-5 / GLOBE final transporter;
- original score qualification, congratulatory ending, five-character name entry and title return;
- desktop keyboard controls;
- touchscreen controls and virtual-keyboard terminal input.

Current known reconstruction gaps are tracked in REA/project documentation. The largest gameplay gap for this build is natural flight combat/enemy score production: the ending consumes the authentic score state, but the remaining verified projectile/destructible and moving-object award events still need to be wired into ordinary play.

Build targets:

- Windows x86-64;
- WebAssembly/Web;
- Android arm64 debug-signed sideload APK.

The source repository intentionally excludes original game media and generated C64-derived runtime assets. Private local builds contain the generated runtime resources required to play.
