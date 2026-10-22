/* OOES Core Navigation & UI Functions
   Single source of truth for all shared functions across dashboard pages.
   Include this in every page: <script src="/dashboard/js/ooes-core.js"></script>
*/

// ─── Navigation ───────────────────────────────────────────────────────────────

function goBack() {
  if (document.referrer && document.referrer.includes(window.location.hostname)) {
    window.history.back();
  } else {
    window.location.href = '/dashboard/index.html';
  }
}

function navigateToPage(page) {
  if (!page) return;
  // Accept bare names like "hr-system" or full paths
  const path = page.startsWith('/') ? page
    : page.endsWith('.html') ? '/dashboard/' + page
    : '/dashboard/' + page + '.html';
  window.location.href = path;
}

function navigateToSection(sectionId) {
  if (!sectionId) return;
  const el = document.getElementById(sectionId);
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  } else {
    // Section might be on another page — try hash navigation
    window.location.hash = '#' + sectionId;
  }
}

// ─── Modal ────────────────────────────────────────────────────────────────────

function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (!modal) { console.warn('openModal: no element with id "' + modalId + '"'); return; }
  modal.classList.remove('hidden');
  modal.style.display = 'flex';
  document.body.style.overflow = 'hidden';
  // Close on backdrop click
  modal.addEventListener('click', function(e) {
    if (e.target === modal) closeModal(modalId);
  }, { once: true });
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (!modal) return;
  modal.classList.add('hidden');
  modal.style.display = 'none';
  document.body.style.overflow = '';
}

// Close any open modal on Escape key
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    document.querySelectorAll('[id$="Modal"],[id$="-modal"],[id*="modal"]').forEach(function(m) {
      if (m.style.display !== 'none' && !m.classList.contains('hidden')) {
        closeModal(m.id);
      }
    });
  }
});

// ─── Notifications ────────────────────────────────────────────────────────────

(function createNotificationContainer() {
  if (document.getElementById('ooes-notifications')) return;
  const container = document.createElement('div');
  container.id = 'ooes-notifications';
  container.style.cssText = [
    'position:fixed', 'top:1rem', 'right:1rem', 'z-index:99999',
    'display:flex', 'flex-direction:column', 'gap:0.5rem',
    'pointer-events:none', 'max-width:360px'
  ].join(';');
  document.body.appendChild(container);
})();

function ooesShowNotification(message, type, duration) {
  type = type || 'info';       // 'success' | 'error' | 'warning' | 'info'
  duration = duration || 4000;

  const colors = {
    success: { bg: '#d1fae5', border: '#059669', text: '#065f46', icon: '✓' },
    error:   { bg: '#fee2e2', border: '#dc2626', text: '#7f1d1d', icon: '✕' },
    warning: { bg: '#fef3c7', border: '#d97706', text: '#78350f', icon: '⚠' },
    info:    { bg: '#dbeafe', border: '#2563eb', text: '#1e3a5f', icon: 'ℹ' }
  };
  const c = colors[type] || colors.info;

  const toast = document.createElement('div');
  toast.style.cssText = [
    'display:flex', 'align-items:flex-start', 'gap:10px',
    'padding:12px 16px', 'border-radius:8px',
    'border-left:4px solid ' + c.border,
    'background:' + c.bg,
    'color:' + c.text,
    'font-size:14px', 'font-family:system-ui,sans-serif',
    'box-shadow:0 4px 12px rgba(0,0,0,0.15)',
    'pointer-events:all',
    'opacity:0', 'transform:translateX(20px)',
    'transition:opacity 0.25s,transform 0.25s'
  ].join(';');

  toast.innerHTML =
    '<span style="font-weight:700;font-size:16px;line-height:1">' + c.icon + '</span>' +
    '<span style="flex:1;line-height:1.4">' + message + '</span>' +
    '<button onclick="this.parentElement.remove()" style="background:none;border:none;cursor:pointer;color:' + c.text + ';font-size:16px;line-height:1;padding:0;margin-left:4px">×</button>';

  const container = document.getElementById('ooes-notifications');
  container.appendChild(toast);

  // Animate in
  requestAnimationFrame(function() {
    requestAnimationFrame(function() {
      toast.style.opacity = '1';
      toast.style.transform = 'translateX(0)';
    });
  });

  // Auto dismiss
  setTimeout(function() {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(20px)';
    setTimeout(function() { toast.remove(); }, 300);
  }, duration);
}

// Preserve page-specific notification APIs (the authentication page uses title/message/type).
if (typeof window.showNotification !== 'function') window.showNotification = ooesShowNotification;

// ─── Forms ────────────────────────────────────────────────────────────────────

// Only intercept generic placeholder forms. Never intercept forms with their own
// submit handler: doing so creates false "success" messages on login/registration.
document.addEventListener('DOMContentLoaded', function() {
  document.querySelectorAll('form:not([action]):not([method])').forEach(function(form) {
    if (form.hasAttribute('onsubmit') ||
        form.id === 'officeFlowSignInForm' ||
        form.id === 'officeFlowSignUpForm') return;
    form.addEventListener('submit', function(e) {
      e.preventDefault();
      if (typeof window.showNotification === 'function') {
        window.showNotification('Form submitted successfully!', 'success');
      }
    });
  });
});

// ─── Active nav highlighting ──────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', function() {
  const current = window.location.pathname.split('/').pop();
  document.querySelectorAll('a[href]').forEach(function(link) {
    const href = link.getAttribute('href').split('/').pop().split('?')[0];
    if (href && href === current) {
      link.classList.add('active');
      link.setAttribute('aria-current', 'page');
    }
  });
});
