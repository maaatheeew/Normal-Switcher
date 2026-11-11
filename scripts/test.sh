#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests
swiftc -swift-version 6 Sources/NormalSwitcher/FnTap.swift Tests/FnTapTests.swift -o .build/tests/fn-tap-tests
.build/tests/fn-tap-tests
swiftc -swift-version 6 Sources/NormalSwitcher/FnSettingsSnapshot.swift Sources/NormalSwitcher/FnSettingsAccess.swift Sources/NormalSwitcher/SystemFnAction.swift Tests/SystemFnActionTests.swift -o .build/tests/fn-ownership-tests
.build/tests/fn-ownership-tests
swiftc -swift-version 6 Sources/NormalSwitcher/PanelPlacement.swift Tests/PanelPlacementTests.swift -o .build/tests/panel-placement-tests
.build/tests/panel-placement-tests
