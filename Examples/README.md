# Examples

Canonical persona pack:
- `Examples/personakit.pack.json`

Canonical compose command:
```bash
xcodebuild -project PersonaKit.xcodeproj -target PersonaKitCLI -configuration Debug build
CLI_PATH="$(xcodebuild -project PersonaKit.xcodeproj -target PersonaKitCLI -configuration Debug -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ {dir=$2} /EXECUTABLE_PATH/ {exe=$2} END {print dir \"/\" exe}')"
"$CLI_PATH" compose --persona senior-ios-engineer --context "Repo: PersonaKit" --goal "Ship v1" --task "Review changes"
```

To load this pack in the app:
1) Copy `Examples/personakit.pack.json` to `~/Library/Application Support/PersonaKit/Packs/`
2) Click **Reload** in the app toolbar
