import { useEffect, useMemo, useState } from 'react';
import { Check, Copy, MapPin, Package, Truck } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type OrderTrackingViewProps = { orderId: string | null };

type TrackingOrder = {
  id: string;
  total_price: number;
  delivery_address: string | null;
  shipping_carrier: string | null;
  shipping_service: string | null;
  tracking_number: string | null;
  tracking_status: string | null;
  estimated_delivery_days: string | null;
  listing: { title: string; images: string[] } | null;
};

const steps = [
  ['pending', 'Order Placed'],
  ['label_created', 'Label Created'],
  ['picked_up', 'Picked Up'],
  ['in_transit', 'In Transit'],
  ['out_for_delivery', 'Out for Delivery'],
  ['delivered', 'Delivered'],
] as const;

export function OrderTrackingView({ orderId }: OrderTrackingViewProps) {
  const { user } = useAuth();
  const [order, setOrder] = useState<TrackingOrder | null>(null);
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!orderId || !user) return;
    let active = true;
    const loadOrder = async () => {
      const { data, error: queryError } = await supabase
        .from('orders')
        .select('id,total_price,delivery_address,shipping_carrier,shipping_service,tracking_number,tracking_status,estimated_delivery_days,listing:listings(title,images)')
        .eq('id', orderId)
        .eq('client_id', user.id)
        .maybeSingle();
      if (!active) return;
      if (queryError || !data) {
        setError('This order could not be found.');
        return;
      }
      setOrder(data as unknown as TrackingOrder);
    };
    void loadOrder();
    const channel = supabase.channel(`order-tracking-${orderId}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders', filter: `id=eq.${orderId}` }, (payload) => {
        setOrder((current) => current ? { ...current, ...(payload.new as Partial<TrackingOrder>) } : current);
      })
      .subscribe();
    return () => { active = false; void supabase.removeChannel(channel); };
  }, [orderId, user]);

  const activeStep = useMemo(() => {
    const index = steps.findIndex(([status]) => status === (order?.tracking_status || 'pending'));
    return index >= 0 ? index : 0;
  }, [order?.tracking_status]);

  const copyTracking = async () => {
    if (!order?.tracking_number) return;
    await navigator.clipboard.writeText(order.tracking_number);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  };

  if (!orderId || error) return <div className="max-w-3xl mx-auto px-4 py-12 text-center text-gray-600">{error || 'Select an order to track.'}</div>;
  if (!order) return <div className="max-w-3xl mx-auto px-4 py-12 text-center text-gray-600">Loading tracking details...</div>;

  return (
    <main className="max-w-4xl mx-auto px-4 sm:px-6 py-8">
      <div className="mb-8"><p className="text-sm font-semibold uppercase tracking-wider text-blue-600">Live order tracking</p><h1 className="text-3xl font-bold text-gray-900 mt-2">Track your order</h1></div>
      <section className="bg-white rounded-2xl shadow-sm border border-gray-200 p-5 sm:p-7">
        <div className="flex gap-4 items-center border-b border-gray-100 pb-6">
          {order.listing?.images?.[0] ? <img src={order.listing.images[0]} alt={order.listing.title} className="w-20 h-20 rounded-xl object-cover" /> : <div className="w-20 h-20 rounded-xl bg-gray-100 flex items-center justify-center"><Package className="text-gray-400" /></div>}
          <div><h2 className="text-xl font-bold text-gray-900">{order.listing?.title || 'Order'}</h2><p className="text-gray-600">€{Number(order.total_price).toFixed(2)}</p></div>
        </div>
        <div className="py-8 overflow-x-auto"><div className="min-w-[680px] flex items-start">{steps.map(([status, label], index) => <div key={status} className="flex-1 relative text-center"><div className={`mx-auto w-9 h-9 rounded-full flex items-center justify-center relative z-10 ${index <= activeStep ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-500'}`}>{index < activeStep ? <Check className="w-4 h-4" /> : <span className="text-sm">{index + 1}</span>}</div>{index < steps.length - 1 && <div className={`absolute top-4 left-1/2 w-full h-1 ${index < activeStep ? 'bg-blue-600' : 'bg-gray-200'}`} /> }<p className={`mt-3 text-xs font-medium ${index <= activeStep ? 'text-blue-700' : 'text-gray-500'}`}>{label}</p></div>)}</div></div>
        <div className="grid sm:grid-cols-2 gap-4">
          <div className="rounded-xl bg-gray-50 p-4"><p className="text-xs text-gray-500 uppercase tracking-wide">Shipping</p><p className="font-semibold text-gray-900 mt-1">{order.shipping_carrier || 'Sendcloud'} · {order.shipping_service || 'Service pending'}</p><p className="text-sm text-gray-600 mt-1">{order.estimated_delivery_days && !order.estimated_delivery_days.startsWith('0-0') ? order.estimated_delivery_days : 'Estimated delivery will appear when available'}</p></div>
          <div className="rounded-xl bg-gray-50 p-4"><p className="text-xs text-gray-500 uppercase tracking-wide">Tracking number</p>{order.tracking_number ? <button onClick={copyTracking} className="mt-1 flex items-center gap-2 font-semibold text-blue-700 hover:text-blue-800">{order.tracking_number}<Copy className="w-4 h-4" />{copied && <span className="text-xs text-green-700">Copied</span>}</button> : <p className="font-semibold text-gray-900 mt-1">Not available yet</p>}</div>
        </div>
        <div className="mt-4 flex items-start gap-3 rounded-xl border border-gray-200 p-4"><MapPin className="w-5 h-5 text-gray-500 mt-0.5" /><div><p className="font-semibold text-gray-900">Delivery address</p><p className="text-sm text-gray-600 whitespace-pre-line mt-1">{order.delivery_address || 'Address unavailable'}</p></div><Truck className="w-5 h-5 text-blue-600 ml-auto" /></div>
      </section>
    </main>
  );
}
