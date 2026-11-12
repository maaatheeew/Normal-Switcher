#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests
swiftc -swift-version 6 Sources/NormalSwitcher/FnTap.swift Tests/FnTapTests.swift -o .build/tests/fn-tap-tests
.build/tests/fn-tap-tests
swiftc -swift-version 6 Sources/NormalSwitcher/FnSettingsSnapshot.swift Sources/NormalSwitcher/FnSettingsAccess.swift Sources/NormalSwitcher/SystemFnAction.swift Tests/SystemFnActionTests.swift -o .build/tests/fn-ownership-tests
.build/tests/fn-ownership-tests
swiftc -swift-version 6 Sources/NormalSwitcher/IndicatorPreference.swift Sources/NormalSwitcher/IndicatorSettingsAccess.swift Sources/NormalSwitcher/GlobalIndicatorSettings.swift Sources/NormalSwitcher/SystemLanguageIndicator.swift Tests/SystemLanguageIndicatorTests.swift -o .build/tests/system-indicator-tests
.build/tests/system-indicator-tests
swiftc -swift-version 6 -target arm64-apple-macos26.0 \
    Sources/NormalSwitcher/KeyboardLayout.swift \
    Sources/NormalSwitcher/LayoutCatalog.swift \
    Sources/NormalSwitcher/LoginItemManager.swift \
    Sources/NormalSwitcher/FnTap.swift \
    Sources/NormalSwitcher/FnListener.swift \
    Sources/NormalSwitcher/FnSettingsSnapshot.swift \
    Sources/NormalSwitcher/FnSettingsAccess.swift \
    Sources/NormalSwitcher/HIToolboxSettings.swift \
    Sources/NormalSwitcher/SystemFnAction.swift \
    Sources/NormalSwitcher/IndicatorPreference.swift \
    Sources/NormalSwitcher/IndicatorSettingsAccess.swift \
    Sources/NormalSwitcher/GlobalIndicatorSettings.swift \
    Sources/NormalSwitcher/SystemLanguageIndicator.swift \
    Sources/NormalSwitcher/SwitcherModel.swift \
    Sources/NormalSwitcher/ActivationFeedback.swift \
    Tests/KeyboardAccessTests.swift -o .build/tests/keyboard-access-tests
.build/tests/keyboard-access-tests
python3 - <<'PYTEST'
from pathlib import Path
import subprocess
sources = [str(p) for p in Path('Sources/NormalSwitcher').glob('*.swift') if p.name != 'Launcher.swift']
subprocess.run(['swiftc', '-swift-version', '6', '-target', 'arm64-apple-macos26.0', *sources, 'Tests/NativeMenuTests.swift', '-o', '.build/tests/native-menu-tests'], check=True)
subprocess.run(['.build/tests/native-menu-tests'], check=True)
subprocess.run(['swiftc', '-swift-version', '6', '-target', 'arm64-apple-macos26.0', *sources, 'Tests/ConfettiTests.swift', '-o', '.build/tests/confetti-tests'], check=True)
subprocess.run(['.build/tests/confetti-tests'], check=True)

PYTEST
