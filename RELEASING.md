# Releasing Checkup for Stardew Valley

Direct download only (Developer ID + notarization), installed via Homebrew. Bundle ID:
`com.patlaplante.StardewCheckup`. Personal settings (`TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `TAP_DIR`)
are read from `~/.config/mac-app-kit/defaults.env` or `./.release.env`, both git-ignored.

```sh
# one-time (if not using the App Store Connect API key): store notarization credentials
xcrun notarytool store-credentials notarize-profile --apple-id you@example.com --team-id "$TEAM_ID"

./build.sh --universal --sign devid --notarize    # → build/StardewCheckup-<version>.zip
```

Needs the *Developer ID Application* certificate in the keychain.

`Tools/release.sh` bumps nothing itself: set `CFBundleShortVersionString` / `CFBundleVersion` in
`Resources/Info.plist`, commit, then run it. It builds and notarizes, tags `v<version>`, creates the
GitHub release with the zip, and updates `Casks/stardew-checkup.rb` in `patbonecrusher/homebrew-tap`.

Install: `brew install --cask patbonecrusher/tap/stardew-checkup`

## GitHub Actions

`.github/workflows/build.yml` is manual-only. To use it, add these repository secrets:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PWD` | base64 `.p12` of the Developer ID Application cert |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | notarytool credentials |
| `HOMEBREW_TAP_TOKEN` | PAT with repo scope on homebrew-tap (cask update dispatch) |
