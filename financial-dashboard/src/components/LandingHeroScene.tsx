import { useEffect, useMemo, useRef, useState, type MutableRefObject } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';

type MotionEnvironment = {
  checked: boolean;
  canUseWebgl: boolean;
  reducedMotion: boolean;
};

type MouseTarget = MutableRefObject<{
  enabled: boolean;
  x: number;
  y: number;
}>;

type LandingHeroSceneVariant = 'background' | 'side-hero';

const chipData = [
  { label: 'Expenses', color: '#38bdf8', offset: 0.15 },
  { label: 'Budgets', color: '#34d399', offset: 1.72 },
  { label: 'Goals', color: '#a78bfa', offset: 3.28 },
  { label: 'Insights', color: '#facc15', offset: 4.85 },
] as const;

function webglAvailable() {
  try {
    const canvas = document.createElement('canvas');
    return Boolean(
      window.WebGLRenderingContext &&
        (canvas.getContext('webgl2') || canvas.getContext('webgl')),
    );
  } catch {
    return false;
  }
}

function createChipTexture(label: string, color: string) {
  const canvas = document.createElement('canvas');
  canvas.width = 320;
  canvas.height = 104;
  const ctx = canvas.getContext('2d');

  if (ctx) {
    const radius = 32;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'rgba(15, 23, 42, 0.64)';
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.shadowColor = color;
    ctx.shadowBlur = 8;

    ctx.beginPath();
    ctx.moveTo(radius, 14);
    ctx.lineTo(canvas.width - radius, 14);
    ctx.quadraticCurveTo(canvas.width - 14, 14, canvas.width - 14, radius);
    ctx.lineTo(canvas.width - 14, canvas.height - radius);
    ctx.quadraticCurveTo(canvas.width - 14, canvas.height - 14, canvas.width - radius, canvas.height - 14);
    ctx.lineTo(radius, canvas.height - 14);
    ctx.quadraticCurveTo(14, canvas.height - 14, 14, canvas.height - radius);
    ctx.lineTo(14, radius);
    ctx.quadraticCurveTo(14, 14, radius, 14);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.shadowBlur = 0;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(48, 52, 9, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#dbeafe';
    ctx.font = '600 26px system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, 72, 52);
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

function createDashboardCardTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 720;
  canvas.height = 420;
  const ctx = canvas.getContext('2d');

  if (ctx) {
    const radius = 36;
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const fill = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    fill.addColorStop(0, 'rgba(30, 41, 59, 0.62)');
    fill.addColorStop(0.5, 'rgba(15, 23, 42, 0.54)');
    fill.addColorStop(1, 'rgba(2, 6, 23, 0.58)');

    ctx.shadowColor = 'rgba(56, 189, 248, 0.22)';
    ctx.shadowBlur = 22;
    ctx.fillStyle = fill;
    ctx.strokeStyle = 'rgba(186, 230, 253, 0.34)';
    ctx.lineWidth = 2;

    ctx.beginPath();
    ctx.moveTo(radius, 24);
    ctx.lineTo(canvas.width - radius, 24);
    ctx.quadraticCurveTo(canvas.width - 24, 24, canvas.width - 24, radius);
    ctx.lineTo(canvas.width - 24, canvas.height - radius);
    ctx.quadraticCurveTo(canvas.width - 24, canvas.height - 24, canvas.width - radius, canvas.height - 24);
    ctx.lineTo(radius, canvas.height - 24);
    ctx.quadraticCurveTo(24, canvas.height - 24, 24, canvas.height - radius);
    ctx.lineTo(24, radius);
    ctx.quadraticCurveTo(24, 24, radius, 24);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    ctx.shadowBlur = 0;
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.14)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 4; i += 1) {
      const y = 146 + i * 54;
      ctx.beginPath();
      ctx.moveTo(96, y);
      ctx.lineTo(canvas.width - 96, y);
      ctx.stroke();
    }

    ctx.fillStyle = 'rgba(226, 232, 240, 0.82)';
    ctx.font = '600 26px system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
    ctx.fillText('Intelligence overview', 88, 86);

    ctx.fillStyle = 'rgba(125, 211, 252, 0.9)';
    ctx.beginPath();
    ctx.arc(canvas.width - 124, 78, 8, 0, Math.PI * 2);
    ctx.arc(canvas.width - 94, 78, 8, 0, Math.PI * 2);
    ctx.arc(canvas.width - 64, 78, 8, 0, Math.PI * 2);
    ctx.fill();
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.generateMipmaps = false;
  return texture;
}

function StaticHeroFallback({ variant }: { variant: LandingHeroSceneVariant }) {
  if (variant === 'side-hero') {
    return (
      <div
        className="absolute inset-0"
        style={{
          background:
            'radial-gradient(circle at 54% 46%, rgba(56, 189, 248, 0.22), rgba(59, 130, 246, 0.08) 36%, transparent 70%)',
        }}
      />
    );
  }

  return (
    <>
      <div
        className="absolute inset-0 bg-slate-950"
        style={{
          background:
            'radial-gradient(circle at 50% 34%, rgba(59, 130, 246, 0.34), transparent 34%), radial-gradient(circle at 72% 22%, rgba(16, 185, 129, 0.16), transparent 28%), linear-gradient(180deg, #020617 0%, #08111f 56%, #020617 100%)',
        }}
      />
      <div
        className="absolute inset-0 opacity-40"
        style={{
          backgroundImage:
            'linear-gradient(rgba(148, 163, 184, 0.08) 1px, transparent 1px), linear-gradient(90deg, rgba(148, 163, 184, 0.06) 1px, transparent 1px)',
          backgroundSize: '64px 64px',
        }}
      />
      <div className="absolute inset-0 bg-gradient-to-b from-slate-950/10 via-slate-950/20 to-slate-950/75" />
    </>
  );
}

function OrbitLine({
  radiusX,
  radiusY,
  rotation,
  opacity,
  color = '#7dd3fc',
}: {
  radiusX: number;
  radiusY: number;
  rotation: [number, number, number];
  opacity: number;
  color?: string;
}) {
  const line = useMemo(() => {
    const curve = new THREE.EllipseCurve(0, 0, radiusX, radiusY, 0, Math.PI * 2, false, 0);
    const points = curve.getPoints(144).map((point) => new THREE.Vector3(point.x, point.y, 0));
    const geometry = new THREE.BufferGeometry().setFromPoints(points);
    const material = new THREE.LineBasicMaterial({
      color,
      transparent: true,
      opacity,
      depthWrite: false,
    });
    const nextLine = new THREE.Line(geometry, material);
    nextLine.rotation.set(...rotation);
    return nextLine;
  }, [color, opacity, radiusX, radiusY, rotation]);

  useEffect(() => {
    return () => {
      line.geometry.dispose();
      (line.material as THREE.Material).dispose();
    };
  }, [line]);

  return <primitive object={line} />;
}

function Particles({ variant }: { variant: LandingHeroSceneVariant }) {
  const pointsRef = useRef<THREE.Points>(null);
  const geometry = useMemo(() => {
    const positions: number[] = [];
    const count = variant === 'side-hero' ? 64 : 90;
    for (let i = 0; i < count; i += 1) {
      positions.push(
        (Math.random() - 0.5) * (variant === 'side-hero' ? 5.2 : 7.2),
        (Math.random() - 0.5) * (variant === 'side-hero' ? 2.9 : 3.4),
        (Math.random() - 0.5) * 2.1,
      );
    }
    const nextGeometry = new THREE.BufferGeometry();
    nextGeometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    return nextGeometry;
  }, [variant]);

  useEffect(() => () => geometry.dispose(), [geometry]);

  useFrame(({ clock }) => {
    if (!pointsRef.current) return;
    pointsRef.current.rotation.y = clock.elapsedTime * 0.018;
    pointsRef.current.rotation.x = Math.sin(clock.elapsedTime * 0.12) * 0.025;
  });

  return (
    <points ref={pointsRef} geometry={geometry}>
      <pointsMaterial
        color="#bfdbfe"
        size={variant === 'side-hero' ? 0.014 : 0.017}
        sizeAttenuation
        transparent
        opacity={variant === 'side-hero' ? 0.34 : 0.48}
        depthWrite={false}
      />
    </points>
  );
}

function SmoothChartLine() {
  const line = useMemo(() => {
    const curve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-0.58, -0.08, 0.1),
      new THREE.Vector3(-0.36, 0.04, 0.1),
      new THREE.Vector3(-0.1, -0.02, 0.1),
      new THREE.Vector3(0.18, 0.14, 0.1),
      new THREE.Vector3(0.48, 0.07, 0.1),
      new THREE.Vector3(0.66, 0.24, 0.1),
    ]);
    const geometry = new THREE.BufferGeometry().setFromPoints(curve.getPoints(48));
    const material = new THREE.LineBasicMaterial({
      color: '#67e8f9',
      transparent: true,
      opacity: 0.82,
      depthWrite: false,
    });
    return new THREE.Line(geometry, material);
  }, []);

  useEffect(() => {
    return () => {
      line.geometry.dispose();
      (line.material as THREE.Material).dispose();
    };
  }, [line]);

  return <primitive object={line} />;
}

function CentralDashboardCard() {
  const groupRef = useRef<THREE.Group>(null);
  const texture = useMemo(() => createDashboardCardTexture(), []);

  useEffect(() => () => texture.dispose(), [texture]);

  useFrame(({ clock }, delta) => {
    if (!groupRef.current) return;
    groupRef.current.rotation.y = THREE.MathUtils.damp(
      groupRef.current.rotation.y,
      Math.sin(clock.elapsedTime * 0.18) * 0.08,
      2,
      delta,
    );
    groupRef.current.rotation.z = THREE.MathUtils.damp(
      groupRef.current.rotation.z,
      Math.sin(clock.elapsedTime * 0.12) * 0.025,
      2,
      delta,
    );
  });

  return (
    <group ref={groupRef}>
      <sprite scale={[1.92, 1.12, 1]}>
        <spriteMaterial map={texture} transparent opacity={0.96} depthWrite={false} />
      </sprite>
      <mesh position={[-0.5, -0.2, 0.08]}>
        <boxGeometry args={[0.16, 0.42, 0.025]} />
        <meshBasicMaterial color="#38bdf8" transparent opacity={0.62} />
      </mesh>
      <mesh position={[-0.18, -0.13, 0.08]}>
        <boxGeometry args={[0.16, 0.56, 0.025]} />
        <meshBasicMaterial color="#34d399" transparent opacity={0.58} />
      </mesh>
      <mesh position={[0.14, -0.26, 0.08]}>
        <boxGeometry args={[0.16, 0.3, 0.025]} />
        <meshBasicMaterial color="#a78bfa" transparent opacity={0.58} />
      </mesh>
      <SmoothChartLine />
      <mesh position={[0.45, 0.08, 0.12]}>
        <sphereGeometry args={[0.105, 24, 24]} />
        <meshBasicMaterial color="#e0f2fe" transparent opacity={0.78} />
      </mesh>
      <mesh position={[0.45, 0.08, 0.11]}>
        <ringGeometry args={[0.19, 0.195, 72]} />
        <meshBasicMaterial color="#7dd3fc" transparent opacity={0.5} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
}

function OrbitChip({
  label,
  color,
  showLabel,
}: {
  label: string;
  color: string;
  showLabel: boolean;
}) {
  const texture = useMemo(() => createChipTexture(label, color), [label, color]);

  useEffect(() => () => texture.dispose(), [texture]);

  return (
    <group>
      <mesh>
        <sphereGeometry args={[0.055, 18, 18]} />
        <meshBasicMaterial color={color} transparent opacity={0.9} />
      </mesh>
      <mesh>
        <ringGeometry args={[0.095, 0.1, 32]} />
        <meshBasicMaterial color={color} transparent opacity={0.28} side={THREE.DoubleSide} />
      </mesh>
      {showLabel && (
        <sprite position={[0.34, 0, 0]} scale={[0.76, 0.25, 1]}>
          <spriteMaterial map={texture} transparent opacity={0.82} depthWrite={false} />
        </sprite>
      )}
    </group>
  );
}

function OrbitingNodes({ compact }: { compact: boolean }) {
  const chipRefs = useRef<Array<THREE.Group | null>>([]);
  const radiusX = compact ? 1.58 : 1.92;
  const radiusY = compact ? 0.84 : 1.02;
  const speed = compact ? 0.055 : 0.04;

  useFrame(({ clock }) => {
    chipData.forEach((chip, index) => {
      const ref = chipRefs.current[index];
      if (!ref) return;
      const angle = chip.offset + clock.elapsedTime * speed;
      ref.position.set(
        Math.cos(angle) * radiusX,
        Math.sin(angle) * radiusY,
        Math.sin(angle) * 0.12,
      );
      const depthScale = compact ? 0.78 : 0.92 + Math.sin(angle) * 0.04;
      ref.scale.setScalar(depthScale);
    });
  });

  return (
    <group>
      {chipData.map((chip, index) => (
        <group
          key={chip.label}
          ref={(node) => {
            chipRefs.current[index] = node;
          }}
        >
          <OrbitChip label={chip.label} color={chip.color} showLabel={!compact} />
        </group>
      ))}
    </group>
  );
}

function OrbitLines({ compact }: { compact: boolean }) {
  const scale = compact ? 0.82 : 1;

  return (
    <group scale={scale} rotation={[0.08, 0, 0]}>
      <OrbitLine radiusX={2.08} radiusY={1.1} rotation={[0.1, 0.12, 0.02]} opacity={0.16} />
      <OrbitLine radiusX={2.28} radiusY={1.2} rotation={[-0.1, -0.08, 0.34]} opacity={0.1} color="#86efac" />
      <OrbitLine radiusX={1.88} radiusY={0.98} rotation={[0.06, 0.2, -0.28]} opacity={0.11} color="#c4b5fd" />
    </group>
  );
}

function HeroScene({ mouseRef, variant }: { mouseRef: MouseTarget; variant: LandingHeroSceneVariant }) {
  const rigRef = useRef<THREE.Group>(null);
  const { size } = useThree();
  const isSideHero = variant === 'side-hero';
  const compact = size.width < 480 || size.height < 360;

  useFrame((_, delta) => {
    if (!rigRef.current) return;
    const pointer = mouseRef.current;
    const targetY = pointer.enabled ? pointer.x * 0.1 : 0;
    const targetX = pointer.enabled ? -pointer.y * 0.075 : 0;

    rigRef.current.rotation.y = THREE.MathUtils.damp(rigRef.current.rotation.y, targetY, 2.4, delta);
    rigRef.current.rotation.x = THREE.MathUtils.damp(rigRef.current.rotation.x, targetX, 2.4, delta);
  });

  return (
    <>
      {variant === 'background' && <color attach="background" args={['#020617']} />}
      <ambientLight intensity={0.78} />
      <group ref={rigRef} position={[0, compact ? 0.04 : -0.02, 0]} scale={compact ? 0.82 : isSideHero ? 1.02 : 0.94}>
        <Particles variant={variant} />
        <OrbitLines compact={compact} />
        <CentralDashboardCard />
        <OrbitingNodes compact={compact} />
      </group>
    </>
  );
}

export default function LandingHeroScene({ variant = 'background' }: { variant?: LandingHeroSceneVariant }) {
  const [environment, setEnvironment] = useState<MotionEnvironment>({
    checked: false,
    canUseWebgl: false,
    reducedMotion: false,
  });
  const mouseRef = useRef({ enabled: false, x: 0, y: 0 });

  useEffect(() => {
    const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

    const updateEnvironment = () => {
      setEnvironment({
        checked: true,
        canUseWebgl: webglAvailable(),
        reducedMotion: motionQuery.matches,
      });
    };

    updateEnvironment();
    motionQuery.addEventListener('change', updateEnvironment);
    return () => motionQuery.removeEventListener('change', updateEnvironment);
  }, []);

  useEffect(() => {
    const parallaxQuery = window.matchMedia('(pointer: fine) and (min-width: 768px)');

    const updateParallax = () => {
      mouseRef.current.enabled = parallaxQuery.matches;
      if (!parallaxQuery.matches) {
        mouseRef.current.x = 0;
        mouseRef.current.y = 0;
      }
    };

    const handlePointerMove = (event: PointerEvent) => {
      if (!mouseRef.current.enabled) return;
      mouseRef.current.x = (event.clientX / window.innerWidth - 0.5) * 2;
      mouseRef.current.y = (event.clientY / window.innerHeight - 0.5) * 2;
    };

    updateParallax();
    parallaxQuery.addEventListener('change', updateParallax);
    window.addEventListener('pointermove', handlePointerMove, { passive: true });

    return () => {
      parallaxQuery.removeEventListener('change', updateParallax);
      window.removeEventListener('pointermove', handlePointerMove);
    };
  }, []);

  const shouldRenderCanvas = environment.checked && environment.canUseWebgl && !environment.reducedMotion;

  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-0 overflow-hidden">
      <StaticHeroFallback variant={variant} />
      {shouldRenderCanvas && (
        <Canvas
          className="pointer-events-none absolute inset-0"
          camera={{ position: [0, 0, variant === 'side-hero' ? 6.25 : 5.8], fov: variant === 'side-hero' ? 42 : 40 }}
          dpr={[1, 1.5]}
          gl={{
            alpha: variant === 'side-hero',
            antialias: true,
            powerPreference: 'low-power',
            stencil: false,
          }}
          style={{ pointerEvents: 'none' }}
        >
          <HeroScene mouseRef={mouseRef} variant={variant} />
        </Canvas>
      )}
      {variant === 'background' && (
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_42%,rgba(2,6,23,0.36),rgba(2,6,23,0.84)_76%)]" />
      )}
    </div>
  );
}
