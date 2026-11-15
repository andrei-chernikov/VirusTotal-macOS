# Three local menu variants

These are separate local builds for comparison, not releases. All three use the same bundle identifier and app data; install one at a time. They are ad-hoc signed and are not notarized or official releases.

1. `Artifacts/Comparison/1-Background.dmg`: previous background-monitoring version (commit `232946b`).
2. `Artifacts/Comparison/2-Menu-Window.dmg`: menu-bar-only mode opens a normal app window (commit `e96cfa8`).
3. `Artifacts/Comparison/3-Menu-Panel.dmg`: compact menu panel. The panel is off by default and has a separate preference from the previous background mode. On first launch, the ordinary window shows the welcome and API setup; turn the panel on in Settings → Advanced → Menu Bar Interface. Turn it off in the same settings inside the panel to restore the ordinary window. Mini Mode is available in the ordinary-window mode.

All DMGs use the supplied artwork in `Packaging/DMG/background.png`. Do not upload an unknown file without the user's consent; file scans can send file contents to VirusTotal.

## Validation

- Full Xcode test suite: 43 tests in 10 suites, `/private/tmp/virustotal-onboarding-tests-final.log`.
- An isolated app with its own bundle identifier was started with the old background preference enabled and no account; the ordinary welcome with API Key and Username appeared and the new panel setting was off. No real credentials were entered.
- A separate debug app with its own bundle identifier and data was used for UI exploration. On the earlier panel size, file and folder dialogs opened and cancellation returned to the same section; switching off the mode restored a window. The selected-section mismatch found in that check was subsequently fixed.
- In an isolated 420×480 preview, the home, file, URL, batch, monitor, empty history, log filters, and three settings tabs were inspected. A log-clear label found during this check was corrected. This preview does not prove actual popover behavior.
- Physical left/right menu-bar clicks, results with a live account, notifications, Services/Shortcuts, and restart behavior still require hands-on validation. The automation sometimes raises the hidden host window and dismisses the status popover, so it does not prove those interactions. The user has not yet accepted the compact layout.
- The release script builds arm64 and x86_64, verifies the ad-hoc signature and packs the supplied background. A local ad-hoc signature does not provide Apple notarization.

No GitHub update has been sent. The separate artwork proposal is in `docs/DMG_ARTWORK_PROPOSAL_DRAFT.md`.
