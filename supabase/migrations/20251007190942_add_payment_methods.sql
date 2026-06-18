/*
  # Add payment methods for pickers

  ## Overview
  This migration creates a system for pickers to specify their accepted payment methods,
  allowing clients to see how they can pay for souvenirs.

  ## 1. New Tables
    - `picker_payment_methods`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references picker_profiles)
      - `method_type` (text, type of payment: paypal, venmo, bank_transfer, cash, crypto, etc.)
      - `method_name` (text, display name for the payment method)
      - `account_identifier` (text, account details like email, phone, or public info)
      - `notes` (text, additional instructions or notes)
      - `preferred` (boolean, whether this is the picker's preferred method)
      - `active` (boolean, whether this method is currently available)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ## 2. Security
    - Enable RLS on `picker_payment_methods` table
    - Pickers can create, read, update, and delete their own payment methods
    - Authenticated users can view payment methods of any picker (for transparency)
    - Only picker owners can modify their payment methods

  ## 3. Notes
    - Allows pickers to add multiple payment methods
    - Supports various payment types worldwide
    - Preferred method helps clients know which to use
    - Account identifiers are public (don't store sensitive data)
    - Pickers should only share safe, public-facing payment info
*/

CREATE TABLE IF NOT EXISTS picker_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES picker_profiles(id) ON DELETE CASCADE NOT NULL,
  method_type text NOT NULL CHECK (method_type IN (
    'paypal', 'venmo', 'cashapp', 'zelle', 'bank_transfer', 
    'wise', 'revolut', 'crypto', 'cash', 'other'
  )),
  method_name text NOT NULL,
  account_identifier text NOT NULL,
  notes text DEFAULT '',
  preferred boolean DEFAULT false,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE picker_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view payment methods"
  ON picker_payment_methods FOR SELECT
  TO authenticated
  USING (active = true);

CREATE POLICY "Pickers can create own payment methods"
  ON picker_payment_methods FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update own payment methods"
  ON picker_payment_methods FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can delete own payment methods"
  ON picker_payment_methods FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_picker_payment_methods_picker_id ON picker_payment_methods(picker_id);
CREATE INDEX IF NOT EXISTS idx_picker_payment_methods_active ON picker_payment_methods(active);