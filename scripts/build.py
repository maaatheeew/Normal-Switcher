#!/usr/bin/env python3
"""Build an app bundle; Xcode adds adaptive Icon Composer renditions."""
import argparse
import pathlib
import plistlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent

def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], cwd=ROOT, check=True, **kwargs)

def build():
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-adaptive-icon', action='store_true')
    args = parser.parse_args()
    run(['swift', 'build', '-c', 'release'])
    bin_path = pathlib.Path(run(['swift', 'build', '-c', 'release', '--show-bin-path'], capture_output=True, text=True).stdout.strip())
    app = ROOT / 'dist/Normal Switcher.app'
    if app.exists(): shutil.rmtree(app)
    resources = app / 'Contents/Resources'
    (app / 'Contents/MacOS').mkdir(parents=True)
    resources.mkdir()
    shutil.copy2(bin_path / 'NormalSwitcher', app / 'Contents/MacOS/NormalSwitcher')
    info = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
    actool = subprocess.run(['xcrun', '--find', 'actool'], capture_output=True, text=True)
    if actool.returncode == 0:
        partial = ROOT / '.build/icon-info.plist'
        run([actool.stdout.strip(), '--compile', resources, '--platform', 'macosx', '--minimum-deployment-target', '26.0', '--app-icon', 'AppIcon', '--output-partial-info-plist', partial, '--standalone-icon-behavior', 'all', ROOT / 'Resources/AppIcon.icon'])
        info.update(plistlib.loads(partial.read_bytes()))
    else:
        if args.require_adaptive_icon: raise SystemExit('Xcode actool is required for the adaptive icon.')
        iconset = ROOT / '.build/AppIcon.iconset'
        iconset.mkdir(exist_ok=True)
        original = ROOT / 'docs/assets/icon-light.png'
        for size in [16, 32, 128, 256, 512]:
            for scale in [1, 2]:
                name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
                run(['sips', '-z', str(size * scale), str(size * scale), original, '--out', iconset / name], stdout=subprocess.DEVNULL)
        run(['iconutil', '-c', 'icns', iconset, '-o', resources / 'AppIcon.icns'])
        info.pop('CFBundleIconName', None)
        print('Icon: native Icon Composer raster fallback. Xcode build produces adaptive Assets.car.')
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    run(['codesign', '--force', '--sign', '-', app])
    run(['codesign', '--verify', '--deep', '--strict', app])
    archive = ROOT / 'dist/Normal-Switcher-1.0.0-macOS.zip'
    if archive.exists(): archive.unlink()
    run(['ditto', '-c', '-k', '--keepParent', app, archive])
    print(app)

if __name__ == '__main__': build()
