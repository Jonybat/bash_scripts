## My bash scripts

These are just some bash scripts that i wrote. Some are quite old, and most have been adapted and refactored along the time and my experience with bash.

---

### `shlog.sh`

Script to be sourced from other scripts. Provides `shlog` function, for logging funcionality with some options:

* __log directory__ (set by default in the script by the `globalLogDir`), can be overriden by:
  * global variable `LOGDIR`
  * argument `-p /alternative/path/`
* __log filename__ (set by default to `script_name.log`), can be overriden by:
  * global variable `LOGFILE`
  * argument `-p alternative.log`
* __log path__ (set by default as a combination of the above 2), can be overriden by:
  * global variable `LOGPATH`
  * argument `-p /alternative/path/alternative.log`
* __disable logging__ to file on a per case basis (only prints to STDOUT), with `-p nolog`
* __time stamps__:
  * argument `-s timestamp` = `HH:MM:SS - message`
  * argument `-s datestamp` = `YYYY:MM:DD HH:MM:SS - message`
  * argument `-s weekstamp` = `HH:MM:SS YYYY:MM:DD ShortWeekday Weeknumber - message`

#### Usage: `shlog [-p|--path=nolog|/alternative/path/alternative.log] [-s|--stamp=timestamp|datestamp|weekstamp] \"text\"|\"\$(cmd)\"`

---

### `shmount.sh`

Script to be sourced from other scripts. Provides `mount_mounts` and `umount_mounts` functions. Expanded array should be provided as single argument, where each line is a CSV format as: `<UUID>,</mount/dir>,<fstype (defaults to auto)>,<mount opts (defaults to defaults)>`

#### Usage: `mount_mounts "${mounts_array[@]}"`

---

### `shrans.sh`

Script to be sourced from other scripts. Provides `shrans_init` and `shrans_check` functions. Directory provided as single argument, use init to create the honey files and check to check them.

#### Usage: `shrans_check /mnt/files`

---

### `shuser.sh`

Script to be sourced from other scripts. Simple script to make sure script runs as specified user.

#### Usage: `. shuser.sh "user"`

---

### `shlock.sh`

Script to be sourced from other scripts. Provides run lock funcionality to scripts with PID tracking. Includes `remove_lock` function to remove lock file.

#### Usage: `. shlock.sh`

---

### `pushbullet.sh`

Script to be sourced from other scripts. Provides `pushb` function, for easy interface with pushbullet, with invoker script detection. Designed to use [pushbullet-bash](https://github.com/Jonybat/pushbullet-bash)

#### Usage: `pushb "message"`

---

### `backup.sh`

Backup script with multiple options:

* Individual and recursive file and folder backup
* Backup folder compression
* Backup cloning to extra directory
* File and folder exclusions
* FTP contents dump
* Selective or full MySQL databases dump
* Filesystem cloning
* Pre backup scripts support
* Status and settings command line options
* Colored and optional plain text log

See [backup_config.sample](backup_config.sample) for all the options.

#### Usage: `backup.sh [start|status|settings] [config_file]`

---

### `clonedir_installer.sh`

Script to install GRUB and fix fstab in a filesystem clone.

#### Usage: `clonedir_installer.sh /mnt/fsclone/`

---

### `connection_status.sh`

Script to check network, dns and internet connectivity, and notify or trigger scripts accordingly.

---

### `dynamic_dns_updater.sh`

Script to check and update dynamic dns to namecheap. Requires some global variables:

#### `.secrets` example:
```
NAMECHEAP_DOMAIN="domain.com"
NAMECHEAP_HOST="@"
NAMECHEAP_PASSWORD="password"
```

---

### `anime_renamer.sh`

Script to rename anime files based on their AniDB name, using [anidbcli](https://github.com/Jonybat/anidbcli). The input files are parsed from the line break separated list in the `animeListFile` variable. Requires AniDB API settings as global variables:

#### `.secrets` example:
```
ANIDB_USER="username"
ANIDB_PASS="password"
ANIDB_APIKEY="apikey"
```

---

### `git_create_repo.sh`

Simple script to create bare git repositories for git-http-backend.

#### Usage: `git_create_repo.sh "repo_name"`

---

### `rm_replacement.sh`

Simple script to act as a replacement for `rm` command, to add trash funcionality. Add `alias rm="/path/to/script/rm_replacement.sh"` to `~/.bashrc` or alike.

---

### `snort_rules_updater.sh`

Simple script to update snort rules with the latest community rules available online. Requires Snort Oinkcode to be set as global variable:

#### `.secrets` example:
```
SNORT_OINKCODE="oinkcode"
```

---

### `zabbix_sender.sh`

[Zabbix sender](https://www.zabbix.com/documentation/4.0/manual/concepts/sender) implementation in b(a)sh. It was built to be as portable as possbile, mainly to be able to run it on limited shells, like BusyBox. Provides extra arguments:

* `-p "port"` instead of `-z server:port`
* `-i "input-file"` for batch sending of multiple values

#### Usage:
```
  zabbix_sender.sh -z "server" [-p "port"] -s "host" -k "key" -o "value"
  zabbix_sender.sh -z "server" [-p "port"] -i "input-file""
```

---

### `ups_msg.sh`

Simple script to act as a NOTIFYCMD script for NUT's upsmon.

#### Suggested config options for `/etc/nut/upsmon.conf`:
```
NOTIFYCMD "/path/to/ups_msg.sh"

NOTIFYMSG ONLINE        "UPS %s - on line power"
NOTIFYMSG ONBATT        "UPS %s - on battery"
NOTIFYMSG LOWBATT       "UPS %s - battery is low"
NOTIFYMSG FSD           "UPS %s - forced shutdown"
NOTIFYMSG COMMOK        "UPS %s - communications established"
NOTIFYMSG COMMBAD       "UPS %s - communications lost"
NOTIFYMSG SHUTDOWN      "UPS %s - automatic system shutdown"
NOTIFYMSG REPLBATT      "UPS %s - battery needs to be replaced"
NOTIFYMSG NOCOMM        "UPS %s - unavailable"
NOTIFYMSG NOPARENT      "upsmon parent process died - shutdown impossible"

NOTIFYFLAG ONLINE       SYSLOG+EXEC+WALL
NOTIFYFLAG ONBATT       SYSLOG+EXEC+WALL
NOTIFYFLAG LOWBATT      SYSLOG+EXEC+WALL
NOTIFYFLAG FSD          SYSLOG+EXEC+WALL
NOTIFYFLAG COMMOK       SYSLOG+EXEC
NOTIFYFLAG COMMBAD      SYSLOG+EXEC
NOTIFYFLAG SHUTDOWN     SYSLOG+EXEC+WALL
NOTIFYFLAG REPLBATT     SYSLOG+EXEC
NOTIFYFLAG NOCOMM       SYSLOG+EXEC
NOTIFYFLAG NOPARENT     SYSLOG+EXEC
```

---

### `scan_watchdog.sh`

Daemon script to add network scan funcionality to a usb flatbed scanner, over samba shares. It looks for a trigger file, located in a samba shared ramdisk (to avoid constant disk reads), and triggers the scan according to the text inside the trigger file. Currently the options are: `color`, `color-hq`, `grayscale`, `grayscale-hq` and `lineart`. Requires ramdisk directory, scan destination directory and scanner USB ID to be set as global variables:

#### `.secrets` example:
```
SCAN_DEVID="1234:5678"
SCAN_DESTINATION="/mnt/scans/"
SCAN_RAMDISK="/mnt/ramdisk" # No trailing slash
```
