//Grapple hook v18/10/22a

float g_grappleCooldown = 0.1f;
float g_grappleDist = 2048.f;

string sndGrappleStart = "grapple/grapplestart.ogg";
string sndGrappleHit = "grapple/grapplehit.ogg";

string g_ropeSprite = "sprites/tongue.spr";

array<GrappleHook> g_gphooks;
array<PlayerData> g_pd(33);

//Temporary command to enable hook
array<bool> g_enabled(33);
CClientCommand g_ToggleHook("grapple", "Enable grapple hook", @enableHook);

void enableHook(const CCommand@ pArgs)
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	int idx = plr.entindex();
	
	g_enabled[idx] = !g_enabled[idx];
		
		
	g_PlayerFuncs.SayText(plr, (g_enabled[idx] ? "Hook is enabled. Press E to use\n" : "Hook is now disabled.\n"));
	//g_PlayerFuncs.SayText(plr, pd.enabled);
}

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );
	SetupHooks();
	
	g_Scheduler.SetInterval("GrappleThink", 0.015);
}

void MapInit() 
{
	g_pd.resize(0);
	g_pd.resize(33);
	g_gphooks.resize(0);
	g_enabled.resize(0);
	g_enabled.resize(33);

	g_Game.PrecacheModel(g_ropeSprite);
	g_Game.PrecacheModel("models/egg.mdl");
	g_SoundSystem.PrecacheSound(sndGrappleStart);
	g_SoundSystem.PrecacheSound(sndGrappleHit);
}

void SetupHooks()
{
	g_Hooks.RegisterHook( Hooks::Player::PlayerUse, @PlayerUse);
	g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
	g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @ClientPutInServer);
}

void Debug(string str)
{
	g_PlayerFuncs.SayTextAll(null, str);
}

class PlayerData
{
	GrappleHook@ grapple;
	float lastGrapple = 0.f;
	bool enabled = false;
	
	bool IgnoreFallDamage()
	{
		return (g_Engine.time - lastGrapple <= 3.5f);
	}
	
	bool CanGrapple()
	{
		return (g_Engine.time - lastGrapple) >= g_grappleCooldown && (grapple is null);
	}
};

class GrappleHook
{
	GrappleHook(){}
	
	GrappleHook(CBasePlayer@ plr, Vector lookAt)
	{
		if(plr is null)
			return;
		@attachPlr = plr;
			
		@attachEnt = g_EntityFuncs.Create( "item_generic", plr.EarPosition() + lookAt * 150.f, plr.pev.angles, true );
		if(attachEnt is null)
		{
			//Debug("attachent was null");
			return;
		}
		attachEnt.pev.movetype = MOVETYPE_NOCLIP;
		attachEnt.pev.scale = 0.05f;
		g_EntityFuncs.DispatchSpawn( attachEnt.edict() );
		
		startTime = g_Engine.time;
		killTime = g_Engine.time + 5.0f;
		
		plrStartVelocity = attachPlr.pev.velocity * Vector(1,1,0);
		plrStartLookAt = lookAt;
		
		launching = true;
		attachEnt.pev.velocity = attachEnt.pev.velocity + plrStartLookAt * 1550.f;
		
		te_beament(attachPlr, attachEnt, g_ropeSprite, 0, 0, int(killTime*10), 12, 12, 0);
		
		g_SoundSystem.PlaySound(attachEnt.edict(), CHAN_STREAM, sndGrappleStart, 1.0f, 0.4f, 0, 100);
		
		g_gphooks.insertLast(this);
	}
	
	void Delete()
	{
		if(attachEnt !is null)
		{
			PlayerData@ pd = g_pd[attachPlr.entindex()];
			@pd.grapple = null;
			pd.lastGrapple = g_Engine.time;
		
			te_killbeam(attachEnt);
			//Debug("Hook killed.");
			g_EntityFuncs.Remove(attachEnt);
		}
	}
	
	void LaunchFly()
	{
		TraceResult tr;
		Vector vecSrc = attachEnt.pev.origin;
		Vector vecEnd = vecSrc + plrStartLookAt * 50.f;
		float dist = (attachPlr.pev.origin - vecSrc).Length();
		
		if(dist > 2048.f)
		{
			killTime = 0.f;
			return;
		}
		
		g_Utility.TraceLine( vecSrc, vecEnd, ignore_monsters, null, tr );		
		if(tr.fStartSolid == 1)
		{
			if(tr.fInWater == 1)
			{
				killTime = 0.f;
				//Debug("Hit skybox/water");
				return;
			}
			//Debug("Found surface!");
			attachEnt.pev.velocity = Vector(0,0,0);
			launching = false;
			
			g_SoundSystem.StopSound(attachEnt.edict(), CHAN_STREAM, sndGrappleStart, true);
			
			te_killbeam(attachEnt);
			te_beament(attachPlr, attachEnt, g_ropeSprite, 0, 0, int(killTime*10), 12, 1, 0);
			g_SoundSystem.PlaySound(attachPlr.edict(), CHAN_AUTO, sndGrappleHit, 1.0f, 0.4f, 0, 100);
			return;
		}
	}
	
	void PullPlayer()
	{	
		if(attachPlr.pev.flags & FL_ONGROUND != 0)
		{
			attachPlr.SetOrigin(attachPlr.pev.origin + Vector(0,0,14));
		}
	
		Vector dir = (attachEnt.pev.origin - attachPlr.pev.origin);
		float dist = dir.Length();
		dir = dir / dist;
		
		float lerp = g_Engine.frametime*0.5f;
		
		if(dist < 200.f)
		{
			killTime = 0.f;
			attachPlr.pev.velocity = attachPlr.pev.velocity + dir * Vector(10.f, 10, 120);
			return;
		}
		
		if(attachPlr.m_afButtonLast & IN_JUMP != 0 && startTime < g_Engine.time - 0.4f)
		{
			//Debug("Jump kills hook");
			killTime = 0.f;
			attachPlr.pev.velocity = attachPlr.pev.velocity + dir * Vector(10.f, 10, 200);
		}
		else
		{
			float velBonus = attachPlr.pev.velocity.Length()*lerp;
			attachPlr.pev.velocity = attachPlr.pev.velocity + dir * Vector(10.f, 10, 30) * (velBonus < 1.0 ? 1.0 : velBonus) + plrStartVelocity * (lerp*2);
			
			float speed = (attachPlr.pev.velocity).Length();
			if(speed > 800)
			{
				attachPlr.pev.velocity = attachPlr.pev.velocity / speed * 800;
			}
		}
		
		Vector velDir = attachPlr.pev.velocity.Normalize();
		float dot = DotProduct(velDir, dir);
		if(dot < -0.05f && startTime < g_Engine.time - 1.0f)
		{
			//Debug("Dot kill!");
			killTime = 0.f;
		}
	}
	
	bool launching = false;
	
	float startTime = 0.f;
	float killTime = -1.f;
	
	Vector plrStartVelocity;
	Vector plrStartLookAt;
	
	CBasePlayer@ attachPlr;
	CBaseEntity@ attachEnt;
}

void GrappleThink()
{
	for(int i = 0; i < int(g_gphooks.size()); ++i)
	{
		GrappleHook@ ghook = g_gphooks[i];
		
		if(ghook.killTime < g_Engine.time)
		{
			//Debug("Hook expired.");
			ghook.Delete();
			g_gphooks.removeAt(i);
		}
		
		if(ghook.launching)
		{
			ghook.LaunchFly();
		}
		else
		{
			ghook.PullPlayer();
		}
	}
}



void te_beament(CBaseEntity@ srcEnt, CBaseEntity@ dstEnt, 
	string sprite=g_ropeSprite, int frameStart=0, 
	int frameRate=100, int life=10, int width=32, int noise=1, 
	int scroll=32,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null) {
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_BEAMENTS);
	m.WriteShort(srcEnt.entindex());
	m.WriteShort(dstEnt.entindex());
	m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
	m.WriteByte(frameStart);
	m.WriteByte(frameRate);
	m.WriteByte(life);
	m.WriteByte(width);
	m.WriteByte(noise);
	m.WriteByte(255);
	m.WriteByte(255);
	m.WriteByte(255);
	m.WriteByte(128); // actually brightness
	m.WriteByte(scroll);
	m.End();
}

void te_killbeam(CBaseEntity@ target, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_KILLBEAM);
	m.WriteShort(target.entindex());
	m.End();
}

HookReturnCode PlayerUse( CBasePlayer@ plr, uint& out flag )
{
	int idx = plr.entindex();
	int buttons = plr.m_afButtonPressed;
	
	if(buttons & IN_USE != 0 && plr.IsAlive())
	{
		PlayerData@ pd = g_pd[plr.entindex()];
		if(g_enabled[idx] && pd.CanGrapple())
		{
			TraceResult tr;
			Math.MakeVectors( plr.pev.v_angle );
			Vector vecSrc = plr.pev.origin + plr.pev.view_ofs;
			Vector vecEnd = vecSrc + g_Engine.v_forward * g_grappleDist;
			
			g_Utility.TraceLine( vecSrc, vecEnd, ignore_monsters, null, tr );
			float dist = (vecSrc - tr.vecEndPos).Length();
			if(tr.fInWater == 0 && dist > 200.f && dist < 2048.f)
			{
				GrappleHook ghook = GrappleHook(plr, g_Engine.v_forward);
				@pd.grapple = ghook;
			
				//Debug("Hook started!");
			}
		}
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerTakeDamage( DamageInfo@ dmg_info )
{
	CBasePlayer@ plr = cast<CBasePlayer@>(dmg_info.pVictim);
	int dmgFlag = dmg_info.bitsDamageType;
	
	if(plr is null or dmgFlag & DMG_FALL == 0)
		return HOOK_CONTINUE;
		
	PlayerData@ pd = g_pd[plr.entindex()];
	if(pd.IgnoreFallDamage())
	{
		dmg_info.flDamage = 0;
	}
	
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientPutInServer( CBasePlayer@ plr )
{
	g_enabled[plr.entindex()] = false;
	
	return HOOK_CONTINUE;
}