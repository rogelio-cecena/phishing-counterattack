#!/usr/bin/env zsh

server_info() {
    DWH_URL="<<Target_URL>>"
    curl -s -X GET "$DWH_URL"| jq
}

generate_string() {
    local length=${1:-8}
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

cleanse_string() {
  local raw_input="$1"

  sed -e '1{/^[[:blank:]]*$/d;}' \
      -e '${/^[[:blank:]]*$/d;}' \
      -e 's/^[[:blank:]]*//' <<< "$raw_input"
}

random_sleep() {
  local min=${1:-10}
  local max=${2:-30}

  local range=$(( max - min + 1 ))
  local delay=$(( (RANDOM % range) + min ))

  printf "Sleeping for %s seconds...\n" "$delay"
  sleep "$delay"
}

post_and_validate() {
  local payload="$1"
  local target_url="$2"

  local status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$target_url")

  if [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]; then
    printf "Success! (HTTP %s)\n" "$status_code"
    return 0
  elif [[ "$status_code" -eq 429 ]]; then
    printf "Rate Limited! (HTTP 429). The server is dropping requests.\n"
    return 1
  else
    printf "❌ Error! (HTTP %s)\n" "$status_code"
    return 1
  fi
}

flood() {
    VICTIM_EMAIL="$(generate_string 5).$(generate_string 5)@example.com"
    VICTIM_PASS=$(generate_string 20)
    VICTIM_IP="$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 ))"
    VICTIM_LOC="Mexico City, Mexico"

    VICTIM_FIRST_MESSAGE="
    Email: ${VICTIM_EMAIL}
    IP: ${VICTIM_IP}
    Location: ${VICTIM_LOC}
    "
    VICTIM_FIRST_MESSAGE=$(cleanse_string $VICTIM_FIRST_MESSAGE)

    VICTIM_SECOND_MESSAGE="
    Password: ${VICTIM_PASS}
    IP: ${VICTIM_IP}
    Location: ${VICTIM_LOC}
    "
    VICTIM_SECOND_MESSAGE="\`\`\`$(cleanse_string $VICTIM_SECOND_MESSAGE)\`\`\`"

    JSON_PAYLOAD=$(jq -n --arg content "$VICTIM_FIRST_MESSAGE" '{content: $content}')
    printf "%s\n" "$JSON_PAYLOAD" | jq .
    post_and_validate "$JSON_PAYLOAD" "$DWH_URL"

    random_sleep

    JSON_PAYLOAD=$(jq -n --arg content "$VICTIM_SECOND_MESSAGE" '{content: $content}')
    printf "%s\n" "$JSON_PAYLOAD" | jq .
    post_and_validate "$JSON_PAYLOAD" "$DWH_URL"

    random_sleep

    trap 'echo "\nStop request received. Exiting gracefully..."; exit 0' SIGINT
}

server_info
while true; do
    flood
done
