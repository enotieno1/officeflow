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
    var metadata = user.user_metadata || {};
    var name = metadata.full_name || [metadata.first_name, metadata.last_name].filter(Boolean).join(' ') || user.email;
    var res;
    try {
      res = await supabase.from('profiles').select('role, organization_id, unit_id').eq('id', user.id).single();
    } catch (e) {
      throw new Error('Your account was authenticated, but OfficeFlow could not load your profile. Please try again.');
    }
    if (res.error || !res.data) {
      throw new Error('Your account profile is not ready yet. Please wait a moment and sign in again. If this continues, contact OfficeFlow support.');
    }
    this._session = {
      id: user.id,
      email: user.email,
      name: name,
      role: res.data.role || 'employee',
      organization_id: res.data.organization_id || null,
      unit_id: res.data.unit_id || null
    };
    return this._session;
  },

  async login(email, password) {
    try {
      var { data, error } = await supabase.auth.signInWithPassword({ email: email, password: password });
      if (error || !data.user) return { error: (error && error.message) || 'Invalid email or password.' };
      var s = await this._loadProfile(data.user);
      // This flag is only a UI hint; Supabase session validation and RLS remain
      // the actual security boundary.
      localStorage.setItem('ooesSession', '1');
      return s;
    } catch (e) {
      return { error: e && e.message ? e.message : 'Unable to complete sign-in. Check your connection and try again.' };
    }
  },

  async register(fn, ln, email, password, redirectTo, phone) {
    try {
      var fullName = (fn + ' ' + ln).trim();
      var confirmationUrl = redirectTo || (window.location.origin + '/dashboard/auth.html');
      var { data, error } = await supabase.auth.signUp({
        email: email,
        password: password,
        options: {
          data: {
            full_name: fullName,
            first_name: fn,
            last_name: ln,
            ...(phone ? { phone: phone } : {})
          },
          emailRedirectTo: confirmationUrl
        }
      });
      if (error) return { error: error.message };
      if (!data.user) return { error: 'If registration succeeded, check your email to confirm the account, then sign in.' };
      // If email confirmation is off, Supabase returns a session immediately.
      if (data.session) {
        var s = await this._loadProfile(data.user);
        localStorage.setItem('ooesSession', '1');
        return s;
      }
      return { pendingConfirmation: true, email: email };
    } catch (e) {
      return { error: e && e.message ? e.message : 'Unable to complete sign-up. Check your connection and try again.' };
    }
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
    try {
      var { data, error } = await supabase.auth.getSession();
      if (error) throw error;
      if (!data || !data.session) {
        this._session = null;
        localStorage.removeItem('ooesSession');
        window.location.replace('/dashboard/auth.html');
        return false;
      }
      await this._loadProfile(data.session.user);
      localStorage.setItem('ooesSession', '1'); // UI hint only; Supabase/RLS remain authoritative.
      return true;
    } catch (error) {
      // Always let the page's ready promise resolve. A transient profile/network
      // error must not leave every protected page stuck on "Loading…".
      this._session = null;
      localStorage.removeItem('ooesSession');
      console.error('OfficeFlow session verification failed', error);
      if (!window.location.pathname.endsWith('/auth.html')) {
        window.location.replace('/dashboard/auth.html?reason=session');
      }
      return false;
    }
  },

  renderUserInfo: function () {
    var s = this._session;
    if (!s) return;
    document.querySelectorAll('[data-user-name]').forEach(function (el) { el.textContent = s.name; });
    document.querySelectorAll('[data-user-email]').forEach(function (el) { el.textContent = s.email; });
    document.querySelectorAll('[data-user-role]').forEach(function (el) { el.textContent = s.role; });
  }
};

OOES_AUTH.ready = new Promise(function (resolve) { OOES_AUTH._readyResolve = resolve; });

(function () {
  if (!window.location.pathname.includes('auth.html')) {
    document.addEventListener('DOMContentLoaded', async function () {
      var ok = false;
      try {
        ok = await OOES_AUTH.requireAuth();
        if (ok) OOES_AUTH.renderUserInfo();
      } catch (error) {
        // Defensive final guard: never leave OOES_AUTH.ready unresolved.
        console.error('OfficeFlow auth initialization failed', error);
        OOES_AUTH._session = null;
      } finally {
        OOES_AUTH._readyResolve(ok);
      }
    });
  } else {
    OOES_AUTH._readyResolve(false);
  }
})();
