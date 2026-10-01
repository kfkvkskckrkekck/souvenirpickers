import {
  MapPin,
  MessageCircle,
  ShoppingBag,
  Star,
  Globe,
  TrendingUp,
  Package,
  Heart,
  ArrowRight,
  Sparkles,
  Award,
  Shield,
} from "lucide-react";
import { useAuth } from "../contexts/AuthContext";
import ProfileCompletionBanner from "./ProfileCompletionBanner";

type HomeViewProps = {
  onViewChange: (view: string) => void;
};

export function HomeView({ onViewChange }: HomeViewProps) {
  const { profile } = useAuth();

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-orange-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12 lg:py-16">
        {profile && (
          <ProfileCompletionBanner
            onNavigateToProfile={() => onViewChange("profile")}
          />
        )}

        {!profile && (
          <div className="text-center mb-12 sm:mb-16 lg:mb-20">
            <h1 className="text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-extrabold text-gray-900 mb-4 sm:mb-6 leading-tight">
              Discover Unique Souvenirs
              <br />
              <span className="bg-gradient-to-r from-blue-600 to-orange-500 bg-clip-text text-transparent">
                from Around the World
              </span>
            </h1>
            <p className="text-base sm:text-lg md:text-xl lg:text-2xl text-gray-600 max-w-4xl mx-auto mb-8 sm:mb-12 leading-relaxed px-2">
              Connect with locals worldwide to discover authentic souvenirs or
              earn money by becoming a picker
            </p>

            <div className="max-w-5xl mx-auto mb-6 sm:mb-8">
              <div className="bg-gradient-to-r from-blue-600 to-orange-500 p-0.5 rounded-2xl shadow-lg">
                <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white rounded-2xl px-6 py-5">
                  <div className="flex items-center gap-4">
                    <div className="bg-gradient-to-br from-amber-400 to-orange-500 p-2.5 rounded-xl shadow-md flex-shrink-0">
                      <Star className="w-6 h-6 text-white fill-white" />
                    </div>
                    <div>
                      <span className="font-extrabold text-gray-900 text-xl tracking-tight">
                        How It Works
                      </span>
                      <p className="text-gray-500 text-sm mt-0.5">
                        Connect with locals worldwide to bring authentic
                        treasures to your doorstep
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 bg-gradient-to-r from-blue-50 to-orange-50 border border-orange-200 rounded-xl px-4 py-2">
                    <span className="text-orange-600 font-semibold text-sm whitespace-nowrap">
                      Watch the video below
                    </span>
                    <span className="text-orange-500 text-lg font-bold">↓</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="max-w-5xl mx-auto mb-8 sm:mb-12">
              <div className="relative rounded-2xl sm:rounded-3xl overflow-hidden shadow-2xl border-4 border-blue-500 bg-gradient-to-br from-blue-900 to-blue-700">
                <video
                  className="w-full h-auto"
                  controls
                  playsInline
                  preload="auto"
                  crossOrigin="anonymous"
                  onLoadStart={() => console.log("Video load started")}
                  onLoadedMetadata={(e) =>
                    console.log(
                      "Video metadata loaded:",
                      e.currentTarget.duration,
                    )
                  }
                  onLoadedData={() => console.log("Video data loaded")}
                  onCanPlay={() => console.log("Video can play")}
                  onError={(e) => {
                    console.error("Video error:", e.currentTarget.error);
                    const target = e.currentTarget;
                    if (target.parentElement) {
                      target.parentElement.innerHTML = `
                        <div class="flex items-center justify-center h-full min-h-[300px] text-white text-center p-8">
                          <div>
                            <p class="text-xl font-bold mb-2">Video Loading Issue</p>
                            <p class="text-sm opacity-90">The demo video is being optimized for web streaming.</p>
                            <p class="text-sm opacity-90 mt-2">Please check back shortly!</p>
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
                  <div className="flex items-center justify-center h-full min-h-[300px] text-white">
                    <p>Your browser does not support the video tag.</p>
                  </div>
                </video>
              </div>
              <p className="text-center mt-4 text-gray-600 font-semibold">
                Watch how SouvenirPickers connects collectors with authentic
                treasures from around the world
              </p>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 sm:gap-4 md:gap-6 max-w-5xl mx-auto mb-8 sm:mb-12">
              <div className="bg-gradient-to-br from-blue-500 to-blue-600 text-white p-4 sm:p-6 rounded-xl sm:rounded-2xl shadow-xl transform hover:scale-105 transition-all duration-300">
                <div className="text-2xl sm:text-3xl md:text-4xl font-black mb-1 sm:mb-2">
                  150+
                </div>
                <div className="text-blue-100 font-semibold text-xs sm:text-sm md:text-base">
                  Countries
                </div>
              </div>
              <div className="bg-gradient-to-br from-orange-500 to-orange-600 text-white p-4 sm:p-6 rounded-xl sm:rounded-2xl shadow-xl transform hover:scale-105 transition-all duration-300">
                <div className="text-2xl sm:text-3xl md:text-4xl font-black mb-1 sm:mb-2">
                  1000+
                </div>
                <div className="text-orange-100 font-semibold text-xs sm:text-sm md:text-base">
                  Listings
                </div>
              </div>
              <div className="bg-gradient-to-br from-green-500 to-green-600 text-white p-4 sm:p-6 rounded-xl sm:rounded-2xl shadow-xl transform hover:scale-105 transition-all duration-300">
                <div className="text-2xl sm:text-3xl md:text-4xl font-black mb-1 sm:mb-2">
                  500+
                </div>
                <div className="text-green-100 font-semibold text-xs sm:text-sm md:text-base">
                  Active Pickers
                </div>
              </div>
              <div className="bg-gradient-to-br from-teal-500 to-cyan-600 text-white p-4 sm:p-6 rounded-xl sm:rounded-2xl shadow-xl transform hover:scale-105 transition-all duration-300">
                <div className="text-2xl sm:text-3xl md:text-4xl font-black mb-1 sm:mb-2">
                  98%
                </div>
                <div className="text-teal-100 font-semibold text-xs sm:text-sm md:text-base">
                  Satisfaction
                </div>
              </div>
            </div>

            <div className="grid md:grid-cols-5 gap-4 sm:gap-6 md:gap-8 max-w-7xl mx-auto mb-8 sm:mb-12">
              <div className="md:col-span-2 grid gap-4 sm:gap-6">
                <div className="group relative overflow-hidden bg-gradient-to-br from-blue-500 via-blue-600 to-blue-700 p-6 sm:p-8 rounded-2xl sm:rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(59,130,246,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
                  <div className="absolute top-0 right-0 w-40 h-40 bg-white opacity-10 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700"></div>
                  <div className="absolute bottom-0 left-0 w-32 h-32 bg-white opacity-10 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700"></div>

                  <div className="relative z-10">
                    <div className="mb-3 sm:mb-4 transform group-hover:scale-110 group-hover:rotate-6 transition-all duration-500">
                      <div className="bg-white bg-opacity-20 backdrop-blur-sm p-3 sm:p-4 rounded-xl sm:rounded-2xl inline-block shadow-xl">
                        <Globe className="w-8 h-8 sm:w-10 sm:h-10 text-white" />
                      </div>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white mb-2 sm:mb-3 transition-all duration-300 tracking-tight drop-shadow-lg">
                      DISCOVER
                    </h2>
                    <div className="h-1 w-16 sm:w-20 bg-white rounded-full mb-3 sm:mb-4 group-hover:w-24 sm:group-hover:w-32 transition-all duration-500 shadow-lg shadow-white/50"></div>
                    <p className="text-sm sm:text-base text-blue-50 leading-relaxed">
                      Browse authentic souvenirs from{" "}
                      <span className="font-bold text-white">
                        150+ countries
                      </span>{" "}
                      curated by local experts
                    </p>
                  </div>
                </div>

                <div className="group relative overflow-hidden bg-gradient-to-br from-orange-500 via-orange-600 to-red-600 p-6 sm:p-8 rounded-2xl sm:rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(249,115,22,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
                  <div className="absolute top-0 right-0 w-40 h-40 bg-white opacity-10 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700"></div>
                  <div className="absolute bottom-0 left-0 w-32 h-32 bg-white opacity-10 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700"></div>

                  <div className="relative z-10">
                    <div className="mb-3 sm:mb-4 transform group-hover:scale-110 group-hover:rotate-6 transition-all duration-500">
                      <div className="bg-white bg-opacity-20 backdrop-blur-sm p-3 sm:p-4 rounded-xl sm:rounded-2xl inline-block shadow-xl">
                        <Heart className="w-8 h-8 sm:w-10 sm:h-10 text-white fill-white animate-pulse" />
                      </div>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white mb-2 sm:mb-3 transition-all duration-300 tracking-tight drop-shadow-lg">
                      ENJOY
                    </h2>
                    <div className="h-1 w-16 sm:w-20 bg-white rounded-full mb-3 sm:mb-4 group-hover:w-24 sm:group-hover:w-32 transition-all duration-500 shadow-lg shadow-white/50"></div>
                    <p className="text-sm sm:text-base text-orange-50 leading-relaxed">
                      Receive{" "}
                      <span className="font-bold text-white">
                        handpicked treasures
                      </span>{" "}
                      with personal stories and guaranteed authenticity
                    </p>
                  </div>
                </div>
              </div>

              <div className="md:col-span-1 flex items-center justify-center">
                <div className="group relative overflow-hidden bg-gradient-to-br from-pink-500 via-rose-600 to-red-600 p-8 sm:p-10 md:p-12 rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(244,63,94,0.5)] transition-all duration-500 transform hover:scale-105 h-full flex items-center">
                  <div className="absolute inset-0 bg-white opacity-5 animate-pulse"></div>
                  <div className="absolute top-0 right-0 w-32 h-32 bg-white opacity-10 rounded-full -mr-16 -mt-16 group-hover:scale-150 transition-transform duration-700"></div>
                  <div className="absolute bottom-0 left-0 w-32 h-32 bg-white opacity-10 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700"></div>

                  <div className="relative z-10 text-center">
                    <div className="mb-4 transform group-hover:scale-110 transition-all duration-500 flex justify-center">
                      <div className="bg-white bg-opacity-20 backdrop-blur-sm p-4 sm:p-5 rounded-2xl inline-block shadow-xl">
                        <Sparkles className="w-12 h-12 sm:w-16 sm:h-16 text-white animate-pulse" />
                      </div>
                    </div>
                    <h2 className="text-3xl sm:text-4xl md:text-5xl font-black text-white mb-3 tracking-tight drop-shadow-lg">
                      WELCOME
                    </h2>
                    <div className="h-1.5 w-20 bg-white rounded-full mb-4 mx-auto group-hover:w-32 transition-all duration-500 shadow-lg shadow-white/50"></div>
                    <p className="text-sm sm:text-base md:text-lg text-rose-50 leading-relaxed font-semibold">
                      Your Journey to{" "}
                      <span className="text-white font-black">Authentic</span>{" "}
                      Souvenirs Starts Here
                    </p>
                  </div>
                </div>
              </div>

              <div className="md:col-span-2 grid gap-4 sm:gap-6">
                <div className="group relative overflow-hidden bg-gradient-to-br from-green-500 via-green-600 to-emerald-700 p-6 sm:p-8 rounded-2xl sm:rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(34,197,94,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
                  <div className="absolute top-0 right-0 w-40 h-40 bg-yellow-400 opacity-20 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700 animate-pulse"></div>
                  <div className="absolute bottom-0 left-0 w-32 h-32 bg-yellow-300 opacity-20 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700 animate-pulse"></div>

                  <div className="relative z-10">
                    <div className="mb-3 sm:mb-4 transform group-hover:scale-110 group-hover:rotate-12 transition-all duration-500">
                      <div className="bg-gradient-to-br from-yellow-400 to-yellow-500 p-3 sm:p-4 rounded-xl sm:rounded-2xl inline-block shadow-2xl">
                        <TrendingUp className="w-8 h-8 sm:w-10 sm:h-10 text-green-900 animate-bounce" />
                      </div>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black mb-2 sm:mb-3 transition-all duration-300 relative">
                      <span className="inline-block bg-gradient-to-r from-yellow-300 to-yellow-400 text-green-900 px-2 sm:px-3 py-1 rounded-lg shadow-lg">
                        EARN MONEY
                      </span>
                    </h2>
                    <div className="h-1 w-16 sm:w-20 bg-gradient-to-r from-yellow-300 via-yellow-200 to-white rounded-full mb-3 sm:mb-4 group-hover:w-24 sm:group-hover:w-32 transition-all duration-500 shadow-lg shadow-yellow-300/50"></div>
                    <p className="text-sm sm:text-base text-green-50 leading-relaxed">
                      Turn every trip into{" "}
                      <span className="font-black text-yellow-300 text-lg">
                        PROFIT
                      </span>
                      . Earn{" "}
                      <span className="font-bold text-white">$500-$5,000+</span>{" "}
                      monthly
                    </p>
                  </div>
                </div>

                <div className="group relative overflow-hidden bg-gradient-to-br from-pink-500 via-rose-600 to-red-600 p-6 sm:p-8 rounded-2xl sm:rounded-3xl shadow-2xl hover:shadow-[0_20px_60px_rgba(244,63,94,0.4)] transition-all duration-500 transform hover:-translate-y-3 hover:scale-105">
                  <div className="absolute top-0 right-0 w-40 h-40 bg-white opacity-10 rounded-full -mr-20 -mt-20 group-hover:scale-150 transition-transform duration-700"></div>
                  <div className="absolute bottom-0 left-0 w-32 h-32 bg-white opacity-10 rounded-full -ml-16 -mb-16 group-hover:scale-150 transition-transform duration-700"></div>

                  <div className="relative z-10">
                    <div className="mb-3 sm:mb-4 transform group-hover:scale-110 group-hover:rotate-6 transition-all duration-500">
                      <div className="bg-white bg-opacity-20 backdrop-blur-sm p-3 sm:p-4 rounded-xl sm:rounded-2xl inline-block shadow-xl">
                        <MessageCircle className="w-8 h-8 sm:w-10 sm:h-10 text-white" />
                      </div>
                    </div>
                    <h2 className="text-2xl sm:text-3xl font-black text-white mb-2 sm:mb-3 transition-all duration-300 tracking-tight drop-shadow-lg">
                      CONNECT
                    </h2>
                    <div className="h-1 w-16 sm:w-20 bg-white rounded-full mb-3 sm:mb-4 group-hover:w-24 sm:group-hover:w-32 transition-all duration-500 shadow-lg shadow-white/50"></div>
                    <p className="text-sm sm:text-base text-pink-50 leading-relaxed">
                      Chat with{" "}
                      <span className="font-bold text-white">
                        local pickers
                      </span>{" "}
                      worldwide and build lasting connections
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
              {profile?.user_type === "client" ? (
                <>
                  <button
                    onClick={() => onViewChange("listings")}
                    className="group bg-gradient-to-r from-blue-600 to-blue-700 text-white px-10 py-4 rounded-xl font-bold text-lg hover:from-blue-700 hover:to-blue-800 transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 flex items-center gap-2"
                  >
                    Browse Souvenirs
                    <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                  </button>
                  <button
                    onClick={() => onViewChange("desires")}
                    className="bg-white text-blue-600 px-10 py-4 rounded-xl font-bold text-lg border-3 border-blue-600 hover:bg-blue-50 transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105"
                  >
                    Post Your Desire
                  </button>
                </>
              ) : (
                <>
                  <button
                    onClick={() => onViewChange("listings")}
                    className="group bg-gradient-to-r from-green-600 to-green-700 text-white px-10 py-4 rounded-xl font-bold text-lg hover:from-green-700 hover:to-green-800 transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 flex items-center gap-2"
                  >
                    Start Earning Today
                    <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                  </button>
                  <button
                    onClick={() => onViewChange("desires")}
                    className="bg-white text-green-600 px-10 py-4 rounded-xl font-bold text-lg border-3 border-green-600 hover:bg-green-50 transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105"
                  >
                    View Client Desires
                  </button>
                </>
              )}
            </div>
          </div>
        )}

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-12 sm:mb-16 lg:mb-20">
          <div className="group bg-white p-5 sm:p-6 lg:p-8 rounded-xl sm:rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-2">
            <div className="w-10 h-10 sm:w-12 sm:h-12 lg:w-14 lg:h-14 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg sm:rounded-xl flex items-center justify-center mb-3 sm:mb-4 lg:mb-5 shadow-lg group-hover:scale-110 transition-transform">
              <MapPin className="w-5 h-5 sm:w-6 sm:h-6 lg:w-7 lg:h-7 text-white" />
            </div>
            <h3 className="text-base sm:text-lg lg:text-xl font-bold text-gray-900 mb-2 sm:mb-3">
              Global Network
            </h3>
            <p className="text-gray-600 text-sm sm:text-base leading-relaxed">
              Access pickers in 150+ countries worldwide
            </p>
          </div>

          <div className="group bg-white p-5 sm:p-6 lg:p-8 rounded-xl sm:rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-2">
            <div className="w-10 h-10 sm:w-12 sm:h-12 lg:w-14 lg:h-14 bg-gradient-to-br from-orange-500 to-orange-600 rounded-lg sm:rounded-xl flex items-center justify-center mb-3 sm:mb-4 lg:mb-5 shadow-lg group-hover:scale-110 transition-transform">
              <Shield className="w-5 h-5 sm:w-6 sm:h-6 lg:w-7 lg:h-7 text-white" />
            </div>
            <h3 className="text-base sm:text-lg lg:text-xl font-bold text-gray-900 mb-2 sm:mb-3">
              Secure Payments
            </h3>
            <p className="text-gray-600 text-sm sm:text-base leading-relaxed">
              Protected transactions with escrow system
            </p>
          </div>

          <div className="group bg-white p-5 sm:p-6 lg:p-8 rounded-xl sm:rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-2">
            <div className="w-10 h-10 sm:w-12 sm:h-12 lg:w-14 lg:h-14 bg-gradient-to-br from-green-500 to-green-600 rounded-lg sm:rounded-xl flex items-center justify-center mb-3 sm:mb-4 lg:mb-5 shadow-lg group-hover:scale-110 transition-transform">
              <Award className="w-5 h-5 sm:w-6 sm:h-6 lg:w-7 lg:h-7 text-white" />
            </div>
            <h3 className="text-base sm:text-lg lg:text-xl font-bold text-gray-900 mb-2 sm:mb-3">
              Verified Pickers
            </h3>
            <p className="text-gray-600 text-sm sm:text-base leading-relaxed">
              Trusted experts with proven track records
            </p>
          </div>

          <div className="group bg-white p-5 sm:p-6 lg:p-8 rounded-xl sm:rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-2">
            <div className="w-10 h-10 sm:w-12 sm:h-12 lg:w-14 lg:h-14 bg-gradient-to-br from-amber-500 to-yellow-600 rounded-lg sm:rounded-xl flex items-center justify-center mb-3 sm:mb-4 lg:mb-5 shadow-lg group-hover:scale-110 transition-transform">
              <Sparkles className="w-5 h-5 sm:w-6 sm:h-6 lg:w-7 lg:h-7 text-white" />
            </div>
            <h3 className="text-base sm:text-lg lg:text-xl font-bold text-gray-900 mb-2 sm:mb-3">
              Authentic Items
            </h3>
            <p className="text-gray-600 text-sm sm:text-base leading-relaxed">
              Genuine souvenirs with quality guarantee
            </p>
          </div>
        </div>

        {profile?.user_type === "picker" && (
          <div className="relative overflow-hidden bg-gradient-to-r from-green-600 via-green-700 to-green-800 text-white rounded-2xl sm:rounded-3xl p-6 sm:p-8 lg:p-12 shadow-2xl mb-8 sm:mb-12">
            <div className="absolute top-0 right-0 w-64 h-64 bg-yellow-400 opacity-10 rounded-full -mr-32 -mt-32 animate-pulse"></div>
            <div className="absolute bottom-0 left-0 w-96 h-96 bg-yellow-400 opacity-10 rounded-full -ml-48 -mb-48 animate-pulse"></div>
            <div className="absolute top-1/4 right-1/4 text-9xl opacity-5">
              💰
            </div>
            <div className="absolute bottom-1/4 left-1/4 text-9xl opacity-5">
              💸
            </div>
            <div className="relative z-10">
              <div className="flex items-center gap-4 mb-6">
                <div className="bg-gradient-to-br from-yellow-400 to-yellow-500 p-4 rounded-2xl shadow-xl animate-bounce">
                  <Package className="w-12 h-12 text-green-900" />
                </div>
                <div>
                  <h2 className="text-5xl font-black bg-gradient-to-r from-yellow-300 via-yellow-200 to-white bg-clip-text text-transparent">
                    Start Making Money NOW!
                  </h2>
                  <p className="text-yellow-300 text-lg font-bold mt-1">
                    🚀 Your Next Income Stream Awaits
                  </p>
                </div>
              </div>
              <p className="text-green-50 text-2xl mb-4 max-w-3xl leading-relaxed font-semibold">
                <span className="text-yellow-300 font-black text-3xl">
                  $500 - $5,000+
                </span>{" "}
                per month! Complete your profile, browse paid requests, and
                start earning today. Pickers are making{" "}
                <span className="text-yellow-300 font-bold">real money</span>{" "}
                bringing souvenirs from their travels!
              </p>
              <div className="bg-orange-400 bg-opacity-90 backdrop-blur-sm p-4 rounded-xl border-2 border-orange-300 mb-8 max-w-3xl">
                <p className="text-green-900 text-sm font-bold flex items-center gap-2">
                  <span className="text-lg">⚠️</span>
                  <span>
                    Note: A 10% platform commission applies to all sales
                  </span>
                </p>
              </div>
              <div className="grid md:grid-cols-3 gap-4 mb-8 max-w-4xl">
                <div className="bg-yellow-400 bg-opacity-20 backdrop-blur-sm p-4 rounded-xl border-2 border-yellow-400 border-opacity-40">
                  <div className="text-3xl font-black text-yellow-300 mb-2">
                    💵 Flexible
                  </div>
                  <p className="text-green-100">Work on your own schedule</p>
                </div>
                <div className="bg-yellow-400 bg-opacity-20 backdrop-blur-sm p-4 rounded-xl border-2 border-yellow-400 border-opacity-40">
                  <div className="text-3xl font-black text-yellow-300 mb-2">
                    🌍 Global
                  </div>
                  <p className="text-green-100">
                    Earn from anywhere you travel
                  </p>
                </div>
                <div className="bg-yellow-400 bg-opacity-20 backdrop-blur-sm p-4 rounded-xl border-2 border-yellow-400 border-opacity-40">
                  <div className="text-3xl font-black text-yellow-300 mb-2">
                    📈 Unlimited
                  </div>
                  <p className="text-green-100">No cap on your earnings</p>
                </div>
              </div>
              <div className="flex gap-4 flex-wrap">
                <button
                  onClick={() => onViewChange("profile")}
                  className="bg-gradient-to-r from-yellow-400 to-yellow-500 text-green-900 px-10 py-5 rounded-xl font-black text-xl hover:from-yellow-300 hover:to-yellow-400 transition-all duration-300 shadow-2xl hover:shadow-yellow-400/50 transform hover:scale-105 flex items-center gap-3 animate-pulse"
                >
                  💰 Start Earning Now
                  <ArrowRight className="w-6 h-6" />
                </button>
                <button
                  onClick={() => onViewChange("desires")}
                  className="bg-white bg-opacity-20 backdrop-blur-sm text-white px-8 py-5 rounded-xl font-bold text-lg hover:bg-opacity-30 transition-all duration-300 border-2 border-yellow-400 border-opacity-60 shadow-lg"
                >
                  Browse Paid Requests
                </button>
              </div>
            </div>
          </div>
        )}

        {profile?.user_type === "client" && (
          <div className="relative overflow-hidden bg-gradient-to-r from-orange-500 via-orange-600 to-orange-700 text-white rounded-2xl sm:rounded-3xl p-6 sm:p-8 lg:p-12 shadow-2xl">
            <div className="absolute top-0 right-0 w-64 h-64 bg-white opacity-5 rounded-full -mr-32 -mt-32"></div>
            <div className="absolute bottom-0 left-0 w-96 h-96 bg-white opacity-5 rounded-full -ml-48 -mb-48"></div>
            <div className="relative z-10">
              <div className="flex items-center gap-4 mb-6">
                <div className="bg-white bg-opacity-20 p-4 rounded-2xl">
                  <ShoppingBag className="w-12 h-12" />
                </div>
                <h2 className="text-4xl font-extrabold">How It Works</h2>
              </div>
              <div className="grid md:grid-cols-3 gap-8 mt-8">
                <div className="bg-white bg-opacity-10 p-6 rounded-2xl backdrop-blur-sm">
                  <div className="text-5xl font-extrabold mb-4 text-white">
                    1
                  </div>
                  <h3 className="font-bold text-xl mb-3">Browse Listings</h3>
                  <p className="text-orange-100 text-lg leading-relaxed">
                    Explore unique, ready-to-buy souvenirs from verified pickers
                    around the world
                  </p>
                </div>
                <div className="bg-white bg-opacity-10 p-6 rounded-2xl backdrop-blur-sm">
                  <div className="text-5xl font-extrabold mb-4 text-white">
                    2
                  </div>
                  <h3 className="font-bold text-xl mb-3">Buy & Checkout</h3>
                  <p className="text-orange-100 text-lg leading-relaxed">
                    Shipping is calculated automatically at checkout — pay
                    securely with escrow protection
                  </p>
                </div>
                <div className="bg-white bg-opacity-10 p-6 rounded-2xl backdrop-blur-sm">
                  <div className="text-5xl font-extrabold mb-4 text-white">
                    3
                  </div>
                  <h3 className="font-bold text-xl mb-3">Track & Receive</h3>
                  <p className="text-orange-100 text-lg leading-relaxed">
                    Follow your order as it ships and confirm delivery once your
                    souvenir arrives
                  </p>
                </div>
              </div>
              <div className="mt-8 flex gap-4">
                <button
                  onClick={() => onViewChange("listings")}
                  className="bg-white text-orange-600 px-8 py-4 rounded-xl font-bold text-lg hover:bg-orange-50 transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 flex items-center gap-2"
                >
                  Get Started Now
                  <ArrowRight className="w-5 h-5" />
                </button>
                <button
                  onClick={() => onViewChange("pickers")}
                  className="bg-orange-400 text-white px-8 py-4 rounded-xl font-bold text-lg hover:bg-orange-300 transition-all duration-300 border-2 border-white border-opacity-30"
                >
                  Meet Our Pickers
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
