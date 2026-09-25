# Contrato aditivo de clientes (v1)

Todas rutas salvo recovery requieren Bearer. API financiera sin cambios. Este archivo fija las interfaces de implementación y debe mantenerse sincronizado con serializers/tests.

## Momentum

`GET /api/engagement/me` devuelve:

```ts
type Text = { es: string; en: string };
type Mission = {
 key: string; scope: 'activation'|'feature'|'weekly'|'monthly'|'comeback';
 title: Text; requirement: Text; deeplink: string; review:boolean; period: string;
 status: 'active'|'completed'|'unavailable'|'replaced';
 slot: 'review'|'maintenance'|'goal'|null; target: number; progress: number;
 nominal_xp: number; granted_xp: number; reason: Text|null;
};
type Achievement = {
 key: string; title: Text; requirement: Text; progress: number; target: number;
 xp: number; completed_at: string|null; seen_at: string|null; available: boolean; reason: Text|null;
};
type Momentum = {
 enabled: boolean; catalog_version: 1; user_id: number; generated_at: string;
 lifetime_xp: number; xp_history:{period:string;xp:number}[]; level: {key:string; title:Text; minimum_xp:number; next_xp:number|null};
 week: {key:string; timezone:string; starts_at:string; ends_at:string; assigned:boolean;
 completed:number; total:number; bonus_xp:number; repeatable_xp:number; cap:number;
 new_week:boolean; unavailable:boolean; grace_applied:boolean; grace_period_key:string|null};
 month: {key:string; repeatable_xp:number; cap:75}; rhythm:number;
 missions:Mission[]; achievements:Achievement[];
 ai_credits:{available:boolean; balance:number; expires_at:string|null};
 backfill:{completed:boolean; unseen:boolean}; coachmark_seen:boolean;
 preferences:{notifications_enabled:boolean; quiet_start:number; quiet_end:number; locale:'en'|'es';
 timezone_name:string; timezone_offset_min:number};
};
```

`GET /missions/current` → `{missions, week, month}`; `/achievements` → `{achievements}`. Paths relativos a `/api/engagement`. Flag off `/me` puede devolver sólo `{enabled:false,user_id}`; ocultar tarjeta.

`GET /review/:kind` donde kind=`weekly`,`monthly` o key de misión de revisión asignada → `{snapshot_id,kind,period,expires_at,sections:[{key,title:Text,applicable,data:Record<string,unknown>[]}]}`. Datos reales, tablas con nombres de campos en UI traducidos. Secciones: accounts,recent_activity,net,categories,obligations,projects,invoices,investments,budgets. Confirmar todas aplicables sólo después de render. Cada snapshot caduca15min y al fin período; si datos cambian, pedir otro.

`POST /weekly-review` y `/monthly-review`: `{snapshot_id,confirmed_sections:string[],next_step:'review_spending'|'organize_categories'|'check_obligations'|'review_goal'|'keep_plan'}`. Devuelve estado Momentum. Ningún GET consume evidencia ni concede review.

`POST /client-events`: `{event_id:UUID,type:'review_confirmed',mission_key,snapshot_id,confirmed_sections,occurred_at:ISO}` o `{event_id,type:'week_presented'|'coachmark_seen'|'backfill_seen',occurred_at}`. Event UUID estable al reintentar. Recibido debe corresponder al período vigente: no premio retroactivo. Confirmación explícita no se encola silenciosamente como éxito; offline conserva UUID/payload por usuario para reintento antes de15min; expirado pide nueva evidencia. No XP/user_id/eventos privilegiados en payload.

`POST /achievements/:key/seen` con `{}`. `POST /preferences` con preferences + opcional timezone_name IANA/timezone_offset_min. `/me` acepta query timezone_name/offset inicial; límites ya asignados no cambian.

`grace_period_key` identifica la semana ISO beneficiada: puede ser la anterior, aunque la semana actual no tenga gracia. La preferencia explícita de zona prevalece frente al dispositivo; `week.timezone` conserva la zona del período iniciado y puede diferir hasta el siguiente. `preferences.timezone_name` puede devolver `offset` si no hay IANA válida; para ese fallback, POST envía únicamente `timezone_offset_min` (entero de -720 a 840). Horas quietas: enteros de 0 a 23; inicio igual a fin silencia todo el día.

Export local `POST /client-events` con type=`report_exported`,event_id,occurred_at,snapshot_id obtenido de `GET /review/report`, se manda sólo si impresión/sharePDF completó correctamente; no guardar recibos/finanzas en cola. Backend valida datos/owner/capacidad. Respuesta estado.

## Telemetría

`POST /api/analytics/events` body `{events:[{event_id:UUID,schema_version:1,event_type,session_id:UUID,install_id?:UUID,client_platform:'web'|'android'|'ios'|'unknown',app_version?:string,app_build?:string,source_screen?:string,client_occurred_at:ISO,metadata?:{feature?:string,step?:string,flow_id?:UUID,outcome?:string}}]}`. Máximo20eventos por lote. Respuesta `{accepted:number}`. No datos financieros, preguntas, email, ruta/query/url/token ni arbitrary fields. UUID estable offline,24h máximo. Sesión nueva tras30min sin foreground/actividad; push background no registra uso. Root/proveedor crean purchase_verified/subscription_state_changed, nunca cliente.

Allowlist event_type: session_started,app_foregrounded,screen_view,feature_used,onboarding_step_completed,paywall_viewed,checkout_started,purchase_pending,purchase_failed,restore_completed. Screens/features: dashboard,accounts,transactions,payments,projects,invoices,investments,categories,analytics,settings,momentum,achievements,ai,receipt,onboarding,paywall. Metadata step: account,transactions,categories,payment,insight,review; outcome: canceled,network,pending,failed,success. Rutas reset/login/signup no tracking. Instalación UUID aleatoria rotatoria, nunca fingerprint.

## IA existente

`POST /api/ai-chat` mantiene `{messages}` y `{reply}`. Nuevos clientes añaden `request_id:UUID` estable por pregunta/reintento. Crédito requiere request_id; Pro mantiene compatibilidad. No guardar prompts en analytics ni en ledger. Servidor prioriza Pro, reserva y concede evento sólo en éxito.

## Recuperación

`POST /api/auth/forgot-password {email,language:'es'|'en'}` → confirmación neutral200, retry_after_seconds60.
`POST /api/auth/reset-password {token,password,confirm_password}` → éxito o código INVALID_OR_EXPIRED_LINK.
`POST /api/auth/change-password {current_password,password,confirm_password}` autenticado con reauth. Nunca auto-login. Ver documentación específica recovery para límites/links. Capturar fragment token y retirarlo de history; no trackers en reset.

## Admin web (sólo owner)

Todos los endpoints `/api/admin/*` vuelven a verificar `admin_roles.role='owner'` en DB tras autenticar JWT. `GET /access` → `{allowed:true,analytics_enabled:boolean}`; no propietario403, anónimo401.

`GET /:section` para overview,usage,users,subscriptions,momentum,data-health y `GET /users/:id` devuelven:

```ts
{
 meta:{generated_at:string,filters:Record<string,unknown>,tracking_started_at:string|null,partial_day:boolean,notes:{en:string,es:string}[]},
 cards:{key:string,label:{en:string,es:string},value:number|string|null,unit?:string}[],
 series:{key:string,title:{en:string,es:string},kind:'line'|'bar'|'cohort'|'funnel',rows:Record<string,unknown>[],x:string,values:string[]}[],
 tables:{key:string,title:{en:string,es:string},rows:Record<string,unknown>[]}[],
 pagination?:{page:number,page_size:number,total:number}
}
```

Filtros query: start/end `YYYY-MM-DD` inclusivos, timezone IANA (UTC default), platform all/web/android/ios/unknown, provider all/google/apple/stripe/unknown, plan ID exacto, status normalizado, version, cohort fecha de alta, environment production/test/internal/unknown/all (production default), include_internal true/false (false default), q ID/email, page y page_size (máx100). Rango máx366d, sin fechas futuras. Valores cohort d7/d30 y cards con unit% están en escala0–100; null=N/D, nunca convertir a cero.

`GET /export/users` y `/export/subscriptions` aplican los mismos filtros y permisos, CSV con columnas allowlist y fórmulas escapadas, hasta10,000filas/5exports por hora. Los metadatos de auditoría no guardan email de búsqueda. No hay mutaciones de suscripciones ni endpoint de asignación de roles.
