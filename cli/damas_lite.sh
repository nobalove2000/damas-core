#!/bin/bash
#
# Shell methods for DAMAS software (damas-software.org)
#
# This file is part of damas-core.
#
# damas-core is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# damas-core is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with damas-core.  If not, see <http://www.gnu.org/licenses/>.

# VARIABLES
USER=`whoami`
CURL_ARGS='-ks -w "\n%{http_code}" -H "Content-Type: application/json"'
BUFFER_SIZE=1000

# map errors sent by the server
map_server_errors() {
  case $1 in
    200) # OK
      exit 0
      ;;
    201) # OK (node(s) created)
      exit 0
      ;;
    000) # Server unreachable
      exit 3
      ;;
    207) # Multi-Status (some nodes do not exist)
      exit 7
      ;;
    400) # Bad request (not formatted correctly)
      exit 40
      ;;
    401) # Unauthorized
      exit 41
      ;;
    403) # Forbidden (the user does not have the right permission)
      exit 43
      ;;
    404) # Not found (all the nodes do not exist)
      exit 44
      ;;
    409) # Conflict (all nodes already exist with these identifiers)
      exit 49
      ;;
    500) # Internal server error
      exit 50
      ;;
    *)   # Unknown server error
      exit 60
      ;;
  esac
}

run() {
  if [ $VERBOSE ]; then
    echo "$1"
  fi
  RES=$(eval "$1")
  if [ ! $QUIET ]; then
    if [ $LINESOUT ]; then
      printf "$(echo "$RES" | sed '$d' | sed 's/.*\["\(.*\)"\].*/\1/g' | sed 's/\",\"/\n/g')\n"
    else
      echo $(echo "$RES" | sed '$d')
    fi
  fi
  map_server_errors "${RES##*$'\n'}"
}

load_token() {
  if [ $DAMAS_TOKEN ]; then
    local TOKEN=$DAMAS_TOKEN
  else
    local TOKEN=$(cat /tmp/damas-$USER 2> /dev/null)
  fi

  AUTH='-H "Authorization: Bearer '$TOKEN'"'
}

show_help_msg() {
  echo "usage: damas [--help] -s|--server <server_url> [-q|--quiet] [-v|--verbose] [-l|--lines] <command> [<args>]"
  echo ""
  echo "Authentication commands: "
  echo "   signin    <username> <pass>"
  echo "   signout   Remove authorization token"
  echo ""
  echo "CRUDS commands (send JSON to the server, see examples below):"
  echo "   create       <json>  create node(s)"
  echo "   read         <json>  show the keys of the file"
  echo "   update       <json>  update nodes"
  echo "   upsert       <json>  create or update nodes"
  echo "   delete       <json>  delete nodes"
  echo "   search       <query> search"
  echo ""
  echo "MORE commands"
  echo "   graph        <json>  read all related nodes"
  echo "   search       <string> search by query string"
  echo "   search_mongo <query> <sort> <limit> <skip> MongoDB search"
  echo ""
  echo "ENVIRONMENT VARIABLES"
  echo "  DAMAS_SERVER"
  echo "    URL of the server hosting damas-core. It can specify https:// or http:// protocols."
  echo "  DAMAS_TOKEN"
  echo "    Token used for authentication."
  echo ""
  echo "EXAMPLES"
  echo "    create an arbitrary node giving a JSON"
  echo "        damas -s yourserver create '{\"key\":\"value\",\"comment\":\"created with cli\"}'"
  echo "    list every nodes"
  echo "        damas -s yourserver search *"
  echo "    search keys matching a regular expression"
  echo "        damas -s yourserver search _id:/.*mov/"
  echo "    read nodes from a search result using a pipe"
  echo "        damas search * | damas read -"
  echo "    search deleted:true key, sort by _id key, show result as lines of ids"
  echo "        damas -s yourserver -l search_mongo '{\"deleted\":true}' '{\"_id\":1}' 0 0"
  echo ""
  echo "EXIT VALUES"
  echo "  0  Success"
  echo "  1  Syntax or usage error"
  echo "  2  Not a damas repository (or any parent)"
  echo "  3  Server is unreachable"
  echo "  7  (Server 207) Multi-Status (some nodes do not exist)"
  echo "  40 (Server 400) Bad request (not formatted correctly)"
  echo "  41 (Server 401) Unauthorized"
  echo "  43 (Server 403) Forbidden (the user does not have the right permission)"
  echo "  44 (Server 404) Not found (all the nodes do not exist)"
  echo "  49 (Server 409) Conflict (all nodes already exist with these identifiers)"
  echo "  50 (Server 500) Internal server error"
  echo "  60 (Server xxx) Unknown server error"
  exit 0
}

# loop through arguments
while true; do
  case "$1" in
    -h)
      echo "usage: damas [--help] <command> [<args>]"
      exit 0
      ;;
    --help)
      show_help_msg
      ;;
    -v | --verbose)
      VERBOSE=true
      CURL_VERBOSE="-v"
      shift 1
      ;;
    -q | --quiet)
      QUIET=true
      shift 1
      ;;
    -l | --lines)
      LINESOUT=true
      shift 1
      ;;
    -s | --server)
      DAMAS_SERVER=$2
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

COMMAND=$1
shift

if [ -z "$COMMAND" ]; then
  echo "damas: missing command"
  show_help_msg
  exit 1
fi

if [ ! -t 0 -a $# -eq 0 ]; then
  #run this script for input stream
  xargs -n $BUFFER_SIZE $0 $COMMAND
  exit $?
fi

load_token

if [ "$1" == "-" ]; then
  DATA=@/dev/stdin 
else
  DATA=$*
fi

case $COMMAND in
  create)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -d '$DATA' ${DAMAS_SERVER}/api/create/"
    ;;
  read)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -d '$DATA' ${DAMAS_SERVER}/api/read/"
    ;;
  update)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -X PUT -d '$DATA' ${DAMAS_SERVER}/api/update/"
    ;;
  upsert)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -d '$DATA' ${DAMAS_SERVER}/api/upsert/"
    ;;
  delete)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -X DELETE -d '$DATA' ${DAMAS_SERVER}/api/delete/"
    ;;
  graph)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -d '$DATA' ${DAMAS_SERVER}/api/graph/0/"
    ;;
  search)
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH ${DAMAS_SERVER}/api/search/$1"
    ;;
  search_mongo)
    QUERY='{"query": '$1', "sort": '$2', "limit": '$3', "skip": '$4'}'
    run "curl $CURL_VERBOSE $CURL_ARGS $AUTH -X POST ${DAMAS_SERVER}/api/search_mongo/ -d '$QUERY'"
    ;;
  signin)
    if [ $VERBOSE ]; then
      echo "$1"
    fi
    USERN=$1
    PASS=$2
	if [ $3 ]; then
	  expiresIn="&expiresIn=$3"
	else
	  expiresIn=""
	fi
    if [ -z $USERN ]; then
      read -p "login: " USERN
    fi
    if [ -z $PASS ]; then
      read -sp "password: " PASS
      printf "\n\n"
    fi
    RES=$(eval "curl $CURL_VERBOSE -ks -w \"\n%{http_code}\" --fail -d 'username=$USERN&password=${PASS}${expiresIn}' ${DAMAS_SERVER}/api/signIn/")
    TOKEN=$(echo $RES| sed 's/^.*"token":"\([^"]*\)".*$/\1/')
    echo $TOKEN
    echo $TOKEN > "/tmp/damas-$USER"
    chmod go-rw "/tmp/damas-$USER"
    map_server_errors "${RES##*$'\n'}"
    ;;
  signout)
    rm "/tmp/damas-$USER"
    exit 0
    ;;
  *)
    echo "damas: invalid command '$COMMAND'" >&2
    show_help_msg
    exit 1
    ;;
esac
