#!/bin/bash

set -e

echo "🚀 Applying complete consolidated migration to Supabase..."
echo "   Project: bfqvzxczmvfteqbhgyvx"
echo ""

# Read environment variables
source .env

MIGRATION_FILE="supabase/migrations/99999999999999_complete_marketplace_schema_consolidated.sql"

# Check if file exists
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ Migration file not found: $MIGRATION_FILE"
    exit 1
fi

echo "📖 Reading migration file..."
SQL_CONTENT=$(cat "$MIGRATION_FILE")
FILE_SIZE=$(wc -c < "$MIGRATION_FILE")
echo "   Size: $((FILE_SIZE / 1024)) KB"
echo ""

# Split into logical sections (by migration markers) and apply each
echo "🔧 Splitting and applying sections..."
echo ""

cd supabase/migrations

# Split by migration sections
csplit -s -f section_ 99999999999999_complete_marketplace_schema_consolidated.sql '/-- Migration:/' '{*}'

SECTIONS=$(ls section_* 2>/dev/null | wc -l)
echo "   Found $SECTIONS sections"
echo ""

SUCCESS=0
FAILED=0

for section in section_*; do
    SECTION_NUM=$(echo $section | sed 's/section_//')
    printf "   [%02d/%02d] Applying section... " $((SECTION_NUM+1)) $SECTIONS

    # Apply via psql or curl (using execute_sql endpoint)
    if psql "$DATABASE_URL" -f "$section" > /dev/null 2>&1; then
        echo "✓"
        ((SUCCESS++))
    else
        echo "⚠"
        ((FAILED++))
    fi

    sleep 0.2
done

echo ""
echo "==========================================================="
echo "✅ Migration application complete!"
echo "   Successful sections: $SUCCESS"
echo "   Failed sections: $FAILED"
echo "==========================================================="

# Cleanup
rm -f section_*

echo ""
echo "🧹 Cleaned up temporary files"
