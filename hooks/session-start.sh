#!/bin/sh
"$CLAUDE_PLUGIN_ROOT/bin/solidvibes" hello --hook "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null
exit 0
