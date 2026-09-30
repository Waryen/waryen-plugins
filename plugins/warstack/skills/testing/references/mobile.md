# Mobile: headless simulators and emulators

## Device

Lock the device before booting or using it (conventions → Commands, device lock). At cleanup, shut down only a device you both locked and booted.

- **iOS** (macOS only). Pick a simulator from `xcrun simctl list devices available`. Boot it without the Simulator app: `xcrun simctl boot <udid>`, then `xcrun simctl bootstatus <udid> -b`. Shut it down with `xcrun simctl shutdown <udid>`.
- **Android.** List AVDs with `emulator -list-avds`. Start one in the background with `emulator -avd <name> -no-window -no-audio -no-boot-anim`. It is ready once `adb -s <serial> wait-for-device` returns and `adb -s <serial> shell getprop sys.boot_completed` prints `1`. Kill it with `adb -s <serial> emu kill`.
- **Offline scenarios** run on Android:
  - Turn the network off with `adb -s <serial> shell svc wifi disable` and `adb -s <serial> shell svc data disable`.
  - Turn it back on with `svc wifi enable` and `svc data enable` before cleanup.
  - The iOS simulator shares the host network, so translate those checks to Android.

## Build and install

- Build for the simulator or emulator from the worktree with the repo's own commands (repo memory → Checks and Launch; e.g. an Nx target, `xcodebuild -sdk iphonesimulator`, `./gradlew assembleDebug`). A worktree's first build may need pods or bundles; record what it needed under Bootstrap.
- Install with `xcrun simctl install <udid> <app>`, or `adb -s <serial> install -r <apk>`.

## Drive, first that applies

1. **The repo's Maestro flows**: `maestro test <flow> --device <id>`, with the environment the repo's own tooling generates for them.
2. **warstack's Maestro flows** in repo memory `e2e/`.
3. **A new Maestro flow** in repo memory `e2e/`.
4. **The mobile MCP tools**, when Maestro is not installed and the mobile-mcp plugin is. They are named `mobile_*`, and ToolSearch loads them.
   - Record the steps you drove in `features/<feature>.md`.
   - Pin the device id on every call, and list the elements on screen before tapping by coordinates.
   - On iOS they drive through one WebDriverAgent on port 8100, so also take the lock `ios-wda`.
   - If iOS calls time out, check that WebDriverAgent is up: `curl -s http://localhost:8100/status` should report ready. If it isn't, find the app with `find ~/.claude/plugins/data -maxdepth 3 -name WebDriverAgentRunner-Runner.app`, then install it with `xcrun simctl install <udid> <app>` and start it with `xcrun simctl launch <udid> com.facebook.WebDriverAgentRunner.xctrunner`.

Stay inside the app under test: relaunch it rather than navigating through the home screen.

## Evidence

- A screenshot of each check's end state: `xcrun simctl io <udid> screenshot <file>`, or `adb -s <serial> shell screencap -p /sdcard/tw.png` then `adb -s <serial> pull /sdcard/tw.png <file>`.
- A state read when the check is about data: app storage, or logs (`xcrun simctl spawn <udid> log show --last 2m`, `adb -s <serial> logcat -d`).
- On a crash, the crash log verbatim.
