# FinSight

Aplicación financiera con React/Vite (`financial-dashboard/src`), API Express/MySQL (`financial-dashboard/server`) y clientes Flutter Android/iOS (`mobile`).

## Operación de la actualización de plataforma

El [registro de implementación y runbook](docs/implementation/finsight-platform-upgrade.md) contiene el alcance, decisiones, checks comprobados, despliegue, rollback y validaciones externas pendientes. La [auditoría previa](docs/implementation/repository-audit.md) documenta la arquitectura y los contratos heredados.

1. Revisar [configuración sin secretos](financial-dashboard/.env.example) y los runbooks antes de arrancar. No reutilizar automáticamente archivos de entorno legacy que puedan apuntar a un servicio real.
2. Preparar una base MySQL aislada. Las [migraciones](database/migrations) se aplican explícitamente: la API comprueba readiness y no migra ni siembra usuarios al arrancar en producción.
3. Desplegar API y workers antes de clientes; habilitar flags gradualmente. Conservar verificación de pagos, ACK, webhooks y revocación de sesiones durante rollback.

Desde `financial-dashboard`, `npm run check:server`, `npx tsc --noEmit`, `npm run build`, `npm run test:server` y `npm run assets:check` verifican código y assets. `npm run test:db` añade integración sobre MySQL local configurado; ver las condiciones de aislamiento y preparación en el runbook. Flutter: comandos y resultados en [mobile-upgrade.md](docs/implementation/mobile-upgrade.md).

Si el arranque se bloquea, `npm run doctor:server` comprueba **sólo con SELECT** la base configurada y muestra la causa sin credenciales. Usa la misma configuración que `npm run server`: `MYSQL_URL` prevalece sobre `MYSQL_*`. `migrate:check` sólo inspecciona archivos SQL, no verifica la base. No habilitar el bootstrap legacy para saltarse migraciones pendientes. Ver la [revisión de migración remota](docs/implementation/remote-migration-review.md).

- [Momentum y créditos](docs/implementation/momentum.md)
- [Billing y matriz sandbox](docs/implementation/billing-upgrade.md)
- [Admin, métricas y telemetría](docs/implementation/web-admin-analytics.md)
- [Recuperación de contraseña](docs/implementation/recovery.md)
- [Reparación explícita de inversiones legacy](docs/implementation/investment-account-backfill.md)
- [Contrato API de clientes](docs/implementation/client-contract.md)
- [Despliegue autorizado y estado de Cloud Run](docs/implementation/cloud-run-deployment.md)

Los builds y pruebas locales no sustituyen las pruebas de tiendas, correo, dispositivos ni staging. La implementación inicial no publicó ni ejecutó migraciones de producción; la operación posterior autorizada y su estado se registran en el informe de Cloud Run enlazado arriba.
