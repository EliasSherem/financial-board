import { useEffect, useMemo, useRef, useState, type MutableRefObject } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Pause, Play } from 'lucide-react';
import * as THREE from 'three';
import { useI18n } from '../contexts/I18nContext';
import './LandingHeroScene.css';

type Language = 'en' | 'es';
type Variant = 'background' | 'side-hero';
type ValueRef = MutableRefObject<number>;
type MouseTarget = MutableRefObject<{ enabled: boolean; x: number; y: number }>;
const DURATION = 16;
const MOMENTUM_START = 10.3;
const MOMENTUM_BADGE = '/landing/momentum-badge.svg';
const words = {
  es: { steps: ['Organiza', 'Entiende', 'Avanza'], demo: 'DEMO · MXN', overview: 'Tu resumen', transactions: 'Movimientos', groceries: 'Supermercado', food: 'Alimentación', salary: 'Salario', income: 'Ingresos', electricity: 'Electricidad', services: 'Servicios', spending: 'Gastos por categoría', budget: 'Tu presupuesto', momentum: 'Tu progreso, visible.', example: 'Datos de ejemplo', pause: 'Pausar animación', play: 'Reanudar animación', description: 'Demostración 3D de FinSight: los movimientos se organizan, los gráficos muestran tus finanzas y una insignia representa tu progreso en Momentum. Los datos son de ejemplo.' },
  en: { steps: ['Organize', 'Understand', 'Advance'], demo: 'DEMO · MXN', overview: 'Your overview', transactions: 'Transactions', groceries: 'Groceries', food: 'Food', salary: 'Salary', income: 'Income', electricity: 'Electricity', services: 'Services', spending: 'Spending by category', budget: 'Your budget', momentum: 'See your progress.', example: 'Example data', pause: 'Pause animation', play: 'Resume animation', description: 'A 3D FinSight demonstration: transactions come together, charts reveal your finances, and a badge represents your progress in Momentum. All figures are examples.' },
} as const;
const smooth = (start: number, end: number, value: number) => { const t = THREE.MathUtils.clamp((value - start) / (end - start), 0, 1); return t * t * (3 - 2 * t); };
const easeOut = (value: number) => 1 - (1 - THREE.MathUtils.clamp(value, 0, 1)) ** 4;
const phaseTime = (time: ValueRef) => time.current % DURATION;

function webglAvailable() {
  try {
    const context = document.createElement('canvas').getContext('webgl2');
    if (!context) return false;
    context.getExtension('WEBGL_lose_context')?.loseContext();
    return true;
  } catch { return false; }
}

function canvasTexture(width: number, height: number, draw: (context: CanvasRenderingContext2D) => void) {
  const canvas = document.createElement('canvas');
  canvas.width = width; canvas.height = height;
  const context = canvas.getContext('2d');
  if (context) draw(context);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

function panelBackground(context: CanvasRenderingContext2D, width: number, height: number, radius: number) {
  const fill = context.createLinearGradient(0, 0, width, height);
  fill.addColorStop(0, '#203650'); fill.addColorStop(0.55, '#142740'); fill.addColorStop(1, '#142139');
  context.fillStyle = fill; context.strokeStyle = 'rgba(175,204,243,.32)'; context.lineWidth = 2;
  context.beginPath(); context.roundRect(2, 2, width - 4, height - 4, radius); context.fill(); context.stroke();
}

function panelGeometry(width: number, height: number, depth: number) {
  const radius = Math.min(height * 0.2, 0.17), l = -width / 2, r = width / 2, b = -height / 2, t = height / 2;
  const shape = new THREE.Shape();
  shape.moveTo(l + radius, b); shape.lineTo(r - radius, b); shape.quadraticCurveTo(r, b, r, b + radius);
  shape.lineTo(r, t - radius); shape.quadraticCurveTo(r, t, r - radius, t); shape.lineTo(l + radius, t);
  shape.quadraticCurveTo(l, t, l, t - radius); shape.lineTo(l, b + radius); shape.quadraticCurveTo(l, b, l + radius, b);
  return new THREE.ExtrudeGeometry(shape, { depth, steps: 1, bevelEnabled: true, bevelSize: 0.013, bevelThickness: 0.012, bevelSegments: 3, curveSegments: 10 });
}

function Surface({ width, height, texture, opacity, depth = 0.06, color = '#365373' }: { width: number; height: number; texture?: THREE.Texture; opacity?: ValueRef; depth?: number; color?: string }) {
  const geometry = useMemo(() => panelGeometry(width, height, depth), [width, height, depth]);
  const edge = useRef<THREE.MeshStandardMaterial>(null), face = useRef<THREE.MeshBasicMaterial>(null);
  useEffect(() => () => geometry.dispose(), [geometry]);
  useFrame(() => { const value = opacity?.current ?? 1; if (edge.current) edge.current.opacity = value; if (face.current) face.current.opacity = value; });
  return <>
    <mesh geometry={geometry}><meshStandardMaterial ref={edge} color={color} metalness={0.55} roughness={0.26} transparent depthWrite={false} /></mesh>
    {texture && <mesh position={[0, 0, depth + 0.014]}><planeGeometry args={[width, height]} /><meshBasicMaterial ref={face} map={texture} transparent depthWrite={false} toneMapped={false} /></mesh>}
  </>;
}

function TextureFace({ texture, width, height, opacity, position = [0, 0, 0] }: { texture: THREE.Texture; width: number; height: number; opacity: ValueRef; position?: [number, number, number] }) {
  const material = useRef<THREE.MeshBasicMaterial>(null);
  useFrame(() => { if (material.current) material.current.opacity = opacity.current; });
  return <mesh position={position}><planeGeometry args={[width, height]} /><meshBasicMaterial ref={material} map={texture} transparent depthWrite={false} toneMapped={false} /></mesh>;
}

function labelTexture(title: string, subtitle = '', color = '#dfeaff') {
  return canvasTexture(900, 240, context => {
    context.textAlign = 'center'; context.textBaseline = 'middle'; context.fillStyle = color;
    context.font = '500 53px system-ui, -apple-system, sans-serif'; context.fillText(title, 450, subtitle ? 80 : 120);
    if (subtitle) { context.fillStyle = '#a4b8d3'; context.font = '400 35px system-ui, -apple-system, sans-serif'; context.fillText(subtitle, 450, 160); }
  });
}

function Transaction({ index, time, compact, language }: { index: number; time: ValueRef; compact: boolean; language: Language }) {
  const group = useRef<THREE.Group>(null), opacity = useRef(0);
  const texture = useMemo(() => {
    const copy = words[language];
    const rows = [{ title: copy.groceries, category: copy.food, amount: '−$480.00', color: '#bcabeb', icon: '−' }, { title: copy.salary, category: copy.income, amount: '+$32,000.00', color: '#9bcebc', icon: '+' }, { title: copy.electricity, category: copy.services, amount: '−$1,150.00', color: '#9cc5f0', icon: '−' }];
    const row = rows[index];
    return canvasTexture(1100, 230, context => {
      panelBackground(context, 1100, 230, 40);
      context.fillStyle = `${row.color}22`; context.beginPath(); context.roundRect(38, 55, 120, 120, 32); context.fill();
      context.fillStyle = row.color; context.font = '400 62px system-ui, sans-serif'; context.textAlign = 'center'; context.textBaseline = 'middle'; context.fillText(row.icon, 98, 110);
      context.textAlign = 'left'; context.fillStyle = '#edf3fe'; context.font = '500 52px system-ui, -apple-system, sans-serif'; context.fillText(row.title, 194, 91);
      context.fillStyle = '#9fb3ce'; context.font = '400 37px system-ui, -apple-system, sans-serif'; context.fillText(row.category, 194, 148);
      context.textAlign = 'right'; context.fillStyle = index === 1 ? '#abd9c8' : '#d6e4f7'; context.font = '500 50px system-ui, -apple-system, sans-serif'; context.fillText(row.amount, 1053, 114);
    });
  }, [index, language]);
  useEffect(() => () => texture.dispose(), [texture]);
  useFrame(() => {
    if (!group.current) return;
    const t = phaseTime(time), start = index * 0.68;
    const enter = easeOut((t - start) / 1.65), exit = smooth(4.25 + index * 0.13, 5.15 + index * 0.13, t);
    opacity.current = smooth(start, start + 0.38, t) * (1 - exit);
    group.current.visible = opacity.current > 0.002;
    const side = index % 2 ? 1 : -1, destinationY = 0.47 - index * 0.59;
    group.current.position.set(side * (compact ? 0.6 : 2.6) * (1 - enter) - exit * 0.48, destinationY + (compact ? 1.0 : 0.45) * (1 - enter) + exit * 0.18, 0.2 + (1 - enter) * 0.8 - exit * 0.2);
    group.current.rotation.set(0.025 * (1 - enter), side * 0.52 * (1 - enter) - exit * 0.28, side * 0.09 * (1 - enter));
    group.current.scale.setScalar((0.8 + enter * 0.2) * (1 - exit * 0.15));
  });
  return <group ref={group}><Surface width={2.94} height={0.56} texture={texture} opacity={opacity} depth={0.055} /></group>;
}

function FinancialChart({ time, language }: { time: ValueRef; language: Language }) {
  const group = useRef<THREE.Group>(null), opacity = useRef(0);
  const bars = useRef<Array<THREE.Mesh | null>>([]), barMaterials = useRef<Array<THREE.MeshStandardMaterial | null>>([]);
  const lineMaterial = useRef<THREE.MeshBasicMaterial>(null), ringMaterial = useRef<THREE.MeshStandardMaterial>(null), ringTrack = useRef<THREE.MeshBasicMaterial>(null);
  const point = useRef<THREE.Mesh>(null), pointMaterial = useRef<THREE.MeshBasicMaterial>(null);
  const curve = useMemo(() => new THREE.CatmullRomCurve3([new THREE.Vector3(-1.43, -0.29, 0.17), new THREE.Vector3(-1.08, -0.02, 0.17), new THREE.Vector3(-0.74, -0.15, 0.17), new THREE.Vector3(-0.42, 0.21, 0.17), new THREE.Vector3(-0.08, 0.11, 0.17)]), []);
  const line = useMemo(() => new THREE.TubeGeometry(curve, 64, 0.014, 5, false), [curve]);
  const arc = useMemo(() => new THREE.TorusGeometry(0.46, 0.047, 10, 90, Math.PI * 2 * 0.62), []);
  const labels = useMemo(() => {
    const copy = words[language];
    return [labelTexture(copy.spending), labelTexture(copy.budget), labelTexture('62%', copy.food), labelTexture('$2,480 / $4,000')];
  }, [language]);
  useEffect(() => () => { line.dispose(); arc.dispose(); }, [line, arc]);
  useEffect(() => () => labels.forEach(texture => texture.dispose()), [labels]);
  useFrame(() => {
    if (!group.current) return;
    const t = phaseTime(time), enter = smooth(4.55, 5.55, t), exit = smooth(9.05, 10.15, t);
    opacity.current = enter * (1 - exit); group.current.visible = opacity.current > 0.002;
    group.current.position.set(-exit * 0.18, (1 - enter) * -0.2 + exit * 0.12, 0.18 - exit * 0.22);
    group.current.rotation.y = -exit * 0.2; group.current.scale.setScalar(0.88 + enter * 0.12 - exit * 0.12);
    const heights = [0.37, 0.79, 0.51, 0.98];
    bars.current.forEach((bar, index) => {
      if (!bar) return;
      const height = Math.max(0.001, heights[index] * easeOut((t - 5 - index * 0.22) / 1.3));
      bar.scale.y = height; bar.position.y = -0.71 + height / 2;
      if (barMaterials.current[index]) barMaterials.current[index]!.opacity = opacity.current;
    });
    const traced = smooth(5.8, 8.05, t);
    line.setDrawRange(0, Math.floor((line.index?.count ?? 0) * traced / 30) * 30);
    arc.setDrawRange(0, Math.floor((arc.index?.count ?? 0) * smooth(5.65, 7.85, t) / 60) * 60);
    if (point.current) { curve.getPointAt(traced, point.current.position); point.current.visible = traced > 0.001; }
    if (lineMaterial.current) lineMaterial.current.opacity = opacity.current * 0.9;
    if (ringMaterial.current) ringMaterial.current.opacity = opacity.current;
    if (ringTrack.current) ringTrack.current.opacity = opacity.current * 0.22;
    if (pointMaterial.current) pointMaterial.current.opacity = opacity.current;
  });
  return <group ref={group}>
    <TextureFace texture={labels[0]} width={1.69} height={0.45} opacity={opacity} position={[-0.78, 0.66, 0.1]} />
    <TextureFace texture={labels[1]} width={1.36} height={0.36} opacity={opacity} position={[0.97, 0.65, 0.1]} />
    {[0, 1, 2, 3].map(index => <mesh key={index} ref={node => { bars.current[index] = node; }} position={[-1.42 + index * 0.36, -0.7, 0.035]}><boxGeometry args={[0.21, 1, 0.13]} /><meshStandardMaterial ref={material => { barMaterials.current[index] = material; }} color={['#719ad2', '#9d92ce', '#87b6aa', '#85acd8'][index]} metalness={0.3} roughness={0.3} transparent depthWrite={false} /></mesh>)}
    <mesh geometry={line}><meshBasicMaterial ref={lineMaterial} color="#c1dafa" transparent depthWrite={false} /></mesh>
    <mesh ref={point}><sphereGeometry args={[0.044, 16, 16]} /><meshBasicMaterial ref={pointMaterial} color="#e7f2ff" transparent depthWrite={false} /></mesh>
    <group position={[0.98, -0.04, 0.15]} rotation={[0, 0, Math.PI / 2]} scale={[1, -1, 1]}>
      <mesh><torusGeometry args={[0.46, 0.033, 10, 90]} /><meshBasicMaterial ref={ringTrack} color="#7f9abc" transparent depthWrite={false} /></mesh>
      <mesh geometry={arc}><meshStandardMaterial ref={ringMaterial} color="#9bb5ed" emissive="#4b598f" emissiveIntensity={0.22} metalness={0.3} roughness={0.24} transparent depthWrite={false} /></mesh>
    </group>
    <TextureFace texture={labels[2]} width={0.91} height={0.39} opacity={opacity} position={[0.98, -0.04, 0.23]} />
    <TextureFace texture={labels[3]} width={1.34} height={0.36} opacity={opacity} position={[0.98, -0.76, 0.12]} />
  </group>;
}

function MomentumMoment({ time, language }: { time: ValueRef; language: Language }) {
  const group = useRef<THREE.Group>(null), medal = useRef<THREE.Group>(null), opacity = useRef(0), ring = useRef<THREE.Mesh>(null), ringMaterial = useRef<THREE.MeshBasicMaterial>(null);
  const { invalidate } = useThree();
  const badge = useMemo(() => canvasTexture(512, 512, () => {}), []);
  const caption = useMemo(() => labelTexture('FinSight Momentum', words[language].momentum), [language]);
  useEffect(() => {
    let disposed = false;
    const image = new Image(512, 512);
    image.onload = () => {
      if (disposed) return;
      const canvas = badge.image as HTMLCanvasElement, context = canvas.getContext('2d');
      context?.clearRect(0, 0, 512, 512); context?.drawImage(image, 0, 0, 512, 512); badge.needsUpdate = true; invalidate();
    };
    image.src = MOMENTUM_BADGE;
    return () => { disposed = true; image.onload = null; badge.dispose(); };
  }, [badge, invalidate]);
  useEffect(() => () => caption.dispose(), [caption]);
  useFrame(() => {
    if (!group.current || !medal.current) return;
    // The chart finishes fading at 10.15s, before the single badge enters.
    const t = phaseTime(time), enter = easeOut((t - MOMENTUM_START) / 1.8), exit = smooth(14.55, 15.85, t);
    opacity.current = smooth(MOMENTUM_START, MOMENTUM_START + 0.85, t) * (1 - exit); group.current.visible = opacity.current > 0.002;
    group.current.position.set(0, (1 - enter) * -0.8 + exit * 0.12, 0.35 + enter * 0.3 - exit * 0.45);
    group.current.scale.setScalar(0.62 + enter * 0.38 - exit * 0.2);
    medal.current.rotation.set(0.04, (1 - enter) * -0.95 - 0.13 + Math.sin((t - 10) * 0.7) * 0.11, 0.025);
    if (ring.current) { ring.current.rotation.z = (t - 10) * 0.19; ring.current.scale.setScalar(0.76 + enter * 0.24); }
    if (ringMaterial.current) ringMaterial.current.opacity = opacity.current * 0.3;
  });
  return <group ref={group}>
    <mesh ref={ring} position={[0, 0.12, -0.07]}><torusGeometry args={[0.88, 0.012, 7, 96, Math.PI * 1.58]} /><meshBasicMaterial ref={ringMaterial} color="#abbbe9" transparent depthWrite={false} /></mesh>
    <group ref={medal} position={[0, 0.12, 0]}><Surface width={1.24} height={1.24} texture={badge} opacity={opacity} depth={0.13} color="#496392" /></group>
    <TextureFace texture={caption} width={2.53} height={0.67} opacity={opacity} position={[0, -0.91, 0.18]} />
  </group>;
}

function ProductPanel({ time, compact, language }: { time: ValueRef; compact: boolean; language: Language }) {
  const group = useRef<THREE.Group>(null);
  const texture = useMemo(() => canvasTexture(1200, 836, context => {
    const copy = words[language]; panelBackground(context, 1200, 836, 55);
    context.fillStyle = '#e4edf9'; context.font = '600 57px system-ui, -apple-system, sans-serif'; context.fillText('FinSight', 82, 113);
    context.fillStyle = '#93aac8'; context.font = '400 27px system-ui, -apple-system, sans-serif'; context.fillText(copy.overview, 82, 154);
    context.textAlign = 'right'; context.fillStyle = '#bacce5'; context.font = '500 22px system-ui, -apple-system, sans-serif'; context.fillText(copy.demo, 1117, 113);
    context.strokeStyle = 'rgba(165,191,224,.13)'; context.lineWidth = 2; context.beginPath(); context.moveTo(81, 191); context.lineTo(1119, 191); context.stroke();
  }), [language]);
  useEffect(() => () => texture.dispose(), [texture]);
  useFrame(() => {
    if (!group.current) return;
    const t = phaseTime(time), shift = smooth(3.8, 5.6, t), reward = smooth(9.3, 11, t), reset = smooth(14.5, 16, t);
    group.current.rotation.set(0.045 + Math.sin(t / DURATION * Math.PI * 2) * 0.025, -0.13 + shift * 0.2 - reward * 0.19 - reset * 0.01, Math.sin(t / DURATION * Math.PI * 2) * 0.014);
    group.current.position.y = Math.sin(t / DURATION * Math.PI * 2) * 0.045;
  });
  return <group ref={group}>
    <group position={[-0.1, 0.07, -0.18]} rotation={[0, 0.035, 0.028]}><Surface width={3.8} height={2.65} color="#203654" depth={0.035} /></group>
    <Surface width={3.8} height={2.65} texture={texture} depth={0.09} />
    <group position={[0, -0.08, 0.13]}>
      {[0, 1, 2].map(index => <Transaction key={index} index={index} time={time} compact={compact} language={language} />)}
      <FinancialChart time={time} language={language} />
      <MomentumMoment time={time} language={language} />
    </group>
  </group>;
}

function HeroScene({ mouseRef, variant, reducedMotion, running, language, onPhase }: { mouseRef: MouseTarget; variant: Variant; reducedMotion: boolean; running: boolean; language: Language; onPhase: (phase: number) => void }) {
  const rig = useRef<THREE.Group>(null), time = useRef(reducedMotion ? 8.4 : 0), previousPhase = useRef(-1);
  const { size, viewport } = useThree();
  const compact = size.width < 640;
  const scale = Math.min(viewport.width / (compact ? 4.65 : 6.4), viewport.height / 3.75) * 0.97;
  useFrame((_, delta) => {
    if (!rig.current) return;
    const elapsed = running && !reducedMotion ? Math.min(delta, 0.05) : 0;
    time.current += elapsed;
    const phase = phaseTime(time) < 4.55 ? 0 : phaseTime(time) < MOMENTUM_START ? 1 : 2;
    if (phase !== previousPhase.current) { previousPhase.current = phase; onPhase(phase); }
    rig.current.rotation.y = THREE.MathUtils.damp(rig.current.rotation.y, mouseRef.current.enabled && !reducedMotion ? mouseRef.current.x * 0.045 : 0, 3, elapsed);
    rig.current.rotation.x = THREE.MathUtils.damp(rig.current.rotation.x, mouseRef.current.enabled && !reducedMotion ? -mouseRef.current.y * 0.025 : 0, 3, elapsed);
  });
  return <>
    {variant === 'background' && <color attach="background" args={['#060c17']} />}
    <ambientLight intensity={0.85} /><directionalLight position={[-3, 4, 5]} color="#dceaff" intensity={2.7} /><directionalLight position={[3, -1, 3]} color="#b8ade7" intensity={1.3} /><pointLight position={[0, 2, -2]} color="#80a4e1" intensity={5} distance={8} />
    <group ref={rig} position={[0, 0.04, 0]} scale={scale}><ProductPanel time={time} compact={compact} language={language} /></group>
  </>;
}

export default function LandingHeroScene({ variant = 'background' }: { variant?: Variant }) {
  const { language } = useI18n(), copy = words[language];
  const hostRef = useRef<HTMLDivElement>(null), contextCleanup = useRef<(() => void) | null>(null);
  const [active, setActive] = useState(false), [paused, setPaused] = useState(false), [phase, setPhase] = useState(0);
  const [environment, setEnvironment] = useState({ checked: false, canUseWebgl: false, reducedMotion: false });
  const mouseRef = useRef({ enabled: false, x: 0, y: 0 });
  useEffect(() => {
    const query = window.matchMedia('(prefers-reduced-motion: reduce)'), canUseWebgl = webglAvailable();
    const update = () => setEnvironment({ checked: true, canUseWebgl, reducedMotion: query.matches });
    update(); query.addEventListener('change', update);
    return () => query.removeEventListener('change', update);
  }, []);
  useEffect(() => {
    const element = hostRef.current;
    if (!element) return;
    let inView = false;
    const update = () => setActive(inView && document.visibilityState === 'visible');
    const observer = typeof IntersectionObserver === 'undefined' ? null : new IntersectionObserver(entries => { inView = entries[0]?.isIntersecting ?? false; update(); }, { threshold: 0.05 });
    if (observer) observer.observe(element); else { inView = true; update(); }
    document.addEventListener('visibilitychange', update);
    return () => { observer?.disconnect(); document.removeEventListener('visibilitychange', update); contextCleanup.current?.(); };
  }, []);
  useEffect(() => {
    const element = hostRef.current;
    if (!element) return;
    const query = window.matchMedia('(hover: hover) and (pointer: fine) and (min-width: 768px)');
    const reset = () => { mouseRef.current.x = 0; mouseRef.current.y = 0; };
    const update = () => { mouseRef.current.enabled = query.matches; if (!query.matches) reset(); };
    const move = (event: PointerEvent) => { if (!mouseRef.current.enabled) return; const bounds = element.getBoundingClientRect(); if (!bounds.width || !bounds.height) return; mouseRef.current.x = THREE.MathUtils.clamp((event.clientX - bounds.left) / bounds.width * 2 - 1, -1, 1); mouseRef.current.y = THREE.MathUtils.clamp((event.clientY - bounds.top) / bounds.height * 2 - 1, -1, 1); };
    update(); query.addEventListener('change', update); element.addEventListener('pointermove', move, { passive: true }); element.addEventListener('pointerleave', reset, { passive: true });
    return () => { query.removeEventListener('change', update); element.removeEventListener('pointermove', move); element.removeEventListener('pointerleave', reset); };
  }, []);
  const canRender = environment.checked && environment.canUseWebgl;
  const running = active && !paused && !environment.reducedMotion;
  return <div ref={hostRef} className={`finsight-story-scene finsight-story-scene--${variant}`} data-phase={phase}>
    <div className="finsight-story-light" aria-hidden="true" />
    <div className="finsight-story-canvas" role="img" aria-label={copy.description}>
      {canRender && <Canvas aria-hidden="true" camera={{ position: [0, 0, 6.8], fov: 40 }} frameloop={running ? 'always' : 'demand'} dpr={[1, 1.5]} gl={{ alpha: true, antialias: true, powerPreference: 'low-power', stencil: false }} style={{ pointerEvents: 'none' }} onCreated={({ gl }) => {
        gl.toneMapping = THREE.ACESFilmicToneMapping; gl.toneMappingExposure = 1.04;
        const lost = (event: Event) => { event.preventDefault(); setEnvironment(current => ({ ...current, canUseWebgl: false })); };
        contextCleanup.current?.(); gl.domElement.addEventListener('webglcontextlost', lost); contextCleanup.current = () => gl.domElement.removeEventListener('webglcontextlost', lost);
      }}><HeroScene mouseRef={mouseRef} variant={variant} reducedMotion={environment.reducedMotion} running={running} language={language} onPhase={setPhase} /></Canvas>}
      {environment.checked && !canRender && <div className="finsight-story-fallback" aria-hidden="true"><img src={MOMENTUM_BADGE} alt="" width="96" height="96" /><strong>FinSight Momentum</strong><span>{copy.momentum}</span></div>}
    </div>
    <span className="finsight-story-demo" aria-hidden="true">{copy.example}</span>
    <div className="finsight-story-steps" aria-hidden="true">{copy.steps.map((step, index) => <span key={step} data-current={phase === index}><span>0{index + 1}</span>{step}</span>)}</div>
    {canRender && !environment.reducedMotion && <button type="button" className="finsight-story-pause" onClick={() => setPaused(current => !current)} aria-label={paused ? copy.play : copy.pause} title={paused ? copy.play : copy.pause}>{paused ? <Play size={16} /> : <Pause size={16} />}</button>}
  </div>;
}
