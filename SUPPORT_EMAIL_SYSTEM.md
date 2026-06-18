# Support Email Notification System

## Overview
The support chat system now automatically sends email notifications to support@souvenirpickers.com whenever a user sends a message through the support chat interface.

## How It Works

### 1. User Sends Support Message
- User opens the Support Chat interface in the app
- Types their message and clicks Send
- Message is saved to the `support_messages` table

### 2. Automatic Email Notification
- Database trigger `trigger_notify_support_team` fires immediately after message insert
- Trigger function `notify_support_team_of_new_message()` executes
- Function uses `pg_net` to asynchronously call the `send-email-notification` edge function
- Edge function sends a formatted email to support@souvenirpickers.com

### 3. Email Content
The support team receives:
- User's full name and email address
- Complete message content
- Timestamp of when the message was sent
- Conversation ID for reference
- Direct link to admin panel

## Components

### Database Trigger
- **Name**: `trigger_notify_support_team`
- **Table**: `support_messages`
- **Event**: AFTER INSERT
- **Condition**: Only fires for non-support messages (from users)

### Trigger Function
- **Name**: `notify_support_team_of_new_message()`
- **Security**: SECURITY DEFINER
- **Async**: Uses pg_net for non-blocking email delivery
- **Error Handling**: Logs warnings but doesn't fail message insertion

### Edge Function
- **Name**: `send-email-notification`
- **Type**: support_message_received
- **SMTP**: Uses BlueHost SMTP (mail.souvenirpickers.com)
- **From**: support@souvenirpickers.com
- **To**: support@souvenirpickers.com

## Email Format
The support team receives beautifully formatted HTML emails with:
- Blue gradient header with "New Support Message"
- User information (name, email, timestamp)
- Full message content in a highlighted box
- Conversation ID for tracking
- "View in Admin Panel" button
- Professional footer with SouvenirPickers branding

## Testing
To test the system:
1. Log into souvenirpickers.com as any user
2. Navigate to Support section in the sidebar
3. Send a test message
4. Check support@souvenirpickers.com inbox within 1-2 minutes

## Production Status
✅ All components deployed and active
✅ Database trigger active
✅ Edge function deployed
✅ SMTP configured (BlueHost)
✅ Email templates ready

## Email Delivery
- **Service**: BlueHost SMTP
- **Host**: mail.souvenirpickers.com
- **Port**: 587 (TLS)
- **From**: support@souvenirpickers.com
- **To**: support@souvenirpickers.com

All SMTP credentials are securely stored in Supabase Edge Function secrets.
