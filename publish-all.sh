#!/bin/bash
# readers-retreat/publish-all.sh
# Full publish script — stages EVERYTHING and pushes to GitHub.
# Use this when you want to sync the entire local repo (index, stories, PDFs, etc.)

set -euo pipefail

STORIES_DIR="stories"
PDF_DIR=".pdf"
GITHUB_USER="norsiwel"
REPO="readers-retreat"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_USER/$REPO/$BRANCH/$STORIES_DIR"
SITE_BASE="https://$GITHUB_USER.github.io/$REPO"

# ── Show what git sees as changed ────────────────────────────────────────────
echo "📋 Current repo status:"
git status --short
echo

read -p "Stage everything and push? (y/N): " -n1 -r
echo
if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
  echo "Abort."
  exit 0
fi

# Stage the whole repo
git add -A

# ── Build safe file lists ────────────────────────────────────────────────────
mapfile -d '' -t ALL_STORY_FILES < <(
  find "$STORIES_DIR" -type f \( -name "*.txt" -o -name "*.md" \) -print0 | sort -z
)

mapfile -d '' -t TOP_LEVEL_STORY_FILES < <(
  find "$STORIES_DIR" -maxdepth 1 -type f \( -name "*.txt" -o -name "*.md" \) -print0 | sort -z
)

mapfile -d '' -t PDF_FILES < <(
  find "$PDF_DIR" -type f -name "*.pdf" -print0 2>/dev/null | sort -z || true
)

# ── Regenerate llms.txt ──────────────────────────────────────────────────────
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

# ── Regenerate sitemap.xml ───────────────────────────────────────────────────
echo "🗺️  Regenerating sitemap.xml..."

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo ''
  echo '    <!-- Main site -->'
  echo '    <url>'
  echo "        <loc>$SITE_BASE/</loc>"
  echo '        <changefreq>weekly</changefreq>'
  echo '        <priority>1.0</priority>'
  echo '    </url>'
  echo ''
  echo '    <!-- Stories -->'

  for FILE in "${ALL_STORY_FILES[@]}"; do
    FILENAME=$(basename "$FILE")
    echo '    <url>'
    echo "        <loc>$RAW_BASE/$FILENAME</loc>"
    echo '        <changefreq>monthly</changefreq>'
    echo '        <priority>0.8</priority>'
    echo '    </url>'
  done

  echo ''
  echo '    <!-- PDFs -->'
  for PDF_FILE in "${PDF_FILES[@]}"; do
    PDFNAME=$(basename "$PDF_FILE")
    echo '    <url>'
    echo "        <loc>$SITE_BASE/$PDF_DIR/$PDFNAME</loc>"
    echo '        <changefreq>monthly</changefreq>'
    echo '        <priority>0.9</priority>'
    echo '    </url>'
  done

  echo '</urlset>'
} > sitemap.xml

git add sitemap.xml
echo "✅ sitemap.xml updated."

# ── Regenerate manifest.json ─────────────────────────────────────────────────
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

# ── Commit message ────────────────────────────────────────────────────────────
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
