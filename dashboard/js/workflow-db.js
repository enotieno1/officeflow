var OfficeFlowWorkflow = {
  async published() {
    const { data, error } = await supabase
      .from('workflow_versions')
      .select('id,version_no,status,workflow_definition_id,workflow_definitions(id,name)')
      .eq('status','published')
      .order('created_at',{ascending:false});
    if(error) throw error;
    return data || [];
  },
  async submit(versionId,title,payload,priority) {
    const { data,error } = await supabase.rpc('fn_submit_request',{
      p_workflow_version_id:versionId,
      p_title:title,
      p_payload:payload || {},
      p_priority:priority || 'normal'
    });
    if(error) throw error;
    return data;
  },
  async request(id) {
    const { data,error } = await supabase
      .from('requests')
      .select('id,title,payload,priority,status,attempt_no,submitted_by,created_at,updated_at,workflow_version_id')
      .eq('id',id).single();
    if(error) throw error;
    return data;
  },
  async steps(id) {
    const { data,error } = await supabase
      .from('request_steps')
      .select('id,step_order,status,decided_by,decided_at,due_at,escalated_at,workflow_step_id')
      .eq('request_id',id).order('step_order',{ascending:true});
    if(error) throw error;
    return data || [];
  },
  async stepDefinitions(versionId) {
    const { data,error } = await supabase
      .from('workflow_steps')
      .select('id,step_order,approver_role,name,sla_hours')
      .eq('workflow_version_id',versionId).order('step_order',{ascending:true});
    if(error) throw error;
    return data || [];
  },
  async decide(stepId,decision,comment) {
    const { data,error } = await supabase.rpc('fn_decide_request_step',{
      p_request_step_id:stepId,
      p_decision:decision,
      p_comment:comment || null
    });
    if(error) throw error;
    return data;
  }
};
