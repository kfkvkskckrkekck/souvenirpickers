const fs = require('fs');
const path = require('path');

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing environment variables!');
  console.error('   VITE_SUPABASE_URL:', supabaseUrl ? '✓' : '✗');
  console.error('   VITE_SUPABASE_SERVICE_ROLE_KEY:', supabaseServiceKey ? '✓' : '✗');
  process.exit(1);
}

async function applyConsolidatedMigration() {
  const migrationFile = path.join(__dirname, 'supabase', 'migrations', '99999999999999_complete_marketplace_schema_consolidated.sql');

  console.log('📖 Reading consolidated migration...');
  const content = fs.readFileSync(migrationFile, 'utf8');

  console.log(`   Size: ${(content.length / 1024).toFixed(2)} KB`);
  console.log(`   Lines: ${content.split('\n').length}`);

  // Split into chunks by migration sections
  const migrations = content.split(/-- =========================================\n-- Migration: /);
  console.log(`   Sections: ${migrations.length}`);

  console.log('\n🚀 Applying consolidated migration to Supabase...\n');

  let successCount = 0;
  let failCount = 0;

  for (let i = 0; i < migrations.length; i++) {
    const chunk = migrations[i];
    if (!chunk.trim()) continue;

    // Extract migration name from chunk
    const lines = chunk.split('\n');
    const migrationName = lines[0]?.split('.sql')[0] || `Section ${i}`;

    process.stdout.write(`   [${i}/${migrations.length}] ${migrationName.substring(0, 50)}... `);

    try {
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': supabaseServiceKey,
          'Authorization': `Bearer ${supabaseServiceKey}`
        },
        body: JSON.stringify({ query: chunk })
      });

      if (!response.ok) {
        const error = await response.text();
        console.log('❌');
        console.error(`      Error: ${error.substring(0, 200)}`);
        failCount++;
      } else {
        console.log('✓');
        successCount++;
      }
    } catch (error) {
      console.log('❌');
      console.error(`      Error: ${error.message}`);
      failCount++;
    }

    // Small delay between chunks
    await new Promise(resolve => setTimeout(resolve, 300));
  }

  console.log('\n' + '='.repeat(60));
  console.log(`✅ Migration complete!`);
  console.log(`   Successful: ${successCount}`);
  console.log(`   Failed: ${failCount}`);
  console.log('='.repeat(60));
}

applyConsolidatedMigration().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
