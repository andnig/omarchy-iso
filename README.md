# Omarchy ISO

The Omarchy ISO streamlines [the installation of Omarchy](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started). It includes the Omarchy Configurator as a front-end to archinstall and automatically launches the [Omarchy Installer](https://github.com/basecamp/omarchy) after base arch has been setup.

## Downloading the latest ISO

See the ISO link on [omarchy.org](https://omarchy.org).

## Creating the ISO

Run `./bin/omarchy-iso-make` and the output goes into `./release`. You can build from your local `$OMARCHY_PATH` for testing with `--local-source`, from the dev branch with `--dev`, or from the quattro branch with `--quattro`. The dev and quattro builds use the edge package mirror.

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `OMARCHY_INSTALLER_REPO` - GitHub repository for the installer (default: `basecamp/omarchy`)
- `OMARCHY_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)

Example usage:

```bash
OMARCHY_INSTALLER_REPO="andnig/pondhouse-linux" ./bin/omarchy-iso-make
```

## Testing the ISO

Run `./bin/omarchy-iso-boot [release/omarchy.iso]`.

## Signing the ISO

Run `./bin/omarchy-iso-sign [release/omarchy.iso]` using your configured GPG secret key.

## Uploading the ISO

Run `./bin/omarchy-iso-upload [release/omarchy.iso]`. This requires you've configured rclone (use `rclone config`).

## Full release of the ISO

Run `./bin/omarchy-iso-release VERSION` to create, sign, and upload stable and dev ISOs. Add `--rc` to release only an RC build instead.

## Error handling

- If you get an error about packages being corrupt, remove the offline cache directory `sudo rm -rf $HOME/.cache/omarchy/iso_xxxxx`.
