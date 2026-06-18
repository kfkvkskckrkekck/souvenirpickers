import { useState, useEffect } from 'react';
import { Shield, ShieldAlert, ShieldCheck, Clock } from 'lucide-react';
import { supabase } from '../lib/supabase';

type VerificationStatus = 'pending' | 'processing' | 'verified' | 'suspicious' | 'rejected';

interface VerificationBadgeProps {
  storagePath: string;
  showDetails?: boolean;
}

interface VerificationData {
  status: VerificationStatus;
  confidence_score: number | null;
  verified_at: string | null;
}

export function VerificationBadge({ storagePath, showDetails = false }: VerificationBadgeProps) {
  const [verification, setVerification] = useState<VerificationData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadVerificationStatus();
  }, [storagePath]);

  const loadVerificationStatus = async () => {
    try {
      const { data, error } = await supabase.rpc('get_media_verification_status', {
        p_storage_path: storagePath,
      });

      if (error) throw error;

      if (data && data.length > 0) {
        setVerification(data[0]);
      }
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  if (loading || !verification) {
    return null;
  }

  const getStatusConfig = (status: VerificationStatus) => {
    switch (status) {
      case 'verified':
        return {
          icon: ShieldCheck,
          color: 'text-green-600',
          bgColor: 'bg-green-50',
          borderColor: 'border-green-200',
          label: 'AI Verified',
          description: 'This media has been verified as authentic',
        };
      case 'suspicious':
        return {
          icon: ShieldAlert,
          color: 'text-yellow-600',
          bgColor: 'bg-yellow-50',
          borderColor: 'border-yellow-200',
          label: 'Under Review',
          description: 'This media is being reviewed by our team',
        };
      case 'rejected':
        return {
          icon: ShieldAlert,
          color: 'text-red-600',
          bgColor: 'bg-red-50',
          borderColor: 'border-red-200',
          label: 'Verification Failed',
          description: 'This media could not be verified',
        };
      case 'processing':
        return {
          icon: Clock,
          color: 'text-blue-600',
          bgColor: 'bg-blue-50',
          borderColor: 'border-blue-200',
          label: 'Verifying',
          description: 'AI verification in progress',
        };
      case 'pending':
        return {
          icon: Clock,
          color: 'text-gray-600',
          bgColor: 'bg-gray-50',
          borderColor: 'border-gray-200',
          label: 'Pending',
          description: 'Verification pending',
        };
    }
  };

  const config = getStatusConfig(verification.status);
  const Icon = config.icon;

  if (!showDetails) {
    return (
      <div
        className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium ${config.bgColor} ${config.color} border ${config.borderColor}`}
        title={config.description}
      >
        <Icon className="w-3.5 h-3.5" />
        <span>{config.label}</span>
        {verification.confidence_score && verification.status === 'verified' && (
          <span className="text-xs opacity-75">
            ({Math.round(verification.confidence_score)}%)
          </span>
        )}
      </div>
    );
  }

  return (
    <div className={`p-3 rounded-lg border ${config.borderColor} ${config.bgColor}`}>
      <div className="flex items-start gap-3">
        <div className={`p-2 rounded-full ${config.bgColor}`}>
          <Icon className={`w-5 h-5 ${config.color}`} />
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h4 className={`font-semibold ${config.color}`}>{config.label}</h4>
            {verification.confidence_score && (
              <span className="text-xs text-gray-500">
                Confidence: {Math.round(verification.confidence_score)}%
              </span>
            )}
          </div>
          <p className="text-sm text-gray-600 mt-1">{config.description}</p>
          {verification.verified_at && (
            <p className="text-xs text-gray-500 mt-1">
              Verified {new Date(verification.verified_at).toLocaleDateString()}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
