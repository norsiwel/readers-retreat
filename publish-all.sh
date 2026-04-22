#!/bin/bash
# readers-retreat/publish-all.sh
# Full publish script — stages EVERYTHING and pushes to GitHub.
# Use this when you want to sync the entire local repo (index, stories, etc.)

set -e  # Exit on error

STORIES_DIR="stories"
GITHUB_USER="norsiwel"
REPO="readers-retreat"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_USER/$REPO/$BRANCH/$STORIES_DIR"

# ── Show what git sees as changed ────────────────────────────────────────────
echo "📋 Current repo status:"
git status --short
echo

read -p "Stage everything and push? (y/N): " -n1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Abort."
  exit 0
fi

# Stage the whole repo
git add -A

# ── Regenerate llms.txt ───────────────────────────────────────────────────────
echo
echo "📝 Regenerating llms.txt..."

mapfile -t ALL_STORY_FILES < <(find "$STORIES_DIR" -name "*.txt" -o -name "*.md" | sort)

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
  echo "Interactive reader: https://$GITHUB_USER.github.io/$REPO/"
  echo "Repository:         https://github.com/$GITHUB_USER/$REPO"
} > llms.txt

git add llms.txt
echo "✅ llms.txt updated with ${#ALL_STORY_FILES[@]} stories."
# ─────────────────────────────────────────────────────────────────────────────

# Commit message
DEFAULT_MSG="Full sync: update index and all content $(date -u '+%Y-%m-%d')"
echo
echo "Default commit message: $DEFAULT_MSG"
read -p "Press Enter to use it, or type a custom message: " CUSTOM_MSG
COMMIT_MSG="${CUSTOM_MSG:-$DEFAULT_MSG}"

git commit -m "$COMMIT_MSG" || { echo "ℹ️  Nothing to commit — repo already up to date."; exit 0; }
echo
echo "🚀 Pushing to GitHub..."
git push origin main

echo
echo "✅ Done! Your site is live at:"
echo "   https://norsiwel.github.io/readers-retreat/"
