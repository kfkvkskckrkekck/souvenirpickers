/*
  # Create Invoice System for Subscription Payments

  1. New Tables
    - `invoices`
      - `id` (uuid, primary key)
      - `invoice_number` (text, unique) - Format: INV-YYYY-MM-XXXXXXX
      - `picker_id` (uuid, references profiles)
      - `payment_id` (uuid, references picker_subscription_payments)
      - `issue_date` (date) - Invoice issue date
      - `due_date` (date) - Payment due date
      - `billing_period_start` (date)
      - `billing_period_end` (date)
      - `subtotal` (decimal) - Amount before tax
      - `tax_rate` (decimal) - VAT/Tax rate percentage
      - `tax_amount` (decimal) - Calculated tax
      - `total_amount` (decimal) - Final amount
      - `currency` (text) - EUR, USD, etc.
      - `status` (enum: 'draft', 'sent', 'paid', 'cancelled')
      - `payment_method` (text) - Card type and last 4 digits
      - `paid_at` (timestamp)
      - `sent_at` (timestamp) - When email was sent
      - `billing_name` (text) - Customer/company name
      - `billing_email` (text)
      - `billing_address` (text)
      - `billing_city` (text)
      - `billing_postal_code` (text)
      - `billing_country` (text)
      - `tax_id` (text) - VAT number if applicable
      - `notes` (text) - Additional notes
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on invoices table
    - Pickers can view their own invoices
    - Admins can view all invoices
    - System can create and update invoices

  3. Indexes
    - Index on picker_id for user queries
    - Index on invoice_number for lookups
    - Index on issue_date for chronological queries
    - Index on status for filtering

  4. Functions
    - Auto-generate invoice numbers
    - Calculate tax amounts
    - Update invoice sequence

  5. Notes
    - Invoices generated automatically after successful subscription payment
    - Email sent to picker with PDF invoice attachment
    - Supports VAT/tax calculation for EU countries
    - Invoice numbers follow format: INV-2025-11-0000001
*/

-- Create enum for invoice status
DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create invoices table
CREATE TABLE IF NOT EXISTS invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number text UNIQUE NOT NULL,
  picker_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  payment_id uuid REFERENCES picker_subscription_payments(id) ON DELETE SET NULL,
  issue_date date DEFAULT CURRENT_DATE NOT NULL,
  due_date date DEFAULT CURRENT_DATE NOT NULL,
  billing_period_start date NOT NULL,
  billing_period_end date NOT NULL,
  subtotal decimal(10,2) NOT NULL,
  tax_rate decimal(5,2) DEFAULT 0,
  tax_amount decimal(10,2) DEFAULT 0,
  total_amount decimal(10,2) NOT NULL,
  currency text DEFAULT 'EUR' NOT NULL,
  status invoice_status DEFAULT 'draft' NOT NULL,
  payment_method text,
  paid_at timestamptz,
  sent_at timestamptz,
  billing_name text NOT NULL,
  billing_email text NOT NULL,
  billing_address text,
  billing_city text,
  billing_postal_code text,
  billing_country text,
  tax_id text,
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create invoice sequence table for tracking invoice numbers
CREATE TABLE IF NOT EXISTS invoice_sequences (
  year integer PRIMARY KEY,
  month integer NOT NULL,
  last_sequence integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(year, month)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_invoices_picker 
  ON invoices(picker_id);

CREATE INDEX IF NOT EXISTS idx_invoices_number 
  ON invoices(invoice_number);

CREATE INDEX IF NOT EXISTS idx_invoices_issue_date 
  ON invoices(issue_date DESC);

CREATE INDEX IF NOT EXISTS idx_invoices_status 
  ON invoices(status);

CREATE INDEX IF NOT EXISTS idx_invoices_payment 
  ON invoices(payment_id);

-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_sequences ENABLE ROW LEVEL SECURITY;

-- Pickers can view their own invoices
CREATE POLICY "Pickers can view own invoices"
  ON invoices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- System can create invoices
CREATE POLICY "System can create invoices"
  ON invoices
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- System can update invoices
CREATE POLICY "System can update invoices"
  ON invoices
  FOR UPDATE
  TO authenticated
  USING (true);

-- Admins can view all invoices
CREATE POLICY "Admins can view all invoices"
  ON invoices
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.user_type = 'admin'
  ));

-- Function to generate next invoice number
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS text AS $$
DECLARE
  current_year integer;
  current_month integer;
  next_sequence integer;
  invoice_num text;
BEGIN
  current_year := EXTRACT(YEAR FROM CURRENT_DATE)::integer;
  current_month := EXTRACT(MONTH FROM CURRENT_DATE)::integer;
  
  -- Get or create sequence for current year/month
  INSERT INTO invoice_sequences (year, month, last_sequence)
  VALUES (current_year, current_month, 1)
  ON CONFLICT (year, month) 
  DO UPDATE SET 
    last_sequence = invoice_sequences.last_sequence + 1,
    updated_at = now()
  RETURNING last_sequence INTO next_sequence;
  
  -- Format: INV-2025-11-0000001
  invoice_num := 'INV-' || 
                 current_year::text || '-' || 
                 LPAD(current_month::text, 2, '0') || '-' ||
                 LPAD(next_sequence::text, 7, '0');
  
  RETURN invoice_num;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set search path for the function
ALTER FUNCTION generate_invoice_number() SET search_path = public, pg_temp;

-- Function to calculate VAT based on country
CREATE OR REPLACE FUNCTION calculate_vat_rate(country_code text)
RETURNS decimal AS $$
BEGIN
  -- EU VAT rates (simplified - in production, use accurate rates)
  CASE UPPER(country_code)
    WHEN 'AT' THEN RETURN 20.00; -- Austria
    WHEN 'BE' THEN RETURN 21.00; -- Belgium
    WHEN 'BG' THEN RETURN 20.00; -- Bulgaria
    WHEN 'CY' THEN RETURN 19.00; -- Cyprus
    WHEN 'CZ' THEN RETURN 21.00; -- Czech Republic
    WHEN 'DE' THEN RETURN 19.00; -- Germany
    WHEN 'DK' THEN RETURN 25.00; -- Denmark
    WHEN 'EE' THEN RETURN 20.00; -- Estonia
    WHEN 'ES' THEN RETURN 21.00; -- Spain
    WHEN 'FI' THEN RETURN 24.00; -- Finland
    WHEN 'FR' THEN RETURN 20.00; -- France
    WHEN 'GR' THEN RETURN 24.00; -- Greece
    WHEN 'HR' THEN RETURN 25.00; -- Croatia
    WHEN 'HU' THEN RETURN 27.00; -- Hungary
    WHEN 'IE' THEN RETURN 23.00; -- Ireland
    WHEN 'IT' THEN RETURN 22.00; -- Italy
    WHEN 'LT' THEN RETURN 21.00; -- Lithuania
    WHEN 'LU' THEN RETURN 17.00; -- Luxembourg
    WHEN 'LV' THEN RETURN 21.00; -- Latvia
    WHEN 'MT' THEN RETURN 18.00; -- Malta
    WHEN 'NL' THEN RETURN 21.00; -- Netherlands
    WHEN 'PL' THEN RETURN 23.00; -- Poland
    WHEN 'PT' THEN RETURN 23.00; -- Portugal
    WHEN 'RO' THEN RETURN 19.00; -- Romania
    WHEN 'SE' THEN RETURN 25.00; -- Sweden
    WHEN 'SI' THEN RETURN 22.00; -- Slovenia
    WHEN 'SK' THEN RETURN 20.00; -- Slovakia
    ELSE RETURN 0.00; -- Non-EU or unknown
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Set search path for the function
ALTER FUNCTION calculate_vat_rate(text) SET search_path = public, pg_temp;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_invoice_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_invoice_timestamp
  BEFORE UPDATE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_invoice_updated_at();
