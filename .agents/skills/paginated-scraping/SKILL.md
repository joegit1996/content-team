# Paginated Scraping

Scrape listing pages that spread results across multiple pages — handling next buttons, infinite scroll, offset/cursor pagination, and load-more patterns.

## When to Use

Use this skill when collecting data from listing pages that don't show all results on a single page:
- Search results (Google Maps, directories)
- E-commerce product listings (Talabat, Noon, Amazon)
- Job boards (Bayt, LinkedIn)
- Review sites (TripAdvisor, Zomato)
- Any site with "Next", "Load More", page numbers, or infinite scroll

## Pagination Patterns

### Pattern 1: URL Parameter Pagination

The most common pattern. Page number or offset appears in the URL.

```
https://example.com/restaurants?page=1
https://example.com/restaurants?page=2
https://example.com/products?offset=0&limit=20
https://example.com/products?offset=20&limit=20
```

**Strategy**: Increment the parameter until you get an empty page or hit your target count.

```python
import time
import requests
from typing import Optional

class URLPaginator:
    def __init__(self, base_url: str, param_name: str = "page",
                 start: int = 1, delay: float = 2.0):
        self.base_url = base_url
        self.param_name = param_name
        self.current = start
        self.delay = delay

    def fetch_all(self, max_pages: int = 100,
                  target_count: Optional[int] = None) -> list:
        all_items = []
        consecutive_empty = 0

        for page_num in range(self.current, self.current + max_pages):
            separator = "&" if "?" in self.base_url else "?"
            url = f"{self.base_url}{separator}{self.param_name}={page_num}"

            items = self._extract_items(url)

            if not items:
                consecutive_empty += 1
                if consecutive_empty >= 2:
                    break  # Two empty pages = no more data
                continue

            consecutive_empty = 0
            all_items.extend(items)

            if target_count and len(all_items) >= target_count:
                all_items = all_items[:target_count]
                break

            time.sleep(self.delay)

        return all_items

    def _extract_items(self, url: str) -> list:
        # Override this or pass an extractor function
        raise NotImplementedError
```

### Pattern 2: Offset/Limit Pagination

Common in APIs and modern web apps.

```python
class OffsetPaginator:
    def __init__(self, base_url: str, limit: int = 20, delay: float = 2.0):
        self.base_url = base_url
        self.limit = limit
        self.delay = delay

    def fetch_all(self, target_count: Optional[int] = None) -> list:
        all_items = []
        offset = 0

        while True:
            separator = "&" if "?" in self.base_url else "?"
            url = f"{self.base_url}{separator}offset={offset}&limit={self.limit}"

            items = self._extract_items(url)

            if not items:
                break

            all_items.extend(items)
            offset += self.limit

            if target_count and len(all_items) >= target_count:
                all_items = all_items[:target_count]
                break

            # If we got fewer items than the limit, we've reached the end
            if len(items) < self.limit:
                break

            time.sleep(self.delay)

        return all_items
```

### Pattern 3: Cursor/Token Pagination

Used by modern APIs (Google Maps, Instagram, Facebook). Each response includes a token for the next page.

```python
class CursorPaginator:
    def __init__(self, base_url: str, cursor_field: str = "next_cursor",
                 cursor_param: str = "cursor", delay: float = 2.0):
        self.base_url = base_url
        self.cursor_field = cursor_field
        self.cursor_param = cursor_param
        self.delay = delay

    def fetch_all(self, target_count: Optional[int] = None) -> list:
        all_items = []
        cursor = None

        while True:
            url = self.base_url
            if cursor:
                separator = "&" if "?" in url else "?"
                url = f"{url}{separator}{self.cursor_param}={cursor}"

            response = self._fetch(url)
            items = response.get("items", response.get("results", []))
            next_cursor = response.get(self.cursor_field)

            if not items:
                break

            all_items.extend(items)

            if target_count and len(all_items) >= target_count:
                all_items = all_items[:target_count]
                break

            if not next_cursor:
                break  # No more pages

            cursor = next_cursor
            time.sleep(self.delay)

        return all_items
```

### Pattern 4: Infinite Scroll (Playwright)

Content loads as the user scrolls. Requires a real browser.

```python
from playwright.sync_api import sync_playwright

class InfiniteScrollScraper:
    def __init__(self, url: str, item_selector: str,
                 scroll_delay: float = 2.0):
        self.url = url
        self.item_selector = item_selector
        self.scroll_delay = scroll_delay

    def fetch_all(self, target_count: int = 100) -> list:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(self.url, wait_until="networkidle")

            previous_count = 0
            stall_count = 0

            while True:
                # Scroll to bottom
                page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                page.wait_for_timeout(int(self.scroll_delay * 1000))

                # Count items
                items = page.query_selector_all(self.item_selector)
                current_count = len(items)

                if current_count >= target_count:
                    break

                if current_count == previous_count:
                    stall_count += 1
                    if stall_count >= 3:
                        break  # No new items after 3 scrolls
                else:
                    stall_count = 0

                previous_count = current_count

            # Extract data from all loaded items
            items = page.query_selector_all(self.item_selector)
            results = [self._extract_item(item) for item in items[:target_count]]

            browser.close()
            return results

    def _extract_item(self, element) -> dict:
        # Override to extract fields from each item element
        raise NotImplementedError
```

### Pattern 5: "Load More" Button

Similar to infinite scroll but requires clicking a button.

```python
class LoadMoreScraper:
    def __init__(self, url: str, item_selector: str,
                 button_selector: str, delay: float = 2.0):
        self.url = url
        self.item_selector = item_selector
        self.button_selector = button_selector
        self.delay = delay

    def fetch_all(self, target_count: int = 100) -> list:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(self.url, wait_until="networkidle")

            while True:
                items = page.query_selector_all(self.item_selector)
                if len(items) >= target_count:
                    break

                button = page.query_selector(self.button_selector)
                if not button or not button.is_visible():
                    break  # No more "Load More" button

                button.click()
                page.wait_for_timeout(int(self.delay * 1000))

            items = page.query_selector_all(self.item_selector)
            results = [self._extract_item(item) for item in items[:target_count]]

            browser.close()
            return results
```

## Detection: Which Pattern Is This Page Using?

Before scraping, identify the pagination type:

| Signal | Pattern |
|---|---|
| URL has `?page=N` or `?p=N` | URL parameter |
| URL has `?offset=N&limit=N` | Offset/limit |
| API response has `next_cursor`, `nextPageToken` | Cursor |
| Page has no pagination controls, content loads on scroll | Infinite scroll |
| Page has a "Load More" / "Show More" button | Load more |
| Page has numbered links (1, 2, 3... Next) | URL parameter |

## Integration with Batch Checkpoint

When scraping paginated results at scale, combine with the `batch-checkpoint` skill:

1. After each page, add items to the current batch
2. Checkpoint at the interval defined by batch-checkpoint
3. Record which page you're on in the progress metadata:

```json
{
  "progress": {
    "scope": "talabat restaurants kuwait",
    "completed": 150,
    "estimated_total": 500,
    "status": "in_progress",
    "current_page": 8,
    "total_pages_seen": 8,
    "pagination_type": "url_parameter"
  }
}
```

This allows resuming from the last page if interrupted.

## Rules

1. **Always add delays** between page requests (minimum 1-2 seconds)
2. **Detect the end** — don't keep fetching empty pages. Stop after 2 consecutive empty results.
3. **Respect robots.txt** — check if paginated paths are allowed
4. **Track progress** — record current page in batch metadata for resumability
5. **Handle duplicates** — some pagination schemes return overlapping items. Deduplicate by ID or key field.
6. **Set a hard cap** — never fetch more than `max_pages` even if there's more data, unless explicitly configured
7. **Use the lightest method first** — URL params > offset > cursor > Playwright. Only use browser for infinite scroll / load more.
