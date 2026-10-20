import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const reply=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json"}});
Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return reply(405,{error:"Method not allowed"});
 const url=Deno.env.get("SUPABASE_URL"), service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), secret=Deno.env.get("INTASEND_SECRET_KEY"), challenge=Deno.env.get("INTASEND_WEBHOOK_CHALLENGE");
 if(!url||!service||!secret||!challenge)return reply(503,{error:"Webhook verification is not configured."});
 let body:Record<string,unknown>;try{body=await req.json()}catch{return reply(400,{error:"Invalid JSON"})}
 if(typeof body.challenge!=="string"||body.challenge!==challenge)return reply(401,{error:"Webhook challenge mismatch"});
 const topic=typeof body.topic==="string"?body.topic:"collection_event", inv=(body.invoice&&typeof body.invoice==="object"?body.invoice:body) as Record<string,unknown>;
 const invoiceId=typeof inv.invoice_id==="string"?inv.invoice_id:"", apiRef=typeof inv.api_ref==="string"?inv.api_ref:"", incomingState=typeof inv.state==="string"?inv.state.toUpperCase():"";
 if(topic!=="collection_event"||!invoiceId||!apiRef||!incomingState)return reply(200,{received:true,ignored:true});
 const db=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:attempt,error:lookupErr}=await db.from("billing_payment_attempts").select("id,api_ref,amount,currency,subscription_id,plan_id,status").eq("api_ref",apiRef).maybeSingle();
 if(lookupErr)return reply(500,{error:"Could not reconcile payment"});
 if(!attempt)return reply(200,{received:true,ignored:true});
 let response:Response;try{response=await fetch("https://api.intasend.com/api/v1/payment/status/",{method:"POST",headers:{Authorization:"Bearer "+secret,"Content-Type":"application/json"},body:JSON.stringify({invoice_id:invoiceId})})}catch{return reply(502,{error:"Provider verification unavailable; retry webhook"})}
 const statusBody=await response.json().catch(()=>({}));if(!response.ok)return reply(502,{error:"Provider verification failed; retry webhook"});
 const v=(statusBody.invoice&&typeof statusBody.invoice==="object"?statusBody.invoice:statusBody) as Record<string,unknown>;
 const state=String(v.state??"").toUpperCase();
 if(String(v.api_ref??"")!==attempt.api_ref||String(v.invoice_id??invoiceId)!==invoiceId||Number(v.value)!==Number(attempt.amount)||String(v.currency??"")!==attempt.currency||state!==incomingState)return reply(409,{error:"Verified provider details do not match this payment"});
 const eventKey=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(["intasend",topic,invoiceId,state].join(":"))).then(h=>Array.from(new Uint8Array(h)).map(b=>b.toString(16).padStart(2,"0")).join(""));
 const {data:prior,error:priorErr}=await db.from("billing_provider_events").select("id,processed_at").eq("event_key",eventKey).maybeSingle();
 if(priorErr)return reply(500,{error:"Could not check event idempotency"});
 if(prior?.processed_at)return reply(200,{received:true,duplicate:true});
 if(!prior){const {error}=await db.from("billing_provider_events").insert({event_key:eventKey,topic,provider_invoice_id:invoiceId});if(error)return reply(503,{error:"Could not record event; retry webhook"});}
 const mapped=state==="COMPLETE"?"paid":state==="FAILED"?"failed":state==="CANCELED"?"cancelled":"processing";
 const update:Record<string,unknown>={status:mapped,provider_state:state,provider_reference:v.provider_ref??v.mpesa_reference??null,updated_at:new Date().toISOString()};
 if(mapped==="paid")update.verified_at=new Date().toISOString();
 if(mapped==="failed"||mapped==="cancelled")update.failure_reason=v.failed_reason??v.failed_code??state;
 const {error:updateErr}=await db.from("billing_payment_attempts").update(update).eq("id",attempt.id).neq("status","paid");
 if(updateErr)return reply(500,{error:"Payment update failed; retry webhook"});
 if(mapped==="paid"&&attempt.subscription_id){
  const {data:plan,error:planErr}=await db.from("billing_plans").select("interval_unit,interval_count").eq("id",attempt.plan_id).single();
  if(planErr||!plan)return reply(500,{error:"Payment verified but subscription activation needs reconciliation"});
  const start=new Date(),end=new Date(start);
  if(plan.interval_unit==="year")end.setUTCFullYear(end.getUTCFullYear()+Number(plan.interval_count));else end.setUTCMonth(end.getUTCMonth()+Number(plan.interval_count));
  const {error:subErr}=await db.from("billing_subscriptions").update({status:"active",current_period_start:start.toISOString(),current_period_end:end.toISOString(),updated_at:start.toISOString()}).eq("id",attempt.subscription_id);
  if(subErr)return reply(500,{error:"Payment verified but subscription activation failed; retry webhook"});
 }
 const {error:eventErr}=await db.from("billing_provider_events").update({processed_at:new Date().toISOString()}).eq("event_key",eventKey);
 if(eventErr)return reply(500,{error:"Event processed but audit finalization failed; safe to retry"});
 return reply(200,{received:true,status:mapped});
});