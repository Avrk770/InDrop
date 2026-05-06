# InDrop Manual Smoke Checklist

Run this checklist against `dist/InDrop.app` before shipping a visual/UI change.

1. Launch the app from Finder and confirm the popover opens from the menu bar.
2. Switch language to English, then Hebrew, and confirm controls stay aligned and readable.
3. Drop one PNG and confirm it queues, previews, converts, and reveals correctly.
4. Drop one JPEG while the default format is PNG and confirm smart re-encode keeps JPEG.
5. Drop a three-page PDF and confirm outputs are named `Name - Page 01.jpg`, `Name - Page 02.jpg`, `Name - Page 03.jpg`.
6. Drop a supported file with an unsupported `.txt` file and confirm the unsupported file is skipped before conversion.
7. Set a custom output folder and confirm output files are written there.
8. Enable `Open output folder` and confirm Finder opens after a successful conversion.
9. Test `Keep original`, `Backup original`, and `Replace original` with disposable files.
10. Convert multiple files with `Replace original` and confirm the extra batch warning appears.
11. Cancel a multi-file conversion and confirm remaining source files return to the queue.
12. Clear queue/results and confirm Undo restores them.
