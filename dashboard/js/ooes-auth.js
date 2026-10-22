// OOES_AUTH — real Supabase Auth wrapper.
// Public API remains unchanged so dashboard pages do not need editing.
var OOES_AUTH = {
  _session: null,
  _readyResolve: null,
  ready: null,

  ROLE_PERMISSIONS: {
    employee:      {canEdit:true,  canDelete:false, canViewFinance:false, canManageUsers:false},
    officer:       {canEdit:true,  canDelete:false, canViewFinance:true,  canManageUsers:false},
    manager:       {canEdit:true,  canDelete:true,  canViewFinance:true,  canManageUsers:false},
    administrator: {canEdit:true,  canDelete:true,  canViewFinance:true,  canManageUsers:true},
    auditor:       {canEdit:false, canDelete:false, canViewFinance:true,  canManageUsers:false},
    super_admin:   {canEdit:true,  canDelete:true,  canViewFinance:true,  canManageUsers:true}
  },

  _setSessionFlag() {
    try { window.localStorage.setItem('ooesSession', '1'); } catch (_) {}
  },
  _clearSessionFlag() {
    try { window.localStorage.removeItem('ooesSession'); } catch (_) {}
  },

  async _loadProfile(user) {
    var metadata = user.user_metadata || {};
    var name = metadata.full_name ||
      [metadata.first_name, metadata.last_name].filter(Boolean).join(' ') ||
      user.email || 'OfficeFlow user';
    var res = null;
    var lastError = null;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        res = await supabase.from('profiles')
          .select('role, organization_id, unit_id')
          .eq('id', user.id)
          .maybeSingle();
        if (!res.error && res.data) break;
        lastError = res.error || new Error('Profile row was not returned.');
      } catch (e) { lastError = e; }
      if (attempt < 2) {
        await new Promise(function(resolve) {
          window.setTimeout(resolve, attempt === 0 ? 250 : 600);
        });
      }
    }
    if (!res || res.error || !res.data) {
      var detail = lastError && lastError.message ? ' (' + lastError.message + ')' : '';
      throw new Error('OfficeFlow signed you in, but could not load your account profile. Please retry. If it continues, ask your administrator to check your profile.' + detail);
    }
    this._session = {
      id: user.id, email: user.email, name: name,
      role: res.data.role || 'employee',
      organization_id: res.data.organization_id || null,
      unit_id: res.data.unit_id || null
    };
    return this._session;
  },

  async login(email, password) {
    try {
      if (!email || !password) return { error: 'Enter your email address and password.' };
      var result = await supabase.auth.signInWithPassword({email: email.trim(), password: password});
      if (result.error || !result.data || !result.data.user) {
        return { error: (result.error && result.error.message) || 'Unable to sign in. Check your email and password, then try again.' };
      }
      var session = await this._loadProfile(result.data.user);
      this._setSessionFlag();
      return session;
    } catch (e) {
      return { error: e && e.message ? e.message : 'Unable to complete sign-in. Check your connection and try again.' };
    }
  },

  async register(fn, ln, email, password, redirectTo, phone) {
    try {
      var fullName = (fn + ' ' + ln).trim();
      // Always use the dedicated confirmation handler; caller-provided redirect URLs
      // can point at a page that does not process every Supabase email-link format.
      var confirmationUrl = window.location.origin + '/dashboard/auth-confirmation.html';
      var result = await supabase.auth.signUp({
        email: email.trim(),
        password: password,
        options: {
          data: {
            full_name: fullName, first_name: fn, last_name: ln,
            ...(phone ? { phone: phone } : {})
          },
          emailRedirectTo: confirmationUrl
        }
      });
      if (result.error) {
        var authMessage = result.error.message || 'Unable to create your account. Please try again.';
        if (/email rate limit exceeded|rate limit/i.test(authMessage)) {
          authMessage = 'OfficeFlow reached the email provider sending limit. Please wait before requesting another confirmation email. If this continues, the platform administrator must configure a production SMTP provider in Supabase Auth.';
        } else if (/already registered|user already exists/i.test(authMessage)) {
          authMessage = 'An account may already exist for this email. Try signing in, or use Forgot password if you cannot access it.';
        } else if (/password.*(weak|short)|weak password/i.test(authMessage)) {
          authMessage = 'Please choose a stronger password that meets the password requirements.';
        }
        return { error: authMessage };
      }
      if (!result.data || !result.data.user) {
        return { error: 'If registration succeeded, check your email to confirm the account, then sign in.' };
      }
      if (result.data.session) {
        var session = await this._loadProfile(result.data.user);
        this._setSessionFlag();
        return session;
      }
      return { pendingConfirmation: true, email: email };
    } catch (e) {
      return { error: e && e.message ? e.message : 'Unable to complete sign-up. Check your connection and try again.' };
    }
  },

  async logout(redirect) {
    try { await supabase.auth.signOut(); }
    finally { this._session = null; this._clearSessionFlag(); }
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
      var result = await supabase.auth.getSession();
      if (result.error) throw result.error;
      if (!result.data || !result.data.session) {
        this._clearSessionFlag();
        window.location.replace('/dashboard/auth.html');
        return false;
      }
      await this._loadProfile(result.data.session.user);
      this._setSessionFlag();
      return true;
    } catch (e) {
      this._clearSessionFlag();
      window.location.replace('/dashboard/auth.html?auth_error=session');
      return false;
    }
  },

  renderUserInfo: function () {
    var session = this._session;
    if (!session) return;
    document.querySelectorAll('[data-user-name]').forEach(function (el) { el.textContent = session.name; });
    document.querySelectorAll('[data-user-email]').forEach(function (el) { el.textContent = session.email; });
    document.querySelectorAll('[data-user-role]').forEach(function (el) { el.textContent = session.role; });
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
  } else { OOES_AUTH._readyResolve(false); }
})();
