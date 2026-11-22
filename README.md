# Easier Screenshots

**Take a screenshot on your Mac. Paste it right away and find the file in Pictures → Screenshots.**

If you miss the copy-and-save workflow from Windows 11’s **Win+Shift+S**, this small menu bar app adds it to the Mac shortcuts you already have. [Windows Snipping Tool](https://support.microsoft.com/en-us/windows/apps/use-snipping-tool-to-capture-screenshots)

| Shortcut | Capture |
| --- | --- |
| **⌘⇧4** | Select an area |
| **⌘⇧3** | Capture the whole screen |
| **⌘⇧4**, then **Space** | Capture a window |

Use **⌘V** to paste the image. The file stays in `~/Pictures/Screenshots`. On a Mac with multiple displays, a whole-screen capture can save several files, and one of those images goes to the clipboard. [Mac screenshot shortcuts](https://support.apple.com/en-ie/102646)

## Install from source

Requires **macOS 14 or later** and the Xcode Command Line Tools. If the tools are missing, run `xcode-select --install` and finish the installer first.

From the project folder, run:

```sh
bash scripts/build.sh
open build
```

Move **Easier Screenshots.app** from the build folder to **Applications** and open it. The script builds a universal app for Apple silicon and Intel and signs it locally. There are no third-party dependencies.

## One-time setup

1. Press **⌘⇧5** to open the macOS Screenshot toolbar.
2. Choose **Options → Other Location…**, then select **Pictures → Screenshots**. Easier Screenshots creates the folder on launch.
3. Under **Options**, turn off **Show Floating Thumbnail** so the image is saved and copied promptly. Press **Esc** to close the toolbar. [Apple screenshot settings](https://support.apple.com/en-ie/102646)

To keep the app running after you restart, add **Easier Screenshots** under **System Settings → General → Login Items & Extensions → Open at Login**.

## How it works

macOS captures and saves the image. Easier Screenshots watches the Screenshots folder, then copies each new image to the clipboard. It also copies images manually added to that folder. It skips existing files on launch and keeps no clipboard history. Everything stays on your Mac, and the app requires neither Screen Recording nor Accessibility permission.

If a screenshot stays on the Desktop, check the save location with **⌘⇧5**. If it goes to the clipboard only, use the shortcuts above without holding **Control**. The camera icon in the menu bar opens the folder and the setup instructions.

To stop copying, quit the app from its menu. To undo the save-location change, choose a different location in the macOS Screenshot toolbar.

## Test the watcher

Run `bash scripts/test.sh` on a Mac to check file detection and copying with a temporary folder and a separate test clipboard.

## License

[MIT](LICENSE)
