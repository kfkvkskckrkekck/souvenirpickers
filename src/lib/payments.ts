import { supabase } from './supabase';

type CreatePaymentIntentParams = {
  orderId: string;
  amount: number;
  productAmount?: number;
  shippingAmount?: number;
};

export async function createPaymentIntentForOrder({
  orderId,
  amount,
  productAmount,
  shippingAmount,
}: CreatePaymentIntentParams): Promise<{ clientSecret: string }> {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData?.session?.access_token;

  if (!token) {
    throw new Error('Not authenticated');
  }

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
  const response = await fetch(`${supabaseUrl}/functions/v1/create-payment-intent`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({
      orderId,
      amount,
      productAmount,
      shippingAmount,
      currency: 'eur',
    }),
  });

  const result = await response.json();

  if (result.error) {
    throw new Error(result.error);
  }
  if (!result.clientSecret) {
    throw new Error('Failed to initialize payment.');
  }

  return { clientSecret: result.clientSecret };
}
