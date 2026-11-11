<table><tr><td width="116"><img src="docs/assets/icon-light.png" alt="Normal Switcher icon" width="96"></td><td><h1>Normal Switcher</h1><p>Language switching that feels normal. A small, native macOS menu bar app by Matthew Avgul.</p></td></tr></table>

## Features

- Tap **Fn / 🌐** to select your next keyboard language directly.
- A fixed destination per press prevents toggling back when another handler has already selected that language.
- Fn combinations stay combinations: Fn + Delete, arrow keys, and media keys do not change the language.
- A rounded capsule in the menu bar shows the selected language (RU, EN, FR, etc.) and opens a compact Liquid Glass panel.
- Choose a language from the panel, pause Fn switching, or enable launch at login.
- Automatically follows the macOS light/dark appearance and a layered Icon Composer icon.
- No accounts, telemetry, network service, or text logging.

## Requirements and installation

macOS 26 or later. The downloadable build targets Apple Silicon.

Download the ZIP from [Releases](https://github.com/maaatheeew/Normal-Switcher/releases), move **Normal Switcher.app** into Applications, and open it. Quit other Fn remapping utilities before starting it.

On first enabling **Switch with Fn**, macOS asks for Accessibility access (called Device Control and Data Access in macOS 27). After access is granted, the app saves the current Fn action, sets the system action to Do Nothing, and takes over Fn switching. Turning the switch off restores the exact saved action, including Do Nothing or an absent preference. Normal exit also restores it. Each enable captures the latest system setting. The language buttons still work when Fn switching is paused. **Launch at login** is off until you enable it.

If access is missing, an inline **Allow access** action appears during setup. Until permission is granted, the app leaves the system Fn action unchanged. Secure Input (for example, password fields) can prevent global key monitoring.

The initial release is ad-hoc signed, not Apple-notarized. Rebuilding or updating an ad-hoc signed copy may require approving Accessibility access again. macOS may require you to allow opening it in Privacy & Security.

## Build

```sh
./scripts/test.sh
python3 scripts/build.py
open "dist/Normal Switcher.app"
```

Swift 6.2 or later is required. Xcode supplies `actool`, which compiles the adaptive icon into `Assets.car`. With Command Line Tools alone, the build uses an `.icns` fallback rendered by Apple's Icon Composer. The layered source is in `Resources/AppIcon.icon`.

## How switching works

The app observes the physical Fn key, remembers the intended input-source ID on key-down, and selects that exact ID on release. Repeated edges cannot select a second destination. Other keys and modifiers cancel a standalone tap. Input sources are read from the enabled macOS keyboard sources, and changes made outside the app update the panel.

A dynamically resolved private HIToolbox function refreshes the system Fn-action cache after writing the preference; if it is unavailable, the saved setting remains and may need a logout or manual refresh in Keyboard settings. Input selection itself uses the public Text Input Source API.

## Credits

Inspired by the problem and approach described in [tonku321/FnLangSwitch](https://github.com/tonku321/fn-lang-switcher). Thank you for highlighting a simpler way to switch input sources.

The app does not draw an indicator beside the mouse or restyle the system text-caret indicator.

Normal Switcher is a separate implementation with its own UI, artwork, event handling, and tests. It does not redistribute the original FnLangSwitch source or binary. Apple frameworks and SF Symbols belong to Apple.

## License

[MIT](LICENSE) · Copyright © 2026 Matthew Avgul.
