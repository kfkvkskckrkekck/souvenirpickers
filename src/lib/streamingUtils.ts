export interface StreamingConfig {
  provider: 'agora' | 'daily' | 'twilio' | 'custom';
  appId?: string;
  apiKey?: string;
}

export interface StreamToken {
  token: string;
  expiresAt: number;
}

export class StreamingService {
  private config: StreamingConfig;

  constructor(config: StreamingConfig) {
    this.config = config;
  }

  async generateToken(streamId: string, role: 'host' | 'audience'): Promise<StreamToken> {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

    const endpoint = this.getTokenEndpoint();

    const response = await fetch(`${supabaseUrl}/functions/v1/${endpoint}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ streamId, role }),
    });

    if (!response.ok) {
      throw new Error('Failed to generate streaming token');
    }

    const data = await response.json();
    return data;
  }

  private getTokenEndpoint(): string {
    switch (this.config.provider) {
      case 'agora':
        return 'generate-agora-token';
      case 'daily':
        return 'create-daily-room';
      case 'twilio':
        return 'generate-twilio-token';
      default:
        throw new Error('Unsupported streaming provider');
    }
  }

  async validateStream(streamId: string): Promise<boolean> {
    return true;
  }

  async getStreamStats(streamId: string) {
    return {
      viewers: 0,
      duration: 0,
      quality: 'good',
    };
  }
}

export const createStreamingService = (provider: StreamingConfig['provider']): StreamingService => {
  const config: StreamingConfig = {
    provider,
    appId: import.meta.env.VITE_AGORA_APP_ID || import.meta.env.VITE_DAILY_API_KEY,
  };

  return new StreamingService(config);
};

export const StreamingProviders = {
  AGORA: 'agora' as const,
  DAILY: 'daily' as const,
  TWILIO: 'twilio' as const,
  CUSTOM: 'custom' as const,
};

export const getProviderName = (provider: string): string => {
  const names: Record<string, string> = {
    agora: 'Agora',
    daily: 'Daily.co',
    twilio: 'Twilio Video',
    custom: 'Custom WebRTC',
  };
  return names[provider] || 'Unknown';
};

export const estimateCost = (
  provider: string,
  minutesPerMonth: number
): { cost: number; currency: string } => {
  const rates: Record<string, number> = {
    agora: 0.00099,
    daily: 0.002,
    twilio: 0.0015,
  };

  const rate = rates[provider] || 0;
  return {
    cost: minutesPerMonth * rate,
    currency: 'USD',
  };
};

export interface StreamQuality {
  resolution: '480p' | '720p' | '1080p';
  fps: 15 | 24 | 30 | 60;
  bitrate: number;
}

export const getRecommendedQuality = (
  networkSpeed: 'slow' | 'medium' | 'fast'
): StreamQuality => {
  const qualities: Record<string, StreamQuality> = {
    slow: {
      resolution: '480p',
      fps: 15,
      bitrate: 500,
    },
    medium: {
      resolution: '720p',
      fps: 24,
      bitrate: 1500,
    },
    fast: {
      resolution: '1080p',
      fps: 30,
      bitrate: 3000,
    },
  };

  return qualities[networkSpeed] || qualities.medium;
};

export const checkStreamingCapabilities = async (): Promise<{
  hasCamera: boolean;
  hasMicrophone: boolean;
  supportsWebRTC: boolean;
}> => {
  const hasWebRTC = !!(
    navigator.mediaDevices &&
    navigator.mediaDevices.getUserMedia &&
    window.RTCPeerConnection
  );

  let hasCamera = false;
  let hasMicrophone = false;

  if (hasWebRTC) {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      hasCamera = devices.some((device) => device.kind === 'videoinput');
      hasMicrophone = devices.some((device) => device.kind === 'audioinput');
    } catch (error) {
    }
  }

  return {
    hasCamera,
    hasMicrophone,
    supportsWebRTC: hasWebRTC,
  };
};

export const requestMediaPermissions = async (): Promise<{
  video: boolean;
  audio: boolean;
}> => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: true,
      audio: true,
    });

    stream.getTracks().forEach((track) => track.stop());

    return { video: true, audio: true };
  } catch (error) {
    return { video: false, audio: false };
  }
};

export const formatStreamDuration = (seconds: number): string => {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
  return `${minutes}:${secs.toString().padStart(2, '0')}`;
};

export const calculateBandwidthUsage = (
  quality: StreamQuality,
  durationMinutes: number
): number => {
  const bitrateKbps = quality.bitrate;
  const megabytesPerMinute = (bitrateKbps * 60) / 8 / 1024;
  return megabytesPerMinute * durationMinutes;
};
