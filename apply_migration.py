#!/usr/bin/env python3
import os
import requests
import time

# Load environment variables
with open('.env') as f:
    for line in f:
        if line.strip() and not line.startswith('#'):
            key, value = line.strip().split('=', 1)
            os.environ[key] = value

SUPABASE_URL = os.environ['VITE_SUPABASE_URL']
SUPABASE_KEY = os.environ['VITE_SUPABASE_ANON_KEY']

print("🚀 Applying consolidated migration to Supabase")
print(f"   Project: bfqvzxczmvfteqbhgyvx\n")

# Read the consolidated migration
migration_file = 'supabase/migrations/99999999999999_complete_marketplace_schema_consolidated.sql'
print(f"📖 Reading {migration_file}...")

with open(migration_file, 'r') as f:
    content = f.read()

file_size_kb = len(content) / 1024
print(f"   Size: {file_size_kb:.2f} KB")
print(f"   Lines: {len(content.splitlines())}\n")

# Split by migration sections
sections = content.split('-- =========================================')
sections = [s.strip() for s in sections if s.strip()]

print(f"🔧 Applying {len(sections)} sections...\n")

success_count = 0
fail_count = 0

for i, section in enumerate(sections, 1):
    # Extract section name
    lines = section.split('\n')
    section_name = lines[0] if lines else f"Section {i}"
    section_name = section_name.replace('--', '').strip()[:50]

    print(f"   [{i:02d}/{len(sections):02d}] {section_name}...", end=' ', flush=True)

    # Apply via Supabase REST API
    try:
        response = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
            headers={
                'Content-Type': 'application/json',
                'apikey': SUPABASE_KEY,
                'Authorization': f'Bearer {SUPABASE_KEY}'
            },
            json={'query': section},
            timeout=30
        )

        if response.status_code == 200:
            print("✓")
            success_count += 1
        else:
            print("⚠")
            print(f"       Error: {response.text[:100]}")
            fail_count += 1

    except Exception as e:
        print("❌")
        print(f"       Error: {str(e)[:100]}")
        fail_count += 1

    time.sleep(0.3)

print(f"\n{'='*60}")
print(f"✅ Migration complete!")
print(f"   Successful: {success_count}")
print(f"   Failed: {fail_count}")
print(f"{'='*60}")
