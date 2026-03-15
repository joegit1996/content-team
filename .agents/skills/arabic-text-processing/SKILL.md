# Arabic Text Processing

Normalize, validate, and clean Arabic text for structured data collection. Handles Unicode normalization, mixed-direction text, and common encoding issues.

## When to Use

Use this skill when processing data that contains Arabic text — business names, descriptions, addresses, or any content in Arabic script.

## Normalization Rules

### 1. Unicode Normalization

Always apply NFC (Canonical Decomposition, followed by Canonical Composition):

```python
import unicodedata

def normalize_arabic(text):
    if text is None:
        return None
    # NFC normalization
    text = unicodedata.normalize('NFC', text)
    # Remove zero-width characters
    text = text.replace('\u200b', '')  # Zero-width space
    text = text.replace('\u200c', '')  # Zero-width non-joiner
    text = text.replace('\u200d', '')  # Zero-width joiner (keep if needed for display)
    text = text.replace('\u200e', '')  # Left-to-right mark
    text = text.replace('\u200f', '')  # Right-to-left mark
    text = text.replace('\ufeff', '')  # BOM
    return text.strip()
```

### 2. Alef Normalization

Normalize all Alef variants to bare Alef for consistent matching (but preserve original for display):

```python
ALEF_VARIANTS = {
    '\u0622': '\u0627',  # Alef with Madda → Alef
    '\u0623': '\u0627',  # Alef with Hamza above → Alef
    '\u0625': '\u0627',  # Alef with Hamza below → Alef
    '\u0671': '\u0627',  # Alef Wasla → Alef
}

def normalize_alef(text):
    """Normalize for matching purposes only."""
    for variant, replacement in ALEF_VARIANTS.items():
        text = text.replace(variant, replacement)
    return text
```

### 3. Taa Marbuta / Haa Normalization

For matching and deduplication:
```python
def normalize_taa_marbuta(text):
    """Normalize Taa Marbuta to Haa for matching."""
    return text.replace('\u0629', '\u0647')  # ة → ه
```

### 4. Diacritics (Tashkeel) Handling

Remove diacritics for matching, preserve for display if present:
```python
import re

TASHKEEL_PATTERN = re.compile(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]')

def remove_tashkeel(text):
    return TASHKEEL_PATTERN.sub('', text)
```

### 5. Tatweel (Kashida) Removal

Remove stretching characters used for display alignment:
```python
def remove_tatweel(text):
    return text.replace('\u0640', '')  # ـ
```

## Validation Rules

### Arabic Text Detection

```python
ARABIC_RANGE = re.compile(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')

def contains_arabic(text):
    """Check if text contains Arabic characters."""
    return bool(ARABIC_RANGE.search(text))

def is_predominantly_arabic(text):
    """Check if text is mostly Arabic (>50% Arabic chars)."""
    if not text:
        return False
    arabic_chars = len(ARABIC_RANGE.findall(text))
    total_chars = len(text.replace(' ', ''))
    return arabic_chars / max(total_chars, 1) > 0.5
```

### Common Issues to Flag

| Issue | Detection | Action |
|---|---|---|
| Latin text in Arabic field | `not contains_arabic(text)` | Flag as gap |
| Transliterated Arabic | Detects patterns like "ma6bakh", "3arab" | Flag — not real Arabic |
| Mojibake (encoding corruption) | Detects `Ø` `Ù` sequences in supposedly Arabic text | Flag as encoding error |
| HTML entities | `&amp;#1605;` patterns | Decode to actual Arabic |
| Mixed direction without proper marks | Arabic + numbers/English | Add directional marks if needed |

### Mojibake Detection

```python
def detect_mojibake(text):
    """Detect UTF-8 interpreted as Latin-1 (common Arabic encoding issue)."""
    mojibake_patterns = ['Ø', 'Ù', 'Ú', 'Û']
    return any(p in text for p in mojibake_patterns) and not contains_arabic(text)

def fix_mojibake(text):
    """Attempt to fix Arabic mojibake."""
    try:
        return text.encode('latin-1').decode('utf-8')
    except (UnicodeDecodeError, UnicodeEncodeError):
        return text  # Can't fix, return as-is
```

## Deduplication with Arabic

When comparing Arabic text for deduplication:

```python
def arabic_match_key(text):
    """Create a normalized key for Arabic text matching."""
    if text is None:
        return None
    text = normalize_arabic(text)
    text = normalize_alef(text)
    text = normalize_taa_marbuta(text)
    text = remove_tashkeel(text)
    text = remove_tatweel(text)
    text = text.strip()
    return text
```

Compare `arabic_match_key(name1) == arabic_match_key(name2)` for fuzzy Arabic matching.

## Rules

1. Always store the **original** Arabic text — normalize only for matching/comparison
2. Never transliterate Arabic to Latin — keep Arabic script
3. Ensure all output files use UTF-8 encoding
4. When writing CSV, use UTF-8 BOM (`\xEF\xBB\xBF`) for Excel compatibility
5. Test Arabic text renders correctly by checking for Mojibake patterns
6. For bilingual entries (ar + en), validate that the Arabic field actually contains Arabic
