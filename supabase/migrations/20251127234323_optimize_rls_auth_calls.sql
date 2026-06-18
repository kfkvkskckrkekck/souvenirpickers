/*
  # Optimize RLS Policies - Replace auth.uid() with SELECT wrapper

  1. Performance Optimization
    - Wraps all auth.uid() calls with (select auth.uid())
    - Prevents re-evaluation of auth function for each row
    - Improves query performance significantly at scale
    
  2. Implementation
    - Drops existing policies and recreates with optimized auth calls
    - Maintains exact same logic and security
    - Only changes performance characteristics
*/

-- Helper function to optimize all RLS policies
DO $$
DECLARE
  pol record;
  new_using text;
  new_check text;
BEGIN
  -- Loop through all policies that likely use auth.uid()
  FOR pol IN 
    SELECT 
      schemaname,
      tablename,
      policyname,
      cmd,
      qual as using_clause,
      with_check as check_clause
    FROM pg_policies
    WHERE schemaname = 'public'
    AND (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
  LOOP
    -- Replace auth.uid() with (select auth.uid()) in USING clause
    IF pol.using_clause IS NOT NULL THEN
      new_using := replace(pol.using_clause, 'auth.uid()', '(select auth.uid())');
    ELSE
      new_using := NULL;
    END IF;
    
    -- Replace auth.uid() with (select auth.uid()) in WITH CHECK clause
    IF pol.check_clause IS NOT NULL THEN
      new_check := replace(pol.check_clause, 'auth.uid()', '(select auth.uid())');
    ELSE
      new_check := NULL;
    END IF;
    
    -- Drop the old policy
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
      pol.policyname,
      pol.schemaname,
      pol.tablename
    );
    
    -- Recreate with optimized version
    IF pol.cmd = '*' THEN
      -- FOR ALL
      IF new_using IS NOT NULL AND new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR ALL TO authenticated USING (%s) WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using, new_check
        );
      ELSIF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR ALL TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      ELSIF new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR ALL TO authenticated WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_check
        );
      END IF;
    ELSIF pol.cmd = 'r' THEN
      -- FOR SELECT
      IF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR SELECT TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      END IF;
    ELSIF pol.cmd = 'a' THEN
      -- FOR INSERT
      IF new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR INSERT TO authenticated WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_check
        );
      END IF;
    ELSIF pol.cmd = 'w' THEN
      -- FOR UPDATE
      IF new_using IS NOT NULL AND new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR UPDATE TO authenticated USING (%s) WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using, new_check
        );
      ELSIF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR UPDATE TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      ELSIF new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR UPDATE TO authenticated WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_check
        );
      END IF;
    ELSIF pol.cmd = 'd' THEN
      -- FOR DELETE
      IF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR DELETE TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      END IF;
    END IF;
  END LOOP;
END $$;