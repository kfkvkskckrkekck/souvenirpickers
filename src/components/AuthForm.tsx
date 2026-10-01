// import { useState, useEffect } from "react";
// import {
//   LogIn,
//   UserPlus,
//   Globe,
//   Star,
//   MessageCircle,
//   ShoppingBag,
//   Eye,
//   EyeOff,
//   Gift,
//   Sparkles,
//   Users,
//   Plane,
// } from "lucide-react";
// import { useAuth } from "../contexts/AuthContext";
// import { supabase } from "../lib/supabase";

// export function AuthForm() {
//   const [isSignUp, setIsSignUp] = useState(false);
//   const [email, setEmail] = useState("");
//   const [password, setPassword] = useState("");
//   const [fullName, setFullName] = useState("");
//   const [userType, setUserType] = useState<"picker" | "client">("client");
//   const [error, setError] = useState("");
//   const [loading, setLoading] = useState(false);
//   const [isPasswordResetSent, setIsPasswordResetSent] = useState(false);
//   const [showPassword, setShowPassword] = useState(false);
//   const [showForgotPassword, setShowForgotPassword] = useState(false);
//   const [useMagicLink, setUseMagicLink] = useState(false);
//   const [magicLinkSent, setMagicLinkSent] = useState(false);
//   const [showHelpModal, setShowHelpModal] = useState(false);
//   const [referralCode, setReferralCode] = useState<string>("");
//   const [showGoogleProfileModal, setShowGoogleProfileModal] = useState(false);
//   const [googleUserData, setGoogleUserData] = useState<any>(null);
//   const { signIn, signUp } = useAuth();

//   useEffect(() => {
//     const urlParams = new URLSearchParams(window.location.search);
//     const refCode = urlParams.get("ref");
//     if (refCode) {
//       console.log("Referral code detected:", refCode);
//       setReferralCode(refCode);
//     }

//     // Check if user just signed in with Google and needs to complete profile
//     const checkGoogleAuth = async () => {
//       const {
//         data: { session },
//       } = await supabase.auth.getSession();
//       if (session?.user) {
//         const { data: profile } = await supabase
//           .from("profiles")
//           .select("user_type, full_name")
//           .eq("id", session.user.id)
//           .maybeSingle();

//         // If profile exists but missing user_type or full_name, show modal
//         if (profile && (!profile.user_type || !profile.full_name)) {
//           setGoogleUserData(session.user);
//           setFullName(
//             session.user.user_metadata?.full_name ||
//               session.user.user_metadata?.name ||
//               "",
//           );
//           setShowGoogleProfileModal(true);
//         }
//       }
//     };

//     checkGoogleAuth();
//   }, []);

//   const handleSubmit = async (e: React.FormEvent) => {
//     e.preventDefault();
//     setError("");
//     setLoading(true);

//     try {
//       if (isSignUp) {
//         // Check if email already exists before attempting signup
//         console.log("Checking if email exists:", email.trim());

//         const checkResponse = await fetch(
//           `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/check-email-exists`,
//           {
//             method: "POST",
//             headers: {
//               "Content-Type": "application/json",
//               Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
//             },
//             body: JSON.stringify({
//               email: email.trim(),
//             }),
//           },
//         );

//         const checkData = await checkResponse.json();
//         console.log("Email check response:", checkData);

//         if (checkData.exists) {
//           // Email already exists - show error and stop
//           setError(
//             "Email already exists. Use a different email or sign in with this email.",
//           );
//           setLoading(false);
//           return;
//         }

//         // Email doesn't exist, proceed with signup
//         // User will need to confirm their email before logging in
//         const signupResult = await signUp(email, password, fullName, userType);

//         // Check if email confirmation is required
//         if (signupResult && !signupResult.session) {
//           // Email confirmation required - show success message
//           setError("");
//           setLoading(false);
//           alert(
//             "Account created successfully! Please check your email to confirm your account before signing in.",
//           );
//           setIsSignUp(false); // Switch to login form
//           return;
//         }

//         console.log("✅ Signup successful! User is now logged in.");

//         // If there's a referral code, create the referral relationship
//         if (referralCode && signupResult?.user) {
//           console.log("Processing referral code:", referralCode);
//           try {
//             // Find the referrer by their referral code
//             const { data: referrer, error: referrerError } = await supabase
//               .from("referral_codes")
//               .select("user_id")
//               .eq("code", referralCode)
//               .maybeSingle();

//             if (referrerError) {
//               console.error("Error finding referrer:", referrerError);
//             } else if (referrer) {
//               console.log("Found referrer:", referrer.user_id);

//               // Create referral relationship (rewards will be created when first order completes)
//               const { error: referralError } = await supabase
//                 .from("referrals")
//                 .insert({
//                   referrer_id: referrer.user_id,
//                   referred_id: signupResult.user.id,
//                   referral_code: referralCode,
//                   status: "pending", // Will change to 'completed' when first order is done
//                 });

//               if (referralError) {
//                 console.error(
//                   "Error creating referral relationship:",
//                   referralError,
//                 );
//               } else {
//                 console.log(
//                   "✅ Referral relationship created! Rewards will be applied after first order.",
//                 );
//               }
//             } else {
//               console.log("Referral code not found:", referralCode);
//             }
//           } catch (err) {
//             console.error("Error processing referral:", err);
//           }
//         }
//       } else {
//         if (useMagicLink) {
//           await handleMagicLinkLogin();
//         } else {
//           await signIn(email, password);
//         }
//       }
//     } catch (err: any) {
//       console.error("🔴 AUTH ERROR:", err);
//       console.error("Error details:", {
//         message: err.message,
//         status: err.status,
//         code: err.code,
//         name: err.name,
//         fullError: err,
//       });

//       let errorMessage = err.message || "An error occurred";

//       // Handle duplicate email during sign up
//       if (
//         isSignUp &&
//         (err.message?.toLowerCase().includes("already") ||
//           err.message?.toLowerCase().includes("registered") ||
//           err.message?.toLowerCase().includes("exists") ||
//           err.code === "user_already_exists")
//       ) {
//         errorMessage =
//           "Email already exists. Use a different email or sign in with this email.";
//       } else if (err.status === 400) {
//         errorMessage = `${err.message} - Check your email/password format`;
//       } else if (err.status === 429) {
//         errorMessage =
//           "Too many attempts. Please wait 60 seconds and try again.";
//       } else if (err.message?.includes("Invalid")) {
//         errorMessage = "Invalid email or password. Please check and try again.";
//       }

//       setError(errorMessage);
//     } finally {
//       setLoading(false);
//     }
//   };

//   const handleMagicLinkLogin = async () => {
//     try {
//       console.log("Checking if user exists for magic link:", email.trim());

//       // First check if email exists
//       const checkResponse = await fetch(
//         `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/check-email-exists`,
//         {
//           method: "POST",
//           headers: {
//             "Content-Type": "application/json",
//             Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
//           },
//           body: JSON.stringify({
//             email: email.trim(),
//           }),
//         },
//       );

//       const checkData = await checkResponse.json();
//       console.log("Email check response:", checkData);

//       if (!checkData.exists) {
//         // Email doesn't exist - show error
//         throw new Error(
//           "No account found with this email. Please sign up first or check your email address.",
//         );
//       }

//       console.log("Sending magic link to:", email.trim());

//       // Call custom edge function to send magic link email
//       const response = await fetch(
//         `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-magic-link-recovery`,
//         {
//           method: "POST",
//           headers: {
//             "Content-Type": "application/json",
//             Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
//           },
//           body: JSON.stringify({
//             email: email.trim(),
//           }),
//         },
//       );

//       const data = await response.json();

//       if (!response.ok) {
//         throw new Error(data.error || "Failed to send magic link");
//       }

//       console.log("✓ Magic link sent successfully");
//       setMagicLinkSent(true);

//       setTimeout(() => {
//         setMagicLinkSent(false);
//       }, 15000);
//     } catch (err: any) {
//       console.error("Magic link error:", err);
//       throw err;
//     }
//   };

//   const handleForgotPassword = async (e: React.FormEvent) => {
//     e.preventDefault();
//     setError("");
//     setLoading(true);

//     try {
//       console.log("Sending password reset email to:", email.trim());

//       // Call custom edge function to send password reset email
//       const response = await fetch(
//         `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-password-reset-email`,
//         {
//           method: "POST",
//           headers: {
//             "Content-Type": "application/json",
//             Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
//           },
//           body: JSON.stringify({
//             email: email.trim(),
//             redirectTo: `${window.location.origin}/reset-password`,
//           }),
//         },
//       );

//       const data = await response.json();

//       if (!response.ok) {
//         throw new Error(data.error || "Failed to send reset email");
//       }

//       console.log("✓ Password reset email sent successfully");
//       setIsPasswordResetSent(true);
//       setShowForgotPassword(false);
//     } catch (err: any) {
//       console.error("Password reset error:", err);
//       setError(err.message || "Failed to send reset email. Please try again.");
//     } finally {
//       setLoading(false);
//     }
//   };

//   const handleGoogleSignIn = async () => {
//     try {
//       setError("");
//       setLoading(true);

//       console.log("Starting Google OAuth flow...");
//       console.log("Redirect URL:", window.location.origin);

//       // Use the current origin so it works on both production and preview environments
//       const redirectTo = `${window.location.origin}/`;

//       const { data, error } = await supabase.auth.signInWithOAuth({
//         provider: "google",
//         options: {
//           redirectTo,
//           queryParams: {
//             access_type: "offline",
//             prompt: "consent",
//           },
//         },
//       });

//       if (error) {
//         console.error("OAuth initiation error:", error);
//         throw error;
//       }

//       console.log("OAuth flow initiated successfully");
//       // The user will be redirected to Google's OAuth page
//       // After successful authentication, they'll be redirected back to the app
//     } catch (err: any) {
//       console.error("Google sign-in error:", err);
//       setError(
//         err.message ||
//           "Failed to sign in with Google. Check browser console for details.",
//       );
//       setLoading(false);
//     }
//   };

//   const handleCompleteGoogleProfile = async (e: React.FormEvent) => {
//     e.preventDefault();
//     setError("");
//     setLoading(true);

//     try {
//       if (!googleUserData) return;

//       // Update profile with user_type and full_name
//       const { error: profileError } = await supabase
//         .from("profiles")
//         .update({
//           user_type: userType,
//           full_name: fullName,
//         })
//         .eq("id", googleUserData.id);

//       if (profileError) throw profileError;

//       // If user is a picker, create picker_profile
//       if (userType === "picker") {
//         const { error: pickerError } = await supabase
//           .from("picker_profiles")
//           .insert({
//             user_id: googleUserData.id,
//             languages: [],
//             location_city: "",
//             location_country: "",
//           });

//         if (pickerError && pickerError.code !== "23505") {
//           // Ignore duplicate key error
//           throw pickerError;
//         }
//       }

//       // Reload the page to update the auth context
//       window.location.reload();
//     } catch (err: any) {
//       console.error("Error completing Google profile:", err);
//       setError(err.message || "Failed to complete profile");
//     } finally {
//       setLoading(false);
//     }
//   };

//   return (
//     <div className="min-h-screen overflow-x-hidden bg-[#f8fbff] text-slate-900">
//       {/* Ambient background */}
//       <div className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
//         <div className="absolute -left-40 top-20 h-96 w-96 rounded-full bg-blue-200/30 blur-3xl" />
//         <div className="absolute right-[-10rem] top-0 h-[34rem] w-[34rem] rounded-full bg-green-200/25 blur-3xl" />
//         <div className="absolute left-1/3 top-[40rem] h-80 w-80 rounded-full bg-orange-200/20 blur-3xl" />
//       </div>

//       <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-10">
//         {/* Header */}
//         {/* <header className="flex items-center justify-between py-5 lg:py-7">
//           <div className="flex items-center gap-3">
//             <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-600 to-blue-500 shadow-lg shadow-blue-500/20">
//               <Globe className="h-6 w-6 text-white" />
//             </div>
//             <div>
//               <div className="text-lg font-black tracking-tight text-slate-950">
//                 Global Network
//               </div>
//               <div className="hidden text-[10px] font-bold uppercase tracking-[0.2em] text-slate-400 sm:block">
//                 Discover • Connect • Earn
//               </div>
//             </div>
//           </div>

//           <nav className="hidden items-center gap-8 text-sm font-semibold text-slate-600 lg:flex">
//             <a
//               href="#top"
//               className="text-blue-600 transition hover:text-blue-700"
//             >
//               Home
//             </a>
//             <a href="#how-it-works" className="transition hover:text-blue-600">
//               How It Works
//             </a>
//             <a href="#features" className="transition hover:text-blue-600">
//               Features
//             </a>
//             <a href="#trust" className="transition hover:text-blue-600">
//               Why Us
//             </a>
//           </nav>

//           <div className="flex items-center gap-2 sm:gap-3">
//             <a
//               href="#auth"
//               className="rounded-full border border-blue-200 bg-white px-4 py-2.5 text-sm font-bold text-blue-600 shadow-sm transition hover:border-blue-400 hover:shadow-md sm:px-5"
//             >
//               Login
//             </a>
//             <a
//               href="#auth"
//               className="rounded-full bg-gradient-to-r from-blue-600 to-blue-500 px-4 py-2.5 text-sm font-bold text-white shadow-lg shadow-blue-500/25 transition hover:-translate-y-0.5 hover:shadow-xl sm:px-5"
//             >
//               Sign Up
//             </a>
//           </div>
//         </header> */}

//         <main id="top">
//           {/* Hero */}
//           <section className="relative grid items-center gap-12 pb-16 pt-8 lg:grid-cols-[0.92fr_1.08fr] lg:gap-10 lg:pb-24 lg:pt-12">
//             <div className="relative z-10 max-w-2xl">
//               <div className="mb-5 inline-flex items-center gap-2 rounded-full border border-blue-100 bg-blue-50 px-4 py-2 text-xs font-extrabold tracking-wide text-blue-700 shadow-sm">
//                 <Sparkles className="h-3.5 w-3.5 text-blue-500" />
//                 Connect · Learn · Earn
//               </div>

//               <h1 className="text-[clamp(2.7rem,5.2vw,5.2rem)] font-black leading-[0.98] tracking-[-0.045em] text-slate-950">
//                 Discover Unique{" "}
//                 <span className="bg-gradient-to-r from-blue-600 via-blue-500 to-blue-600 bg-clip-text text-transparent">
//                   Souvenirs
//                 </span>
//                 <br />
//                 from Around the{" "}
//                 <span className="bg-gradient-to-r from-blue-600 via-orange-500 to-orange-500 bg-clip-text text-transparent">
//                   World
//                 </span>
//               </h1>

//               <p className="mt-7 max-w-xl text-base leading-7 text-slate-600 sm:text-lg">
//                 Connect with locals worldwide to discover authentic souvenirs or
//                 earn money by becoming a picker.
//               </p>

//               <div className="mt-8 grid max-w-2xl grid-cols-1 gap-3 sm:grid-cols-3">
//                 <div className="flex items-center gap-3 rounded-2xl border border-blue-100 bg-white/80 p-3 shadow-sm backdrop-blur">
//                   <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
//                     <Globe className="h-5 w-5" />
//                   </div>
//                   <div>
//                     <p className="text-xs font-extrabold text-slate-800">
//                       Authentic
//                     </p>
//                     <p className="text-[11px] text-slate-500">Local Finds</p>
//                   </div>
//                 </div>

//                 <div className="flex items-center gap-3 rounded-2xl border border-blue-100 bg-white/80 p-3 shadow-sm backdrop-blur">
//                   <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
//                     <Star className="h-5 w-5" />
//                   </div>
//                   <div>
//                     <p className="text-xs font-extrabold text-slate-800">
//                       Safe &amp; Secure
//                     </p>
//                     <p className="text-[11px] text-slate-500">Transactions</p>
//                   </div>
//                 </div>

//                 <div className="flex items-center gap-3 rounded-2xl border border-blue-100 bg-white/80 p-3 shadow-sm backdrop-blur">
//                   <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
//                     <Users className="h-5 w-5" />
//                   </div>
//                   <div>
//                     <p className="text-xs font-extrabold text-slate-800">
//                       Support
//                     </p>
//                     <p className="text-[11px] text-slate-500">
//                       Local Communities
//                     </p>
//                   </div>
//                 </div>
//               </div>

//               <div className="mt-8 flex flex-wrap items-center gap-3">
//                 <a
//                   href="#auth"
//                   className="inline-flex items-center gap-3 rounded-full bg-gradient-to-r from-blue-600 to-blue-500 px-7 py-4 text-sm font-black text-white shadow-xl shadow-blue-500/25 transition hover:-translate-y-1 hover:shadow-2xl"
//                 >
//                   Join Now
//                   <span className="text-lg">→</span>
//                 </a>
//                 <a
//                   href="#how-it-works"
//                   className="inline-flex items-center gap-3 rounded-full border border-slate-200 bg-white px-7 py-4 text-sm font-black text-slate-700 shadow-sm transition hover:-translate-y-1 hover:border-blue-200 hover:text-blue-600 hover:shadow-lg"
//                 >
//                   <span className="flex h-6 w-6 items-center justify-center rounded-full bg-blue-50 text-blue-600">
//                     ▶
//                   </span>
//                   Watch Video
//                 </a>
//               </div>

//               <img
//                 src="/landing-assets/world-skyline-bg.jpg"
//                 alt=""
//                 aria-hidden="true"
//                 className="pointer-events-none mt-8 h-24 w-full max-w-xl object-cover object-left opacity-80 sm:h-28 lg:h-32"
//               />
//             </div>

//             {/* Hero video */}
//             <div id="how-it-works" className="relative min-w-0 lg:pl-2">
//               <div className="absolute -inset-5 rounded-[3rem] bg-gradient-to-br from-blue-400/25 via-blue-300/10 to-green-300/20 blur-2xl" />

//               <div className="relative overflow-visible">
//                 {/* Decorative plane + flight path */}
//                 <svg
//                   className="pointer-events-none absolute -top-16 right-10 z-30 hidden h-20 w-28 text-blue-400/70 sm:block"
//                   viewBox="0 0 140 96"
//                   fill="none"
//                 >
//                   <path
//                     d="M4 70C40 10 95 4 134 18"
//                     stroke="currentColor"
//                     strokeWidth="2"
//                     strokeDasharray="5 6"
//                     strokeLinecap="round"
//                   />
//                 </svg>
//                 <Plane className="pointer-events-none absolute -top-[4.25rem] right-8 z-30 hidden h-6 w-6 -rotate-6 text-blue-500 sm:block" />

//                 <div className="absolute -right-2 -top-14 z-20 hidden max-w-[11rem] -rotate-3 text-right sm:block">
//                   <p className="font-serif text-lg italic leading-tight text-slate-700">
//                     Real People
//                     <br />
//                     Real Stories
//                     <br />
//                     <span className="text-blue-600">Authentic Souvenirs</span>
//                   </p>
//                   <svg
//                     className="ml-auto mt-1 h-8 w-10 text-slate-400"
//                     viewBox="0 0 40 32"
//                     fill="none"
//                   >
//                     <path
//                       d="M36 4C30 16 20 24 4 27"
//                       stroke="currentColor"
//                       strokeWidth="1.5"
//                       strokeLinecap="round"
//                     />
//                     <path
//                       d="M9 22L4 27L10 30"
//                       stroke="currentColor"
//                       strokeWidth="1.5"
//                       strokeLinecap="round"
//                       strokeLinejoin="round"
//                     />
//                   </svg>
//                 </div>

//                 <div className="relative overflow-hidden rounded-[2rem] border-4 border-white bg-slate-950 shadow-[0_30px_80px_rgba(15,23,42,0.18)]">
//                   <video
//                     loop
//                     playsInline
//                     controls
//                     controlsList="nodownload"
//                     preload="auto"
//                     crossOrigin="anonymous"
//                     className="aspect-video w-full object-cover"
//                     onLoadStart={() =>
//                       console.log("AuthForm video load started")
//                     }
//                     onLoadedMetadata={() =>
//                       console.log("AuthForm video metadata loaded")
//                     }
//                     onCanPlay={() => console.log("AuthForm video can play")}
//                     onError={(e) => {
//                       console.error(
//                         "AuthForm video error:",
//                         e.currentTarget.error,
//                       );
//                       const target = e.currentTarget;
//                       if (target.parentElement) {
//                         target.parentElement.innerHTML = `
//                           <div class="flex items-center justify-center h-full text-white text-center p-8 bg-gradient-to-br from-blue-900 to-blue-700">
//                             <div>
//                               <p class="font-bold mb-2">Demo Video Loading...</p>
//                               <p class="text-sm opacity-90">Optimizing for streaming</p>
//                             </div>
//                           </div>
//                         `;
//                       }
//                     }}
//                   >
//                     <source
//                       src="https://bfqvzxczmvfteqbhgyvx.supabase.co/storage/v1/object/public/media/platform-demo-video.mp4"
//                       type="video/mp4"
//                     />
//                     <div className="flex h-full items-center justify-center text-white">
//                       Your browser does not support the video tag.
//                     </div>
//                   </video>
//                 </div>

//                 <div className="pointer-events-none absolute -bottom-5 left-5 hidden h-20 w-20 rounded-full bg-blue-500/10 blur-xl sm:block" />
//                 <div className="pointer-events-none absolute -right-8 bottom-16 hidden h-28 w-28 rounded-full bg-green-400/20 blur-2xl sm:block" />
//               </div>

//               {/* Sign in / sign up card, overlapping the video */}
//               <div id="auth" className="relative z-20 mt-6 lg:-mt-16">
//                 <div className="absolute -inset-3 rounded-[2rem] bg-gradient-to-r from-blue-500/25 via-orange-400/15 to-green-400/25 blur-xl" />
//                 <div className="relative rounded-[2rem] border border-white/80 bg-white p-5 shadow-[0_25px_70px_rgba(15,23,42,0.16)] sm:p-7">
//                   {isPasswordResetSent ? (
//                     <div className="py-6 text-center">
//                       <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-orange-50 text-orange-600">
//                         <svg
//                           className="h-7 w-7"
//                           fill="none"
//                           stroke="currentColor"
//                           viewBox="0 0 24 24"
//                         >
//                           <path
//                             strokeLinecap="round"
//                             strokeLinejoin="round"
//                             strokeWidth={2}
//                             d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
//                           />
//                         </svg>
//                       </div>
//                       <h2 className="text-2xl font-black text-slate-950">
//                         Check Your Email
//                       </h2>
//                       <p className="mt-2 text-sm leading-6 text-slate-500">
//                         We've sent a password reset link to{" "}
//                         <strong>{email}</strong>. Click the link in the email to
//                         reset your password.
//                       </p>
//                       <div className="mt-5 rounded-2xl bg-orange-50 p-4 text-left text-sm text-orange-800">
//                         <strong>Link expires in 1 hour.</strong> Didn't receive
//                         it? Check your spam folder.
//                       </div>
//                       <button
//                         onClick={() => {
//                           setIsPasswordResetSent(false);
//                           setEmail("");
//                         }}
//                         className="mt-5 text-sm font-bold text-blue-600 hover:text-blue-700"
//                       >
//                         Back to Sign In
//                       </button>
//                     </div>
//                   ) : magicLinkSent ? (
//                     <div className="py-6 text-center">
//                       <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-blue-50 text-blue-600">
//                         <svg
//                           className="h-7 w-7"
//                           fill="none"
//                           stroke="currentColor"
//                           viewBox="0 0 24 24"
//                         >
//                           <path
//                             strokeLinecap="round"
//                             strokeLinejoin="round"
//                             strokeWidth={2}
//                             d="M3 19v-8.93a2 2 0 01.89-1.664l7-4.666a2 2 0 012.22 0l7 4.666A2 2 0 0121 10.07V19M3 19a2 2 0 002 2h14a2 2 0 002-2M3 19l6.75-4.5M21 19l-6.75-4.5M3 10l6.75 4.5M21 10l-6.75 4.5m0 0l-1.14.76a2 2 0 01-2.22 0l-1.14-.76"
//                           />
//                         </svg>
//                       </div>
//                       <h2 className="text-2xl font-black text-slate-950">
//                         Check Your Email
//                       </h2>
//                       <p className="mt-2 text-sm leading-6 text-slate-500">
//                         We've sent a magic login link to{" "}
//                         <strong>{email}</strong>. Click the link to sign in
//                         instantly.
//                       </p>
//                       <div className="mt-5 rounded-2xl bg-blue-50 p-4 text-left text-sm text-blue-800">
//                         <strong>Didn't receive the email?</strong> Check your
//                         spam folder or request another link.
//                       </div>
//                       <button
//                         onClick={() => {
//                           setMagicLinkSent(false);
//                           setEmail("");
//                         }}
//                         className="mt-5 text-sm font-bold text-blue-600 hover:text-blue-700"
//                       >
//                         Back to Sign In
//                       </button>
//                     </div>
//                   ) : (
//                     <>
//                       <div className="mb-5 text-center">
//                         <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-600 to-blue-500 text-white shadow-lg shadow-blue-500/20">
//                           {isSignUp ? (
//                             <UserPlus className="h-5 w-5" />
//                           ) : (
//                             <LogIn className="h-5 w-5" />
//                           )}
//                         </div>
//                         <h2 className="text-2xl font-black tracking-tight text-slate-950">
//                           {isSignUp ? "Start Your Journey" : "Welcome"}
//                         </h2>
//                         <p className="mt-1 text-xs leading-5 text-slate-500">
//                           {isSignUp
//                             ? "Create your account and join the global community"
//                             : "Sign in to continue your adventure"}
//                         </p>
//                       </div>

//                       <div className="mb-5 grid grid-cols-2 rounded-2xl bg-slate-100 p-1.5">
//                         <button
//                           onClick={() => {
//                             setIsSignUp(false);
//                             setMagicLinkSent(false);
//                             setUseMagicLink(false);
//                           }}
//                           className={`rounded-xl py-2.5 text-sm font-extrabold transition ${
//                             !isSignUp
//                               ? "bg-white text-blue-600 shadow-sm"
//                               : "text-slate-500 hover:text-slate-800"
//                           }`}
//                         >
//                           SIGN IN
//                         </button>
//                         <button
//                           onClick={() => {
//                             setIsSignUp(true);
//                             setMagicLinkSent(false);
//                             setUseMagicLink(false);
//                           }}
//                           className={`rounded-xl py-2.5 text-sm font-extrabold transition ${
//                             isSignUp
//                               ? "bg-orange-500 text-white shadow-md shadow-orange-500/20"
//                               : "text-slate-500 hover:text-slate-800"
//                           }`}
//                         >
//                           SIGN UP
//                         </button>
//                       </div>

//                       {referralCode && isSignUp && (
//                         <div className="mb-4 flex items-start gap-3 rounded-2xl border border-green-200 bg-green-50 p-3">
//                           <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-green-500">
//                             <Gift className="h-4 w-4 text-white" />
//                           </div>
//                           <div className="min-w-0">
//                             <p className="text-xs font-extrabold text-green-900">
//                               Referral Code Applied!
//                             </p>
//                             <p className="mt-0.5 text-[11px] leading-4 text-green-700">
//                               Code{" "}
//                               <span className="font-mono font-bold">
//                                 {referralCode}
//                               </span>{" "}
//                               — earn rewards after your first order.
//                             </p>
//                           </div>
//                         </div>
//                       )}

//                       <form onSubmit={handleSubmit} className="space-y-3.5">
//                         {isSignUp && (
//                           <>
//                             <div>
//                               <label className="mb-1.5 block text-xs font-bold text-slate-700">
//                                 Full Name{" "}
//                                 <span className="text-red-500">*</span>
//                               </label>
//                               <input
//                                 type="text"
//                                 value={fullName}
//                                 onChange={(e) => setFullName(e.target.value)}
//                                 className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 text-sm outline-none transition focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-500/10"
//                                 autoComplete="off"
//                                 required
//                               />
//                             </div>

//                             <div>
//                               <label className="mb-1.5 block text-xs font-bold text-slate-700">
//                                 I am a...{" "}
//                                 <span className="text-red-500">*</span>
//                               </label>
//                               <div className="grid grid-cols-2 gap-2">
//                                 <button
//                                   type="button"
//                                   onClick={() => setUserType("client")}
//                                   className={`rounded-xl border px-3 py-2.5 text-left transition ${
//                                     userType === "client"
//                                       ? "border-blue-500 bg-blue-50 text-blue-700 ring-2 ring-blue-500/10"
//                                       : "border-slate-200 bg-slate-50 text-slate-600 hover:border-slate-300"
//                                   }`}
//                                 >
//                                   <div className="text-sm font-extrabold">
//                                     Collector
//                                   </div>
//                                   <div className="mt-0.5 text-[11px] text-slate-500">
//                                     Find souvenirs
//                                   </div>
//                                 </button>

//                                 <button
//                                   type="button"
//                                   onClick={() => setUserType("picker")}
//                                   className={`rounded-xl border px-3 py-2.5 text-left transition ${
//                                     userType === "picker"
//                                       ? "border-blue-500 bg-blue-50 text-blue-700 ring-2 ring-blue-500/10"
//                                       : "border-slate-200 bg-slate-50 text-slate-600 hover:border-slate-300"
//                                   }`}
//                                 >
//                                   <div className="text-sm font-extrabold">
//                                     Picker
//                                   </div>
//                                   <div className="mt-0.5 text-[11px] text-slate-500">
//                                     Collect items
//                                   </div>
//                                 </button>
//                               </div>
//                             </div>

//                             <div>
//                               <label className="mb-1.5 block text-xs font-bold text-slate-700">
//                                 Referral Code{" "}
//                                 <span className="font-normal text-slate-400">
//                                   (Optional)
//                                 </span>
//                               </label>
//                               <input
//                                 type="text"
//                                 value={referralCode}
//                                 onChange={(e) => {
//                                   const value = e.target.value
//                                     .trim()
//                                     .toUpperCase();
//                                   setReferralCode(value);
//                                 }}
//                                 placeholder="Enter code (e.g., 9CBUTKH5)"
//                                 className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 font-mono text-sm uppercase outline-none transition focus:border-green-500 focus:bg-white focus:ring-4 focus:ring-green-500/10"
//                                 autoComplete="off"
//                                 maxLength={10}
//                               />
//                               <p className="mt-1 text-[10px] text-slate-400">
//                                 Have a referral code? Enter it to get €5 off
//                                 your first order!
//                               </p>
//                             </div>
//                           </>
//                         )}

//                         <div>
//                           <label className="mb-1.5 block text-xs font-bold text-slate-700">
//                             Email <span className="text-red-500">*</span>
//                           </label>
//                           <input
//                             type="email"
//                             value={email}
//                             onChange={(e) => setEmail(e.target.value)}
//                             placeholder="Enter your email"
//                             className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 text-sm outline-none transition focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-500/10"
//                             autoComplete="off"
//                             required
//                           />
//                         </div>

//                         {!isSignUp && !useMagicLink && (
//                           <div className="text-right">
//                             <button
//                               type="button"
//                               onClick={() => setUseMagicLink(true)}
//                               className="text-[11px] font-bold text-blue-600 hover:text-blue-700"
//                             >
//                               Or sign in with a magic link instead
//                             </button>
//                           </div>
//                         )}

//                         {!isSignUp && useMagicLink && (
//                           <div className="rounded-2xl border border-blue-100 bg-blue-50 p-3.5">
//                             <div className="flex items-start gap-3">
//                               <div className="text-xl">✨</div>
//                               <div>
//                                 <h4 className="text-sm font-extrabold text-blue-900">
//                                   Magic Link Sign In
//                                 </h4>
//                                 <p className="mt-1 text-xs leading-5 text-blue-800">
//                                   We'll send you a link to sign in instantly —
//                                   no password required.
//                                 </p>
//                                 <button
//                                   type="button"
//                                   onClick={() => setUseMagicLink(false)}
//                                   className="mt-1 text-[11px] font-bold text-blue-600 underline"
//                                 >
//                                   Use password instead
//                                 </button>
//                               </div>
//                             </div>
//                           </div>
//                         )}

//                         {(!useMagicLink || isSignUp) && (
//                           <div>
//                             <label className="mb-1.5 block text-xs font-bold text-slate-700">
//                               Password <span className="text-red-500">*</span>
//                             </label>
//                             <div className="relative">
//                               <input
//                                 type={showPassword ? "text" : "password"}
//                                 value={password}
//                                 onChange={(e) => setPassword(e.target.value)}
//                                 placeholder={
//                                   isSignUp
//                                     ? "Min. 6 characters"
//                                     : "Enter password"
//                                 }
//                                 className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 pr-11 text-sm outline-none transition focus:border-orange-500 focus:bg-white focus:ring-4 focus:ring-orange-500/10"
//                                 autoComplete="off"
//                                 required={!useMagicLink}
//                                 minLength={6}
//                               />
//                               <button
//                                 type="button"
//                                 onClick={() => setShowPassword(!showPassword)}
//                                 className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 transition hover:text-slate-700"
//                                 aria-label={
//                                   showPassword
//                                     ? "Hide password"
//                                     : "Show password"
//                                 }
//                               >
//                                 {showPassword ? (
//                                   <EyeOff className="h-4 w-4" />
//                                 ) : (
//                                   <Eye className="h-4 w-4" />
//                                 )}
//                               </button>
//                             </div>
//                           </div>
//                         )}

//                         {error && (
//                           <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-xs font-semibold leading-5 text-red-700">
//                             {error}
//                           </div>
//                         )}

//                         <button
//                           type="submit"
//                           disabled={loading}
//                           className="group relative w-full overflow-hidden rounded-xl bg-gradient-to-r from-blue-600 to-blue-500 py-3.5 text-sm font-black uppercase tracking-wide text-white shadow-lg shadow-blue-500/20 transition hover:-translate-y-0.5 hover:shadow-xl disabled:cursor-not-allowed disabled:opacity-50"
//                         >
//                           <span className="relative flex items-center justify-center gap-2">
//                             {loading ? (
//                               <>
//                                 <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
//                                 <span>PROCESSING...</span>
//                               </>
//                             ) : isSignUp ? (
//                               <>
//                                 <UserPlus className="h-4 w-4" />
//                                 <span>Create Account</span>
//                               </>
//                             ) : useMagicLink ? (
//                               <>
//                                 <span>✨</span>
//                                 <span>Send Magic Link</span>
//                               </>
//                             ) : (
//                               <>
//                                 <LogIn className="h-4 w-4" />
//                                 <span>Sign In</span>
//                               </>
//                             )}
//                           </span>
//                         </button>
//                       </form>

//                       <div className="my-5 flex items-center gap-3">
//                         <div className="h-px flex-1 bg-slate-200" />
//                         <span className="text-[10px] font-bold text-slate-400">
//                           OR
//                         </span>
//                         <div className="h-px flex-1 bg-slate-200" />
//                       </div>

//                       <button
//                         type="button"
//                         onClick={handleGoogleSignIn}
//                         disabled={loading}
//                         className="flex w-full items-center justify-center gap-2.5 rounded-xl border border-slate-200 bg-white py-3 text-sm font-bold text-slate-700 shadow-sm transition hover:border-slate-300 hover:bg-slate-50 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
//                       >
//                         <svg className="h-5 w-5" viewBox="0 0 24 24">
//                           <path
//                             fill="#4285F4"
//                             d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
//                           />
//                           <path
//                             fill="#34A853"
//                             d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
//                           />
//                           <path
//                             fill="#FBBC05"
//                             d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
//                           />
//                           <path
//                             fill="#EA4335"
//                             d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
//                           />
//                         </svg>
//                         <span>
//                           {isSignUp
//                             ? "Sign up with Google"
//                             : "Sign in with Google"}
//                         </span>
//                       </button>

//                       <div className="mt-5 border-t border-slate-100 pt-5 text-center">
//                         <p className="text-xs text-slate-500">
//                           {isSignUp
//                             ? "Already have an account?"
//                             : "Don't have an account?"}{" "}
//                           <button
//                             type="button"
//                             onClick={() => setIsSignUp(!isSignUp)}
//                             className="font-extrabold text-blue-600 hover:text-blue-700"
//                           >
//                             {isSignUp ? "Sign In" : "Sign Up"}
//                           </button>
//                         </p>

//                         {!isSignUp && (
//                           <div className="mt-3 flex flex-col gap-2">
//                             <button
//                               type="button"
//                               onClick={() => setShowForgotPassword(true)}
//                               className="text-xs font-semibold text-orange-600 hover:text-orange-700"
//                             >
//                               Forgot Password?
//                             </button>
//                             <button
//                               type="button"
//                               onClick={() => setShowHelpModal(true)}
//                               className="text-[11px] font-medium text-slate-400 underline underline-offset-2 hover:text-slate-600"
//                             >
//                               Can't access your email? Get help
//                             </button>
//                           </div>
//                         )}
//                       </div>
//                     </>
//                   )}
//                 </div>
//               </div>
//             </div>
//           </section>

//           {/* Three core paths */}
//           <section id="features" className="pb-20 lg:pb-24">
//             <div className="grid gap-5 lg:grid-cols-3">
//               <div className="group overflow-hidden rounded-[2rem] shadow-xl shadow-blue-500/15 transition duration-300 hover:-translate-y-2 hover:shadow-2xl">
//                 <img
//                   src="/landing-assets/discover-card.jpg"
//                   alt="Discover — Browse authentic souvenirs from 150+ countries, curated by local experts."
//                   className="block h-full w-full object-cover"
//                 />
//               </div>

//               <div className="group overflow-hidden rounded-[2rem] shadow-xl shadow-orange-500/15 transition duration-300 hover:-translate-y-2 hover:shadow-2xl">
//                 <img
//                   src="/landing-assets/enjoy-card.jpg"
//                   alt="Enjoy — Receive handpicked treasures with genuine stories and guaranteed authenticity."
//                   className="block h-full w-full object-cover"
//                 />
//               </div>

//               <div className="group overflow-hidden rounded-[2rem] shadow-xl shadow-green-500/15 transition duration-300 hover:-translate-y-2 hover:shadow-2xl">
//                 <img
//                   src="/landing-assets/earn-card.jpg"
//                   alt="Earn Money — Earn every trip, pick souvenirs, make a difference. Flexible work, global reach."
//                   className="block h-full w-full object-cover"
//                 />
//               </div>
//             </div>
//           </section>

//           {/* Trust cards */}
//           <section id="trust" className="pb-20 lg:pb-28">
//             <div className="grid gap-5 md:grid-cols-3">
//               <div className="group rounded-[1.75rem] border border-blue-100 bg-white p-6 shadow-lg shadow-slate-900/5 transition hover:-translate-y-1 hover:shadow-xl">
//                 <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-blue-50 text-blue-600 transition group-hover:bg-blue-600 group-hover:text-white">
//                   <Globe className="h-6 w-6" />
//                 </div>
//                 <h3 className="mt-5 text-xl font-black text-slate-950">
//                   Global Network
//                 </h3>
//                 <p className="mt-2 text-sm leading-6 text-slate-500">
//                   Access to a vast 150+ countries and local markets from trusted
//                   pickers worldwide.
//                 </p>
//                 <div className="mt-5 h-1 w-9 rounded-full bg-blue-500 transition-all group-hover:w-16" />
//               </div>

//               <div className="group rounded-[1.75rem] border border-orange-100 bg-white p-6 shadow-lg shadow-slate-900/5 transition hover:-translate-y-1 hover:shadow-xl">
//                 <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-orange-50 text-orange-600 transition group-hover:bg-orange-500 group-hover:text-white">
//                   <MessageCircle className="h-6 w-6" />
//                 </div>
//                 <h3 className="mt-5 text-xl font-black text-slate-950">
//                   Direct Communication
//                 </h3>
//                 <p className="mt-2 text-sm leading-6 text-slate-500">
//                   Chat directly with pickers to discuss specific items,
//                   negotiate prices, and track your requests.
//                 </p>
//                 <div className="mt-5 h-1 w-9 rounded-full bg-orange-500 transition-all group-hover:w-16" />
//               </div>

//               <div className="group rounded-[1.75rem] border border-green-100 bg-white p-6 shadow-lg shadow-slate-900/5 transition hover:-translate-y-1 hover:shadow-xl">
//                 <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-green-50 text-green-600 transition group-hover:bg-green-500 group-hover:text-white">
//                   <Star className="h-6 w-6" />
//                 </div>
//                 <h3 className="mt-5 text-xl font-black text-slate-950">
//                   Verified Pickers
//                 </h3>
//                 <p className="mt-2 text-sm leading-6 text-slate-500">
//                   Real reviews and ratings from other users to find trusted
//                   pickers with proven track records.
//                 </p>
//                 <div className="mt-5 h-1 w-9 rounded-full bg-green-500 transition-all group-hover:w-16" />
//               </div>
//             </div>
//           </section>

//           {/* Bottom CTA */}
//           <section className="mb-12 overflow-hidden rounded-[2rem] bg-gradient-to-r from-blue-600 via-blue-500 to-green-500 p-8 text-center shadow-2xl shadow-blue-500/15 sm:p-12">
//             <div className="mx-auto max-w-3xl">
//               <p className="text-xs font-black uppercase tracking-[0.2em] text-white/70">
//                 Your next discovery is out there
//               </p>
//               <h2 className="mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">
//                 Ready to explore something truly authentic?
//               </h2>
//               <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-white/80">
//                 Connect with people, discover unique treasures, and make every
//                 journey more valuable.
//               </p>
//               <a
//                 href="#auth"
//                 className="mt-7 inline-flex items-center gap-2 rounded-full bg-white px-7 py-3.5 text-sm font-black text-blue-600 shadow-lg transition hover:-translate-y-1 hover:shadow-xl"
//               >
//                 Get Started <span>→</span>
//               </a>
//             </div>
//           </section>
//         </main>
//       </div>

//       {showHelpModal && (
//         <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
//           <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-8 relative max-h-[90vh] overflow-y-auto">
//             <button
//               onClick={() => setShowHelpModal(false)}
//               className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
//             >
//               <svg
//                 className="w-6 h-6"
//                 fill="none"
//                 stroke="currentColor"
//                 viewBox="0 0 24 24"
//               >
//                 <path
//                   strokeLinecap="round"
//                   strokeLinejoin="round"
//                   strokeWidth={2}
//                   d="M6 18L18 6M6 6l12 12"
//                 />
//               </svg>
//             </button>

//             <div className="text-center mb-6">
//               <div className="w-16 h-16 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
//                 <svg
//                   className="w-8 h-8 text-white"
//                   fill="none"
//                   stroke="currentColor"
//                   viewBox="0 0 24 24"
//                 >
//                   <path
//                     strokeLinecap="round"
//                     strokeLinejoin="round"
//                     strokeWidth={2}
//                     d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"
//                   />
//                 </svg>
//               </div>
//               <h3 className="text-2xl font-bold text-gray-900 mb-2">
//                 Can't Access Your Email?
//               </h3>
//               <p className="text-gray-600">
//                 If you can't access your email, here are your options to recover
//                 your account:
//               </p>
//             </div>

//             <div className="space-y-4">
//               <div className="bg-blue-50 border-2 border-blue-300 rounded-xl p-4">
//                 <h4 className="font-bold text-blue-900 mb-2 flex items-center gap-2">
//                   <span className="text-lg">1️⃣</span>
//                   Check Your Spam/Junk Folder
//                 </h4>
//                 <p className="text-sm text-blue-800">
//                   Password reset emails often get filtered. Check your spam,
//                   junk, or promotions folder.
//                 </p>
//               </div>

//               <div className="bg-green-50 border-2 border-green-300 rounded-xl p-4">
//                 <h4 className="font-bold text-green-900 mb-2 flex items-center gap-2">
//                   <span className="text-lg">2️⃣</span>
//                   Use Backup Recovery Options
//                 </h4>
//                 <p className="text-sm text-green-800 mb-2">
//                   If you previously set up backup recovery options (backup
//                   email, phone number), those will be used automatically when
//                   you request a password reset.
//                 </p>
//                 <p className="text-xs text-green-700 italic">
//                   Note: You can set up backup options in Account Recovery
//                   Settings (Shield icon) after logging in.
//                 </p>
//               </div>

//               <div className="bg-orange-50 border-2 border-orange-300 rounded-xl p-4">
//                 <h4 className="font-bold text-orange-900 mb-2 flex items-center gap-2">
//                   <span className="text-lg">3️⃣</span>
//                   Try Magic Link Instead
//                 </h4>
//                 <p className="text-sm text-orange-800 mb-3">
//                   Magic links are sometimes more reliable than password resets.
//                   They provide instant access without needing a password.
//                 </p>
//                 <button
//                   onClick={() => {
//                     setShowHelpModal(false);
//                     setUseMagicLink(true);
//                   }}
//                   className="w-full bg-orange-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-orange-700 transition-colors"
//                 >
//                   Try Magic Link Sign In
//                 </button>
//               </div>

//               <div className="bg-red-50 border-2 border-red-300 rounded-xl p-4">
//                 <h4 className="font-bold text-red-900 mb-2 flex items-center gap-2">
//                   <span className="text-lg">4️⃣</span>
//                   Contact Support
//                 </h4>
//                 <p className="text-sm text-red-800 mb-2">
//                   If none of the above work, our support team can help verify
//                   your identity and restore access to your account.
//                 </p>
//                 <p className="text-xs text-red-700 font-medium">
//                   Email: support@souvenirpickers.com
//                 </p>
//               </div>

//               <div className="bg-gray-100 border border-gray-300 rounded-xl p-4">
//                 <h4 className="font-bold text-gray-900 mb-2">
//                   Prevention Tips
//                 </h4>
//                 <ul className="text-sm text-gray-700 space-y-1 list-disc list-inside">
//                   <li>
//                     Always set up backup recovery options after creating your
//                     account
//                   </li>
//                   <li>Keep your email password secure and accessible</li>
//                   <li>Add your phone number for SMS recovery</li>
//                   <li>Save your password in a secure password manager</li>
//                 </ul>
//               </div>
//             </div>

//             <button
//               onClick={() => setShowHelpModal(false)}
//               className="w-full mt-6 bg-gray-200 text-gray-700 py-3 rounded-xl font-medium hover:bg-gray-300 transition-colors"
//             >
//               Close
//             </button>
//           </div>
//         </div>
//       )}

//       {showForgotPassword && (
//         <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
//           <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 relative">
//             <button
//               onClick={() => {
//                 setShowForgotPassword(false);
//                 setIsPasswordResetSent(false);
//                 setError("");
//               }}
//               className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
//             >
//               <svg
//                 className="w-6 h-6"
//                 fill="none"
//                 stroke="currentColor"
//                 viewBox="0 0 24 24"
//               >
//                 <path
//                   strokeLinecap="round"
//                   strokeLinejoin="round"
//                   strokeWidth={2}
//                   d="M6 18L18 6M6 6l12 12"
//                 />
//               </svg>
//             </button>

//             {isPasswordResetSent ? (
//               <div className="text-center">
//                 <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
//                   <svg
//                     className="w-8 h-8 text-green-600"
//                     fill="none"
//                     stroke="currentColor"
//                     viewBox="0 0 24 24"
//                   >
//                     <path
//                       strokeLinecap="round"
//                       strokeLinejoin="round"
//                       strokeWidth={2}
//                       d="M5 13l4 4L19 7"
//                     />
//                   </svg>
//                 </div>
//                 <h3 className="text-2xl font-bold text-gray-900 mb-3">
//                   Check Your Email
//                 </h3>
//                 <p className="text-gray-600 mb-4">
//                   If an account exists for <strong>{email}</strong>, you'll
//                   receive a password reset link shortly.
//                 </p>

//                 <div className="bg-orange-50 border-2 border-orange-300 rounded-lg p-4 text-left mb-4">
//                   <p className="text-sm text-orange-900 font-bold mb-2 flex items-center gap-2">
//                     <span className="text-lg">📬</span>
//                     IMPORTANT: Check Your Spam Folder!
//                   </p>
//                   <p className="text-sm text-orange-800">
//                     Password reset emails often end up in spam/junk folders.
//                     Please check there first if you don't see the email in your
//                     inbox within 2 minutes.
//                   </p>
//                 </div>

//                 <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left mb-4">
//                   <p className="text-sm text-blue-900 font-semibold mb-2">
//                     Still didn't receive the email?
//                   </p>
//                   <ul className="text-sm text-blue-800 space-y-1 list-disc list-inside">
//                     <li>Make sure you entered the correct email</li>
//                     <li>
//                       Wait 60 seconds, then try requesting again (rate limited)
//                     </li>
//                     <li>Open browser console (F12) to check for any errors</li>
//                     <li>Try using the magic link sign in option instead</li>
//                   </ul>
//                 </div>

//                 <div className="bg-green-50 border border-green-200 rounded-lg p-4 text-left">
//                   <p className="text-sm text-green-900 font-semibold mb-2">
//                     Alternative Options:
//                   </p>
//                   <button
//                     onClick={() => {
//                       setIsPasswordResetSent(false);
//                       setShowForgotPassword(false);
//                       setUseMagicLink(true);
//                     }}
//                     className="text-sm text-green-700 hover:text-green-800 font-medium underline"
//                   >
//                     Try Magic Link Sign In instead →
//                   </button>
//                 </div>
//               </div>
//             ) : (
//               <>
//                 <h3 className="text-2xl font-bold text-gray-900 mb-2">
//                   Reset Password
//                 </h3>
//                 <p className="text-gray-600 mb-6">
//                   Enter your email address and we'll send you a link to reset
//                   your password.
//                 </p>

//                 <form onSubmit={handleForgotPassword} className="space-y-4">
//                   <div>
//                     <label className="block text-sm font-bold text-gray-900 mb-2">
//                       Email Address <span className="text-red-600">*</span>
//                     </label>
//                     <input
//                       type="email"
//                       value={email}
//                       onChange={(e) => setEmail(e.target.value)}
//                       placeholder="Enter your email"
//                       className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-100 focus:border-blue-500 transition-all text-sm placeholder:text-gray-400"
//                       required
//                     />
//                   </div>

//                   {error && (
//                     <div className="bg-red-50 border-2 border-red-300 text-red-700 p-3 rounded-xl text-sm font-bold">
//                       {error}
//                     </div>
//                   )}

//                   <button
//                     type="submit"
//                     disabled={loading}
//                     className="w-full bg-gradient-to-r from-orange-600 to-orange-500 text-white py-3 rounded-xl font-bold text-base hover:from-orange-700 hover:to-orange-600 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
//                   >
//                     {loading ? (
//                       <span className="flex items-center justify-center gap-2">
//                         <div className="w-5 h-5 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
//                         Sending...
//                       </span>
//                     ) : (
//                       "Send Reset Link"
//                     )}
//                   </button>
//                 </form>
//               </>
//             )}
//           </div>
//         </div>
//       )}

//       {showGoogleProfileModal && (
//         <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
//           <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 relative">
//             <div className="text-center mb-6">
//               <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4">
//                 <UserPlus className="w-8 h-8 text-white" />
//               </div>
//               <h3 className="text-2xl font-bold text-gray-900 mb-2">
//                 Complete Your Profile
//               </h3>
//               <p className="text-gray-600">
//                 Welcome! Please complete your profile to get started.
//               </p>
//             </div>

//             <form onSubmit={handleCompleteGoogleProfile} className="space-y-4">
//               <div>
//                 <label className="block text-sm font-medium text-gray-700 mb-1">
//                   Full Name <span className="text-red-600">*</span>
//                 </label>
//                 <input
//                   type="text"
//                   value={fullName}
//                   onChange={(e) => setFullName(e.target.value)}
//                   className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
//                   required
//                 />
//               </div>

//               <div>
//                 <label className="block text-sm font-medium text-gray-700 mb-1">
//                   I am a... <span className="text-red-600">*</span>
//                 </label>
//                 <div className="grid grid-cols-2 gap-2">
//                   <button
//                     type="button"
//                     onClick={() => setUserType("client")}
//                     className={`py-2 px-3 rounded-lg border-2 transition-all ${
//                       userType === "client"
//                         ? "border-blue-600 bg-blue-50 text-blue-700"
//                         : "border-gray-200 hover:border-gray-300"
//                     }`}
//                   >
//                     <div className="font-medium text-sm">Collector</div>
//                     <div className="text-xs text-gray-500">Find souvenirs</div>
//                   </button>
//                   <button
//                     type="button"
//                     onClick={() => setUserType("picker")}
//                     className={`py-2 px-3 rounded-lg border-2 transition-all ${
//                       userType === "picker"
//                         ? "border-blue-600 bg-blue-50 text-blue-700"
//                         : "border-gray-200 hover:border-gray-300"
//                     }`}
//                   >
//                     <div className="font-medium text-sm">Picker</div>
//                     <div className="text-xs text-gray-500">Collect items</div>
//                   </button>
//                 </div>
//               </div>

//               {error && (
//                 <div className="bg-red-50 border-2 border-red-300 text-red-700 p-3 rounded-xl text-sm font-bold">
//                   {error}
//                 </div>
//               )}

//               <button
//                 type="submit"
//                 disabled={loading}
//                 className="w-full bg-gradient-to-r from-blue-600 to-blue-500 text-white py-3 rounded-xl font-bold text-base hover:from-blue-700 hover:to-blue-600 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
//               >
//                 {loading ? (
//                   <span className="flex items-center justify-center gap-2">
//                     <div className="w-5 h-5 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
//                     Completing...
//                   </span>
//                 ) : (
//                   "Complete Profile"
//                 )}
//               </button>
//             </form>
//           </div>
//         </div>
//       )}
//     </div>
//   );
// }

import { useState, useEffect } from "react";
import {
  LogIn,
  UserPlus,
  Globe,
  Star,
  MessageCircle,
  ShoppingBag,
  Eye,
  EyeOff,
  Gift,
  Sparkles,
  Users,
  Plane,
  ShieldCheck,
} from "lucide-react";
import { useAuth } from "../contexts/AuthContext";
import { supabase } from "../lib/supabase";

export function AuthForm() {
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [userType, setUserType] = useState<"picker" | "client">("client");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [isPasswordResetSent, setIsPasswordResetSent] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [useMagicLink, setUseMagicLink] = useState(false);
  const [magicLinkSent, setMagicLinkSent] = useState(false);
  const [showHelpModal, setShowHelpModal] = useState(false);
  const [referralCode, setReferralCode] = useState<string>("");
  const [showGoogleProfileModal, setShowGoogleProfileModal] = useState(false);
  const [googleUserData, setGoogleUserData] = useState<any>(null);
  const { signIn, signUp } = useAuth();

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const refCode = urlParams.get("ref");
    if (refCode) {
      console.log("Referral code detected:", refCode);
      setReferralCode(refCode);
    }

    // Check if user just signed in with Google and needs to complete profile
    const checkGoogleAuth = async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (session?.user) {
        const { data: profile } = await supabase
          .from("profiles")
          .select("user_type, full_name")
          .eq("id", session.user.id)
          .maybeSingle();

        // If profile exists but missing user_type or full_name, show modal
        if (profile && (!profile.user_type || !profile.full_name)) {
          setGoogleUserData(session.user);
          setFullName(
            session.user.user_metadata?.full_name ||
              session.user.user_metadata?.name ||
              "",
          );
          setShowGoogleProfileModal(true);
        }
      }
    };

    checkGoogleAuth();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (isSignUp) {
        // Check if email already exists before attempting signup
        console.log("Checking if email exists:", email.trim());

        const checkResponse = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/check-email-exists`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
            },
            body: JSON.stringify({
              email: email.trim(),
            }),
          },
        );

        const checkData = await checkResponse.json();
        console.log("Email check response:", checkData);

        if (checkData.exists) {
          // Email already exists - show error and stop
          setError(
            "Email already exists. Use a different email or sign in with this email.",
          );
          setLoading(false);
          return;
        }

        // Email doesn't exist, proceed with signup
        // User will need to confirm their email before logging in
        const signupResult = await signUp(email, password, fullName, userType);

        // Check if email confirmation is required
        if (signupResult && !signupResult.session) {
          // Email confirmation required - show success message
          setError("");
          setLoading(false);
          alert(
            "Account created successfully! Please check your email to confirm your account before signing in.",
          );
          setIsSignUp(false); // Switch to login form
          return;
        }

        console.log("✅ Signup successful! User is now logged in.");

        // If there's a referral code, create the referral relationship
        if (referralCode && signupResult?.user) {
          console.log("Processing referral code:", referralCode);
          try {
            // Find the referrer by their referral code
            const { data: referrer, error: referrerError } = await supabase
              .from("referral_codes")
              .select("user_id")
              .eq("code", referralCode)
              .maybeSingle();

            if (referrerError) {
              console.error("Error finding referrer:", referrerError);
            } else if (referrer) {
              console.log("Found referrer:", referrer.user_id);

              // Create referral relationship (rewards will be created when first order completes)
              const { error: referralError } = await supabase
                .from("referrals")
                .insert({
                  referrer_id: referrer.user_id,
                  referred_id: signupResult.user.id,
                  referral_code: referralCode,
                  status: "pending", // Will change to 'completed' when first order is done
                });

              if (referralError) {
                console.error(
                  "Error creating referral relationship:",
                  referralError,
                );
              } else {
                console.log(
                  "✅ Referral relationship created! Rewards will be applied after first order.",
                );
              }
            } else {
              console.log("Referral code not found:", referralCode);
            }
          } catch (err) {
            console.error("Error processing referral:", err);
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
      console.error("🔴 AUTH ERROR:", err);
      console.error("Error details:", {
        message: err.message,
        status: err.status,
        code: err.code,
        name: err.name,
        fullError: err,
      });

      let errorMessage = err.message || "An error occurred";

      // Handle duplicate email during sign up
      if (
        isSignUp &&
        (err.message?.toLowerCase().includes("already") ||
          err.message?.toLowerCase().includes("registered") ||
          err.message?.toLowerCase().includes("exists") ||
          err.code === "user_already_exists")
      ) {
        errorMessage =
          "Email already exists. Use a different email or sign in with this email.";
      } else if (err.status === 400) {
        errorMessage = `${err.message} - Check your email/password format`;
      } else if (err.status === 429) {
        errorMessage =
          "Too many attempts. Please wait 60 seconds and try again.";
      } else if (err.message?.includes("Invalid")) {
        errorMessage = "Invalid email or password. Please check and try again.";
      }

      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleMagicLinkLogin = async () => {
    try {
      console.log("Checking if user exists for magic link:", email.trim());

      // First check if email exists
      const checkResponse = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/check-email-exists`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          },
          body: JSON.stringify({
            email: email.trim(),
          }),
        },
      );

      const checkData = await checkResponse.json();
      console.log("Email check response:", checkData);

      if (!checkData.exists) {
        // Email doesn't exist - show error
        throw new Error(
          "No account found with this email. Please sign up first or check your email address.",
        );
      }

      console.log("Sending magic link to:", email.trim());

      // Call custom edge function to send magic link email
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-magic-link-recovery`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          },
          body: JSON.stringify({
            email: email.trim(),
          }),
        },
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to send magic link");
      }

      console.log("✓ Magic link sent successfully");
      setMagicLinkSent(true);

      setTimeout(() => {
        setMagicLinkSent(false);
      }, 15000);
    } catch (err: any) {
      console.error("Magic link error:", err);
      throw err;
    }
  };

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      console.log("Sending password reset email to:", email.trim());

      // Call custom edge function to send password reset email
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-password-reset-email`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          },
          body: JSON.stringify({
            email: email.trim(),
            redirectTo: `${window.location.origin}/reset-password`,
          }),
        },
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to send reset email");
      }

      console.log("✓ Password reset email sent successfully");
      setIsPasswordResetSent(true);
      setShowForgotPassword(false);
    } catch (err: any) {
      console.error("Password reset error:", err);
      setError(err.message || "Failed to send reset email. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignIn = async () => {
    try {
      setError("");
      setLoading(true);

      console.log("Starting Google OAuth flow...");
      console.log("Redirect URL:", window.location.origin);

      // Use the current origin so it works on both production and preview environments
      const redirectTo = `${window.location.origin}/`;

      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo,
          queryParams: {
            access_type: "offline",
            prompt: "consent",
          },
        },
      });

      if (error) {
        console.error("OAuth initiation error:", error);
        throw error;
      }

      console.log("OAuth flow initiated successfully");
      // The user will be redirected to Google's OAuth page
      // After successful authentication, they'll be redirected back to the app
    } catch (err: any) {
      console.error("Google sign-in error:", err);
      setError(
        err.message ||
          "Failed to sign in with Google. Check browser console for details.",
      );
      setLoading(false);
    }
  };

  const handleCompleteGoogleProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (!googleUserData) return;

      // Update profile with user_type and full_name
      const { error: profileError } = await supabase
        .from("profiles")
        .update({
          user_type: userType,
          full_name: fullName,
        })
        .eq("id", googleUserData.id);

      if (profileError) throw profileError;

      // If user is a picker, create picker_profile
      if (userType === "picker") {
        const { error: pickerError } = await supabase
          .from("picker_profiles")
          .insert({
            user_id: googleUserData.id,
            languages: [],
            location_city: "",
            location_country: "",
          });

        if (pickerError && pickerError.code !== "23505") {
          // Ignore duplicate key error
          throw pickerError;
        }
      }

      // Reload the page to update the auth context
      window.location.reload();
    } catch (err: any) {
      console.error("Error completing Google profile:", err);
      setError(err.message || "Failed to complete profile");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen overflow-x-hidden bg-[#f8fbff] text-slate-900">
      {/* Ambient background */}
      <div className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
        <div className="absolute -left-40 top-20 h-96 w-96 rounded-full bg-blue-200/30 blur-3xl" />
        <div className="absolute right-[-10rem] top-0 h-[34rem] w-[34rem] rounded-full bg-green-200/25 blur-3xl" />
        <div className="absolute left-1/3 top-[40rem] h-80 w-80 rounded-full bg-orange-200/20 blur-3xl" />
      </div>

      <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-10">
        {/* Header */}
        {/* <header className="flex items-center justify-between py-5 lg:py-7">
          <div className="flex items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-600 to-blue-500 shadow-lg shadow-blue-500/20">
              <Globe className="h-6 w-6 text-white" />
            </div>
            <div>
              <div className="text-lg font-black tracking-tight text-slate-950">
                Global Network
              </div>
              <div className="hidden text-[10px] font-bold uppercase tracking-[0.2em] text-slate-400 sm:block">
                Discover • Connect • Earn
              </div>
            </div>
          </div>

          <nav className="hidden items-center gap-8 text-sm font-semibold text-slate-600 lg:flex">
            <a
              href="#top"
              className="text-blue-600 transition hover:text-blue-700"
            >
              Home
            </a>
            <a href="#how-it-works" className="transition hover:text-blue-600">
              How It Works
            </a>
            <a href="#features" className="transition hover:text-blue-600">
              Features
            </a>
            <a href="#trust" className="transition hover:text-blue-600">
              Why Us
            </a>
          </nav>

          <div className="flex items-center gap-2 sm:gap-3">
            <a
              href="#auth"
              className="rounded-full border border-blue-200 bg-white px-4 py-2.5 text-sm font-bold text-blue-600 shadow-sm transition hover:border-blue-400 hover:shadow-md sm:px-5"
            >
              Login
            </a>
            <a
              href="#auth"
              className="rounded-full bg-gradient-to-r from-blue-600 to-blue-500 px-4 py-2.5 text-sm font-bold text-white shadow-lg shadow-blue-500/25 transition hover:-translate-y-0.5 hover:shadow-xl sm:px-5"
            >
              Sign Up
            </a>
          </div>
        </header> */}

        <main id="top">
          {/* Hero */}
          <section className="relative grid items-start gap-10 pb-20 pt-6 lg:grid-cols-[0.9fr_1.1fr] lg:gap-8 lg:pb-32 lg:pt-10">
            {/* Skyline, bottom-left, fades out to the right */}
            <img
              src="/landing-assets/world-skyline-bg.jpg"
              alt=""
              aria-hidden="true"
              className="pointer-events-none absolute bottom-0 left-0 z-0 hidden h-56 w-[88%] object-cover object-left mix-blend-multiply lg:block xl:h-96"
              style={{
                WebkitMaskImage:
                  "linear-gradient(to right, #000 55%, transparent 100%)",
                maskImage:
                  "linear-gradient(to right, #000 55%, transparent 100%)",
              }}
            />

            {/* Left column */}
            <div className="relative z-10 max-w-2xl lg:pt-6">
              <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-blue-100 bg-white px-4 py-2 text-xs font-extrabold text-blue-700 shadow-sm shadow-blue-500/10">
                <Sparkles className="h-4 w-4 text-amber-400" />
                Connect · Learn · Earn
              </div>

              <h1 className="text-[clamp(2.6rem,4.8vw,4.6rem)] font-black leading-[1.02] tracking-[-0.04em] text-slate-950">
                Discover Unique
                <br />
                <span className="text-blue-600">Souvenirs</span>
                <br />
                from Around <span className="text-blue-600">the</span>
                <br />
                <span className="bg-gradient-to-r from-orange-500 via-orange-500 to-amber-500 bg-clip-text text-transparent">
                  World
                </span>
              </h1>

              <p className="mt-6 max-w-md text-base leading-7 text-slate-600 sm:text-lg">
                Connect with locals worldwide to discover authentic souvenirs or
                earn money by becoming a picker.
              </p>

              <div className="mt-8 flex flex-wrap gap-x-7 gap-y-4">
                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-blue-50 text-blue-600 ring-1 ring-blue-100">
                    <Globe className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="text-sm font-extrabold leading-tight text-slate-800">
                      Authentic
                    </p>
                    <p className="text-xs text-slate-500">Local Finds</p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-blue-50 text-blue-600 ring-1 ring-blue-100">
                    <ShieldCheck className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="text-sm font-extrabold leading-tight text-slate-800">
                      Safe &amp; Secure
                    </p>
                    <p className="text-xs text-slate-500">Transactions</p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-blue-50 text-blue-600 ring-1 ring-blue-100">
                    <Users className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="text-sm font-extrabold leading-tight text-slate-800">
                      Support
                    </p>
                    <p className="text-xs text-slate-500">Local Communities</p>
                  </div>
                </div>
              </div>

              <div className="mt-9 flex flex-wrap items-center gap-4">
                <a
                  href="#auth"
                  className="inline-flex items-center gap-4 rounded-full bg-gradient-to-r from-blue-600 to-blue-500 py-4 pl-8 pr-6 text-sm font-black text-white shadow-xl shadow-blue-500/30 transition hover:-translate-y-1 hover:shadow-2xl"
                >
                  Join Now
                  <span className="text-lg leading-none">→</span>
                </a>
                <a
                  href="#how-it-works"
                  className="inline-flex items-center gap-3 rounded-full border border-slate-200 bg-white py-3 pl-4 pr-7 text-sm font-black text-slate-700 shadow-md shadow-slate-900/5 transition hover:-translate-y-1 hover:border-blue-200 hover:text-blue-600 hover:shadow-lg"
                >
                  <span className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-600 pl-0.5 text-[10px] text-white">
                    ▶
                  </span>
                  Watch Video
                </a>
              </div>
            </div>

            {/* Right column: video + auth card */}
            <div id="how-it-works" className="relative z-10 min-w-0">
              <div className="absolute -inset-4 rounded-[2.5rem] bg-gradient-to-br from-blue-400/25 via-blue-300/10 to-green-300/20 blur-2xl" />

              <div className="relative">
                <div
                  aria-hidden="true"
                  className="blob absolute -bottom-20 -left-24 z-0 h-[220px] w-[280px] bg-gradient-to-br from-orange-200 via-orange-300 to-blue-200 opacity-75 blur-xl sm:h-[320px] sm:w-[320px] lg:h-[380px] lg:w-[380px]"
                />

                <div
                  aria-hidden="true"
                  className="blob absolute -top-20 right-24 z-0 h-[320px] w-[320px] bg-gradient-to-br from-blue-200 via-blue-300 to-indigo-300 opacity-75 blur-xl sm:h-[360px] sm:w-[360px] lg:h-[180px] lg:w-[220px]"
                />

                {/* Dashed flight path + plane */}
                <svg
                  className="pointer-events-none absolute -top-4 right-4 z-0 hidden h-16 w-28 text-blue-400/70 sm:block"
                  viewBox="0 0 140 96"
                  fill="none"
                >
                  <path
                    d="M4 70C40 10 95 4 134 18"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeDasharray="5 6"
                    strokeLinecap="round"
                  />
                </svg>
                <Plane className="pointer-events-none absolute -right-1 -top-[1.6rem] z-30 hidden h-7 w-7 rotate-[8deg] text-blue-600 sm:block" />

                <div className="relative overflow-hidden rounded-[1.75rem] border-4 border-white bg-slate-950 shadow-[0_30px_80px_rgba(15,23,42,0.2)]">
                  <video
                    loop
                    playsInline
                    controls
                    controlsList="nodownload"
                    preload="auto"
                    crossOrigin="anonymous"
                    className="aspect-video w-full object-cover"
                    onLoadStart={() =>
                      console.log("AuthForm video load started")
                    }
                    onLoadedMetadata={() =>
                      console.log("AuthForm video metadata loaded")
                    }
                    onCanPlay={() => console.log("AuthForm video can play")}
                    onError={(e) => {
                      console.error(
                        "AuthForm video error:",
                        e.currentTarget.error,
                      );
                      const target = e.currentTarget;
                      if (target.parentElement) {
                        target.parentElement.innerHTML = `
                          <div class="flex items-center justify-center h-full text-white text-center p-8 bg-gradient-to-br from-blue-900 to-blue-700">
                            <div>
                              <p class="font-bold mb-2">Demo Video Loading...</p>
                              <p class="text-sm opacity-90">Optimizing for streaming</p>
                            </div>
                          </div>
                        `;
                      }
                    }}
                  >
                    <source
                      src="https://bfqvzxczmvfteqbhgyvx.supabase.co/storage/v1/object/public/media/platform-demo-video.mp4"
                      type="video/mp4"
                    />

                    <div className="flex h-full items-center justify-center text-white">
                      Your browser does not support the video tag.
                    </div>
                  </video>

                  {/* Script text sits on the video, top-right */}
                  {/* <div className="pointer-events-none absolute right-5 top-5 z-10 hidden -rotate-6 text-right sm:block">
                    <p className="font-serif text-xl italic leading-tight text-white drop-shadow-[0_2px_8px_rgba(0,0,0,0.65)] lg:text-2xl">
                      Real People
                      <br />
                      Real Stories
                      <br />
                      <span className="text-sky-200">Authentic Souvenirs</span>
                    </p>
                  </div> */}
                </div>
              </div>

              {/* Sign in / sign up card: right aligned, just overlapping the video corner */}
              <div
                id="auth"
                className="relative z-20 mt-6 sm:ml-auto sm:w-[80%] lg:-mt-3 lg:w-[68%] xl:w-[62%]"
              >
                <div className="absolute -inset-2 rounded-[2rem] bg-gradient-to-r from-blue-500/25 via-orange-400/15 to-green-400/25 blur-xl" />
                <div className="relative rounded-[1.75rem] border border-white/80 bg-white p-5 shadow-[0_25px_70px_rgba(15,23,42,0.18)] sm:p-6">
                  {isPasswordResetSent ? (
                    <div className="py-6 text-center">
                      <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-orange-50 text-orange-600">
                        <svg
                          className="h-7 w-7"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                          />
                        </svg>
                      </div>
                      <h2 className="text-2xl font-black text-slate-950">
                        Check Your Email
                      </h2>
                      <p className="mt-2 text-sm leading-6 text-slate-500">
                        We've sent a password reset link to{" "}
                        <strong>{email}</strong>. Click the link in the email to
                        reset your password.
                      </p>
                      <div className="mt-5 rounded-2xl bg-orange-50 p-4 text-left text-sm text-orange-800">
                        <strong>Link expires in 1 hour.</strong> Didn't receive
                        it? Check your spam folder.
                      </div>
                      <button
                        onClick={() => {
                          setIsPasswordResetSent(false);
                          setEmail("");
                        }}
                        className="mt-5 text-sm font-bold text-blue-600 hover:text-blue-700"
                      >
                        Back to Sign In
                      </button>
                    </div>
                  ) : magicLinkSent ? (
                    <div className="py-6 text-center">
                      <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-blue-50 text-blue-600">
                        <svg
                          className="h-7 w-7"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M3 19v-8.93a2 2 0 01.89-1.664l7-4.666a2 2 0 012.22 0l7 4.666A2 2 0 0121 10.07V19M3 19a2 2 0 002 2h14a2 2 0 002-2M3 19l6.75-4.5M21 19l-6.75-4.5M3 10l6.75 4.5M21 10l-6.75 4.5m0 0l-1.14.76a2 2 0 01-2.22 0l-1.14-.76"
                          />
                        </svg>
                      </div>
                      <h2 className="text-2xl font-black text-slate-950">
                        Check Your Email
                      </h2>
                      <p className="mt-2 text-sm leading-6 text-slate-500">
                        We've sent a magic login link to{" "}
                        <strong>{email}</strong>. Click the link to sign in
                        instantly.
                      </p>
                      <div className="mt-5 rounded-2xl bg-blue-50 p-4 text-left text-sm text-blue-800">
                        <strong>Didn't receive the email?</strong> Check your
                        spam folder or request another link.
                      </div>
                      <button
                        onClick={() => {
                          setMagicLinkSent(false);
                          setEmail("");
                        }}
                        className="mt-5 text-sm font-bold text-blue-600 hover:text-blue-700"
                      >
                        Back to Sign In
                      </button>
                    </div>
                  ) : (
                    <>
                      <div className="mb-4 flex items-center gap-3">
                        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-blue-600 to-blue-500 text-white shadow-lg shadow-blue-500/25">
                          <Globe className="h-6 w-6" />
                        </div>
                        <div className="min-w-0">
                          <h2 className="text-xl font-black leading-tight tracking-tight text-slate-950">
                            {isSignUp ? "Start Your Journey" : "Welcome"}
                          </h2>
                          <p className="text-xs leading-4 text-slate-500">
                            {isSignUp
                              ? "Create your account and join the global community"
                              : "Sign in to continue your adventure"}
                          </p>
                        </div>
                      </div>

                      <div className="mb-4 grid grid-cols-2 gap-1 rounded-xl bg-slate-100 p-1">
                        <button
                          onClick={() => {
                            setIsSignUp(false);
                            setMagicLinkSent(false);
                            setUseMagicLink(false);
                          }}
                          className={`flex items-center justify-center gap-2 rounded-lg py-2.5 text-xs font-extrabold transition ${
                            !isSignUp
                              ? "bg-gradient-to-r from-blue-600 to-blue-500 text-white shadow-md shadow-blue-500/25"
                              : "text-slate-500 hover:text-slate-800"
                          }`}
                        >
                          <LogIn className="h-4 w-4" />
                          SIGN IN
                        </button>
                        <button
                          onClick={() => {
                            setIsSignUp(true);
                            setMagicLinkSent(false);
                            setUseMagicLink(false);
                          }}
                          className={`flex items-center justify-center gap-2 rounded-lg py-2.5 text-xs font-extrabold transition ${
                            isSignUp
                              ? "bg-orange-500 text-white shadow-md shadow-orange-500/25"
                              : "text-slate-500 hover:text-slate-800"
                          }`}
                        >
                          <UserPlus className="h-4 w-4" />
                          SIGN UP
                        </button>
                      </div>

                      {referralCode && isSignUp && (
                        <div className="mb-4 flex items-start gap-3 rounded-2xl border border-green-200 bg-green-50 p-3">
                          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-green-500">
                            <Gift className="h-4 w-4 text-white" />
                          </div>
                          <div className="min-w-0">
                            <p className="text-xs font-extrabold text-green-900">
                              Referral Code Applied!
                            </p>
                            <p className="mt-0.5 text-[11px] leading-4 text-green-700">
                              Code{" "}
                              <span className="font-mono font-bold">
                                {referralCode}
                              </span>{" "}
                              — earn rewards after your first order.
                            </p>
                          </div>
                        </div>
                      )}

                      <form onSubmit={handleSubmit} className="space-y-3.5">
                        {isSignUp && (
                          <>
                            <div>
                              <label className="mb-1.5 block text-xs font-bold text-slate-700">
                                Full Name{" "}
                                <span className="text-red-500">*</span>
                              </label>
                              <input
                                type="text"
                                value={fullName}
                                onChange={(e) => setFullName(e.target.value)}
                                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 text-sm outline-none transition focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-500/10"
                                autoComplete="off"
                                required
                              />
                            </div>

                            <div>
                              <label className="mb-1.5 block text-xs font-bold text-slate-700">
                                I am a...{" "}
                                <span className="text-red-500">*</span>
                              </label>
                              <div className="grid grid-cols-2 gap-2">
                                <button
                                  type="button"
                                  onClick={() => setUserType("client")}
                                  className={`rounded-xl border px-3 py-2.5 text-left transition ${
                                    userType === "client"
                                      ? "border-blue-500 bg-blue-50 text-blue-700 ring-2 ring-blue-500/10"
                                      : "border-slate-200 bg-slate-50 text-slate-600 hover:border-slate-300"
                                  }`}
                                >
                                  <div className="text-sm font-extrabold">
                                    Collector
                                  </div>
                                  <div className="mt-0.5 text-[11px] text-slate-500">
                                    Find souvenirs
                                  </div>
                                </button>

                                <button
                                  type="button"
                                  onClick={() => setUserType("picker")}
                                  className={`rounded-xl border px-3 py-2.5 text-left transition ${
                                    userType === "picker"
                                      ? "border-blue-500 bg-blue-50 text-blue-700 ring-2 ring-blue-500/10"
                                      : "border-slate-200 bg-slate-50 text-slate-600 hover:border-slate-300"
                                  }`}
                                >
                                  <div className="text-sm font-extrabold">
                                    Picker
                                  </div>
                                  <div className="mt-0.5 text-[11px] text-slate-500">
                                    Collect items
                                  </div>
                                </button>
                              </div>
                            </div>

                            <div>
                              <label className="mb-1.5 block text-xs font-bold text-slate-700">
                                Referral Code{" "}
                                <span className="font-normal text-slate-400">
                                  (Optional)
                                </span>
                              </label>
                              <input
                                type="text"
                                value={referralCode}
                                onChange={(e) => {
                                  const value = e.target.value
                                    .trim()
                                    .toUpperCase();
                                  setReferralCode(value);
                                }}
                                placeholder="Enter code (e.g., 9CBUTKH5)"
                                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 font-mono text-sm uppercase outline-none transition focus:border-green-500 focus:bg-white focus:ring-4 focus:ring-green-500/10"
                                autoComplete="off"
                                maxLength={10}
                              />
                              <p className="mt-1 text-[10px] text-slate-400">
                                Have a referral code? Enter it to get €5 off
                                your first order!
                              </p>
                            </div>
                          </>
                        )}

                        <div>
                          <label className="mb-1.5 block text-xs font-bold text-slate-700">
                            Email <span className="text-red-500">*</span>
                          </label>
                          <input
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            placeholder="Enter your email"
                            className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 text-sm outline-none transition focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-500/10"
                            autoComplete="off"
                            required
                          />
                        </div>

                        {!isSignUp && !useMagicLink && (
                          <div className="text-right">
                            <button
                              type="button"
                              onClick={() => setUseMagicLink(true)}
                              className="text-[11px] font-bold text-blue-600 hover:text-blue-700"
                            >
                              Or sign in with a magic link instead
                            </button>
                          </div>
                        )}

                        {!isSignUp && useMagicLink && (
                          <div className="rounded-2xl border border-blue-100 bg-blue-50 p-3.5">
                            <div className="flex items-start gap-3">
                              <div className="text-xl">✨</div>
                              <div>
                                <h4 className="text-sm font-extrabold text-blue-900">
                                  Magic Link Sign In
                                </h4>
                                <p className="mt-1 text-xs leading-5 text-blue-800">
                                  We'll send you a link to sign in instantly —
                                  no password required.
                                </p>
                                <button
                                  type="button"
                                  onClick={() => setUseMagicLink(false)}
                                  className="mt-1 text-[11px] font-bold text-blue-600 underline"
                                >
                                  Use password instead
                                </button>
                              </div>
                            </div>
                          </div>
                        )}

                        {(!useMagicLink || isSignUp) && (
                          <div>
                            <label className="mb-1.5 block text-xs font-bold text-slate-700">
                              Password <span className="text-red-500">*</span>
                            </label>
                            <div className="relative">
                              <input
                                type={showPassword ? "text" : "password"}
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                placeholder={
                                  isSignUp
                                    ? "Min. 6 characters"
                                    : "Enter password"
                                }
                                className="w-full rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-3 pr-11 text-sm outline-none transition focus:border-orange-500 focus:bg-white focus:ring-4 focus:ring-orange-500/10"
                                autoComplete="off"
                                required={!useMagicLink}
                                minLength={6}
                              />
                              <button
                                type="button"
                                onClick={() => setShowPassword(!showPassword)}
                                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 transition hover:text-slate-700"
                                aria-label={
                                  showPassword
                                    ? "Hide password"
                                    : "Show password"
                                }
                              >
                                {showPassword ? (
                                  <EyeOff className="h-4 w-4" />
                                ) : (
                                  <Eye className="h-4 w-4" />
                                )}
                              </button>
                            </div>
                          </div>
                        )}

                        {error && (
                          <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-xs font-semibold leading-5 text-red-700">
                            {error}
                          </div>
                        )}

                        <button
                          type="submit"
                          disabled={loading}
                          className="group relative w-full overflow-hidden rounded-xl bg-gradient-to-r from-blue-600 to-blue-500 py-3.5 text-sm font-black uppercase tracking-wide text-white shadow-lg shadow-blue-500/20 transition hover:-translate-y-0.5 hover:shadow-xl disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          <span className="relative flex items-center justify-center gap-2">
                            {loading ? (
                              <>
                                <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                                <span>PROCESSING...</span>
                              </>
                            ) : isSignUp ? (
                              <>
                                <UserPlus className="h-4 w-4" />
                                <span>Create Account</span>
                              </>
                            ) : useMagicLink ? (
                              <>
                                <span>✨</span>
                                <span>Send Magic Link</span>
                              </>
                            ) : (
                              <>
                                <LogIn className="h-4 w-4" />
                                <span>Sign In</span>
                              </>
                            )}
                          </span>
                        </button>
                      </form>

                      <div className="my-5 flex items-center gap-3">
                        <div className="h-px flex-1 bg-slate-200" />
                        <span className="text-[10px] font-bold text-slate-400">
                          OR
                        </span>
                        <div className="h-px flex-1 bg-slate-200" />
                      </div>

                      <button
                        type="button"
                        onClick={handleGoogleSignIn}
                        disabled={loading}
                        className="flex w-full items-center justify-center gap-2.5 rounded-xl border border-slate-200 bg-white py-3 text-sm font-bold text-slate-700 shadow-sm transition hover:border-slate-300 hover:bg-slate-50 hover:shadow-md disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        <svg className="h-5 w-5" viewBox="0 0 24 24">
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
                        <span>
                          {isSignUp
                            ? "Sign up with Google"
                            : "Sign in with Google"}
                        </span>
                      </button>

                      <div className="mt-5 border-t border-slate-100 pt-5 text-center">
                        <p className="text-xs text-slate-500">
                          {isSignUp
                            ? "Already have an account?"
                            : "Don't have an account?"}{" "}
                          <button
                            type="button"
                            onClick={() => setIsSignUp(!isSignUp)}
                            className="font-extrabold text-blue-600 hover:text-blue-700"
                          >
                            {isSignUp ? "Sign In" : "Sign Up"}
                          </button>
                        </p>

                        {!isSignUp && (
                          <div className="mt-3 flex flex-col gap-2">
                            <button
                              type="button"
                              onClick={() => setShowForgotPassword(true)}
                              className="text-xs font-semibold text-orange-600 hover:text-orange-700"
                            >
                              Forgot Password?
                            </button>
                            <button
                              type="button"
                              onClick={() => setShowHelpModal(true)}
                              className="text-[11px] font-medium text-slate-400 underline underline-offset-2 hover:text-slate-600"
                            >
                              Can't access your email? Get help
                            </button>
                          </div>
                        )}
                      </div>
                    </>
                  )}
                </div>
              </div>
            </div>
          </section>

          {/* Three core paths */}
          <section id="features" className="pb-20 lg:pb-24">
            <div className="grid gap-5 lg:grid-cols-3">
              <div className="group overflow-hidden rounded-[2rem] shadow-xl shadow-blue-500/15 transition duration-300 hover:-translate-y-2 hover:shadow-2xl">
                <img
                  src="/landing-assets/discover-card.jpg"
                  alt="Discover — Browse authentic souvenirs from 150+ countries, curated by local experts."
                  className="block h-full w-full object-cover"
                />
              </div>

              <div className="group overflow-hidden rounded-[2rem] shadow-xl shadow-orange-500/15 transition duration-300 hover:-translate-y-2 hover:shadow-2xl">
                <img
                  src="/landing-assets/enjoy-card.jpg"
                  alt="Enjoy — Receive handpicked treasures with genuine stories and guaranteed authenticity."
                  className="block h-full w-full object-cover"
                />
              </div>

              <div className="group overflow-hidden rounded-[2rem] shadow-xl shadow-green-500/15 transition duration-300 hover:-translate-y-2 hover:shadow-2xl">
                <img
                  src="/landing-assets/earn-card.jpg"
                  alt="Earn Money — Earn every trip, pick souvenirs, make a difference. Flexible work, global reach."
                  className="block h-full w-full object-cover"
                />
              </div>
            </div>
          </section>

          {/* Trust cards */}
          <section id="trust" className="pb-20 lg:pb-28">
            <div className="grid gap-5 md:grid-cols-3">
              <div className="group rounded-[1.75rem] border border-blue-100 bg-white p-6 shadow-lg shadow-slate-900/5 transition hover:-translate-y-1 hover:shadow-xl">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-blue-50 text-blue-600 transition group-hover:bg-blue-600 group-hover:text-white">
                  <Globe className="h-6 w-6" />
                </div>
                <h3 className="mt-5 text-xl font-black text-slate-950">
                  Global Network
                </h3>
                <p className="mt-2 text-sm leading-6 text-slate-500">
                  Access to a vast 150+ countries and local markets from trusted
                  pickers worldwide.
                </p>
                <div className="mt-5 h-1 w-9 rounded-full bg-blue-500 transition-all group-hover:w-16" />
              </div>

              <div className="group rounded-[1.75rem] border border-orange-100 bg-white p-6 shadow-lg shadow-slate-900/5 transition hover:-translate-y-1 hover:shadow-xl">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-orange-50 text-orange-600 transition group-hover:bg-orange-500 group-hover:text-white">
                  <MessageCircle className="h-6 w-6" />
                </div>
                <h3 className="mt-5 text-xl font-black text-slate-950">
                  Direct Communication
                </h3>
                <p className="mt-2 text-sm leading-6 text-slate-500">
                  Chat directly with pickers to discuss specific items,
                  negotiate prices, and track your requests.
                </p>
                <div className="mt-5 h-1 w-9 rounded-full bg-orange-500 transition-all group-hover:w-16" />
              </div>

              <div className="group rounded-[1.75rem] border border-green-100 bg-white p-6 shadow-lg shadow-slate-900/5 transition hover:-translate-y-1 hover:shadow-xl">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-green-50 text-green-600 transition group-hover:bg-green-500 group-hover:text-white">
                  <Star className="h-6 w-6" />
                </div>
                <h3 className="mt-5 text-xl font-black text-slate-950">
                  Verified Pickers
                </h3>
                <p className="mt-2 text-sm leading-6 text-slate-500">
                  Real reviews and ratings from other users to find trusted
                  pickers with proven track records.
                </p>
                <div className="mt-5 h-1 w-9 rounded-full bg-green-500 transition-all group-hover:w-16" />
              </div>
            </div>
          </section>

          {/* Bottom CTA */}
          <section className="mb-12 overflow-hidden rounded-[2rem] bg-gradient-to-r from-blue-600 via-blue-500 to-green-500 p-8 text-center shadow-2xl shadow-blue-500/15 sm:p-12">
            <div className="mx-auto max-w-3xl">
              <p className="text-xs font-black uppercase tracking-[0.2em] text-white/70">
                Your next discovery is out there
              </p>
              <h2 className="mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">
                Ready to explore something truly authentic?
              </h2>
              <p className="mx-auto mt-3 max-w-xl text-sm leading-6 text-white/80">
                Connect with people, discover unique treasures, and make every
                journey more valuable.
              </p>
              <a
                href="#auth"
                className="mt-7 inline-flex items-center gap-2 rounded-full bg-white px-7 py-3.5 text-sm font-black text-blue-600 shadow-lg transition hover:-translate-y-1 hover:shadow-xl"
              >
                Get Started <span>→</span>
              </a>
            </div>
          </section>
        </main>
      </div>

      {showHelpModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-8 relative max-h-[90vh] overflow-y-auto">
            <button
              onClick={() => setShowHelpModal(false)}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>

            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg
                  className="w-8 h-8 text-white"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"
                  />
                </svg>
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-2">
                Can't Access Your Email?
              </h3>
              <p className="text-gray-600">
                If you can't access your email, here are your options to recover
                your account:
              </p>
            </div>

            <div className="space-y-4">
              <div className="bg-blue-50 border-2 border-blue-300 rounded-xl p-4">
                <h4 className="font-bold text-blue-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">1️⃣</span>
                  Check Your Spam/Junk Folder
                </h4>
                <p className="text-sm text-blue-800">
                  Password reset emails often get filtered. Check your spam,
                  junk, or promotions folder.
                </p>
              </div>

              <div className="bg-green-50 border-2 border-green-300 rounded-xl p-4">
                <h4 className="font-bold text-green-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">2️⃣</span>
                  Use Backup Recovery Options
                </h4>
                <p className="text-sm text-green-800 mb-2">
                  If you previously set up backup recovery options (backup
                  email, phone number), those will be used automatically when
                  you request a password reset.
                </p>
                <p className="text-xs text-green-700 italic">
                  Note: You can set up backup options in Account Recovery
                  Settings (Shield icon) after logging in.
                </p>
              </div>

              <div className="bg-orange-50 border-2 border-orange-300 rounded-xl p-4">
                <h4 className="font-bold text-orange-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">3️⃣</span>
                  Try Magic Link Instead
                </h4>
                <p className="text-sm text-orange-800 mb-3">
                  Magic links are sometimes more reliable than password resets.
                  They provide instant access without needing a password.
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
                  If none of the above work, our support team can help verify
                  your identity and restore access to your account.
                </p>
                <p className="text-xs text-red-700 font-medium">
                  Email: support@souvenirpickers.com
                </p>
              </div>

              <div className="bg-gray-100 border border-gray-300 rounded-xl p-4">
                <h4 className="font-bold text-gray-900 mb-2">
                  Prevention Tips
                </h4>
                <ul className="text-sm text-gray-700 space-y-1 list-disc list-inside">
                  <li>
                    Always set up backup recovery options after creating your
                    account
                  </li>
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
                setError("");
              }}
              className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>

            {isPasswordResetSent ? (
              <div className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg
                    className="w-8 h-8 text-green-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                </div>
                <h3 className="text-2xl font-bold text-gray-900 mb-3">
                  Check Your Email
                </h3>
                <p className="text-gray-600 mb-4">
                  If an account exists for <strong>{email}</strong>, you'll
                  receive a password reset link shortly.
                </p>

                <div className="bg-orange-50 border-2 border-orange-300 rounded-lg p-4 text-left mb-4">
                  <p className="text-sm text-orange-900 font-bold mb-2 flex items-center gap-2">
                    <span className="text-lg">📬</span>
                    IMPORTANT: Check Your Spam Folder!
                  </p>
                  <p className="text-sm text-orange-800">
                    Password reset emails often end up in spam/junk folders.
                    Please check there first if you don't see the email in your
                    inbox within 2 minutes.
                  </p>
                </div>

                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-left mb-4">
                  <p className="text-sm text-blue-900 font-semibold mb-2">
                    Still didn't receive the email?
                  </p>
                  <ul className="text-sm text-blue-800 space-y-1 list-disc list-inside">
                    <li>Make sure you entered the correct email</li>
                    <li>
                      Wait 60 seconds, then try requesting again (rate limited)
                    </li>
                    <li>Open browser console (F12) to check for any errors</li>
                    <li>Try using the magic link sign in option instead</li>
                  </ul>
                </div>

                <div className="bg-green-50 border border-green-200 rounded-lg p-4 text-left">
                  <p className="text-sm text-green-900 font-semibold mb-2">
                    Alternative Options:
                  </p>
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
                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                  Reset Password
                </h3>
                <p className="text-gray-600 mb-6">
                  Enter your email address and we'll send you a link to reset
                  your password.
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
                      "Send Reset Link"
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
              <h3 className="text-2xl font-bold text-gray-900 mb-2">
                Complete Your Profile
              </h3>
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
                    onClick={() => setUserType("client")}
                    className={`py-2 px-3 rounded-lg border-2 transition-all ${
                      userType === "client"
                        ? "border-blue-600 bg-blue-50 text-blue-700"
                        : "border-gray-200 hover:border-gray-300"
                    }`}
                  >
                    <div className="font-medium text-sm">Collector</div>
                    <div className="text-xs text-gray-500">Find souvenirs</div>
                  </button>
                  <button
                    type="button"
                    onClick={() => setUserType("picker")}
                    className={`py-2 px-3 rounded-lg border-2 transition-all ${
                      userType === "picker"
                        ? "border-blue-600 bg-blue-50 text-blue-700"
                        : "border-gray-200 hover:border-gray-300"
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
                  "Complete Profile"
                )}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
