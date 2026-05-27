#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${STUDIO_REVIEW_OUTPUT_DIR:-$REPO_ROOT/.build/studio-review}"
VALID_WORKSPACE="${STUDIO_REVIEW_WORKSPACE:-$REPO_ROOT/Fixtures/studio-demo-workspace}"
INVALID_WORKSPACE="${STUDIO_REVIEW_INVALID_WORKSPACE:-$REPO_ROOT/Fixtures/studio-demo-invalid-workspace}"
DEFAULTS_SUITE="${STUDIO_REVIEW_DEFAULTS_SUITE:-PersonaKitStudioReview}"
MAX_WINDOW_WIDTH="${STUDIO_REVIEW_MAX_WINDOW_WIDTH:-1180}"
MAX_WINDOW_HEIGHT="${STUDIO_REVIEW_MAX_WINDOW_HEIGHT:-820}"
RELATIONSHIP_GEOMETRY_FILE="$OUTPUT_DIR/relationship-map-current.geometry.json"

cleanup() {
  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
  defaults delete "$DEFAULTS_SUITE" >/dev/null 2>&1 || true
}

trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/home"
mkdir -p "$OUTPUT_DIR/empty-global/.personakit/Packs"
find "$OUTPUT_DIR" -maxdepth 1 \
  \( -name "*.png" -o -name "*.log" -o -name "*.accessibility.txt" -o -name "*.bounds.txt" -o -name "*.geometry.json" -o -name "review-notes.md" \) \
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

  capture_running_window "$name"
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
}

capture_running_window() {
  local name="$1"

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

  printf "%s\n" "$window_bounds" > "$OUTPUT_DIR/$name.bounds.txt"
  require_window_fits "$name" "$window_bounds"
  screencapture -x -R "$window_bounds" "$OUTPUT_DIR/$name.png"
  osascript > "$OUTPUT_DIR/$name.accessibility.txt" 2>&1 <<'APPLESCRIPT' || true
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
    tell process "PersonaKitStudio"
      if not (exists window 1) then error "PersonaKitStudio window 1 not found"
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

copy_relationship_geometry() {
  local name="$1"

  require_non_empty_file "$RELATIONSHIP_GEOMETRY_FILE"
  cp "$RELATIONSHIP_GEOMETRY_FILE" "$OUTPUT_DIR/$name.geometry.json"
}

relationship_map_node_identifier() {
  local key="$1"

  python3 - "$key" <<'PY'
import sys

raw_value = sys.argv[1]
slug_parts = []
last_separator = False

for character in raw_value.lower():
    if "a" <= character <= "z" or "0" <= character <= "9":
        slug_parts.append(character)
        last_separator = False
    elif not last_separator:
        slug_parts.append("-")
        last_separator = True

slug = "".join(slug_parts).strip("-") or "unknown"
hash_value = 2166136261

for byte in raw_value.encode("utf-8"):
    hash_value = ((hash_value ^ byte) * 16777619) & 0xFFFFFFFF

print(f"relationship-map-node-{slug}-{hash_value:08x}")
PY
}

require_relationship_geometry_attachment() {
  local path="$1"
  local node_key="$2"

  python3 - "$path" "$node_key" <<'PY'
import json
import math
import sys

path = sys.argv[1]
node_key = sys.argv[2]
tolerance = 1.5

with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

routes = payload.get("routes", [])
matching_routes = [
    route for route in routes
    if route.get("fromKey") == node_key or route.get("toKey") == node_key
]

if not matching_routes:
    raise SystemExit(f"error: no route geometry for {node_key} in {path}")

def assert_close(label, actual, expected):
    if math.fabs(actual - expected) > tolerance:
        raise SystemExit(
            f"error: {label} expected {expected:.2f}, got {actual:.2f} in {path}"
        )

for route in matching_routes:
    if route.get("fromKey") == node_key:
        frame = route["sourceFrame"]
        point = route["startPoint"]
        target_frame = route["targetFrame"]
        expected_x = frame["maxX"] if target_frame["midX"] >= frame["midX"] else frame["minX"]
        assert_close(f"{node_key} source x", point["x"], expected_x)
        assert_close(f"{node_key} source y", point["y"], frame["midY"])

    if route.get("toKey") == node_key:
        frame = route["targetFrame"]
        point = route["endPoint"]
        source_frame = route["sourceFrame"]
        expected_x = frame["minX"] if frame["midX"] >= source_frame["midX"] else frame["maxX"]
        assert_close(f"{node_key} target x", point["x"], expected_x)
        assert_close(f"{node_key} target y", point["y"], frame["midY"])
PY
}

require_relationship_geometry_moved() {
  local baseline_path="$1"
  local dragged_path="$2"
  local node_key="$3"
  local minimum_delta="$4"

  python3 - "$baseline_path" "$dragged_path" "$node_key" "$minimum_delta" <<'PY'
import json
import math
import sys

baseline_path = sys.argv[1]
dragged_path = sys.argv[2]
node_key = sys.argv[3]
minimum_delta = float(sys.argv[4])

def load_node_mid_y(path):
    with open(path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    for route in payload.get("routes", []):
        if route.get("fromKey") == node_key:
            return route["sourceFrame"]["midY"]
        if route.get("toKey") == node_key:
            return route["targetFrame"]["midY"]

    raise SystemExit(f"error: no route geometry for {node_key} in {path}")

baseline_mid_y = load_node_mid_y(baseline_path)
dragged_mid_y = load_node_mid_y(dragged_path)
delta = dragged_mid_y - baseline_mid_y

if delta < minimum_delta:
    raise SystemExit(
        f"error: expected {node_key} to move down at least {minimum_delta:.2f}pt, got {delta:.2f}pt"
    )
PY
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

element_center_by_identifier() {
  local identifier="$1"

  osascript <<APPLESCRIPT
on findElementByIdentifier(elementRef, targetIdentifier)
  tell application "System Events"
    try
      set elementIdentifier to value of attribute "AXIdentifier" of elementRef as text
      if elementIdentifier is targetIdentifier then return elementRef
    end try

    try
      set childElements to UI elements of elementRef
      repeat with childElement in childElements
        set matchedElement to my findElementByIdentifier(childElement, targetIdentifier)
        if matchedElement is not missing value then return matchedElement
      end repeat
    end try

    return missing value
  end tell
end findElementByIdentifier

with timeout of 10 seconds
  tell application "System Events"
    tell process "PersonaKitStudio"
      if not (exists window 1) then error "PersonaKitStudio window 1 not found"
      set matchedElement to my findElementByIdentifier(window 1, "$identifier")
      if matchedElement is missing value then error "AXIdentifier not found: $identifier"

      set elementPosition to position of matchedElement
      set elementSize to size of matchedElement
      set centerX to (item 1 of elementPosition) + ((item 1 of elementSize) / 2)
      set centerY to (item 2 of elementPosition) + ((item 2 of elementSize) / 2)

      return (centerX as integer as text) & "," & (centerY as integer as text)
    end tell
  end tell
end timeout
APPLESCRIPT
}

press_element_by_identifier() {
  local identifier="$1"

  osascript >/dev/null <<APPLESCRIPT
on findElementByIdentifier(elementRef, targetIdentifier)
  tell application "System Events"
    try
      set elementIdentifier to value of attribute "AXIdentifier" of elementRef as text
      if elementIdentifier is targetIdentifier then return elementRef
    end try

    try
      set childElements to UI elements of elementRef
      repeat with childElement in childElements
        set matchedElement to my findElementByIdentifier(childElement, targetIdentifier)
        if matchedElement is not missing value then return matchedElement
      end repeat
    end try

    return missing value
  end tell
end findElementByIdentifier

with timeout of 10 seconds
  tell application "System Events"
    tell process "PersonaKitStudio"
      if not (exists window 1) then error "PersonaKitStudio window 1 not found"
      set matchedElement to my findElementByIdentifier(window 1, "$identifier")
      if matchedElement is missing value then error "AXIdentifier not found: $identifier"
      perform action "AXPress" of matchedElement
    end tell
  end tell
end timeout
APPLESCRIPT
}

drag_between_points() {
  local from_x="$1"
  local from_y="$2"
  local to_x="$3"
  local to_y="$4"

  swift - "$from_x" "$from_y" "$to_x" "$to_y" <<'SWIFT'
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 5,
  let fromX = Double(arguments[1]),
  let fromY = Double(arguments[2]),
  let toX = Double(arguments[3]),
  let toY = Double(arguments[4])
else {
  fputs("usage: drag_between_points from_x from_y to_x to_y\n", stderr)
  exit(2)
}

let source = CGEventSource(stateID: .hidSystemState)
let start = CGPoint(x: fromX, y: fromY)
let end = CGPoint(x: toX, y: toY)
let steps = 24

func post(
  _ type: CGEventType,
  at point: CGPoint
) {
  guard
    let event = CGEvent(
      mouseEventSource: source,
      mouseType: type,
      mouseCursorPosition: point,
      mouseButton: .left
    )
  else {
    fputs("error: failed to create CGEvent\n", stderr)
    exit(1)
  }

  event.post(tap: .cghidEventTap)
}

post(.mouseMoved, at: start)
usleep(80_000)
post(.leftMouseDown, at: start)
usleep(80_000)

for step in 1...steps {
  let progress = Double(step) / Double(steps)
  let point = CGPoint(
    x: fromX + (toX - fromX) * progress,
    y: fromY + (toY - fromY) * progress
  )

  post(.leftMouseDragged, at: point)
  usleep(12_000)
}

post(.leftMouseUp, at: end)
SWIFT
}

drag_element_by_identifier() {
  local identifier="$1"
  local delta_x="$2"
  local delta_y="$3"
  local center
  local from_x
  local from_y

  center="$(element_center_by_identifier "$identifier")"
  IFS="," read -r from_x from_y <<< "$center"

  drag_between_points \
    "$from_x" \
    "$from_y" \
    "$((from_x + delta_x))" \
    "$((from_y + delta_y))"
}

capture_relationship_map_drag_review() {
  local persona_identifier
  local directive_identifier
  persona_identifier="$(relationship_map_node_identifier "persona:solo-developer")"
  directive_identifier="$(relationship_map_node_identifier "directive:small-cli-change")"

  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$OUTPUT_DIR/home/Library/Saved Application State"
  rm -f "$RELATIONSHIP_GEOMETRY_FILE"

  printf "Launching PersonaKitStudio for relationship map drag review\n" \
    > "$OUTPUT_DIR/07-relationship-map-drag-baseline.log"

  HOME="$OUTPUT_DIR/home" \
    PERSONAKIT_STUDIO_GLOBAL_SCOPE_PATH="$OUTPUT_DIR/empty-global/.personakit" \
    PERSONAKIT_STUDIO_REVIEW_GEOMETRY_FILE="$RELATIONSHIP_GEOMETRY_FILE" \
    PERSONAKIT_STUDIO_USER_DEFAULTS_SUITE_NAME="$DEFAULTS_SUITE" \
    "$STUDIO_EXECUTABLE" \
    --workspace "$VALID_WORKSPACE" \
    --section relationship-map \
    >> "$OUTPUT_DIR/07-relationship-map-drag-baseline.log" 2>&1 &

  local pid="$!"

  sleep "${STUDIO_REVIEW_CAPTURE_DELAY:-4}"
  osascript -e 'tell application "PersonaKitStudio" to activate' >/dev/null 2>&1 || true
  sleep 1

  capture_running_window "07-relationship-map-drag-baseline"
  copy_relationship_geometry "07-relationship-map-drag-baseline"
  cp "$OUTPUT_DIR/07-relationship-map-drag-baseline.log" \
    "$OUTPUT_DIR/08-relationship-map-drag-persona.log"
  cp "$OUTPUT_DIR/07-relationship-map-drag-baseline.log" \
    "$OUTPUT_DIR/09-relationship-map-drag-directive.log"

  drag_element_by_identifier \
    "$persona_identifier" \
    0 \
    300
  sleep 1
  capture_running_window "08-relationship-map-drag-persona"
  copy_relationship_geometry "08-relationship-map-drag-persona"

  press_element_by_identifier "relationship-map-reset-layout"
  sleep 1

  drag_element_by_identifier \
    "$directive_identifier" \
    0 \
    300
  sleep 1
  capture_running_window "09-relationship-map-drag-directive"
  copy_relationship_geometry "09-relationship-map-drag-directive"

  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  osascript -e 'tell application "PersonaKitStudio" to quit' >/dev/null 2>&1 || true
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
capture_state \
  "06-relationship-map" \
  --workspace "$VALID_WORKSPACE" \
  --section relationship-map
capture_relationship_map_drag_review

cat > "$OUTPUT_DIR/review-notes.md" <<NOTES
# PersonaKit Studio Review

Generated by \`make studio-review\`.

Captured files:

- \`01-no-workspace.png\`: no workspace selected with seeded recent workspaces.
- \`02-loaded-public-workspace.png\`: valid public starter workspace.
- \`03-library-list.png\`: Library list seeded from the public starter workspace.
- \`04-validation-results-valid.png\`: Validation Results report for the public starter workspace.
- \`05-validation-results-error.png\`: Validation Results for a deterministic invalid workspace.
- \`06-relationship-map.png\`: Relationship Map for the public starter workspace.
- \`07-relationship-map-drag-baseline.png\`: Relationship Map baseline for deterministic drag review.
- \`08-relationship-map-drag-persona.png\`: Relationship Map after dragging the Persona node downward.
- \`09-relationship-map-drag-directive.png\`: Relationship Map after resetting and dragging the Directive node downward.
- \`*.accessibility.txt\`: best-effort recursive accessibility hierarchy for review aid only.
- \`*.bounds.txt\`: captured window x,y,width,height, guarded against oversized launch frames.

Manual review checklist:

- The no-workspace state makes the next action discoverable.
- The loaded workspace shows a Sessions preview without private context.
- The Library list is readable and scoped to public starter content.
- Validation Results explains what a valid workspace checked.
- Validation Results expose the deterministic error in the invalid workspace.
- Relationship Map renders from the public starter workspace.
- Relationship Map drag captures show connected lines tracking dragged nodes without unrelated route jumps.
- Primary controls have clear accessible labels and roles.
NOTES

for state in \
  "01-no-workspace" \
  "02-loaded-public-workspace" \
  "03-library-list" \
  "04-validation-results-valid" \
  "05-validation-results-error" \
  "06-relationship-map" \
  "07-relationship-map-drag-baseline" \
  "08-relationship-map-drag-persona" \
  "09-relationship-map-drag-directive"
do
  require_non_empty_file "$OUTPUT_DIR/$state.png"
  require_non_empty_file "$OUTPUT_DIR/$state.log"
  require_non_empty_file "$OUTPUT_DIR/$state.accessibility.txt"
  require_non_empty_file "$OUTPUT_DIR/$state.bounds.txt"
done

require_non_empty_file "$OUTPUT_DIR/review-notes.md"

RELATIONSHIP_DIRECTIVE_IDENTIFIER="$(relationship_map_node_identifier "directive:small-cli-change")"
RELATIONSHIP_PERSONA_IDENTIFIER="$(relationship_map_node_identifier "persona:solo-developer")"

for state in \
  "07-relationship-map-drag-baseline" \
  "08-relationship-map-drag-persona" \
  "09-relationship-map-drag-directive"
do
  require_non_empty_file "$OUTPUT_DIR/$state.geometry.json"
done

require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Welcome to PersonaKit Studio"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Inspect PersonaKit Roots"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Open Workspace..."
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "Recent Workspaces"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "$VALID_WORKSPACE"
require_accessibility_text "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "$INVALID_WORKSPACE"
require_accessibility_text_count "$OUTPUT_DIR/01-no-workspace.accessibility.txt" "description=Hide Sidebar" 1
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Workspace Status"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "description=Inspector"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "description=Help"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "solo-dev-v1"
require_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Search Sessions"
require_accessibility_text_count "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "description=Hide Sidebar" 1
reject_accessibility_text "$OUTPUT_DIR/02-loaded-public-workspace.accessibility.txt" "Session Inspector"
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
require_accessibility_text "$OUTPUT_DIR/04-validation-results-valid.accessibility.txt" "No references or intents in this workspace"
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
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "Relationship Map"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "Search Relationship Map"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "description=Inspector"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "description=Help"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "Resolved"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "solo-developer"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "default kit"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "identifier=relationship-map-focus-selected-session"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "identifier=relationship-map-canvas"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "identifier=$RELATIONSHIP_DIRECTIVE_IDENTIFIER"
require_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "identifier=$RELATIONSHIP_PERSONA_IDENTIFIER"
reject_accessibility_text "$OUTPUT_DIR/06-relationship-map.accessibility.txt" "No nodes"

for state in \
  "07-relationship-map-drag-baseline" \
  "08-relationship-map-drag-persona" \
  "09-relationship-map-drag-directive"
do
  require_accessibility_text "$OUTPUT_DIR/$state.accessibility.txt" "Relationship Map"
  require_accessibility_text "$OUTPUT_DIR/$state.accessibility.txt" "identifier=relationship-map-canvas"
  require_accessibility_text "$OUTPUT_DIR/$state.accessibility.txt" "identifier=$RELATIONSHIP_DIRECTIVE_IDENTIFIER"
  require_accessibility_text "$OUTPUT_DIR/$state.accessibility.txt" "identifier=$RELATIONSHIP_PERSONA_IDENTIFIER"
  reject_accessibility_text "$OUTPUT_DIR/$state.accessibility.txt" "No nodes"
done

require_accessibility_text \
  "$OUTPUT_DIR/08-relationship-map-drag-persona.accessibility.txt" \
  "identifier=relationship-map-reset-layout"
require_accessibility_text \
  "$OUTPUT_DIR/09-relationship-map-drag-directive.accessibility.txt" \
  "identifier=relationship-map-reset-layout"

require_relationship_geometry_attachment \
  "$OUTPUT_DIR/08-relationship-map-drag-persona.geometry.json" \
  "persona:solo-developer"
require_relationship_geometry_moved \
  "$OUTPUT_DIR/07-relationship-map-drag-baseline.geometry.json" \
  "$OUTPUT_DIR/08-relationship-map-drag-persona.geometry.json" \
  "persona:solo-developer" \
  240
require_relationship_geometry_attachment \
  "$OUTPUT_DIR/09-relationship-map-drag-directive.geometry.json" \
  "directive:small-cli-change"
require_relationship_geometry_moved \
  "$OUTPUT_DIR/07-relationship-map-drag-baseline.geometry.json" \
  "$OUTPUT_DIR/09-relationship-map-drag-directive.geometry.json" \
  "directive:small-cli-change" \
  240

echo "Studio review artifacts written to $OUTPUT_DIR"
