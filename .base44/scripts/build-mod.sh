#!/bin/sh
# Rebuilds the Geode mod whenever the source changes and writes a build report
# that the sandbox preview serves on port 3000.
#
# There is no dev server in this project: the mod is compiled into a .geode
# package, so "live reload" here means rebuilding on source changes.
set -u

WORK="${WORK:-/work}"
OUT="${OUT:-/out}"
ARTIFACTS="$OUT/artifacts"

mkdir -p "$OUT" "$ARTIFACTS"

# ---------------------------------------------------------------- SDK version

# mod.json pins the SDK version the mod compiles against; keep the installed
# SDK in sync with it (the CLI action on CI does the same thing).
# The CLI prints its version inside a log line, so pull the number out of it.
WANT_RAW="$(jq -r '.geode // empty' "$WORK/mod.json" 2>/dev/null || true)"
WANT="$(printf '%s' "$WANT_RAW" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
HAVE="$(geode sdk version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
if [ -n "$WANT" ]; then
    if [ "$HAVE" != "$WANT" ]; then
        echo "Syncing Geode SDK to $WANT (installed: ${HAVE:-none})..."
        geode sdk update "$WANT" && geode sdk install-binaries -p win
    else
        echo "Geode SDK $HAVE matches mod.json."
    fi
else
    echo "Note: mod.json has no usable 'geode' version field; using the installed SDK."
fi

# ------------------------------------------------------------------- report

html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

artifact_links() {
    found=0
    for f in "$ARTIFACTS"/*.geode; do
        [ -e "$f" ] || continue
        found=1
        name="$(basename "$f")"
        size="$(du -h "$f" | cut -f1)"
        printf '<li><a href="artifacts/%s">%s</a> <span class="muted">(%s)</span></li>\n' \
            "$(printf '%s' "$name" | html_escape)" "$(printf '%s' "$name" | html_escape)" "$(printf '%s' "$size" | html_escape)"
    done
    [ "$found" = 1 ] || printf '<li class="muted">No .geode package produced yet.</li>\n'
}

write_report() {
    state="$1"   # building | passed | failed
    headline="$2"
    finished="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    {
        cat <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AI in Editor - mod build</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 2.5rem 1.25rem; font: 16px/1.6 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
         background: #0f1115; color: #e6e8ec; }
  main { max-width: 62rem; margin: 0 auto; }
  h1 { margin: 0 0 .25rem; font-size: 1.6rem; letter-spacing: -.02em; }
  .sub { margin: 0 0 1.75rem; color: #949aa8; }
  .card { background: #171a21; border: 1px solid #262b36; border-radius: 12px; padding: 1.25rem 1.4rem; margin-bottom: 1.25rem; }
  .state { display: inline-flex; align-items: center; gap: .55rem; font-weight: 600; letter-spacing: .01em; }
  .dot { width: .62rem; height: .62rem; border-radius: 50%; display: inline-block; }
  .building .dot { background: #e0a83e; animation: pulse 1.2s ease-in-out infinite; }
  .passed  .dot { background: #3fbf7f; }
  .failed  .dot { background: #e05561; }
  .building .state { color: #e0a83e; }
  .passed .state { color: #3fbf7f; }
  .failed .state { color: #e05561; }
  @keyframes pulse { 0%,100% { opacity: 1 } 50% { opacity: .35 } }
  h2 { font-size: .8rem; text-transform: uppercase; letter-spacing: .09em; color: #949aa8; margin: 0 0 .75rem; }
  ul { margin: 0; padding-left: 1.1rem; }
  a { color: #7fb3ff; }
  pre { margin: 0; max-height: 26rem; overflow: auto; background: #0b0d11; border: 1px solid #262b36;
        border-radius: 8px; padding: 1rem; font-size: .82rem; line-height: 1.5; white-space: pre-wrap; word-break: break-word; }
  .muted { color: #949aa8; }
  .meta { color: #949aa8; font-size: .85rem; margin-top: .5rem; }
</style>
</head>
<body>
<main>
  <h1>AI in Editor</h1>
  <p class="sub">Geode mod for Geometry Dash - build status</p>

  <div class="card $state">
    <span class="state"><span class="dot"></span>$headline</span>
    <p class="meta">Last build: $finished &middot; target: Windows (cross-compiled) &middot; SDK: $(printf '%s' "$WANT" | html_escape)</p>
  </div>

  <div class="card">
    <h2>Artifacts</h2>
    <ul>
HTML
        artifact_links
        cat <<HTML
    </ul>
  </div>

  <div class="card">
    <h2>Build log</h2>
    <pre>
HTML
        if [ -f "$OUT/build.log" ]; then
            tail -n 60 "$OUT/build.log" | html_escape
        else
            printf 'Waiting for the first build...'
        fi
        cat <<HTML
</pre>
  </div>
</main>
</body>
</html>
HTML
    } > "$OUT/index.html.tmp"
    mv "$OUT/index.html.tmp" "$OUT/index.html"
}

# -------------------------------------------------------------------- build

run_build() {
    echo "=== build $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
    : > "$OUT/build.log"
    write_report "building" "Building..."

    if (cd "$WORK" && geode build -p windows) >> "$OUT/build.log" 2>&1; then
        find "$WORK" -maxdepth 3 -name '*.geode' -not -path "$WORK/.git/*" \
            -exec cp -f {} "$ARTIFACTS/" \; 2>/dev/null || true
        echo "Build succeeded."
        write_report "passed" "Build passed"
    else
        echo "Build failed."
        write_report "failed" "Build failed"
    fi
}

snapshot() {
    find "$WORK" -maxdepth 3 \
        \( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' -o -name 'CMakeLists.txt' -o -name 'mod.json' \) \
        -not -path "$WORK/.git/*" -not -path "$WORK/build*" \
        -printf '%p %T@\n' 2>/dev/null | sort | md5sum | cut -d' ' -f1
}

write_report "building" "Starting up..."
LAST=""
while :; do
    CURRENT="$(snapshot)"
    if [ "$CURRENT" != "$LAST" ]; then
        LAST="$CURRENT"
        run_build
        LAST="$(snapshot)"
    fi
    sleep 5
done
