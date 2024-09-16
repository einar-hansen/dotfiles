#!/bin/bash

# Function to check if OPENAI_API_KEY is set
check_api_key() {
  if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY environment variable is not set." >&2
    return 1
  fi
}

# Function to call the OpenAI API
call_openai_api() {
  local JSON_PAYLOAD="$1"

  curl -sS --fail https://api.openai.com/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$JSON_PAYLOAD"
}

# Function to extract content from the API response
extract_content_from_response() {
  local RESPONSE="$1"

  # Check for error in the response
  if echo "$RESPONSE" | grep -q '"error":'; then
    local ERROR_MSG=$(echo "$RESPONSE" | grep -o '"message": *"[^"]*"' | sed 's/"message": *"//;s/"$//')
    echo "Error from OpenAI API: $ERROR_MSG" >&2
    return 1
  fi

  # Extract content using grep and sed
  local CONTENT=$(echo "$RESPONSE" | grep -o '"content": *"[^"]*"' | sed 's/"content": *"//;s/"$//')

  if [ -n "$CONTENT" ]; then
    # Unescape the content
    echo -e "$(echo "$CONTENT" | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')"
    return 0
  else
    echo "Error: Failed to extract content from API response. Raw response:" >&2
    echo "$RESPONSE" >&2
    return 1
  fi
}

# Function to interact with OpenAI's GPT model from the terminal
gpt() {
  check_api_key || return 1

  local TEMPERATURE=0.7
  local MAX_TOKENS=500
  local MODEL="gpt-4o-mini"
  local SYSTEM_PROMPT="You are a helpful assistant. Provide concise and informative answers to user queries."

  # Parse options
  while [[ "$1" =~ ^- ]]; do
    case "$1" in
      -t|--temperature)
        shift
        TEMPERATURE="$1"
        ;;
      -m|--max-tokens)
        shift
        MAX_TOKENS="$1"
        ;;
      -M|--model)
        shift
        MODEL="$1"
        ;;
      -h|--help)
        echo "Usage: gpt [options] \"Your question here\""
        echo
        echo "Options:"
        echo "  -t, --temperature   Set the temperature (default: $TEMPERATURE)"
        echo "  -m, --max-tokens    Set the max tokens (default: $MAX_TOKENS)"
        echo "  -M, --model         Set the model name (default: $MODEL)"
        echo "  -h, --help          Display this help message"
        return 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  # Read user prompt
  local USER_PROMPT
  if [ $# -gt 0 ]; then
    USER_PROMPT="$*"
  elif [ ! -t 0 ]; then
    USER_PROMPT="$(cat)"
  else
    echo "Error: No input provided." >&2
    echo "Usage: gpt \"Your question here\"" >&2
    return 1
  fi

  # Construct JSON payload
  local JSON_PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "messages": [
    {"role": "system", "content": "$SYSTEM_PROMPT"},
    {"role": "user", "content": "$USER_PROMPT"}
  ],
  "temperature": $TEMPERATURE,
  "max_tokens": $MAX_TOKENS
}
EOF
)

  local RESPONSE=$(call_openai_api "$JSON_PAYLOAD")

  if [ $? -ne 0 ]; then
    echo "$RESPONSE" >&2
    return 1
  fi

  extract_content_from_response "$RESPONSE"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  gpt "$@"
fi
