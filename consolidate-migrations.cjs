const fs = require('fs');
const path = require('path');

const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
const outputFile = path.join(migrationsDir, '99999999999999_complete_marketplace_schema_consolidated.sql');

console.log('Reading all migration files...');

const files = fs.readdirSync(migrationsDir)
  .filter(f => f.endsWith('.sql'))
  .filter(f => !f.includes('complete_marketplace_schema'))
  .sort();

console.log(`Found ${files.length} migration files`);

let consolidatedSQL = `/*
  # Complete Marketplace Schema - Consolidated Migration

  This migration consolidates ALL ${files.length} migrations into one comprehensive schema.
  It includes:

  ## Core Tables
  - profiles, picker_profiles, listings, requests, messages, reviews

  ## Order & Payment System
  - orders, order_items, cart_items, payment_intents, payment_escrow, refunds
  - stripe_subscriptions, picker_subscription_payments, picker_payment_cards
  - collector_payment_methods, picker_payout_info

  ## Communication & Social
  - conversations, conversation_messages, conversation_participants
  - followers, likes, comments, social_posts, stories, live_streams

  ## Features
  - client_desires, notifications, notification_preferences
  - favorites, reported_content, blocked_users
  - analytics_events, page_views, picker_analytics
  - recommendations, recommendation_interactions
  - referral_codes, referral_rewards
  - video_calls, custom_orders
  - support_tickets, disputes, dispute_messages
  - wishlist_items, search_history
  - media_verifications, invoices
  - trust_scores, identity_verifications
  - delivery_confirmation_reminders, trial_ending_reminders

  ## Storage & Functions
  - Storage buckets for pickup videos and media
  - Automated triggers and functions
  - pg_cron jobs for scheduled tasks

  Applied: ${new Date().toISOString()}
*/

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

`;

for (const file of files) {
  const filePath = path.join(migrationsDir, file);
  const content = fs.readFileSync(filePath, 'utf8');

  consolidatedSQL += `\n\n-- =========================================\n`;
  consolidatedSQL += `-- Migration: ${file}\n`;
  consolidatedSQL += `-- =========================================\n\n`;
  consolidatedSQL += content;
}

fs.writeFileSync(outputFile, consolidatedSQL);

console.log(`\n✅ Consolidated migration created:`);
console.log(`   ${outputFile}`);
console.log(`   Size: ${(fs.statSync(outputFile).size / 1024).toFixed(2)} KB`);
console.log(`\nConsolidated ${files.length} migrations into one file.`);
