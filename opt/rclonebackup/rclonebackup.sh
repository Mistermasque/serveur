#!/bin/bash


# config file
CONFIG_FILE=""
# Set Verbose mode or not
VERBOSE=false
# Set Log mode or not (adding date time before each message)
LOG=false
# Array that contains config names
declare -a CONFIGS

usage() {
   cat << MSG_USAGE
Script used to synchronise local directories with cloud remote repositories throw rclone.
Need stoml and rclone installed.
See: https://github.com/freshautomations/stoml https://rclone.org/install/

Usage  :
   $(basename $0) [Options]

Options :
   -h : Show this message
   -v : Activate verbosity
MSG_USAGE
}

msg() {
   local msg="$1"
   local type="$2"
   local stderr=false
   local prefix=''
   local now=''

   if [[ -z $type ]]; then
      type="default"
   fi

   if [[ $LOG = true ]]; then
      now="$(date "+%Y-%m-%d %H:%M:%S") "
   fi

   case "${type}" in
      'error')
         prefix="[ERROR] "
         stderr=true
      ;;
      'warning')
         prefix="[WARN] "
      ;;
      'verbose')
         if [[ $VERBOSE = false ]]; then
            return
         fi
      ;;
      'default')
      ;;
      *)
         echo "[ERROR] msg type '${type}' unknown" >&2
         exit 1
      ;;
   esac

   if [[ $stderr = true ]]; then
      printf '%s%s%s\n' "$now" "$prefix" "$msg"
   else
      printf '%s%s%s\n' "$now" "$prefix" "$msg"
   fi

}

checkDependencies() {
   if ! command -v "stoml" &> /dev/null
   then
      msg "Command stoml not found. Please install it before using this script.
See https://github.com/freshautomations/stoml for install instructions." 'error'
      exit 1
   fi

    if ! command -v "rclone" &> /dev/null
   then
      msg "Command rclone not found. Please install it before using this script.
See https://rclone.org/install/for install instructions." 'error'
      exit 1
   fi
}

function checkConfig() {
   local config_dir=$( dirname "$(readlink -f "$0")" )
   CONFIG_FILE="$config_dir/rclonebackup-config.toml"

   msg "Read config file '$CONFIG_FILE'..."

   if [[ ! -f $CONFIG_FILE ]]; then
      msg "Could not load settings from '$CONFIG_FILE' (file does not exist), please create config file." 'error'
      exit 1
   fi

   local remote_configs=$(stoml "$CONFIG_FILE" remote_configs)

   if [[ -z $remote_configs ]]; then
      msg "Variable 'remote_configs' empty or not defined in config file" 'error'
      exit 1
   fi

   local var_names=('name' 'local_path' 'remote_path' 'sync_younger_than')
   local optional_vars=('sync_younger_than')

   for conf_name in ${remote_configs[@]}
   do
      msg "Check '$conf_name' config [remotes.$conf_name] section from config file..." 'verbose'

      local config_section=$(stoml "$CONFIG_FILE" remotes.$conf_name)
      if [[ -z $config_section ]]; then
         msg "Section [remotes.$conf_name] empty or not defined in config file, ignoring" 'warning'
         continue
      fi

      declare -A conf

      for var_name in ${var_names[@]}
      do
         local value=$(stoml "$CONFIG_FILE" remotes.$conf_name.$var_name)
         if [[ -z $value ]]; then

            if [[ ${optional_vars[@]} =~ $var_name ]]; then
               value=''
            else
               msg "Variable '$var_name' empty or not defined in section [remotes.$conf_name] from config file" 'error'
               exit 1
            fi
         fi
        
         conf[$var_name]=$value
         msg "- $var_name = '${conf[$var_name]}'" 'verbose'
      done

      if [[ ! -f ${conf['local_path']} ]]; then
         msg "Local file or directory '${conf[local_path]}' defined in section [remotes.$conf_name] doesn't exists" 'error'
         exit 1
      fi

      if ! rclone config show "${conf['name']}" > /dev/null; then
         msg "Config '${conf[name]}' defined in section [remotes.$conf_name] is not configured in rclone" 'error'
         exit 1
      fi

      CONFIGS+=($conf_name)
   done
}

execute() {
   local conf_name="$1"
   local name=$(stoml "$CONFIG_FILE" remotes.$conf_name.name)
   local local_path=$(stoml "$CONFIG_FILE" remotes.$conf_name.local_path)
   local remote_path=$(stoml "$CONFIG_FILE" remotes.$conf_name.remote_path)
   local sync_younger_than=$(stoml "$CONFIG_FILE" remotes.$conf_name.sync_younger_than)

   msg "Execute sync for remote '$name'..."

   local cmd="rclone sync \"$local_path\" \"${name}:${remote_path}\""

   if [[ $VERBOSE = true ]]; then
      cmd="$cmd -v"
   fi

   if [[ -n $sync_younger_than ]]; then
      cmd="$cmd --max-age"
   fi
   
   msg "$cmd" 'verbose'
}

while getopts "hvl" option; do
   case "${option}" in
      v)
         VERBOSE=true
         ;;
      l)
         LOG=true
         ;;
      h)
         usage
         exit 0
      ;;
      *)
         usage
         exit 1
   esac
done

if [[ $LOG = true ]]; then
   echo "--------------------------"
   msg "$(basename $0) starting..."
fi

checkDependencies
checkConfig

for config in ${CONFIGS[@]}
do
   execute "$config"
done
