#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${STUDIO_REVIEW_OUTPUT_DIR:-$REPO_ROOT/Artifacts/studio-review}"
VALID_WORKSPACE="${STUDIO_REVIEW_WORKSPACE:-$REPO_ROOT/Fixtures/studio-demo-workspace}"
INVALID_WORKSPACE="${STUDIO_REVIEW_INVALID_WORKSPACE:-$REPO_ROOT/Fixtures/studio-demo-invalid-workspace}"
DEFAULTS_SUITE="${STUDIO_REVIEW_DEFAULTS_SUITE:-PersonaKitStudioReview}"

cleanup() {
  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
  defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
}

trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/home"
mkdir -p "$OUTPUT_DIR/empty-global/.personakit/Packs"
find "$OUTPUT_DIR" -maxdepth 1 \
  \( -name "*.png" -o -name "*.log" -o -name "*.accessibility.txt" -o -name "review-notes.md" \) \
  -delete
defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
defaults write "$DEFAULTS_SUITE" \
  "studio.recentWorkspaces.v1" \
  -string "[\"$VALID_WORKSPACE\",\"$INVALID_WORKSPACE\"]"

cd "$REPO_ROOT"

swift build --product PersonaKitStudio
STUDIO_EXECUTABLE="$(swift build --show-bin-path)/PersonaKitStudio"

capture_state() {
  local name="$1"
  shift

  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$OUTPUT_DIR/home/Library/Saved Application State"

  printf "Launching PersonaKitStudio for %s\n" "$name" > "$OUTPUT_DIR/$name.log"

  if [ "${STUDIO_REVIEW_NO_AUTO_ACTIVATE:-0}" = "1" ]; then
    HOME="$OUTPUT_DIR/home" \
      PERSONAKIT_STUDIO_GLOBAL_SCOPE_PATH="$OUTPUT_DIR/empty-global/.personakit" \
      PERSONAKIT_STUDIO_USER_DEFAULTS_SUITE_NAME="$DEFAULTS_SUITE" \
      "$STUDIO_EXECUTABLE" --no-auto-activate "$@" >> "$OUTPUT_DIR/$name.log" 2>&1 &
  else
    HOME="$OUTPUT_DIR/home" \
      PERSONAKIT_STUDIO_GLOBAL_SCOPE_PATH="$OUTPUT_DIR/empty-global/.personakit" \
      PERSONAKIT_STUDIO_USER_DEFAULTS_SUITE_NAME="$DEFAULTS_SUITE" \
      "$STUDIO_EXECUTABLE" "$@" >> "$OUTPUT_DIR/$name.log" 2>&1 &
  fi

  local pid="$!"

  sleep "${STUDIO_REVIEW_CAPTURE_DELAY:-4}"
  osascript -e 'tell application "PersonaKitStudio" to activate' >/dev/null 2>&1 || true
  sleep 1

  local window_bounds=""
  local attempt

  for attempt in {1..10}; do
    if window_bounds="$(osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "PersonaKitStudio"
    if not (exists window 1) then error "PersonaKitStudio window 1 not found"
    set windowPosition to position of window 1
    set windowSize to size of window 1
    return (item 1 of windowPosition as text) & "," & (item 2 of windowPosition as text) & "," & (item 1 of windowSize as text) & "," & (item 2 of windowSize as text)
  end tell
end tell
APPLESCRIPT
    )"; then
      break
    fi

    sleep 1
  done

  if [ -z "$window_bounds" ]; then
    echo "error: PersonaKitStudio window 1 not found for $name" >&2
    exit 1
  fi

  screencapture -x -R "$window_bounds" "$OUTPUT_DIR/$name.png"
  osascript > "$OUTPUT_DIR/$name.accessibility.txt" 2>&1 <<'APPLESCRIPT' || true
on describeElement(elementRef, indent)
  tell application "System Events"
    set roleText to "missing role"
    set nameText to "missing name"
    set valueText to "missing value"
    set descriptionText to "missing description"
    set helpText to "missing help"
    set enabledText to "missing enabled"

    try
      set roleText to role of elementRef as text
    end try
    try
      set nameText to name of elementRef as text
    end try
    try
      set valueText to value of elementRef as text
    end try
    try
      set descriptionText to description of elementRef as text
    end try
    try
      set helpText to help of elementRef as text
    end try
    try
      set enabledText to enabled of elementRef as text
    end try

    set outputText to indent & roleText & " | name=" & nameText & " | value=" & valueText & " | description=" & descriptionText & " | help=" & helpText & " | enabled=" & enabledText

    try
      set childElements to UI elements of elementRef
      repeat with childElement in childElements
        set outputText to outputText & linefeed & my describeElement(childElement, indent & "  ")
      end repeat
    end try

    return outputText
  end tell
end describeElement

with timeout of 10 seconds
  tell application "System Events"
    tell process "PersonaKitStudio"
      if not (exists window 1) then error "PersonaKitStudio window 1 not found"
      return my describeElement(window 1, "")
    end tell
  end tell
end timeout
APPLESCRIPT
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
}

require_non_empty_file() {
  local path="$1"

  if [ ! -s "$path" ]; then
    echo "error: expected non-empty review artifact at $path" >&2
    exit 1
  fi
}

require_accessibility_text() {
  local path="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$path"; then
    echo "error: expected accessibility text '$expected' in $path" >&2
    exit 1
  fi
}

reject_accessibility_text() {
  local path="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$path"; then
    echo "error: unexpected accessibility text '$unexpected' in $path" >&2
    exit 1
  fi
}

capture_state "01-no-workspace"
capture_state "02-loaded-public-workspace" --workspace "$VALID_WORKSPACE"
capture_state "03-library-list" --workspace "$VALID_WORKSPACE" --section personas
capture_state \
  "04-validation-results-error" \
  --workspace "$INVALID_WORKSPACE" \
  --section validation-results
capture_state \
  "05-relationship-map" \
  --workspace "$VALID_WORKSPACE" \
  --section relationship-map

cat > "$OUTPUT_DIR/review-notes.md" <<NOTES
# PersonaKit Studio Review

Generated by \`make studio-review\`.

Artifacts:

- \`01-no-workspace.png\`: no workspace selected with seeded recent workspaces.
- \`02-loaded-public-workspace.png\`: valid public starter workspace.
- \`03-library-list.png\`: Library list seeded from the public starter workspace.
- \`04-validation-results-error.png\`: Validation Results for a deterministic invalid workspace.
- \`05-relationship-map.png\`: Relationship Map for the public starter workspace.
- \`*.accessibility.txt\`: best-effort recursive accessibility hierarchy for review aid only.

Manual review checklist:

- The no-workspace state makes the next action discoverable.
- The loaded workspace shows a Sessions preview without private context.
- The Library list is readable and scoped to public starter content.
- Validation Results expose the deterministic error in the invalid workspace.
- Relationship Map renders from the public starter workspace.
- Primary controls have clear accessible labels and roles.
NOTES

for state in \
  "01-no-workspace" \
  "02-loaded-public-workspace" \
  "03-library-list" \
  "04-validation-results-error" \
  "05-relationship-map"
do
  require_non_empty_file "$OUTPUT_DIR/$state.png"
  require_non_empty_file "$OUTPUT_DIR/$state.log"
  require_non_empty_file "$OUTPUT_DIR/$state.accessibility.txt"
done

require_non_empty_file "$OUTPUT_DIR/review-notes.md"

require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Welcome to PersonaKit Studio"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Inspect PersonaKit Roots"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Open Workspace..."
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Recent Workspaces"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "$VALID_WORKSPACE"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "$INVALID_WORKSPACE"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Workspace Summary"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "solo-dev-v1"
require_accessibility_text "$OUTPUT_DIR/03-library-list.accessibility.txt" "solo-developer"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-error.accessibility.txt" "Validation Results"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-error.accessibility.txt" "broken-missing-persona"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-error.accessibility.txt" "Missing persona id."
require_accessibility_text "$OUTPUT_DIR/05-relationship-map.accessibility.txt" "Relationship Map"
require_accessibility_text "$OUTPUT_DIR/05-relationship-map.accessibility.txt" "Resolved"
require_accessibility_text "$OUTPUT_DIR/05-relationship-map.accessibility.txt" "solo-developer"
require_accessibility_text "$OUTPUT_DIR/05-relationship-map.accessibility.txt" "default kit"
reject_accessibility_text "$OUTPUT_DIR/05-relationship-map.accessibility.txt" "No nodes"

echo "Studio review artifacts written to $OUTPUT_DIR"
