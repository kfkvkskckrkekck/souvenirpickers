import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// console.log('🔧 Initializing Supabase client...', {
//   url: supabaseUrl ? `${supabaseUrl.substring(0, 30)}...` : 'MISSING',
//   anonKey: supabaseAnonKey ? `${supabaseAnonKey.substring(0, 20)}...` : 'MISSING'
// });

if (!supabaseUrl || !supabaseAnonKey) {
  console.error("❌ CRITICAL: Environment variables missing!", {
    VITE_SUPABASE_URL: supabaseUrl,
    VITE_SUPABASE_ANON_KEY: supabaseAnonKey ? "exists but empty" : "missing",
  });
  throw new Error(
    "❌ CRITICAL ERROR: Supabase environment variables are missing!\n" +
      "Please ensure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are set in your .env file.\n" +
      "Expected project: bfqvzxczmvfteqbhgyvx",
  );
}

const EXPECTED_PROJECT_ID = "bfqvzxczmvfteqbhgyvx";
if (!supabaseUrl.includes(EXPECTED_PROJECT_ID)) {
  throw new Error(
    `❌ CRITICAL ERROR: Wrong Supabase project detected!\n` +
      `Expected project ID: ${EXPECTED_PROJECT_ID}\n` +
      `Current URL: ${supabaseUrl}\n` +
      `Please update your .env file with the correct project credentials.`,
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: typeof window !== "undefined" ? window.localStorage : undefined,
    storageKey: "souvenirpickers-auth",
    flowType: "pkce",
  },
  global: {
    headers: {
      apikey: supabaseAnonKey,
    },
  },
});

console.log("✅ Supabase client initialized successfully");

export type Profile = {
  id: string;
  email: string;
  full_name: string;
  user_type: "picker" | "client";
  avatar_url?: string;
  bio?: string;
  trial_started_at: string;
  trial_ends_at: string;
  subscription_status: "trial" | "active" | "past_due" | "cancelled";
  subscription_started_at?: string;
  last_payment_date?: string;
  next_payment_due?: string;
  payment_failed: boolean;
  company_name?: string;
  billing_address?: string;
  billing_city?: string;
  billing_postal_code?: string;
  billing_country?: string;
  tax_id?: string;
  billing_email?: string;
  billing_phone?: string;
  default_delivery_address?: string;
  facebook_url?: string;
  twitter_url?: string;
  instagram_url?: string;
  threads_url?: string;
  is_admin?: boolean;
  created_at: string;
};

export type PickerProfile = {
  id: string;
  user_id: string;
  current_location: string;
  regions: string[];
  specialties: string[];
  latitude?: number;
  longitude?: number;
  location_updated_at?: string;
  rating: number;
  total_reviews: number;
  verified: boolean;
  verification_status?: "unverified" | "pending" | "verified" | "rejected";
  verification_documents?: string[];
  verification_notes?: string;
  verified_at?: string;
  total_sales?: number;
  total_revenue?: number;
  last_active_at?: string;
  created_at: string;
};

export type Listing = {
  id: string;
  picker_id: string;
  title: string;
  description: string;
  category: string;
  region: string;
  price: number;
  image_url?: string;
  images: string[];
  videos: string[];
  latitude?: number;
  longitude?: number;
  pickup_location?: string;
  weight_kg?: number;
  length_cm?: number;
  width_cm?: number;
  height_cm?: number;
  package_size_preset?: "small" | "medium" | "large" | "xlarge" | "custom";
  available: boolean;
  created_at: string;
  updated_at: string;
};

export type Request = {
  id: string;
  client_id: string;
  picker_id?: string;
  title: string;
  description: string;
  region: string;
  category: string;
  budget?: number;
  status: "open" | "assigned" | "in_progress" | "completed" | "cancelled";
  created_at: string;
  updated_at: string;
};

export type Message = {
  id: string;
  request_id: string;
  sender_id: string;
  recipient_id: string;
  content: string;
  read: boolean;
  created_at: string;
};

export type Review = {
  id: string;
  picker_id: string;
  client_id: string;
  request_id?: string;
  order_id?: string;
  listing_id?: string;
  rating: number;
  comment?: string;
  response?: string;
  response_at?: string;
  created_at: string;
  updated_at: string;
};

export type ClientDesire = {
  id: string;
  client_id: string;
  title: string;
  description: string;
  category: string;
  preferred_regions: string[];
  preferred_locations: string[];
  latitude?: number;
  longitude?: number;
  budget_min?: number;
  budget_max?: number;
  urgency: "low" | "medium" | "high";
  active: boolean;
  created_at: string;
  updated_at: string;
};

export type PaymentMethod = {
  id: string;
  picker_id: string;
  method_type:
    | "credit_card"
    | "debit_card"
    | "paypal"
    | "bank_account"
    | "other";
  card_brand?: string;
  last_four?: string;
  cardholder_name: string;
  expiry_month?: number;
  expiry_year?: number;
  is_default: boolean;
  stripe_payment_method_id?: string;
  created_at: string;
  updated_at: string;
};

export type Conversation = {
  id: string;
  client_id: string;
  picker_id: string;
  created_at: string;
  updated_at: string;
};

export type ConversationMessage = {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  read: boolean;
  created_at: string;
};

export type Order = {
  id: string;
  client_id: string;
  picker_id: string;
  listing_id: string;
  status:
    | "pending"
    | "accepted"
    | "in_progress"
    | "paid"
    | "label_created"
    | "shipped"
    | "delivered"
    | "completed"
    | "cancelled"
    | "refunded";
  quantity: number;
  total_price: number;
  delivery_address?: string;
  delivery_street?: string;
  delivery_street_line2?: string;
  delivery_city?: string;
  delivery_postal_code?: string;
  delivery_country?: string;
  delivery_instructions?: string;
  shipping_carrier?: string;
  shipping_service?: string;
  shipping_cost?: number;
  shipping_label_url?: string;
  tracking_status?: string;
  sendcloud_parcel_id?: string;
  label_purchased_at?: string;
  estimated_delivery_days?: string;
  payment_status: "pending" | "paid" | "refunded";
  payment_intent_id?: string;
  notes?: string;
  is_gift?: boolean;
  gift_recipient_name?: string;
  gift_recipient_email?: string;
  gift_message?: string;
  gift_recipient_address?: string;
  transportation_cost?: number;
  shipping_quote_status?:
    | "quote_requested"
    | "quote_provided"
    | "quote_approved"
    | "no_quote_needed";
  shipping_notes?: string;
  quote_requested_at?: string;
  quote_provided_at?: string;
  estimated_weight_kg?: number;
  tracking_number?: string;
  carrier?: string;
  shipping_paid?: boolean;
  shipping_paid_at?: string;
  shipping_transfer_id?: string;
  shipped_at?: string;
  auto_release_at?: string;
  estimated_delivery?: string;
  actual_delivery?: string;
  refund_requested_at?: string;
  refund_reason?: string;
  refunded_at?: string;
  refund_amount?: number;
  cancelled_at?: string;
  delivered_at?: string;
  pickup_video_url?: string;
  pickup_video_uploaded_at?: string;
  pickup_video_thumbnail_url?: string;
  goods_received?: boolean;
  goods_received_at?: string;
  goods_confirmed?: boolean;
  goods_confirmed_at?: string;
  confirmation_notes?: string;
  created_at: string;
  updated_at: string;
};

export type OrderStatusHistory = {
  id: string;
  order_id: string;
  status: string;
  notes?: string;
  changed_by: string;
  created_at: string;
};

export type CollectorPaymentMethod = {
  id: string;
  user_id: string;
  type: string;
  brand?: string;
  last_four?: string;
  exp_month?: number;
  exp_year?: number;
  is_default: boolean;
  stripe_payment_method_id?: string;
  created_at: string;
};

export type CartItem = {
  id: string;
  client_id: string;
  listing_id: string;
  quantity: number;
  transportation_cost?: number;
  shipping_quote_status:
    | "no_quote_needed"
    | "quote_requested"
    | "quote_provided"
    | "quote_expired";
  shipping_notes?: string;
  quote_requested_at?: string;
  quote_provided_at?: string;
  delivery_street?: string;
  delivery_street_line2?: string;
  delivery_city?: string;
  delivery_postal_code?: string;
  delivery_country?: string;
  estimated_weight_kg?: number;
  created_at: string;
  updated_at: string;
};

export type Notification = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  message: string;
  link?: string;
  read: boolean;
  created_at: string;
  metadata?: Record<string, any>;
};

export type Favorite = {
  id: string;
  client_id: string;
  listing_id: string;
  created_at: string;
};

export type FavoritePicker = {
  id: string;
  client_id: string;
  picker_id: string;
  created_at: string;
};

export type ReportedUser = {
  id: string;
  reporter_id: string;
  reported_user_id: string;
  reason: string;
  description?: string;
  status: "pending" | "reviewed" | "resolved" | "dismissed";
  reviewed_by?: string;
  reviewed_at?: string;
  created_at: string;
};

export type BlockedUser = {
  id: string;
  user_id: string;
  blocked_user_id: string;
  created_at: string;
};

export type OrderUpdate = {
  id: string;
  order_id: string;
  status: string;
  message: string;
  created_by?: string;
  created_at: string;
};

export type PickerAnalytics = {
  id: string;
  picker_id: string;
  date: string;
  views: number;
  messages_received: number;
  orders_received: number;
  revenue: number;
  created_at: string;
};

export type PaymentIntent = {
  id: string;
  order_id: string;
  stripe_payment_intent_id: string;
  amount: number;
  currency: string;
  status: "pending" | "succeeded" | "failed" | "canceled";
  client_secret: string;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
};

export type PaymentEscrow = {
  id: string;
  payment_intent_id: string;
  order_id: string;
  amount: number;
  status: "held" | "released_to_picker" | "refunded_to_client";
  held_at: string;
  released_at?: string;
  released_to?: string;
  notes?: string;
  created_at: string;
};

export type Refund = {
  id: string;
  payment_intent_id: string;
  order_id: string;
  stripe_refund_id?: string;
  amount: number;
  reason?: string;
  status: "pending" | "succeeded" | "failed";
  initiated_by: string;
  created_at: string;
};
