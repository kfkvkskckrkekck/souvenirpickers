import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase, Profile } from '../lib/supabase';

type AuthContextType = {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  signUp: (email: string, password: string, fullName: string, userType: 'picker' | 'client') => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
};

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Handle email confirmation and password reset tokens from URL
    const handleAuthRedirect = async () => {
      // Check BOTH hash params (#token_hash) AND query params (?token_hash)
      const hashParams = new URLSearchParams(window.location.hash.substring(1));
      const queryParams = new URLSearchParams(window.location.search);

      // Get values from either hash or query params
      const type = hashParams.get('type') || queryParams.get('type');
      const accessToken = hashParams.get('access_token') || queryParams.get('access_token');
      const refreshToken = hashParams.get('refresh_token') || queryParams.get('refresh_token');
      const pkceToken = hashParams.get('token') || hashParams.get('token_hash') || queryParams.get('token_hash');

      console.log('🔍 Auth redirect detected:', {
        type,
        hasAccessToken: !!accessToken,
        hasRefreshToken: !!refreshToken,
        hasPkceToken: !!pkceToken,
        fullHash: window.location.hash,
        fullSearch: window.location.search
      });

      // Handle PKCE flow (email confirmation with token_hash parameter)
      if (pkceToken && type) {
        try {
          console.log('🔄 Verifying PKCE token...', { type, token: pkceToken.substring(0, 20) + '...' });

          // Verify the OTP token from the email
          const { data, error } = await supabase.auth.verifyOtp({
            token_hash: pkceToken,
            type: type === 'signup' ? 'signup' : (type === 'magiclink' ? 'magiclink' : 'recovery')
          });

          if (error) {
            console.error('❌ PKCE token verification error:', error);
            throw error;
          }

          if (data.session && data.user) {
            console.log('✅ PKCE verification successful! User confirmed:', data.user.id);
            console.log('✅ User email_confirmed_at:', data.user.email_confirmed_at);
            setUser(data.user);

            // For password reset, don't load profile or clean URL yet
            if (type === 'recovery') {
              setLoading(false);
              return;
            }

            // For signup/magiclink, clean URL and load profile
            if (type === 'signup' || type === 'magiclink') {
              console.log('📧 Email confirmed! Loading profile...');
              await loadProfile(data.user.id);
              // Clean URL by removing all query params
              window.history.replaceState({}, document.title, window.location.origin);
              setLoading(false);
              return;
            }
          } else {
            console.error('❌ No session after PKCE verification');
          }
        } catch (err) {
          console.error('❌ PKCE auth redirect error:', err);
        }
      }

      // Handle standard OAuth flow with access_token and refresh_token
      if (accessToken && refreshToken) {
        try {
          console.log('🔄 Exchanging tokens for session...');
          const { data, error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });

          if (error) {
            console.error('❌ Session exchange error:', error);
            throw error;
          }

          if (data.session) {
            console.log('✅ Session established:', data.session.user.id);
            console.log('✅ Email confirmed at:', data.session.user.email_confirmed_at);
            setUser(data.session.user);

            // For password reset, don't load profile or clean URL yet
            if (type === 'recovery') {
              setLoading(false);
              return;
            }

            // For signup/magiclink, clean URL immediately and load profile
            if (type === 'signup' || type === 'magiclink') {
              console.log('📧 Email confirmed! Loading profile...');
              await loadProfile(data.session.user.id);
              window.history.replaceState({}, document.title, window.location.pathname);
              setLoading(false);
              return;
            }

            // For any other auth flow
            await loadProfile(data.session.user.id);
            window.history.replaceState({}, document.title, window.location.pathname);
            setLoading(false);
            return;
          }
        } catch (err) {
          console.error('❌ Auth redirect error:', err);
        }
      }
    };

    handleAuthRedirect();

    // Add timeout protection for session check (10 seconds max)
    const sessionTimeout = setTimeout(() => {
      console.warn('⚠️ Session check timeout - forcing loading to false');
      setLoading(false);
    }, 10000);

    supabase.auth.getSession().then(async ({ data: { session } }) => {
      clearTimeout(sessionTimeout);
      console.log('📋 Session check complete:', session?.user ? `User: ${session.user.id}` : 'No session');

      // Note: we no longer sign out users whose profile isn't found yet —
      // Google OAuth users may not have a profile row immediately after redirect.

      setUser(session?.user ?? null);
      if (session?.user) {
        loadProfile(session.user.id);
      } else {
        setLoading(false);
      }
    }).catch((error) => {
      clearTimeout(sessionTimeout);
      console.error('❌ Session check error:', error);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {

      (async () => {
        setUser(session?.user ?? null);
        if (session?.user) {
          await loadProfile(session.user.id);
        } else {
          setProfile(null);
          setLoading(false);
        }
      })();
    });

    return () => {

      subscription.unsubscribe();
    };
  }, []);

  const loadProfile = async (userId: string, retries = 5) => {
    console.log(`🔍 Loading profile for user: ${userId}, retries left: ${retries}`);

    try {
      // Add timeout protection (5 seconds max per attempt)
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Profile query timeout')), 5000)
      );

      const queryPromise = supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      const { data, error } = await Promise.race([queryPromise, timeoutPromise]) as any;

      if (error) {
        console.error('❌ Profile query error:', error);
        throw error;
      }

      // If profile doesn't exist yet and we have retries left, wait and try again
      if (!data && retries > 0) {
        console.log(`⏳ Profile not found yet, retrying... (${retries} attempts left)`);
        await new Promise(resolve => setTimeout(resolve, 500));
        return loadProfile(userId, retries - 1);
      }

      // If still no profile (e.g. Google OAuth user), create one from auth metadata
      if (!data) {
        const { data: { user: authUser } } = await supabase.auth.getUser();
        if (authUser) {
          const fullName = authUser.user_metadata?.full_name || authUser.user_metadata?.name || authUser.email?.split('@')[0] || 'User';
          const { data: newProfile, error: insertError } = await supabase
            .from('profiles')
            .upsert({
              id: userId,
              full_name: fullName,
              email: authUser.email,
              user_type: 'client',
            }, { onConflict: 'id' })
            .select()
            .maybeSingle();

          if (!insertError && newProfile) {
            console.log('✅ Profile created for OAuth user:', fullName);
            setProfile(newProfile);
            setLoading(false);
            return;
          }
        }
        console.warn('⚠️ Profile not found and could not be created');
      } else {
        console.log('✅ Profile loaded successfully:', data.full_name);
      }

      setProfile(data);
    } catch (error: any) {
      console.error('❌ Failed to load profile:', error.message);
      setProfile(null);
    } finally {
      console.log('🏁 Profile loading complete, setting loading to false');
      setLoading(false);
    }
  };

  const signUp = async (email: string, password: string, fullName: string, userType: 'picker' | 'client') => {
    console.log('🚀 Sign Up Request:', { email, fullName, userType });

    // Sign up with emailRedirectTo to ensure user is logged in immediately
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}`,
        data: {
          full_name: fullName,
          user_type: userType,
        },
      },
    });

    console.log('�� Sign Up Response:', { data, error });

    if (error) {
      console.error('❌ Sign Up Error:', error);
      throw error;
    }

    if (!data.user) {
      throw new Error('Sign up failed. Please try again.');
    }

    // If there's a session, user is auto-confirmed (email confirmation disabled)
    if (data.session) {
      console.log('✅ User auto-confirmed and logged in:', data.user.id);
      await loadProfile(data.user.id);
      return { user: data.user, session: data.session };
    }

    // If no session, email confirmation is required
    if (data.user && !data.session) {
      console.log('📧 Email confirmation required for:', data.user.email);
      // Return user data - user will receive confirmation email
      // The confirmation link will log them in automatically
      return { user: data.user, session: null };
    }
  };

  const signIn = async (email: string, password: string) => {
    console.log('🔐 Sign In Request:', { email });

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      console.log('📥 Sign In Response:', {
        user: data.user?.id,
        session: data.session ? 'exists' : 'none',
        error: error ? {
          message: error.message,
          status: error.status,
          name: error.name
        } : null
      });

      if (error) {
        console.error('❌ Sign In Error:', error);

        if (error.message.includes('Invalid login credentials')) {
          throw new Error('Invalid email or password. Please check your credentials and try again.');
        }

        throw error;
      }

      if (!data.user || !data.session) {
        throw new Error('Sign in failed. Please try again.');
      }

      console.log('✅ Sign in successful:', data.user.id);
      await loadProfile(data.user.id);
    } catch (err: any) {
      console.error('❌ Sign In Failed:', {
        message: err.message,
        code: err.code,
        status: err.status
      });
      throw err;
    }
  };

  const signOut = async () => {

    try {
      await supabase.auth.signOut();

    } catch (error) {

    }
  };

  const refreshProfile = async () => {
    if (user) {
      await loadProfile(user.id);
    }
  };

  return (
    <AuthContext.Provider value={{ user, profile, loading, signUp, signIn, signOut, refreshProfile }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
