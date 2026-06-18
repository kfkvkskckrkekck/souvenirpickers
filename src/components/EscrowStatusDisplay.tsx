import { Shield, Clock, CheckCircle, XCircle, AlertCircle } from 'lucide-react';

type EscrowStatus = 'held' | 'released' | 'refunded';

type EscrowStatusDisplayProps = {
  status: EscrowStatus;
  amount: number;
  heldAt?: string;
  releasedAt?: string;
  notes?: string;
  orderStatus?: string;
  deliveredAt?: string;
};

export function EscrowStatusDisplay({
  status,
  amount,
  heldAt,
  releasedAt,
  notes,
  orderStatus,
  deliveredAt,
}: EscrowStatusDisplayProps) {
  const getStatusInfo = () => {
    switch (status) {
      case 'held':
        const canAutoRelease = orderStatus === 'delivered' && deliveredAt;
        const daysRemaining = canAutoRelease
          ? Math.max(0, Math.ceil((14 * 24 * 60 * 60 * 1000 - (Date.now() - new Date(deliveredAt).getTime())) / (1000 * 60 * 60 * 24)))
          : null;

        return {
          icon: Shield,
          color: 'bg-blue-600',
          bgColor: 'bg-blue-50',
          borderColor: 'border-blue-200',
          textColor: 'text-blue-900',
          title: 'Payment Held in Escrow',
          description: canAutoRelease
            ? `Funds will auto-release in ${daysRemaining} day${daysRemaining !== 1 ? 's' : ''} if not disputed`
            : 'Payment is securely held until delivery is confirmed',
        };
      case 'released':
        return {
          icon: CheckCircle,
          color: 'bg-green-600',
          bgColor: 'bg-green-50',
          borderColor: 'border-green-200',
          textColor: 'text-green-900',
          title: 'Payment Released',
          description: 'Funds have been released to the picker',
        };
      case 'refunded':
        return {
          icon: XCircle,
          color: 'bg-red-600',
          bgColor: 'bg-red-50',
          borderColor: 'border-red-200',
          textColor: 'text-red-900',
          title: 'Payment Refunded',
          description: 'Funds have been refunded to your account',
        };
      default:
        return {
          icon: AlertCircle,
          color: 'bg-gray-600',
          bgColor: 'bg-gray-50',
          borderColor: 'border-gray-200',
          textColor: 'text-gray-900',
          title: 'Unknown Status',
          description: 'Payment status is unclear',
        };
    }
  };

  const statusInfo = getStatusInfo();
  const Icon = statusInfo.icon;

  return (
    <div className={`${statusInfo.bgColor} ${statusInfo.borderColor} border rounded-lg p-4`}>
      <div className="flex items-start gap-3">
        <div className={`${statusInfo.color} rounded-full p-2 flex-shrink-0`}>
          <Icon className="w-5 h-5 text-white" />
        </div>
        <div className="flex-1">
          <div className="flex items-center justify-between mb-1">
            <h4 className={`font-semibold ${statusInfo.textColor}`}>
              {statusInfo.title}
            </h4>
            <span className={`font-bold ${statusInfo.textColor}`}>
              ${amount.toFixed(2)}
            </span>
          </div>
          <p className="text-sm text-gray-700 mb-2">{statusInfo.description}</p>

          {status === 'held' && orderStatus === 'delivered' && (
            <div className="flex items-center gap-2 mt-3 p-2 bg-white rounded border border-blue-200">
              <Clock className="w-4 h-4 text-blue-600" />
              <p className="text-xs text-gray-700">
                Have an issue? You can dispute this order within 14 days of delivery
              </p>
            </div>
          )}

          {notes && (
            <div className="mt-2 text-xs text-gray-600 italic">
              Note: {notes}
            </div>
          )}

          <div className="mt-2 flex gap-4 text-xs text-gray-600">
            {heldAt && (
              <div>
                <span className="font-medium">Held:</span>{' '}
                {new Date(heldAt).toLocaleDateString()}
              </div>
            )}
            {releasedAt && (
              <div>
                <span className="font-medium">Released:</span>{' '}
                {new Date(releasedAt).toLocaleDateString()}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
