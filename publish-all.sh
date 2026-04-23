#!/bin/bash
# readers-retreat/publish-all.sh
# Full publish script — stages EVERYTHING and pushes to GitHub.
# Use this when you want to sync the entire local repo (index, stories, PDFs, etc.)

set -euo pipefail

STORIES_DIR="stories"
PDF_DIR="pdf"
GITHUB_USER="norsiwel"
REPO="readers-retreat"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_USER/$REPO/$BRANCH/$STORIES_DIR"
SITE_BASE="https://$GITHUB_USER.github.io/$REPO"

echo "📋 Current repo status:"
git status --short
echo

read -p "Stage everything and push? (y/N): " -n1 -r
echo
if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
  echo "Abort."
  exit 0
fi

git add -A

mapfile -d '' -t ALL_STORY_FILES < <(
  find "$STORIES_DIR" -type f \( -name "*.txt" -o -name "*.md" \) -print0 | sort -z
)

mapfile -d '' -t TOP_LEVEL_STORY_FILES < <(
  find "$STORIES_DIR" -maxdepth 1 -type f \( -name "*.txt" -o -name "*.md" \) -print0 | sort -z
)

mapfile -d '' -t PDF_FILES < <(
  find "$PDF_DIR" -type f -name "*.pdf" -print0 2>/dev/null | sort -z || true
)

echo
echo "📝 Regenerating llms.txt..."

{
  echo "# Norsiwel's Readers Retreat"
  echo ""
  echo "> A collection of original stories by Norsiwel, freely available to read."
  echo "> Last updated: $(date -u '+%Y-%m-%d')"
  echo ""
  echo "## How to access stories"
  echo ""
  echo "Each story is a plain text file hosted on GitHub."
  echo "Fetch any story directly via its raw URL listed below."
  echo ""
  echo "Full story directory: https://github.com/$GITHUB_USER/$REPO/tree/$BRANCH/$STORIES_DIR"
  echo ""
  echo "## Stories (${#ALL_STORY_FILES[@]} total)"
  echo ""

  for FILE in "${ALL_STORY_FILES[@]}"; do
    FILENAME=$(basename "$FILE")
    DISPLAY=$(echo "$FILENAME" | sed 's/\.[^.]*$//' | sed 's/[-_]/ /g')
    echo "- $DISPLAY"
    echo "  $RAW_BASE/$FILENAME"
    echo ""
  done

  echo "## Site"
  echo ""
  echo "Interactive reader: $SITE_BASE/"
  echo "Repository:         https://github.com/$GITHUB_USER/$REPO"
} > llms.txt

git add llms.txt
echo "✅ llms.txt updated with ${#ALL_STORY_FILES[@]} stories."

echo "🗺️  Regenerating sitemap.xml..."

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo ''
  echo '    <url>'
  echo "        <loc>$SITE_BASE/</loc>"
  echo '        <changefreq>weekly</changefreq>'
  echo '        <priority>1.0</priority>'
  echo '    </url>'

  for FILE in "${ALL_STORY_FILES[@]}"; do
    FILENAME=$(basename "$FILE")
    echo '    <url>'
    echo "        <loc>$RAW_BASE/$FILENAME</loc>"
    echo '        <changefreq>monthly</changefreq>'
    echo '        <priority>0.8</priority>'
    echo '    </url>'
  done

  for PDF_FILE in "${PDF_FILES[@]}"; do
    REL_PATH="${PDF_FILE#./}"
    echo '    <url>'
    echo "        <loc>$SITE_BASE/$REL_PATH</loc>"
    echo '        <changefreq>monthly</changefreq>'
    echo '        <priority>0.9</priority>'
    echo '    </url>'
  done

  echo '</urlset>'
} > sitemap.xml

git add sitemap.xml
echo "✅ sitemap.xml updated."

echo "📋 Regenerating manifest.json..."

echo "[" > manifest.json
FIRST=1

for FILE in "${TOP_LEVEL_STORY_FILES[@]}"; do
  FILENAME=$(basename "$FILE")
  TIMESTAMP=$(stat -c "%Y" "$FILE")
  SIZE=$(stat -c "%s" "$FILE")

  if [ "$FIRST" -eq 0 ]; then
    echo "," >> manifest.json
  fi

  printf '  {"name":"%s","timestamp":%s,"size":%s}' "$FILENAME" "$TIMESTAMP" "$SIZE" >> manifest.json
  FIRST=0
done

echo "" >> manifest.json
echo "]" >> manifest.json

git add manifest.json
echo "✅ manifest.json updated."

echo "🖼️  Regenerating graphic-stories.json..."

echo "[" > graphic-stories.json
FIRST=1

if [ -d "$PDF_DIR" ]; then
  while IFS= read -r -d '' STORY_DIR; do
    SLUG=$(basename "$STORY_DIR")
    PDF_PATH="$PDF_DIR/$SLUG/issue.pdf"
    COVER_JPG="$PDF_DIR/$SLUG/cover.jpg"
    COVER_PNG="$PDF_DIR/$SLUG/cover.png"
    META_PATH="$PDF_DIR/$SLUG/meta.json"

    if [ ! -f "$PDF_PATH" ]; then
      echo "⚠️  Skipping $SLUG (missing issue.pdf)"
      continue
    fi

    if [ -f "$COVER_JPG" ]; then
      COVER_PATH="$COVER_JPG"
    elif [ -f "$COVER_PNG" ]; then
      COVER_PATH="$COVER_PNG"
    else
      COVER_PATH=""
    fi

    if [ -f "$META_PATH" ]; then
      TITLE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("title","Untitled"))' "$META_PATH")
      CARD_META=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("meta","Graphic Story"))' "$META_PATH")
    else
      TITLE=$(echo "$SLUG" | sed 's/[-_]/ /g' | sed 's/\b\(.\)/\u\1/g')
      CARD_META="Graphic Story"
    fi

    if [ "$FIRST" -eq 0 ]; then
      echo "," >> graphic-stories.json
    fi

    printf '  {"title":"%s","meta":"%s","pdf":"%s","cover":"%s"}' \
      "$TITLE" "$CARD_META" "$PDF_PATH" "$COVER_PATH" >> graphic-stories.json

    FIRST=0
  done < <(find "$PDF_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
fi

echo "" >> graphic-stories.json
echo "]" >> graphic-stories.json

git add graphic-stories.json
echo "✅ graphic-stories.json updated."

if [ ! -f ".nojekyll" ]; then
  touch .nojekyll
fi
git add .nojekyll

DEFAULT_MSG="Full sync: update index and all content $(date -u '+%Y-%m-%d')"
echo
echo "Default commit message: $DEFAULT_MSG"
read -r -p "Press Enter to use it, or type a custom message: " CUSTOM_MSG
COMMIT_MSG="${CUSTOM_MSG:-$DEFAULT_MSG}"

if git diff --cached --quiet; then
  echo "ℹ️  Nothing staged to commit — repo already up to date."
  exit 0
fi

git commit -m "$COMMIT_MSG"

echo
echo "🚀 Pushing to GitHub..."
git push origin "$BRANCH"

echo
echo "✅ Done! Your site is live at:"
echo "   $SITE_BASE/"
