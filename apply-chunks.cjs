const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing environment variables!');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyChunks() {
  const chunksDir = path.join(__dirname, 'supabase', 'migrations');
  const chunks = fs.readdirSync(chunksDir)
    .filter(f => f.startsWith('chunk_'))
    .sort();

  console.log(`📦 Found ${chunks.length} chunks to apply\n`);

  let successCount = 0;
  let failCount = 0;

  for (const chunk of chunks) {
    const chunkPath = path.join(chunksDir, chunk);
    const sql = fs.readFileSync(chunkPath, 'utf8');

    process.stdout.write(`   Applying ${chunk}... `);

    try {
      const { error } = await supabase.rpc('exec_sql', { query: sql });

      if (error) {
        console.log('❌');
        console.error(`      ${error.message.substring(0, 150)}`);
        failCount++;
      } else {
        console.log('✓');
        successCount++;
      }
    } catch (error) {
      console.log('❌');
      console.error(`      ${error.message.substring(0, 150)}`);
      failCount++;
    }

    await new Promise(resolve => setTimeout(resolve, 200));
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log(`✅ Complete! Success: ${successCount}, Failed: ${failCount}`);
  console.log('='.repeat(60));

  // Cleanup chunks
  console.log('\n🧹 Cleaning up chunk files...');
  chunks.forEach(chunk => {
    fs.unlinkSync(path.join(chunksDir, chunk));
  });
  console.log('✓ Cleanup complete');
}

applyChunks().catch(console.error);
