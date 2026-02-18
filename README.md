# AutoRig Distribution

Professional distribution repository for AutoRig executable artifacts.

## Repository Layout

- `bin/autorig_cli-linux-x86_64` - Linux CLI binary
- `bin/setup.sh` - setup helper script
- `plugins/autorig_blender-0.1.0.zip` - Blender add-on package
- `proposal/autorig_enterprise_proposal.pdf` - business proposal deck
- `docs/` - usage, verification, and installation guides
- `SHA256SUMS` - integrity hashes for distributed artifacts

## Quick Start

```bash
bash ./bin/setup.sh
```

Run API server and open the web interface:

```bash
bash ./bin/setup.sh --run --host 127.0.0.1 --port 8000
```

Then visit:

- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/healthz`

## Documentation

- `docs/QUICKSTART.md`
- `docs/BLENDER_INSTALL.md`
- `docs/VERIFY_CHECKSUMS.md`

## Experimental Features

### Geometric Inference Mode (Optional / EXPERIMENTAL)

This release includes an optional **EXPERIMENTAL** "Draw -> Recognize -> Correct" mode that infers a skeleton from
user guide strokes/lines, then runs the standard correction + export pipeline.

Enablement (disabled by default):

- API server: set `AUTORIG_ENABLE_GEOMETRIC_AUTORIG=1`
- Client request: `rig_mode=geometric_inference` (Web/Blender UI labels this as EXPERIMENTAL)

Compatibility:

- When disabled, behavior is identical to the default ML mode.

## Support

- Email: `support@astroclub.space`
