# Working in this repository

This is a **Geode mod for Geometry Dash**, not a web application. The mod is
C++ compiled into a `.geode` package by CMake; there is no dev server and
nothing to open in a browser natively.

## Running it here

```bash
docker compose -f docker-compose.base44.yml up -d --build
```

* `mod-build` compiles the mod and **rebuilds automatically when sources
  change** (source files are bind-mounted; the loop polls every 5s).
* `preview` serves the build report and the compiled package on **port 3000**,
  which is what the preview pane shows. The package is also at
  `/artifacts/<id>.geode`.

The first `up` builds the toolchain image (Geode CLI, SDK, prebuilt binaries and
the Windows cross-compilation toolchain — the Windows SDK download is the slow
part). Source edits never need an image rebuild.

## Things that bite

* **Mods cannot be built natively for Linux.** Geode targets Windows, macOS,
  iOS and Android only, so the sandbox cross-compiles to Windows on Linux via
  `geode sdk install-linux` (xwin + Windows SDK). `geode sdk install-binaries
  -p linux` also resolves to the *Windows* binaries.
* `mod.json` is not optional metadata: `geode build` and the CI action both read
  its `geode` field to pick the SDK version. Invalid JSON there fails the build
  before any compilation happens. `mod-build` re-syncs the installed SDK to that
  field on startup.
* `CMakeLists.txt` must have exactly that name and spelling — a `Cmakelists.txt`
  is silently ignored and cmake then reports that the directory "does not appear
  to contain CMakeLists.txt".
* `CMakeLists.txt` globs `*.cpp` **non-recursively on purpose**: CI clones the
  SDK into the workspace (`geode sdk install "$GITHUB_WORKSPACE/geode-sdk-clone"`),
  and a recursive glob would sweep the SDK's own sources into the mod build.
* Build output lands in `build-win/` in the repository (git-ignored). Do not
  commit it.

## Verifying a change

1. Watch the `mod-build` log: `docker compose -f docker-compose.base44.yml logs -f mod-build`
2. Confirm the report on port 3000 says **Build passed**, and that the artifact
   list contains a `.geode`.
3. The same build runs on CI in `.github/workflows/c-cpp.yml`
   (`geode-sdk/build-geode-mod`) — on GitHub runners it builds for Android64;
   the sandbox cross-compiles to Windows. Both verify the same sources.
