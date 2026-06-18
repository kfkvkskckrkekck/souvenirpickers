/*
  # Add Picker Profile Identity Fields
  
  1. Changes
    - Add `full_name` to picker_profiles for picker-specific display name
    - Add `bio` to picker_profiles for picker-specific biography
    - Add `avatar_url` to picker_profiles for picker-specific avatar
    
  2. Purpose
    - Separate picker profile identity from collector profile identity
    - Allow users to have different names/bios/avatars for picker vs collector modes
    - Maintain privacy by keeping the two identities separate
    
  3. Notes
    - These fields will override the profiles table fields when user is in picker mode
    - NULL values mean the picker hasn't customized their picker identity yet
*/

-- Add picker-specific identity fields
ALTER TABLE picker_profiles 
ADD COLUMN IF NOT EXISTS full_name text,
ADD COLUMN IF NOT EXISTS bio text,
ADD COLUMN IF NOT EXISTS avatar_url text;

-- Add comment explaining the purpose
COMMENT ON COLUMN picker_profiles.full_name IS 'Picker-specific display name, overrides profiles.full_name when in picker mode';
COMMENT ON COLUMN picker_profiles.bio IS 'Picker-specific biography, overrides profiles.bio when in picker mode';
COMMENT ON COLUMN picker_profiles.avatar_url IS 'Picker-specific avatar, overrides profiles.avatar_url when in picker mode';
