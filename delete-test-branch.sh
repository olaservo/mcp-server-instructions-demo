#!/bin/bash

# Script to delete the test branch created by create-validation-pr.sh

set -e

BRANCH_NAME="feature/input-validation-enhancement"
BASE_BRANCH="main"

echo "Deleting validation enhancement test branch..."

# Check if we're currently on the branch to be deleted
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
    echo "Switching from $BRANCH_NAME to $BASE_BRANCH..."
    git checkout "$BASE_BRANCH"
fi

# Delete local branch if it exists
if git branch --list | grep -q "$BRANCH_NAME"; then
    echo "Deleting local branch: $BRANCH_NAME"
    git branch -D "$BRANCH_NAME"
else
    echo "Local branch $BRANCH_NAME not found"
fi

# Delete remote branch if it exists
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    echo "Deleting remote branch: origin/$BRANCH_NAME"
    git push origin --delete "$BRANCH_NAME"
else
    echo "Remote branch origin/$BRANCH_NAME not found"
fi

# Close any open PR for this branch
echo "Checking for open PR..."
if gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' | grep -q '^[0-9]'; then
    PR_NUMBER=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number')
    echo "Closing PR #$PR_NUMBER..."
    gh pr close "$PR_NUMBER"
else
    echo "No open PR found for branch $BRANCH_NAME"
fi

echo "Cleanup completed successfully!"
echo "Branch $BRANCH_NAME has been deleted locally and remotely"