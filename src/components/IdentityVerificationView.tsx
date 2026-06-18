import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Shield, Upload, CheckCircle, XCircle, Clock, AlertTriangle, FileText, Camera } from 'lucide-react';

interface Verification {
  id: string;
  verification_type: string;
  document_url: string;
  status: string;
  rejection_reason: string | null;
  created_at: string;
  verified_at: string | null;
}

export default function IdentityVerificationView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [verifications, setVerifications] = useState<Verification[]>([]);
  const [uploading, setUploading] = useState(false);
  const [selectedType, setSelectedType] = useState('id_card');
  const [file, setFile] = useState<File | null>(null);
  const [isDragging, setIsDragging] = useState(false);

  useEffect(() => {
    loadVerifications();
  }, [user]);

  const loadVerifications = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('identity_verifications')
        .select('*')
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setVerifications(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const validateAndSetFile = (selectedFile: File) => {
    // Validate file type
    const validTypes = ['image/jpeg', 'image/jpg', 'image/png'];
    if (!validTypes.includes(selectedFile.type)) {
      alert('Please select a valid image file (PNG or JPG)');
      return false;
    }

    // Validate file size (10MB max)
    const maxSize = 10 * 1024 * 1024; // 10MB in bytes
    if (selectedFile.size > maxSize) {
      alert('File size must be less than 10MB');
      return false;
    }

    setFile(selectedFile);
    return true;
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      validateAndSetFile(e.target.files[0]);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      validateAndSetFile(e.dataTransfer.files[0]);
    }
  };

  const uploadVerification = async () => {
    if (!file) {
      alert('Please select a file');
      return;
    }

    try {
      setUploading(true);

      const fileExt = file.name.split('.').pop();
      const fileName = `${user?.id}-${selectedType}-${Date.now()}.${fileExt}`;
      const filePath = `verifications/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('media')
        .upload(filePath, file, {
          cacheControl: '3600',
          upsert: false
        });

      if (uploadError) {
        console.error('Upload error:', uploadError);
        throw new Error(`Upload failed: ${uploadError.message}`);
      }

      const { data: { publicUrl } } = supabase.storage
        .from('media')
        .getPublicUrl(filePath);

      const { error: insertError } = await supabase
        .from('identity_verifications')
        .insert({
          user_id: user?.id,
          verification_type: selectedType,
          document_url: publicUrl,
          status: 'pending'
        });

      if (insertError) {
        console.error('Insert error:', insertError);
        throw new Error(`Database error: ${insertError.message}`);
      }

      alert('Verification document uploaded successfully! We will review it shortly.');
      setFile(null);
      const fileInput = document.getElementById('file-upload') as HTMLInputElement;
      if (fileInput) fileInput.value = '';
      loadVerifications();
    } catch (error: any) {
      console.error('Verification upload error:', error);
      alert(error.message || 'Failed to upload verification document. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'approved':
        return (
          <div className="flex items-center gap-1 text-green-600 bg-green-50 px-2 py-1 rounded-full text-sm font-medium">
            <CheckCircle className="w-4 h-4" />
            Approved
          </div>
        );
      case 'pending':
        return (
          <div className="flex items-center gap-1 text-yellow-600 bg-yellow-50 px-2 py-1 rounded-full text-sm font-medium">
            <Clock className="w-4 h-4" />
            Pending Review
          </div>
        );
      case 'rejected':
        return (
          <div className="flex items-center gap-1 text-red-600 bg-red-50 px-2 py-1 rounded-full text-sm font-medium">
            <XCircle className="w-4 h-4" />
            Rejected
          </div>
        );
      default:
        return null;
    }
  };

  const getTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      id_card: 'National ID Card',
      passport: 'Passport',
      drivers_license: 'Driver\'s License',
      utility_bill: 'Utility Bill',
      selfie: 'Selfie with ID'
    };
    return labels[type] || type;
  };

  const isVerified = verifications.some(v => v.status === 'approved');
  const pendingVerification = verifications.find(v => v.status === 'pending');

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
          <Shield className="w-8 h-8 text-blue-600" />
          Identity Verification
        </h1>
        <p className="text-gray-600">Verify your identity to build trust and unlock premium features</p>
      </div>

      {isVerified && (
        <div className="mb-8 bg-green-50 border-2 border-green-200 rounded-xl p-6">
          <div className="flex items-start gap-4">
            <CheckCircle className="w-8 h-8 text-green-600 flex-shrink-0" />
            <div>
              <h3 className="text-lg font-bold text-green-900 mb-2">Identity Verified</h3>
              <p className="text-green-800 mb-3">
                Your identity has been successfully verified. You now have access to all platform features and enhanced trust badge.
              </p>
              <div className="flex items-center gap-2">
                <Shield className="w-5 h-5 text-green-600" />
                <span className="font-semibold text-green-900">Verified User</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {pendingVerification && !isVerified && (
        <div className="mb-8 bg-yellow-50 border-2 border-yellow-200 rounded-xl p-6">
          <div className="flex items-start gap-4">
            <Clock className="w-8 h-8 text-yellow-600 flex-shrink-0" />
            <div>
              <h3 className="text-lg font-bold text-yellow-900 mb-2">Verification Pending</h3>
              <p className="text-yellow-800">
                We're currently reviewing your verification documents. This typically takes 24-48 hours. You'll receive a notification once the review is complete.
              </p>
            </div>
          </div>
        </div>
      )}

      {!isVerified && !pendingVerification && (
        <div className="mb-8 bg-blue-50 border-2 border-blue-200 rounded-xl p-6">
          <div className="flex items-start gap-4">
            <AlertTriangle className="w-8 h-8 text-blue-600 flex-shrink-0" />
            <div className="flex-1">
              <h3 className="text-lg font-bold text-blue-900 mb-2">Why Verify Your Identity?</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
                <div className="bg-white rounded-lg p-3 border border-blue-200">
                  <h4 className="font-semibold text-blue-900 mb-1">Build Trust</h4>
                  <p className="text-sm text-blue-800">Get a verified badge that shows users you're legitimate</p>
                </div>
                <div className="bg-white rounded-lg p-3 border border-blue-200">
                  <h4 className="font-semibold text-blue-900 mb-1">Higher Rankings</h4>
                  <p className="text-sm text-blue-800">Verified users appear higher in search results</p>
                </div>
                <div className="bg-white rounded-lg p-3 border border-blue-200">
                  <h4 className="font-semibold text-blue-900 mb-1">Increased Limits</h4>
                  <p className="text-sm text-blue-800">Access higher transaction limits and features</p>
                </div>
                <div className="bg-white rounded-lg p-3 border border-blue-200">
                  <h4 className="font-semibold text-blue-900 mb-1">Better Trust Score</h4>
                  <p className="text-sm text-blue-800">+25 points to your platform trust score</p>
                </div>
              </div>

              <div className="bg-white rounded-lg p-4 border border-blue-200">
                <h4 className="font-semibold text-blue-900 mb-2">Required Documents</h4>
                <ul className="space-y-2 text-sm text-blue-800">
                  <li className="flex items-center gap-2">
                    <FileText className="w-4 h-4" />
                    Government-issued photo ID (Passport, National ID, or Driver's License)
                  </li>
                  <li className="flex items-center gap-2">
                    <Camera className="w-4 h-4" />
                    Clear, color photo of the document (all corners visible)
                  </li>
                  <li className="flex items-center gap-2">
                    <Shield className="w-4 h-4" />
                    All information must be clearly readable
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      )}

      {!isVerified && !pendingVerification && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
          <h3 className="text-xl font-bold text-gray-900 mb-4">Upload Verification Document</h3>

          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Document Type</label>
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="id_card">National ID Card</option>
              <option value="passport">Passport</option>
              <option value="drivers_license">Driver's License</option>
              <option value="utility_bill">Utility Bill (for address verification)</option>
              <option value="selfie">Selfie with ID</option>
            </select>
          </div>

          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Document Image</label>
            <div
              className={`border-2 border-dashed rounded-lg p-8 text-center transition-all ${
                isDragging
                  ? 'border-blue-500 bg-blue-50'
                  : file
                    ? 'border-green-500 bg-green-50'
                    : 'border-gray-300 hover:border-blue-400 hover:bg-gray-50'
              }`}
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
            >
              <input
                type="file"
                accept="image/png,image/jpeg,image/jpg"
                onChange={handleFileChange}
                className="hidden"
                id="file-upload"
              />
              <label htmlFor="file-upload" className="cursor-pointer block">
                <Upload className={`w-12 h-12 mx-auto mb-3 ${file ? 'text-green-600' : 'text-gray-400'}`} />
                {file ? (
                  <>
                    <p className="text-sm font-semibold text-green-900 mb-1">{file.name}</p>
                    <p className="text-xs text-green-700 mb-2">
                      {(file.size / 1024 / 1024).toFixed(2)} MB
                    </p>
                    <p className="text-xs text-gray-600">Click to choose a different file</p>
                  </>
                ) : (
                  <>
                    <p className="text-sm text-gray-700 font-medium mb-1">
                      Click to upload or drag and drop
                    </p>
                    <p className="text-xs text-gray-500">PNG or JPG up to 10MB</p>
                  </>
                )}
              </label>
            </div>
          </div>

          <button
            onClick={uploadVerification}
            disabled={!file || uploading}
            className="w-full px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {uploading ? (
              <>
                <Clock className="w-5 h-5 animate-spin" />
                Uploading...
              </>
            ) : (
              <>
                <Upload className="w-5 h-5" />
                Submit for Verification
              </>
            )}
          </button>

          <p className="text-xs text-gray-500 mt-3 text-center">
            Your documents are encrypted and handled securely. We never share your personal information.
          </p>
        </div>
      )}

      {verifications.length > 0 && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4">Verification History</h3>
          <div className="space-y-4">
            {verifications.map(verification => (
              <div key={verification.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <p className="font-semibold text-gray-900">{getTypeLabel(verification.verification_type)}</p>
                    <p className="text-sm text-gray-600">
                      Submitted {new Date(verification.created_at).toLocaleDateString()}
                    </p>
                  </div>
                  {getStatusBadge(verification.status)}
                </div>
                {verification.status === 'rejected' && verification.rejection_reason && (
                  <div className="mt-3 bg-red-50 border border-red-200 rounded p-3">
                    <p className="text-sm font-medium text-red-900 mb-1">Rejection Reason:</p>
                    <p className="text-sm text-red-800">{verification.rejection_reason}</p>
                  </div>
                )}
                {verification.verified_at && (
                  <p className="text-sm text-green-600 mt-2">
                    Verified on {new Date(verification.verified_at).toLocaleDateString()}
                  </p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
