
((BROWSER :NAME "play 2048" :URL "http://gabrielecirulli.github.io/2048"
  :LUTRIS-ID 8)
 (WINE :NAME "Touhou 9" :EXEC
  "/mnt/Old_HDD/home/rush/Games/Touhou 9 - Phantasmagoria of Flower View/th09.exe"
  :PROFILE TOUHOUENV)
 (WINE :NAME "Touhou 8 - Imperishable Night" :EXEC
  "/mnt/Old_HDD/home/rush/Games/Touhou 8 - Imperishable Night/Touhou08.exe"
  :PROFILE TOUHOUENV)
 (WINE :NAME "Arknights" :EXEC
  "/home/rush/.wine/drive_c/YostarGames/Arknights_EN_Gamelauncher/Arknights_EN_Gamelauncher.exe")
 (WINE :NAME "Happy Wheels" :EXEC
  "/home/rush/Downloads/happy/Happy Wheels.exe")
 (VITA3K :NAME "PSO Nova" :EXEC "PCSG00351" :TAGS (:GAME :LOL))
 (WINE :NAME "Ragnarok Online" :EXEC
  "/home/rush/.wine/drive_c/users/rush/AppData/Local/Programs/UaRO World of Your Dream/UaRo Patcher.exe"
  :PROFILE (("DXVK_ASYNC" "1") ("WINE_LARGE_ADDRESS_AWARE" "0")))
 (STEAM :NAME "Elin JRPG" :EXEC "steam://rungameid/2135150")
 (STEAM :NAME "Brawlhalla" :EXEC "steam://rungameid/291550" :TAGS ("NICE"))
 (STEAM :NAME "Terraria" :EXEC "steam://rungameid/105600")
 (STEAM :NAME "Peggle Deluxe" :EXEC "steam://rungameid/3480")
 (STEAM :NAME "The Legend of Heroes: Trails in the Sky" :EXEC
  "steam://rungameid/251150")
 (STEAM :NAME "RPG Maker MV" :EXEC "steam://rungameid/363890")
 (STEAM :NAME "Hacknet" :EXEC "steam://rungameid/365450")
 (STEAM :NAME "Helen's Mysterious Castle" :EXEC "steam://rungameid/418190")
 (STEAM :NAME "hackmud" :EXEC "steam://rungameid/469920")
 (STEAM :NAME "Muck" :EXEC "steam://rungameid/1625450")
 (STEAM :NAME "Persona 3 Reload" :EXEC "steam://rungameid/2161700")
 (STEAM :NAME "Deus Ex: Game of the Year Edition" :EXEC
  "steam://rungameid/6910")
 (STEAM :NAME "RPG Maker VX Ace" :EXEC "steam://rungameid/220700")
 (STEAM :NAME "SIC-1" :EXEC "steam://rungameid/2124440")
 (WINE :NAME "eraToho The World" :EXEC
  "/home/rush/Games/eratoho-the-world/drive_c/Games/eraTW/Emuera.exe" :PROFILE
  (("WINEPREFIX" "/home/rush/Games/eratoho-the-world")) :LUTRIS-ID 3)
 (WINE :NAME "ragnarok local" :EXEC
  "/home/rush/Downloads/Ragnarok.server/3_Client/Ragnarok.exe" :PROFILE
  (("DXVK_ASYNC" "1") ("WINEPREFIX" "/home/rush/.wine")) :LUTRIS-ID 4)
 (STEAM :NAME "FINAL FANTASY VIII" :EXEC "steam://rungameid/39150")
 (STEAM :NAME "Punishing: Gray Raven" :EXEC "steam://rungameid/4125930")
 (STEAM :NAME "Runeline Playtest" :EXEC "steam://rungameid/4430000")
 (STEAM :NAME "EVE Online" :EXEC "steam://rungameid/8500")
 (STEAM :NAME "The Elder Scrolls V: Skyrim Special Edition" :EXEC
  "steam://rungameid/489830")
 (STEAM :NAME "Core Keeper" :EXEC "steam://rungameid/1621690")
 (EXEC :NAME "Minecraft Launcher" :EXEC "minecraft")
 (EXEC :NAME "OSU!" :EXEC "/home/rush/Documents/my-appimages/osu/osu")
 (EXEC :NAME "Monster Hunter Frontier Z" :EXEC
  "/home/rush/Downloads/MHFCT4.1/mhf-cli" :PHASES
  ((REPLACE PRE
            (RUN-COMMAND CTX
                         (SPLIT-SHELL-ARGS
                          "pg_ctl -D /home/rush/.local/share/postgresql/18 -l /home/rush/.local/share/postgresql/18/server.log start")))
   (ADD-BEFORE EXEC SERVER
    (RUN-COMMAND-ASYNC CTX '("/home/rush/Downloads/erupe-Linux-amd64/erupe-ce")
                       :WAIT NIL :DIRECTORY
                       "/home/rush/Downloads/erupe-Linux-amd64/"))
   (ADD-AFTER SERVER DELAY (SLEEP 10))
   (REPLACE POST
            (RUN-COMMAND CTX
                         (SPLIT-SHELL-ARGS
                          "pg_ctl -D /home/rush/.local/share/postgresql/18 -l /home/rush/.local/share/postgresql/18/server.log stop"))))
  :PROFILE MHFZ :ARGS
  "-u MMOFAN --char-id 5 --game-dir /home/rush/Downloads/MHFCT4.1/")
 (EXEC :NAME "Cataclysm Bright Nights" :EXEC
  "/home/rush/Games/cataclysmbn-v0.12.0/cataclysm-launcher")
 (EXEC :NAME "XCHESS" :EXEC "/home/rush/Downloads/xboard-4.9.1/xboard" :ARGS
  "-debug -pieceImageDirectory /home/rush/Downloads/xboard-4.9.1/svg")
 (STEAM :NAME "Peggle Extreme" :EXEC "steam://rungameid/3483")
 (STEAM :NAME "Evening Starter" :EXEC "steam://rungameid/1342100")
 (STEAM :NAME "Epic Seven" :EXEC "steam://rungameid/5019180")
 (STEAM :NAME "Killing Floor" :EXEC "steam://rungameid/1250")
 (STEAM :NAME "Yunyun Syndrome!? Rhythm Psychosis" :EXEC
  "steam://rungameid/2914150")
 (STEAM :NAME "Crystar" :EXEC "steam://rungameid/981750"))
