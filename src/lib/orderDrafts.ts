import { useCallback, useEffect, useMemo, useRef } from 'react';
import { supabase } from './supabase';

// Checkout creates the order row only when the buyer presses Pay, because the
// create-payment-intent edge function needs an existing order to attach the
// payment to. If that attempt then fails or is abandoned, the unpaid row must
// not be left behind looking like a placed order.

export async function discardUnpaidOrders(orderIds: string[], userId?: string): Promise<string[]> {
  if (orderIds.length === 0) return [];

  // The payment_status filter (mirrored by the DELETE RLS policy) means an
  // order that has been paid can never be removed from here.
  const { data, error } = await supabase
    .from('orders')
    .delete()
    .in('id', orderIds)
    .eq('payment_status', 'pending')
    .select('id');

  if (error) throw error;

  const removed = (data ?? []).map((row: { id: string }) => row.id);

  if (removed.length > 0 && userId) {
    await supabase
      .from('notifications')
      .delete()
      .eq('user_id', userId)
      .in('metadata->>order_id', removed);
  }

  return removed;
}

export type UnpaidOrderGuard = {
  trackCreated: (orderId: string) => void;
  markPaid: (orderId: string) => void;
  markOutcomeUnknown: (orderId: string) => void;
  setProcessing: (processing: boolean) => void;
  discard: () => Promise<{ removed: string[]; remaining: string[] }>;
};

// Tracks the orders a checkout created and removes the ones that never got
// paid when the buyer cancels or leaves. Orders that are paid, or whose payment
// outcome is unknown, are never touched, and nothing is removed while a
// payment is mid-flight (the Stripe webhook settles those).
export function useUnpaidOrderGuard(userId: string | undefined): UnpaidOrderGuard {
  const created = useRef(new Set<string>());
  const protectedIds = useRef(new Set<string>());
  const processing = useRef(false);
  const userIdRef = useRef(userId);
  userIdRef.current = userId;

  const discard = useCallback(async () => {
    const unpaid = [...created.current].filter((id) => !protectedIds.current.has(id));
    if (processing.current || unpaid.length === 0) {
      return { removed: [], remaining: unpaid };
    }

    try {
      const removed = await discardUnpaidOrders(unpaid, userIdRef.current);
      removed.forEach((id) => created.current.delete(id));
      return { removed, remaining: unpaid.filter((id) => !removed.includes(id)) };
    } catch {
      return { removed: [], remaining: unpaid };
    }
  }, []);

  const guard = useMemo<UnpaidOrderGuard>(
    () => ({
      trackCreated: (orderId) => {
        created.current.add(orderId);
      },
      markPaid: (orderId) => {
        protectedIds.current.add(orderId);
      },
      markOutcomeUnknown: (orderId) => {
        protectedIds.current.add(orderId);
      },
      setProcessing: (value) => {
        processing.current = value;
      },
      discard,
    }),
    [discard],
  );

  useEffect(() => {
    return () => {
      void guard.discard();
    };
  }, [guard]);

  return guard;
}
