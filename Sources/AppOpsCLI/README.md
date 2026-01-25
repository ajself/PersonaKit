# AppOpsCLI

AppOpsCLI is a **local, manual tool** that captures performance metrics for key
PersonaKit workflows (reload, compose, diff, import, export). It runs entirely
offline and writes deterministic reports to disk.

## Run it

```bash
Scripts/appops
```

Or directly:

```bash
swift run AppOpsCLI -- [options]
```

## Options

- `--out-dir <path>`: output directory (default: `Artifacts/`)
- `--import-source <path>`: pack file or folder to import (default: `Examples/personakit.pack.json`)
- `--diff-left <path>`: left pack file for diff (default: built-in pack)
- `--diff-right <path>`: right pack file for diff (default: `Examples/personakit.pack.json`)
- `--no-user-packs`: skip loading user packs from `~/Library/Application Support/PersonaKit/Packs`
- `--help`: show usage

## Output layout

```
Artifacts/
  appops-<timestamp>/
    REPORT.md
    report.json
    import/
    export/
```

`REPORT.md` is the human‑readable summary; `report.json` is the machine‑readable
schema emitted by AppOpsCore.

## Notes

- This tool is for internal measurement only.
- It does not ship with the app or user‑facing CLI.
- Keep output under version control **only if you intend to**, as it is ignored by default.
