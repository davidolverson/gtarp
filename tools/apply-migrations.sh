#!/usr/bin/env bash
# ============================================================================
# tools/apply-migrations.sh [--baseline] [--dry-run]
#
# Idempotent runner for sql/*.sql. Tracks what has been applied in a
# gtarp_schema_migrations table (filename + sha256 + applied_at) so it can
# be re-run safely — already-applied files are skipped, and a file whose
# checksum CHANGED after apply is reported loudly and never silently
# re-run (edit-after-apply always needs a human decision).
#
#   --baseline   Record every sql/*.sql as applied WITHOUT running it.
#                Use ONCE on a database that pre-dates this tool (both the
#                local test DB and production already had 0001..0020
#                applied by hand). Running apply without a baseline on
#                such a DB would replay seed data.
#   --dry-run    Show what would be applied/skipped; change nothing.
#
# Database connection: defaults to the LOCAL test server's MariaDB Docker
# container. For any other target (e.g. the production game host), set
# MYSQL_CMD to a command that reads SQL on stdin, e.g.:
#   MYSQL_CMD="mysql -h127.0.0.1 -uqbox -p<pw> qbox" tools/apply-migrations.sh
#
# CI never runs this — the deploy workflow only WARNS about pending
# migrations (see DEPLOY.md). This script is the manual step made safe.
# ============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SQL_DIR="$REPO/sql"
MYSQL_CMD="${MYSQL_CMD:-docker exec -i gtarp-mariadb mariadb -uqbox -pqbox_pw qbox}"

BASELINE=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --baseline) BASELINE=true ;;
        --dry-run)  DRY_RUN=true ;;
        *) echo "usage: apply-migrations.sh [--baseline] [--dry-run]" >&2; exit 1 ;;
    esac
done

run_sql() { $MYSQL_CMD; }

# Fetch the recorded checksum for a filename. Emits the bare checksum or
# nothing. Uses a CS: marker so it works with or without column headers,
# and survives the table not existing yet (first --dry-run).
recorded_checksum() {
    printf "SELECT CONCAT('CS:', checksum) FROM gtarp_schema_migrations WHERE filename='%s';\n" "$1" \
        | $MYSQL_CMD 2>/dev/null \
        | sed -n 's/^CS:\([0-9a-f]\{64\}\)$/\1/p' \
        || true
}

sha() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# Tracking table — safe to create repeatedly.
if ! $DRY_RUN; then
    run_sql <<'SQL'
CREATE TABLE IF NOT EXISTS gtarp_schema_migrations (
    filename   VARCHAR(255) NOT NULL PRIMARY KEY,
    checksum   CHAR(64)     NOT NULL,
    applied_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    baselined  TINYINT(1)   NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL
fi

applied=0 skipped=0 baselined=0 drift=0

for path in "$SQL_DIR"/*.sql; do
    [ -e "$path" ] || { echo "no sql files found in $SQL_DIR" >&2; exit 1; }
    file="$(basename "$path")"
    sum="$(sha "$path")"

    row="$(recorded_checksum "$file" | tr -d '[:space:]')"

    if [ -n "$row" ]; then
        if [ "$row" = "$sum" ]; then
            skipped=$((skipped + 1))
        else
            echo "!! DRIFT: $file was applied with a different checksum" >&2
            echo "   recorded=$row" >&2
            echo "   on disk =$sum" >&2
            echo "   A migration changed after being applied. Resolve by hand" >&2
            echo "   (write a NEW migration; never edit an applied one), then" >&2
            echo "   UPDATE gtarp_schema_migrations SET checksum='$sum' WHERE filename='$file';" >&2
            drift=$((drift + 1))
        fi
        continue
    fi

    if $DRY_RUN; then
        if $BASELINE; then echo "would baseline: $file"; else echo "would apply: $file"; fi
        continue
    fi

    if $BASELINE; then
        printf "INSERT INTO gtarp_schema_migrations (filename, checksum, baselined) VALUES ('%s','%s',1);\n" "$file" "$sum" | run_sql
        echo "baselined: $file"
        baselined=$((baselined + 1))
    else
        echo "applying: $file"
        run_sql < "$path"
        printf "INSERT INTO gtarp_schema_migrations (filename, checksum) VALUES ('%s','%s');\n" "$file" "$sum" | run_sql
        applied=$((applied + 1))
    fi
done

echo "---"
echo "applied=$applied baselined=$baselined skipped=$skipped drift=$drift"
if [ "$drift" -gt 0 ]; then
    echo "FAILED: checksum drift detected — see messages above." >&2
    exit 2
fi
