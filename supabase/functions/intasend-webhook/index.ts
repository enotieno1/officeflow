import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const reply=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json"}});
Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return reply(405,{error:"Method not allowed"});
 const url=Deno.env.get("SUPABASE_URL"), service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), secret=Deno.env.get("INTASEND_SECRET_KEY"), challenge=Deno.env.get("INTASEND_WEBHOOK_CHALLENGE");
 if(!url||!service||!secret||!challenge)return reply(503,{error:"Webhook verification is not configured."});
 let body:Record<string,unknown>;try{body=await req.json()}catch{return reply(400,{error:"Invalid JSON"});}
 if(typeof body.challenge!=="string"||body.challenge!==challenge)return reply(401,{error:"Webhook challenge mismatch"});
 const topic=typeof body.topic==="string"?body.topic:"collection_event";
 const invoice=(body.invoice&&typeof body.invoice==="object"?body.invoice:body) as Record<string,unknown>;
 const invoiceId=typeof invoice.invoice_id==="string"?invoice.invoice_id:"";
 const apiRef=typeof invoice.api_ref==="string"?invoice.api_ref:"";
 const incomingState=typeof invoice.state==="string"?invoice.state.toUpperCase():"";
 if(topic!=="collection_event"||!invoiceId||!apiRef||!incomingState)return reply(200,{received:true,ignored:true});
 const allowedStates=["PENDING","PROCESSING","RETRY","PARTIAL","COMPLETE","FAILED","CANCELED","CANCELLED"];
 if(!allowedStates.includes(incomingState))return reply(400,{error:"Unsupported payment state"});
 const db=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:attempt,error:lookupErr}=await db.from("billing_payment_attempts").select("id,api_ref,provider_invoice_id").eq("api_ref",apiRef).maybeSingle();
 if(lookupErr)return reply(503,{error:"Could not find payment attempt; retry webhook"});
 if(!attempt)return reply(200,{received:true,ignored:true});
 let response:Response;
 try{
  response=await fetch("https://api.intasend.com/api/v1/payment/status/",{
   method:"POST",
   headers:{Authorization:"Bearer "+secret,"Content-Type":"application/json"},
   body:JSON.stringify({invoice_id:invoiceId})
  });
 }catch{return reply(503,{error:"Provider verification unavailable; retry webhook"});}
 const statusBody=await response.json().catch(()=>({}));
 if(!response.ok)return reply(503,{error:"Provider verification failed; retry webhook"});
 const verified=(statusBody.invoice&&typeof statusBody.invoice==="object"?statusBody.invoice:statusBody) as Record<string,unknown>;
 const verifiedId=String(verified.invoice_id??"");
 const verifiedRef=String(verified.api_ref??"");
 const verifiedState=String(verified.state??"").toUpperCase();
 const amount=Number(verified.value);
 const currency=String(verified.currency??"");
 if(verifiedId!==invoiceId||verifiedRef!==apiRef||!Number.isFinite(amount)||!currency||!allowedStates.includes(verifiedState)){
  return reply(409,{error:"Verified provider invoice does not match the event"});
 }
 if(attempt.provider_invoice_id&&attempt.provider_invoice_id!==invoiceId)return reply(409,{error:"Invoice ID does not match the stored attempt"});
 // Events may arrive out of order. The status API's verified current state is authoritative.
 // Key by the incoming event state so a replay is idempotent while stale events cannot downgrade a paid attempt.
 const eventKey=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(["intasend",topic,invoiceId,incomingState].join(":"))).then(h=>Array.from(new Uint8Array(h)).map(b=>b.toString(16).padStart(2,"0")).join(""));
 const {data:result,error:reconcileErr}=await db.rpc("fn_reconcile_intasend_payment",{
  p_event_key:eventKey,
  p_topic:topic,
  p_invoice_id:invoiceId,
  p_api_ref:apiRef,
  p_provider_state:verifiedState,
  p_provider_reference:verified.provider_ref??verified.mpesa_reference??null,
  p_amount:amount,
  p_currency:currency,
  p_failure_reason:verified.failed_reason??verified.failed_code??null
 });
 if(reconcileErr)return reply(503,{error:"Payment verification succeeded but reconciliation needs retry"});
 return reply(200,{received:true,status:result?.status??verifiedState.toLowerCase(),duplicate:result?.duplicate===true});
});