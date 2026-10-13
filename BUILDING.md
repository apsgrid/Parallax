# Building Parallax

Parallax is a Godot 4.7 reconstruction of the 1986 C64 game. The repository contains the reverse-engineering notes, deterministic reference models, tests, extractors and Godot source.

## Important asset boundary

Original disk/tape/program images and generated artwork/world data are intentionally **not** committed.

A fresh checkout therefore needs an authorised local copy of the original game media before the runtime data and derived C64 artwork can be regenerated. Do not add the original D64/T64/TAP/NIB/PRG files or generated C64 asset directories to Git.

The local reconstruction currently uses:

- `Unpacked/playable_ram.bin` as the corrected canonical 64 KiB RAM image;
- `Godot/data/world_480.json`;
- `Godot/data/interior_runtime.json`;
- generated world/interior tile atlases;
- generated on-foot, encounter and flight-object sprite PNGs.

These generated runtime assets are included in local exports but remain excluded from source control.

## Regenerating local runtime assets

From the project root on a prepared reconstruction machine:

```powershell
python extract_world.py
python generate_tile_atlases.py
python extract_interior_runtime.py
python generate_interior_tile_atlases.py
python generate_ground_sprites.py
python generate_encounter_sprites.py
python generate_flight_object_sprites.py
```

Run the canonical verification scripts before exporting.

## Godot

The current project targets Godot **4.7.2** using the GL compatibility renderer.

Export templates for the same Godot version are required.

The checked-in presets are:

- `Windows` — Windows x86-64 release executable;
- `Web` — non-threaded WebAssembly build;
- `Android` — arm64 Android APK.

## Android toolchain

Android export requires:

- Java/JDK;
- Android SDK platform-tools;
- an Android platform/build-tools accepted by Godot;
- the standard local Android debug keystore for the sideload build.

On Ichabod the validated toolchain uses Android SDK platform 35+ and a Godot 4.7.2 Android template. The exported APK currently reports minimum SDK 24 and target SDK 36.

No release signing key is stored in this repository. The build script deliberately emits a **debug-signed sideload APK**.

## Build command

```powershell
.\build_release.ps1 -Target all -Package
```

Optional environment variables:

- `GODOT_BIN` — Godot console/editor executable;
- `ANDROID_SDK_ROOT` or `ANDROID_HOME`;
- `JAVA_HOME`.

Individual targets:

```powershell
.\build_release.ps1 -Target windows
.\build_release.ps1 -Target web
.\build_release.ps1 -Target android
```

Artifacts are written below ignored `Builds/`.

With `-Package`, the release directory contains:

- `Parallax-Windows-x64.zip`;
- `Parallax-Web.zip`;
- `Parallax-Android-arm64.apk`;
- `SHA256SUMS.txt`.

## Controls

Desktop keyboard:

- Left/Right or A/D — turn/move;
- Down/S — climb/down depending on mode;
- Up/W — dive/up depending on mode;
- Z — FIRE/action;
- Space — landing gear;
- Tab — recovered speed/velocity mode;
- F7 — shield status toggle;
- Enter — KARD/PASS status;
- Y/N — KARD take/decline prompts;
- keyboard text — terminal KARD/password input.

Touchscreen builds expose an on-screen D-pad, FIRE, GEAR, SPEED, SHIELD and STATUS buttons. KARD prompts get dedicated Yes/No buttons. Terminal input uses a touch text field and the platform virtual keyboard while still feeding the same recovered simulation models.

## Validation

Before a release, run all Godot model/integration suites, the static canonical-RAM verifiers, a headless scene boot, and then smoke-test the exported Windows executable. Validate the Web files over HTTP and verify the APK signature/package metadata.
