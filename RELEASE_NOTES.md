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

Current known reconstruction gaps are tracked in REA/project documentation. Natural resident laser fire and destructible-terrain +15 score production are now wired into ordinary play, so the ending's score qualification can be reached without test injection. The remaining flight-combat gap is the authentic three-slot moving-object spawn/type/motion scheduler; its hit geometry and 2*object_state score formula are verified and tested, but synthetic enemies are deliberately not substituted.

Build targets:

- Windows x86-64;
- WebAssembly/Web;
- Android arm64 debug-signed sideload APK.

The source repository intentionally excludes original game media and generated C64-derived runtime assets. Private local builds contain the generated runtime resources required to play.
