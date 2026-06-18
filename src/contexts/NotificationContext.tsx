import React, { createContext, useContext, useState, useCallback } from 'react';
import { CheckCircle, XCircle, AlertCircle, Info, X } from 'lucide-react';

type NotificationType = 'success' | 'error' | 'warning' | 'info';

interface Notification {
  id: string;
  type: NotificationType;
  message: string;
  duration?: number;
}

interface ConfirmationOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  type?: 'danger' | 'warning' | 'info';
}

interface NotificationContextType {
  showNotification: (type: NotificationType, message: string, duration?: number) => void;
  showConfirmation: (options: ConfirmationOptions) => Promise<boolean>;
}

const NotificationContext = createContext<NotificationContextType | undefined>(undefined);

export const useNotification = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error('useNotification must be used within NotificationProvider');
  }
  return context;
};

export const NotificationProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [confirmation, setConfirmation] = useState<{
    options: ConfirmationOptions;
    resolve: (value: boolean) => void;
  } | null>(null);

  const showNotification = useCallback((type: NotificationType, message: string, duration = 5000) => {
    const id = Math.random().toString(36).substring(7);
    const notification: Notification = { id, type, message, duration };

    console.log('🔔 Showing notification:', { type, message, id });
    setNotifications(prev => [...prev, notification]);

    if (duration > 0) {
      setTimeout(() => {
        console.log('🧹 Removing notification:', id);
        setNotifications(prev => prev.filter(n => n.id !== id));
      }, duration);
    }
  }, []);

  const showConfirmation = useCallback((options: ConfirmationOptions): Promise<boolean> => {
    return new Promise((resolve) => {
      setConfirmation({ options, resolve });
    });
  }, []);

  const handleConfirm = (value: boolean) => {
    if (confirmation) {
      confirmation.resolve(value);
      setConfirmation(null);
    }
  };

  const removeNotification = (id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
  };

  const getIcon = (type: NotificationType) => {
    switch (type) {
      case 'success':
        return <CheckCircle className="w-5 h-5" />;
      case 'error':
        return <XCircle className="w-5 h-5" />;
      case 'warning':
        return <AlertCircle className="w-5 h-5" />;
      case 'info':
        return <Info className="w-5 h-5" />;
    }
  };

  const getColors = (type: NotificationType) => {
    switch (type) {
      case 'success':
        return 'bg-green-50 border-green-200 text-green-800';
      case 'error':
        return 'bg-red-50 border-red-200 text-red-800';
      case 'warning':
        return 'bg-yellow-50 border-yellow-200 text-yellow-800';
      case 'info':
        return 'bg-blue-50 border-blue-200 text-blue-800';
    }
  };

  const getConfirmButtonColor = (type?: 'danger' | 'warning' | 'info') => {
    switch (type) {
      case 'danger':
        return 'bg-red-600 hover:bg-red-700';
      case 'warning':
        return 'bg-yellow-600 hover:bg-yellow-700';
      default:
        return 'bg-blue-600 hover:bg-blue-700';
    }
  };

  return (
    <NotificationContext.Provider value={{ showNotification, showConfirmation }}>
      {children}

      <div className="fixed top-4 right-4 z-[9999] space-y-2 max-w-md pointer-events-none">
        {notifications.map(notification => (
          <div
            key={notification.id}
            className={`flex items-start gap-3 p-4 rounded-lg border shadow-lg animate-slide-in pointer-events-auto ${getColors(notification.type)}`}
          >
            <div className="flex-shrink-0 mt-0.5">
              {getIcon(notification.type)}
            </div>
            <p className="flex-1 text-sm font-medium leading-relaxed">
              {notification.message}
            </p>
            <button
              onClick={() => removeNotification(notification.id)}
              className="flex-shrink-0 hover:opacity-70 transition-opacity"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      {confirmation && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50 animate-fade-in">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full animate-scale-in">
            <div className="p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {confirmation.options.title}
              </h3>
              <p className="text-gray-600 leading-relaxed">
                {confirmation.options.message}
              </p>
            </div>
            <div className="flex gap-3 px-6 pb-6">
              <button
                onClick={() => handleConfirm(false)}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 font-medium hover:bg-gray-50 transition-colors"
              >
                {confirmation.options.cancelText || 'Cancel'}
              </button>
              <button
                onClick={() => handleConfirm(true)}
                className={`flex-1 px-4 py-2 rounded-lg text-white font-medium transition-colors ${getConfirmButtonColor(confirmation.options.type)}`}
              >
                {confirmation.options.confirmText || 'Confirm'}
              </button>
            </div>
          </div>
        </div>
      )}
    </NotificationContext.Provider>
  );
};
