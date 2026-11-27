#!/bin/sh
"$CLAUDE_PLUGIN_ROOT/bin/solidvibes" handover --snapshot "${CLAUDE_PROJECT_DIR:-.}" >/dev/null 2>&1
exit 0
