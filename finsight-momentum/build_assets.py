from pathlib import Path
import json, math
P=Path(__file__).parent
colors={'blue':'#2563EB','mint':'#22B66F','lavender':'#7C83FD','amber':'#F59E0B'}
shapes={
'eye':'<path d="M18 30 Q32 14 46 30 Q32 46 18 30Z"/><circle cx="32" cy="30" r="5"/>',
'wallet':'<rect x="18" y="22" width="28" height="22" rx="5"/><path d="M20 22V19H41V22M38 29H46V37H38Z"/>',
'map':'<path d="M19 23L28 19L37 23L45 19V42L37 46L28 42L19 46ZM28 19V42M37 23V46M22 29H41M38 26L41 29L38 32"/>',
'search':'<circle cx="29" cy="28" r="11"/><path d="M37 36L46 45"/>',
'checklist':'<rect x="21" y="18" width="24" height="29" rx="4"/><path d="M25 26L27 28L31 24M34 26H40M25 35L27 37L31 33M34 35H40"/>',
'ring':'<circle cx="32" cy="32" r="14" stroke-dasharray="18 4"/>',
'orbit':''.join(f'<circle cx="{32+14*math.cos(i*math.pi/6):.2f}" cy="{32+14*math.sin(i*math.pi/6):.2f}" r="1.5"/>' for i in range(12)),
'calendar':'<rect x="19" y="21" width="26" height="25" rx="4"/><path d="M19 28H45M25 18V24M39 18V24M25 34H29M35 34H39M25 40H29M35 40H39"/>',
'shield':'<path d="M32 17L46 23V32Q45 43 32 49Q19 43 18 32V23Z"/>',
'repeat':'<path d="M21 27Q26 16 39 22L44 27M44 20V27H37M43 37Q38 48 25 42L20 37M20 44V37H27"/>',
'chart':'<path d="M19 19V45H46M25 38V31M33 38V24M41 38V19"/>',
'calendars':'<rect x="16" y="24" width="13" height="21" rx="3"/><rect x="26" y="20" width="13" height="25" rx="3"/><rect x="36" y="24" width="13" height="21" rx="3"/><path d="M16 30H26M27 27H38M39 30H49"/>',
'folder':'<path d="M18 25V22Q18 19 21 19H29L34 25H44Q47 25 47 28V42Q47 45 44 45H21Q18 45 18 42Z"/><path d="M24 35H40M27 32V38M33 32V38"/>',
'flag':'<path d="M27 44V20Q33 16 39 21L43 20V32Q36 36 27 31"/>',
'document':'<path d="M22 18H36L44 26V46H22ZM36 18V27H44M27 33H38M27 39H35"/>',
'arrows':'<path d="M18 25H44M38 19L44 25L38 31M46 40H20M26 34L20 40L26 46"/>',
'trend':'<path d="M18 43L27 32L34 36L45 21M37 21H45V29"/>',
'receipt':'<path d="M23 18L27 21L31 18L35 21L39 18L43 21V47L39 44L35 47L31 44L27 47L23 44ZM28 28H38M28 34H38M28 40H33"/>',
'stack':'<path d="M17 23V46H36M21 19V42H40"/><path d="M26 18H44V46L40 43L35 46L30 43L26 46ZM30 26H40M30 32H40"/>',
'grid':'<rect x="19" y="19" width="11" height="11" rx="3"/><rect x="35" y="19" width="11" height="11" rx="3"/><rect x="19" y="35" width="11" height="11" rx="3"/>',
'chat':'<path d="M19 21H45V40H31L22 47V40H19Z"/><path d="M25 28H37M25 34H34"/>',
'comeback':'<path d="M20 29A15 15 0 1 1 22 43M20 19V29H30"/>',
'spark':'<path d="M32 18L36 28L46 32L36 36L32 46L28 36L18 32L28 28Z"/>',
'compass':'<circle cx="32" cy="32" r="15"/><path d="M38 25L35 35L25 39L29 29Z"/>',
'route':'<path d="M21 44V30Q21 23 29 23H35Q44 23 44 32V40M39 35L44 40L49 35"/><circle cx="21" cy="44" r="3"/>',
'layers':'<path d="M17 27L32 18L47 27L32 36ZM17 34L32 43L47 34M17 41L32 50L47 41"/>'}
check='<path d="M36 40L40 44L48 35"/>'
star='<path d="M43 32L45 37L50 38L46 42L47 47L43 44L38 47L39 42L35 38L41 37Z"/>'
tag='<path d="M25 25H31L35 29L29 35L25 31Z"/>'
rows=[
('clear_view','Primera visión clara','eye','blue','chart'),('account_organizer','Organizador de cuentas','wallet','blue','check'),('money_mapper','Mapa financiero','map','lavender',''),('spending_detective_1','Detective de gastos','search','mint','tag'),('spending_detective_2','Observador de detalles','search','blue','tags'),('spending_detective_3','Experto en categorías','search','lavender','star'),('weekly_rhythm','Ritmo semanal','checklist','blue','spark'),('consistency_builder','Constancia','ring','mint',''),('momentum_keeper','Momentum sostenido','orbit','blue',''),('half_year_clarity','Medio año de claridad','calendar','lavender','eye'),('bill_guardian_1','Guardián de pagos','shield','amber','calendar'),('bill_guardian_2','Planificador de pagos','shield','blue','repeat'),('bill_guardian_3','Experto en compromisos','shield','lavender','star'),('subscription_sleuth','Detective de suscripciones','repeat','mint','search'),('analytics_explorer','Explorador de análisis','chart','blue','eye'),('monthly_master_1','Revisión mensual','calendar','blue','chart'),('monthly_master_2','Claridad trimestral','calendars','mint',''),('monthly_master_3','Un año en foco','orbit','lavender','calendar'),('project_planner','Planificador de proyectos','folder','blue','check'),('goal_builder_1','Primer avance','flag','mint','quarter'),('goal_builder_2','A mitad de camino','flag','blue','half'),('goal_builder_3','Casi completo','flag','amber','threequarter'),('goal_builder_4','Proyecto completo','flag','lavender','full'),('invoice_ready','Listo para facturar','document','blue','check'),('invoice_keeper','Facturas al día','shield','mint','document'),('cashflow_ready','Flujo bajo control','arrows','blue','calendar'),('investment_observer','Observador de inversiones','trend','lavender','eye'),('receipt_ready_1','Primer comprobante','receipt','blue','check'),('receipt_ready_2','Organizador de comprobantes','stack','mint','check'),('receipt_ready_3','Experto en comprobantes','stack','lavender','star'),('category_curator','Curador de categorías','grid','mint','check'),('report_ready','Primer reporte','document','blue','chart'),('ai_explorer','Explorador de IA','chat','lavender','spark'),('comeback_strong','Retoma tu claridad','comeback','amber','spark')]
def artwork(base,detail):
 s=shapes[base]
 if detail in ['quarter','half','threequarter','full']:
  n={'quarter':25,'half':50,'threequarter':75,'full':100}[detail]
  s+=f'<circle cx="32" cy="32" r="21" pathLength="100" stroke-dasharray="{n} 100" transform="rotate(-90 32 32)"/>'
 elif detail=='check':s+=check
 elif detail=='star':s+=star
 elif detail=='tag':s+=tag
 elif detail=='tags':s+=tag+'<path d="M27 22H33L38 27"/>'
 elif detail:s+=f'<g transform="translate(25 27) scale(.48)">{shapes[detail]}</g>'
 return s
manifest={'version':1,'viewBox':'0 0 64 64','badges':[],'levels':[],'ui':[]}
def svg(key,art,c,dark=False,locked=False):
 color='#94A3B8' if locked else c
 bg='#182439' if dark else '#F5F9FF'
 return f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><defs><linearGradient id="{key}_g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{color}" stop-opacity=".23"/><stop offset="1" stop-color="{color}" stop-opacity=".04"/></linearGradient></defs><rect x="3" y="3" width="58" height="58" rx="18" fill="{bg}"/><rect x="3" y="3" width="58" height="58" rx="18" fill="url(#{key}_g)" stroke="{color}" stroke-opacity=".28"/><path d="M12 22Q12 10 24 10H43" fill="none" stroke="#FFFFFF" stroke-opacity=".65" stroke-width="2" stroke-linecap="round"/><g fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{art}</g></svg>'''
for key,name,base,family,detail in rows:
 item={'key':key,'name_es':name,'family':family,'files':{}}
 for state in ['light','dark','locked_light','locked_dark']:
  rel=f'assets/badges/{key}__{state}.svg';(P/rel).write_text(svg(key,artwork(base,detail),colors[family],'dark' in state,'locked' in state));item['files'][state]=rel
 manifest['badges'].append(item)
for key,name,base,family in [('explorer','Explorador','compass','blue'),('organizer','Organizador','grid','mint'),('planner','Planificador','route','blue'),('strategist','Estratega','layers','lavender')]:
 item={'key':key,'name_es':name,'files':{}}
 for state in ['light','dark']:
  rel=f'assets/levels/{key}__{state}.svg';(P/rel).write_text(svg(key,shapes[base],colors[family],state=='dark'));item['files'][state]=rel
 manifest['levels'].append(item)
for key,base in [('momentum_mark','trend'),('xp','spark'),('weekly_review','checklist'),('monthly_review','calendar'),('mission_review','eye'),('mission_maintenance','grid'),('mission_goal','flag'),('week_complete','ring'),('ai_credit','chat'),('comeback','comeback'),('empty_missions','compass'),('all_achievements','layers')]:
 item={'key':key,'files':{}}
 for state in ['light','dark']:
  rel=f'assets/ui/{key}__{state}.svg';(P/rel).write_text(svg(key,shapes[base]+(check if key=='week_complete' else ''),colors['blue'],state=='dark'));item['files'][state]=rel
 manifest['ui'].append(item)
(P/'assets/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
html='''<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>FinSight Momentum · Assets</title><style>body{font:15px system-ui;margin:0;background:#eef3fb;color:#13254a}main{max-width:1120px;margin:60px auto;padding:24px}h1{font-size:44px;letter-spacing:-2px}p{color:#536581}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:16px}.card{background:white;border:1px solid #dce6f4;border-radius:22px;padding:22px}.icons{display:flex;gap:10px;align-items:center}.dark{background:#111b2d;border-radius:14px;padding:5px}img{width:64px;height:64px}small{display:block;margin-top:10px;color:#657691;overflow-wrap:anywhere}h2{margin-top:42px}</style><main><p>FINSIGHT / SISTEMA VISUAL 01</p><h1>Un avance que se siente.</h1><p>Momentum · 34 insignias, 4 niveles y recursos de interfaz. SVG originales para web y Flutter.</p>'''
for title,items in [('Insignias',manifest['badges']),('Niveles',manifest['levels']),('Interfaz',manifest['ui'])]:
 html+=f'<h2>{title}</h2><div class="grid">'
 for item in items:
  html+='<div class="card"><div class="icons">'+''.join(f'<img class="{"dark" if state=="dark" else ""}" src="{item["files"][state]}" alt="{item["key"]} {state}">' for state in ['light','dark']+(['locked_light'] if 'locked_light' in item['files'] else []))+'</div><p>'+item.get('name_es',item['key'])+'</p><small>'+item['key']+'</small></div>'
 html+='</div>'
(P/'PREVIEW.html').write_text(html+'</main></html>')
print('Generated',len(list(P.rglob('*.svg'))),'SVG assets')
