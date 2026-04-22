#!/bin/bash
# readers-retreat/publish-new.sh
# Incremental publish script for new/updated .txt and .pdf stories

set -e  # Exit on error

STORIES_DIR="stories"
GITHUB_USER="norsiwel"
REPO="readers-retreat"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_USER/$REPO/$BRANCH/$STORIES_DIR"

if [ ! -d "$STORIES_DIR" ]; then
  echo "❌ Error: '$STORIES_DIR' directory not found."
  exit 1
fi

# Use an array to collect candidate files safely (.txt and .pdf)
mapfile -t CANDIDATE_FILES < <(find "$STORIES_DIR" \( -name "*.txt" -o -name "*.pdf" \) -type f 2>/dev/null | sort)

if [ ${#CANDIDATE_FILES[@]} -eq 0 ]; then
  echo "✅ No .txt or .pdf files found in '$STORIES_DIR'."
  exit 0
fi

# Now check which ones are actually changed vs HEAD
CHANGED_FILES=()
for file in "${CANDIDATE_FILES[@]}"; do
  # Check if file differs from HEAD (or is untracked)
  if ! git diff --quiet HEAD -- "$file" 2>/dev/null || ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    CHANGED_FILES+=("$file")
  fi
done

# Also detect deletions: files that exist in Git but not on disk
DELETED_FILES=()
while IFS= read -r -d '' tracked_file; do
  if [ ! -e "$tracked_file" ]; then
    DELETED_FILES+=("$tracked_file")
  fi
done < <(git ls-files -z -- "$STORIES_DIR/*.txt" "$STORIES_DIR/*.pdf" 2>/dev/null)

# Combine changed + deleted
ALL_CHANGES=("${CHANGED_FILES[@]}" "${DELETED_FILES[@]}")

if [ ${#ALL_CHANGES[@]} -eq 0 ]; then
  echo "✅ No new, modified, or deleted .txt or .pdf files in '$STORIES_DIR'."
  exit 0
fi

echo "📄 Found changed stories:"
for i in "${!ALL_CHANGES[@]}"; do
  echo "  $((i+1))) ${ALL_CHANGES[i]}"
done

echo
read -p "Add and publish these files? (y/N): " -n1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Abort."
  exit 0
fi

# Stage all changes (including deletions)
git add -A -- "${ALL_CHANGES[@]}"

# Extract titles (only for existing files)
TITLES=()
for file in "${CHANGED_FILES[@]}"; do
  if [ -f "$file" ]; then
    title=$(head -n1 "$file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    TITLES+=("$title")
  fi
done

# ── Regenerate llms.txt from ALL stories currently in the folder ──────────────
echo
echo "📝 Regenerating llms.txt..."

mapfile -t ALL_STORY_FILES < <(find "$STORIES_DIR" \( -name "*.txt" -o -name "*.pdf" -o -name "*.md" \) | sort)

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

# Build commit message
COUNT=${#TITLES[@]}
if [ $COUNT -eq 0 ] && [ ${#DELETED_FILES[@]} -gt 0 ]; then
  DEFAULT_MSG="Remove ${#DELETED_FILES[@]} story file(s)"
elif [ $COUNT -eq 1 ]; then
  DEFAULT_MSG="Add story: ${TITLES[0]}"
else
  DISPLAY_TITLES=$(printf '%s\n' "${TITLES[@]}" | head -n 3 | paste -sd ', ' -)
  if [ $COUNT -gt 3 ]; then
    DISPLAY_TITLES="$DISPLAY_TITLES, +$((COUNT - 3))"
  fi
  if [ ${#DELETED_FILES[@]} -gt 0 ]; then
    DEFAULT_MSG="Update stories: $DISPLAY_TITLES (+${#DELETED_FILES[@]} deleted)"
  else
    DEFAULT_MSG="Add $COUNT new stories: $DISPLAY_TITLES"
  fi
fi

echo
echo "Default commit message: $DEFAULT_MSG"
read -p "Press Enter to use it, or type a custom message: " CUSTOM_MSG
COMMIT_MSG="${CUSTOM_MSG:-$DEFAULT_MSG}"

git commit -m "$COMMIT_MSG"
echo
echo "🚀 Pushing to GitHub..."
git push origin main

echo
echo "✅ Done! Your stories are live at:"
echo "   https://norsiwel.github.io/readers-retreat/"
