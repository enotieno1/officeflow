/* OfficeFlow shared persistent dashboard navigation.
 * Keeps module navigation consistent without replacing module content or auth logic.
 */
(function () {
  'use strict';
  if (window.__officeFlowSharedNavigationLoaded) return;
  window.__officeFlowSharedNavigationLoaded = true;

  const groups = [
    { title: 'Core Modules', items: [
      ['HR Management','hr-system.html','fa-users'],
      ['Finance & Administration','financial-management.html','fa-coins'],
      ['Accounting Tools (Classic)','accounting-tools.html','fa-calculator'],
      ['Tasks & Workflow','tasks-management.html','fa-list-check'],
      ['Document Management','document-management.html','fa-file-alt'],
      ['Email & Communication','email-system.html','fa-envelope'],
      ['Calendar & Scheduling','calendar-system.html','fa-calendar-days'],
      ['AI Productivity','ai-features.html','fa-wand-magic-sparkles'],
      ['Reports & Insights','reports.html','fa-chart-bar'],
      ['Security & Access','security-center.html','fa-shield-alt']
    ]},
    { title: 'Workflow Operations', items: [
      ['My Work','my-work.html','fa-inbox'],
      ['Notifications','notifications.html','fa-bell'],
      ['Work Center','workflow.html','fa-route'],
      ['Module Workbench','officeflow-module-center.html','fa-layer-group'],
      ['Workflow Builder','workflow-builder.html','fa-sitemap'],
      ['Automation Engine','automation.html','fa-bolt'],
      ['Control Tower','control-tower.html','fa-chart-line'],
      ['Fraud Alerts','fraud-detection.html','fa-triangle-exclamation']
    ]},
    { title: 'Organization', items: [
      ['Departments','departments.html','fa-building'],
      ['Operations Department (Classic)','operations-department.html','fa-gears']
    ]}
  ];

  function initialize() {
    if (!document.body || document.querySelector('.of-shared-sidebar')) return;
    const path = location.pathname.split('/').pop() || 'index.html';
    const original = document.getElementById('sidebar');
    const sidebar = original || document.createElement('aside');
    if (!original) sidebar.id = 'sidebar';
    sidebar.dataset.ofSharedSidebar = 'true';
    sidebar.setAttribute('aria-label', 'OfficeFlow main navigation');
    sidebar.className = 'of-shared-sidebar';
    const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const links = groups.map(group =>
      '<div class="of-nav-section">'+esc(group.title)+'</div>' +
      group.items.map(item => {
        const active = path === item[1];
        return '<a class="of-nav-link'+(active?' is-active':'')+'" '+(active?'aria-current="page" ':'')+'href="/dashboard/'+esc(item[1])+'"><i class="fas '+esc(item[2])+'" aria-hidden="true"></i><span>'+esc(item[0])+'</span></a>';
      }).join('')
    ).join('');
    sidebar.innerHTML =
      '<div class="of-nav-brand"><div class="of-nav-brand-title">OfficeFlow</div><div class="of-nav-brand-sub">Office Operations</div></div>' +
      '<nav class="of-nav-list"><a class="of-nav-link'+(path==='index.html'?' is-active':'')+'" href="/dashboard/index.html"><i class="fas fa-home" aria-hidden="true"></i><span>Dashboard</span></a>'+links+'</nav>' +
      '<div class="of-nav-footer"><span class="of-nav-user">OfficeFlow Workspace</span><button type="button" id="of-nav-logout">Logout</button></div>';
    if (!original) {
      document.body.insertBefore(sidebar, document.body.firstChild);
      document.body.classList.add('of-nav-injected');
    }
    const css = document.createElement('style');
    css.id = 'of-shared-navigation-styles';
    css.textContent = `
      .of-shared-sidebar{position:fixed!important;inset:0 auto 0 0!important;width:256px!important;max-width:86vw!important;height:100vh!important;z-index:1000!important;display:flex!important;flex-direction:column!important;overflow:hidden!important;background:linear-gradient(160deg,#16213e 0%,#202d4d 100%)!important;color:#f8fafc!important;border-right:1px solid rgba(255,255,255,.12)!important;box-sizing:border-box!important;transform:translateX(0);transition:transform .22s ease}
      .of-nav-brand{padding:22px 20px 18px;border-bottom:1px solid rgba(255,255,255,.13);flex-shrink:0}
      .of-nav-brand-title{font:700 23px/1.2 Inter,Arial,sans-serif;letter-spacing:.2px;color:#fff}
      .of-nav-brand-sub{font:12px/1.5 Inter,Arial,sans-serif;color:#c7d2e8;margin-top:5px}
      .of-nav-list{padding:10px 10px 16px;overflow-y:auto;flex:1;min-height:0}
      .of-nav-section{font:700 10px/1.4 Inter,Arial,sans-serif;text-transform:uppercase;letter-spacing:1.2px;color:#c6a86a;padding:17px 10px 7px}
      .of-nav-link{display:flex;align-items:center;gap:10px;padding:9px 10px;margin:2px 0;border-radius:7px;color:#d8e0ef!important;text-decoration:none!important;font:500 12px/1.35 Inter,Arial,sans-serif;transition:background .15s,color .15s}
      .of-nav-link i{width:17px;min-width:17px;text-align:center;color:#c6a86a}
      .of-nav-link:hover{background:rgba(255,255,255,.1);color:#fff!important}
      .of-nav-link.is-active{background:rgba(198,168,106,.2);box-shadow:inset 3px 0 #c6a86a;color:#fff!important}
      .of-nav-footer{padding:12px 16px;border-top:1px solid rgba(255,255,255,.13);font:11px Inter,Arial,sans-serif;color:#c7d2e8;display:flex;align-items:center;justify-content:space-between;gap:8px}
      .of-nav-footer button{border:1px solid rgba(255,255,255,.2);border-radius:5px;padding:5px 8px;color:#f4d5d5;background:transparent;cursor:pointer}
      body.of-nav-injected{padding-left:256px!important}
      body.of-nav-injected>.of-shared-sidebar{margin:0!important}
      body:has(.of-shared-sidebar) .ml-56{margin-left:256px!important}
      body:has(.of-shared-sidebar) .ml-64{margin-left:256px!important}
      body:has(.of-shared-sidebar) .container.mx-auto{margin-left:272px!important;margin-right:16px!important;max-width:calc(100% - 288px)!important}
      #of-nav-toggle{display:none;position:fixed;left:10px;top:10px;z-index:1002;border:0;border-radius:8px;background:#16213e;color:#fff;padding:10px 12px;box-shadow:0 2px 12px #0003}
      #of-nav-overlay{display:none;position:fixed;inset:0;background:#0b1220a6;z-index:999}
      @media(max-width:768px){body.of-nav-injected{padding-left:0!important}body:has(.of-shared-sidebar) .ml-56,body:has(.of-shared-sidebar) .ml-64{margin-left:0!important}body:has(.of-shared-sidebar) .container.mx-auto{margin-left:0!important;margin-right:auto!important;max-width:100%!important}.of-shared-sidebar{transform:translateX(-102%)}.of-shared-sidebar.of-nav-open{transform:translateX(0)}#of-nav-toggle{display:block}#of-nav-overlay.of-nav-overlay-open{display:block}}
    `;
    document.head.appendChild(css);
    if (!document.getElementById('of-nav-toggle')) {
      const toggle = document.createElement('button');
      toggle.id = 'of-nav-toggle'; toggle.type = 'button'; toggle.setAttribute('aria-label','Open navigation'); toggle.innerHTML = '<i class="fas fa-bars" aria-hidden="true"></i>';
      document.body.appendChild(toggle);
      const overlay = document.createElement('div'); overlay.id = 'of-nav-overlay'; overlay.setAttribute('aria-hidden','true'); overlay.className='of-nav-overlay';
      document.body.appendChild(overlay);
      const close = () => { sidebar.classList.remove('of-nav-open'); overlay.classList.remove('of-nav-overlay-open'); };
      toggle.addEventListener('click', () => { sidebar.classList.toggle('of-nav-open'); overlay.classList.toggle('of-nav-overlay-open'); });
      overlay.addEventListener('click', close);
      sidebar.querySelectorAll('a').forEach(a => a.addEventListener('click', close));
    }
    const logout = document.getElementById('of-nav-logout');
    if (logout) logout.addEventListener('click', () => {
      if (window.OOES_AUTH && typeof window.OOES_AUTH.logout === 'function') window.OOES_AUTH.logout();
      else if (window.ooesAuth && typeof window.ooesAuth.logout === 'function') window.ooesAuth.logout();
      else if (window.supabase && window.supabase.auth) window.supabase.auth.signOut().finally(() => location.href='/dashboard/auth.html');
      else location.href='/dashboard/auth.html';
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize, {once:true});
  else initialize();
})();