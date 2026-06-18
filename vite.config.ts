import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
  base: '/',
  server: {
    host: true,
  },
  publicDir: 'public',
  build: {
    copyPublicDir: true,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('react') || id.includes('react-dom')) {
              return 'react-vendor';
            }
            if (id.includes('@supabase')) {
              return 'supabase-vendor';
            }
            if (id.includes('@stripe')) {
              return 'stripe-vendor';
            }
            if (id.includes('lucide-react')) {
              return 'icons-vendor';
            }
            return 'vendor';
          }
          if (id.includes('src/components/')) {
            const componentName = id.split('/components/')[1]?.split('.')[0];
            if (componentName && ['HomeView', 'AuthForm', 'Header', 'Sidebar', 'Footer'].includes(componentName)) {
              return 'core-components';
            }
          }
        },
      },
    },
    cssCodeSplit: true,
    minify: 'esbuild',
    sourcemap: false,
    chunkSizeWarningLimit: 1000,
  },
});
