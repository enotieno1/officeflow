// OOES_AUTH — real Supabase Auth wrapper.
// Public API is unchanged on purpose (getSession/getRole/can/requireAuth/
// renderUserInfo/logout) so none of the other dashboard pages need editing.
// requireAuth()/login()/register() are now async internally, but the result
// is cached in memory so every other page can keep reading it synchronously.
var OOES_AUTH = {
  _session: null,   // cached in-memory: {id, email, name, role}
  _readyResolve: null,
  ready: null,      // await OOES_AUTH.ready if a page needs the session before it runs

  // Locked six-role model (profiles_role_check). Least-privilege ('employee')
  // is the fail-safe default everywhere below — never fail open into a
  // privileged role.
  ROLE_PERMISSIONS: {
    employee:      {canEdit:true,  canDelete:false, canViewFinance:false, canManageUsers:false},
    officer:       {canEdit:true,  canDelete:false, canViewFinance:true,  canManageUsers:false},
    manager:       {canEdit:true,  canDelete:true,  canViewFinance:true,  canManageUsers:false},
    administrator: {canEdit:true,  canDelete:true,  canViewFinance:true,  canManageUsers:true},
    auditor:       {canEdit:false, canDelete:false, canViewFinance:true,  canManageUsers:false},
    super_admin:   {canEdit:true,  canDelete:true,  canViewFinance:true,  canManageUsers:true}
  },

  async _loadProfile(user) {
    var name = (user.user_metadata && user.user_metadata.full_name) || user.email;
    var role = 'employee'; // fail-safe default (matches the DB's own default role) if the profile fetch fails
    try {
      var res = await supabase.from('profiles').select('full_name, role').eq('id', user.id).single();
      if (res.data) {
        name = res.data.full_name || name;
        role = res.data.role || role;
      }
    } catch (e) { /* profile row may not exist yet (trigger lag) — fall back to defaults */ }
    this._session = { id: user.id, email: user.email, name: name, role: role };
    return this._session;
  },

  async login(email, password) {
    var { data, error } = await supabase.auth.signInWithPassword({ email: email, password: password });
    if (error || !data.user) return { error: (error && error.message) || 'Invalid email or password.' };
    var s = await this._loadProfile(data.user);
    // 28 of the dashboard pages have an inline pre-render guard that checks this
    // localStorage flag before ooes-auth.js even runs, to avoid a flash of content.
    // It is NOT the security boundary — Supabase's own session + RLS are — so a
    // stale/forged flag can't grant access to anything; requireAuth() below still
    // verifies the real session on every page load.
    localStorage.setItem('ooesSession', '1');
    return s;
  },

  async register(fn, ln, email, password) {
    var fullName = (fn + ' ' + ln).trim();
    var { data, error } = await supabase.auth.signUp({
      email: email,
      password: password,
      options: { data: { full_name: fullName } }
    });
    if (error) return { error: error.message };
    if (!data.user) return { error: 'Check your email to confirm your account, then sign in.' };
    // If email confirmation is off, Supabase returns a session immediately.
    if (data.session) {
      var s = await this._loadProfile(data.user);
      localStorage.setItem('ooesSession', '1');
      return s;
    }
    return { pendingConfirmation: true, email: email };
  },

  async logout(redirect) {
    await supabase.auth.signOut();
    this._session = null;
    localStorage.removeItem('ooesSession');
    if (redirect !== false) window.location.href = '/dashboard/auth.html';
  },

  getSession: function () { return this._session; },
  isLoggedIn: function () { return this._session !== null; },
  getRole: function () { return this._session ? this._session.role : 'employee'; },
  can: function (perm) {
    var perms = this.ROLE_PERMISSIONS[this.getRole()] || this.ROLE_PERMISSIONS.employee;
    return perms[perm] === true;
  },

  async requireAuth() {
    var { data } = await supabase.auth.getSession();
    if (!data.session) {
      localStorage.removeItem('ooesSession');
      window.location.replace('/dashboard/auth.html');
      return false;
    }
    await this._loadProfile(data.session.user);
    localStorage.setItem('ooesSession', '1'); // keep the pre-render guard flag in sync
    return true;
  },

  renderUserInfo: function () {
    var s = this._session;
    if (!s) return;
    document.querySelectorAll('[data-user-name]').forEach(function (el) { el.textContent = s.name; });
    document.querySelectorAll('[data-user-email]').forEach(function (el) { el.textContent = s.email; });
  }
};

OOES_AUTH.ready = new Promise(function (resolve) { OOES_AUTH._readyResolve = resolve; });

(function () {
  if (!window.location.pathname.includes('auth.html')) {
    document.addEventListener('DOMContentLoaded', async function () {
      var ok = await OOES_AUTH.requireAuth();
      if (ok) OOES_AUTH.renderUserInfo();
      OOES_AUTH._readyResolve(ok);
    });
  } else {
    OOES_AUTH._readyResolve(false);
  }
})();
