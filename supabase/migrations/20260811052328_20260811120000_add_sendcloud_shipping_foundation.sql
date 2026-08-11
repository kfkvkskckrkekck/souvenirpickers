/*
# Add Sendcloud shipping foundation and archive manual quote tables

1. Listing package fields
- Adds weight_kg, length_cm, width_cm, height_cm, and package_size_preset to listings.
- These values are used by the platform to request automated shipping rates.

2. Seller addresses
- Creates seller_addresses for seller ship-from details.
- Each address belongs to an authenticated seller and can be marked as the default.

3. Order shipping fields
- Adds carrier, service, cost, label URL, tracking number/status, Sendcloud parcel ID,
  label purchase time, and estimated delivery days to orders.
- Existing order and payment data is preserved.

4. Manual quote archival
- Renames shipping_quotes and transportation_quotes to *_archived when present.
- No table or user data is dropped. Existing quote-related columns remain intact for
  historical compatibility and are no longer used by the application.

5. Security
- Enables RLS on seller_addresses.
- Authenticated sellers can only select, insert, update, and delete their own addresses.
- The service_role can select all seller addresses.
- Adds an orders realtime publication entry when it is not already present.
*/

ALTER TABLE listings ADD COLUMN IF NOT EXISTS weight_kg numeric(8,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS length_cm numeric(8,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS width_cm numeric(8,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS height_cm numeric(8,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS package_size_preset varchar(20);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'listings_package_size_preset_check'
      AND conrelid = 'public.listings'::regclass
  ) THEN
    ALTER TABLE listings ADD CONSTRAINT listings_package_size_preset_check
      CHECK (package_size_preset IS NULL OR package_size_preset IN ('small', 'medium', 'large', 'xlarge', 'custom'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS seller_addresses (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name varchar(255) NOT NULL,
  company_name varchar(255),
  street varchar(255) NOT NULL,
  city varchar(100) NOT NULL,
  postcode varchar(20) NOT NULL,
  country_code char(2) NOT NULL,
  phone varchar(30) NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_seller_addresses_seller_id ON seller_addresses(seller_id);
CREATE INDEX IF NOT EXISTS idx_seller_addresses_default ON seller_addresses(seller_id, is_default);

ALTER TABLE seller_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sellers can read own addresses" ON seller_addresses;
CREATE POLICY "Sellers can read own addresses" ON seller_addresses
  FOR SELECT TO authenticated USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can insert own addresses" ON seller_addresses;
CREATE POLICY "Sellers can insert own addresses" ON seller_addresses
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can update own addresses" ON seller_addresses;
CREATE POLICY "Sellers can update own addresses" ON seller_addresses
  FOR UPDATE TO authenticated USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Sellers can delete own addresses" ON seller_addresses;
CREATE POLICY "Sellers can delete own addresses" ON seller_addresses
  FOR DELETE TO authenticated USING (auth.uid() = seller_id);

DROP POLICY IF EXISTS "Service role can read seller addresses" ON seller_addresses;
CREATE POLICY "Service role can read seller addresses" ON seller_addresses
  FOR SELECT TO service_role USING (true);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_carrier varchar(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_service varchar(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_cost numeric(10,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_label_url text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_number varchar(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_status varchar(50) NOT NULL DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS sendcloud_parcel_id varchar(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS label_purchased_at timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS estimated_delivery_days varchar(50);

DO $$
BEGIN
  IF to_regclass('public.shipping_quotes') IS NOT NULL
     AND to_regclass('public.shipping_quotes_archived') IS NULL THEN
    ALTER TABLE public.shipping_quotes RENAME TO shipping_quotes_archived;
  END IF;
  IF to_regclass('public.transportation_quotes') IS NOT NULL
     AND to_regclass('public.transportation_quotes_archived') IS NULL THEN
    ALTER TABLE public.transportation_quotes RENAME TO transportation_quotes_archived;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
END $$;