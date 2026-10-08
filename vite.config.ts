import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // GitHub Pages publica em luizmarinello.github.io/blitz/ (workflow .github/workflows/pages.yml)
  base: process.env.GITHUB_PAGES ? '/blitz/' : '/',
  server: { port: 3000, strictPort: true },   // 3000 = Site URL padrão do Supabase Auth
})
