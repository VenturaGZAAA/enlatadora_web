#!/bin/sh
exec python3 "$(dirname "$0")/deploy_web.py" "$@"
