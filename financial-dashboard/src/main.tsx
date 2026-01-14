import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

// Rewrite API calls from localhost to deployed API URL at runtime
const VITE_API_URL = (import.meta as any)?.env?.VITE_API_URL as string | undefined;
if (typeof window !== 'undefined' && VITE_API_URL) {
  try {
    const fromBase = 'http://localhost:3001';
    const toBase = VITE_API_URL.replace(/\/api\/?$/, '');
    const origFetch = window.fetch.bind(window);
    window.fetch = (input: RequestInfo | URL, init?: RequestInit) => {
      let url = typeof input === 'string' ? input : (input as any).url || (input as URL).toString();
      if (typeof url === 'string' && url.startsWith(fromBase + '/')) {
        url = url.replace(fromBase, toBase);
        input = typeof input === 'string' ? url : new Request(url, input as RequestInit);
      }
      return origFetch(input as any, init);
    };
  } catch {
    // ignore
  }
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
