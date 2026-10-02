import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { AlertTriangle, FileText, Upload, MessageSquare, CheckCircle, XCircle, Clock, Eye } from 'lucide-react';
import SouvenirLoader from './SouvenirLoader';

interface Dispute {
  id: string;
  order_id: string;
  filed_by: string;
  against_user: string;
  dispute_type: string;
  description: string;
  evidence_urls: string[];
  status: string;
  resolution: string | null;
  resolution_type: string | null;
  refund_amount: number | null;
  created_at: string;
  resolved_at: string | null;
  order: {
    listing: {
      title: string;
    };
  };
  against_profile: {
    full_name: string;
  };
}

interface DisputeMessage {
  id: string;
  sender_id: string;
  message: string;
  is_admin_message: boolean;
  created_at: string;
  sender: {
    full_name: string;
  };
}

export default function DisputesView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [selectedDispute, setSelectedDispute] = useState<Dispute | null>(null);
  const [messages, setMessages] = useState<DisputeMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [sendingMessage, setSendingMessage] = useState(false);

  useEffect(() => {
    loadDisputes();
  }, [user]);

  useEffect(() => {
    if (selectedDispute) {
      loadDisputeMessages(selectedDispute.id);
    }
  }, [selectedDispute]);

  const loadDisputes = async () => {
    try {
      setLoading(true);
      const { data, error} = await supabase
        .from('disputes')
        .select(`
          *,
          order:orders(
            listing:listings(title)
          ),
          against_profile:profiles!disputes_against_user_fkey(full_name)
        `)
        .or(`filed_by.eq.${user?.id},against_user.eq.${user?.id}`)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setDisputes(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const loadDisputeMessages = async (disputeId: string) => {
    try {
      const { data, error } = await supabase
        .from('dispute_messages')
        .select(`
          *,
          sender:profiles(full_name)
        `)
        .eq('dispute_id', disputeId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (error) {

    }
  };

  const sendMessage = async () => {
    if (!newMessage.trim() || !selectedDispute) return;

    try {
      setSendingMessage(true);
      const { error } = await supabase
        .from('dispute_messages')
        .insert({
          dispute_id: selectedDispute.id,
          sender_id: user?.id,
          message: newMessage
        });

      if (error) throw error;

      setNewMessage('');
      await loadDisputeMessages(selectedDispute.id);
    } catch (error) {

      alert('Failed to send message');
    } finally {
      setSendingMessage(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const badges: Record<string, any> = {
      open: { icon: AlertTriangle, color: 'bg-red-100 text-red-800', label: 'Open' },
      investigating: { icon: Eye, color: 'bg-yellow-100 text-yellow-800', label: 'Investigating' },
      resolved: { icon: CheckCircle, color: 'bg-green-100 text-green-800', label: 'Resolved' },
      closed: { icon: XCircle, color: 'bg-gray-100 text-gray-800', label: 'Closed' },
      escalated: { icon: AlertTriangle, color: 'bg-purple-100 text-purple-800', label: 'Escalated' }
    };

    const badge = badges[status] || badges.open;
    const Icon = badge.icon;

    return (
      <div className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium ${badge.color}`}>
        <Icon className="w-4 h-4" />
        {badge.label}
      </div>
    );
  };

  const getDisputeTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      non_delivery: 'Non-Delivery',
      wrong_item: 'Wrong Item',
      damaged_item: 'Damaged Item',
      quality_issue: 'Quality Issue',
      refund_request: 'Refund Request',
      other: 'Other'
    };
    return labels[type] || type;
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading disputes..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
          <AlertTriangle className="w-8 h-8 text-red-600" />
          Disputes & Resolution
        </h1>
        <p className="text-gray-600">Manage order disputes and communicate with support</p>
      </div>

      {disputes.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12 text-center">
          <CheckCircle className="w-16 h-16 text-green-400 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 mb-3">No Disputes</h3>
          <p className="text-gray-600 mb-6">
            You don't have any active or past disputes. This is great! It means your transactions are going smoothly.
          </p>
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 max-w-2xl mx-auto">
            <p className="text-sm text-blue-800 mb-2">
              <strong>If you encounter an issue with an order:</strong>
            </p>
            <ul className="text-sm text-blue-800 text-left space-y-1 ml-6 list-disc">
              <li>Try contacting the other party directly through messages first</li>
              <li>If unresolved, go to the order page and click "File Dispute"</li>
              <li>Provide detailed information and evidence</li>
              <li>Our team will investigate and help resolve the issue</li>
            </ul>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-1 space-y-4">
            <h2 className="font-bold text-gray-900">Your Disputes ({disputes.length})</h2>
            {disputes.map(dispute => (
              <div
                key={dispute.id}
                onClick={() => setSelectedDispute(dispute)}
                className={`bg-white rounded-lg shadow-sm border-2 p-4 cursor-pointer hover:border-blue-300 transition-colors ${
                  selectedDispute?.id === dispute.id ? 'border-blue-500' : 'border-gray-200'
                }`}
              >
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <p className="font-semibold text-gray-900 text-sm line-clamp-1">
                      {dispute.order.listing.title}
                    </p>
                    <p className="text-xs text-gray-600">
                      {getDisputeTypeLabel(dispute.dispute_type)}
                    </p>
                  </div>
                  {getStatusBadge(dispute.status)}
                </div>
                <p className="text-xs text-gray-500">
                  Filed {new Date(dispute.created_at).toLocaleDateString()}
                </p>
              </div>
            ))}
          </div>

          <div className="lg:col-span-2">
            {selectedDispute ? (
              <div className="bg-white rounded-xl shadow-sm border border-gray-200">
                <div className="p-6 border-b border-gray-200">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h2 className="text-2xl font-bold text-gray-900 mb-1">
                        {selectedDispute.order.listing.title}
                      </h2>
                      <p className="text-gray-600">
                        {getDisputeTypeLabel(selectedDispute.dispute_type)}
                      </p>
                    </div>
                    {getStatusBadge(selectedDispute.status)}
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div className="bg-gray-50 rounded-lg p-3">
                      <p className="text-xs text-gray-600 mb-1">Filed By</p>
                      <p className="font-semibold text-gray-900">
                        {selectedDispute.filed_by === user?.id ? 'You' : 'Other Party'}
                      </p>
                    </div>
                    <div className="bg-gray-50 rounded-lg p-3">
                      <p className="text-xs text-gray-600 mb-1">Filed Date</p>
                      <p className="font-semibold text-gray-900">
                        {new Date(selectedDispute.created_at).toLocaleDateString()}
                      </p>
                    </div>
                  </div>

                  <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                    <p className="text-sm font-semibold text-gray-900 mb-2">Dispute Description:</p>
                    <p className="text-sm text-gray-700">{selectedDispute.description}</p>
                  </div>

                  {selectedDispute.evidence_urls && selectedDispute.evidence_urls.length > 0 && (
                    <div className="mb-4">
                      <p className="text-sm font-semibold text-gray-900 mb-2">Evidence:</p>
                      <div className="grid grid-cols-3 gap-2">
                        {selectedDispute.evidence_urls.map((url, index) => (
                          <img
                            key={index}
                            src={url}
                            alt={`Evidence ${index + 1}`}
                            className="w-full h-24 object-cover rounded border border-gray-200"
                          />
                        ))}
                      </div>
                    </div>
                  )}

                  {selectedDispute.resolution && (
                    <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                      <p className="text-sm font-semibold text-green-900 mb-2 flex items-center gap-2">
                        <CheckCircle className="w-4 h-4" />
                        Resolution:
                      </p>
                      <p className="text-sm text-green-800 mb-2">{selectedDispute.resolution}</p>
                      {selectedDispute.refund_amount && (
                        <p className="text-sm text-green-800">
                          <strong>Refund Amount:</strong> ${selectedDispute.refund_amount}
                        </p>
                      )}
                      {selectedDispute.resolved_at && (
                        <p className="text-xs text-green-700 mt-2">
                          Resolved on {new Date(selectedDispute.resolved_at).toLocaleDateString()}
                        </p>
                      )}
                    </div>
                  )}
                </div>

                <div className="p-6 border-b border-gray-200">
                  <h3 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                    <MessageSquare className="w-5 h-5" />
                    Dispute Communication
                  </h3>

                  <div className="space-y-4 mb-4 max-h-96 overflow-y-auto">
                    {messages.length === 0 ? (
                      <p className="text-center text-gray-500 py-8">No messages yet. Start the conversation.</p>
                    ) : (
                      messages.map(message => (
                        <div
                          key={message.id}
                          className={`${
                            message.sender_id === user?.id
                              ? 'ml-auto bg-blue-100'
                              : message.is_admin_message
                              ? 'bg-purple-100'
                              : 'bg-gray-100'
                          } rounded-lg p-3 max-w-[80%]`}
                        >
                          <div className="flex items-center gap-2 mb-1">
                            <p className="text-xs font-semibold text-gray-900">
                              {message.is_admin_message ? '🛡️ Support Team' : message.sender.full_name}
                            </p>
                            <p className="text-xs text-gray-500">
                              {new Date(message.created_at).toLocaleTimeString()}
                            </p>
                          </div>
                          <p className="text-sm text-gray-800">{message.message}</p>
                        </div>
                      ))
                    )}
                  </div>

                  {selectedDispute.status !== 'closed' && selectedDispute.status !== 'resolved' && (
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={newMessage}
                        onChange={(e) => setNewMessage(e.target.value)}
                        onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
                        placeholder="Type your message..."
                        className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      />
                      <button
                        onClick={sendMessage}
                        disabled={!newMessage.trim() || sendingMessage}
                        className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
                      >
                        {sendingMessage ? 'Sending...' : 'Send'}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12 text-center">
                <FileText className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                <p className="text-gray-600">Select a dispute to view details and communicate</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
