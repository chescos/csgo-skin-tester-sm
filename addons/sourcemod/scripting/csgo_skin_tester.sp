#pragma semicolon 1

/**
 * *********************************************************************************************************
 * INCLUDES
 * *********************************************************************************************************
 */

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <smjansson>
#include <SteamWorks>
#include <socket>
#include <logdebug>

/**
 * *********************************************************************************************************
 * DEFINES
 * *********************************************************************************************************
 */

#define PLUGIN_NAME									"CS:GO Skin Tester"
#define PLUGIN_VERSION							"0.1.0"
#define LENGTH_IP										20
#define LENGTH_PORT									2
#define LENGTH_PAINTKIT_NAME				100
#define LENGTH_ITEM_NAME						100
#define LENGTH_ITEM_CLASS						100
#define LENGTH_ITEM_NAME_TECHNICAL	100
#define LENGTH_ITEM_TYPE						100
#define LENGTH_URL									128

/**
 * *********************************************************************************************************
 * PLUGIN INFO
 * *********************************************************************************************************
 */

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "chescos",
	description = "CS:GO Skin Tester - Inspect skins in-game",
	version = PLUGIN_VERSION
};

/**
 * *********************************************************************************************************
 * GLOBALS
 * *********************************************************************************************************
 */

new String:g_sServerIP[20];
new String:g_sServerPort[6];
new String:g_sServerSlots[2];

new Handle:g_hSocketIP;
new Handle:g_hSocketPort;

new Handle:g_hSocket;

new Handle:g_hPlayerSkins[MAXPLAYERS+1];

/**
 * *********************************************************************************************************
 * MAIN EVENTS
 * *********************************************************************************************************
 */

public OnPluginStart()
{
	InitDebugLog("debug_csgo_skin_tester", "csgo_skin_tester");

	LogDebug("OnPluginStart");

	// event hooks
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	// create convars
	g_hSocketIP = CreateConVar("sm_st_socket_ip", "", "IP address of the socket server", FCVAR_PROTECTED, false, 0.0, false, 0.0);
	g_hSocketPort = CreateConVar("sm_st_socket_port", "", "Port of the socket server", FCVAR_PROTECTED, false, 0.0, false, 0.0);

	AutoExecConfig(true, "csgo_skin_tester");

	// get server port
	new iPort = GetConVarInt(FindConVar("hostport"));
	Format(g_sServerPort, sizeof(g_sServerPort), "%d", iPort);

	// get server IP
	new iHostip = GetConVarInt(FindConVar("hostip"));
	Format(g_sServerIP, sizeof(g_sServerIP), "%d.%d.%d.%d", iHostip >>> 24 & 255, iHostip >>> 16 & 255, iHostip >>> 8 & 255, iHostip & 255);

	// get slots
	new iSlots = MaxClients;
	Format(g_sServerSlots, sizeof(g_sServerSlots), "%d", iSlots);

	// create a new tcp socket
	g_hSocket = SocketCreate(SOCKET_TCP, OnSocketError);

	// repeated heartbeat timer
	CreateTimer(10.0, TimerSendHeartbeat, _, TIMER_REPEAT);

	for(new i = 1; i <= MaxClients; i++) {
		if(IsValidClient(i)) {
			SDKHook(i, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
		}
	}
}

public OnConfigsExecuted()
{
	LogDebug("OnConfigsExecuted");

	// connect to socket as soon as sourcemod configs have been executed
	// need to wait for this event because we need to read the sm_st_socket_ip and sm_st_socket_port convar values
	ConnectToSocket();
}

public OnPluginEnd()
{
	LogDebug("OnPluginEnd");
}

public OnClientPutInServer(int client)
{
	LogDebug("OnClientPutInServer for client %d", client);

	if(IsValidClient(client)) {
		SDKHook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
	}
}

public OnClientDisconnect(int client)
{
	ClearSkin(client);
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) > CS_TEAM_SPECTATOR) {
		new Handle:hData = json_object();
		new String:sIP[LENGTH_IP];

		GetClientIP(client, sIP, sizeof(sIP));
		json_object_set_new(hData, "ip", json_string(sIP));

		SendSocketMessage("player-spawned", hData);
	}

	return Plugin_Continue;
}

public Action:OnPostWeaponEquip(int client, int weapon)
{
	LogDebug("OnPostWeaponEquip (client %d, weapon %d)", client, weapon);

	// player has no pending skin
	if(g_hPlayerSkins[client] == INVALID_HANDLE) {
		LogDebug("No pending skin");
		return;
	}

	// weapon is invalid
	if(weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon)) {
		LogDebug("Weapon is invalid", weapon);
		return;
	}

	new iOwner = GetEntProp(weapon, Prop_Send, "m_hPrevOwner");

	// weapon has a previous owner
	if(iOwner > 0) {
		LogDebug("Weapon has previous owner: %d", iOwner);
		return;
	}

	decl String:sClassname[LENGTH_ITEM_CLASS];

	// can not get classname or classname has no valid skins
	if(!GetEdictClassname(weapon, sClassname, sizeof(sClassname)) || StrEqual(sClassname, "weapon_taser") || StrEqual(sClassname, "weapon_c4")) {
		LogDebug("Weapon classname %s does not qualify", sClassname);
		return;
	}

	new iWeaponIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	LogDebug("Weapon with classname %s, weapon index %d, owner %d passed", sClassname, iWeaponIndex, iOwner);

	// weapon is default CT knife or a default T knife, replace with selected knife
	if(iWeaponIndex == 42 || iWeaponIndex == 59) {
		decl String:sItemNameTechnical[LENGTH_ITEM_NAME_TECHNICAL];
		GetTrieString(g_hPlayerSkins[client], "item_name_technical", sItemNameTechnical, sizeof(sItemNameTechnical));
		RemovePlayerItem(client, weapon);
		AcceptEntityInput(weapon, "Kill");
		new iKnife = GivePlayerItem(client, sItemNameTechnical);
		EquipPlayerWeapon(client, iKnife);
		LogDebug("Replaced knife with %s", sItemNameTechnical);
		return;
	}

	new iItemDefindex;

	GetTrieValue(g_hPlayerSkins[client], "item_defindex", iItemDefindex);

	// weapon defindex does not match the defindex of the selected skin
	if(iItemDefindex != iWeaponIndex) {
		LogDebug("Entry found for classname %s for client %d but weapon defindex %d does not match paintkit defindex %d", sClassname, client, iWeaponIndex, iItemDefindex);
		return;
	}

	new iPaintkit;
	new iStattrak;
	new iSeed;
	new Float:fWear;

	GetTrieValue(g_hPlayerSkins[client], "paintkit_defindex", iPaintkit);
	GetTrieValue(g_hPlayerSkins[client], "stattrak", iStattrak);
	GetTrieValue(g_hPlayerSkins[client], "seed", iSeed);
	GetTrieValue(g_hPlayerSkins[client], "wear", fWear);

	LogDebug("Found paintkit %d", iPaintkit);

	decl String:sPaintkitName[LENGTH_PAINTKIT_NAME], String:sItemName[LENGTH_ITEM_NAME];

	GetTrieString(g_hPlayerSkins[client], "paintkit_name", sPaintkitName, sizeof(sPaintkitName));
	GetTrieString(g_hPlayerSkins[client], "item_name", sItemName, sizeof(sItemName));

	ChangePaint(weapon, iPaintkit, iSeed, iStattrak, fWear);

	ClearSkin(client);
}

/**
 * *********************************************************************************************************
 * SOCKET EVENTS
 * *********************************************************************************************************
 */

public OnSocketConnected(Handle:socket, any:arg) {
	LogDebug("OnSocketConnected");

	SendHeartbeat();
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:arg) {
	LogDebug("OnSocketReceive");
	LogDebug("Received socket data: %s", receiveData);

	// create new JSON handle from received data
	new Handle:hArray = json_load(receiveData);

	decl String:sEvent[64];

	json_array_get_string(hArray, 0, sEvent, sizeof(sEvent));
	new Handle:hObj = json_array_get(hArray, 1);

	// do stuff, forward the event with the obj data
	if(StrEqual(sEvent, "skin-created")) {
		OnSocketSkinCreated(hObj);
	}

	// close the handle
	CloseHandle(hArray);
}

public OnSocketDisconnected(Handle:socket, any:arg) {
	// connection: close advises the webserver to close the connection when the transfer is finished, we're done here
	LogDebug("OnSocketDisconnected");

	// we need to manually disconnect the socket
	// this will not close the handle, the socket will be reset to a state similar to after SocketCreate()
	if(SocketIsConnected(g_hSocket)) {
		SocketDisconnect(g_hSocket);
		LogDebug("Manually disconnected socket on disconnect");
	}
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg) {
	// a socket error occured
	LogDebug("OnSocketError");
	LogDebug("Socket error %d (errno %d)", errorType, errorNum);

	// we need to manually disconnect the socket
	// this will not close the handle, the socket will be reset to a state similar to after SocketCreate()
	if(SocketIsConnected(g_hSocket)) {
		SocketDisconnect(g_hSocket);
		LogDebug("Manually disconnected socket on error");
	}
}

/**
 * *********************************************************************************************************
 * SOCKET MESSAGE EVENTS
 * *********************************************************************************************************
 */

void OnSocketSkinCreated(Handle:hObj)
{
	LogDebug("OnSocketSkinCreated");

	decl String:sIP[LENGTH_IP];
	json_object_get_string(hObj, "ip", sIP, sizeof(sIP));

	new client = FindClientByIP(sIP);

	if(client == -1) {
		LogDebug("No client has been found for IP %s", sIP);
		return;
	}

	new Handle:hTrie = CreateTrie();

	decl String:sPaintkitName[LENGTH_PAINTKIT_NAME], String:sItemName[LENGTH_ITEM_NAME], String:sItemClass[LENGTH_ITEM_CLASS];
	decl String:sItemNameTechnical[LENGTH_ITEM_NAME_TECHNICAL], String:sItemType[LENGTH_ITEM_TYPE];

	json_object_get_string(hObj, "paintkit_name", sPaintkitName, sizeof(sPaintkitName));
	json_object_get_string(hObj, "item_name", sItemName, sizeof(sItemName));
	json_object_get_string(hObj, "item_class", sItemClass, sizeof(sItemClass));
	json_object_get_string(hObj, "item_name_technical", sItemNameTechnical, sizeof(sItemNameTechnical));
	json_object_get_string(hObj, "item_type", sItemType, sizeof(sItemType));

	new iPaintkitDefindex, iItemDefindex, iSeed, iStattrak, Float:fWear;

	iPaintkitDefindex = json_object_get_int(hObj, "paintkit_defindex");
	iItemDefindex = json_object_get_int(hObj, "item_defindex");
	iSeed = json_object_get_int(hObj, "seed");
	iStattrak = json_object_get_int(hObj, "stattrak");
	fWear = json_object_get_float(hObj, "wear");

	SetTrieString(hTrie, "paintkit_name", sPaintkitName, false);
	SetTrieString(hTrie, "item_name", sItemName, false);
	SetTrieString(hTrie, "item_class", sItemClass, false);
	SetTrieString(hTrie, "item_name_technical", sItemNameTechnical, false);
	SetTrieString(hTrie, "item_type", sItemType, false);

	SetTrieValue(hTrie, "paintkit_defindex", iPaintkitDefindex, false);
	SetTrieValue(hTrie, "item_defindex", iItemDefindex, false);
	SetTrieValue(hTrie, "seed", iSeed, false);
	SetTrieValue(hTrie, "stattrak", iStattrak, false);
	SetTrieValue(hTrie, "wear", fWear, false);

	// Set the player skin.
	g_hPlayerSkins[client] = hTrie;

	// client qualifies for live update
	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) > CS_TEAM_SPECTATOR) {
		LogDebug("Client qualifies for live update");
		// skin is for a knife
		if(StrEqual(sItemClass, "weapon_knife")) {
			new iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
			if(iWeapon != -1) {
				RemovePlayerItem(client, iWeapon);
				AcceptEntityInput(iWeapon, "Kill");
				new iKnife = GivePlayerItem(client, sItemNameTechnical);
				EquipPlayerWeapon(client, iKnife);
				FakeClientCommand(client, "use weapon_knife");
			}
		}
		// skin is for some nice gloves
		else if(StrEqual(sItemClass, "wearable_item")) {
			ChangeGloves(client, iItemDefindex, iPaintkitDefindex, 0.01, 0);
		}
		// skin is for a weapon
		else {
			new iActiveWeapon;
			// weapon is a secondary
			if(StrEqual(sItemType, "Pistols")) {
				iActiveWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
			}
			// weapon is a primary
			else {
				iActiveWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
			}

			// remove active weapon if there is one
			if(iActiveWeapon != -1) {
				RemovePlayerItem(client, iActiveWeapon);
				AcceptEntityInput(iActiveWeapon, "Kill");
			}
			new iNewWeapon = GivePlayerItem(client, sItemNameTechnical);
			EquipPlayerWeapon(client, iNewWeapon);
			FakeClientCommand(client, "use %s", sItemClass);
		}
		PrintToChatCustom(client, "Applied paintkit %s for item %s.", sPaintkitName, sItemName);
	}

	LogDebug("Applied paintkit %s for item %s", sPaintkitName, sItemName);

	CloseHandle(hObj);
}

/**
 * *********************************************************************************************************
 * TIMERS
 * *********************************************************************************************************
 */

public Action:TimerSendHeartbeat(Handle:timer)
{
	ConnectToSocket();
	SendHeartbeat();

	return Plugin_Continue;
}

public Action ReactivateWeaponTimer(Handle:timer, DataPack:ph)
{
	ResetPack(ph);

	new client = EntRefToEntIndex(ReadPackCell(ph));
	new iItem = EntRefToEntIndex(ReadPackCell(ph));

	LogDebug("ReactivateWeaponTimer for client %d with item %d", client, iItem);

	if(client != INVALID_ENT_REFERENCE && iItem != INVALID_ENT_REFERENCE) {
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iItem);
	}

	CloseHandle(ph);
}

/**
 * *********************************************************************************************************
 * MAIN FUNCTIONS
 * *********************************************************************************************************
 */

void ConnectToSocket()
{
	// connect to socket server if not connected
	if(!SocketIsConnected(g_hSocket)) {
		decl String:sSocketIP[LENGTH_IP];
		GetConVarString(g_hSocketIP, sSocketIP, sizeof(sSocketIP));
		new iSocketPort = GetConVarInt(g_hSocketPort);

		LogDebug("Connecting to socket server at %s:%d...", sSocketIP, iSocketPort);
		SocketConnect(g_hSocket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, sSocketIP, iSocketPort);
	}
}

void ClearSkin(int client)
{
	if(g_hPlayerSkins[client] != INVALID_HANDLE) {
		ClearTrie(g_hPlayerSkins[client]);
		CloseHandle(g_hPlayerSkins[client]);
		g_hPlayerSkins[client] = INVALID_HANDLE;
	}
}

void SendHeartbeat()
{
	LogDebug("Sending heartbeat");

	new Handle:hData = json_object();

	json_object_set_new(hData, "ip", json_string(g_sServerIP));
	json_object_set_new(hData, "port", json_string(g_sServerPort));
	json_object_set_new(hData, "slots", json_string(g_sServerSlots));

	new Handle:hPlayers = json_array();

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i)) {
			new String:sIP[LENGTH_IP];
			GetClientIP(i, sIP, sizeof(sIP));
			json_array_append_new(hPlayers, json_string(sIP));
		}
	}

	json_object_set_new(hData, "players", hPlayers);

	SendSocketMessage("server-heartbeat", hData);
}

void SendSocketMessage(const String:sEvent[], Handle:hData)
{
	// socket is not connected
	if(!SocketIsConnected(g_hSocket)) {
		LogDebug("Can not send socket message (event: %s), socket is not connected", sEvent);
		return;
	}

	// crate a json array
	new Handle:hArray = json_array();

	// insert the data into the array in the correct format
	json_array_append_new(hArray, json_string(sEvent));
	json_array_append_new(hArray, hData);

	// transform the json object to a json string
	decl String:sJSON[4096];
	json_dump(hArray, sJSON, sizeof(sJSON), 0);

	// append "\n" to the JSON, necessary for our socket protocol
	StrCat(sJSON, sizeof(sJSON), "\n");

	// send the json string to the socket server
	SocketSend(g_hSocket, sJSON);

	LogDebug("Sent socket event %s, raw json: %s", sEvent, sJSON);

	// close the handle
	CloseHandle(hArray);
}


/**
 * *********************************************************************************************************
 * HELPER FUNCTIONS
 * *********************************************************************************************************
 */

void PrintToChatCustom(int client, const String:sMessage[], any:...)
{
	decl String:sBuffer[512];
	decl String:sFormattedMessage[512];

	SetGlobalTransTarget(client);

	Format(sBuffer, sizeof(sBuffer), " \x01\x0B\x02[CS:GO Skin Tester] \x04%s", sMessage);
	VFormat(sFormattedMessage, sizeof(sFormattedMessage), sBuffer, 3);

	PrintToChat(client, "%s", sFormattedMessage);
}

void ChangePaint(int weapon, int iPaintkit, int iSeed, int iStattrak, float fWear)
{
	// Member: m_iItemIDLow (offset 108) (type integer) (bits 32) (Unsigned)
	SetEntProp(weapon, Prop_Send,"m_iItemIDLow", -1);

	// Member: m_nFallbackPaintKit (offset 2308) (type integer) (bits 16) (Unsigned)
	SetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit", iPaintkit);
	// Member: m_flFallbackWear (offset 2316) (type float) (bits 0) (NoScale)
	SetEntPropFloat(weapon, Prop_Send, "m_flFallbackWear", fWear);
	// Member: m_nFallbackSeed (offset 2312) (type integer) (bits 10) (Unsigned)
	SetEntProp(weapon, Prop_Send, "m_nFallbackSeed", iSeed);
	// Member: m_nFallbackStatTrak (offset 2320) (type integer) (bits 20) ()
	SetEntProp(weapon, Prop_Send, "m_nFallbackStatTrak", iStattrak);

	LogDebug("Changed weapon %d to paintkit %d, seed %d, stattrak %d, wear %f", weapon, iPaintkit, iSeed, iStattrak, fWear);
}

void ChangeGloves(int client, int iDefindex, int iPaintkit, float fWear, int iSeed)
{
	// search for already existing gloves
	new iEnt = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");

	// delete existing gloves
	if(iEnt != -1) {
		AcceptEntityInput(iEnt, "KillHierarchy");
	}

	// create wearable entity
	new iWearable = CreateEntityByName("wearable_item");

	if(iWearable != -1) {
		// https://www.unknowncheats.me/forum/counterstrike-global-offensive/199679-glove-changer.html
		// https://www.unknowncheats.me/forum/counterstrike-global-offensive/195638-glove-model-names-skin-ids.html
		// set wearable entity on client
		SetEntPropEnt(client, Prop_Send, "m_hMyWearables", iWearable);
		// type of gloves
		SetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex", iDefindex);
		// exact gloves
		SetEntProp(iWearable, Prop_Send,  "m_nFallbackPaintKit", iPaintkit);
		// gloves seed
		SetEntProp(iWearable, Prop_Send, "m_nFallbackSeed", iSeed);
		// set perfect wear
		SetEntPropFloat(iWearable, Prop_Send, "m_flFallbackWear", fWear);
		// can be anything but 0
		SetEntProp(iWearable, Prop_Send, "m_iItemIDLow", 2048);
		// removes "[Wearables (Server) (230)]" error
		SetEntProp(iWearable, Prop_Send, "m_bInitialized", 1);
		// entity must be bind to client, else it wont work
		SetEntPropEnt(iWearable, Prop_Data, "m_hParent", client);
		SetEntPropEnt(iWearable, Prop_Data, "m_hOwnerEntity", client);
		// for third person
		SetEntPropEnt(iWearable, Prop_Data, "m_hMoveParent", client);
		// removes third person default gloves
		SetEntProp(client, Prop_Send, "m_nBody", 1);
		// spawn entity
		DispatchSpawn(iWearable);
	}

	// remove active weapon and assign it again with a timer
	// this is necessary to "reload" the gloves, else the old gloves will still be there
	ReactivateWeapon(client);
}

void ReactivateWeapon(int client)
{
	LogDebug("ReactivateWeapon for client %d", client);

	new iItem = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
	DataPack ph = new DataPack();
	WritePackCell(ph, EntIndexToEntRef(client));

	if(IsValidEntity(iItem)) {
		WritePackCell(ph, EntIndexToEntRef(iItem));
	}
	else {
		WritePackCell(ph, -1);
	}

	CreateTimer(0.1, ReactivateWeaponTimer, ph, TIMER_FLAG_NO_MAPCHANGE);
}

int FindClientByIP(const String:sIP[])
{
	new String:sTempIP[LENGTH_IP];

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i)) {
			// retrieve the players IP and compare it to the given IP
			if(GetClientIP(i, sTempIP, sizeof(sTempIP)) && StrEqual(sTempIP, sIP)) {
				return i;
			}
		}
	}

	return -1;
}

bool IsValidClient(int client)
{
	// check if the client is valid
	if(1 <= client && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)) {
		return true;
	}

	return false;
}
