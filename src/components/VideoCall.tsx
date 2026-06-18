import { useState, useEffect, useRef } from 'react';
import { Video, VideoOff, Mic, MicOff, PhoneOff, Phone, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type VideoCallProps = {
  conversationId: string;
  otherUserId: string;
  otherUserName: string;
  onClose: () => void;
  isIncoming?: boolean;
  callId?: string;
};

export function VideoCall({
  conversationId,
  otherUserId,
  otherUserName,
  onClose,
  isIncoming = false,
  callId: initialCallId
}: VideoCallProps) {
  const { profile } = useAuth();
  const [callId, setCallId] = useState<string | null>(initialCallId || null);
  const [isConnecting, setIsConnecting] = useState(true);
  const [isVideoEnabled, setIsVideoEnabled] = useState(true);
  const [isAudioEnabled, setIsAudioEnabled] = useState(true);
  const [callStatus, setCallStatus] = useState<'connecting' | 'ringing' | 'active' | 'ended'>('connecting');
  const [callDuration, setCallDuration] = useState(0);
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);
  const localStreamRef = useRef<MediaStream | null>(null);
  const callStartTimeRef = useRef<Date | null>(null);
  const durationIntervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (isIncoming && initialCallId) {
      handleIncomingCall();
    } else {
      initiateCall();
    }

    return () => {
      cleanup();
    };
  }, []);

  const cleanup = () => {
    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach(track => track.stop());
    }
    if (durationIntervalRef.current) {
      clearInterval(durationIntervalRef.current);
    }
  };

  const handleIncomingCall = async () => {
    try {
      setCallStatus('ringing');
      await setupLocalStream();
      setIsConnecting(false);
    } catch (error) {
      onClose();
    }
  };

  const initiateCall = async () => {
    if (!profile) return;

    try {
      await setupLocalStream();

      const roomName = `call_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

      const { data: call, error } = await supabase
        .from('video_calls')
        .insert({
          conversation_id: conversationId,
          initiator_id: profile.id,
          receiver_id: otherUserId,
          room_name: roomName,
          status: 'ringing'
        })
        .select()
        .single();

      if (error) throw error;

      setCallId(call.id);
      setCallStatus('ringing');
      setIsConnecting(false);

      subscribeToCallUpdates(call.id);
    } catch (error) {
      onClose();
    }
  };

  const setupLocalStream = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true
      });

      localStreamRef.current = stream;

      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }
    } catch (error) {
      throw error;
    }
  };

  const subscribeToCallUpdates = (callIdToSubscribe: string) => {
    const channel = supabase
      .channel(`video_call_${callIdToSubscribe}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'video_calls',
          filter: `id=eq.${callIdToSubscribe}`
        },
        (payload) => {
          const updatedCall = payload.new;
          if (updatedCall.status === 'active' && callStatus !== 'active') {
            handleCallActive();
          } else if (updatedCall.status === 'ended' || updatedCall.status === 'declined') {
            handleCallEnded();
          }
        }
      )
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  };

  const acceptCall = async () => {
    if (!callId) return;

    try {
      await supabase
        .from('video_calls')
        .update({
          status: 'active',
          started_at: new Date().toISOString()
        })
        .eq('id', callId);

      handleCallActive();
    } catch (error) {
    }
  };

  const handleCallActive = () => {
    setCallStatus('active');
    callStartTimeRef.current = new Date();

    durationIntervalRef.current = setInterval(() => {
      if (callStartTimeRef.current) {
        const duration = Math.floor((Date.now() - callStartTimeRef.current.getTime()) / 1000);
        setCallDuration(duration);
      }
    }, 1000);
  };

  const declineCall = async () => {
    if (!callId) return;

    try {
      await supabase
        .from('video_calls')
        .update({
          status: 'declined',
          ended_at: new Date().toISOString()
        })
        .eq('id', callId);

      onClose();
    } catch (error) {
    }
  };

  const endCall = async () => {
    if (!callId) return;

    try {
      const endTime = new Date().toISOString();
      const duration = callStartTimeRef.current
        ? Math.floor((Date.now() - callStartTimeRef.current.getTime()) / 1000)
        : 0;

      await supabase
        .from('video_calls')
        .update({
          status: 'ended',
          ended_at: endTime,
          duration_seconds: duration
        })
        .eq('id', callId);

      handleCallEnded();
    } catch (error) {
    }
  };

  const handleCallEnded = () => {
    setCallStatus('ended');
    cleanup();
    setTimeout(() => onClose(), 1000);
  };

  const toggleVideo = () => {
    if (localStreamRef.current) {
      const videoTrack = localStreamRef.current.getVideoTracks()[0];
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled;
        setIsVideoEnabled(videoTrack.enabled);
      }
    }
  };

  const toggleAudio = () => {
    if (localStreamRef.current) {
      const audioTrack = localStreamRef.current.getAudioTracks()[0];
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled;
        setIsAudioEnabled(audioTrack.enabled);
      }
    }
  };

  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center">
      <div className="w-full h-full max-w-7xl mx-auto p-4 flex flex-col">
        <div className="flex justify-between items-center mb-4">
          <div className="text-white">
            <h2 className="text-2xl font-bold">{otherUserName}</h2>
            <p className="text-gray-300">
              {callStatus === 'connecting' && 'Connecting...'}
              {callStatus === 'ringing' && (isIncoming ? 'Incoming call...' : 'Ringing...')}
              {callStatus === 'active' && formatDuration(callDuration)}
              {callStatus === 'ended' && 'Call ended'}
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-white hover:text-gray-300 transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="flex-1 grid md:grid-cols-2 gap-4 mb-4">
          <div className="relative bg-gray-900 rounded-2xl overflow-hidden">
            <video
              ref={remoteVideoRef}
              autoPlay
              playsInline
              className="w-full h-full object-cover"
            />
            {callStatus !== 'active' && (
              <div className="absolute inset-0 flex items-center justify-center bg-gray-800">
                <div className="text-center text-white">
                  <div className="w-24 h-24 bg-gradient-to-br from-blue-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4">
                    <span className="text-4xl font-bold">
                      {otherUserName.charAt(0).toUpperCase()}
                    </span>
                  </div>
                  <p className="text-xl">{otherUserName}</p>
                </div>
              </div>
            )}
          </div>

          <div className="relative bg-gray-900 rounded-2xl overflow-hidden">
            <video
              ref={localVideoRef}
              autoPlay
              playsInline
              muted
              className="w-full h-full object-cover"
            />
            {!isVideoEnabled && (
              <div className="absolute inset-0 flex items-center justify-center bg-gray-800">
                <div className="text-center text-white">
                  <div className="w-24 h-24 bg-gradient-to-br from-orange-500 to-orange-600 rounded-full flex items-center justify-center mx-auto mb-4">
                    <span className="text-4xl font-bold">
                      {profile?.full_name?.charAt(0).toUpperCase() || 'Y'}
                    </span>
                  </div>
                  <p className="text-xl">You</p>
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="flex justify-center gap-4">
          {callStatus === 'ringing' && isIncoming ? (
            <>
              <button
                onClick={acceptCall}
                className="bg-green-600 hover:bg-green-700 text-white p-6 rounded-full transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-110"
              >
                <Phone className="w-8 h-8" />
              </button>
              <button
                onClick={declineCall}
                className="bg-red-600 hover:bg-red-700 text-white p-6 rounded-full transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-110"
              >
                <PhoneOff className="w-8 h-8" />
              </button>
            </>
          ) : callStatus === 'active' || callStatus === 'ringing' ? (
            <>
              <button
                onClick={toggleVideo}
                className={`${
                  isVideoEnabled ? 'bg-gray-700 hover:bg-gray-600' : 'bg-red-600 hover:bg-red-700'
                } text-white p-5 rounded-full transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-110`}
              >
                {isVideoEnabled ? <Video className="w-6 h-6" /> : <VideoOff className="w-6 h-6" />}
              </button>
              <button
                onClick={toggleAudio}
                className={`${
                  isAudioEnabled ? 'bg-gray-700 hover:bg-gray-600' : 'bg-red-600 hover:bg-red-700'
                } text-white p-5 rounded-full transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-110`}
              >
                {isAudioEnabled ? <Mic className="w-6 h-6" /> : <MicOff className="w-6 h-6" />}
              </button>
              <button
                onClick={endCall}
                className="bg-red-600 hover:bg-red-700 text-white p-6 rounded-full transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-110"
              >
                <PhoneOff className="w-8 h-8" />
              </button>
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}
