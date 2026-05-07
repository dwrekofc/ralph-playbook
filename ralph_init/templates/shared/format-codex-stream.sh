#!/bin/bash
# Formats Codex CLI --json output into readable terminal output.
# Usage: codex exec --json ... | ./format-codex-stream.sh

RESET='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
MAGENTA='\033[35m'
RED='\033[31m'
WHITE='\033[97m'

while IFS= read -r line; do
    msg_type=$(echo "$line" | jq -r '.msg.type // .type // empty')

    case "$msg_type" in
        thread.started)
            thread_id=$(echo "$line" | jq -r '.thread_id // empty')
            echo -e "${BOLD}${CYAN}━━━ Codex Thread ━━━${RESET}"
            echo -e "${DIM}Thread: ${thread_id}${RESET}"
            echo ""
            ;;

        turn.started)
            echo -e "${BOLD}${CYAN}━━━ Turn Started ━━━${RESET}"
            ;;

        item.started)
            item_type=$(echo "$line" | jq -r '.item.type // empty')
            case "$item_type" in
                command_execution)
                    cmd=$(echo "$line" | jq -r '.item.command // empty')
                    echo -e "${YELLOW}[tool] ${BOLD}exec${RESET} ${DIM}${cmd}${RESET}"
                    ;;
                *)
                    echo -e "${CYAN}[${item_type:-item}]${RESET}"
                    ;;
            esac
            ;;

        item.completed)
            item_type=$(echo "$line" | jq -r '.item.type // empty')
            case "$item_type" in
                agent_message)
                    content=$(echo "$line" | jq -r '.item.text // empty')
                    [ -n "$content" ] && echo -e "${WHITE}${content}${RESET}\n"
                    ;;
                command_execution)
                    exit_code=$(echo "$line" | jq -r '.item.exit_code // empty')
                    output=$(echo "$line" | jq -r '.item.aggregated_output // empty' | head -c 240)
                    if [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; then
                        echo -e "${RED}  [result] exit ${exit_code}${RESET} ${DIM}${output}${RESET}"
                    else
                        echo -e "${GREEN}  [result]${RESET} ${DIM}${output}${RESET}"
                    fi
                    ;;
                *)
                    preview=$(echo "$line" | jq -c '.item // .' | head -c 240)
                    echo -e "${CYAN}[${item_type:-item completed}]${RESET} ${DIM}${preview}${RESET}"
                    ;;
            esac
            ;;

        text|agent_message|assistant_message)
            content=$(echo "$line" | jq -r '.msg.content // .message // .content // empty')
            [ -n "$content" ] && echo -e "${WHITE}${content}${RESET}\n"
            ;;

        reasoning|thinking)
            content=$(echo "$line" | jq -r '.msg.content // .summary // .content // empty')
            [ -n "$content" ] && echo -e "${MAGENTA}${BOLD}[reasoning]${RESET}\n${DIM}${content}${RESET}\n"
            ;;

        exec_command_begin|exec_command|exec_approval_request)
            cmd=$(echo "$line" | jq -r '.msg.command // .cmd // .command // empty')
            [ -z "$cmd" ] && cmd=$(echo "$line" | jq -r '.msg.call.command // empty')
            echo -e "${YELLOW}[tool] ${BOLD}exec${RESET} ${DIM}${cmd}${RESET}"
            ;;

        exec_command_end|exec_result)
            exit_code=$(echo "$line" | jq -r '.msg.exit_code // .exit_code // empty')
            output=$(echo "$line" | jq -r '.msg.output // .output // .msg.stdout // empty' | head -c 240)
            if [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; then
                echo -e "${RED}  [result] exit ${exit_code}${RESET} ${DIM}${output}${RESET}"
            else
                echo -e "${GREEN}  [result]${RESET} ${DIM}${output}${RESET}"
            fi
            ;;

        apply_patch|apply_patch_approval_request|patch_apply_begin)
            path=$(echo "$line" | jq -r '.msg.path // .path // empty')
            echo -e "${YELLOW}[tool] ${BOLD}apply_patch${RESET} ${DIM}${path}${RESET}"
            ;;

        turn_complete|turn.completed)
            echo -e "${GREEN}${BOLD}[turn complete]${RESET}"
            ;;

        error|turn_failed|turn.failed)
            content=$(echo "$line" | jq -r '.msg.message // .message // .error // .msg.content // empty')
            echo -e "${RED}${BOLD}[error]${RESET} ${content}"
            ;;

        *)
            if [ -n "$msg_type" ]; then
                preview=$(echo "$line" | jq -c '.msg // .' | head -c 240)
                echo -e "${CYAN}[${msg_type}]${RESET} ${DIM}${preview}${RESET}"
            fi
            ;;
    esac
done
