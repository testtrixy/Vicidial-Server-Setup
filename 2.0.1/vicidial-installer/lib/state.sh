#!/bin/bash
STATE_FILE=".install_state"

is_stage_complete() {
    grep -q "^$1$" "$STATE_FILE" 2>/dev/null
}

mark_stage_done() {
    echo "$1" >> "$STATE_FILE"
}
