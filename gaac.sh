gaac() {
  # Function to clean control characters from JSON response and escape unescaped newlines
  # clean_json_response() {
  #   echo "$1" | perl -0pe 's/\\n/\\\\n/g; s/([^\\])\n/\1\\n/g;'
  # }

  # Check if there are staged files
  STAGED_FILES=$(git diff --cached --name-only)
  if [[ -z "$STAGED_FILES" ]]; then
    echo "No files are staged for commit."
    return 1
  fi

  # Get the diff of staged files
  GIT_DIFF=$(git diff --cached)

  # Build the prompt for the API
  SYSTEM_PROMPT="You are a helpful assistant that writes extremely concise and effective git commit messages based on changes provided. Your commit messages should be no longer than 50 characters if possible, and never exceed 72 characters."
  USER_PROMPT="Generate a concise git commit message for the following changes. Use the imperative mood, and start with a capital letter. Do not use punctuation at the end. Here are some examples of good commit messages:
- Add user authentication feature
- Fix memory leak in data processing
- Update README with API documentation
- Refactor database connection logic
- Optimize image loading algorithm

Now, generate a commit message for these changes:

$GIT_DIFF"

  # Create a JSON payload for the API request
  JSON_PAYLOAD=$(jq -n \
    --arg model "gpt-4o-mini" \
    --arg system_prompt "$SYSTEM_PROMPT" \
    --arg user_prompt "$USER_PROMPT" \
    '{
      model: $model,
      messages: [
        {"role": "system", "content": $system_prompt},
        {"role": "user", "content": $user_prompt}
      ],
      max_tokens: 100,
      temperature: 0.5
    }'
  )

  # Call the OpenAI API
  RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$JSON_PAYLOAD"
  )

  # Print the full response for debugging
  echo "Full API Response:"
  echo "$RESPONSE"
  echo "-------------------------"

  # Clean control characters and escape unescaped newlines in the response
  CLEAN_RESPONSE="$RESPONSE"

  # Check if the response is valid JSON
  if ! echo "$CLEAN_RESPONSE" | jq empty >/dev/null 2>&1; then
    echo "Received invalid JSON from the API."
    return 1
  fi

  # Check for API errors
  ERROR_MSG=$(printf '%s\n' "$CLEAN_RESPONSE" | jq -r '.error.message // empty')
  if [[ -n "$ERROR_MSG" ]]; then
    echo "Error from API: $ERROR_MSG"
    return 1
  fi

  # Extract the commit message
  COMMIT_MESSAGE=$(echo "$CLEAN_RESPONSE" | jq -r '.choices[0].message.content')

  if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo "Failed to generate commit message or received empty message."
    echo "Would you like to enter a commit message manually? (y/n)"
    read -k1 MANUAL_INPUT
    echo
    if [[ "$MANUAL_INPUT" == "y" ]]; then
      echo "Enter your commit message:"
      read -r COMMIT_MESSAGE
    else
      echo "Commit canceled."
      return 1
    fi
  fi

  # Display the commit message and staged files
  echo
  echo "Generated commit message:"
  echo "-------------------------"
  echo "$COMMIT_MESSAGE"
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
    echo "$COMMIT_MESSAGE" > "$TEMP_FILE"
    "${EDITOR:-nano}" "$TEMP_FILE"
    COMMIT_MESSAGE=$(cat "$TEMP_FILE")
    rm "$TEMP_FILE"
  fi
  # Commit the changes
  git commit -m "$COMMIT_MESSAGE"


  # Ask if the user wants to create a pull request
  echo "Do you want to create a pull request? (y/n)"
  read -k1 CREATE_PR
  echo

  if [[ "$CREATE_PR" == "y" ]]; then
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
    SYSTEM_PROMPT="You are a helpful assistant that generates concise and informative pull request titles and descriptions based on git commit history. For the title, provide a brief summary of the overall changes. For the body, provide a more detailed explanation of the changes, including any notable additions, modifications, or potential impacts. Use markdown formatting for the body."
    USER_PROMPT="Generate a pull request title and body for the following commit history:\n\n$COMMIT_HISTORY"

    JSON_PAYLOAD=$(jq -n \
      --arg model "gpt-4o-mini" \
      --arg system_prompt "$SYSTEM_PROMPT" \
      --arg user_prompt "$USER_PROMPT" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $system_prompt},
          {role: "user", content: $user_prompt}
        ],
        temperature: 0.7,
        max_tokens: 500
      }'
    )

    # Call the OpenAI API
    RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$JSON_PAYLOAD"
    )

    echo "$RESPONSE" > response.json
    echo "$RESPONSE" > response2.json

    echo "----RAW RESPONSE----"
    echo "$RESPONSE"
    echo "----"

    # Clean control characters and escape unescaped newlines in the response
    CLEAN_RESPONSE="$RESPONSE"

    # Check if the response is valid JSON
    if ! echo "$CLEAN_RESPONSE" | jq empty >/dev/null 2>&1; then
      echo "Received invalid JSON from the API."
      return 1
    fi

    # Check for API errors
    ERROR_MSG=$(printf '%s\n' "$CLEAN_RESPONSE" | jq -r '.error.message // empty')
    if [[ -n "$ERROR_MSG" ]]; then
      echo "Error from API: $ERROR_MSG"
      return 1
    fi

    # Extract the AI-generated content
    AI_CONTENT=$(echo "$CLEAN_RESPONSE" | jq -r '.choices[0].message.content')

    # Extract the title and body
    if [[ "$AI_CONTENT" == *"### Pull Request Title"* ]]; then
        PR_TITLE=$(echo "$AI_CONTENT" | sed -n '/^### Pull Request Title/,/^###/p' | sed '1d;/^###/d' | tr -d '\r\n')
        PR_BODY=$(echo "$AI_CONTENT" | sed -n '/^### Pull Request Description/,$p' | sed '1d')
    else
        # Fallback to the previous method if the specific format is not found
        PR_TITLE=$(echo "$AI_CONTENT" | sed -n '1p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        PR_BODY=$(echo "$AI_CONTENT" | sed '1d')
    fi

    # Truncate the title if it's too long
    if [ ${#PR_TITLE} -gt 72 ]; then
        PR_TITLE="${PR_TITLE:0:69}..."
    fi

    # Display the generated title and body
    echo "AI-generated Pull Request Title:"
    echo "$PR_TITLE"
    echo
    echo "AI-generated Pull Request Body:"
    echo "$PR_BODY"
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
  else
    # If no PR is created, just push the changes
    git push
  fi
}
