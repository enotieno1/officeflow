/* OfficeFlow department-specific sign-in. Department access is verified from the protected profiles/departments tables; URL/UI labels are not authorization. */
(function () {
  'use strict';
  const form = document.getElementById('department-login-form');
  if (!form) return;
  const code = String(document.body.dataset.departmentCode || '').toUpperCase();
  const config = {
    HR: {name:'Human Resources', category:'HR', icon:'fa-users', description:'Confidential employee records and HR workflows.'},
    FIN: {name:'Finance', category:'Finance', icon:'fa-coins', description:'Finance requests, approvals and financial operations.'},
    PROC: {name:'Procurement', category:'Procurement', icon:'fa-cart-shopping', description:'Purchasing requests, sourcing and procurement approvals.'},
    ADMIN: {name:'Administration', category:'Administration', icon:'fa-building', description:'Office administration and shared services.'},
    IT: {name:'Information Technology', category:'IT', icon:'fa-laptop-code', description:'IT service requests, assets and technology operations.'},
    LEGAL: {name:'Legal & Compliance', category:'Legal & Compliance', icon:'fa-scale-balanced', description:'Legal, compliance and policy workflows.'},
    CORP: {name:'Corporate Operations', category:'Corporate Operations', icon:'fa-sitemap', description:'Cross-functional corporate operations and coordination.'}
  };
  const department = config[code];
  const message = document.getElementById('login-message');
  const button = document.getElementById('login-submit');
  const setMessage = (text, kind) => {
    message.textContent = text;
    message.className = 'message ' + (kind || 'info');
    message.hidden = false;
  };
  if (!department) {
    setMessage('This department portal is not configured. Please use the main OfficeFlow sign-in.', 'error');
    button.disabled = true;
    return;
  }
  document.title = 'OfficeFlow | ' + department.name + ' Sign In';
  document.getElementById('department-name').textContent = department.name;
  document.getElementById('department-description').textContent = department.description;
  document.getElementById('department-icon').className = 'fa-solid ' + department.icon;

  form.addEventListener('submit', async function (event) {
    event.preventDefault();
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    button.disabled = true;
    button.textContent = 'Verifying access…';
    setMessage('Signing in securely and checking your department assignment…', 'info');
    try {
      const {data, error} = await supabase.auth.signInWithPassword({email, password});
      if (error || !data.user) throw new Error(error?.message || 'Invalid email or password.');
      const {data: profile, error: profileError} = await supabase
        .from('profiles')
        .select('role, organization_id, unit_id')
        .eq('id', data.user.id)
        .single();
      if (profileError || !profile) {
        await supabase.auth.signOut();
        throw new Error('Your OfficeFlow profile could not be verified. Contact your organization administrator.');
      }
      const role = profile.role || 'employee';
      const isAdmin = role === 'administrator' || role === 'super_admin';
      if (!isAdmin) {
        const {data: dept, error: deptError} = await supabase
          .from('departments')
          .select('id,name,code')
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();
        if (deptError || !dept) {
          await supabase.auth.signOut();
          throw new Error('This department is not active for your organization. Contact your administrator.');
        }
        if (!profile.unit_id || profile.unit_id !== dept.id) {
          await supabase.auth.signOut();
          throw new Error('Access denied: this account is not assigned to ' + department.name + '. Ask your administrator to assign the correct department.');
        }
      }
      setMessage('Access verified. Opening ' + department.name + '…', 'success');
      window.location.replace('/dashboard/operational-module.html?category=' + encodeURIComponent(department.category));
    } catch (error) {
      setMessage(error && error.message ? error.message : 'Sign-in failed. Please try again.', 'error');
      button.disabled = false;
      button.textContent = 'Sign in to ' + department.name;
    }
  });
})();