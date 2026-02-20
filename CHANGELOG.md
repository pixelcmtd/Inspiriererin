## 0.3.1

- Change prometheus prefix from `inspiriererin_` to `insp8n_`
- Fix a bug in the `$ log` command (JSON-encoding `Uri`)
- Update dependencies

## 0.3.0

- `nyxx` 6
- Added support for `INSP_DISCORD_TOKEN` environment variable instead of using args
- Removed `--self` option, as it isn't really needed
- Removed rate limiting being logged to home channel
- Stopped using `inspirobot`, as it seems to have been abandoned and would break
us now
- Added `messageContent` intent

## 0.2.0

- Added CLI arguments to allow you to override `metrics-port`, `self` and `home`
- `nyxx` 5
- More logging

## 0.1.0

- Initial release
