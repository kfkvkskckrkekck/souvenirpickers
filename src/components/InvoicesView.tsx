import { useState, useEffect } from 'react';
import { FileText, Download, Eye, Calendar, CheckCircle, Clock } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';

interface Invoice {
  id: string;
  invoice_number: string;
  issue_date: string;
  due_date: string;
  billing_period_start: string;
  billing_period_end: string;
  subtotal: number;
  tax_rate: number;
  tax_amount: number;
  total_amount: number;
  currency: string;
  status: 'draft' | 'sent' | 'paid' | 'cancelled';
  payment_method?: string;
  paid_at?: string;
  sent_at?: string;
}

export function InvoicesView() {
  const { profile } = useAuth();
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedInvoice, setSelectedInvoice] = useState<Invoice | null>(null);

  useEffect(() => {
    if (profile?.id) {
      loadInvoices();
    }
  }, [profile]);

  const loadInvoices = async () => {
    try {
      const { data, error } = await supabase
        .from('invoices')
        .select('*')
        .eq('picker_id', profile!.id)
        .order('issue_date', { ascending: false });

      if (error) throw error;
      setInvoices(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const configs = {
      paid: { color: 'bg-green-100 text-green-800', icon: CheckCircle, label: 'Paid' },
      sent: { color: 'bg-blue-100 text-blue-800', icon: Clock, label: 'Sent' },
      draft: { color: 'bg-gray-100 text-gray-800', icon: Clock, label: 'Draft' },
      cancelled: { color: 'bg-red-100 text-red-800', icon: Clock, label: 'Cancelled' },
    };

    const config = configs[status as keyof typeof configs] || configs.draft;
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium ${config.color}`}>
        <Icon className="w-3.5 h-3.5" />
        {config.label}
      </span>
    );
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const formatCurrency = (amount: number, currency: string) => {
    const symbol = currency === 'EUR' ? '€' : currency === 'USD' ? '$' : currency;
    return `${symbol}${parseFloat(amount.toString()).toFixed(2)}`;
  };

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-center py-12">
          <div className="text-gray-500">Loading invoices...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Invoices</h2>
          <p className="text-gray-600 mt-1">View and download your subscription invoices</p>
        </div>
      </div>

      {invoices.length === 0 ? (
        <div className="text-center py-12 bg-white rounded-lg border-2 border-dashed border-gray-300">
          <FileText className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-900 mb-2">No invoices yet</h3>
          <p className="text-gray-600">
            Your subscription invoices will appear here after payment
          </p>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-200">
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Invoice
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Billing Period
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Amount
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {invoices.map((invoice) => (
                  <tr key={invoice.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-blue-100 rounded-lg">
                          <FileText className="w-5 h-5 text-blue-600" />
                        </div>
                        <div>
                          <div className="font-semibold text-gray-900">{invoice.invoice_number}</div>
                          {invoice.payment_method && (
                            <div className="text-xs text-gray-500">{invoice.payment_method}</div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-1 text-sm text-gray-600">
                        <Calendar className="w-4 h-4" />
                        {formatDate(invoice.issue_date)}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                      {formatDate(invoice.billing_period_start)} - {formatDate(invoice.billing_period_end)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="font-semibold text-gray-900">
                        {formatCurrency(invoice.total_amount, invoice.currency)}
                      </div>
                      {invoice.tax_amount > 0 && (
                        <div className="text-xs text-gray-500">
                          incl. VAT {formatCurrency(invoice.tax_amount, invoice.currency)}
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getStatusBadge(invoice.status)}
                      {invoice.paid_at && (
                        <div className="text-xs text-gray-500 mt-1">
                          {formatDate(invoice.paid_at)}
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      <button
                        onClick={() => setSelectedInvoice(invoice)}
                        className="inline-flex items-center gap-2 px-3 py-1.5 text-sm text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg transition-colors"
                      >
                        <Eye className="w-4 h-4" />
                        View
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {selectedInvoice && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
              <h3 className="text-xl font-bold text-gray-900">Invoice Details</h3>
              <button
                onClick={() => setSelectedInvoice(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <span className="text-2xl">&times;</span>
              </button>
            </div>

            <div className="p-6 space-y-6">
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-3xl font-bold text-blue-600 mb-2">SouvenirPickers</div>
                  <div className="text-sm text-gray-600">
                    Global Marketplace Platform<br />
                    Email: billing@souvenirpickers.com
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-2xl font-bold text-gray-900 mb-2">INVOICE</div>
                  <div className="text-lg text-gray-600">{selectedInvoice.invoice_number}</div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-6 pt-6 border-t border-gray-200">
                <div>
                  <div className="text-sm font-semibold text-gray-500 mb-2">ISSUE DATE</div>
                  <div className="text-gray-900">{formatDate(selectedInvoice.issue_date)}</div>
                </div>
                <div>
                  <div className="text-sm font-semibold text-gray-500 mb-2">DUE DATE</div>
                  <div className="text-gray-900">{formatDate(selectedInvoice.due_date)}</div>
                </div>
              </div>

              <div className="pt-6 border-t border-gray-200">
                <div className="text-sm font-semibold text-gray-500 mb-3">BILLING PERIOD</div>
                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="text-gray-900">
                    {formatDate(selectedInvoice.billing_period_start)} - {formatDate(selectedInvoice.billing_period_end)}
                  </div>
                  <div className="text-sm text-gray-600 mt-1">
                    SouvenirPickers Picker Subscription - Monthly marketplace access and tools
                  </div>
                </div>
              </div>

              <div className="pt-6 border-t border-gray-200 space-y-3">
                <div className="flex justify-between text-gray-600">
                  <span>Subtotal</span>
                  <span>{formatCurrency(selectedInvoice.subtotal, selectedInvoice.currency)}</span>
                </div>
                {selectedInvoice.tax_rate > 0 && (
                  <div className="flex justify-between text-gray-600">
                    <span>VAT ({selectedInvoice.tax_rate}%)</span>
                    <span>{formatCurrency(selectedInvoice.tax_amount, selectedInvoice.currency)}</span>
                  </div>
                )}
                <div className="flex justify-between text-xl font-bold text-gray-900 pt-3 border-t border-gray-200">
                  <span>Total</span>
                  <span>{formatCurrency(selectedInvoice.total_amount, selectedInvoice.currency)} {selectedInvoice.currency}</span>
                </div>
              </div>

              {selectedInvoice.status === 'paid' && selectedInvoice.paid_at && (
                <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div className="flex items-center gap-2 text-green-800 font-semibold mb-2">
                    <CheckCircle className="w-5 h-5" />
                    PAID
                  </div>
                  <div className="text-sm text-green-700">
                    <div>Payment Date: {formatDate(selectedInvoice.paid_at)}</div>
                    {selectedInvoice.payment_method && (
                      <div>Payment Method: {selectedInvoice.payment_method}</div>
                    )}
                  </div>
                </div>
              )}
            </div>

            <div className="sticky bottom-0 bg-gray-50 border-t border-gray-200 px-6 py-4">
              <button
                onClick={() => setSelectedInvoice(null)}
                className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
