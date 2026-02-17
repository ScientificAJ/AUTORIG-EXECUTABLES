# AutoRig Executables

Executable-only distribution for AutoRig.

## Included

- `autorig_cli-linux-x86_64` (Linux CLI executable)
- `setup.sh` (setup helper script)

## Notes

- No Python source files are included in this repository.
- Blender plugin zip is excluded because its standard package format contains `.py` add-on source files.
- To run on Linux:

```bash
chmod +x ./autorig_cli-linux-x86_64
./autorig_cli-linux-x86_64 --help
```
