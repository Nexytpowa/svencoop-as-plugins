const int server_id = 1;

const string g_InputFile = "scripts/plugins/store/discordinput.txt";
const string g_OutputFile = "scripts/plugins/store/discordoutput.txt";
//This is where map preview images are stored
const string g_ImagePathURL = "https://image.gametracker.com/images/maps/160x120/hl/";
array<string> g_BannedKeywords = { "https://", "http://" }; //Try not to put too many here

const string g_ChannelID = (server_id == 1 ? "927048975142490152" : "927049137151680582"); //for server 2
const string g_ChannelCMD = "say "+g_ChannelID+" ";
const string g_EmbedCMD = "embed "+g_ChannelID+" ";

const array<string> g_CountNames = { "st", "nd", "rd", "th" };

bool g_ChangingMap = false;
int g_OldPlayerCount = 0;
int g_RestartAttempts = 0;
string g_OldMap = "";

array<string> g_OutputQueue;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Nexy");
	g_Module.ScriptInfo.SetContactInfo("https://steamcommunity.com/id/nexytpowa/");
	
	g_Hooks.RegisterHook(Hooks::Game::MapChange, @MapChange);

	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @ClientPutInServer);
	g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @ClientDisconnect);
	
	//g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @OnPlayerKilled);
	
	g_Scheduler.SetInterval("OutputQueue", 0.150f);
	g_Scheduler.SetInterval("ProcessInput", 0.150f);
}

void ProcessInput()
{
	bool clearfile = false;
	File@ file = g_FileSystem.OpenFile(g_InputFile, OpenFile::READ);
	if (file !is null && file.IsOpen())
	{
		while (!file.EOFReached())
		{
			string sLine;
			file.ReadLine(sLine);
			
			if (sLine.IsEmpty())
				continue;
			
			array<string> args = sLine.Split(" ");
			
			if(args[0] == "say")
			{
				sLine.Truncate(120);
				g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, sLine.SubString(4));
			}
			else if(args[0] == "cmd")
			{
				g_EngineFuncs.ServerCommand(sLine.SubString(4)+"\n");
			}
			clearfile = true;
		}
		file.Close();
		
		// turns out you can't have read and write permissions together
		if(clearfile)
		{
			File@ fileW = g_FileSystem.OpenFile(g_InputFile, OpenFile::WRITE);
			fileW.Write("");
			fileW.Close();
		}
	}
}

void OutputQueue()
{
	if(g_OutputQueue.length() <= 0)
		return;
	
	File@ file = g_FileSystem.OpenFile(g_OutputFile, OpenFile::APPEND);
	if (file !is null && file.IsOpen())
	{
		for(uint i = 0; i < g_OutputQueue.length(); ++i)
		{
			file.Write(g_OutputQueue[i] + "\n");
		}
		g_OutputQueue.removeRange(0, g_OutputQueue.length());
		file.Close();
	}
}

HookReturnCode MapChange() 
{
	if(!g_ChangingMap)
	{
		g_OldPlayerCount = g_PlayerFuncs.GetNumPlayers();
		g_ChangingMap = true;
	}
	return HOOK_CONTINUE;
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer ) 
{
	//If i put this in MapInit it will execute twice when the server uses changelevel instead of map
	//at least the discord bot will only print map changes when theres a player online
	if(g_ChangingMap)
	{
		if(g_OldMap != g_Engine.mapname)
		{
			string mapName = g_Engine.mapname;		
			string nextMap_cvar = g_EngineFuncs.CVarGetString("mp_nextmap");
			string nextMapCycle_cvar = g_EngineFuncs.CVarGetString("mp_nextmap_cycle");
			string nextMap = (nextMap_cvar.Length() >= 2 ? nextMap_cvar : nextMapCycle_cvar);
			string title = "\"title\": " + "\"Map: "+mapName+"\", ";
			string description = "\"description\": " + "\"Currently playing "+mapName+" with "+g_OldPlayerCount+" player(s) connected."+"\", ";
			string image = "\"image\": { \"url\": \"" +g_ImagePathURL+mapName.ToLowercase()+".jpg\" }, ";
			string footnote = "\"footer\": { \"text\": \"" +"Next map: "+nextMap+ "\" } ";
		
			g_OutputQueue.insertLast(g_EmbedCMD + "{ " + title + description + image + footnote + "}");
			g_OldMap = mapName;
			g_RestartAttempts = 0;
		}
		else
		{
			g_OutputQueue.insertLast(g_ChannelCMD + "* Restarted map ``"+g_Engine.mapname+"`` for the ``"+(g_RestartAttempts+1)+g_CountNames[Math.clamp(0, 3, g_RestartAttempts)]+"`` time!");
			g_RestartAttempts++;
		}
		g_ChangingMap = false;
	}

	const string steamID = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	const string Out = "+  ``"+pPlayer.pev.netname+" has joined the game.``  ``"+steamID+"``";
	g_OutputQueue.insertLast(g_ChannelCMD+Out);

	return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
	const string steamID = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	const string Out = "-  ``"+pPlayer.pev.netname+" disconnected from the game.``  ``"+steamID+"``";
	g_OutputQueue.insertLast(g_ChannelCMD+Out);
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientSay(SayParameters@ pParams)
{
	if(pParams.ShouldHide)
		return HOOK_CONTINUE;
		
	const CCommand@ pArguments = pParams.GetArguments();
	if(pArguments.ArgC() <= 0)
		return HOOK_CONTINUE;
	
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	const string Name = (pPlayer.IsAlive() ? "" : "\\*DEAD\\* ") + pPlayer.pev.netname;
	string Said = pParams.GetCommand();
	for(uint i = 0; i < g_BannedKeywords.length(); ++i)
		Said.Replace(g_BannedKeywords[i], "");
	
	g_OutputQueue.insertLast(g_ChannelCMD+Name+": "+Said);
	
	return HOOK_CONTINUE;
}






HookReturnCode OnPlayerKilled(CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib)
{
	if(pPlayer.entindex() == pAttacker.entindex())
	{
		g_OutputQueue.insertLast(g_ChannelCMD+"> "+pPlayer.pev.netname+" suicided.");
		return HOOK_CONTINUE;
	}

	string AttackerName;
	if(pAttacker.IsPlayer())
	{
		AttackerName = pAttacker.pev.netname;
	}
	else
	{
		AttackerName = pAttacker.pev.classname;
	}
		
	string Out = "> "+pPlayer.pev.netname+" got "+(iGib == 2 ? "gibbed" : "killed")+" by "+AttackerName+".";
	g_OutputQueue.insertLast(g_ChannelCMD+Out);
	return HOOK_CONTINUE;
}
