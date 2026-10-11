#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${STUDIO_REVIEW_OUTPUT_DIR:-$REPO_ROOT/.build/studio-review}"
REVIEW_HOME="$OUTPUT_DIR/home"
VALID_WORKSPACE="${STUDIO_REVIEW_WORKSPACE:-$REPO_ROOT/Fixtures/studio-demo-workspace}"
INVALID_WORKSPACE="${STUDIO_REVIEW_INVALID_WORKSPACE:-$REPO_ROOT/Fixtures/studio-demo-invalid-workspace}"
DEFAULTS_SUITE="${STUDIO_REVIEW_DEFAULTS_SUITE:-PersonaKitStudioReview}"
APP_NAME="${STUDIO_REVIEW_APP_NAME:-PersonaKitStudio}"
MAX_WINDOW_WIDTH="${STUDIO_REVIEW_MAX_WINDOW_WIDTH:-1180}"
MAX_WINDOW_HEIGHT="${STUDIO_REVIEW_MAX_WINDOW_HEIGHT:-820}"

cleanup() {
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  HOME="$REVIEW_HOME" defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
}

trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
mkdir -p "$REVIEW_HOME"
mkdir -p "$OUTPUT_DIR/empty-global/.personakit/Packs"
find "$OUTPUT_DIR" -maxdepth 1 \
  \( -name "*.png" -o -name "*.log" -o -name "*.accessibility.txt" -o -name "*.bounds.txt" -o -name "*.geometry.json" -o -name "review-notes.md" \) \
  -delete
HOME="$REVIEW_HOME" defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
HOME="$REVIEW_HOME" defaults write "$DEFAULTS_SUITE" \
  "studio.recentWorkspaces" \
  -string "[\"$VALID_WORKSPACE\",\"$INVALID_WORKSPACE\"]"

cd "$REPO_ROOT"

swift build --product PersonaKitStudio
STUDIO_EXECUTABLE="$(swift build --show-bin-path)/PersonaKitStudio"

capture_state() {
  local name="$1"
  shift

  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$REVIEW_HOME/Library/Saved Application State"

  printf "Launching %s for %s\n" "$APP_NAME" "$name" > "$OUTPUT_DIR/$name.log"

  if [ "${STUDIO_REVIEW_NO_AUTO_ACTIVATE:-0}" = "1" ]; then
    HOME="$REVIEW_HOME" \
      PERSONAKIT_STUDIO_GLOBAL_SCOPE_PATH="$OUTPUT_DIR/empty-global/.personakit" \
      PERSONAKIT_STUDIO_USER_DEFAULTS_SUITE_NAME="$DEFAULTS_SUITE" \
      "$STUDIO_EXECUTABLE" --no-auto-activate "$@" >> "$OUTPUT_DIR/$name.log" 2>&1 &
  else
    HOME="$REVIEW_HOME" \
      PERSONAKIT_STUDIO_GLOBAL_SCOPE_PATH="$OUTPUT_DIR/empty-global/.personakit" \
      PERSONAKIT_STUDIO_USER_DEFAULTS_SUITE_NAME="$DEFAULTS_SUITE" \
      "$STUDIO_EXECUTABLE" "$@" >> "$OUTPUT_DIR/$name.log" 2>&1 &
  fi

  local pid="$!"

  sleep "${STUDIO_REVIEW_CAPTURE_DELAY:-4}"
  osascript -e "tell application \"$APP_NAME\" to activate" >/dev/null 2>&1 || true
  sleep 1

  capture_running_window "$name" "$pid"
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
}

capture_running_window() {
  local name="$1"
  local pid="${2:?missing launched Studio process id}"

  local window_bounds=""
  local attempt

  for attempt in {1..10}; do
    if window_bounds="$(osascript <<APPLESCRIPT
tell application "System Events"
  set matchingProcesses to every process whose unix id is $pid
  if matchingProcesses is {} then error "$APP_NAME process $pid not found"
  tell item 1 of matchingProcesses
    if not (exists window 1) then error "$APP_NAME window 1 not found"
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
    local process_state="unknown"

    if [ -n "$pid" ]; then
      if kill -0 "$pid" >/dev/null 2>&1; then
        process_state="running"
      else
        process_state="not running"
      fi
    fi

    echo "error: $APP_NAME window 1 not found for $name" >&2
    echo "error: review log: $OUTPUT_DIR/$name.log" >&2
    echo "error: launched process state: $process_state" >&2
    exit 1
  fi

  printf "%s\n" "$window_bounds" > "$OUTPUT_DIR/$name.bounds.txt"
  require_window_fits "$name" "$window_bounds"
  screencapture -x -R "$window_bounds" "$OUTPUT_DIR/$name.png"
  osascript > "$OUTPUT_DIR/$name.accessibility.txt" 2>&1 <<APPLESCRIPT || true
on describeElement(elementRef, indent)
  tell application "System Events"
    set roleText to "missing role"
    set nameText to "missing name"
    set valueText to "missing value"
    set descriptionText to "missing description"
    set helpText to "missing help"
    set identifierText to "missing identifier"
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
      set identifierText to value of attribute "AXIdentifier" of elementRef as text
    end try
    try
      set enabledText to enabled of elementRef as text
    end try

    set outputText to indent & roleText & " | name=" & nameText & " | value=" & valueText & " | description=" & descriptionText & " | help=" & helpText & " | identifier=" & identifierText & " | enabled=" & enabledText

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
    set matchingProcesses to every process whose unix id is $pid
    if matchingProcesses is {} then error "$APP_NAME process $pid not found"
    tell item 1 of matchingProcesses
      if not (exists window 1) then error "$APP_NAME window 1 not found"
      return my describeElement(window 1, "")
    end tell
  end tell
end timeout
APPLESCRIPT
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

require_accessibility_text_count() {
  local path="$1"
  local expected="$2"
  local expected_count="$3"
  local actual_count

  actual_count="$(grep -Fc "$expected" "$path" || true)"

  if [ "$actual_count" -ne "$expected_count" ]; then
    echo "error: expected accessibility text '$expected' $expected_count times in $path, got $actual_count" >&2
    exit 1
  fi
}

require_window_fits() {
  local name="$1"
  local bounds="$2"
  local x
  local y
  local width
  local height

  IFS="," read -r x y width height <<< "$bounds"

  if [ "$width" -gt "$MAX_WINDOW_WIDTH" ]; then
    echo "error: expected $name window width <= $MAX_WINDOW_WIDTH, got $width" >&2
    exit 1
  fi

  if [ "$height" -gt "$MAX_WINDOW_HEIGHT" ]; then
    echo "error: expected $name window height <= $MAX_WINDOW_HEIGHT, got $height" >&2
    exit 1
  fi
}

capture_state "01-no-workspace"
capture_state "02-loaded-public-workspace" --workspace "$VALID_WORKSPACE"
capture_state "03-library-list" --workspace "$VALID_WORKSPACE" --section personas
capture_state \
  "04-validation-results-valid" \
  --workspace "$VALID_WORKSPACE" \
  --section validation-results
capture_state \
  "05-validation-results-error" \
  --workspace "$INVALID_WORKSPACE" \
  --section validation-results

cat > "$OUTPUT_DIR/review-notes.md" <<NOTES
# PersonaKit Studio Review

Generated by \`make studio-review\`.

Captured files:

- \`01-no-workspace.png\`: no workspace selected with seeded recent workspaces.
- \`02-loaded-public-workspace.png\`: valid public starter workspace.
- \`03-library-list.png\`: Library list seeded from the public starter workspace.
- \`04-validation-results-valid.png\`: Validation Results report for the public starter workspace.
- \`05-validation-results-error.png\`: Validation Results for a deterministic invalid workspace.
- \`*.accessibility.txt\`: best-effort recursive accessibility hierarchy for review aid only.
- \`*.bounds.txt\`: captured window x,y,width,height, guarded against oversized launch frames.

Manual review checklist:

- The no-workspace state makes the next action discoverable.
- The loaded workspace shows a Sessions preview without private context.
- The Library list is readable and scoped to public starter content.
- Validation Results explains what a valid workspace checked.
- Validation Results expose the deterministic error in the invalid workspace.
- Primary controls have clear accessible labels and roles.
NOTES

for state in \
  "01-no-workspace" \
  "02-loaded-public-workspace" \
  "03-library-list" \
  "04-validation-results-valid" \
  "05-validation-results-error"
do
  require_non_empty_file "$OUTPUT_DIR/$state.png"
  require_non_empty_file "$OUTPUT_DIR/$state.log"
  require_non_empty_file "$OUTPUT_DIR/$state.accessibility.txt"
  require_non_empty_file "$OUTPUT_DIR/$state.bounds.txt"
done

require_non_empty_file "$OUTPUT_DIR/review-notes.md"

require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Welcome to PersonaKit Studio"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Read a Contract"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Open a folder that contains a .personakit directory"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Recent Workspaces"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "$VALID_WORKSPACE"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "$INVALID_WORKSPACE"
require_accessibility_text_count "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "description=Hide Sidebar" 1
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Workspace Status"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "description=Inspector"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "description=Help"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "solo-dev"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Search Sessions"
require_accessibility_text_count "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "description=Hide Sidebar" 1
reject_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Session Inspector"
reject_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Relationship Map"
require_accessibility_text "$OUTPUT_DIR/03-library-list.accessibility.txt" "solo-developer"
require_accessibility_text "$OUTPUT_DIR/03-library-list.accessibility.txt" "description=Inspector"
require_accessibility_text "$OUTPUT_DIR/03-library-list.accessibility.txt" "description=Help"
require_accessibility_text "$OUTPUT_DIR/03-library-list.accessibility.txt" "Search Personas"
reject_accessibility_text "$OUTPUT_DIR/03-library-list.accessibility.txt" "Persona Preview"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "No validation issues reported"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "Validated Areas"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "Search Validation"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "description=Inspector"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "description=Help"
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "Skills"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "Validation Results"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "2 issues need review"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "1 affected entity"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "1 affected file"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "description=Inspector"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "description=Help"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "broken-missing-persona"
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "Missing persona id."
require_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "Open Session"
reject_accessibility_text "$OUTPUT_DIR/05-validation-results-error.accessibility.txt" "Validated Areas"
echo "Studio review artifacts written to $OUTPUT_DIR"
