import { useEffect, useState, type ReactNode } from 'react';
import { CreditCard, FolderKanban, Repeat } from 'lucide-react';

type ImageSlide = { kind: 'image'; src: string; alt: string; caption: string };
type IllustrationSlide = { kind: 'illustration'; caption: string; render: () => ReactNode };
type Slide = ImageSlide | IllustrationSlide;

// Allow overriding screenshot URLs via env at build-time
const SS = (name: string, fallback: string) => (import.meta as any)?.env?.[name] || fallback;
const BASE = ((import.meta as any)?.env?.BASE_URL as string) || '/';

// Crisp, scalable illustrations to replace lower-quality screenshots
function InvoicesIllustration() {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-indigo-50 via-white to-blue-50 dark:from-slate-900 dark:via-slate-950 dark:to-slate-900">
      <div className="w-[85%] max-w-5xl rounded-2xl bg-white dark:bg-slate-900 shadow-xl ring-1 ring-black/5 dark:ring-white/10 p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-blue-600" /> Invoices
          </div>
          <div className="flex gap-2">
            <div className="rounded-lg border px-3 py-1 text-sm text-slate-600 dark:text-slate-300">New Customer</div>
            <div className="rounded-lg bg-blue-600 text-white px-3 py-1 text-sm">New Invoice</div>
          </div>
        </div>
        <div className="grid gap-4">
          <div className="rounded-xl border bg-white dark:bg-slate-900 p-4">
            <div className="grid grid-cols-6 text-xs text-slate-500">
              <div>NUMBER</div><div>CUSTOMER</div><div>ISSUE</div><div>DUE</div><div className="text-right">TOTAL</div><div className="text-right">STATUS</div>
            </div>
            <div className="mt-3 grid grid-cols-6 items-center text-sm">
              <div>#7</div><div>Customer 1</div><div>04/09/2025</div><div>11/09/2025</div><div className="text-right">$2,516.00</div>
              <div className="text-right"><span className="inline-flex items-center rounded-full bg-emerald-100 text-emerald-700 px-2 py-0.5 text-xs">Paid</span></div>
            </div>
          </div>
          <div className="rounded-xl border bg-white dark:bg-slate-900 p-4">
            <div className="text-lg font-semibold mb-2">Customers</div>
            <div className="text-sm text-slate-600 dark:text-slate-300">Customer 1</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function ProjectsIllustration() {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-violet-50 via-white to-fuchsia-50 dark:from-slate-900 dark:via-slate-950 dark:to-slate-900">
      <div className="w-[90%] max-w-5xl rounded-2xl bg-white dark:bg-slate-900 shadow-xl ring-1 ring-black/5 dark:ring-white/10 p-6">
        <div className="text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-2 mb-4">
          <FolderKanban className="h-6 w-6 text-violet-600" /> Projects
        </div>
        <div className="space-y-3">
          {[{name:'Office Renovation',spent:25,budget:100,status:'Active',color:'bg-emerald-500'},
            {name:'Marketing Campaign',spent:40,budget:80,status:'On Hold',color:'bg-amber-500'},
            {name:'Mobile App',spent:100,budget:100,status:'Completed',color:'bg-blue-600'}].map((p,i)=> (
            <div key={i} className="rounded-xl border p-4">
              <div className="flex items-center justify-between text-sm font-medium">
                <div>{p.name}</div>
                <div className="text-slate-500">${p.spent*250}.00 / ${p.budget*250}.00</div>
              </div>
              <div className="mt-2 h-2 rounded-full bg-slate-200 dark:bg-slate-800 overflow-hidden">
                <div className={`h-full ${p.color}`} style={{width: `${Math.min(100,(p.spent/p.budget)*100)}%`}} />
              </div>
              <div className="mt-2 text-xs"><span className="inline-flex items-center rounded-full bg-slate-100 text-slate-700 px-2 py-0.5">{p.status}</span></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function RecurringIllustration() {
  return (
    <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-teal-50 via-white to-sky-50 dark:from-slate-900 dark:via-slate-950 dark:to-slate-900">
      <div className="w-[92%] max-w-5xl rounded-2xl bg-white dark:bg-slate-900 shadow-xl ring-1 ring-black/5 dark:ring-white/10 p-6">
        <div className="text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-2 mb-4">
          <Repeat className="h-6 w-6 text-teal-600" /> Recurring Payments
        </div>
        <div className="grid grid-cols-4 gap-3 mb-4">
          {['4 Active','0 Paused','$1,095.67 Monthly','0 This Week'].map((t,i)=>(
            <div key={i} className="rounded-xl border p-3 text-sm text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-900">{t}</div>
          ))}
        </div>
        <div className="grid gap-2 text-sm">
          {['netflix','tenis','chatgpt'].map((n,i)=>(
            <div key={i} className="rounded-lg border p-3 flex items-center justify-between">
              <div>
                <div className="font-medium capitalize">{n}</div>
                <div className="text-xs text-slate-500">Monthly</div>
              </div>
              <div className="text-slate-700 dark:text-slate-200">${[99,166.67,400][i].toLocaleString()}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

const slides: Slide[] = [
  { kind: 'image', src: SS('VITE_SS_DASHBOARD', `${BASE}screenshots/dashboard.png`), alt: 'Dashboard overview', caption: 'Dashboard' },
  { kind: 'illustration', caption: 'Invoices', render: () => <InvoicesIllustration /> },
  { kind: 'illustration', caption: 'Projects', render: () => <ProjectsIllustration /> },
  { kind: 'illustration', caption: 'Recurring Payments', render: () => <RecurringIllustration /> },
];

function variants(path: string): string[] {
  const baseDir = path.slice(0, path.lastIndexOf('/') + 1);
  const nameWithExt = path.substring(baseDir.length);
  const name = nameWithExt.replace(/\.(png|jpg|jpeg|svg)$/i, '');
  const cap = name.charAt(0).toUpperCase() + name.slice(1);
  return [
    path,
    // svg first (current default)
    `${baseDir}${name}.svg`,
    `${baseDir}${cap}.svg`,
    `${baseDir}${name}.png`,
    `${baseDir}${name}.jpg`,
    // Handle accidental double extensions (e.g., dashboard.png.png)
    `${baseDir}${name}.png.png`,
    `${baseDir}${name}.jpg.jpg`,
    `${baseDir}${cap}.png`,
    `${baseDir}${cap}.jpg`,
    `${baseDir}${cap}.png.png`,
    `${baseDir}${cap}.jpg.jpg`,
  ];
}

async function resolveSrc(cands: string[], timeoutMs = 4000): Promise<string | null> {
  for (const url of cands) {
    const ok = await new Promise<boolean>((resolve) => {
      const img = new Image();
      const t = setTimeout(() => resolve(false), timeoutMs);
      img.onload = () => { clearTimeout(t); resolve(true); };
      img.onerror = () => { clearTimeout(t); resolve(false); };
      img.src = url + (url.includes('?') ? '&' : '?') + 'v=' + Date.now(); // bypass CDN cache once
    });
    if (ok) return url;
  }
  return null;
}

export default function AppCarousel() {
  const [index, setIndex] = useState(0);
  const [resolved, setResolved] = useState<(string | null)[]>(slides.map(() => null));
  const [loading, setLoading] = useState(true);
  const next = () => setIndex((i) => (i + 1) % slides.length);
  const prev = () => setIndex((i) => (i - 1 + slides.length) % slides.length);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const outs: (string | null)[] = [];
      for (const s of slides) {
        if (s.kind === 'image') {
          const src = await resolveSrc(variants(s.src));
          outs.push(src);
        } else {
          outs.push(null);
        }
      }
      if (!cancelled) {
        setResolved(outs);
        setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  return (
    <div className="relative w-full">
      <div className="overflow-hidden rounded-xl ring-1 ring-black/5 dark:ring-white/10 bg-white dark:bg-gray-900">
        <div className="relative aspect-[16/9] w-full">
          {(() => {
            const s = slides[index];
            if (s.kind === 'illustration') return s.render();
            if (!loading && resolved[index]) {
              return (
                <img
                  key={(resolved[index] as string) + '-' + index}
                  src={resolved[index] as string}
                  alt={s.alt}
                  loading="lazy"
                  className="absolute inset-0 h-full w-full object-cover"
                />
              );
            }
            return (
              <div className="absolute inset-0 flex items-center justify-center bg-[radial-gradient(ellipse_at_center,_#eef2ff,_#fff)] dark:bg-gray-900 text-center p-8">
                <div className="text-sm text-slate-600 max-w-md">Loading preview…</div>
              </div>
            );
          })()}
        </div>
      </div>

      <button
        onClick={prev}
        className="absolute left-3 top-1/2 -translate-y-1/2 rounded-full bg-white/80 dark:bg-gray-800/80 px-3 py-2 text-sm ring-1 ring-black/5 dark:ring-white/10 hover:bg-white dark:hover:bg-gray-800"
        aria-label="Previous screenshot"
      >
        ‹
      </button>
      <button
        onClick={next}
        className="absolute right-3 top-1/2 -translate-y-1/2 rounded-full bg-white/80 dark:bg-gray-800/80 px-3 py-2 text-sm ring-1 ring-black/5 dark:ring-white/10 hover:bg-white dark:hover:bg-gray-800"
        aria-label="Next screenshot"
      >
        ›
      </button>

      <div className="mt-3 flex items-center justify-center gap-2">
        {slides.map((_, i) => (
          <button
            key={i}
            onClick={() => setIndex(i)}
            className={`h-2 w-2 rounded-full ${i === index ? 'bg-blue-600' : 'bg-gray-300 dark:bg-gray-600'}`}
            aria-label={`Go to slide ${i + 1}`}
          />
        ))}
      </div>

      <div className="mt-2 text-center text-xs text-slate-500">{slides[index].caption}</div>
    </div>
  );
}
