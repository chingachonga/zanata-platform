#!/bin/bash -xe

# determine directory containing this script
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# change to top of the git working directory
cd $DIR/../
ZANATA_WAR=$(echo $PWD/zanata-war/target/zanata-*.war)

# volume mapping for JBoss deployment folder (put exploded war or war file here to deploy)
ZANATA_DEPLOYMENTS_DIR=$HOME/docker-volumes/zanata-deployments
# make zanata deployment directory accessible to docker containers (SELinux)
mkdir -p ${ZANATA_DEPLOYMENTS_DIR} && chcon -Rt svirt_sandbox_file_t ${ZANATA_DEPLOYMENTS_DIR}

if [ -f "$ZANATA_WAR" ]
then
    # remove old file (hardlink) first
    rm ${ZANATA_DEPLOYMENTS_DIR}/ROOT.war
    # we can not use symlink as JBoss inside docker can't properly read the symlink file
    # try to link or copy the war file to deployments directory
    ln ${ZANATA_WAR} ${ZANATA_DEPLOYMENTS_DIR}/ROOT.war || cp ${ZANATA_WAR} ${ZANATA_DEPLOYMENTS_DIR}/ROOT.war
else
    echo "===== NO war file found. Please build Zanata war first ====="
    exit 1
fi

# JBoss ports
HTTP_PORT=8080
DEBUG_PORT=8787
MGMT_PORT=9090

while getopts ":p:H" opt; do
  case ${opt} in
    p)
      echo "===== set JBoss port offset to $OPTARG ====="
      if [ "$OPTARG" -eq "$OPTARG" ] 2>/dev/null
      then
        HTTP_PORT=$(($OPTARG + 8080))
        DEBUG_PORT=$(($OPTARG + 8787))
        MGMT_PORT=$(($OPTARG + 9090))
        echo "===== http port       : $HTTP_PORT"
        echo "===== debug port      : $DEBUG_PORT"
        echo "===== management port : $MGMT_PORT"
      else
        echo "===== MUST provide an integer as argument ====="
        exit 1
      fi
      ;;
    H)
      echo "========   HELP   ========="
      echo "-p <offset number> : set JBoss port offset"
      echo "-H                 : display help"
      exit
      ;;
    \?)
      echo "Invalid option: -${OPTARG}. Use -H for help" >&2
      exit 1
      ;;
  esac
done

# volume mapping for zanata server files
ZANATA_DIR=$HOME/docker-volumes/zanata
# create the data directory and set permissions (SELinux)
mkdir -p $ZANATA_DIR && chcon -Rt svirt_sandbox_file_t "$ZANATA_DIR"

# build the docker dev image
docker build -t zanata/server-dev docker/

# OutOfMemoryError handling:
#  The heap will be dumped to a file on the host, eg ~/docker-volumes/zanata/java_pid63.hprof
#  By default, we will keep the JVM running, so that a debugger can be attached.
#  Alternative option: -XX:OnOutOfMemoryError='kill -9 %p'

JBOSS_DEPLOYMENT_VOLUME=/opt/jboss/wildfly/standalone/deployments/

# runs zanata/server-dev:latest docker image
docker run \
    -e JAVA_OPTS="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/jboss/zanata" \
    --rm --name zanata --link zanatadb:db \
    -p ${HTTP_PORT}:8080 -p ${DEBUG_PORT}:8787 -p ${MGMT_PORT}:9990 -it \
    -v ${ZANATA_DEPLOYMENTS_DIR}:${JBOSS_DEPLOYMENT_VOLUME} \
    -v $ZANATA_DIR:/opt/jboss/zanata \
    zanata/server-dev
