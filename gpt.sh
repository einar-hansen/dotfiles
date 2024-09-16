#!/bin/bash

# Function to check if OPENAI_API_KEY is set
check_api_key() {
  if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY environment variable is not set." >&2
    return 1
  fi
}

# Function to interact with OpenAI's GPT model using the OpenAI CLI
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

  # Call OpenAI CLI
  local RESPONSE=$(openai api chat.completions.create \
    -m "$MODEL" \
    -g "system" "$SYSTEM_PROMPT" \
    -g "user" "$USER_PROMPT" \
    --temperature "$TEMPERATURE" \
    --max-tokens "$MAX_TOKENS")

  # Check for errors
  if [ $? -ne 0 ]; then
    echo "Error: OpenAI CLI command failed" >&2
    echo "$RESPONSE" >&2
    return 1
  fi

  # Extract and print the content
  echo "$RESPONSE"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  gpt "$@"
fi
