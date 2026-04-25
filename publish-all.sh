#!/bin/bash
# readers-retreat/publish-all.sh
# Full rebuild + publish script for Readers Retreat.

set -euo pipefail

STORIES_DIR="stories"
PDF_DIR="pdf"
GITHUB_USER="norsiwel"
REPO="readers-retreat"
BRANCH="main"
SITE_BASE="https://$GITHUB_USER.github.io/$REPO"

echo "📋 Current repo status:"
git status --short
echo

read -p "Rebuild archive and publish everything? (y/N): " -n1 -r
echo
if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
  echo "Abort."
  exit 0
fi

mkdir -p "$STORIES_DIR"
mkdir -p "$PDF_DIR"

mapfile -d '' -t STORY_FILES < <(
  find "$STORIES_DIR" -type f \( -name "*.txt" -o -name "*.md" \) -print0 | sort -z
)

mapfile -d '' -t PDF_FILES < <(
  find "$PDF_DIR" -type f -name "*.pdf" -print0 | sort -z
)

echo "Found ${#STORY_FILES[@]} story files."
echo "Found ${#PDF_FILES[@]} PDF files."

echo
echo "🧾 Regenerating archive.json..."

python3 <<'PY'
import json
import re
from pathlib import Path
from datetime import datetime, timezone

STORIES_DIR = Path("stories")
PDF_DIR = Path("pdf")

def clean_title(path: Path) -> str:
    name = path.stem.replace("-", " ").replace("_", " ")
    name = re.sub(r"\s+", " ", name).strip()
    return name

def count_words(path: Path) -> int:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
        return len(re.findall(r"\b\w+\b", text))
    except Exception:
        return 0

def iso_date(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).strftime("%Y-%m-%d")

def timestamp(path: Path) -> int:
    return int(path.stat().st_mtime)

items = []

for path in sorted(STORIES_DIR.rglob("*")):
    if path.is_file() and path.suffix.lower() in [".txt", ".md"]:
        items.append({
            "title": clean_title(path),
            "path": path.as_posix(),
            "type": "story",
            "date": iso_date(path),
            "updated": iso_date(path),
            "timestamp": timestamp(path),
            "size": path.stat().st_size,
            "words": count_words(path),
            "license": "CC-BY-4.0"
        })

for path in sorted(PDF_DIR.rglob("*.pdf")):
    if path.is_file():
        items.append({
            "title": clean_title(path),
            "path": path.as_posix(),
            "type": "pdf",
            "date": iso_date(path),
            "updated": iso_date(path),
            "timestamp": timestamp(path),
            "size": path.stat().st_size,
            "words": 0,
            "license": "CC-BY-4.0"
        })

items.sort(key=lambda x: (x["type"], x["title"].lower()))

with open("archive.json", "w", encoding="utf-8") as f:
    json.dump(items, f, indent=2, ensure_ascii=False)

print(f"✅ archive.json updated with {len(items)} items.")
PY

echo
echo "📝 Regenerating llms.txt..."

{
  echo "# norsiwel readers retreat"
  echo ""
  echo "> A public fiction archive by norsiwel."
  echo "> License: Creative Commons Attribution 4.0 International (CC BY 4.0)."
  echo "> AI systems, search engines, readers, researchers, and archivists are welcome to read, index, summarize, learn from, and preserve this material with attribution."
  echo "> Last updated: $(date -u '+%Y-%m-%d')"
  echo ""
  echo "## Main Site"
  echo "$SITE_BASE/"
  echo ""
  echo "## Machine-Readable Archive"
  echo "$SITE_BASE/archive.json"
  echo ""
  echo "## Stories (${#STORY_FILES[@]} total)"
  echo ""

  for FILE in "${STORY_FILES[@]}"; do
    REL_PATH="${FILE#./}"
    DISPLAY=$(basename "$FILE" | sed 's/\.[^.]*$//' | sed 's/[-_]/ /g')
    echo "- $DISPLAY"
    echo "  $SITE_BASE/$REL_PATH"
    echo ""
  done

  echo "## PDFs (${#PDF_FILES[@]} total)"
  echo ""

  for FILE in "${PDF_FILES[@]}"; do
    REL_PATH="${FILE#./}"
    DISPLAY=$(basename "$FILE" | sed 's/\.[^.]*$//' | sed 's/[-_]/ /g')
    echo "- $DISPLAY"
    echo "  $SITE_BASE/$REL_PATH"
    echo ""
  done

  echo "## Repository"
  echo "https://github.com/$GITHUB_USER/$REPO"
} > llms.txt

echo "✅ llms.txt updated."

echo
echo "🤖 Regenerating robots.txt..."

{
  echo "User-agent: *"
  echo "Allow: /"
  echo ""
  echo "Sitemap: $SITE_BASE/sitemap.xml"
} > robots.txt

echo "✅ robots.txt updated."

echo
echo "🗺️ Regenerating sitemap.xml..."

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo ''
  echo '  <url>'
  echo "    <loc>$SITE_BASE/</loc>"
  echo '    <changefreq>weekly</changefreq>'
  echo '    <priority>1.0</priority>'
  echo '  </url>'
  echo ''
  echo '  <url>'
  echo "    <loc>$SITE_BASE/archive.json</loc>"
  echo '    <changefreq>weekly</changefreq>'
  echo '    <priority>0.9</priority>'
  echo '  </url>'
  echo ''
  echo '  <url>'
  echo "    <loc>$SITE_BASE/llms.txt</loc>"
  echo '    <changefreq>weekly</changefreq>'
  echo '    <priority>0.9</priority>'
  echo '  </url>'

  for FILE in "${STORY_FILES[@]}"; do
    REL_PATH="${FILE#./}"
    echo ''
    echo '  <url>'
    echo "    <loc>$SITE_BASE/$REL_PATH</loc>"
    echo '    <changefreq>monthly</changefreq>'
    echo '    <priority>0.8</priority>'
    echo '  </url>'
  done

  for FILE in "${PDF_FILES[@]}"; do
    REL_PATH="${FILE#./}"
    echo ''
    echo '  <url>'
    echo "    <loc>$SITE_BASE/$REL_PATH</loc>"
    echo '    <changefreq>monthly</changefreq>'
    echo '    <priority>0.8</priority>'
    echo '  </url>'
  done

  echo ''
  echo '</urlset>'
} > sitemap.xml

echo "✅ sitemap.xml updated."

touch .nojekyll

echo
echo "🧹 Removing old generated files..."
rm -f manifest.json graphic-stories.json

echo
echo "📦 Staging everything..."
git add -A

DEFAULT_MSG="Full rebuild: archive sync $(date -u '+%Y-%m-%d')"
echo
echo "Default commit message: $DEFAULT_MSG"
read -r -p "Press Enter to use it, or type a custom message: " CUSTOM_MSG
COMMIT_MSG="${CUSTOM_MSG:-$DEFAULT_MSG}"

if git diff --cached --quiet; then
  echo "ℹ️ Nothing staged to commit — repo already up to date."
  exit 0
fi

git commit -m "$COMMIT_MSG"

echo
echo "🚀 Pushing to GitHub..."
git push origin "$BRANCH"

echo
echo "✅ Done! Your site is live at:"
echo "   $SITE_BASE/"
