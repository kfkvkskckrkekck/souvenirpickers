import { useState, useEffect } from 'react';
import { LogIn, UserPlus, Globe, Heart, TrendingUp, Star, Package, MapPin, MessageCircle, ShoppingBag, Eye, EyeOff, Gift } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';

export function AuthForm() {
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [userType, setUserType] = useState<'picker' | 'client'>('client');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [isPasswordResetSent, setIsPasswordResetSent] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [useMagicLink, setUseMagicLink] = useState(false);
  const [magicLinkSent, setMagicLinkSent] = useState(false);
  const [showHelpModal, setShowHelpModal] = useState(false);
  const [referralCode, setReferralCode] = useState<string>('');
  const [showGoogleProfileModal, setShowGoogleProfileModal] = useState(false);
  const [googleUserData, setGoogleUserData] = useState<any>(null);
  const { signIn, signUp } = useAuth();

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const refCode = urlParams.get('ref');
    if (refCode) {
      console.log('Referral code detected:', refCode);
      setReferralCode(refCode);
    }

    // Check if user just signed in with Google and needs to complete profile
    const checkGoogleAuth = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('user_type, full_name')
          .eq('id', session.user.id)
          .maybeSingle();

        // If profile exists but missing user_type or full_name, show modal
        if (profile && (!profile.user_type || !profile.full_name)) {
          setGoogleUserData(session.user);
          setFullName(session.user.user_metadata?.full_name || session.user.user_metadata?.name || '');
          setShowGoogleProfileModal(true);
        }
      }
    };

    checkGoogleAuth();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (isSignUp) {
        // Check if email already exists before attempting signup
        console.log('Checking if email exists:', email.trim());

        const checkResponse = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/check-email-exists`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          },
          body: JSON.stringify({
            email: email.trim(),
          }),
        });

        const checkData = await checkResponse.json();
        console.log('Email check response:', checkData);

        if (checkData.exists) {
          // Email already exists - show error and stop
          setError('Email already exists. Use a different email or sign in with this email.');
          setLoading(false);
          return;
        }

        // Email doesn't exist, proceed with signup
        // User will need to confirm their email before logging in
        const signupResult = await signUp(email, password, fullName, userType);

        // Check if email confirmation is required
        if (signupResult && !signupResult.session) {
          // Email confirmation required - show success message
          setError('');
          setLoading(false);
          alert('Account created successfully! Please check your email to confirm your account before signing in.');
          setIsSignUp(false); // Switch to login form
          return;
        }

        console.log('✅ Signup successful! User is now logged in.');

        // If there's a referral code, create the referral relationship
        if (referralCode && signupResult?.user) {
          console.log('Processing referral code:', referralCode);
          try {
            // Find the referrer by their referral code
            const { data: referrer, error: referrerError } = await supabase
              .from('referral_codes')
              .select('user_id')
              .eq('code', referralCode)
              .maybeSingle();

            if (referrerError) {
              console.error('Error finding referrer:', referrerError);
            } else if (referrer) {
              console.log('Found referrer:', referrer.user_id);

              // Create referral relationship (rewards will be created when first order completes)
              const { error: referralError } = await supabase
                .from('referrals')
                .insert({
                  referrer_id: referrer.user_id,
                  referred_id: signupResult.user.id,
                  referral_code: referralCode,
                  status: 'pending' // Will change to 'completed' when first order is done
                });

              if (referralError) {
                console.error('Error creating referral relationship:', referralError);
              } else {
                console.log('✅ Referral relationship created! Rewards will be applied after first order.');
              }
            } else {
              console.log('Referral code not found:', referralCode);
            }
          } catch (err) {
            console.error('Error processing referral:', err);
          }
        }
      } else {
        if (useMagicLink) {
          await handleMagicLinkLogin();
        } else {
          await signIn(email, password);
        }
      }
    } catch (err: any) {
      console.error('🔴 AUTH ERROR:', err);
      console.error('Error details:', {
        message: err.message,
        status: err.status,
        code: err.code,
        name: err.name,
        fullError: err
      });

      let errorMessage = err.message || 'An error occurred';

      // Handle duplicate email during sign up
      if (isSignUp && (
        err.message?.toLowerCase().includes('already') ||
        err.message?.toLowerCase().includes('registered') ||
        err.message?.toLowerCase().includes('exists') ||
        err.code === 'user_already_exists'
      )) {
        errorMessage = 'Email already exists. Use a different email or sign in with this email.';
      } else if (err.status === 400) {
        errorMessage = `${err.message} - Check your email/password format`;
      } else if (err.status === 429) {
        errorMessage = 'Too many attempts. Please wait 60 seconds and try again.';
      } else if (err.message?.includes('Invalid')) {
        errorMessage = 'Invalid email or password. Please check and try again.';
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleMagicLinkLogin = async () => {
    try {
      console.log('Checking if user exists for magic link:', email.trim());

      // First check if email exists
      const checkResponse = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/check-email-exists`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          email: email.trim(),
        }),
      });

      const checkData = await checkResponse.json();
      console.log('Email check response:', checkData);

      if (!checkData.exists) {
        // Email doesn't exist - show error
        throw new Error('No account found with this email. Please sign up first or check your email address.');
      }

      console.log('Sending magic link to:', email.trim());

      // Call custom edge function to send magic link email
      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-magic-link-recovery`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          email: email.trim(),
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to send magic link');
      }

      console.log('✓ Magic link sent successfully');
      setMagicLinkSent(true);

      setTimeout(() => {
        setMagicLinkSent(false);
      }, 15000);
    } catch (err: any) {
      console.error('Magic link error:', err);
      throw err;
    }
  };

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      console.log('Sending password reset email to:', email.trim());

      // Call custom edge function to send password reset email
      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-password-reset-email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          email: email.trim(),
          redirectTo: `${window.location.origin}/reset-password`,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to send reset email');
      }

      console.log('✓ Password reset email sent successfully');
      setIsPasswordResetSent(true);
      setShowForgotPassword(false);
    } catch (err: any) {
      console.error('Password reset error:', err);
      setError(err.message || 'Failed to send reset email. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignIn = async () => {
    try {
      setError('');
      setLoading(true);

      console.log('Starting Google OAuth flow...');
      console.log('Redirect URL:', window.location.origin);

      // Use the current origin so it works on both production and preview environments
      const redirectTo = `${window.location.origin}/`;

      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo,
          queryParams: {
            access_type: 'offline',
            prompt: 'consent',
          },
        },
      });

      if (error) {
        console.error('OAuth initiation error:', error);
        throw error;
      }

      console.log('OAuth flow initiated successfully');
      // The user will be redirected to Google's OAuth page
      // After successful authentication, they'll be redirected back to the app
    } catch (err: any) {
      console.error('Google sign-in error:', err);
      setError(err.message || 'Failed to sign in with Google. Check browser console for details.');
      setLoading(false);
    }
  };

  const handleCompleteGoogleProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (!googleUserData) return;

      // Update profile with user_type and full_name
      const { error: profileError } = await supabase
        .from('profiles')
        .update({
          user_type: userType,
          full_name: fullName,
        })
        .eq('id', googleUserData.id);

      if (profileError) throw profileError;

      // If user is a picker, create picker_profile
      if (userType === 'picker') {
        const { error: pickerError } = await supabase
          .from('picker_profiles')
          .insert({
            user_id: googleUserData.id,
            languages: [],
            location_city: '',
            location_country: '',
          });

        if (pickerError && pickerError.code !== '23505') { // Ignore duplicate key error
          throw pickerError;
        }
      }

      // Reload the page to update the auth context
      window.location.reload();
    } catch (err: any) {
      console.error('Error completing Google profile:', err);
      setError(err.message || 'Failed to complete profile');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-orange-50">
<div className="max-w-7xl mx-auto px-4 py-12">
        <div className="text-center mb-12">
          <h1 className="text-7xl font-black text-gray-900 mb-6 leading-tight tracking-tight">
            Discover Unique Souvenirs
            <br />
            <span className="bg-gradient-to-r from-blue-600 via-blue-500 to-orange-500 bg-clip-text text-transparent drop-shadow-lg">
              from Around the World
            </span>
          </h1>
          <p className="text-2xl text-gray-600 max-w-4xl mx-auto mb-10 leading-relaxed font-semibold">
            Connect with locals worldwide to discover authentic souvenirs or earn money by becoming a picker
          </p>
        </div>

        <div className="mb-16 max-w-6xl mx-auto relative group">
          <div className="absolute -inset-1 bg-gradient-to-r from-blue-600 via-orange-500 to-green-600 rounded-3xl blur-2xl opacity-75 group-hover:opacity-100 animate-pulse transition duration-1000"></div>
          <div className="relative rounded-3xl overflow-hidden shadow-2xl ring-4 ring-white ring-opacity-50">
            <div className="m-6 bg-gradient-to-r from-blue-600/10 via-orange-600/10 to-green-600/10 backdrop-blur-sm rounded-2xl p-6 border-2 border-blue-200">
              <h3 className="text-2xl font-black text-gray-900 mb-2 flex items-center gap-2">
                <Star className="w-6 h-6 text-yellow-500 fill-yellow-500" />
                How It Works
              </h3>
              <p className="text-gray-700 text-lg font-semibold">
                Connect with locals worldwide to bring authentic treasures to your doorstep
              </p>
            </div>
            <div className="w-full aspect-video relative bg-gradient-to-br from-blue-900 to-blue-700 rounded-2xl overflow-hidden">
              <video
                loop
                playsInline
                controls
                controlsList="nodownload"
                preload="auto"
                crossOrigin="anonymous"
                className="w-full h-full object-cover"
                onLoadStart={() => console.log('AuthForm video load started')}
                onLoadedMetadata={() => console.log('AuthForm video metadata loaded')}
                onCanPlay={() => console.log('AuthForm video can play')}
                onError={(e) => {
                  console.error('AuthForm video error:', e.currentTarget.error);
                  const target = e.currentTarget;
                  if (target.parentElement) {
                    target.parentElement.innerHTML = `
                      <div class="flex items-center justify-center h-full text-white text-center p-8">
                        <div>
                          <p class="font-bold mb-2">Demo Video Loading...</p>
                          <p class="text-sm opacity-90">Optimizing for streaming</p>
                        </div>
                      </div>
                    `;
                  }
                }}
              >
                <source src="https://bfqvzxczmvfteqbhgyvx.supabase.co/storage/v1/object/public/media/platform-demo-video.mp4" type="video/mp4" />
                <div className="flex items-center justify-center h-full text-white">
                  Your browser does not support the video tag.
                </div>
              </video>
            </div>

            {/* <div className="mt-6 bg-gradient-to-r from-blue-600/10 via-orange-600/10 to-green-600/10 backdrop-blur-sm rounded-2xl p-6 border-2 border-blue-200">
              <h3 className="text-2xl font-black text-gray-900 mb-2 flex items-center gap-2">
                <Star className="w-6 h-6 text-yellow-500 fill-yellow-500" />
                How It Works
              </h3>
              <p className="text-gray-700 text-lg font-semibold">
                Connect with locals worldwide to bring authentic treasures to your doorstep
              </p>
            </div> */}
          </div>
        </div>

        <div className="max-w-lg mx-auto mb-16">
          <div className="relative">
            <div className="absolute -inset-2 bg-gradient-to-r from-blue-600 via-orange-500 to-green-600 rounded-3xl blur-xl opacity-30 animate-pulse"></div>
            <div className="relative bg-white rounded-3xl shadow-2xl p-8 border-4 border-white">
          {isPasswordResetSent ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-orange-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Check Your Email</h2>
              <p className="text-gray-600 mb-6">
                We've sent a password reset link to <strong>{email}</strong>.
                Click the link in the email to reset your password.
              </p>
              <div className="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-6">
                <p className="text-sm text-orange-800">
                  <strong>Link expires in 1 hour.</strong> Didn't receive it? Check your spam folder.
                </p>
              </div>
              <button
                onClick={() => {
                  setIsPasswordResetSent(false);
                  setEmail('');
                }}
                className="text-blue-600 hover:text-blue-700 font-medium"
              >
                Back to Sign In
              </button>
            </div>
          ) : magicLinkSent ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 19v-8.93a2 2 0 01.89-1.664l7-4.666a2 2 0 012.22 0l7 4.666A2 2 0 0121 10.07V19M3 19a2 2 0 002 2h14a2 2 0 002-2M3 19l6.75-4.5M21 19l-6.75-4.5M3 10l6.75 4.5M21 10l-6.75 4.5m0 0l-1.14.76a2 2 0 01-2.22 0l-1.14-.76" />
                </svg>
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Check Your Email</h2>
              <p className="text-gray-600 mb-6">
                We've sent a magic login link to <strong>{email}</strong>.
                Click the link in the email to sign in instantly - no password needed!
              </p>
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                <p className="text-sm text-blue-800">
                  <strong>Didn't receive the email?</strong> Check your spam folder or try requesting another link.
                </p>
              </div>
              <button
                onClick={() => {
                  setMagicLinkSent(false);
                  setEmail('');
                }}
                className="text-blue-600 hover:text-blue-700 font-medium"
              >
                Back to Sign In
              </button>
            </div>
          ) : (
          <>
          <div className="mb-6">
            <h2 className="text-3xl font-black text-center mb-2 bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 bg-clip-text text-transparent">
              {isSignUp ? '🚀 Start Your Journey' : '👋 Welcome'}
            </h2>
            <p className="text-center text-gray-600 text-base font-semibold mb-4">
              {isSignUp ? 'Create your account and join thousands of users worldwide' : 'Sign in to continue your adventure'}
            </p>
          </div>

          <div className="relative bg-gradient-to-r from-gray-100 via-gray-50 to-gray-100 p-2 rounded-2xl mb-6 shadow-inner">
            <div className="flex gap-2 relative">
              <button
                onClick={() => {
                  setIsSignUp(false);
                  setMagicLinkSent(false);
                  setUseMagicLink(false);
                }}
                className={`flex-1 py-3 px-4 rounded-xl font-black text-base transition-all duration-300 relative overflow-hidden group ${
                  !isSignUp
                    ? 'bg-gradient-to-br from-blue-600 via-blue-500 to-blue-700 text-white shadow-2xl shadow-blue-500/50 scale-105 ring-4 ring-blue-200'
                    : 'bg-transparent text-gray-500 hover:text-gray-900'
                }`}
              >
                {!isSignUp && (
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white to-transparent opacity-20 animate-shimmer"></div>
                )}
                <div className="relative flex items-center justify-center gap-2">
                  <LogIn className={`w-5 h-5 ${!isSignUp ? 'animate-bounce' : ''}`} />
                  <span className="tracking-wide">SIGN IN</span>
                </div>
                {!isSignUp && (
                  <div className="absolute bottom-0 left-0 right-0 h-1.5 bg-gradient-to-r from-yellow-400 via-orange-500 to-yellow-400 rounded-b-xl shadow-lg"></div>
                )}
              </button>
              <button
                onClick={() => {
                  setIsSignUp(true);
                  setMagicLinkSent(false);
                  setUseMagicLink(false);
                }}
                className={`flex-1 py-3 px-4 rounded-xl font-black text-base transition-all duration-300 relative overflow-hidden group ${
                  isSignUp
                    ? 'bg-gradient-to-br from-orange-500 via-orange-600 to-red-600 text-white shadow-2xl shadow-orange-500/50 scale-105 ring-4 ring-orange-200'
                    : 'bg-transparent text-gray-500 hover:text-gray-900'
                }`}
              >
                {isSignUp && (
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white to-transparent opacity-20 animate-shimmer"></div>
                )}
                <div className="relative flex items-center justify-center gap-2">
                  <UserPlus className={`w-5 h-5 ${isSignUp ? 'animate-bounce' : ''}`} />
                  <span className="tracking-wide">SIGN UP</span>
                </div>
                {isSignUp && (
                  <div className="absolute bottom-0 left-0 right-0 h-1.5 bg-gradient-to-r from-yellow-400 via-green-500 to-yellow-400 rounded-b-xl shadow-lg"></div>
                )}
              </button>
            </div>
          </div>

          {referralCode && isSignUp && (
            <div className="mb-4 bg-gradient-to-r from-green-50 to-emerald-50 border-2 border-green-200 rounded-xl p-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0">
                  <Gift className="w-5 h-5 text-white" />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-bold text-green-900">Referral Code Applied!</p>
                  <p className="text-xs text-green-700">
                    Code <span className="font-mono font-bold">{referralCode}</span> - Earn rewards when you complete your first order!
                  </p>
                </div>
              </div>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {isSignUp && (
              <>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Full Name <span className="text-red-600">*</span>
                  </label>
                  <input
                    type="text"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                    autoComplete="off"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    I am a... <span className="text-red-600">*</span>
                  </label>
                  <div className="grid grid-cols-2 gap-2">
                    <button
                      type="button"
                      onClick={() => setUserType('client')}
                      className={`py-2 px-3 rounded-lg border-2 transition-all ${
                        userType === 'client'
                          ? 'border-blue-600 bg-blue-50 text-blue-700'
                          : 'border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      <div className="font-medium text-sm">Collector</div>
                      <div className="text-xs text-gray-500">Find souvenirs</div>
                    </button>
                    <button
                      type="button"
                      onClick={() => setUserType('picker')}
                      className={`py-2 px-3 rounded-lg border-2 transition-all ${
                        userType === 'picker'
                          ? 'border-blue-600 bg-blue-50 text-blue-700'
                          : 'border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      <div className="font-medium text-sm">Picker</div>
                      <div className="text-xs text-gray-500">Collect items</div>
                    </button>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Referral Code (Optional)
                  </label>
                  <input
                    type="text"
                    value={referralCode}
                    onChange={(e) => {
                      const value = e.target.value.trim().toUpperCase();
                      setReferralCode(value);
                    }}
                    placeholder="Enter code (e.g., 9CBUTKH5)"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm font-mono uppercase"
                    autoComplete="off"
                    maxLength={10}
                  />
                  <p className="mt-1 text-xs text-gray-500">
                    Have a referral code? Enter it to get €5 off your first order!
                  </p>
                </div>
              </>
            )}

            <div>
              <label className="block text-sm font-bold text-gray-900 mb-2 flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-gradient-to-r from-blue-600 to-blue-500"></div>
                ✉️ Email <span className="text-red-600">*</span>
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Enter your email"
                className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-100 focus:border-blue-500 transition-all text-sm placeholder:text-gray-400"
                autoComplete="off"
                required
              />
            </div>

            {!isSignUp && !useMagicLink && (
              <div className="text-center mb-4">
                <button
                  type="button"
                  onClick={() => setUseMagicLink(true)}
                  className="text-sm text-blue-600 hover:text-blue-700 font-medium underline underline-offset-2"
                >
                  Or sign in with a magic link instead
                </button>
              </div>
            )}

            {!isSignUp && useMagicLink && (
              <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-4 mb-4">
                <div className="flex items-start gap-3">
                  <div className="text-2xl">✨</div>
                  <div>
                    <h4 className="font-bold text-blue-900 mb-1">Magic Link Sign In</h4>
                    <p className="text-sm text-blue-800 mb-3">
                      We'll send you a link to sign in instantly - no password required!
                    </p>
                    <button
                      type="button"
                      onClick={() => setUseMagicLink(false)}
                      className="text-xs text-blue-600 hover:text-blue-700 font-medium underline"
                    >
                      Use password instead
                    </button>
                  </div>
                </div>
              </div>
            )}

            {(!useMagicLink || isSignUp) && (
              <div>
                <label className="block text-sm font-bold text-gray-900 mb-2 flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full bg-gradient-to-r from-orange-600 to-orange-500"></div>
                  🔒 Password <span className="text-red-600">*</span>
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder={isSignUp ? "Min. 6 characters" : "Enter password"}
                    className="w-full px-4 py-3 pr-12 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-orange-100 focus:border-orange-500 transition-all text-sm placeholder:text-gray-400"
                    autoComplete="off"
                    required={!useMagicLink}
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                    aria-label={showPassword ? "Hide password" : "Show password"}
                  >
                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
              </div>
            )}

            {error && (
              <div className="bg-gradient-to-r from-red-50 via-orange-50 to-red-50 border-2 border-red-300 text-red-700 p-3 rounded-xl text-sm font-bold flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-red-600 animate-pulse"></div>
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-blue-600 via-blue-500 to-blue-600 text-white py-4 rounded-xl font-black text-lg hover:from-blue-700 hover:via-blue-600 hover:to-blue-700 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-xl shadow-blue-500/40 hover:shadow-2xl hover:shadow-blue-500/60 transform hover:scale-[1.02] active:scale-[0.98] relative overflow-hidden group uppercase tracking-wide"
            >
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white to-transparent opacity-0 group-hover:opacity-30 group-hover:animate-shimmer"></div>
              <span className="relative flex items-center justify-center gap-3">
                {loading ? (
                  <>
                    <div className="w-5 h-5 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
                    <span>PROCESSING...</span>
                  </>
                ) : isSignUp ? (
                  <>
                    <UserPlus className="w-6 h-6" />
                    <span>🚀 CREATE ACCOUNT</span>
                  </>
                ) : useMagicLink ? (
                  <>
                    <span className="text-2xl">✨</span>
                    <span>SEND MAGIC LINK</span>
                  </>
                ) : (
                  <>
                    <LogIn className="w-6 h-6" />
                    <span>✨ SIGN IN</span>
                  </>
                )}
              </span>
            </button>

          </form>

          <div className="mt-6">
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t-2 border-gray-200"></div>
              </div>
              <div className="relative flex justify-center text-sm">
                <span className="px-4 bg-white text-gray-500 font-semibold">OR</span>
              </div>
            </div>

            <button
              type="button"
              onClick={handleGoogleSignIn}
              disabled={loading}
              className="mt-6 w-full bg-white border-2 border-gray-300 text-gray-700 py-4 rounded-xl font-bold text-base hover:bg-gray-50 hover:border-gray-400 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl transform hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center gap-3"
            >
              <svg className="w-6 h-6" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              <span>{isSignUp ? 'Sign up with Google' : 'Sign in with Google'}</span>
            </button>
          </div>

          <div className="mt-6 pt-6 border-t-2 border-gray-100">
            <p className="text-gray-500 text-sm font-semibold text-center">
              {isSignUp ? 'Already have an account?' : "Don't have an account?"}
              {' '}
              <button
                type="button"
                onClick={() => setIsSignUp(!isSignUp)}
                className="text-blue-600 hover:text-blue-700 font-bold underline underline-offset-2 hover:underline-offset-4 transition-all"
              >
                {isSignUp ? 'Sign In' : 'Sign Up'}
              </button>
            </p>
            {!isSignUp && (
              <div className="text-center mt-3 space-y-2">
                <p>
                  <button
                    type="button"
                    onClick={() => setShowForgotPassword(true)}
                    className="text-sm text-orange-600 hover:text-orange-700 font-medium underline underline-offset-2 hover:underline-offset-4 transition-all"
                  >
                    Forgot Password?
                  </button>
                </p>
                <p>
                  <button
                    type="button"
                    onClick={() => setShowHelpModal(true)}
                    className="text-xs text-gray-500 hover:text-gray-700 font-medium underline underline-offset-2 hover:underline-offset-4 transition-all"
                  >
                    Can't access your email? Get help
                  </button>
                </p>
              </div>
            )}
          </div>
          </>
          )}
            </div>
          </div>
        </div>

        <div className="text-center mb-12">

          <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto mb-12">
            <div className="group relative overflow-hidden bg-gradient-to-br from-blue-500 via-blue-600 to-blue-700 p-10 rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(59,130,246,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
              <div className="absolute top-0 right-0 w-40 h-40 bg-white opacity-10 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700"></div>
              <div className="absolute bottom-0 left-0 w-32 h-32 bg-white opacity-10 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700"></div>

              <div className="relative z-10">
                <div className="mb-6 transform group-hover:scale-110 group-hover:rotate-6 transition-all duration-500">
                  <div className="bg-white bg-opacity-20 backdrop-blur-sm p-5 rounded-2xl inline-block shadow-xl">
                    <Globe className="w-12 h-12 text-white" />
                  </div>
                </div>
                <h2 className="text-4xl font-black text-white mb-4 transition-all duration-300 tracking-tight drop-shadow-lg">
                  DISCOVER
                </h2>
                <div className="h-1.5 w-24 bg-white rounded-full mb-5 group-hover:w-40 transition-all duration-500 shadow-lg shadow-white/50"></div>
                <p className="text-xl text-blue-50 leading-relaxed mb-6">
                  Browse authentic souvenirs from <span className="font-bold text-white">150+ countries</span> curated by local experts
                </p>
                <div className="flex items-center gap-3 text-white text-sm">
                  <div className="flex items-center gap-2 bg-white bg-opacity-20 px-4 py-2 rounded-full backdrop-blur-sm">
                    <Star className="w-4 h-4 fill-white" />
                    <span className="font-semibold">1000+ Listings</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="group relative overflow-hidden bg-gradient-to-br from-orange-500 via-orange-600 to-red-600 p-10 rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(249,115,22,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
              <div className="absolute top-0 right-0 w-40 h-40 bg-white opacity-10 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700"></div>
              <div className="absolute bottom-0 left-0 w-32 h-32 bg-white opacity-10 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700"></div>

              <div className="relative z-10">
                <div className="mb-6 transform group-hover:scale-110 group-hover:rotate-6 transition-all duration-500">
                  <div className="bg-white bg-opacity-20 backdrop-blur-sm p-5 rounded-2xl inline-block shadow-xl">
                    <Heart className="w-12 h-12 text-white fill-white animate-pulse" />
                  </div>
                </div>
                <h2 className="text-4xl font-black text-white mb-4 transition-all duration-300 tracking-tight drop-shadow-lg">
                  ENJOY
                </h2>
                <div className="h-1.5 w-24 bg-white rounded-full mb-5 group-hover:w-40 transition-all duration-500 shadow-lg shadow-white/50"></div>
                <p className="text-xl text-orange-50 leading-relaxed mb-6">
                  Receive <span className="font-bold text-white">handpicked treasures</span> with personal stories and guaranteed authenticity
                </p>
                <div className="flex items-center gap-3 text-white text-sm">
                  <div className="flex items-center gap-2 bg-white bg-opacity-20 px-4 py-2 rounded-full backdrop-blur-sm">
                    <Package className="w-4 h-4" />
                    <span className="font-semibold">Safe Delivery</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="group relative overflow-hidden bg-gradient-to-br from-green-500 via-green-600 to-emerald-700 p-10 rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(34,197,94,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
              <div className="absolute top-0 right-0 w-40 h-40 bg-yellow-400 opacity-20 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700 animate-pulse"></div>
              <div className="absolute bottom-0 left-0 w-32 h-32 bg-yellow-300 opacity-20 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700 animate-pulse"></div>
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-yellow-400 opacity-10 rounded-full blur-3xl group-hover:opacity-20 transition-opacity duration-700"></div>

              <div className="relative z-10">
                <div className="mb-6 transform group-hover:scale-110 group-hover:rotate-12 transition-all duration-500">
                  <div className="bg-gradient-to-br from-yellow-400 to-yellow-500 p-5 rounded-2xl inline-block shadow-2xl">
                    <TrendingUp className="w-12 h-12 text-green-900 animate-bounce" />
                  </div>
                </div>
                <h2 className="text-3xl font-black mb-4 transition-all duration-300 relative">
                  <span className="inline-block bg-gradient-to-r from-yellow-300 to-yellow-400 text-green-900 px-3 py-1.5 rounded-lg shadow-lg">
                    EARN MONEY
                  </span>
                </h2>
                <div className="h-1.5 w-24 bg-gradient-to-r from-yellow-300 via-yellow-200 to-white rounded-full mb-5 group-hover:w-40 transition-all duration-500 shadow-lg shadow-yellow-300/50"></div>
                <p className="text-xl text-green-50 leading-relaxed mb-6">
                  Turn every trip into <span className="font-black text-yellow-300 text-2xl">PROFIT</span>! Earn <span className="font-bold text-white">$500-$5,000+</span> monthly picking souvenirs while you travel
                </p>
                <div className="flex items-center gap-3 text-white text-sm flex-wrap">
                  <div className="flex items-center gap-2 bg-yellow-400 bg-opacity-90 px-4 py-2 rounded-full backdrop-blur-sm shadow-lg">
                    <span className="font-black text-xl text-green-900">💰💰💰</span>
                    <span className="font-bold text-green-900">Get Paid to Travel</span>
                  </div>
                  <div className="flex items-center gap-2 bg-white bg-opacity-20 px-4 py-2 rounded-full backdrop-blur-sm">
                    <span className="font-bold">No Limits</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-8 max-w-5xl mx-auto mb-12">
            <div className="bg-white p-8 rounded-3xl shadow-lg hover:shadow-2xl transition-all duration-300 border-t-4 border-blue-500">
              <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl flex items-center justify-center mb-6 shadow-lg">
                <MapPin className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Global Network</h3>
              <p className="text-gray-600 text-lg leading-relaxed">
                Access pickers in over 150 countries ready to find the perfect souvenir from regions you can't reach
              </p>
            </div>

            <div className="bg-white p-8 rounded-3xl shadow-lg hover:shadow-2xl transition-all duration-300 border-t-4 border-orange-500">
              <div className="w-16 h-16 bg-gradient-to-br from-orange-500 to-orange-600 rounded-2xl flex items-center justify-center mb-6 shadow-lg">
                <MessageCircle className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Direct Communication</h3>
              <p className="text-gray-600 text-lg leading-relaxed">
                Chat directly with pickers to discuss specific items, negotiate prices, and track your requests
              </p>
            </div>

            <div className="bg-white p-8 rounded-3xl shadow-lg hover:shadow-2xl transition-all duration-300 border-t-4 border-green-500">
              <div className="w-16 h-16 bg-gradient-to-br from-green-500 to-green-600 rounded-2xl flex items-center justify-center mb-6 shadow-lg">
                <Star className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Verified Pickers</h3>
              <p className="text-gray-600 text-lg leading-relaxed">
                Read reviews and ratings from other clients to find trusted pickers with proven track records
              </p>
            </div>
          </div>
        </div>
      </div>

      {showHelpModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-8 relative max-h-[90vh] overflow-y-auto">
            <button
              onClick={() => setShowHelpModal(false)}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>

            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-2">Can't Access Your Email?</h3>
              <p className="text-gray-600">
                If you can't access your email, here are your options to recover your account:
              </p>
            </div>

            <div className="space-y-4">
              <div className="bg-blue-50 border-2 border-blue-300 rounded-xl p-4">
                <h4 className="font-bold text-blue-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">1️⃣</span>
                  Check Your Spam/Junk Folder
                </h4>
                <p className="text-sm text-blue-800">
                  Password reset emails often get filtered. Check your spam, junk, or promotions folder.
                </p>
              </div>

              <div className="bg-green-50 border-2 border-green-300 rounded-xl p-4">
                <h4 className="font-bold text-green-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">2️⃣</span>
                  Use Backup Recovery Options
                </h4>
                <p className="text-sm text-green-800 mb-2">
                  If you previously set up backup recovery options (backup email, phone number), those will be used automatically when you request a password reset.
                </p>
                <p className="text-xs text-green-700 italic">
                  Note: You can set up backup options in Account Recovery Settings (Shield icon) after logging in.
                </p>
              </div>

              <div className="bg-orange-50 border-2 border-orange-300 rounded-xl p-4">
                <h4 className="font-bold text-orange-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">3️⃣</span>
                  Try Magic Link Instead
                </h4>
                <p className="text-sm text-orange-800 mb-3">
                  Magic links are sometimes more reliable than password resets. They provide instant access without needing a password.
                </p>
                <button
                  onClick={() => {
                    setShowHelpModal(false);
                    setUseMagicLink(true);
                  }}
                  className="w-full bg-orange-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-orange-700 transition-colors"
                >
                  Try Magic Link Sign In
                </button>
              </div>

              <div className="bg-red-50 border-2 border-red-300 rounded-xl p-4">
                <h4 className="font-bold text-red-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">4️⃣</span>
                  Contact Support
                </h4>
                <p className="text-sm text-red-800 mb-2">
                  If none of the above work, our support team can help verify your identity and restore access to your account.
                </p>
                <p className="text-xs text-red-700 font-medium">
                  Email: support@souvenirpickers.com
                </p>
              </div>

              <div className="bg-gray-100 border border-gray-300 rounded-xl p-4">
                <h4 className="font-bold text-gray-900 mb-2">Prevention Tips</h4>
                <ul className="text-sm text-gray-700 space-y-1 list-disc list-inside">
                  <li>Always set up backup recovery options after creating your account</li>
                  <li>Keep your email password secure and accessible</li>
                  <li>Add your phone number for SMS recovery</li>
                  <li>Save your password in a secure password manager</li>
                </ul>
              </div>
            </div>

            <button
              onClick={() => setShowHelpModal(false)}
              className="w-full mt-6 bg-gray-200 text-gray-700 py-3 rounded-xl font-medium hover:bg-gray-300 transition-colors"
            >
              Close
            </button>
          </div>
        </div>
      )}

      {showForgotPassword && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 relative">
            <button
              onClick={() => {
                setShowForgotPassword(false);
                setIsPasswordResetSent(false);
                setError('');
              }}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>

            {isPasswordResetSent ? (
              <div className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <h3 className="text-2xl font-bold text-gray-900 mb-3">Check Your Email</h3>
                <p className="text-gray-600 mb-4">
                  If an account exists for <strong>{email}</strong>, you'll receive a password reset link shortly.
                </p>

                <div className="bg-orange-50 border-2 border-orange-300 rounded-lg p-4 text-left mb-4">
                  <p className="text-sm text-orange-900 font-bold mb-2 flex items-center gap-2">
                    <span className="text-lg">📬</span>
                    IMPORTANT: Check Your Spam Folder!
                  </p>
                  <p className="text-sm text-orange-800">
                    Password reset emails often end up in spam/junk folders. Please check there first if you don't see the email in your inbox within 2 minutes.
                  </p>
                </div>

                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left mb-4">
                  <p className="text-sm text-blue-900 font-semibold mb-2">Still didn't receive the email?</p>
                  <ul className="text-sm text-blue-800 space-y-1 list-disc list-inside">
                    <li>Make sure you entered the correct email</li>
                    <li>Wait 60 seconds, then try requesting again (rate limited)</li>
                    <li>Open browser console (F12) to check for any errors</li>
                    <li>Try using the magic link sign in option instead</li>
                  </ul>
                </div>

                <div className="bg-green-50 border border-green-200 rounded-lg p-4 text-left">
                  <p className="text-sm text-green-900 font-semibold mb-2">Alternative Options:</p>
                  <button
                    onClick={() => {
                      setIsPasswordResetSent(false);
                      setShowForgotPassword(false);
                      setUseMagicLink(true);
                    }}
                    className="text-sm text-green-700 hover:text-green-800 font-medium underline"
                  >
                    Try Magic Link Sign In instead →
                  </button>
                </div>
              </div>
            ) : (
              <>
                <h3 className="text-2xl font-bold text-gray-900 mb-2">Reset Password</h3>
                <p className="text-gray-600 mb-6">
                  Enter your email address and we'll send you a link to reset your password.
                </p>

                <form onSubmit={handleForgotPassword} className="space-y-4">
                  <div>
                    <label className="block text-sm font-bold text-gray-900 mb-2">
                      Email Address <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="Enter your email"
                      className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-100 focus:border-blue-500 transition-all text-sm placeholder:text-gray-400"
                      required
                    />
                  </div>

                  {error && (
                    <div className="bg-red-50 border-2 border-red-300 text-red-700 p-3 rounded-xl text-sm font-bold">
                      {error}
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-gradient-to-r from-orange-600 to-orange-500 text-white py-3 rounded-xl font-bold text-base hover:from-orange-700 hover:to-orange-600 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
                  >
                    {loading ? (
                      <span className="flex items-center justify-center gap-2">
                        <div className="w-5 h-5 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
                        Sending...
                      </span>
                    ) : (
                      'Send Reset Link'
                    )}
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      )}

      {showGoogleProfileModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 relative">
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <UserPlus className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-2">Complete Your Profile</h3>
              <p className="text-gray-600">
                Welcome! Please complete your profile to get started.
              </p>
            </div>

            <form onSubmit={handleCompleteGoogleProfile} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Full Name <span className="text-red-600">*</span>
                </label>
                <input
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  I am a... <span className="text-red-600">*</span>
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setUserType('client')}
                    className={`py-2 px-3 rounded-lg border-2 transition-all ${
                      userType === 'client'
                        ? 'border-blue-600 bg-blue-50 text-blue-700'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <div className="font-medium text-sm">Collector</div>
                    <div className="text-xs text-gray-500">Find souvenirs</div>
                  </button>
                  <button
                    type="button"
                    onClick={() => setUserType('picker')}
                    className={`py-2 px-3 rounded-lg border-2 transition-all ${
                      userType === 'picker'
                        ? 'border-blue-600 bg-blue-50 text-blue-700'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <div className="font-medium text-sm">Picker</div>
                    <div className="text-xs text-gray-500">Collect items</div>
                  </button>
                </div>
              </div>

              {error && (
                <div className="bg-red-50 border-2 border-red-300 text-red-700 p-3 rounded-xl text-sm font-bold">
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-gradient-to-r from-blue-600 to-blue-500 text-white py-3 rounded-xl font-bold text-base hover:from-blue-700 hover:to-blue-600 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
              >
                {loading ? (
                  <span className="flex items-center justify-center gap-2">
                    <div className="w-5 h-5 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
                    Completing...
                  </span>
                ) : (
                  'Complete Profile'
                )}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
