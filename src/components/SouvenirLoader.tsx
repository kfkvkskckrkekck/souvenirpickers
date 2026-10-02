type SouvenirLoaderProps = {
  isLoading?: boolean;
  message?: string;
  fullScreen?: boolean;
};

export default function SouvenirLoader({
  isLoading = true,
  message = "Loading your next adventure...",
  fullScreen = false,
}: SouvenirLoaderProps) {
  if (!isLoading) return null;

  return (
    <>
      <style>{`
        @keyframes souvenirSpin {
          from {
            transform: rotate(0deg);
          }
          to {
            transform: rotate(360deg);
          }
        }

        @keyframes souvenirSpinReverse {
          from {
            transform: rotate(360deg);
          }
          to {
            transform: rotate(0deg);
          }
        }

        @keyframes souvenirDot {
          0%,
          100% {
            transform: translateY(0);
            opacity: 0.35;
          }

          50% {
            transform: translateY(-5px);
            opacity: 1;
          }
        }

        @keyframes souvenirFloat {
          0%,
          100% {
            transform: translateY(0) scale(1);
          }

          50% {
            transform: translateY(-5px) scale(1.04);
          }
        }

        @keyframes souvenirGlow {
          0% {
            opacity: 0.35;
            filter: blur(14px);
          }

          50% {
            opacity: 0.7;
            filter: blur(20px);
          }

          100% {
            opacity: 0.35;
            filter: blur(14px);
          }
        }

        .souvenir-loader-ring {
          animation: souvenirSpin 3.5s linear infinite;
        }

        .souvenir-loader-ring-reverse {
          animation: souvenirSpinReverse 5s linear infinite;
        }

        .souvenir-loader-glow {
          animation: souvenirGlow 2.5s ease-in-out infinite;
        }

        .souvenir-loader-dot {
          animation: souvenirDot 1.2s ease-in-out infinite;
        }

        .souvenir-loader-float {
          animation: souvenirFloat 2.4s ease-in-out infinite;
        }

        @media (prefers-reduced-motion: reduce) {
          .souvenir-loader-ring,
          .souvenir-loader-ring-reverse,
          .souvenir-loader-glow,
          .souvenir-loader-dot,
          .souvenir-loader-float {
            animation: none !important;
          }
        }
      `}</style>

      <div
        className={
          fullScreen
            ? "fixed inset-0 z-[9999] flex min-h-screen items-center justify-center overflow-hidden bg-gradient-to-br from-blue-50 via-white to-orange-50"
            : "relative flex w-full items-center justify-center overflow-hidden py-8"
        }
      >
        {/* Soft background glow */}
        <div
          className="
            souvenir-loader-glow
            pointer-events-none
            absolute
            h-36
            w-36
            sm:h-44
            sm:w-44
            rounded-full
            bg-gradient-to-r
            from-blue-500
            via-orange-400
            to-green-500
            opacity-40
            blur-2xl
          "
        />

        <div className="relative flex w-full max-w-[220px] flex-col items-center px-4">
          {/* =====================================================
              MAIN CHARACTER / LOADER
          ===================================================== */}
          <div className="relative flex h-28 w-28 items-center justify-center sm:h-32 sm:w-32">
            {/* Large rotating gradient ring */}
            <div
              className="souvenir-loader-ring absolute inset-[6px] rounded-full p-[3px]"
              style={{
                background:
                  "conic-gradient(from 0deg, #1677ff 0deg, #1677ff 115deg, #ff7a00 180deg, #ff7a00 235deg, #20b95a 300deg, #20b95a 345deg, #1677ff 360deg)",
                WebkitMask:
                  "linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0)",
                WebkitMaskComposite: "xor",
                maskComposite: "exclude",
              }}
            />

            {/* Bright moving glow ring */}
            <div
              className="souvenir-loader-ring absolute inset-[2px] rounded-full opacity-80 blur-[1px]"
              style={{
                background:
                  "conic-gradient(from 0deg, transparent 0deg, transparent 25deg, rgba(22,119,255,.9) 55deg, rgba(255,122,0,.95) 105deg, rgba(32,185,90,.95) 155deg, transparent 210deg, transparent 360deg)",
                WebkitMask:
                  "linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0)",
                WebkitMaskComposite: "xor",
                maskComposite: "exclude",
                padding: "2px",
              }}
            />

            {/* Reverse dashed travel orbit */}
            <div className="souvenir-loader-ring-reverse absolute inset-[12px] rounded-full border border-dashed border-blue-300/50" />

            {/* Floating travel dots */}
            <span className="souvenir-loader-float absolute left-[6%] top-[30%] h-1.5 w-1.5 rounded-full bg-orange-500 shadow-md shadow-orange-300" />

            <span
              className="souvenir-loader-float absolute right-[7%] top-[40%] h-2 w-2 rounded-full bg-green-500 shadow-md shadow-green-300"
              style={{ animationDelay: "0.5s" }}
            />

            <span
              className="souvenir-loader-float absolute bottom-[19%] left-[14%] h-1.5 w-1.5 rounded-full bg-blue-500 shadow-md shadow-blue-300"
              style={{ animationDelay: "1s" }}
            />

            {/* Character image */}
            <img
              src="/loader/loading-character.png"
              alt="Souvenir Picker"
              className="relative z-10 h-full w-full object-contain drop-shadow-[0_12px_20px_rgba(30,80,130,0.18)]"
              draggable={false}
            />
          </div>

          {/* =====================================================
              LOADING TEXT
          ===================================================== */}
          <div className="mt-2 text-center sm:mt-3">
            <h2 className="text-sm font-black tracking-tight text-slate-900 sm:text-base">
              {message}
            </h2>

            <p className="mx-auto mt-1.5 max-w-[200px] text-xs font-medium leading-relaxed text-slate-500">
              Authentic souvenirs. Real stories.
            </p>

            {/* Animated loading dots */}
            <div className="mt-3 flex items-center justify-center gap-1.5">
              <span className="souvenir-loader-dot h-2 w-2 rounded-full bg-blue-600 shadow-sm shadow-blue-300" />

              <span
                className="souvenir-loader-dot h-2 w-2 rounded-full bg-orange-500 shadow-sm shadow-orange-300"
                style={{ animationDelay: "0.2s" }}
              />

              <span
                className="souvenir-loader-dot h-2 w-2 rounded-full bg-green-500 shadow-sm shadow-green-300"
                style={{ animationDelay: "0.4s" }}
              />
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
