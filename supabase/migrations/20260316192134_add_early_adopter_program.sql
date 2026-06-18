/*
  # Early Adopter Program for First 500 Pickers

  1. New Columns
    - `profiles` table:
      - `is_early_adopter` (boolean) - Flag for early adopter status (no subscription fee)
      - `early_adopter_number` (integer) - Sequential number (1-500) for early adopters
  
  2. New Table
    - `early_adopter_stats` - Tracks the count of early adopters
      - `id` (integer, primary key)
      - `total_count` (integer) - Current count of early adopters
      - `max_count` (integer) - Maximum allowed (500)
      - `updated_at` (timestamptz) - Last update time
  
  3. Functions
    - `assign_early_adopter_status()` - Automatically assigns early adopter status to new pickers
  
  4. Security
    - Enable RLS on early_adopter_stats
    - Add policies for public read access to the counter
*/

-- Add early adopter columns to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_early_adopter boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS early_adopter_number integer;

-- Create early adopter stats table
CREATE TABLE IF NOT EXISTS early_adopter_stats (
  id integer PRIMARY KEY DEFAULT 1,
  total_count integer DEFAULT 0,
  max_count integer DEFAULT 500,
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT single_row_constraint CHECK (id = 1)
);

-- Insert the initial row
INSERT INTO early_adopter_stats (id, total_count, max_count)
VALUES (1, 0, 500)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE early_adopter_stats ENABLE ROW LEVEL SECURITY;

-- Public read access to counter
CREATE POLICY "Anyone can view early adopter stats"
  ON early_adopter_stats
  FOR SELECT
  TO public
  USING (true);

-- Only service role can update
CREATE POLICY "Service role can update stats"
  ON early_adopter_stats
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Function to assign early adopter status
CREATE OR REPLACE FUNCTION assign_early_adopter_status()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  current_count integer;
  max_allowed integer;
  next_number integer;
BEGIN
  -- Only process for picker accounts
  IF NEW.user_type = 'picker' THEN
    -- Get current stats
    SELECT total_count, max_count INTO current_count, max_allowed
    FROM early_adopter_stats
    WHERE id = 1
    FOR UPDATE;
    
    -- Check if we still have spots available
    IF current_count < max_allowed THEN
      -- Calculate next number
      next_number := current_count + 1;
      
      -- Update the profile
      NEW.is_early_adopter := true;
      NEW.early_adopter_number := next_number;
      
      -- Update the counter
      UPDATE early_adopter_stats
      SET total_count = next_number,
          updated_at = now()
      WHERE id = 1;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to assign early adopter status on profile creation
DROP TRIGGER IF EXISTS assign_early_adopter_on_insert ON profiles;
CREATE TRIGGER assign_early_adopter_on_insert
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION assign_early_adopter_status();

-- Grant necessary permissions
GRANT SELECT ON early_adopter_stats TO anon, authenticated;
GRANT ALL ON early_adopter_stats TO service_role;

-- Create index for quick lookups
CREATE INDEX IF NOT EXISTS idx_profiles_early_adopter 
  ON profiles(is_early_adopter, early_adopter_number) 
  WHERE is_early_adopter = true;
