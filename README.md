# Omarchy ISO

The Omarchy ISO streamlines [the installation of Omarchy](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started). It includes the Omarchy Configurator as a front-end to archinstall and automatically launches the [Omarchy Installer](https://github.com/basecamp/omarchy) after base arch has been setup.

## Downloading the latest ISO

[Download Omarchy Online ISO](https://iso.omarchy.org/omarchy-online.iso) (1.4GB)

## Creating the ISO

Run `./bin/omarchy-iso-make` and the output goes into `./release`.

### Environment Variables

You can customize the repositories used during the build process by passing in variables:

- `OMARCHY_INSTALLER_REPO` - GitHub repository for the installer (default: `basecamp/omarchy`)
- `OMARCHY_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `master`)
- `OMARCHY_INSTALLER_URL` - URL to a custom omarchy installer script (default: `https://pondhouse-data.com/utilities/arch/install`)

Example usage:

```bash
OMARCHY_INSTALLER_REPO="andnig/dotfiles-arch" OMARCHY_INSTALLER_URL="https://pondhouse-data.com/utilities/arch/install" ./bin/omarchy-iso-make
```

## Testing the ISO

Run `./bin/omarchy-iso-boot [release/omarchy.iso]`.

## Signing the ISO

Run `./bin/omarchy-iso-sign [gpg-user] [release/omarchy.iso]`.

## Uploading the ISO

Run `./bin/omarchy-iso-upload [release/omarchy.iso]`. This requires you've configured rclone (use `rclone config`).

## Full release of the ISO

Run `./bin/omarchy-iso-release` to create, test, sign, and upload the ISO in one flow.
