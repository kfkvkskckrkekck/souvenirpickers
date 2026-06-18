/*
  # Create content reports table for safety reporting

  1. New Table
    - content_reports
      - id (uuid, primary key)
      - reporter_id (uuid, references profiles)
      - content_type (text) - listing, user, review, message
      - content_id (uuid) - ID of the reported content
      - report_category (text) - spam, harassment, fraud, inappropriate, etc.
      - description (text) - details about the report
      - status (text) - pending, reviewing, action_taken, dismissed, escalated
      - action_taken (text, nullable) - what action was taken
      - reviewed_at (timestamptz, nullable)
      - reviewed_by (uuid, nullable) - admin who reviewed
      - created_at (timestamptz)

  2. Security
    - Enable RLS
    - Users can insert reports
    - Users can view their own reports
*/

CREATE TABLE IF NOT EXISTS content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content_type text NOT NULL,
  content_id uuid NOT NULL,
  report_category text NOT NULL,
  description text NOT NULL,
  status text DEFAULT 'pending',
  action_taken text,
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES profiles(id),
  created_at timestamptz DEFAULT now()
);

-- Add constraints
ALTER TABLE content_reports 
DROP CONSTRAINT IF EXISTS content_reports_content_type_check;

ALTER TABLE content_reports 
ADD CONSTRAINT content_reports_content_type_check 
CHECK (content_type IN ('listing', 'user', 'review', 'message', 'order'));

ALTER TABLE content_reports 
DROP CONSTRAINT IF EXISTS content_reports_report_category_check;

ALTER TABLE content_reports 
ADD CONSTRAINT content_reports_report_category_check 
CHECK (report_category IN ('spam', 'harassment', 'fraud', 'inappropriate', 'fake_content', 'other'));

ALTER TABLE content_reports 
DROP CONSTRAINT IF EXISTS content_reports_status_check;

ALTER TABLE content_reports 
ADD CONSTRAINT content_reports_status_check 
CHECK (status IN ('pending', 'reviewing', 'action_taken', 'dismissed', 'escalated'));

-- Enable RLS
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can insert reports" ON content_reports;
DROP POLICY IF EXISTS "Users can view own reports" ON content_reports;

CREATE POLICY "Users can insert reports"
  ON content_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can view own reports"
  ON content_reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS content_reports_reporter_id_idx ON content_reports(reporter_id);
CREATE INDEX IF NOT EXISTS content_reports_status_idx ON content_reports(status);
CREATE INDEX IF NOT EXISTS content_reports_created_at_idx ON content_reports(created_at DESC);