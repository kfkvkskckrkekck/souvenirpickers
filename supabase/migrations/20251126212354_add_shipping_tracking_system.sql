-- Shipping and Tracking System
--
-- 1. New Tables
--    - shipping_providers: List of supported shipping carriers
--    - shipment_tracking: Track shipments with real-time updates
--    - shipping_rates: Store shipping rate quotes
--
-- 2. Security
--    - Enable RLS on all tables
--    - Users can only view their own shipment information

-- Create shipping_providers table
CREATE TABLE IF NOT EXISTS shipping_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_code text UNIQUE NOT NULL,
  provider_name text NOT NULL,
  tracking_url_template text,
  supported_countries text[] DEFAULT ARRAY[]::text[],
  api_enabled boolean DEFAULT false,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Create shipment_tracking table
CREATE TABLE IF NOT EXISTS shipment_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  provider_id uuid REFERENCES shipping_providers(id),
  tracking_number text NOT NULL,
  carrier_code text,
  status text DEFAULT 'pending',
  current_location text,
  estimated_delivery timestamptz,
  actual_delivery timestamptz,
  tracking_events jsonb DEFAULT '[]'::jsonb,
  last_updated timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Create shipping_rates table
CREATE TABLE IF NOT EXISTS shipping_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  provider_id uuid REFERENCES shipping_providers(id),
  service_type text,
  rate numeric(10, 2) NOT NULL,
  currency text DEFAULT 'usd',
  estimated_days integer,
  quoted_at timestamptz DEFAULT now(),
  expires_at timestamptz,
  selected boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Insert default shipping providers
INSERT INTO shipping_providers (provider_code, provider_name, tracking_url_template, active)
VALUES 
  ('usps', 'USPS', 'https://tools.usps.com/go/TrackConfirmAction?tLabels={tracking_number}', true),
  ('ups', 'UPS', 'https://www.ups.com/track?tracknum={tracking_number}', true),
  ('fedex', 'FedEx', 'https://www.fedex.com/fedextrack/?tracknumbers={tracking_number}', true),
  ('dhl', 'DHL', 'https://www.dhl.com/en/express/tracking.html?AWB={tracking_number}', true),
  ('other', 'Other Carrier', null, true)
ON CONFLICT (provider_code) DO NOTHING;

-- Enable RLS
ALTER TABLE shipping_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_rates ENABLE ROW LEVEL SECURITY;

-- Policies for shipping_providers (public read)
CREATE POLICY "Anyone can view active providers"
  ON shipping_providers FOR SELECT
  TO authenticated
  USING (active = true);

-- Policies for shipment_tracking
CREATE POLICY "Users can view own shipment tracking"
  ON shipment_tracking FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipment_tracking.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Pickers can insert shipment tracking"
  ON shipment_tracking FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND orders.picker_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update shipment tracking"
  ON shipment_tracking FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipment_tracking.order_id
      AND orders.picker_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipment_tracking.order_id
      AND orders.picker_id = auth.uid()
    )
  );

-- Policies for shipping_rates
CREATE POLICY "Users can view own shipping rates"
  ON shipping_rates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipping_rates.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Pickers can manage shipping rates"
  ON shipping_rates FOR ALL
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND orders.picker_id = auth.uid()
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_shipment_tracking_order_id ON shipment_tracking(order_id);
CREATE INDEX IF NOT EXISTS idx_shipment_tracking_tracking_number ON shipment_tracking(tracking_number);
CREATE INDEX IF NOT EXISTS idx_shipping_rates_order_id ON shipping_rates(order_id);

-- Function to notify users of tracking updates
CREATE OR REPLACE FUNCTION notify_tracking_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status != OLD.status OR NEW.current_location != OLD.current_location THEN
    INSERT INTO notifications (user_id, type, title, message, link)
    SELECT 
      orders.client_id,
      'shipment_update',
      'Shipment Update',
      'Your order has been updated: ' || NEW.status,
      '/orders'
    FROM orders
    WHERE orders.id = NEW.order_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for tracking updates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_shipment_tracking_update'
  ) THEN
    CREATE TRIGGER on_shipment_tracking_update
      AFTER UPDATE ON shipment_tracking
      FOR EACH ROW
      EXECUTE FUNCTION notify_tracking_update();
  END IF;
END $$;
