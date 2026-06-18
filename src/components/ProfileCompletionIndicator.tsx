import { CheckCircle } from 'lucide-react';

interface ProfileCompletionIndicatorProps {
  size?: 'small' | 'medium' | 'large';
}

export function ProfileCompletionIndicator({ size = 'small' }: ProfileCompletionIndicatorProps) {
  const sizeClasses = {
    small: 'w-5 h-5',
    medium: 'w-6 h-6',
    large: 'w-8 h-8'
  };

  const textSizeClasses = {
    small: 'text-xs',
    medium: 'text-sm',
    large: 'text-base'
  };

  return (
    <div className="inline-flex items-center gap-1.5 bg-green-50 text-green-700 px-2.5 py-1 rounded-full border border-green-200">
      <CheckCircle className={`${sizeClasses[size]} fill-green-500 text-white`} />
      <span className={`${textSizeClasses[size]} font-semibold`}>Profile Complete</span>
    </div>
  );
}
