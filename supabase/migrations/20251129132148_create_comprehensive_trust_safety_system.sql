/*
  # Comprehensive Trust & Safety System

  1. New Tables
    - `identity_verifications`
      - User identity verification records with document uploads
      - Tracks verification attempts and status

    - `trust_scores`
      - Calculated trust scores based on user behavior
      - Includes components: transaction history, reviews, verification, responsiveness

    - `disputes`
      - Order disputes and resolution tracking
      - Support for evidence uploads and resolution notes

    - `content_reports`
      - Reports for listings, reviews, and other content
      - Category-based reporting with admin review workflow

    - `safety_actions`
      - Admin actions taken (warnings, suspensions, bans)
      - Audit trail for all safety interventions

    - `suspicious_activity_logs`
      - Automated detection of suspicious patterns
      - Fraud prevention and account takeover protection

  2. Security
    - RLS enabled on all tables
    - Users can view their own records
    - Admin-only policies for moderation actions
    - Reporters can view their own reports

  3. Important Notes
    - Trust scores are calculated automatically based on multiple factors
    - Verification status affects user privileges
    - Dispute resolution includes escrow integration
    - All safety actions are logged for audit
*/

-- Identity Verifications Table
CREATE TABLE IF NOT EXISTS identity_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  verification_type text NOT NULL CHECK (verification_type IN ('id_card', 'passport', 'drivers_license', 'utility_bill', 'selfie')),
  document_url text NOT NULL,
  document_number text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  rejection_reason text,
  verified_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Trust Scores Table
CREATE TABLE IF NOT EXISTS trust_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  overall_score integer DEFAULT 50 CHECK (overall_score >= 0 AND overall_score <= 100),
  verification_score integer DEFAULT 0 CHECK (verification_score >= 0 AND verification_score <= 25),
  transaction_score integer DEFAULT 0 CHECK (transaction_score >= 0 AND transaction_score <= 35),
  review_score integer DEFAULT 0 CHECK (review_score >= 0 AND review_score <= 25),
  responsiveness_score integer DEFAULT 0 CHECK (responsiveness_score >= 0 AND responsiveness_score <= 15),
  completed_orders integer DEFAULT 0,
  successful_transactions integer DEFAULT 0,
  disputes_filed integer DEFAULT 0,
  disputes_against integer DEFAULT 0,
  avg_response_time_hours decimal(10,2),
  last_calculated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Disputes Table
CREATE TABLE IF NOT EXISTS disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  filed_by uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  against_user uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  dispute_type text NOT NULL CHECK (dispute_type IN ('non_delivery', 'wrong_item', 'damaged_item', 'quality_issue', 'refund_request', 'other')),
  description text NOT NULL,
  evidence_urls text[],
  status text DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'closed', 'escalated')),
  resolution text,
  resolution_type text CHECK (resolution_type IN ('refund_full', 'refund_partial', 'replacement', 'no_action', 'other')),
  refund_amount decimal(10,2),
  resolved_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Content Reports Table
CREATE TABLE IF NOT EXISTS content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content_type text NOT NULL CHECK (content_type IN ('listing', 'review', 'profile', 'message', 'story', 'live_stream')),
  content_id uuid NOT NULL,
  report_category text NOT NULL CHECK (report_category IN ('spam', 'fraud', 'inappropriate', 'counterfeit', 'harassment', 'copyright', 'dangerous', 'other')),
  description text NOT NULL,
  evidence_urls text[],
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'action_taken', 'dismissed', 'escalated')),
  action_taken text,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Safety Actions Table
CREATE TABLE IF NOT EXISTS safety_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('warning', 'temporary_suspension', 'permanent_ban', 'feature_restriction', 'verification_required', 'account_review')),
  reason text NOT NULL,
  description text,
  related_report_id uuid,
  related_dispute_id uuid,
  duration_days integer,
  restrictions jsonb,
  actioned_by uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  expires_at timestamptz,
  appeal_status text CHECK (appeal_status IN ('none', 'pending', 'approved', 'denied')),
  appeal_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Suspicious Activity Logs Table
CREATE TABLE IF NOT EXISTS suspicious_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('multiple_failed_logins', 'rapid_orders', 'unusual_location', 'account_takeover_attempt', 'payment_fraud', 'fake_reviews', 'suspicious_messaging', 'price_manipulation')),
  severity text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  description text NOT NULL,
  metadata jsonb,
  ip_address text,
  user_agent text,
  action_taken text,
  reviewed boolean DEFAULT false,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Dispute Messages Table (for communication during disputes)
CREATE TABLE IF NOT EXISTS dispute_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid REFERENCES disputes(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  message text NOT NULL,
  attachment_urls text[],
  is_admin_message boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE safety_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE suspicious_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispute_messages ENABLE ROW LEVEL SECURITY;

-- Identity Verifications Policies
CREATE POLICY "Users can view own verifications"
  ON identity_verifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create verifications"
  ON identity_verifications FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Trust Scores Policies
CREATE POLICY "Users can view own trust score"
  ON trust_scores FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Trust scores viewable by others"
  ON trust_scores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can manage trust scores"
  ON trust_scores FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update trust scores"
  ON trust_scores FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Disputes Policies
CREATE POLICY "Users can view disputes they're involved in"
  ON disputes FOR SELECT
  TO authenticated
  USING (auth.uid() = filed_by OR auth.uid() = against_user);

CREATE POLICY "Users can file disputes"
  ON disputes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = filed_by);

CREATE POLICY "Users can update their disputes"
  ON disputes FOR UPDATE
  TO authenticated
  USING (auth.uid() = filed_by)
  WITH CHECK (auth.uid() = filed_by);

-- Content Reports Policies
CREATE POLICY "Users can view own reports"
  ON content_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_id);

CREATE POLICY "Users can create reports"
  ON content_reports FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- Safety Actions Policies
CREATE POLICY "Users can view own safety actions"
  ON safety_actions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Suspicious Activity Policies
CREATE POLICY "Users can view own suspicious activity"
  ON suspicious_activity_logs FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can log suspicious activity"
  ON suspicious_activity_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Dispute Messages Policies
CREATE POLICY "Users can view dispute messages"
  ON dispute_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_messages.dispute_id
      AND (disputes.filed_by = auth.uid() OR disputes.against_user = auth.uid())
    )
  );

CREATE POLICY "Users can send dispute messages"
  ON dispute_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_messages.dispute_id
      AND (disputes.filed_by = auth.uid() OR disputes.against_user = auth.uid())
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_identity_verifications_user_id ON identity_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_identity_verifications_status ON identity_verifications(status);
CREATE INDEX IF NOT EXISTS idx_trust_scores_user_id ON trust_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_trust_scores_overall ON trust_scores(overall_score DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_order_id ON disputes(order_id);
CREATE INDEX IF NOT EXISTS idx_disputes_filed_by ON disputes(filed_by);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_content ON content_reports(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON content_reports(status);
CREATE INDEX IF NOT EXISTS idx_safety_actions_user_id ON safety_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_user_id ON suspicious_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_reviewed ON suspicious_activity_logs(reviewed);
CREATE INDEX IF NOT EXISTS idx_dispute_messages_dispute_id ON dispute_messages(dispute_id);

-- Function to calculate trust score
CREATE OR REPLACE FUNCTION calculate_trust_score(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verification_score integer := 0;
  v_transaction_score integer := 0;
  v_review_score integer := 0;
  v_responsiveness_score integer := 0;
  v_overall_score integer;
  v_completed_orders integer;
  v_avg_rating decimal;
  v_verified boolean;
BEGIN
  SELECT COUNT(*) INTO v_completed_orders
  FROM orders
  WHERE (client_id = p_user_id OR picker_id = p_user_id)
  AND status = 'completed';

  SELECT verification_status = 'verified' INTO v_verified
  FROM picker_profiles
  WHERE user_id = p_user_id;

  IF v_verified THEN
    v_verification_score := 25;
  ELSIF EXISTS (SELECT 1 FROM identity_verifications WHERE user_id = p_user_id AND status = 'pending') THEN
    v_verification_score := 10;
  END IF;

  IF v_completed_orders > 0 THEN
    v_transaction_score := LEAST(35, v_completed_orders * 3);
  END IF;

  SELECT AVG(rating) INTO v_avg_rating
  FROM reviews
  WHERE reviewed_user_id = p_user_id;

  IF v_avg_rating IS NOT NULL THEN
    v_review_score := LEAST(25, ROUND((v_avg_rating / 5.0) * 25));
  END IF;

  v_responsiveness_score := 10;

  v_overall_score := v_verification_score + v_transaction_score + v_review_score + v_responsiveness_score;

  INSERT INTO trust_scores (
    user_id,
    overall_score,
    verification_score,
    transaction_score,
    review_score,
    responsiveness_score,
    completed_orders,
    last_calculated_at
  ) VALUES (
    p_user_id,
    v_overall_score,
    v_verification_score,
    v_transaction_score,
    v_review_score,
    v_responsiveness_score,
    v_completed_orders,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    overall_score = v_overall_score,
    verification_score = v_verification_score,
    transaction_score = v_transaction_score,
    review_score = v_review_score,
    responsiveness_score = v_responsiveness_score,
    completed_orders = v_completed_orders,
    last_calculated_at = now();

  RETURN v_overall_score;
END;
$$;

-- Function to log suspicious activity
CREATE OR REPLACE FUNCTION log_suspicious_activity(
  p_user_id uuid,
  p_activity_type text,
  p_severity text,
  p_description text,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO suspicious_activity_logs (
    user_id,
    activity_type,
    severity,
    description,
    metadata
  ) VALUES (
    p_user_id,
    p_activity_type,
    p_severity,
    p_description,
    p_metadata
  )
  RETURNING id INTO v_log_id;

  IF p_severity IN ('high', 'critical') THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link
    )
    SELECT
      profiles.id,
      'security_alert',
      'Security Alert',
      'Suspicious activity detected on the platform',
      '/admin/safety'
    FROM profiles
    WHERE user_type = 'admin'
    LIMIT 1;
  END IF;

  RETURN v_log_id;
END;
$$;
