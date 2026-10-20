var supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// Legacy employees and transactions helpers were removed; those screens are retired until full HRIS and ledger modules are implemented.

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
