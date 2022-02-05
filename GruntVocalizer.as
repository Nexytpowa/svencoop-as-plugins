//TODO: Code review and cleaning
// - Add customizable pitch for each word
// - Add support for more characters (scientist, vox) if sound cache supports it
// - Benchmark code and make it less dependant on steamID's to get player values

const string g_SoundFile = "scripts/plugins/cfg/GruntSounds.txt";

const int g_MinPitch = 50;
const int g_MaxPitch = 255;
const float g_DefaultVolume = 0.8f;

const int g_MinSpeed = 70;
const int g_MaxSpeed = 100;
const float g_DefaultSpeed = 0.888f; //Change this to reduce the pause between words for grunts (test carefully with many words)

// g_MulVocalDelay: Increase delay between sentences for each player connected
const float g_BaseVocalDelay = 10.0f;
const float g_MulVocalDelay = 0.5f; 

// Anti-Spam
const float g_MaxSpeechDuration = 15.0f; // Speech duration shall be limited to avoid sentences too long
const int g_MaxWords = 20;  // Max words in a sentence
const int g_MaxRepeatedWord = 3; // Max times a word can be repeated. Will decrement each time this limit is passed in a sentence

const uint g_MaxListLength = 48; // Max length a line can have in the list before jumping




dictionary g_SoundList;
dictionary g_SoundDuration;
dictionary g_PlayerDelays;
dictionary g_Pitch;
dictionary g_Volume;
dictionary g_Speed;

array<string> @g_SoundListKeys;
array<string> g_SoundListPrint;

CClientCommand g_GPitchCMD("gpitch", "Sets the grunt vocalizer's pitch ("+g_MinPitch+"-"+g_MaxPitch+")", @gpitch);
CClientCommand g_GlistCMD("glist", "Shows the available words for a given letter", @glist);
CClientCommand g_GVol("gvolume", "Set a global volume for grunt voicelines, (0-100)", @gvolume);
CClientCommand g_GVol_("gvol", "Set a global volume for grunt voicelines, (0-100)", @gvolume);
CClientCommand g_GSpeed("gspeed", "Word overlapping to reduce pause between words ("+g_MinSpeed+"-"+g_MaxSpeed+")", @gspeed);

class TimedWord
{
	CBasePlayer@ pPlayer;
	string word;
	float time;
	int pitch;
	
	TimedWord(CBasePlayer@ ply, string inWord, float inTime, int inPitch)
	{
		@pPlayer = ply;
		word = inWord;
		time = inTime;
		pitch = inPitch;
	}
}

array<TimedWord@> g_GruntSentences;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Nexy");
	g_Module.ScriptInfo.SetContactInfo("https://steamcommunity.com/id/nexytpowa/");

	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	SetupVocalizer();
}

void MapInit()
{
	SetupVocalizer();
}

void SetupVocalizer()
{
	g_SoundList.deleteAll();
	ReadSounds();

	for (uint i = 0; i < g_SoundListKeys.length(); ++i)
	{
		g_SoundSystem.PrecacheSound(string(g_SoundList[g_SoundListKeys[i]]));
	}
	
	g_Scheduler.SetInterval("GVocalThink", 0.015f);
}

void ReadSounds()
{
	g_SoundListPrint = array<string>();
	
	File@ file = g_FileSystem.OpenFile(g_SoundFile, OpenFile::READ);
	if (file !is null && file.IsOpen())
	{
		while (!file.EOFReached())
		{
			string sLine;
			file.ReadLine(sLine);
			
			if (sLine.SubString(0, 1) == "#" || sLine.IsEmpty())
				continue;

			array<string> parsed = sLine.Split(" ");
			if (parsed.length() < 3)
				continue;

			// 0 = filename, 1 = duration, 2 = replacement name
			g_SoundList[parsed[2]] = "hgrunt/"+parsed[0]+".wav";
			g_SoundDuration[parsed[2]] = atof(parsed[1]);
		}
		file.Close();
		
		
		@g_SoundListKeys = g_SoundList.getKeys();
		g_SoundListKeys.sortAsc();


		
		//Generating sorted list of all vocalizer words
		string oldLetter = g_SoundListKeys[0][0];
		uint lineLength = 0;
		string soundsLine = "";
		for(uint i = 0; i < g_SoundListKeys.length(); ++i)
		{
			string key = g_SoundListKeys[i];
			if(oldLetter != key[0] || lineLength >= g_MaxListLength)
			{
				g_SoundListPrint.insertLast("["+oldLetter.ToUppercase()+"]: "+soundsLine+"\n");
				soundsLine = "";
				lineLength = 0;
				oldLetter = key[0];
			}
			soundsLine += key + " | ";
			lineLength += key.Length();
		}
		g_SoundListPrint.insertLast("["+oldLetter.ToUppercase()+"]: "+soundsLine+"\n");
	}
}

void setPitch(CBasePlayer@ pPlayer, int inPitch)
{
	const string steamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	int pitch = Math.clamp(g_MinPitch, g_MaxPitch, inPitch);
	g_Pitch[steamID] = pitch;
	g_PlayerFuncs.SayText(pPlayer, "[GruntVocalizer] Pitch set to: " + pitch + ".\n");
}

void setVolume(CBasePlayer@ pPlayer, int inVolume)
{
	const string steamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	int volume = Math.clamp(0, 100, inVolume);
	g_Volume[steamID] = float(volume)/100;
	g_PlayerFuncs.SayText(pPlayer, "[GruntVocalizer] Volume set to: " + volume + "%\n");
}

void setPauseSpeed(CBasePlayer@ pPlayer, int inSpeed)
{
	const string steamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	int speed = Math.clamp(g_MinSpeed, g_MaxSpeed, inSpeed);
	g_Speed[steamID] = float(speed)/100;
	g_PlayerFuncs.SayText(pPlayer, "[GruntVocalizer] Speed set to: " + speed + ".\n");
}

int getPitch(CBasePlayer@ pPlayer)
{
	const string steamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	return (g_Pitch.exists(steamID) ? int(g_Pitch[steamID]) : 100);
}

void gpitch(const CCommand@ pArgs)
{
	if (pArgs.ArgC() < 2)
		return;
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	setPitch(pPlayer, atoi(pArgs[1]));
}

void gvolume(const CCommand@ pArgs)
{
	if (pArgs.ArgC() < 2)
		return;
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	setVolume(pPlayer, atoi(pArgs[1]));
}

void gspeed(const CCommand@ pArgs)
{
	if (pArgs.ArgC() < 2)
		return;
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	setPauseSpeed(pPlayer, atoi(pArgs[1]));
}

void glist(const CCommand@ pArgs)
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	
	g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, "Printing all grunt voicelines for a total of ["+g_SoundList.getSize()+"] words.\n");
	for(uint i = 0; i < g_SoundListPrint.length(); ++i)
	{
		g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCONSOLE, g_SoundListPrint[i]);
	}
}

bool SortWords(const TimedWord @&in a, const TimedWord@&in b)
{
	return a.time > b.time;
}

HookReturnCode ClientSay(SayParameters@ pParams)
{
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	const CCommand@ pArguments = pParams.GetArguments();
	const string soundCMD = pArguments.Arg(0).ToLowercase();
	
	if(pArguments.ArgC() <= 1)
		return HOOK_CONTINUE;
	
	if(soundCMD[0] != 'g')
		return HOOK_CONTINUE;
	
	if(soundCMD != "g")
	{
		if(soundCMD == "gpitch")
		{
			setPitch(pPlayer, atoi(pArguments.Arg(1)));
			pParams.ShouldHide = true;
			return HOOK_HANDLED;
		}
		if(soundCMD == "gvol")
		{
			setVolume(pPlayer, atoi(pArguments.Arg(1)));
			pParams.ShouldHide = true;
			return HOOK_HANDLED;
		}
		if(soundCMD == "gspeed")
		{
			setPauseSpeed(pPlayer, atoi(pArguments.Arg(1)));
			pParams.ShouldHide = true;
			return HOOK_HANDLED;
		}
		return HOOK_CONTINUE;
	}
	
	if(pArguments.ArgC()-1 >= g_MaxWords)
	{
		g_PlayerFuncs.SayText(pPlayer, "[GruntVocalizer] You cannot make a sentence with more than "+ g_MaxWords +" words.\n");
		return HOOK_CONTINUE;
	}
	
	string steamID = g_EngineFuncs.GetPlayerAuthId(pPlayer.edict());
	float CurrentDelay = float(g_PlayerDelays[steamID]) - g_EngineFuncs.Time();
	if(CurrentDelay > 0)
	{
		g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTCENTER, "Wait "+int(CurrentDelay+1.0)+" more seconds!\n");
		return HOOK_CONTINUE;
	}
	
	int pitch = getPitch(pPlayer);
	float pitchMul = 100.0f/float(pitch);
	float speed = (g_Speed.exists(steamID) ? float(g_Speed[steamID]) : g_DefaultSpeed);
	
	dictionary repeated_words;
	int max_word_repeat = g_MaxRepeatedWord;
	
	float incTime = 0.0f;
	int validWordsCount = 0;
	int invalidWordsCount = 0;
	for(int i = 1; i < pArguments.ArgC(); ++i)
	{
		string keyword = pArguments.Arg(i);
		if(!g_SoundList.exists(keyword))
		{
			invalidWordsCount++;
			continue;
		}
		
		if(repeated_words.exists(keyword))
		{
			int rtcount = int(repeated_words[keyword]) + 1;
			repeated_words[keyword] = rtcount;
			if(rtcount >= max_word_repeat)
			{
				max_word_repeat = (max_word_repeat >= 1 ? max_word_repeat-1 : 1);
				continue;
			}
		}
		else
		{
			repeated_words[keyword] = 0;
		}
			
		float duration = float(g_SoundDuration[keyword])*speed;
		g_GruntSentences.insertLast( TimedWord(pPlayer, keyword, g_EngineFuncs.Time() + incTime, pitch) );
		validWordsCount++;
			
		incTime += duration*pitchMul;
		if(incTime >= g_MaxSpeechDuration)
			break;
	}
	repeated_words.deleteAll();
	
	if(validWordsCount > 0)
		g_PlayerDelays[steamID] = g_EngineFuncs.Time() + g_BaseVocalDelay + g_MulVocalDelay*float(g_PlayerFuncs.GetNumPlayers());
	
	if(g_GruntSentences.length() > 0)
		g_GruntSentences.sort(SortWords);
		
	// Keeps the message processable incase players want to talk on the server without the discord relay bot registering what they said
	return (invalidWordsCount > 0 ? HOOK_CONTINUE : HOOK_HANDLED);
}

void GVocalThink()
{
	int length = g_GruntSentences.length();
	while(length > 0)
	{
		TimedWord@ t = g_GruntSentences[length-1];
		if(g_EngineFuncs.Time() > t.time)
		{
			CBasePlayer@ plya = t.pPlayer;
			for (int i = 1; i <= g_Engine.maxClients; ++i) 
			{
				CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(i);
				if (plr is null or !plr.IsConnected())
					continue;
				
				string steamID = g_EngineFuncs.GetPlayerAuthId(plr.edict());
				float volume = g_DefaultVolume;
				if(g_Volume.exists(steamID))
					volume = float(g_Volume[steamID]);
				g_SoundSystem.PlaySound(plya.edict(), CHAN_AUTO, string(g_SoundList[t.word]), volume, 0.4f, 0, t.pitch, plr.entindex());
			}
			
			g_GruntSentences.removeLast();
		}
		else
			return;
		length--;
	}
}
