#!/bin/bash

set -e

# Note that these are packages installed to the Arch container used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Sy archiso git sudo base-devel jq

# Setup build locations
build_cache_dir="/var/cache"
offline_mirror_dir="$build_cache_dir/airootfs/var/cache/omarchy/mirror/offline"
mkdir -p $build_cache_dir/
mkdir -p $offline_mirror_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r /archiso/configs/releng/* $build_cache_dir/
rm "$build_cache_dir/airootfs/etc/motd"

# Avoid using reflector for mirror identification as we are relying on the global CDN
rm "$build_cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
rm -rf "$build_cache_dir/airootfs/etc/systemd/system/reflector.service.d"
rm -rf "$build_cache_dir/airootfs/etc/xdg/reflector"

# Bring in our configs
cp -r /configs/* $build_cache_dir/

# Clone Omarchy itself
git clone -b $OMARCHY_INSTALLER_REF https://github.com/$OMARCHY_INSTALLER_REPO.git "$build_cache_dir/airootfs/root/omarchy"

# Make log uploader available in the ISO too
mkdir -p "$build_cache_dir/airootfs/usr/local/bin/"
cp "$build_cache_dir/airootfs/root/omarchy/bin/omarchy-upload-log" "$build_cache_dir/airootfs/usr/local/bin/omarchy-upload-log"

# Copy the Omarchy Plymouth theme to the ISO
mkdir -p "$build_cache_dir/airootfs/usr/share/plymouth/themes/omarchy"
cp -r "$build_cache_dir/airootfs/root/omarchy/default/plymouth/"* "$build_cache_dir/airootfs/usr/share/plymouth/themes/omarchy/"

# Add our additional packages to packages.x86_64
arch_packages=(linux-t2 git gum jq openssl plymouth tzupdate)
printf '%s\n' "${arch_packages[@]}" >>"$build_cache_dir/packages.x86_64"

# Build list of all the packages needed for the offline mirror
all_packages=($(cat "$build_cache_dir/packages.x86_64"))
all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/omarchy/install/omarchy-base.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/omarchy/install/omarchy-other.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/omarchy/install/custom/custom-pacman.packages" | grep -v '^$'))
all_packages+=($(grep -v '^#' /builder/archinstall.packages | grep -v '^$'))

# Download all the packages to the offline mirror inside the ISO
mkdir -p /tmp/offlinedb
pacman --config /configs/pacman-online.conf --noconfirm -Syw "${all_packages[@]}" --cachedir $offline_mirror_dir/ --dbpath /tmp/offlinedb

# Handle AUR packages if the file exists
if [ -f "$build_cache_dir/airootfs/root/omarchy/install/custom/custom-yay.packages" ]; then
  echo "Building AUR packages for offline mirror..."

  # Read non-empty, non-comment lines into an array
  mapfile -t aur_packages < <(
    grep -v '^\s*#' "$build_cache_dir/airootfs/root/omarchy/install/custom/custom-yay.packages" |
      grep -v '^\s*$'
  )

  if [ ${#aur_packages[@]} -eq 0 ]; then
    echo "AUR package list is empty; skipping AUR build."
  else
    # Consistent pacman settings for ONLINE lookups/downloads
    online_conf="/configs/pacman-online.conf"
    online_dbpath="/tmp/offlinedb" # same path you already used earlier
    mkdir -p "$online_dbpath"

    # Create builder user
    useradd -m builder 2>/dev/null || true
    echo "builder ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/builder

    # Tools needed for build + pactree
    pacman -S --needed --noconfirm git base-devel pacman-contrib

    # Install yay for the builder user
    su - builder -c "
      set -euo pipefail
      git clone https://aur.archlinux.org/yay.git ~/yay
      cd ~/yay && makepkg -si --noconfirm --needed
      rm -rf ~/yay
    "

    temp_pkg_dir="/tmp/aur-packages"
    mkdir -p "$temp_pkg_dir"
    chown builder:builder "$temp_pkg_dir"

    pkg_list="${aur_packages[*]}"

    # Build AUR packages and generate a clean dependency list
    su - builder -c "
      set -euo pipefail

      # Build packages (installs them in the builder env; artifacts go to yay cache)
      yay -S --noconfirm --needed --mflags '--skippgpcheck' ${pkg_list}

      # Collect built AUR packages
      find ~/.cache/yay -type f -name '*.pkg.tar.*' -exec cp {} $temp_pkg_dir/ \; 2>/dev/null || true

      # Build a flat, unique dependency LIST (no tree art)
      : > /tmp/all-deps.txt
      for pkg in ${pkg_list}; do
        pactree -ul \"\$pkg\" >> /tmp/all-deps.txt
      done
      sort -u /tmp/all-deps.txt > /tmp/all-deps-sorted.txt
    "

    # Move AUR packages into the offline mirror
    shopt -s nullglob
    mv "$temp_pkg_dir"/*.pkg.tar.* "$offline_mirror_dir/" 2>/dev/null || true
    shopt -u nullglob

    # Ensure the sync DB for all repos in $online_conf exists at the SAME DBPATH
    pacman --config "$online_conf" --dbpath "$online_dbpath" --noconfirm -Sy

    # Download ALL repo-side dependencies into the offline mirror
    if [ -s /tmp/all-deps-sorted.txt ]; then
      echo "Downloading repo dependencies for AUR packages..."
      mapfile -t all_deps </tmp/all-deps-sorted.txt

      repo_pkgs=()
      for dep in "${all_deps[@]}"; do
        # Keep only packages resolvable from your configured ONLINE repos (excludes AUR pkgs)
        if pacman --config "$online_conf" --dbpath "$online_dbpath" -Si "$dep" &>/dev/null; then
          repo_pkgs+=("$dep")
        fi
      done

      if [ ${#repo_pkgs[@]} -gt 0 ]; then
        pacman --config "$online_conf" --dbpath "$online_dbpath" --noconfirm -Sw \
          --cachedir "$offline_mirror_dir/" "${repo_pkgs[@]}"
      fi
    fi

    # Clean up
    rm -rf "$temp_pkg_dir" /tmp/all-deps*.txt "$tmp_dbpath" "$tmp_conf"
    userdel -r builder 2>/dev/null || true
    rm -f /etc/sudoers.d/builder
  fi
fi

repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst

# Create a symlink to the offline mirror instead of duplicating it.
# mkarchiso needs packages at /var/cache/omarchy/mirror/offline in the container,
# but they're actually in $build_cache_dir/airootfs/var/cache/omarchy/mirror/offline
mkdir -p /var/cache/omarchy/mirror
ln -s "$offline_mirror_dir" "/var/cache/omarchy/mirror/offline"

# Copy the pacman.conf to the ISO's /etc directory so the live environment uses our
# same config when booted
cp $build_cache_dir/pacman.conf "$build_cache_dir/airootfs/etc/pacman.conf"

# Finally, we assemble the entire ISO
mkarchiso -v -w "$build_cache_dir/work/" -o "/out/" "$build_cache_dir/"
