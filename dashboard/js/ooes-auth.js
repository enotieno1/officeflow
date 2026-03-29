var OOES_AUTH = {
  SESSION_KEY: 'ooesSession',
  SESSION_DURATION: 28800000,
  DEMO_ACCOUNTS: [
    {email:'admin@ooes.co.ke',password:'Admin@2024',name:'Admin User',role:'admin'},
    {email:'manager@ooes.co.ke',password:'Manager@2024',name:'Office Manager',role:'manager'},
    {email:'demo@ooes.co.ke',password:'Demo@2024',name:'Demo User',role:'viewer'}
  ],
  createSession:function(u){var s={email:u.email,name:u.name,role:u.role||'viewer',expires:Date.now()+this.SESSION_DURATION};localStorage.setItem(this.SESSION_KEY,JSON.stringify(s));return s;},
  getSession:function(){try{var r=localStorage.getItem(this.SESSION_KEY);if(!r)return null;var s=JSON.parse(r);if(Date.now()>s.expires){this.logout(false);return null;}return s;}catch(e){return null;}},
  isLoggedIn:function(){return this.getSession()!==null;},
  login:function(email,password){var a=this.DEMO_ACCOUNTS.find(function(a){return a.email.toLowerCase()===email.toLowerCase()&&a.password===password;});if(a)return this.createSession(a);var reg=JSON.parse(localStorage.getItem('ooesRegistered')||'[]');var u=reg.find(function(u){return u.email.toLowerCase()===email.toLowerCase()&&u.password===password;});if(u)return this.createSession(u);return null;},
  register:function(fn,ln,email,password){var reg=JSON.parse(localStorage.getItem('ooesRegistered')||'[]');if(reg.find(function(u){return u.email.toLowerCase()===email.toLowerCase();}))return{error:'Email already exists.'};var u={email:email,name:fn+' '+ln,password:password,role:'viewer'};reg.push(u);localStorage.setItem('ooesRegistered',JSON.stringify(reg));return this.createSession(u);},
  logout:function(redirect){localStorage.removeItem(this.SESSION_KEY);if(redirect!==false)window.location.href='/dashboard/auth.html';},
  requireAuth:function(){if(!this.isLoggedIn()){window.location.replace('/dashboard/auth.html');return false;}return true;},
  renderUserInfo:function(){var s=this.getSession();if(!s)return;document.querySelectorAll('[data-user-name]').forEach(function(el){el.textContent=s.name;});document.querySelectorAll('[data-user-email]').forEach(function(el){el.textContent=s.email;});}
};
(function(){if(!window.location.pathname.includes('auth.html')){document.addEventListener('DOMContentLoaded',function(){if(OOES_AUTH.requireAuth())OOES_AUTH.renderUserInfo();});}})();
