/*
  # Create Trial Ending Reminder System for Pickers

  1. New Functions
    - `check_trial_endings()` - Finds pickers whose trials are ending soon
    - `create_trial_reminder()` - Creates reminder for a picker
    - `check_picker_has_payment_method()` - Verifies if picker has payment card
    
  2. Reminder Schedule
    - 7 days before: First reminder to add payment method
    - 3 days before: Second reminder with urgency
    - 1 day before: Final urgent reminder
    - On trial end day: Warning about account suspension

  3. Flow
    - Daily check for upcoming trial expirations
    - Send reminders only if picker has no payment method
    - Don't spam if picker already added payment
    - Clear call-to-action to add payment method

  4. Benefits
    - Prevents surprise trial endings
    - Increases payment method conversion
    - Better user experience
    - Reduces churn
*/

-- Function to check if picker has valid payment method
CREATE OR REPLACE FUNCTION check_picker_has_payment_method(p_picker_id uuid)
RETURNS boolean AS $$
DECLARE
  v_has_payment boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM picker_payment_cards
    WHERE picker_id = p_picker_id
    AND stripe_payment_method_id IS NOT NULL
  ) INTO v_has_payment;

  RETURN COALESCE(v_has_payment, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create trial ending reminder
CREATE OR REPLACE FUNCTION create_trial_reminder(
  p_picker_id uuid,
  p_days_until_end integer
)
RETURNS void AS $$
DECLARE
  v_profile record;
  v_reminder_exists boolean;
  v_title text;
  v_message text;
BEGIN
  -- Get picker profile
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = p_picker_id
  AND user_type = 'picker';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Check if reminder already exists for this timeframe
  SELECT EXISTS (
    SELECT 1
    FROM reminder_queue
    WHERE user_id = p_picker_id
      AND reminder_type = 'trial_ending'
      AND (data->>'days_until_end')::int = p_days_until_end
      AND sent = false
      AND cancelled = false
      AND scheduled_for >= now()
  ) INTO v_reminder_exists;

  IF v_reminder_exists THEN
    RETURN;
  END IF;

  -- Don't send if picker already has payment method
  IF check_picker_has_payment_method(p_picker_id) THEN
    RETURN;
  END IF;

  -- Create appropriate message based on days remaining
  IF p_days_until_end >= 7 THEN
    v_title := 'Trial Ending in ' || p_days_until_end || ' Days';
    v_message := 'Your free trial ends in ' || p_days_until_end || ' days. Add your payment method now to continue using SouvenirPickers without interruption.';
  ELSIF p_days_until_end >= 3 THEN
    v_title := 'Action Needed: Trial Ending Soon';
    v_message := 'Only ' || p_days_until_end || ' days left in your trial! Add a payment method now to keep your picker account active and continue earning.';
  ELSIF p_days_until_end >= 1 THEN
    v_title := '⚠️ Urgent: Trial Ends Tomorrow';
    v_message := 'Your trial ends tomorrow! Add your payment method immediately to avoid account suspension and continue accepting orders.';
  ELSE
    v_title := '🚨 Final Notice: Trial Ends Today';
    v_message := 'Your trial ends today! Add a payment method now to prevent your account from being suspended. Don''t lose access to your earnings and customers!';
  END IF;

  -- Schedule reminder
  INSERT INTO reminder_queue (reminder_type, user_id, scheduled_for, data)
  VALUES (
    'trial_ending',
    p_picker_id,
    now() + INTERVAL '5 minutes',
    jsonb_build_object(
      'days_until_end', p_days_until_end,
      'trial_ends_at', v_profile.trial_ends_at,
      'has_payment_method', false
    )
  );

  -- Send immediate notification
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    p_picker_id,
    'trial_ending',
    v_title,
    v_message,
    jsonb_build_object(
      'days_until_end', p_days_until_end,
      'trial_ends_at', v_profile.trial_ends_at,
      'action_required', true,
      'action_url', '/subscription'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check all upcoming trial endings
CREATE OR REPLACE FUNCTION check_trial_endings()
RETURNS json AS $$
DECLARE
  v_picker record;
  v_count_7day integer := 0;
  v_count_3day integer := 0;
  v_count_1day integer := 0;
  v_count_today integer := 0;
  v_days_remaining integer;
BEGIN
  -- Find pickers whose trials are ending soon
  FOR v_picker IN
    SELECT 
      id,
      email,
      full_name,
      trial_ends_at,
      subscription_status
    FROM profiles
    WHERE user_type = 'picker'
      AND subscription_status IN ('trial', 'past_due', 'cancelled')
      AND trial_ends_at IS NOT NULL
      AND trial_ends_at > now()
      AND trial_ends_at <= now() + INTERVAL '14 days'
  LOOP
    -- Calculate days remaining
    v_days_remaining := EXTRACT(DAY FROM (v_picker.trial_ends_at - now()));

    -- Skip if picker already has payment method
    IF check_picker_has_payment_method(v_picker.id) THEN
      CONTINUE;
    END IF;

    -- Create reminders based on days remaining
    IF v_days_remaining = 7 THEN
      PERFORM create_trial_reminder(v_picker.id, 7);
      v_count_7day := v_count_7day + 1;
    ELSIF v_days_remaining = 3 THEN
      PERFORM create_trial_reminder(v_picker.id, 3);
      v_count_3day := v_count_3day + 1;
    ELSIF v_days_remaining = 1 THEN
      PERFORM create_trial_reminder(v_picker.id, 1);
      v_count_1day := v_count_1day + 1;
    ELSIF v_days_remaining = 0 THEN
      PERFORM create_trial_reminder(v_picker.id, 0);
      v_count_today := v_count_today + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'reminders_7day', v_count_7day,
    'reminders_3day', v_count_3day,
    'reminders_1day', v_count_1day,
    'reminders_today', v_count_today,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle trial reminders in reminder queue
CREATE OR REPLACE FUNCTION process_trial_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_has_payment boolean;
BEGIN
  -- Process trial ending reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE reminder_type = 'trial_ending'
      AND scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 50
  LOOP
    BEGIN
      -- Check if picker now has payment method
      v_has_payment := check_picker_has_payment_method(v_reminder.user_id);

      IF v_has_payment THEN
        -- Cancel reminder if payment method was added
        UPDATE reminder_queue
        SET cancelled = true, cancelled_at = now()
        WHERE id = v_reminder.id;
        
        -- Send success notification
        INSERT INTO notifications (user_id, type, title, message)
        VALUES (
          v_reminder.user_id,
          'payment_method_added',
          'Payment Method Added Successfully',
          'Thank you for adding your payment method! Your account will remain active when your trial ends.'
        );
      ELSE
        -- Send the reminder
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'trial_ending_reminder',
          CASE 
            WHEN (v_reminder.data->>'days_until_end')::int >= 7 THEN 'Trial Ending Soon'
            WHEN (v_reminder.data->>'days_until_end')::int >= 3 THEN 'Action Required: Add Payment Method'
            WHEN (v_reminder.data->>'days_until_end')::int >= 1 THEN '⚠️ Urgent: Trial Ends Tomorrow'
            ELSE '🚨 Final Notice: Trial Ends Today'
          END,
          CASE 
            WHEN (v_reminder.data->>'days_until_end')::int >= 7 THEN 
              'Your trial ends in ' || (v_reminder.data->>'days_until_end') || ' days. Add payment method to continue.'
            WHEN (v_reminder.data->>'days_until_end')::int >= 3 THEN 
              'Only ' || (v_reminder.data->>'days_until_end') || ' days left! Add payment now to keep earning.'
            WHEN (v_reminder.data->>'days_until_end')::int >= 1 THEN 
              'Trial ends tomorrow! Add payment method to avoid account suspension.'
            ELSE 
              'Trial ends today! Add payment method now to prevent suspension.'
          END,
          jsonb_build_object(
            'days_until_end', v_reminder.data->>'days_until_end',
            'action_required', true,
            'action_url', '/subscription'
          )
        );

        -- Mark as sent
        UPDATE reminder_queue
        SET sent = true, sent_at = now()
        WHERE id = v_reminder.id;
      END IF;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Error processing trial reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_picker_has_payment_method(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_trial_reminder(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION check_trial_endings() TO authenticated;
GRANT EXECUTE ON FUNCTION process_trial_reminders() TO authenticated;
