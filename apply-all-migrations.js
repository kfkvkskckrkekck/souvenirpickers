const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyMigrations() {
  const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  console.log(`Found ${files.length} migration files`);

  // Skip the first one (already applied) and the last one (fix_profile_creation_trigger)
  const filesToApply = files.slice(1, -1);

  for (const file of filesToApply) {
    console.log(`\nApplying: ${file}`);
    const content = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

    try {
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': supabaseKey,
          'Authorization': `Bearer ${supabaseKey}`
        },
        body: JSON.stringify({ query: content })
      });

      if (!response.ok) {
        const error = await response.text();
        console.error(`❌ Failed to apply ${file}:`, error);
      } else {
        console.log(`✓ Applied ${file}`);
      }
    } catch (error) {
      console.error(`❌ Error applying ${file}:`, error.message);
    }

    // Small delay between migrations
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  console.log('\n✅ All migrations applied!');
}

applyMigrations().catch(console.error);
