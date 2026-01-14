#!/bin/bash
# Usage: ./gp.sh "your commit message"

# 1. Check if a message was provided
if [ -z "$1" ]; then
    echo "❌ Error: Please provide a commit message."
    echo "Usage: ./gp.sh \"fixed the database timeout issue\""
    exit 1
fi

# 2. Stage all changes
echo "📦 Staging changes..."
git add .

# 3. Show status
echo "🔍 Current Status:"
git status --short

# 4. Commit
echo "💾 Committing with message: $1"
git commit -m "$1"

# 5. Push
echo "🚀 Pushing to remote..."
git push

echo "✅ Done!"
