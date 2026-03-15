# Image Downloader

Download images from URLs to local storage, organize them by entity, validate file integrity, and map downloaded paths back to data items.

## When to Use

Use this skill when:
- The user wants actual image files, not just URLs
- The destination API requires image uploads (multipart/form-data or base64)
- You need to verify that image URLs are valid and accessible
- Building a local media library alongside collected data

## Download Strategy

### Directory Structure

```
workspace/media/
├── {entity_id}/
│   ├── logo.{ext}
│   ├── cover.{ext}
│   └── photo_1.{ext}
├── manifest.json          # Maps entity IDs to downloaded file paths
└── errors.json            # Failed downloads
```

### Manifest File

Track all downloaded images in `workspace/media/manifest.json`:

```json
{
  "downloaded_at": "2026-03-15T12:00:00Z",
  "total_downloaded": 45,
  "total_failed": 3,
  "items": {
    "kw-rest-001": {
      "logo": {
        "original_url": "https://example.com/logo.png",
        "local_path": "workspace/media/kw-rest-001/logo.png",
        "size_bytes": 24576,
        "mime_type": "image/png",
        "width": 512,
        "height": 512
      },
      "cover": {
        "original_url": "https://example.com/cover.jpg",
        "local_path": "workspace/media/kw-rest-001/cover.jpg",
        "size_bytes": 102400,
        "mime_type": "image/jpeg",
        "width": 1200,
        "height": 630
      }
    }
  }
}
```

### Download Implementation

```python
import os
import json
import hashlib
import requests
from pathlib import Path
from urllib.parse import urlparse
from datetime import datetime, timezone

class ImageDownloader:
    VALID_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.svg', '.gif', '.avif'}
    VALID_MIME_TYPES = {
        'image/jpeg', 'image/png', 'image/webp', 'image/svg+xml',
        'image/gif', 'image/avif'
    }
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

    def __init__(self, media_dir: str = "workspace/media"):
        self.media_dir = Path(media_dir)
        self.media_dir.mkdir(parents=True, exist_ok=True)
        self.manifest = {"items": {}, "total_downloaded": 0, "total_failed": 0}
        self.errors = []

    def download_for_item(self, item_id: str, image_fields: dict) -> dict:
        """
        Download all image fields for a single item.

        Args:
            item_id: Entity identifier (e.g., "kw-rest-001")
            image_fields: Dict of {field_name: url} (e.g., {"logo": "https://...", "cover": "https://..."})

        Returns:
            Dict mapping field names to local paths
        """
        item_dir = self.media_dir / item_id
        item_dir.mkdir(exist_ok=True)

        results = {}

        for field_name, url in image_fields.items():
            if not url:
                continue

            result = self._download_single(url, item_dir, field_name)

            if result["success"]:
                results[field_name] = result
                self.manifest["total_downloaded"] += 1
            else:
                self.errors.append({
                    "item_id": item_id,
                    "field": field_name,
                    "url": url,
                    "error": result["error"]
                })
                self.manifest["total_failed"] += 1

        self.manifest["items"][item_id] = results
        return results

    def _download_single(self, url: str, output_dir: Path,
                         field_name: str) -> dict:
        """Download a single image."""
        try:
            # Determine extension from URL
            parsed = urlparse(url)
            ext = Path(parsed.path).suffix.lower()

            if ext not in self.VALID_EXTENSIONS:
                ext = ""  # Will detect from content-type

            # Download with streaming
            response = requests.get(url, timeout=30, stream=True, headers={
                "User-Agent": "Mozilla/5.0 (compatible; ContentStockTeam/1.0)"
            })
            response.raise_for_status()

            # Validate content type
            content_type = response.headers.get("Content-Type", "").split(";")[0].strip()
            if content_type not in self.VALID_MIME_TYPES:
                return {"success": False, "error": f"Invalid content type: {content_type}"}

            # Detect extension from content type if needed
            if not ext:
                ext = self._mime_to_ext(content_type)

            # Check file size
            content_length = int(response.headers.get("Content-Length", 0))
            if content_length > self.MAX_FILE_SIZE:
                return {"success": False, "error": f"File too large: {content_length} bytes"}

            # Write file
            filename = f"{field_name}{ext}"
            filepath = output_dir / filename

            with open(filepath, "wb") as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            # Get actual file size
            file_size = filepath.stat().st_size

            return {
                "success": True,
                "original_url": url,
                "local_path": str(filepath),
                "size_bytes": file_size,
                "mime_type": content_type,
                "filename": filename
            }

        except requests.exceptions.RequestException as e:
            return {"success": False, "error": str(e)}

    def _mime_to_ext(self, mime_type: str) -> str:
        mapping = {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
            "image/svg+xml": ".svg",
            "image/gif": ".gif",
            "image/avif": ".avif",
        }
        return mapping.get(mime_type, ".jpg")

    def save_manifest(self):
        """Write manifest and errors to disk."""
        self.manifest["downloaded_at"] = datetime.now(timezone.utc).isoformat()

        with open(self.media_dir / "manifest.json", "w", encoding="utf-8") as f:
            json.dump(self.manifest, f, ensure_ascii=False, indent=2)

        if self.errors:
            with open(self.media_dir / "errors.json", "w", encoding="utf-8") as f:
                json.dump(self.errors, f, ensure_ascii=False, indent=2)
```

### Batch Download for All Items

```python
def download_all_images(validated_path: str, image_fields: list,
                        media_dir: str = "workspace/media"):
    """
    Download images for all validated items.

    Args:
        validated_path: Path to validated.json
        image_fields: List of field names that contain image URLs
                      (e.g., ["logo_url", "cover_image_url"])
        media_dir: Output directory for images
    """
    with open(validated_path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data)  # Handle both wrapped and raw formats
    downloader = ImageDownloader(media_dir)

    for item in items:
        item_id = item.get("id", "unknown")

        # Build image fields dict
        images = {}
        for field in image_fields:
            url = item.get(field)
            if url:
                # Strip _url suffix for cleaner filenames
                clean_name = field.replace("_url", "")
                images[clean_name] = url

        if images:
            downloader.download_for_item(item_id, images)

    downloader.save_manifest()

    print(f"Downloaded: {downloader.manifest['total_downloaded']}")
    print(f"Failed: {downloader.manifest['total_failed']}")
    print(f"Manifest: {media_dir}/manifest.json")
```

## Validation

After downloading, verify image integrity:

```python
def validate_image(filepath: str) -> bool:
    """Check if a downloaded file is a valid image."""
    try:
        # Check file is not empty
        if os.path.getsize(filepath) == 0:
            return False

        # Check magic bytes
        with open(filepath, "rb") as f:
            header = f.read(16)

        # PNG: 89 50 4E 47
        if header[:4] == b'\x89PNG':
            return True
        # JPEG: FF D8 FF
        if header[:3] == b'\xff\xd8\xff':
            return True
        # GIF: 47 49 46 38
        if header[:4] == b'GIF8':
            return True
        # WebP: 52 49 46 46 ... 57 45 42 50
        if header[:4] == b'RIFF' and header[8:12] == b'WEBP':
            return True
        # SVG: starts with < (XML)
        if header[:1] == b'<':
            return True

        return False
    except Exception:
        return False
```

## Integration with Data Export

When exporting to CSV/JSON after image download:

1. Read the manifest at `workspace/media/manifest.json`
2. For each item, replace `logo_url` with `logo_local_path` (or add as new column)
3. If pushing to an API that accepts uploads, read the local file and upload as multipart

## Rules

1. **Create one subdirectory per entity** — keeps media organized and prevents filename collisions
2. **Always write a manifest** — maps entity IDs to file paths for downstream use
3. **Validate after download** — check magic bytes, not just file extension
4. **Max 10MB per image** — skip larger files and log to errors
5. **Respect rate limits** — add 0.5-1s delay between downloads from the same domain
6. **Don't re-download** — if the file already exists in the entity's directory, skip it
7. **Log all failures** — write errors.json so the user knows what's missing
8. **Use streaming downloads** — don't load entire files into memory
