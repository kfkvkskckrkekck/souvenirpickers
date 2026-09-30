import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Shield, AlertTriangle, Flag, Upload, CheckCircle, Clock, XCircle } from 'lucide-react';

interface ContentReport {
  id: string;
  content_type: string;
  content_id: string;
  report_category: string;
  description: string;
  status: string;
  action_taken: string | null;
  reviewed_at: string | null;
  created_at: string;
}

interface Profile {
  user_type: 'picker' | 'collector';
}

export default function SafetyReportingView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [reports, setReports] = useState<ContentReport[]>([]);
  const [showReportModal, setShowReportModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [userType, setUserType] = useState<'picker' | 'collector'>('collector');

  const getDefaultCategory = () => {
    return 'spam';
  };

  const [newReport, setNewReport] = useState({
    content_type: 'listing',
    content_id: '',
    report_category: 'spam',
    description: ''
  });

  useEffect(() => {
    loadUserType();
    loadReports();
  }, [user]);

  const loadUserType = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_type')
        .eq('id', user.id)
        .single();

      if (error) throw error;
      if (data) {
        setUserType(data.user_type);
      }
    } catch (error) {
      console.error('Error loading user type:', error);
    }
  };

  const loadReports = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('content_reports')
        .select('*')
        .eq('reporter_id', user?.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setReports(data || []);
    } catch (error) {
      console.error('Error loading reports:', error);
    } finally {
      setLoading(false);
    }
  };

  const submitReport = async () => {
    if (!newReport.content_id || !newReport.description.trim()) {
      alert('Please fill in all required fields');
      return;
    }

    if (!user?.id) {
      alert('You must be logged in to submit a report');
      return;
    }

    try {
      setSubmitting(true);

      const reportData = {
        reporter_id: user.id,
        content_type: newReport.content_type,
        content_id: newReport.content_id.trim(),
        report_category: newReport.report_category,
        description: newReport.description.trim()
      };

      console.log('Submitting report:', reportData);

      const { data, error } = await supabase
        .from('content_reports')
        .insert(reportData)
        .select();

      if (error) {
        console.error('Supabase error:', error);
        throw error;
      }

      console.log('Report submitted successfully:', data);
      alert('Report submitted successfully. Our team will review it shortly.');
      setShowReportModal(false);
      setNewReport({
        content_type: 'listing',
        content_id: '',
        report_category: getDefaultCategory(),
        description: ''
      });
      loadReports();
    } catch (error: any) {
      console.error('Error submitting report:', error);
      alert(`Failed to submit report: ${error.message || 'Unknown error'}`);
    } finally {
      setSubmitting(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const badges: Record<string, any> = {
      pending: { icon: Clock, color: 'bg-yellow-100 text-yellow-800', label: 'Pending Review' },
      reviewing: { icon: AlertTriangle, color: 'bg-blue-100 text-blue-800', label: 'Under Review' },
      action_taken: { icon: CheckCircle, color: 'bg-green-100 text-green-800', label: 'Action Taken' },
      dismissed: { icon: XCircle, color: 'bg-gray-100 text-gray-800', label: 'Dismissed' },
      escalated: { icon: Flag, color: 'bg-red-100 text-red-800', label: 'Escalated' }
    };

    const badge = badges[status] || badges.pending;
    const Icon = badge.icon;

    return (
      <div className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium ${badge.color}`}>
        <Icon className="w-4 h-4" />
        {badge.label}
      </div>
    );
  };

  const getCategoryLabel = (category: string) => {
    const labels: Record<string, string> = {
      spam: 'Spam',
      fraud: 'Fraud/Scam',
      inappropriate: 'Inappropriate Content',
      counterfeit: 'Counterfeit Product',
      harassment: 'Harassment',
      copyright: 'Copyright Violation',
      dangerous: 'Dangerous/Illegal',
      not_as_described: 'Item Not as Described',
      fake_listing: 'Fake/Misleading Listing',
      no_delivery: 'Never Delivered',
      damaged_item: 'Damaged Item',
      overcharged: 'Overcharged',
      non_payment: 'Non-Payment',
      unreasonable_demands: 'Unreasonable Demands',
      abusive_behavior: 'Abusive Behavior',
      false_claims: 'False Claims/Dispute',
      other: 'Other'
    };
    return labels[category] || category;
  };

  const getContentTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      listing: 'Listing',
      review: 'Review',
      profile: 'User Profile',
      message: 'Message',
      story: 'Story',
      live_stream: 'Live Stream'
    };
    return labels[type] || type;
  };

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center py-12">
          <Clock className="w-8 h-8 animate-spin text-blue-600" />
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
          <Shield className="w-8 h-8 text-blue-600" />
          Safety & Reporting
        </h1>
        <p className="text-gray-600">Report violations and help keep our community safe</p>
      </div>

      <div className="mb-8 bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl p-6 border-2 border-blue-200">
        <div className="flex items-start gap-4">
          <div className="bg-blue-600 p-3 rounded-lg flex-shrink-0">
            <Shield className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">Community Safety</h3>
            <p className="text-gray-700 mb-3">
              We take safety seriously. Help us maintain a trustworthy marketplace by reporting violations.
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <p className="text-sm font-semibold text-gray-900 mb-1">What to Report</p>
                <p className="text-xs text-gray-600">
                  {userType === 'collector'
                    ? 'Fake listings, fraud, counterfeit items, spam, harassment, or misleading content'
                    : 'Non-payment, false claims, abusive collectors, harassment, or unreasonable demands'}
                </p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <p className="text-sm font-semibold text-gray-900 mb-1">Review Process</p>
                <p className="text-xs text-gray-600">Our team reviews reports within 24-48 hours and takes appropriate action</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <p className="text-sm font-semibold text-gray-900 mb-1">Confidential</p>
                <p className="text-xs text-gray-600">Your identity is kept confidential when reporting violations</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <p className="text-sm font-semibold text-gray-900 mb-1">False Reports</p>
                <p className="text-xs text-gray-600">Submitting false reports may result in account restrictions</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {showReportModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Flag className="w-6 h-6 text-red-600" />
              Submit a Report
            </h3>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">What are you reporting? *</label>
                <select
                  value={newReport.content_type}
                  onChange={(e) => setNewReport({ ...newReport, content_type: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="listing">A Listing</option>
                  <option value="review">A Review</option>
                  <option value="profile">A User Profile</option>
                  <option value="message">A Message</option>
                  <option value="story">A Story</option>
                  <option value="live_stream">A Live Stream</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Content ID * <span className="text-xs text-gray-500">(Copy from URL or details page)</span>
                </label>
                <input
                  type="text"
                  value={newReport.content_id}
                  onChange={(e) => setNewReport({ ...newReport, content_id: e.target.value })}
                  placeholder="e.g., 123e4567-e89b-12d3-a456-426614174000"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Report Category *</label>
                <select
                  value={newReport.report_category}
                  onChange={(e) => setNewReport({ ...newReport, report_category: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  {userType === 'collector' ? (
                    <>
                      <optgroup label="Common Issues">
                        <option value="fraud">Fraud/Scam - Dishonest behavior or fake listings</option>
                        <option value="fake_content">Fake/Misleading Content - Counterfeit or misrepresented items</option>
                        <option value="spam">Spam - Unwanted or repetitive content</option>
                      </optgroup>
                      <optgroup label="Behavioral Issues">
                        <option value="harassment">Harassment - Abusive or threatening behavior</option>
                        <option value="inappropriate">Inappropriate Content - Offensive or explicit material</option>
                      </optgroup>
                      <optgroup label="Other">
                        <option value="other">Other - Something else not listed above</option>
                      </optgroup>
                    </>
                  ) : (
                    <>
                      <optgroup label="Payment & Transaction Issues">
                        <option value="fraud">Fraud/Scam - Non-payment or payment disputes</option>
                        <option value="fake_content">False Claims - Unreasonable demands or fake complaints</option>
                      </optgroup>
                      <optgroup label="Behavioral Issues">
                        <option value="harassment">Harassment - Abusive or threatening behavior</option>
                        <option value="inappropriate">Inappropriate Content - Offensive messages or requests</option>
                        <option value="spam">Spam - Excessive or irrelevant messages</option>
                      </optgroup>
                      <optgroup label="Other">
                        <option value="other">Other - Something else not listed above</option>
                      </optgroup>
                    </>
                  )}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Description * <span className="text-xs text-gray-500">(Be specific and detailed)</span>
                </label>
                <textarea
                  value={newReport.description}
                  onChange={(e) => setNewReport({ ...newReport, description: e.target.value })}
                  rows={5}
                  placeholder="Describe what you're reporting and why it violates our policies..."
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <p className="text-sm text-yellow-800">
                  <strong>Important:</strong> False or malicious reports may result in restrictions on your account.
                  Only report genuine violations of our community guidelines.
                </p>
              </div>
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={submitReport}
                disabled={submitting}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium disabled:opacity-50"
              >
                {submitting ? 'Submitting...' : 'Submit Report'}
              </button>
              <button
                onClick={() => {
                  setShowReportModal(false);
                  setNewReport({
                    content_type: 'listing',
                    content_id: '',
                    report_category: getDefaultCategory(),
                    description: ''
                  });
                }}
                className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {reports.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12 text-center">
          <CheckCircle className="w-16 h-16 text-green-400 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 mb-3">No Reports Submitted</h3>
          <p className="text-gray-600 mb-6">
            You haven't submitted any safety reports yet. If you encounter content that violates our policies, please report it.
          </p>
          <button
            onClick={() => {
              setNewReport({
                content_type: 'listing',
                content_id: '',
                report_category: getDefaultCategory(),
                description: ''
              });
              setShowReportModal(true);
            }}
            className="px-6 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium inline-flex items-center gap-2"
          >
            <Flag className="w-5 h-5" />
            Submit a Report
          </button>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4">Your Reports ({reports.length})</h3>
          <div className="space-y-4">
            {reports.map(report => (
              <div key={report.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-semibold text-gray-900">{getContentTypeLabel(report.content_type)}</span>
                      <span className="text-gray-400">•</span>
                      <span className="text-sm text-gray-600">{getCategoryLabel(report.report_category)}</span>
                    </div>
                    <p className="text-sm text-gray-600">
                      Submitted {new Date(report.created_at).toLocaleDateString()}
                    </p>
                  </div>
                  {getStatusBadge(report.status)}
                </div>

                <div className="bg-gray-50 rounded-lg p-3 mb-3">
                  <p className="text-sm text-gray-700">{report.description}</p>
                </div>

                {report.action_taken && (
                  <div className="bg-green-50 border border-green-200 rounded-lg p-3">
                    <p className="text-sm font-semibold text-green-900 mb-1">Action Taken:</p>
                    <p className="text-sm text-green-800">{report.action_taken}</p>
                    {report.reviewed_at && (
                      <p className="text-xs text-green-700 mt-2">
                        Reviewed on {new Date(report.reviewed_at).toLocaleDateString()}
                      </p>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
