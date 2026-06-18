#!/usr/bin/env node

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const EXPECTED_PROJECT_ID = 'bfqvzxczmvfteqbhgyvx';
const OLD_PROJECT_ID = 'usgqobihywfaefrxgdqx';

console.log('🔍 Validating Supabase configuration...\n');

try {
  const envPath = join(__dirname, '..', '.env');
  const envContent = readFileSync(envPath, 'utf8');

  const urlMatch = envContent.match(/VITE_SUPABASE_URL=(.+)/);
  const keyMatch = envContent.match(/VITE_SUPABASE_ANON_KEY=(.+)/);

  if (!urlMatch || !keyMatch) {
    console.error('❌ ERROR: Missing Supabase environment variables in .env file');
    console.error('\nRequired variables:');
    console.error('  - VITE_SUPABASE_URL');
    console.error('  - VITE_SUPABASE_ANON_KEY');
    process.exit(1);
  }

  const supabaseUrl = urlMatch[1].trim();
  const supabaseKey = keyMatch[1].trim();

  if (supabaseUrl.includes(OLD_PROJECT_ID)) {
    console.error(`❌ ERROR: Old/wrong Supabase project detected!`);
    console.error(`\nFound: ${OLD_PROJECT_ID}`);
    console.error(`Expected: ${EXPECTED_PROJECT_ID}`);
    console.error(`\nCurrent URL: ${supabaseUrl}`);
    console.error(`\n⚠️  This will cause all changes to go to the wrong project!`);
    console.error(`Please update your .env file with the correct credentials.`);
    process.exit(1);
  }

  if (!supabaseUrl.includes(EXPECTED_PROJECT_ID)) {
    console.error(`❌ ERROR: Unexpected Supabase project!`);
    console.error(`\nExpected project: ${EXPECTED_PROJECT_ID}`);
    console.error(`Current URL: ${supabaseUrl}`);
    console.error(`\nPlease verify your .env file has the correct project credentials.`);
    process.exit(1);
  }

  if (!supabaseKey.startsWith('eyJ')) {
    console.error('❌ ERROR: Invalid Supabase anon key format');
    console.error('The key should be a JWT token starting with "eyJ"');
    process.exit(1);
  }

  console.log('✅ Configuration is valid!');
  console.log(`✅ Using correct project: ${EXPECTED_PROJECT_ID}`);
  console.log('✅ Environment variables are properly set\n');

} catch (error) {
  if (error.code === 'ENOENT') {
    console.error('❌ ERROR: .env file not found!');
    console.error('\nPlease create a .env file with the following variables:');
    console.error('  VITE_SUPABASE_URL=https://bfqvzxczmvfteqbhgyvx.supabase.co');
    console.error('  VITE_SUPABASE_ANON_KEY=your-anon-key-here');
  } else {
    console.error('❌ ERROR:', error.message);
  }
  process.exit(1);
}
