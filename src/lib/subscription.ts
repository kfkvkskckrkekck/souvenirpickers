import { Profile } from './supabase';

export function getSubscriptionStatus(profile: Profile) {
  const now = new Date();
  const trialEnd = new Date(profile.trial_ends_at);
  const isTrialActive = now < trialEnd;

  if (isTrialActive) {
    const daysRemaining = Math.ceil((trialEnd.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    return {
      status: 'trial' as const,
      isActive: true,
      daysRemaining,
      trialEnd,
      message: `Free trial: ${daysRemaining} days remaining`,
    };
  }

  if (profile.subscription_status === 'active') {
    const nextDue = profile.next_payment_due ? new Date(profile.next_payment_due) : null;
    const daysUntilDue = nextDue ? Math.ceil((nextDue.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)) : 0;

    return {
      status: 'active' as const,
      isActive: true,
      daysUntilDue,
      nextDue,
      message: `Active subscription - Next payment in ${daysUntilDue} days`,
    };
  }

  if (profile.subscription_status === 'past_due') {
    return {
      status: 'past_due' as const,
      isActive: false,
      message: 'Payment past due - Please update payment',
    };
  }

  if (profile.subscription_status === 'cancelled') {
    return {
      status: 'cancelled' as const,
      isActive: false,
      message: 'Subscription cancelled',
    };
  }

  return {
    status: 'expired' as const,
    isActive: false,
    message: 'Trial expired - Subscribe to continue',
  };
}

export function formatDate(date: Date): string {
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

export function calculateDaysRemaining(endDate: string): number {
  const now = new Date();
  const end = new Date(endDate);
  return Math.max(0, Math.ceil((end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)));
}
