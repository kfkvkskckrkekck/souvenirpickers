// Browser Push Notifications for real-time alerts

export async function requestNotificationPermission(): Promise<boolean> {
  if (!('Notification' in window)) {
    console.log('This browser does not support notifications');
    return false;
  }

  if (Notification.permission === 'granted') {
    return true;
  }

  if (Notification.permission !== 'denied') {
    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }

  return false;
}

export function isNotificationPermissionGranted(): boolean {
  return 'Notification' in window && Notification.permission === 'granted';
}

interface NotificationOptions {
  title: string;
  body: string;
  icon?: string;
  tag?: string;
  data?: any;
  requireInteraction?: boolean;
  onClick?: () => void;
}

export function showBrowserNotification(options: NotificationOptions): void {
  if (!isNotificationPermissionGranted()) {
    console.log('Notification permission not granted');
    return;
  }

  try {
    const notification = new Notification(options.title, {
      body: options.body,
      icon: options.icon || '/favicon.ico',
      tag: options.tag,
      data: options.data,
      requireInteraction: options.requireInteraction || false,
      badge: '/favicon.ico'
    });

    if (options.onClick) {
      notification.onclick = () => {
        window.focus();
        options.onClick?.();
        notification.close();
      };
    }

    // Auto-close after 10 seconds if not requiring interaction
    if (!options.requireInteraction) {
      setTimeout(() => notification.close(), 10000);
    }
  } catch (error) {
    console.error('Error showing browser notification:', error);
  }
}

export function showMessageNotification(
  senderName: string,
  messagePreview: string,
  conversationId: string,
  onClickCallback?: () => void
): void {
  showBrowserNotification({
    title: `New message from ${senderName}`,
    body: messagePreview,
    tag: `message-${conversationId}`,
    icon: '/favicon.ico',
    requireInteraction: false,
    data: { type: 'message', conversationId },
    onClick: () => {
      if (onClickCallback) {
        onClickCallback();
      }
    }
  });
}
