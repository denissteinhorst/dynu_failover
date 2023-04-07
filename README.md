# Dynu_Failover


## IMPORTANT
In favor of a more flexible and easier to use solution provided by Cloudflare, this project is no longer maintained.
You can still download the script, but it will probably not be updated anymore...
<h1></h1>


**A simple bash script to provide failover functionality to your dynu.com dynamic-dns based on dns probes to your FritzBoxes via MyFritz.**

## Story time

In my scenario, I have a domain which I want to use for my Home lab.
This domain is registered somewhere, and it's using the nameservers from Dynu.com therefore I use Dynu's API to tell where to point at.
At home, I have two internet connections, each of them heading into a dedicated Fritz Box which is playing the "exposed host" to a pfSense.
Therefore, I want my self-hosted services to be reachable all the time, even when one of the connection fails. (aka failover)

This is where this script comes in. It will ping your MyFritz-Addresses from outside your network and update your Dynu Hostname to the IP address of the FritzBox that is reachable. (Primary -> Secondary -> Error)

What's left to do is to set up your pfSense (or similar device) to open ports for both "WAN IPs" and you are good to go.

## Features

- Easy to use, there is a configuration file where you can set everything up.
- Updates your dynu host automatically based on the status of your FritzBoxes.
- The script will log everything to a logfile (if you want to)
- In Addition to that, the script will only send a maximum of 3 E-Mails if the connection is down. (if you want to)
- A Cooldown is used to prevent the script from spamming the Dynu API if the connection is down for a longer period of time.
- As well as the script will only attempt to call dynu if the IP has actually changed (i.e. primary connection is down).

## Requirements

- Atleast 2 FritzBoxes (with FritzOS 7.x or higher)
- Each FritzBox must have a MyFritz-Address (see FAQ for "how to setup")
- A Dynu.com Account with a ready to use Hostname (or subdomain)
- Some kind of external Linux Server (vserver, root-server etc)
- 5 Minutes of your life to set it up :)

## Configuration (dynu_failover.conf)

<!-- insert markdown table -->
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `PRIMARY_FRIENDLY_NAME` | Friendly Name for your primary connection | `FritzBox 7590 VDSL` |
| `PRIMARY_FRITZDNS` | Your primary MyFritz-Address | `whatever.myfritz.net` |
| `SECONDARY_FRIENDLY_NAME` | Friendly Name for your secondary connection | `FritzBox 6660 CABLE` |
| `SECONDARY_FRITZDNS` | Your secondary MyFritz-Address | `whatsoever.myfritz.net` |
| `DYNU_USERNAME` | Your Dynu.com Username | `username` |
| `DYNU_PASSWORD` | Your Dynu.com Password (SHA-256) | `password` |
| `DYNU_HOSTNAME` | Your Dynu.com Hostname | `yourdomain.tld` |
| `DYNU_URL` | The Base Update-URL from Dynu | `api.dyndns.org/nic/update` |
| `ERROR_MAIL` | Your E-Mail for outages (empty string if you dont want receive any mails) | `your.mail@address.tld` |
| `LOGPATH` | "dynu_failover.log" (default, empty string if you dont want any logs) | `dynu_failover.log` |
| `MAX_RETRIES` | How often should the script run into void until it waits longer | `3` |
| `RETRY_COOLDOWN` | How long should the script wait until it resets the retries (in seconds / default 5min.) | `300` |

## Usage (happy path)

Login to your Linux Machine via SSH as the user you want to run the script as...

CD into the directory where you want to store the script:
`cd /path/to/dynu_failover`

Download the Script from Github:
`git clone https://github.com/denissteinhorst/dynu_failover.git`

Allow the Script to be run:
`cd dynu_failover/`
`chmod +x dynu_failover.sh`

Edit the Configuration:
`nano dynu_failover.conf`

Run the Script once to test it:
`./dynu_failover.sh -v`

check the log file for any errors (If dynu already knows your IP, you will see a "nochg" in the log file):
`tail dynu_failover.log`

Open your crontabs:
`crontab -e`

Add the following line to your crontab:
` * * * * * cd ./path/to/dynu_failover/ && ./dynu_failover.sh -q `

## Usage (advanced)

- optional: Run the script in "quiet mode" (no output to stdout) by using the `-q` or `--quiet` flag.
- optional: Run the script in "verbose mode" (verbose output to stdout) by using the `-v` or `--verbose` flag.
- optional: Run the script in "dry mode" (no changes to files- or dynu) by using the `-d` or `--dry`flag.
- optional: Run the script in "force mode" (forcing to update even if ip is unchanged) by using the `-f` or `--force`flag.

## FAQ

### How to setup MyFritz-Address

> [https://avm.de/service/myfritz/faqs/myfritz-konto-erstellen-und-in-fritzbox-einrichten/](https://avm.de/service/myfritz/faqs/myfritz-konto-erstellen-und-in-fritzbox-einrichten/)

### How to get the SHA-256 Hash of your Dynu.com Password

Windows:
> certutil -hashfile yourpassword.txt SHA256

MacOS:
> shasum -a 256 yourpassword.txt | awk '{print $1}'

### Can I use this script with other DynDNS Providers?

> Probably yes, you can use this script with any Provider that offers updates via cURL. Just change the DYNU_URL in the configuration file. (*You may have to change the parameters in the .sh as well!*)

### Can I use my own Domain as well?

> Yes, you can use this script with any Domain. Just change the DYNU_HOSTNAME in the configuration file and setup your Domain in the Dynu Control Panel. (dont forget to set the nameservers to the ones Dynu provides you with ;))

### How do I know if the script is working?

> Open [https://www.dynu.com/en-US/ControlPanel/DDNS](https://www.dynu.com/en-US/ControlPanel/DDNS) you should see your primary IP in the "IPv4" column.
Next alter the configuration file by changing the primary fritzdns and wait a Minute. You should see your fallback IP not only in the .log file but also in the "IPv4" column on the Dynu Control Panel.

## Files

    dynu_failover/
        dynu_failover.sh
        dynu_failover.conf
        dynu_failover.log (created on initial run)
        dynu_failover.state (created on initial run)

## License

**WTFPL** - Do What The 😘 You Want To Public License [(see LICENSE)](http://www.wtfpl.net/)
