#! /bin/bash 
#
# Script to check Internet connection speed using original Speedtest by Ookla
#
# Jon Witts / Christian Wirtz / Snorre
#
#########################################################################################################################################################
#
# Nagios Exit Codes
#
# 0 =   OK      = The plugin was able to check the service and it appeared to be functioning properly
# 1 =   Warning     = The plugin was able to check the service, but it appeared to be above some warning
#               threshold or did not appear to be working properly
# 2 =   Critical    = The plugin detected that either the service was not running or it was above some critical threshold
# 3 =   Unknown     = Invalid command line arguments were supplied to the plugin or low-level failures internal
#               to the plugin (such as unable to fork, or open a tcp socket) that prevent it from performing the specified operation.
#               Higher-level errors (such as name resolution errors, socket timeouts, etc) are outside of the control of plugins
#               and should generally NOT be reported as UNKNOWN states.
#
########################################################################################################################################################

plugin_name="Nagios speedtest plugin"
version="1.0 20201017"

########################################################################################################################################################
#
#   CHANGELOG
#
#   Version 1.0 - Initial Release
#               - installation of Speedtest by Ookla see: https://www.speedtest.net/apps/cli
#                   export INSTALL_KEY=379CE192D401AB61
#                   sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
#                   echo "deb https://ookla.bintray.com/debian generic main" | sudo tee  /etc/apt/sources.list.d/speedtest.list
#                   sudo apt-get update
#                   sudo apt-get remove speedtest-cli   # if speedtest-cli is installed
#                   sudo apt-get install speedtest
#                - WARNING License: run "speedtest" as monitoring user once to accept license!
#
########################################################################################################################################################

# function to output script usage
usage() {
    cat << EOF

$plugin_name - Version: $version

OPTIONS:
  -h  Show this message
  -w  *Required* - Download Warning Level - integer or floating point
  -c  *Required* - Download Critical Level - integer or floating point
  -W  *Required* - Upload Warning Level - integer or floating point
  -C  *Required* - Upload Critical Level - integer or floating point
  -s  optional Server integer
        run "speedtest --servers" to find your nearest server
  -p  Output Performance Data
  -m  Download Maximum Level - *Required* if you request perfdata or local output
        Integer or floating point in Mbit/s
  -M  Upload Maximum Level - *Required* if you request perfdata  or local output
        Integer or floating point in Mbit/s
  -v  Output plugin version
  -V  Output debug info for testing
  -S  Path to speedtest binary - defaults to $STb
  -T  Output type {local,nagios} - defaults to $checktype
        local = checkmk local check style
  -O  checkmk: Piggyback destination host {HOSTNAME} - prints an optional piggyback section
  -R  checkmk: Script returncode {0,1,2,3} - override skript returncode (f.e. for checkmk mk-job usage)
  -N  checkmk: service name {without spaces!}
EOF
}


#####################################################################
# function to check if a variable is numeric
# expects variable to check as first argument
# and human description of variable as second
isnumeric() {
  re='^[0-9]+([.][0-9]+)?$'
  if ! [[ $1 =~ $re ]]; then
    echo $2" with a value of: "$1" is not a number!" >&2
    usage >&2
    exit 3
  fi
}

#####################################################################
# functions for floating point operations - requires bc!

#####################################################################
# Default scale used by float functions.
float_scale=3

#####################################################################
# Evaluate a floating point number expression.
function float_eval() {
  local stat=0
  local result=0.0
  if [[ $# -gt 0 ]]; then
    result=$(echo "scale=$float_scale; $*" | bc -q 2>/dev/null)
    stat=$?
    if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
  fi
  echo $result
  return $stat
}

#####################################################################
# Evaluate a floating point number conditional expression.
function float_cond() {
  local cond=0
  if [[ $# -gt 0 ]]; then
    cond=$(echo "$*" | bc -q 2>/dev/null)
    if [[ -z "$cond" ]]; then cond=0; fi
    if [[ "$cond" != 0  &&  "$cond" != 1 ]]; then cond=0; fi
  fi
  local stat=$((cond == 0))
  return $stat
}



## Set up the variables to take the arguments - specify defaults
STb="/usr/bin"
checktype="nagios"
DLw=
DLc=
ULw=
ULc=
SEs=
PerfData=
MaxDL=
MaxUL=
debug=
piggyhost=
rc=
servicename=



## Retrieve the arguments using getopts - check options
while getopts "hw:c:W:C:s:pm:M:vVT:O:R:S:N:" OPTION
do
  case $OPTION in
    h) usage; exit 3 ;;
    w) DLw=$OPTARG ;;
    c) DLc=$OPTARG ;;
    W) ULw=$OPTARG ;;
    C) ULc=$OPTARG ;;
    s) SEs=$OPTARG ;;
    p) PerfData="TRUE" ;;
    m) MaxDL=$OPTARG ;;
    M) MaxUL=$OPTARG ;;
    v) echo "$plugin_name. Version number: $version"; exit 3 ;;
    V) debug="TRUE" ;;
    T) checktype=$OPTARG ;;
    O) piggyhost=$OPTARG ;;
    R) rc=$OPTARG ;;
    N) servicename=$OPTARG ;;
    S) STb=$OPTARG ;;
  esac
done

# Check Speedtest binary
if ! [ -x $STb/speedtest ]; then
  echo "Speedtest binary $STb/speedtest not found" >&2
  usage >&2
  exit 3
fi

# Check for empty arguments and exit to usage if found
if  [[ -z $DLw ]] || [[ -z $DLc ]] || [[ -z $ULw ]] || [[ -z $ULc ]]; then
  echo "Missing arguments" >&2
  usage >&2
  exit 3
fi

# Check for empty upload and download maximum arguments if perfdata has been requested
if [[ "$PerfData" == "TRUE" ]] || [[ "$checktype" == "local" ]]; then
  if [[ -z $MaxDL ]] || [[ -z $MaxUL ]]; then
    echo "Missing arguments: -m <MaxDL> -M <MaxUL>" >&2
    usage >&2
    exit 3
  fi
fi

# Check for non-numeric arguments
isnumeric $DLw "Download Warning Level"
isnumeric $DLc "Download Critical Level"
isnumeric $ULw "Upload Warning Level"
isnumeric $ULc "Upload Critical Level"
# Only check upload and download maximums if perfdata requested
if [ "$PerfData" == "TRUE" ]; then
  isnumeric $MaxDL "Download Maximum Level"
  isnumeric $MaxUL "Upload Maximum Level"
fi

# Check if binary bc is installed
type bc >/dev/null 2>&1 || { echo >&2 "Please install bc binary (in order to do floating point operations)"; exit 3; }

# Check that warning levels are not less than critical levels
if float_cond "$DLw < $DLc"; then
  echo "\$DLw is less than \$DLc!" >&2
  usage >&2
  exit 3
elif float_cond "$ULw < $ULc"; then
  echo "\$ULw is less than \$ULc!" >&2
  usage >&2
  exit 3
fi

# Output arguments for debug
if [ "$debug" == "TRUE" ]; then
  echo "Download Warning Level = "$DLw
  echo "Download Critical Level = "$DLc
  echo "Upload Warning Level = "$ULw
  echo "Upload Critical Level = "$ULc
  echo "Server Integer = "$SEs
fi



##Set command up depending upon internal or external
# External
if [ "$SEs" ]; then
  command="$STb/speedtest --server-id=$SEs"
  if [ "$debug" == "TRUE" ]; then
    echo "External Server defined: $SEs"
  fi
else
# Automatic - Choose nearest server
  command="$STb/speedtest"
  if [ "$debug" == "TRUE" ]; then
    echo "Automatic Server defined!"
  fi
fi
command="$command --progress=no"
# Debug: Output Command
if [ "$debug" == "TRUE" ]; then
  echo "Speedtest: $command"
fi



## Excecute Speedtest
# Get the output of the speedtest into a variable
# so we can begin to process it
out=$($command)
# on Error
if [ $? -ne 0 ]; then
  echo "Error on running speedtest command" >&2
  exit 3
fi
# remove CR ("\r", 0x0d)
out=$(echo "$out" | sed 's/\r//')

# echo contents of speedtest for debug
if [ "$debug" == "TRUE" ]; then
  echo "$out"
fi



## Output Processing
ping=$(echo "$out" | grep "Latency:" | awk '{print $2}')
pingUOM=$(echo "$out" | grep "Latency:" | awk '{print $3}')
download=$(echo "$out" | grep "Download:" | awk '{print $2}')
downloadUOM=$(echo "$out" | grep "Download:" | awk '{print $3}')
upload=$(echo "$out" | grep "Upload:" | awk '{print $2}')
uploadUOM=$(echo "$out" | grep "Upload:" | awk '{print $3}')

# echo values for debug
if [ "$debug" == "TRUE" ]; then
  echo "Ping = "$ping
  echo "Download = "$download
  echo "Upload = "$upload
fi

#set up our nagios status and exit code variables
status=
nagcode=

# now we check to see if returned values are within defined ranges
# we will make use of bc for our math!
if float_cond "$download < $DLc"; then
  if [ "$debug" == "TRUE" ]; then
    echo "Download less than critical limit. \$download = $download and \$DLc = $DLc "
  fi
  status="CRITICAL"
  nagcode=2
elif float_cond "$upload < $ULc"; then
  if [ "$debug" == "TRUE" ]; then
    echo "Upload less than critical limit. \$upload = $upload and \$ULc = $ULc"
  fi
  status="CRITICAL"
  nagcode=2
elif float_cond "$download < $DLw"; then
  if [ "$debug" == "TRUE" ]; then
    echo "Download less than warning limit. \$download = $download and \$DLw = $DLw"
  fi
  status="WARNING"
  nagcode=1
elif float_cond "$upload < $ULw"; then
  if [ "$debug" == "TRUE" ]; then
    echo "Upload less than warning limit. \$upload = $upload and \$ULw = $ULw"
  fi
  status="WARNING"
  nagcode=1
else
  if [ "$debug" == "TRUE" ]; then
    echo "Everything within bounds!"
  fi
  status="OK"
  nagcode=0
fi

# Example output nagios
# OK - Ping = 8.841 ms Download = 87.59 Mbit/s Upload = 31.20 Mbit/s|'download'=87.59;80;55;0;105.00 'upload'=31.20;30;20;0;42.00
nagout="$status - Ping = $ping $pingUOM Download = $download $downloadUOM Upload = $upload $uploadUOM"

# Nagios: append perfout if argument was passed to script
if [ "$PerfData" == "TRUE" ]; then
  if [ "$debug" == "TRUE" ]; then
    echo "PerfData requested!"
  fi
  perfout_nag="|'download'=$download;$DLw;$DLc;0;$(echo $MaxDL*1.05|bc) 'upload'=$upload;$ULw;$ULc;0;$(echo $MaxUL*1.05|bc)"
  perfout="|'download'=$download;$DLw;$DLc;0;$(echo $MaxDL*1.05|bc) 'upload'=$upload;$ULw;$ULc;0;$(echo $MaxUL*1.05|bc)"
  nagout=$nagout$perfout_nag
fi

# Checkmk:
if [ "$checktype" = "local" ]; then
  NOW=`date`
  cmkout="$nagcode $servicename 'download'=$download;$DLw;$DLc;0;$(echo $MaxDL*1.05|bc)|'upload'=$upload;$ULw;$ULc;0;$(echo $MaxUL*1.05|bc) Ping = $ping $pingUOM Download = $download $downloadUOM Upload = $upload $uploadUOM $status (last run: $NOW)"
fi



## Output
if [[ "$checktype" == "nagios" ]]; then
  echo $nagout
  exit $nagcode
else
  if [[ "$piggyhost" != "" ]]; then
    echo -e "<<<<$piggyhost>>>>"
    echo -e "<<<local>>>"
  fi
  echo $cmkout
  if [[ "$piggyhost" != "" ]]; then
      echo -e "<<<>>>"
      echo -e "<<<<>>>>"
  fi
  if [[ "$rc" != "" ]]; then
    exit $rc
  else
    exit 0
  fi
fi
