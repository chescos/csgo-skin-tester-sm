## CS:GO Skin Tester SourceMod Plugin

This is the official CS:GO Skin Tester plugin which allows you to inspect the skins of other players in-game.

## Installation

### 1. Get yourself some Steam game server tokens

You should **never** use this plugin with your own [Steam game server tokens](https://steamcommunity.com/dev/managegameservers). Steam will permanently ban all your game server tokens and you will not be able to create new ones.

But there is an easy solution for this: [csgotokens.com](https://csgotokens.com) provides an awesome service. You can buy tokens for your CS:GO server there. Those tokens will get banned every 2-3 days but that's not an issue because csgotokens provides you with a plugin that automatically uses a brand new token everytime that your current token gets banned. Tokens for one whole month will cost you about $2.

### 2. Download the plugin

You bought some game server tokens? Okay, nice! The next step is to [download this repository](https://github.com/chescos/csgo-skin-tester-sm/archive/master.zip) and extract the .zip file.

### 3. Configure the plugin

Now you need to configure the plugin. Navigate to *cfg/sourcemod* and open the file *csgo_skin_tester.cfg* with a text editor. Fill out the socket IP and socket port where your CS:GO Skin Tester web app is running.

### 4. Upload files to your CS:GO server

After providing the config file with the socket connection settings, you can now upload the files to your game server. You only need to upload the *addons* and the *cfg* folder, they go into the game root folder (usually called *csgo*) of your server.

### 5. Change the SourceMod config

On your game server, navigate to *addons/sourcemod/configs* and open the file *core.cfg*. Search for `FollowCSGOServerGuidelines` and set it to `no`. Save and close the file.

### 6. Restart your server and test the plugin

The plugin will require a server restart in order to work. After your server has been restarted, you're ready to go.

# Requirements

All requirements are already included in the repository, you don't need to download and install them yourself.

* [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) - Used for communication with the HTTP API
* [Socket](https://forums.alliedmods.net/showthread.php?t=67640) - Used for communication through sockets
* [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604) - Used for JSON encoding and decoding

# Debugging

You can set the console variable `debug_csgo_skin_tester` to `32` and the plugin will log detailed messages to *addons/sourcemod/logs/debug_csgo_skin_tester.log*. The plugin uses Dr. McKay's logdebug implementation, more information can be found at the [AlliedMods thread](https://forums.alliedmods.net/showthread.php?t=258855).

# ConVars

* **sm_st_socket_ip** - IP address of the socket server (DEFAULT: "")
* **sm_st_socket_port** - Port of the socket server (DEFAULT: "")
