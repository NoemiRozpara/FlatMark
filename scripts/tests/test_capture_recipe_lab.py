"""Black-box smoke capture checks; no Apple tools or devices are used."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
FAKE = r'''#!/usr/bin/env python3
import json, os, pathlib, signal, sys, time
name = pathlib.Path(sys.argv[0]).name
a = sys.argv[1:]
mode = os.environ.get('SCENARIO', '')
state = pathlib.Path(os.environ['STATE'])
if name == 'sleep':
    if a == ['12']:
        deadline = time.monotonic() + 3
        while not (state / 'ready').exists() and time.monotonic() < deadline:
            time.sleep(0.001)
elif name == 'sips':
    if mode == 'dimensions': sys.exit(1)
    w, h = pathlib.Path(a[-1]).read_text().split('x')
    print('pixelWidth: ' + w + '\npixelHeight: ' + h)
elif name == 'sw_vers':
    print('27.0.1')
elif name == 'swiftc':
    dest = pathlib.Path(a[a.index('-o') + 1])
    dest.write_text('#!/bin/bash\nprintf "123\\t600\\t900\\t2\\t1200\\t1800\\n"\n')
    dest.chmod(0o755)
elif name == 'screencapture':
    if mode == 'capture': sys.exit(1)
    pathlib.Path(a[-1]).write_text('1200x1800')
elif name == 'xcrun':
    if a[:4] == ['simctl', 'list', 'devices', 'booted']:
        print(json.dumps({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [
            {'state': 'Booted', 'isAvailable': True, 'name': 'iPhone test', 'udid': 'TEST'}]}}))
    elif a[:3] == ['simctl', 'list', 'runtimes']:
        print(json.dumps({'runtimes': [{'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0',
                                       'version': '27.0'}]}))
    elif 'launch' in a:
        (state / 'ready').unlink(missing_ok=True)
        (state / 'size').unlink(missing_ok=True)
        (state / 'preset').write_text(a[-1])
        if mode == 'launch': sys.exit(1)
    elif '--help' in a:
        sys.exit(1 if mode.startswith('fallback') else 0)
    elif 'start' in a:
        if mode == 'session' and (state / 'preset').read_text() == 'light':
            (state / 'ready').touch()
            sys.exit(1)
        print('Resizable (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE)', flush=True)
        (state / 'ready').touch()
        if mode in ('interrupt', 'hangup'):
            (state / 'session-pid').write_text(str(os.getpid()))
            signal.pause()
    elif 'set' in a:
        if mode in ('interrupt', 'hangup'):
            os.kill(os.getppid(), signal.SIGHUP if mode == 'hangup' else signal.SIGTERM)
        (state / 'size').write_text(a[-1])
        sys.exit(1 if mode == 'resize' else 0)
    elif 'screenshot' in a:
        dest = pathlib.Path(a[a.index('--destination') + 1] if '--destination' in a else a[-1])
        if mode in ('capture', 'fallback-capture'): sys.exit(1)
        if mode in ('empty', 'missing', 'fallback-empty', 'fallback-missing'):
            if mode.endswith('empty'): dest.touch()
            sys.exit(0)
        size = (state / 'size').read_text() if (state / 'size').exists() else '390x844'
        if mode == 'clamped': size = '390x844'
        w, h = map(int, size.split('x'))
        dest.write_text(f'{w * 3}x{h * 3}')
'''


class CaptureRecipeLabTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        scripts = self.root / 'scripts'
        scripts.mkdir()
        shutil.copy(ROOT / 'scripts/capture-recipe-lab.sh', scripts)
        launcher = scripts / 'run-fixture-host.sh'
        launcher.write_text('#!/bin/bash\nexit 0\n')
        launcher.chmod(0o755)
        tools = self.root / 'bin'
        tools.mkdir()
        for name in ['xcrun', 'sips', 'sleep', 'sw_vers', 'swiftc', 'screencapture',
                     'osascript', 'pkill', 'open']:
            tool = tools / name
            tool.write_text(FAKE)
            tool.chmod(0o755)
        (self.root / 'state').mkdir()
        (self.root / 'tmp').mkdir()
        self.env = dict(os.environ, PATH=f'{tools}:' + os.environ['PATH'],
                        STATE=str(self.root / 'state'), TMPDIR=str(self.root / 'tmp'),
                        CAPTURES='light', IOS_WIDTHS='320x700 430x932', MACOS_WIDTHS='600x900')

    def run_capture(self, scenario='', presets='light', platform='ios'):
        result = subprocess.run(['bash', str(self.root / 'scripts/capture-recipe-lab.sh'),
                                 platform, str(self.root / 'output')],
                                env=dict(self.env, SCENARIO=scenario, CAPTURES=presets),
                                capture_output=True, text=True, timeout=15)
        files = sorted(p.name for p in (self.root / 'output').glob('*.png'))
        self.assertEqual(list((self.root / 'tmp').iterdir()), [])
        self.assertEqual(sorted(p.name for p in (self.root / 'output').iterdir()), files)
        return result, files

    def test_names_use_runtime_preset_and_actual_pixels(self):
        result, files = self.run_capture(presets='light dark')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files, [f'ios-27.0-{preset}-{size}.png'
                                 for preset in ['dark', 'light']
                                 for size in ['1290x2796', '960x2100']])
        self.assertIn('4 screenshots saved; 0 failures', result.stdout)

    def test_repeated_runs_preserve_images_without_metadata(self):
        first, files = self.run_capture()
        self.assertEqual(first.returncode, 0, first.stderr)
        originals = {name: (self.root / 'output' / name).read_bytes() for name in files}
        second, files = self.run_capture()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(len(files), 4)
        for name, data in originals.items():
            self.assertEqual((self.root / 'output' / name).read_bytes(), data)
            self.assertIn(name.removesuffix('.png') + '-2.png', files)

    def test_dangling_symlink_is_not_overwritten(self):
        output = self.root / 'output'
        output.mkdir()
        existing = output / 'ios-27.0-light-1170x2532.png'
        existing.symlink_to(output / 'missing-image')
        result, files = self.run_capture('fallback')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(existing.is_symlink())
        self.assertIn('ios-27.0-light-1170x2532-2.png', files)

    def test_concurrent_runs_do_not_overwrite_images(self):
        command = ['bash', str(self.root / 'scripts/capture-recipe-lab.sh'),
                   'ios', str(self.root / 'output')]
        env = dict(self.env, SCENARIO='fallback')
        processes = [subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE, text=True) for _ in range(2)]
        try:
            for process in processes:
                _, stderr = process.communicate(timeout=15)
                self.assertEqual(process.returncode, 0, stderr)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                    process.communicate()
        self.assertEqual(sorted(p.name for p in (self.root / 'output').iterdir()),
                         ['ios-27.0-light-1170x2532-2.png', 'ios-27.0-light-1170x2532.png'])

    def test_clamped_sizes_are_named_by_pixels_not_requests(self):
        result, files = self.run_capture('clamped')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files, ['ios-27.0-light-1170x2532-2.png',
                                 'ios-27.0-light-1170x2532.png'])

    def test_older_xcode_fallback_is_normal_smoke_success(self):
        result, files = self.run_capture('fallback', 'light dark')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('one initial viewport per preset', result.stderr)
        self.assertEqual(files, ['ios-27.0-dark-1170x2532.png', 'ios-27.0-light-1170x2532.png'])

    def test_failed_and_empty_captures_fail_without_images(self):
        for scenario in ['capture', 'fallback-capture', 'empty', 'missing',
                         'fallback-empty', 'fallback-missing', 'dimensions']:
            with self.subTest(scenario=scenario):
                result, files = self.run_capture(scenario)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(files, [])

    def test_launch_failure_stops_capture(self):
        result, files = self.run_capture('launch')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(files, [])

    def test_resize_command_failure_remains_a_failure(self):
        result, files = self.run_capture('resize')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(len(files), 2)
        self.assertIn('Resize failed', result.stderr)

    def test_failed_session_continues_other_presets(self):
        result, files = self.run_capture('session', 'light dark')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(len(files), 2)
        self.assertTrue(all('-dark-' in name for name in files))
        self.assertIn('Resizable session failed: light', result.stderr)

    def test_signals_stop_session_and_remove_temporary_files(self):
        for scenario in ['interrupt', 'hangup']:
            with self.subTest(scenario=scenario):
                result, _ = self.run_capture(scenario)
                self.assertNotEqual(result.returncode, 0)
                pid = int((self.root / 'state/session-pid').read_text())
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)

    def test_macos_names_include_runtime_pixels_and_scroll_position(self):
        result, files = self.run_capture(presets='light dark', platform='macos')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(files, [f'macos-27.0.1-{preset}-1200x1800-{scroll}.png'
                                 for preset in ['dark', 'light']
                                 for scroll in ['end', 'middle', 'top']])

    def test_macos_capture_failure(self):
        result, files = self.run_capture('capture', platform='macos')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(files, [])

    def test_macos_skips_ios_only_enlarged_preset(self):
        result, files = self.run_capture(presets='generous light', platform='macos')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(files), 3)
        self.assertTrue(all('-light-' in name for name in files))
        self.assertIn('Skipping generous', result.stderr)


if __name__ == '__main__':
    unittest.main()
