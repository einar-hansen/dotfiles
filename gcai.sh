# Function for generating and making a commit
ai_commit() {
  # Check if there are staged files
  STAGED_FILES=$(git diff --cached --name-only)
  if [[ -z "$STAGED_FILES" ]]; then
    echo "No files are staged for commit."
    return 1
  fi

  # Get the diff of staged files
  GIT_DIFF=$(git diff --cached)

  # Build the prompt for the API
  SYSTEM_PROMPT="You are a helpful assistant that writes effective git commit messages based on changes provided. Provide your response in a structured format with a subject line and an optional body. The subject line should be no longer than 50 characters if possible, and never exceed 72 characters. Use the imperative mood, start with a capital letter, and do not use punctuation at the end for the subject line. If you think a body is necessary to provide more context or explanation, include it after a blank line. Use the following structure:
SUBJECT: <subject line here>
BODY:
<body content here, if needed>"
  USER_PROMPT="Generate a git commit message for the following changes:

$GIT_DIFF"

  COMMIT_MESSAGE=$(openai api chat.completions.create \
    -m gpt-4o-mini \
    -g system "$SYSTEM_PROMPT" \
    -g user "$USER_PROMPT" \
    --temperature 0.7)

  if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo "Failed to generate commit message or received empty message."
    echo "Would you like to enter a commit message manually? (y/n)"
    read -k1 MANUAL_INPUT
    echo
    if [[ "$MANUAL_INPUT" == "y" ]]; then
      echo "Enter your commit subject line:"
      read -r COMMIT_SUBJECT
      echo "Enter your commit body (press Ctrl+D when finished, leave empty if not needed):"
      COMMIT_BODY=$(cat)
    else
      echo "Commit canceled."
      return 1
    fi
  else
    # Extract the subject and body
    COMMIT_SUBJECT=$(echo "$COMMIT_MESSAGE" | sed -n 's/^SUBJECT: //p')
    COMMIT_BODY=$(echo "$COMMIT_MESSAGE" | sed -n '/^BODY:/,$p' | sed '1d')
  fi

  # Truncate the subject if it's too long
  if [ ${#COMMIT_SUBJECT} -gt 72 ]; then
    COMMIT_SUBJECT="${COMMIT_SUBJECT:0:69}..."
  fi

  # Display the commit message and staged files
  echo
  echo "Generated commit message:"
  echo "-------------------------"
  echo "Subject: $COMMIT_SUBJECT"
  if [[ -n "$COMMIT_BODY" ]]; then
    echo
    echo "Body:"
    echo "$COMMIT_BODY"
  fi
  echo "-------------------------"
  echo
  echo "Staged files:"
  echo "-------------------------"
  echo "$STAGED_FILES"
  echo "-------------------------"
  echo

  # Prompt for user confirmation or editing
  echo "Press 'e' to edit the commit message, 'c' to cancel, or any other key to confirm and commit:"
  read -k1 USER_INPUT
  echo
  if [[ "$USER_INPUT" == "c" ]]; then
    echo "Commit canceled."
    return 1
  elif [[ "$USER_INPUT" == "e" ]]; then
    # Open the commit message in the default editor
    TEMP_FILE=$(mktemp)
    echo "$COMMIT_SUBJECT" > "$TEMP_FILE"
    if [[ -n "$COMMIT_BODY" ]]; then
      echo >> "$TEMP_FILE"
      echo "$COMMIT_BODY" >> "$TEMP_FILE"
    fi
    "${EDITOR:-nano}" "$TEMP_FILE"
    COMMIT_SUBJECT=$(head -n 1 "$TEMP_FILE")
    COMMIT_BODY=$(tail -n +3 "$TEMP_FILE")
    rm "$TEMP_FILE"
  fi

  # Commit the changes
  if [[ -n "$COMMIT_BODY" ]]; then
    git commit -m "$COMMIT_SUBJECT" -m "$COMMIT_BODY"
  else
    git commit -m "$COMMIT_SUBJECT"
  fi
}

# Function for creating a pull request
ai_pr() {
  # Get the current branch name
  CURRENT_BRANCH=$(git branch --show-current)

  # Check if the branch has an upstream branch
  UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)

  if [[ -z "$UPSTREAM" ]]; then
    echo "No upstream branch is set for $CURRENT_BRANCH."
    echo "Choose an option:"
    echo "1) Push to origin/$CURRENT_BRANCH"
    echo "2) Push to origin/main"
    echo "3) Enter a custom branch name"
    read -k1 PUSH_OPTION
    echo

    case $PUSH_OPTION in
      1)
        git push -u origin "$CURRENT_BRANCH"
        ;;
      2)
        git push -u origin "$CURRENT_BRANCH:main"
        CURRENT_BRANCH="main"
        ;;
      3)
        echo "Enter the name of the remote branch:"
        read -r REMOTE_BRANCH
        git push -u origin "$CURRENT_BRANCH:$REMOTE_BRANCH"
        CURRENT_BRANCH="$REMOTE_BRANCH"
        ;;
      *)
        echo "Invalid option. Aborting."
        return 1
        ;;
    esac
  else
    # Push the current branch to its upstream
    git push
  fi

  # Get the repository URL
  REPO_URL=$(git config --get remote.origin.url)
  REPO_URL=${REPO_URL#*:}
  REPO_URL=${REPO_URL%.git}

  # Get the commit history for the current branch
  COMMIT_HISTORY=$(git log origin/main.."$CURRENT_BRANCH" --pretty=format:"%h %s")

  # Generate PR title and body using AI
  SYSTEM_PROMPT="You are a helpful assistant that generates concise and informative pull request titles and descriptions based on git commit history. Provide your response in a structured format with a title (max 72 characters) and a body (using markdown formatting). Use the following structure:
TITLE: <title here>
BODY:
<body content here>"
  USER_PROMPT="Generate a pull request title and body for the following commit history:\n\n$COMMIT_HISTORY"

  # Call the OpenAI API using the CLI
  AI_CONTENT=$(openai api chat.completions.create \
    -m gpt-4o-mini \
    -g system "$SYSTEM_PROMPT" \
    -g user "$USER_PROMPT" \
    --temperature 0.7 \
    --max-tokens 500)

  # Extract the title and body
  PR_TITLE=$(echo "$AI_CONTENT" | sed -n 's/^TITLE: //p')
  PR_BODY=$(echo "$AI_CONTENT" | sed -n '/^BODY:/,$p' | sed '1d')

  # Truncate the title if it's too long
  if [ ${#PR_TITLE} -gt 72 ]; then
    PR_TITLE="${PR_TITLE:0:69}..."
  fi

  # Display the generated title and body
  echo
  echo "Generated title:"
  echo "-------------------------"
  echo "$PR_TITLE"
  echo "-------------------------"
  echo
  echo "Generated body:"
  echo "-------------------------"
  echo "$PR_BODY"
  echo "-------------------------"
  echo

  # Ask user if they want to use the AI-generated content or enter their own
  echo "Do you want to use this AI-generated title and body? (y/n)"
  read -k1 USE_AI_CONTENT
  echo

  if [[ "$USE_AI_CONTENT" != "y" ]]; then
    echo "Enter a title for the pull request:"
    read -r PR_TITLE
    echo "Enter a body for the pull request (press Ctrl+D when finished):"
    PR_BODY=$(cat)
  fi

  # Create the pull request using GitHub CLI
  if command -v gh &> /dev/null; then
    gh pr create --title "$PR_TITLE" --body "$PR_BODY"

    # Open the pull request in the browser
    gh pr view --web
  else
    echo "GitHub CLI (gh) is not installed. Please install it to create pull requests automatically."
    echo "You can create a pull request manually at: https://github.com/$REPO_URL/pull/new/$CURRENT_BRANCH"
  fi
}

# Main function that combines commit and PR creation
gcai() {
  ai_commit
  if [ $? -eq 0 ]; then
    echo "Do you want to create a pull request? (y/n)"
    read -k1 CREATE_PR
    echo
    if [[ "$CREATE_PR" == "y" ]]; then
      ai_pr
    fi
  fi
}

# Main function that combines commit and PR creation
prai() {
  ai_pr
}
