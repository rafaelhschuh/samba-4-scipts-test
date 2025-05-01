#!/bin/bash

# Função de logging

LOG_FILE="/home/ubuntu/samba_manager_refactored/samba_manager_teste/logs/samba_manager.log"

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] - $message" >> "$LOG_FILE"
}

