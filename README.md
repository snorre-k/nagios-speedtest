# Nagios Speedtest plugin

Used to check available bandwidth from a Nagios server. 

Full details here: http://www.jonwitts.co.uk/archives/315

## Changelog
- 2020-01-17 Christian Wirtz:
  - Now with checkmk support as Local Check or Local Check via Piggyback.
  - A mkp for usage with metric file is also available.
- 2020-10-17 Snorre:
  - Automatic server selection
  - Fallback, if given server is not reachable
  - Errors on stderr
  - ```nagios-speedtest-1.5.mkp``` Check MK plugin
  - ```speedtest.py``` for Check MK graping
- 2020-12-12 Snorre:
  - new script: check_speedtest.sh - uses official Ookla speedtest
  
## Usage with Check MK
You can deploy the Plugin and the graphing template with
```
mkp install nagios-speedtest-1.5.mkp
```

If you do not want to use ```mkp```, you can copy the files:
```
cp check_speedtest-cli.sh <site>/local/lib/nagios/plugins/check_speedtest-cli.sh
cp check_speedtest.sh <site>/local/lib/nagios/plugins/check_speedtest.sh
cp speedtest.py <site>/local/share/check_mk/web/plugins/metrics/speedtest.py
```
You can create an active check rule, or integrate the check into the agent.
