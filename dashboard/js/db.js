const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

async function getEmployees() {
  const { data, error } = await supabase.from('employees').select('*');
  if (error) console.error('Error:', error);
  return data || [];
}

async function getTransactions() {
  const { data, error } = await supabase.from('transactions').select('*').order('date', { ascending: false });
  if (error) console.error('Error:', error);
  return data || [];
}

async function getTasks() {
  const { data, error } = await supabase.from('tasks').select('*').order('due_date', { ascending: true });
  if (error) console.error('Error:', error);
  return data || [];
}

async function getDocuments() {
  const { data, error } = await supabase.from('documents').select('*').order('created_at', { ascending: false });
  if (error) console.error('Error:', error);
  return data || [];
}
