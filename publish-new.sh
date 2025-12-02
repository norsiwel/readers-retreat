#!/bin/bash
# readers-retreat/publish-new.sh
# Incremental publish script for new/updated .txt stories

set -e  # Exit on error

STORIES_DIR="stories"

if [ ! -d "$STORIES_DIR" ]; then
  echo "❌ Error: '$STORIES_DIR' directory not found."
  exit 1
fi

# Find .txt files that are either:
# - untracked (new), or
# - modified (but not deleted)
NEW_OR_CHANGED=$(git ls-files -o -m --exclude-standard "$STORIES_DIR/*.txt" 2>/dev/null)

if [ -z "$NEW_OR_CHANGED" ]; then
  echo "✅ No new or modified .txt files in '$STORIES_DIR'."
  exit 0
fi

echo "📄 Found new/modified stories:"
echo "$NEW_OR_CHANGED" | nl -w2 -s') '

echo
read -p "Add and publish these files? (y/N): " -n1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Abort."
  exit 0
fi

# Add only the relevant files
git add $NEW_OR_CHANGED

# Generate default message: "Add X new stories: Title1, Title2..."
TITLES=()
while IFS= read -r file; do
  # Extract display title (first line of file)
  title=$(head -n1 "$file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  TITLES+=("$title")
done <<< "$NEW_OR_CHANGED"

COUNT=${#TITLES[@]}
if [ "$COUNT" -eq 1 ]; then
  DEFAULT_MSG="Add story: ${TITLES[0]}"
else
  # Join first 3 titles to avoid huge messages
  DISPLAY_TITLES=$(printf '%s\n' "${TITLES[@]}" | head -n 3 | paste -sd ', ' -)
  if [ "$COUNT" -gt 3 ]; then
    DISPLAY_TITLES="$DISPLAY_TITLES, +$((COUNT - 3))"
  fi
  DEFAULT_MSG="Add $COUNT new stories: $DISPLAY_TITLES"
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
