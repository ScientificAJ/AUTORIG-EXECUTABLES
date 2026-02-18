# Verify Artifact Checksums

## Linux

```bash
sha256sum -c SHA256SUMS
```

A successful run prints `OK` for each listed file.

## macOS

If `sha256sum` is not available, use:

```bash
shasum -a 256 -c SHA256SUMS
```

## Windows (PowerShell)

Compute and compare a single file hash:

```powershell
Get-FileHash .\\bin\\autorig_cli-linux-x86_64 -Algorithm SHA256
```
