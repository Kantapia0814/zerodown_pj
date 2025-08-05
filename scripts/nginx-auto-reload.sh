#!/bin/bash

CONFIG_FILE="/etc/nginx/conf.d/hello-service.conf"
LAST_MODIFIED=""

echo "Nginx auto-reload watcher started..."

while true; do
    if [ -f "$CONFIG_FILE" ]; then
        CURRENT_MODIFIED=$(stat -c %Y "$CONFIG_FILE" 2>/dev/null)

        if [ "$CURRENT_MODIFIED" != "$LAST_MODIFIED" ] && [ -n "$LAST_MODIFIED" ]; then
            echo "$(date): Config file changed, testing and reloading nginx..."

            if nginx -t >/dev/null 2>&1; then
                nginx -s reload
                echo "$(date): Nginx reloaded successfully"
            else
                echo "$(date): Nginx config test failed, skipping reload"
            fi
        fi

        LAST_MODIFIED="$CURRENT_MODIFIED"
    fi

    sleep 3
done