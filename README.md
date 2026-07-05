# MacDownloader

A small native macOS download manager for HTTP/HTTPS files. It stores download metadata and resume data in Application Support, so paused or interrupted downloads can continue without losing progress when the server supports HTTP range requests.

## Run in development

```bash
swift run MacDownloader
```

## Build a `.app`

```bash
chmod +x scripts/package_app.sh
./scripts/package_app.sh
open dist/MacDownloader.app
```

Downloads are saved to the current user's Downloads folder.
