# AutoRig Executables

Rebuilt artifacts for AutoRig `0.2.2`.

## Included Artifacts

- `bin/autorig_cli-linux-x86_64`
- `plugins/autorig_blender-0.2.2.zip`
- `setup.sh`
- `SHA256SUMS`
- `RELEASE_METADATA.json`

## What’s New In This Build

- Pocket anchor marker contract:
  - `options.pose_request.params.pocket_anchor_markers.<side> = {center, half_extents}`
  - strict API validation rejects NaN/Inf, malformed vectors, and non-positive extents
- Mandatory pocket-anchor confirmation gate for `contact_v2 + hand_in_pocket`:
  - Web: click-to-place anchor center + extents editor + confirmation dialog
  - Blender: run-time confirmation dialog with side/center/extents/preview summary
  - run stays blocked until explicit confirmation
- Deterministic marker fallback preserved:
  - if no marker is provided, inferred pocket anchor fallback is still used

## Quick Start

```bash
chmod +x setup.sh
./setup.sh
```

Or run the CLI directly:

```bash
chmod +x bin/autorig_cli-linux-x86_64
./bin/autorig_cli-linux-x86_64 validate --help
```
