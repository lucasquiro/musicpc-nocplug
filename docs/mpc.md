mpc help
Usage: mpc [options] <command> [--] [<arguments>]
mpc version: 0.35

Options:
  -v, --verbose                  Give verbose output
  -q, --quiet                    Suppress status message
  --no-status                    synonym for --quiet
  -h, --host=<host>              Connect to server on <host>
  -P, --password=<password>      Connect to server using password <password>
  -p, --port=<port>              Connect to server port <port>
  -f, --format=<format>          Print status with format <format>
  -w, --wait                     Wait for operation to finish (e.g. database update)
  -r, --range=[<start>]:[<end>]  Operate on a range (e.g. when loading a playlist)
  -a, --partition=<name>         Operate on partition <name> instead
  --with-prio                    Show only songs that have a non-zero priority

Commands:
  mpc                                                   Display status
  mpc add <uri>                                         Add a song to the queue
  mpc addplaylist <file> <uri> ...                      Add a song to the playlist
  mpc albumart <uri>                                    Download album art for the given song and write to stdout.
  mpc cdprev                                            Compact disk player-like previous command
  mpc channels                                          List the channels that other clients have subscribed to.
  mpc clear                                             Clear the queue
  mpc clearerror                                        Clear the current error
  mpc clearplaylist <file>                              Clear the playlist
  mpc consume <on|off>                                  Toggle consume mode, or specify state
  mpc crop                                              Remove all but the currently playing song
  mpc crossfade [<seconds>]                             Set and display crossfade settings
  mpc current                                           Show the currently playing song
  mpc del <position>                                    Remove a song from the queue
  mpc delpart <name> ...                                Delete partition(s)
  mpc delplaylist <file> <position> ...                 Remove a song from the playlist
  mpc disable [only] <output # or name> [...]           Disable output(s)
  mpc enable [only] <output # or name> [...]            Enable output(s)
  mpc find <type> <query>                               Find a song (exact match)
  mpc findadd <type> <query>                            Find songs and add them to the queue
  mpc idle [events]                                     Idle until an event occurs
  mpc idleloop [events]                                 Continuously idle until an event occurs
  mpc insert <uri>                                      Insert a song to the queue after the current track
  mpc list <type> [<type> <query>]                      Show all tags of <type>
  mpc listall [<file>]                                  List all songs in the music dir
  mpc listneighbors                                     List neighbors.
  mpc load <file>                                       Load <file> into the queue
  mpc ls [<directory>]                                  List the contents of <directory>
  mpc lsplaylists                                       List currently available playlists
  mpc lsdirs [<directory>]                              List subdirectories of <directory>
  mpc makepart <name> ...                               Create partition(s)
  mpc mixrampdb [<dB>]                                  Set and display mixrampdb settings
  mpc mixrampdelay [<seconds>]                          Set and display mixrampdelay settings
  mpc mount [<mount-path> <storage-uri>]                List mounts or add a new mount.
  mpc move <from> <to>                                  Move song in queue
  mpc moveoutput <output # or name>                     Move output to partition (see -a)
  mpc moveplaylist <file> <from> <to>                   Move song in playlist
  mpc next                                              Play the next song in the queue
  mpc outputs                                           Show the current outputs
  mpc outputset <output # or name> <name>=<value>       Set output attributes
  mpc partitions                                        List partitions
  mpc pause                                             Pauses the currently playing song
  mpc pause-if-playing                                  Pauses the currently playing song; exits with failure if not playing
  mpc play [<position>]                                 Start playing at <position>
  mpc playlist [<playlist>]                             Print <playlist>
  mpc prev                                              Play the previous song in the queue
  mpc prio <prio> <position/range> ...                  Change song priorities in the queue
  mpc queued                                            Show the next queued song
  mpc random <on|off>                                   Toggle random mode, or specify state
  mpc readpicture <uri>                                 Download a picture from the given song and write to stdout.
  mpc renplaylist <file> <newfile>                      Rename a playlist
  mpc repeat <on|off>                                   Toggle repeat mode, or specify state
  mpc replaygain [off|track|album]                      Set or display the replay gain mode
  mpc rescan [<path>]                                   Rescan music directory (including unchanged files)
  mpc rm <file>                                         Remove a playlist
  mpc save <file>                                       Save a queue as <file>
  mpc search <type> <query>                             Search for a song
  mpc searchadd <type> <query>                          Search songs and add them to the queue
  mpc searchplay <pattern>                              Find and play a song in the queue
  mpc seek [+-][HH:MM:SS]|<0-100>%                      Seeks to the specified position
  mpc seekthrough [+-][HH:MM:SS]                        Seeks by an amount of time within the song and playlist
  mpc sendmessage <channel> <message>                   Send a message to the specified channel.
  mpc shuffle                                           Shuffle the queue
  mpc single <on|once|off>                              Toggle single mode, or specify state
  mpc stats                                             Display statistics about MPD
  mpc sticker <uri> <get|set|list|delete|find> [args..] Sticker management
  mpc stop                                              Stop playback
  mpc subscribe <channel>                               Subscribe to the specified channel and continuously receive messages.
  mpc toggle                                            Toggles Play/Pause, plays if stopped
  mpc toggleoutput <output # or name> [...]             Toggle output(s)
  mpc unmount <mount-path>                              Remove a mount.
  mpc update [<path>]                                   Scan music directory for updates
  mpc version                                           Report version of MPD
  mpc volume [+-]<num>                                  Set volume to <num> or adjusts by [+-]<num>
  mpc waitmessage <channel>                             Wait for at least one message on the specified channel.

See man 1 mpc for more information about mpc commands and options