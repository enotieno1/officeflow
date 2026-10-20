import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const headers = { "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") ?? "https://officeflow.co.ke", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };
const reply = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), { status, headers });
const phoneKE = (v: unknown) => { if (typeof v !== "string") return null; const d=v.replace(/[\s()+-]/g,""); if (/^0[17]\d{8}$/.test(d)) return "254"+d.slice(1); if (/^254[17]\d{8}$/.test(d)) return d; return null; };
Deno.serve(async (req: Request) => {
 if (req.method==="OPTIONS") return new Response("ok",{headers});
 if (req.method!=="POST") return reply(405,{error:"Method not allowed"});
 const url=Deno.env.get("SUPABASE_URL"), anon=Deno.env.get("SUPABASE_ANON_KEY"), service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), secret=Deno.env.get("INTASEND_SECRET_KEY"), pub=Deno.env.get("INTASEND_PUBLISHABLE_KEY"), app=Deno.env.get("APP_BASE_URL");
 if (!url||!anon||!service||!secret||!pub||!app) return reply(503,{error:"Billing is not configured. No payment was initiated."});
 const auth=req.headers.get("Authorization");
 if (!auth?.startsWith("Bearer ")) return reply(401,{error:"Sign in to manage billing."});
 const userClient=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user},error:authErr}=await userClient.auth.getUser();
 if(authErr||!user) return reply(401,{error:"Session invalid or expired. Sign in again."});
 let body: Record<string,unknown>; try{body=await req.json()}catch{return reply(400,{error:"Invalid request."})}
 const planId=typeof body.plan_id==="string"?body.plan_id:"", method=body.payment_method;
 if(!planId||!["mpesa","card"].includes(String(method))) return reply(400,{error:"Choose an active plan and M-Pesa or card."});
 const phone=method==="mpesa"?phoneKE(body.phone_number):null;
 if(method==="mpesa"&&!phone) return reply(400,{error:"Enter a valid Kenyan mobile number."});
 const db=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:profile,error:pErr}=await db.from("profiles").select("organization_id,role").eq("id",user.id).maybeSingle();
 if(pErr||!profile?.organization_id||!["administrator","super_admin"].includes(profile.role)) return reply(403,{error:"Only an organization administrator can manage billing."});
 const {data:plan}=await db.from("billing_plans").select("id,name,amount,currency,interval_unit,interval_count").eq("id",planId).eq("is_active",true).maybeSingle();
 if(!plan) return reply(404,{error:"Plan unavailable. No payment was initiated."});
 const {data:existing}=await db.from("billing_subscriptions").select("id,status,plan_id").eq("organization_id",profile.organization_id).in("status",["pending","active","past_due"]).maybeSingle();
 if(existing?.status==="active") return reply(409,{error:"Organization already has an active subscription."});
 if(existing?.status==="past_due") return reply(409,{error:"Resolve the outstanding subscription before starting another."});
 if(existing?.status==="pending"&&existing.plan_id!==plan.id) return reply(409,{error:"A different subscription setup is already pending."});
 const subId=existing?.id??crypto.randomUUID();
 if(!existing){const {error}=await db.from("billing_subscriptions").insert({id:subId,organization_id:profile.organization_id,plan_id:plan.id,status:"pending",payment_method:method,provider:"intasend",created_by:user.id}); if(error)return reply(500,{error:"Could not start subscription setup."});}
 const apiRef="of-"+crypto.randomUUID(), origin=app.replace(/\/$/,""), meta=(user.user_metadata??{}) as Record<string,unknown>, names=(typeof meta.full_name==="string"?meta.full_name:"OfficeFlow Customer").trim().split(/\s+/);
 const payload={amount:Number(plan.amount),currency:plan.currency,email:user.email??"",first_name:names[0]||"OfficeFlow",last_name:names.slice(1).join(" ")||"Customer",phone_number:phone??undefined,api_ref:apiRef,redirect_url:origin+"/dashboard/billing.html?payment=pending",host:origin};
 let response:Response;
 try {
  response=method==="mpesa"
   ? await fetch("https://api.intasend.com/api/v1/payment/mpesa-stk-push/",{method:"POST",headers:{Authorization:"Bearer "+secret,"Content-Type":"application/json"},body:JSON.stringify(payload)})
   : await fetch("https://api.intasend.com/api/v1/checkout/",{method:"POST",headers:{"X-IntaSend-Public-API-Key":pub,"Content-Type":"application/json"},body:JSON.stringify(payload)});
 } catch { return reply(502,{error:"Payment provider unreachable. No successful payment recorded."}); }
 const provider=await response.json().catch(()=>({}));
 if(!response.ok) return reply(502,{error:"Payment provider rejected the request. No successful payment recorded."});
 const invoiceId=provider.invoice_id??provider.invoice?.invoice_id??provider.id, checkoutUrl=provider.url??provider.checkout_url??null;
 if(!invoiceId) return reply(502,{error:"Provider returned no payment reference."});
 const {error:payErr}=await db.from("billing_payment_attempts").insert({organization_id:profile.organization_id,subscription_id:subId,plan_id:plan.id,initiated_by:user.id,provider:"intasend",payment_method:method,api_ref:apiRef,provider_invoice_id:String(invoiceId),amount:plan.amount,currency:plan.currency,status:"processing",provider_state:"PROCESSING",checkout_url:checkoutUrl});
 if(payErr) return reply(500,{error:"Provider may have started a payment prompt but OfficeFlow could not record it. Contact support before retrying.",reference:apiRef});
 return reply(200,{status:"processing",message:method==="mpesa"?"Complete the M-Pesa prompt on your phone. OfficeFlow will verify payment.":"Complete payment on the secure hosted checkout. OfficeFlow will verify payment.",checkout_url:checkoutUrl,reference:apiRef});
});