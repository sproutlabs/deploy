#!/bin/bash
#
# Copyright (C) 2017 ht2labs
#
# This program is free software: you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program.
# If not, see http://www.gnu.org/licenses/.


#########################################
#           PACKING FUNCTIONS           #
#########################################
# $1 is the path to the tmp dir
function apt_package ()
{
    echo "creating apt package"
}


function yum_package ()
{
    echo "[LL] creating yum package"
}


#########################################
# GENERIC FUNCTIONS IRRESPECTIVE OF OS  #
#########################################
function checkCopyDir ()
{
    path=*
    if [ $1 ]; then
        path=$1/*
    fi

    if [[ $2 != "p" ]]; then
        echo -n "[LL] copying files (may take some time)...."
    fi
    for D in $path; do
        if [ -d "${D}" ]; then

            # checks to make sure we don't copy unneccesary files
            if [ $D == "node_modules" ]; then
                :
            elif [[ $D =~ .*/src$ ]]; then
                :
            #elif [ $D == "lib" ]; then
            #    :
            else
                # actual copy process (recursively)
                #echo "copying ${D}"
                if [[ ! -d ${TMPDIR}/${D} ]]; then
                    mkdir ${TMPDIR}/${D}
                fi
                # copy files
                for F in $D/*; do
                    if [ -f "${F}" ]; then
                        cp ${F} ${TMPDIR}/${D}/
                    fi
                done

                # go recursively into directories
                checkCopyDir $D p
            fi
        elif [ -f "${D}" ]; then
            cp $D ${TMPDIR}/${D}
        fi
    done
    if [[ $2 != "p" ]]; then
        echo "done"
    fi
}


function determine_os_version ()
{
    VERSION_FILE=/etc/issue.net
    REDHAT_FILE=/etc/redhat-release
    CENTOS_FILE=/etc/centos-release

    OS_SUBVER=false
    OS_VERSION=false
    OS_VNO=false

    # Make sure that the version is one we know about - if not, there'll likely be some strangeness with the package names
    if [ ! -f $VERSION_FILE ]; then
        echo "[LL] Couldn't determine version from $VERSION_FILE, file doesn't exist"
        exit 0
    fi
    RAW_OS_VERSION=$(cat $VERSION_FILE)
    if [[ $RAW_OS_VERSION == *"Amazon"* ]]; then
        OS_VERSION="Redhat"
        OS_SUBVER="Amazon"
        OS_ARCH=$(uname -a | awk '{print $12}')
        output_log "Detected OS: ${OS_VERSION}, subver:${OS_SUBVER}, arch:${OS_ARCH}, vno:${OS_VNO}, NodeOverride: ${NODE_OVERRIDE}, PM2Override:${PM2_OVERRIDE}"
    elif [[ $RAW_OS_VERSION == *"Debian"* ]]; then
        OS_VERSION="Debian"
        output_log "Detected OS: ${OS_VERSION}, subver:${OS_SUBVER}, arch:${OS_ARCH}, vno:${OS_VNO}, NodeOverride: ${NODE_OVERRIDE}, PM2Override:${PM2_OVERRIDE}"
    elif [[ $RAW_OS_VERSION == *"Ubuntu"* ]]; then
        OS_VERSION="Ubuntu"
        OS_VNO=`lsb_release -a | grep Release | awk '{print $2}'`
        if [[ $OS_VNO == "14.04" ]]; then
            NODE_OVERRIDE="6.x"
            PM2_OVERRIDE="ubuntu14"
        fi
        output_log "Detected OS: ${OS_VERSION}, subver:${OS_SUBVER}, arch:${OS_ARCH}, vno:${OS_VNO}, NodeOverride: ${NODE_OVERRIDE}, PM2Override:${PM2_OVERRIDE}"
    elif [[ -f $REDHAT_FILE ]]; then
        RAW_OS_VERSION=$(cat $REDHAT_FILE)
        OS_ARCH=$(uname -a | awk '{print $12}')
        # centos detection
        if [[ $RAW_OS_VERSION == *"CentOS"* ]]; then
            OS_VNO=$(cat $CENTOS_FILE | awk '{print $4}' | tr "." " " | awk '{print $1}')
            if [[ OS_VNO < 6 ]]; then
                echo "[LL] Versions of CentOS prior to CentOS 6 aren't supported"
                exit 0
            fi
            OS_VERSION="Redhat"
            OS_SUBVER="CentOS"
            output_log "Detected OS: ${OS_VERSION}, subver:${OS_SUBVER}, arch:${OS_ARCH}, vno:${OS_VNO}, NodeOverride: ${NODE_OVERRIDE}, PM2Override:${PM2_OVERRIDE}"
        # RHEL
        elif [[ $RAW_OS_VERSION == *"Red Hat Enterprise Linux"* ]]; then
            OS_VERSION="Redhat"
            OS_SUBVER="RHEL"
            OS_VNO=$(cat $REDHAT_FILE | awk '{print $7}')
            output_log "Detected OS: ${OS_VERSION}, subver:${OS_SUBVER}, arch:${OS_ARCH}, vno:${OS_VNO}, NodeOverride: ${NODE_OVERRIDE}, PM2Override:${PM2_OVERRIDE}"
            echo
            output "Sorry, we don't support RHEL at the moment"
            echo

        # Fedora
        elif [[ $RAW_OS_VERSION == *"Fedora"* ]]; then
            OS_VERSION="Redhat"
            OS_SUBVER="Fedora"
            OS_VNO=$(cat $REDHAT_FILE | awk '{print $3}')
            output_log "Detected OS: ${OS_VERSION}, subver:${OS_SUBVER}, arch:${OS_ARCH}, vno:${OS_VNO}, NodeOverride: ${NODE_OVERRIDE}, PM2Override:${PM2_OVERRIDE}"
            if [[ OS_VNO < 24 ]]; then
                echo
                output "Sorry, we don't support this version of Fedora at the moment"
                echo
                exit 0
            fi

        # unknown redhat - bail
        else
            output "Only set up for debian/ubuntu/centos at the moment I'm afraid - exiting"
            exit 0
        fi
    fi

    if [[ ! $OS_VERSION ]]; then
        output "Couldn't determind version from $VERSION_FILE, unknown OS: $RAW_OS_VERSION"
        exit 0
    fi
}


function print_spinner ()
{
    pid=$!
    s='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ));
        printf "\b${s:$i:1}";
        sleep .1;
    done
    printf "\b.";

    if [[ $1 == true ]]; then
        output "done!" false true
    fi
}


function output_log ()
{
    if [[ -f $OUTPUT_LOG ]]; then
        echo $1 >> $OUTPUT_LOG
    fi
}


# $1 is the message
# $2 is true/false to supress newlines
# $3 is true/false to supress the [LL] block
# $4 is the number of whitespace characters to insert before the text (not working yet)
function output ()
{
    if [[ $2 == true ]]; then
        if [[ $3 == true ]]; then
            echo -n $1
            output_log "$1"
        else
            MSG="[LL] $1"
            echo -n $MSG
            output_log "$MSG"
        fi
    else
        if [[ $3 == true ]]; then
            echo $1
            output_log "$1"
        else
            MSG="[LL] $1"
            echo $MSG
            output_log "$MSG"
        fi
    fi
}


# simple function to check if the version is greater than a specific other version
# $1 is the version to check
# $2 is the version to check against
# returns '1' if $1>=$2 or '2' otherwise
function version_check ()
{
    if [[ $1 == $2 ]]
    then
        return 1
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}


#################################################################################
#                            LEARNINGLOCKER FUNCTIONS                           #
#################################################################################
# $1 is the path to the install directory
# $2 is the username to run under
function setup_init_script ()
{
    if [[ ! -d $1 ]]; then
        output "path to install directory (${1}) wasn't a valid directory in setup_init_script(), exiting"
        exit 0
    fi

    if [[ ! `command -v pm2` ]]; then
        output "Didn't install pm2 or can't find it - the init script will need to be set up by hand. Press any key to continue"
        read n
        return
    fi


    output "starting base processes...." true
    su - $2 -c "cd $1; pm2 start all.json"
    output "done" true true

    output "starting xapi process...." true
    su - $2 -c "cd ${1}/xapi; pm2 start xapi.json"
    output "done" true true

    su - $2 -c "pm2 save"
    # I'm going to apologise here for the below line - for some reason when executing the resultant command
    # from the output of pm2 startup, the system $PATH doesn't seem to be set so we have to force it to be
    # an absolute path before running the command. It also needs to go into a variable and be run rather than
    # be run within backticks or the path still isn't substituted correctly. I know, right? it's a pain.
    output "setting up PM2 startup"
    if [[ $PM2_OVERRIDE != false ]]; then
        output "using PM2 startup override of $PM2_OVERRIDE"
        PM2_STARTUP=$(su - $2 -c "pm2 startup $PM2_OVERRIDE | grep sudo | sed 's?sudo ??' | sed 's?\$PATH?$PATH?'")
    else
        PM2_STARTUP=$(su - $2 -c "pm2 startup | grep sudo | sed 's?sudo ??' | sed 's?\$PATH?$PATH?'")
    fi
    CHK=$($PM2_STARTUP)

    if [[ $OS_SUBVER == "fedora" ]]; then
        output_log "fedora detected, SELinux may get in the way"
        echo "=========================="
        echo "|         NOTICE         |"
        echo "=========================="
        echo "As you're on fedora, you may need to either turn off SELinux (not recommended) or add a rule to allow"
        echo "access to the PIDFile in /etc/systemd/system/pm2-${2}.service or the startup script will fail to run"
        echo
        echo "In addition, you'll need to punch a hole in your firewalld config or disable the firewall with:"
        echo "  service stop firewalld"
        echo
        echo
        sleep 5
    fi
}


# this function is needed to fix the lack of a CDN in the unicode-json node module. Essentially we check for a unicode
# file in a set of directories and if it doesn't exist, we create a file
# $1 is the absolute path to the unicode file we want to copy in
function unicode_definition_install ()
{
    if [[ -f /usr/share/unicode/UnicodeData.txt ]]; then
        return 0
    fi
    if [[ -f /usr/share/unicode-data/UnicodeData.txt ]]; then
        return 0
    fi
    if [[ -f /usr/share/unicode/ucd/UnicodeData.txt ]]; then
        return 0
    fi

    if [[ ! -f $1 ]]; then
        output "the path for the unicode file wasn't passed to unicode_definition_install correctly (${1})"
        sleep 5
        return 1
    fi

    mkdir -p /usr/share/unicode
    cp $1 /usr/share/unicode/UnicodeData.txt
    chmod 644 /usr/share/unicode/UnicodeData.txt
}


function base_install ()
{
    # if the checkout dir exists, prompt the user for what to do
    DEFAULT_RM_TMP=y
    DO_BASE_INSTALL=true
    if [[ -d learninglocker_node ]]; then
        while true; do
            output "Temp directory already exists for checkout - delete [y|n] ? (enter is the default of ${DEFAULT_RM_TMP})"
            read -r -s -n 1 n
            if [[ $n == "" ]]; then
                n=$DEFAULT_RM_TMP
            fi
            if [[ $n == "y" ]]; then
                output "Ok, deleting temp directory...." true
                rm -R learninglocker_node
                output "done!" false true
                break
            elif [[ $n == "n" ]]; then
                output "ok, not removing it - could cause weirdness though so be warned"
                sleep 5
                DO_BASE_INSTALL=false
                break
            fi
        done
    fi

    if [[ ! `command -v git` ]]; then
        echo
        output "Can't find git - can't continue"
        echo
        exit 0
    fi

    # check if git is too far out of date
    GIT_VERSION=`git --version | awk '{print $3}'`
    MIN_GIT_VERSION="1.7.10"
    output "Git version: ${GIT_VERSION}, minimum: $MIN_GIT_VERSION"
    version_check $GIT_VERSION $MIN_GIT_VERSION
    VCHK=$?
    if [[ $VCHK == 2 ]]; then
        output "Sorry but your version of git is too old. You should be running a minimum of $MIN_GIT_VERSION"
        exit 0
    fi

    output "Will now try and clone the git repo for the main learninglocker software. May take some time...."

    # in a while loop to capture the case where a user enters the user/pass incorrectly
    if [[ $DO_BASE_INSTALL -eq true ]]; then
        while true; do
            output_log "running git clone"
            git clone -q -b ${GIT_BRANCH} https://github.com/LearningLocker/learninglocker learninglocker_node
            if [[ -d learninglocker_node ]]; then
                output_log "no learninglocker_node dir after git - problem"
                break
            fi
        done
    fi

    cd learninglocker_node
    GIT_REV=`git rev-parse --verify HEAD`
    if [[ ! -f .env ]]; then
        cp .env.example .env
        if [[ $UPDATE_MODE == false ]]; then
            output "Copied example env to .env - This will need editing by hand"
        fi
        APP_SECRET=`openssl rand -base64 32`
        sed -i "s?APP_SECRET=?APP_SECRET=${APP_SECRET}?" .env
    fi

    output "checking UnicodeData is present..." true
    unicode_definition_install $PWD/UnicodeData.txt
    output "done!" false true

    # yarn install
    output "running yarn install...." true
    yarn install >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    # pm2 - done under npm rather than yarn as yarn does weird stuff on global installs on debian
    output "adding pm2...." true
    npm install -g pm2 >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    # yarn build-all
    output "running yarn build-all (this can take a little while - don't worry, it's not broken)...." true
    yarn build-all >>$OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    # pm2 logrotate
    output "installing pm2 logrotate...." true
    pm2 install pm2-logrotate >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true
    output "setting up pm2 logrotate...." true
    pm2 set pm2-logrotate:compress true >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    # npm dedupe
    output "running npm dedupe...." true
    npm dedupe >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true
}


function xapi_install ()
{
    output "Will now try and clone the git repo for XAPI. Will prompt for user/pass and may take some time...."
    # not checking for presence of 'git' command as done in git_clone_base()

    DO_XAPI_CHECKOUT=true;
    if [[ -d xapi ]]; then
        DEFAULT_RM_TMP="y"
        while true; do
            output "Tmp directory already exists for checkout of xapi - delete [y|n] ? (enter is the default of ${DEFAULT_RM_TMP})"
            read n
            output_log "user entered '${n}'"
            if [[ $n == "" ]]; then
                n=$DEFAULT_RM_TMP
            fi
            if [[ $n == "y" ]]; then
                rm -R xapi
                break
            elif [[ $n == "n" ]]; then
                output "ok, not removing it - could cause weirdness though so be warned"
                DO_XAPI_CHECKOUT=false
                sleep 5
                break
            fi
        done
    fi

    # do the checkout in a loop in case the users enters user/pass incorrectly
    if [[ $DO_XAPI_CHECKOUT -eq true ]]; then
        while true; do
            output_log "attempting git clone for xapi"
            git clone -q https://github.com/LearningLocker/xapi-service.git xapi
            if [[ -d xapi ]]; then
                output_log "git clone appears to have failed"
                break
            fi
        done
    fi

    cd xapi/

    # sort out .env
    if [[ ! -f .env ]]; then
        cp .env.example .env
        if [[ $UPDATE_MODE == false ]]; then
            output "Copied example env to .env - This will need editing by hand"
        fi
    fi

    # npm
    output "running npm install...." true
    npm install >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    output "running npm run build...." true
    npm run build >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    cd ../
}



function nvm_install ()
{
    if [[ -d ~/.nvm ]]; then
        output "nvm is already installed. Do you want to check for an update ? [y|n] (Press enter for a default of 'y')"
        while true; do
            read -r -s -n 1 c
            output_log "user entered '${c}'"
            if [[ $c == "" ]] || [[ $c == "y" ]]; then
                output_log "will check NVM"
                break
            elif [[ $c == "n" ]]; then
                output_log "not checking NVM"
                return
            fi
        done
    fi

    output "running nvm install/update process...." true
    wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true
}


# $1 is the file to reprocess
# $2 is the path to the install dir
# $3 is the log path - if not passed in we'll assume it's $2/logs/
# $4 is the pid path - if not passed in we'll assume it's $2/pids/
function reprocess_pm2 ()
{
    if [[ ! $1 ]]; then
        output "no file name passed to reprocess_pm2"
        return
    elif [[ ! -f $1 ]]; then
        output "file '${1}' passed to reprocess_pm2() appears to not exist."
        sleep 10
        return
    fi

    if [[ ! $2 ]]; then
        output "no install path passed to reprocess_pm2 - exiting"
        exit 0
    fi

    LOG_DIR=$2/logs
    PID_DIR=$2/pids
    if [[ $3 ]]; then
        LOG_DIR=$3
    fi
    if [[ $4 ]]; then
        PID_DIR=$4
    fi

    output_log "pm2 - setting pid dir to $PID_DIR"
    output_log "pm2 - setting install path to $2"
    output_log "pm2 - setting log dir to $LOG_DIR"

    sed -i "s?{INSTALL_DIR}?${2}?g" $1
    sed -i "s?{LOG_DIR}?${LOG_DIR}?g" $1
    sed -i "s?{PID_DIR}?${PID_DIR}?g" $1
}


# central method to read variables from the .env and overwrite into the nginx config
# $1 is the nginx config
# $2 is the .env to over-write
# $3 is the xapi .env
# $4 is the path to the install - typically this should be the path to the symlink directory rather than the release dir
function setup_nginx_config ()
{
    if [[ ! -f $1 ]]; then
        output "Warning :: nginx config in $1 can't be found - will need to be edited manually. Press any key to continue"
        read -r -s -n 1 n
        return 0
    fi

    if [[ ! -f $2 ]]; then
        output "Warning :: .env in $2 can't be found, can't set up nginx config correctly - will need to be edited manually. Press any key to continue"
        read -r -s -n 1 n
        return 0
    fi

    if [[ ! -f $3 ]]; then
        output "Warning :: xapi .env in $3 can't be found, can't set up nginx config correctly - will need to be edited manually. Press any key to continue"
        read -r -s -n 1 n
        return 0
    fi

    UI_PORT=`fgrep UI_PORT $2 | sed 's/UI_PORT=//' | sed 's/\r//' `
    XAPI_PORT=`fgrep EXPRESS_PORT $3| sed 's/EXPRESS_PORT=//' | sed 's/\r//' `

    output_log "nginx - setting ui port to $UI_PORT"
    output_log "nginx - setting xapi port to $XAPI_PORT"
    output_log "nginx - setting site root to $4"

    sed -i "s/UI_PORT/${UI_PORT}/" $1
    sed -i "s/XAPI_PORT/${XAPI_PORT}/" $1
    sed -i "s?/SITE_ROOT?${4}?" $1
}



#################################################################################
#                           DEBIAN / UBUNTU FUNCTIONS                           #
#################################################################################
function debian_install ()
{
    # debian & ubuntu have a package called cmdtest which we need to uninstall as it'll conflict with yarn
    apt-get remove cmdtest >> $OUTPUT_LOG 2>>$ERROR_LOG &

    # we run an apt-get update here in case the distro is out of date
    if [[ ! `command -v python` ]] || [[ ! `command -v curl` ]] || [[ ! `command -v git` ]] || [[ ! `command -v gcc` ]] || [[ ! `command -v g++` ]]; then
        apt-get update >> $OUTPUT_LOG 2>>$ERROR_LOG
        apt-get -y -qq install net-tools curl git python build-essential xvfb apt-transport-https >> $OUTPUT_LOG 2>>$ERROR_LOG
    fi

    if [[ ! `command -v python` ]]; then
        output "Something seems to have gone wrong in installing basic software - exiting"
        exit 0
    fi

    if [[ ! `command -v nodejs` ]]; then
        curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - >> $OUTPUT_LOG 2>>$ERROR_LOG
        apt-get -y -qq install nodejs >> $OUTPUT_LOG 2>>$ERROR_LOG
    else
        output "Node.js already installed"
    fi

    if [[ ! `command -v yarn` ]]; then
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - >> $OUTPUT_LOG 2>>$ERROR_LOG
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
        apt-get -qq update >> $OUTPUT_LOG 2>>$ERROR_LOG
        apt-get -y -qq install yarn >> $OUTPUT_LOG 2>>$ERROR_LOG
    else
        output "yarn already installed"
    fi

    if [[ ! `command -v python` ]]; then
        if [[ `command -v python3` ]]; then
            output "Symlinking python3 to python for Yarn"
            ln -s `command -v python3` /usr/bin/python
        else
            output "FATAL Error - can't find python. Path: ${PATH} EUID:${EUID}"
            exit 0
        fi
    fi
}


function debian_nginx ()
{
    if [[ ! -d $1 ]]; then
        output "No temp directory passed to debian_nginx() '${1}', should be impossible - exiting"
        exit 0
    fi

    while true; do
        echo
        output "The next part of the install process will install nginx and remove any default configs - press 'y' to continue or 'n' to abort (press 'enter' for the default of 'y')"
        read -r -s -n 1 n
        output_log "user entered '${n}'"
        if [[ $n == "" ]]; then
            n="y"
        fi
        if [[ $n == "y" ]]; then
            break
        elif [[ $n == "n" ]]; then
            output "Can't continue - you'll need to do this step by hand"
            sleep 5
            return
        fi
    done

    output "installing nginx...." true
    apt-get -y -qq install nginx >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true

    if [[ ! -f ${1}/nginx.conf.example ]]; then
        output "default learninglocker nginx config doesn't exist - can't continue. Press any key to continue"
        read n
        return
    fi


    NGINX_CONFIG=/etc/nginx/sites-available/learninglocker.conf
    XAPI_ENV=${PWD}/xapi/.env
    BASE_ENV=${PWD}/.env
    rm /etc/nginx/sites-enabled/*
    mv ${1}/nginx.conf.example $NGINX_CONFIG
    ln -s $NGINX_CONFIG /etc/nginx/sites-enabled/learninglocker.conf
    # sub in variables from the .envs to the nginx config
    setup_nginx_config $NGINX_CONFIG $BASE_ENV $XAPI_ENV $2

    service nginx restart
}


function debian_mongo ()
{
    if [[ $OS_VERSION == "Ubuntu" ]]; then
        if [[ $OS_VNO == "16.04" ]]; then
            output "Setting up mongo repo (Stock Ubuntu version is too old)"
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
            echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
            apt-get update >> $OUTPUT_LOG 2>>$ERROR_LOG
            apt-get install mongodb-org >> $OUTPUT_LOG 2>>$ERROR_LOG
        fi
    else
        output "installing mongodb...." true
        apt-get -y -qq install mongodb >> $OUTPUT_LOG 2>>$ERROR_LOG &
        print_spinner true
    fi
}


function debian_redis ()
{
    output "[LL] installing redis...." true
    apt-get -y -qq install redis-tools redis-server >> $OUTPUT_LOG 2>>$ERROR_LOG &
    print_spinner true
}


#################################################################################
#                                REDHAT FUNCTIONS                               #
#################################################################################
REDHAT_EPEL_INSTALLED=false
function redhat_epel ()
{
    if [[ $REDHAT_EPEL_INSTALLED == true ]]; then
        return
    fi
    yum install epel-release >> $OUTPUT_LOG 2>>$ERROR_LOG
    REDHAT_EPEL_INSTALLED=true
}


function redhat_redis ()
{
    output "installing redis"
    redhat_epel
    yum install redis >> $OUTPUT_LOG 2>>$ERROR_LOG
    service redis start >> $OUTPUT_LOG 2>>$ERROR_LOG
}


function redhat_mongo ()
{
    output "installing mongodb"
    redhat_epel
    mkdir -p /data/db
    yum install mongodb-server >> $OUTPUT_LOG 2>>$ERROR_LOG
    semanage port -a -t mongod_port_t -p tcp 27017 >> $OUTPUT_LOG 2>>$ERROR_LOG
    service mongod start >> $OUTPUT_LOG 2>>$ERROR_LOG
}


function redhat_install ()
{
    output "installing base software"
    yum -y install curl git python make automake gcc gcc-c++ kernel-devel xorg-x11-server-Xvfb git-core >> $OUTPUT_LOG 2>>$ERROR_LOG

    if [[ ! `command -v nodejs` ]]; then
        output "setting up nodejs repo and installing nodejs"
        curl --silent --location https://rpm.nodesource.com/setup_${NODE_VERSION} | bash -
        yum -y install nodejs >> $OUTPUT_LOG 2>>$ERROR_LOG
    else
        output "Node.js already installed"
    fi

    if [[ ! `command -v yarn` ]]; then
        output "setting up yarn repo and installing yarn"
        wget https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo >> $OUTPUT_LOG 2>>$ERROR_LOG
        yum -y install yarn >> $OUTPUT_LOG 2>>$ERROR_LOG
    else
        output "yarn already installed"
    fi
}


function redhat_nginx ()
{
    if [[ ! -d $1 ]]; then
        output "No temp directory passed to centos_nginx(), should be impossible - exiting"
        exit 0
    fi

    while true; do
        echo
        output "The next part of the install process will install nginx and remove any default configs - press 'y' to continue or 'n' to abort (press 'enter' for the default of 'y')"
        read n
        output_log "user pressed '${n}'"
        if [[ $n == "" ]]; then
            n="y"
        fi
        if [[ $n == "y" ]]; then
            break
        elif [[ $n == "n" ]]; then
            output "Can't continue - you'll need to do this step by hand"
            sleep 5
            return
        fi
    done

    yum -y install nginx >> $OUTPUT_LOG 2>>$ERROR_LOG

    # remove default config if it exists
    if [[ -f /etc/nginx/conf.d/default.conf ]]; then
        rm /etc/nginx/conf.d/default.conf
    fi

    if [[ $OS_SUBVER == "Fedora" ]]; then
        echo "[LL] Default fedora nginx config needs the server block in /etc/nginx/nginx.conf removing"
        echo "     before learninglocker will work properly or it'll clash with the LL config"
        echo "     Press any key to continue"
        read n
    fi


    if [[ ! -f ${1}/nginx.conf.example ]]; then
        output "default learninglocker nginx config doesn't exist - can't continue. Press any key to continue"
        read n
        return
    fi


    NGINX_CONFIG=/etc/nginx/conf.d/learninglocker.conf
    XAPI_ENV=${PWD}/xapi/.env
    BASE_ENV=${PWD}/.env
    mv ${1}/nginx.conf.example $NGINX_CONFIG
    # sub in variables from the .envs to the nginx config
    setup_nginx_config $NGINX_CONFIG $BASE_ENV $XAPI_ENV $2
    restorecon -v $NGINX_CONFIG


    if [[ $OS_SUBVER == "CentOS" ]] || [[ $OS_SUBVER == "Fedora" ]]; then
        echo "[LL] I need to punch a hole in selinux to continue. This is running the command:"
        echo "         setsebool -P httpd_can_network_connect 1"
        echo "     press 'y' to continue or 'n' to exit"
        while true; do
            read n
            if [[ $n == "n" ]]; then
                echo "not doing this, you'll have to run it by hand"
                sleep 5
                break
            elif [[ $n == "y" ]]; then
                setsebool -P httpd_can_network_connect 1
                break
            fi
        done
    fi


    service nginx restart

    if [[ $OS_SUBVER == "CentOS" ]]; then
        output "as you're on CentOS, this may be running with firewalld enabled - you'll either need to punch"
        output "a hole in the firewall rules or disable firewalld (not recommended) to allow inbound access to" false false 5
        output "learning locker. Press any key to continue" false false 5
        read n
    fi
}


#################################################################################
#                                CENTOS FUNCTIONS                               #
#################################################################################


#################################################################################
#                                AMAZON FUNCTIONS                               #
#################################################################################
function amazon_mongo ()
{
    MONGO_REPO_FILE=/etc/yum.repos.d/mongodb-org-3.4.repo

    output "setting up mongo repo in $MONGO_REPO_FILE"

    echo "[mongodb-org-3.4]" > $MONGO_REPO_FILE
    echo "name=MongoDB Repository" >> $MONGO_REPO_FILE
    echo "baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.4/x86_64/" >> $MONGO_REPO_FILE
    echo "gpgcheck=1" >> $MONGO_REPO_FILE
    echo "enabled=1" >> $MONGO_REPO_FILE
    echo "gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc" >> $MONGO_REPO_FILE
    yum -y install mongodb-org
}


#################################################################################
#                                FEDORA FUNCTIONS                               #
#################################################################################
function fedora_redis ()
{
    output "installing redis"
    yum install redis >> $OUTPUT_LOG 2>>$ERROR_LOG
}


function fedora_mongo ()
{
    output "installing mongodb"
    yum install mongodb-server >> $OUTPUT_LOG 2>>$ERROR_LOG
}


#################################################################################
#################################################################################
#################################################################################
#                                                                               #
#                                END OF FUNCTIONS                               #
#                                                                               #
#################################################################################
#################################################################################
#################################################################################

# before anything, make sure the tmp dir is large enough of get the user to specify a new one
_TD=/tmp
MIN_DISK_SPACE=3000000

# check we have enough space available
FREESPACE=`df $_TD | awk '/[0-9]%/{print $(NF-2)}'`
if [[ $FREESPACE -lt $MIN_DISK_SPACE ]]; then
    echo "[LL] your temp dir isn't large enough to continue, please enter a new path (pressing enter will exit)"
    while true; do
        read n
        if [[ $n == "" ]]; then
            exit 0
        elif [[ ! -d $n ]]; then
            echo "[LL] Sorry but the directory '${n}' doesn't exist - please enter a valid one (press enter to exit)"
        else
            _TD=$n
            break
        fi
    done
fi



#################################################################################
#                                DEFAULT VALUES                                 #
#################################################################################
UPI=false
LOCAL_INSTALL=false
PACKAGE_INSTALL=false
DEFAULT_USER=learninglocker
DEFAULT_SYMLINK_PATH=/usr/local/learninglocker/current
DEFAULT_LOCAL_RELEASE_PATH=/usr/local/learninglocker/releases
DEFAULT_INSTALL_TYPE=l
LOCAL_PATH=false
LOCAL_USER=false
TMPDIR=$_TD/.tmpdist
GIT_BRANCH="master"
MIN_REDIS_VERSION="2.8.11"
MIN_MONGO_VERSION="3.0.0"
BUILDDIR=$_TD
MONGO_INSTALLED=false
REDIS_INSTALLED=false
PM2_OVERRIDE=false
NODE_OVERRIDE=false
NODE_VERSION=6.x
UPDATE_MODE=false
GIT_ASK=false
GIT_REV=false
RELEASE_PATH=false
SYMLINK_PATH=false
MIN_MEMORY=970
LOG_PATH=/var/log/learninglocker
OUTPUT_LOG=${LOG_PATH}/install.log
ERROR_LOG=$OUTPUT_LOG # placeholder - only want one file for now, may be changed later



#################################################################################
#                                 START CHECKS                                  #
#################################################################################

# cleanup, just in case
if [ -d $TMPDIR ]; then
    rm -R $TMPDIR
fi

if [ -d "${BUILDDIR}learninglocker_node" ]; then
    echo "clearing old tmp dir"
    rm -R ${BUILDDIR}learninglocker_node
fi

if [ -d $TMPDIR ]; then
    output "tmp directory from prior install (${TMPDIR}) still exists - please clear by hand"
    exit 0
fi

# check if root user
if [[ `whoami` != "root" ]]; then
    output "Sorry, you need to be root to run this script (currently normal user)"
    exit 0
fi
if [[ $EUID > 0 ]]; then
    # THIS EUID check checks if we're sudo - I don't want the script to run a sudo for the time being
    output "Sorry, you need to be root to run this script (currently sudo)"
    exit 0
fi

if [[ ! `command -v openssl` ]]; then
    output "Sorry but you need openssl installed to install"
    exit 0
fi

# check system memory (in MB)
SYSTEM_MEMORY=$(free -m | awk '/^Mem:/{print $2}')
if [[ $SYSTEM_MEMORY -lt $MIN_MEMORY ]]; then
    output "You need a minimum of ${MIN_MEMORY}Mb of system memory to install Learning Locker - can't continue"
    exit 0
fi

# logging
if [[ ! -d $LOG_PATH ]]; then
    mkdir -p $LOG_PATH
fi
if [[ -f $OUTPUT_LOG ]]; then
    rm $OUTPUT_LOG
    touch $OUTPUT_LOG
fi


#################################################################################
#                                 ASK QUESTIONS                                 #
#################################################################################
if [[ $GIT_ASK == true ]]; then
    while true; do
        output "What branch do you want to install ? Press 'enter' for the default of ${GIT_BRANCH}"
        read -r n
        if [[ $n == "" ]]; then
            output_log "user didn't select a branch"
            break
        else
            while true; do
                output "are you sure the branch '${n}' is correct ? [y|n] (press enter for the default of 'y')"
                read -r -s -n 1 c
                if [[ $c == "" ]]; then
                    c="y"
                fi
                output_log "user entered '${c}'"
                if [[ $c == "y" ]]; then
                    GIT_BRANCH=$n
                    break 2
                elif [[ $c == "n" ]]; then
                    break
                fi
            done
        fi
    done
fi

while true; do
    #echo "[LL] Do you want to install this locally(l) or create a package(p) ? [l|p] (enter for default of '${DEFAULT_INSTALL_TYPE}'"
    #read -r -s -n 1 n
    n="l"
    if [[ $n == "" ]]; then
        n=$DEFAULT_INSTALL_TYPE
    fi
    if [[ $n == "l" ]]; then
        output_log "NOTE :: Local install selected"
        LOCAL_INSTALL=true
        break
    elif [[ $n == "p" ]]; then
        output_log "NOTE :: Package install selected"
        PACKAGE_INSTALL=true
        break
    fi
done


#######################################################################
#                       LOCAL INSTALL QUESTIONS                       #
#######################################################################
if [[ $LOCAL_INSTALL == true ]]; then

    # determine local installation path
    output " We require a path to install to and a path to symlink to. The reason for this is that the script can be re-run in order to update"
    output "     cleanly. The path we'll ask you for is a base path for the releases to be installed to so if you select the default of:" false true
    output "         $DEFAULT_LOCAL_RELEASE_PATH" false true
    output "     then we will create a sub-directory under here for every release and symlink the latest install to the final install path (which" false true
    output "     the nginx config points at. This is so that roll-backs can be done easier and we can perform a complete install before finally" false true
    output "     switching the nginx config over which'll minimise downtime on upgrades" false true
    while true; do
        output "What base directory do you want to install to ? (Press 'enter' for the default of $DEFAULT_LOCAL_RELEASE_PATH)"
        read -r p
        if [[ $p == "" ]]; then
            p=$DEFAULT_LOCAL_RELEASE_PATH
        fi
        output_log "attempting to use base path of: $DEFAULT_LOCAL_RELEASE_PATH"
        if [[ ! -d $p ]]; then
            while true; do
                output "Directory '${p}' doesn't exist - should we create it ? [y|n] (Press enter for default of 'y')"
                read -r -s -n 1 c
                if [[ $c == "" ]] || [[ $c == "y" ]]; then
                    output_log "user opted to proceed"
                    mkdir -p $p
                    if [[ ! -d $p ]]; then
                        output "ERROR : Tried to create directory $p and couldn't, exiting"
                        exit 0
                    fi
                    RELEASE_PATH=$p
                    break 2
                elif [[ $c == n ]]; then
                    output "ERROR : Can't continue without creating releases directory, exiting"
                    exit 0
                fi
            done
        else
            RELEASE_PATH=$p
            break
        fi
    done

    # check where to symlink to
    while true; do
        output "What path should the release be symlinked to ? (Press enter for the default of $DEFAULT_SYMLINK_PATH)"
        read -r p
        if [[ $p == "" ]]; then
            p=$DEFAULT_SYMLINK_PATH
        fi
        SYMLINK_PATH=$p
        output_log "attempting to use path of: $SYMLINK_PATH"
        if [[ -f $SYMLINK_PATH ]] && [[ ! -L $SYMLINK_PATH ]]; then
            output "This path appears to already exist and be a regular file rather than a symlink - Can't continue"
            exit 0
        elif [[ -L $SYMLINK_PATH ]]; then
            # symlink exists, go into update mode
            output "It looks like this symlink already exists - do you want to upgrade an existing install ? [y|n] (Press enter for the default of 'y')"
            while true; do
                read -r -s -n 1 c
                if [[ $c == "y" ]] || [[ $c == "" ]]; then
                    output_log "user pressed '${c}'"
                    output_log "NOTE :: RUNNING IN UPDATE MODE FROM NOW ON"
                    UPDATE_MODE=true
                    break 2
                elif [[ $c == n ]]; then
                    while true; do
                        output "Ok, do you want to continue to install anyway ? If you select yes then we'll unlink/delete things as needed [y|n] (Press enter for the default of 'y')"
                        read -r -s -n 1 b
                        if [[ $b == "y" ]] || [[ $b == "" ]]; then
                            output "Ok, continuing on - you won't be prompted for any overrides"
                            break 3
                        elif [[ $b == "n" ]]; then
                            output "Ok, I can't continue - you'll need to complete the install manually"
                            exit 0
                        fi
                    done
                fi
            done
        else
            # no file currently present - bog standard normal install
            break
        fi
    done


    # determine user to install under
    while true; do
        output "I need a user to install the code under - what user would you like me to use ? (press enter for the default of '$DEFAULT_USER')"
        read -r u
        if [[ $u == "" ]]; then
            u=$DEFAULT_USER
        fi
        USERDATA=`getent passwd $u`
        if [[ $USERDATA == *"$u"* ]]; then
            # user exists
            while true; do
                output "User '$u' already exists - are you sure you want to continue? [y|n] (enter for default of 'y')"
                read -r -s -n 1 c
                if [[ $c == "" ]]; then
                    c="y"
                fi
                if [[ $c == "y" ]]; then
                    output_log "continuing using this user"
                    LOCAL_USER=$u
                    break
                elif [[ $c == "n" ]]; then
                    output "Selected to not continue, exiting"
                    exit 0
                fi
            done
        else
            while true; do
                output "User '$u' doesn't exist - do you want me to create them ? [y|n] (enter for default of 'y')"
                read -r -s -n 1 c
                if [[ $c == "" ]]; then
                    c="y"
                fi
                if [[ $c == "y" ]]; then
                    output "Creating user '${u}'...." true
                    useradd -r -d $RELEASE_PATH $u
                    if [[ ! -d $RELEASE_PATH ]]; then
                        mkdir -p $RELEASE_PATH
                    fi
                    chown ${u}:${u} $RELEASE_PATH
                    output "done!" false true
                    LOCAL_USER=$u
                    break
                elif [[ $c == "n" ]]; then
                    output "Can't create user - can't continue"
                    exit 0
                fi
            done
        fi
        break
    done


    # check mongo
    if [[ `command -v mongod` ]]; then
        output "MongoDB is already installed, not installing"
        CUR_MONGO_VERSION=`mongod --version | grep "db version" | sed "s?db version v??"`
        output_log "mongo version currently installed: $CUR_MONGO_VERSION"
        version_check $CUR_MONGO_VERSION $MIN_MONGO_VERSION
        MONGOCHK=$?
        output_log "mongo check is $MONGOCHK"
        if [[ $MONGOCHK == 2 ]]; then
            output "Warning:: this version of mongo (${CUR_MONGO_VERSION}) is below the minimum requirement of ${MIN_MONGO_VERSION} - you'll need to update this yourself"
            sleep 5
        else
            output "Mongo version (${CUR_MONGO_VERSION}) is above minimum of $MIN_MONGO_VERSION - continuing"
            MONGO_INSTALLED=true
        fi
    else
        while true; do
            output "MongoDB isn't installed - do you want to install it ? [y|n] (press 'enter' for default of 'y')"
            read -r -s -n 1 c
            if [[ $c == "" ]]; then
                c="y"
            fi
            if [[ $c == "y" ]]; then
                output_log "opted to install mongo"
                MONGO_INSTALL=true
                MONGO_INSTALLED=true
                break
            elif [[ $c == "n" ]]; then
                output_log "opted not to install mongo"
                MONGO_INSTALL=false
                break
            fi
        done
    fi

    # check redis
    if [[ `command -v redis-server` ]]; then
        output "Redis is already installed, not installing"
        CUR_REDIS_VERSION=`redis-server --version | awk '{print $3}' | sed 's/v=//'`
        output_log "Redis Version: $CUR_REDIS_VERSION"
        version_check $CUR_REDIS_VERSION $MIN_REDIS_VERSION
        REDISCHK=$?
        if [[ $REDISCHK == 2 ]]; then
            output "Warning:: this version of redis (${CUR_REDIS_VERSION}) is below the minimum requirement of ${MIN_REDIS_VERSION} - you'll need to update this yourself"
            sleep 5
        else
            output "Redis version (${CUR_REDIS_VERSION}) is above minimum of $MIN_REDIS_VERSION - continuing"
            REDIS_INSTALLED=true
        fi
    else
        while true; do
            output "Redis isn't installed - do you want to install it ? [y|n] (press 'enter' for default of 'y')"
            read -r -s -n 1 c
            if [[ $c == "" ]]; then
                c="y"
            fi
            if [[ $c == "y" ]]; then
                output_log "opted to install redis"
                REDIS_INSTALL=true
                REDIS_INSTALLED=true
                break
            elif [[ $c == "n" ]]; then
                output_log "opted not to install redis"
                REDIS_INSTALL=false
                break
            fi
        done
    fi
fi


#######################################################################
#                      PACKAGE INSTALL QUESTIONS                      #
#######################################################################
if [[ $PACKAGE_INSTALL == true ]]; then
    echo "PACKAGE QUESTIONS GO HERE"
fi



#################################################################################
#                          RUN BASE INSTALL TO TMPDIR                           #
#################################################################################
determine_os_version

if [[ $NODE_OVERRIDE != false ]]; then
    NODE_VERSION=$NODE_OVERRIDE
fi
output "Installing node version: $NODE_VERSION"

if [[ $OS_VERSION == "Debian" ]]; then
    debian_install
elif [[ $OS_VERSION == "Ubuntu" ]]; then
    debian_install
elif [[ $OS_VERSION == "Redhat" ]]; then
    redhat_install
fi


nvm_install

# base install & build
output "Running install step"
cd $BUILDDIR
base_install
xapi_install

# create tmp dir
output "creating $TMPDIR"
mkdir -p $TMPDIR

# package.json
output "copying modules...." true
if [[ ! -f ${BUILDDIR}/learninglocker_node/package.json ]]; then
    output "can't copy file '${BUILDDIR}/learninglocker_node/package.json' as it doesn't exist- exiting" false true
    exit 0
fi
cp ${BUILDDIR}/learninglocker_node/package.json $TMPDIR/

# pm2 loader
if [[ ! -f ${BUILDDIR}/learninglocker_node/pm2/all.json ]]; then
    output "can't copy file '${BUILDDIR}/learninglocker_node/pm2/all.json' as it doesn't exist- exiting" false true
    exit 0
fi
cp ${BUILDDIR}/learninglocker_node/pm2/all.json.dist $TMPDIR/all.json

# xapi config
if [[ ! -f ${BUILDDIR}/learninglocker_node/xapi/pm2/xapi.json.dist ]]; then
    output "can't copy file '${BUILDDIR}/learninglocker_node/xapi/pm2/xapi.json.dist' as it doesn't exist- exiting" false true
    exit 0
fi
if [[ ! -d ${TMPDIR}/xapi ]]; then
    mkdir -p ${TMPDIR}/xapi
fi
cp ${BUILDDIR}/learninglocker_node/xapi/pm2/xapi.json.dist $TMPDIR/xapi/xapi.json

# node_modules
if [[ ! -d ${BUILDDIR}/learninglocker_node/node_modules ]]; then
    output "can't copy directory '${BUILDDIR}/learninglocker_node/node_modules' as it doesn't exist- exiting" false true
    exit 0
fi
cp -R ${BUILDDIR}/learninglocker_node/node_modules $TMPDIR/ >> $OUTPUT_LOG 2>>$ERROR_LOG &
print_spinner true

output_log "copying nginx.conf.example to $TMPDIR"
cp nginx.conf.example $TMPDIR/

output_log "copying ${BUILDDIR}/learninglocker_node/.git to $TMPDIR"
cp -R ${BUILDDIR}/learninglocker_node/.git $TMPDIR/

output_log "copying ${BUILDDIR}/learninglocker_node/.env to $TMPDIR"
cp ${BUILDDIR}/learninglocker_node/.env $TMPDIR/

output_log "copying ${BUILDDIR}/learninglocker_node/xapi/.env to $TMPDIR/xapi/"
cp ${BUILDDIR}/learninglocker_node/xapi/.env $TMPDIR/xapi/
checkCopyDir


DATESTRING=`date +%Y%m%d`
LOCAL_PATH=${RELEASE_PATH}/ll-${DATESTRING}-${GIT_REV}


if [[ $LOCAL_INSTALL == true ]] && [[ $UPDATE_MODE == false ]]; then
    #################################################################################
    #                                 LOCAL INSTALL                                 #
    #################################################################################


    # UBUNTU & DEBIAN
    if [[ $OS_VERSION == "Ubuntu" ]] || [[ $OS_VERSION == "Debian" ]]; then
        debian_nginx $TMPDIR $SYMLINK_PATH
        if [[ $REDIS_INSTALL == true ]]; then
            debian_redis
        fi
        if [[ $MONGO_INSTALL == true ]]; then
            debian_mongo
        fi
    elif [[ $OS_VERSION == "Redhat" ]]; then
        # BASE REDHAT stuff
        redhat_nginx $TMPDIR $SYMLINK_PATH
    # FEDORA
        if [[ $OS_SUBVER == "Fedora" ]]; then
            if [[ $REDIS_INSTALL == true ]]; then
                fedora_redis
            fi
            if [[ $MONGO_INSTALL == true ]]; then
                fedora_mongo
            fi
    # AMAZON
        elif [[ $OS_SUBVER == "Amazon" ]]; then
            if [[ $REDIS_INSTALL == true ]]; then
                output "AWS Linux doesn't ship with Redis in a repository. You'll need to install this yourself. Press any key to continue"
                REDIS_INSTALL=false
                REDIS_INSTALLED=false
                read -n 1 n
                if [[ $MONGO_INSTALL == true ]]; then
                    output "As redis isn't going to be installed locally, do you still want to install MongoDB ? [y|n] (press enter for the default of 'y')"
                    read -s -r -n 1 n
                    output_log "user entered '${n}'"
                    if [[ $n == "n" ]]; then
                        MONGO_INSTALL=false
                    fi
                fi
            fi
            if [[ $MONGO_INSTALL == true ]]; then
                amazon_mongo
                read n
            fi
        else
    # RHEL / GENERIC REDHAT & CENTOS (nothing specific required for centos)
            if [[ $REDIS_INSTALL == true ]]; then
                redhat_redis
            fi
            if [[ $MONGO_INSTALL == true ]]; then
                redhat_mongo
            fi
        fi
    fi


    output "Local install to $LOCAL_PATH"


    # check redis installed to the right version
    # if not, then we'll act like we haven't installed it
    if [[ $REDIS_INSTALL == true ]]; then
        if [[ ! `command -v redis-server` ]]; then
            output "Warning :: Can't find the redis-server executable, this means it's not been installed when it looks like it should've been. Press any key to continue"
            REDIS_INSTALLED=false
            read -n 1 n
        else
            CUR_REDIS_VERSION=`redis-server --version | awk '{print $3}' | sed 's/v=//'`
            version_check $CUR_REDIS_VERSION $MIN_REDIS_VERSION
            output_log "redis version: $CUR_REDIS_VERSION"
            REDISCHK=$?
            if [[ $REDISCHK == 2 ]]; then
                output "Warning:: this version of redis (${CUR_REDIS_VERSION}) is below the minimum requirement of ${MIN_REDIS_VERSION} - you'll need to update this yourself - Press any key to continue"
                REDIS_INSTALLED=false
                read -n 1 n
            fi
        fi
    fi

    # extra warning for redis not being installed locally
    if [[ $REDIS_INSTALLED == false ]]; then
        output " Learning Locker requires Redis to be installed. As this isn't available on this server you'll need to"
        output "     change the variables in ${LOCAL_PATH}/.env to point to a redis server. The variables you'll need to" false true
        output "     change are 'REDIS_HOST', 'REDIS_PORT', 'REDIS_DB' and possibly 'REDIS_PREFIX'" false true
        echo
        if [[ $OS_SUBVER == "Amazon" ]]; then
            output "As you're running on AWS then you can use 'ElastiCache' to get a Redis instance set up quickly. We can't install"
            output "     Redis on AWS EC2 instances at the moment as there are no official repositories for a copy of Redis. If you want" false true
            output "     to install Redis on this server then we'd recommend you grab the latest version from:" false true
            output "         https://redis.io/download" false true
            output "     and follow the install steps on this page" false true
            echo
        fi
        output "Press any key to continue" false true
        read -n 1 n
        echo
    elif [[ $REDIS_INSTALL == false ]]; then
        # only hit this bit if redis was installed already
        output "Redis appears to have already been installed on this server. By default, Redis doesn't have a huge amount"
        output "     of security enabled and as such, the default Learning Locker config is set up to use the local copy of Redis" false true
        output "     with the default lack of credentials. If you want to secure Redis more or want to connect to a different" false true
        output "     Redis server then you'll need to edit the redis variables:" false true
        output "         'REDIS_HOST', 'REDIS_PORT', 'REDIS_DB' and maybe'REDIS_PREFIX'" false true
        output "     in ${LOCAL_PATH}/.env" false true
        echo
        output "Press any key to continue" false true
        read -n 1 n
        echo
    fi

    # extra warning for mongodb
    if [[ $MONGO_INSTALLED == false ]]; then
        output "Learning Locker requires MongoDB to be installed. As this isn't installed locally on this server you'll"
        output "     need to change the variable in ${LOCAL_PATH}/.env to point to a MongoDB Server. The variable you'll" false true
        output "     have to change is 'MONGODB_PATH'" false true
        echo
        output "Press any key to continue" false true
        read -n 1 n
        echo
    elif [[ $MONGO_INSTALL == false ]]; then
        # only hit this bit if mongo was installed already
        output "MongoDB appears to have already been installed on this server. By default, MongoDB doesn't have a huge amount"
        output "     of security enabled and as such, the default Learning Locker config is set up to use the local copy of MongoDB" false true
        output "     with the default lack of credentials. If you want to secure MongoDB more or want to connect to a different" false true
        output "     MongoDB server then you'll need to edit the 'MONGODB_PATH' variable in ${LOCAL_PATH}/.env" false true
        echo
        output "Press any key to continue" false true
        read -n 1 n
        echo
    fi


    # set up the pid & log directories
    PID_PATH=/var/run
    chown -R ${LOCAL_USER}:${LOCAL_USER} $LOG_PATH


    output_log "reprocessing $TMPDIR/all.json"
    reprocess_pm2 $TMPDIR/all.json $SYMLINK_PATH $LOG_PATH $PID_PATH
    output_log "reprocessing $TMPDIR/xapi/xapi.json"
    reprocess_pm2 $TMPDIR/xapi/xapi.json ${SYMLINK_PATH}/xapi $LOG_PATH $PID_PATH


    mkdir -p $LOCAL_PATH
    cp -R $TMPDIR/* $LOCAL_PATH/
    # above line doesn't copy the .env so have to do this manually
    cp $TMPDIR/.env $LOCAL_PATH/.env
    cp -R $TMPDIR/.git $LOCAL_PATH/
    chown $LOCAL_USER:$LOCAL_USER $LOCAL_PATH -R

    # set up symlink
    if [[ -f $SYMLINK_PATH ]]; then
        output_log "un-linking symlink of $SYMLINK_PATH"
        unlink $SYMLINK_PATH
    fi
    output_log "creating symlink : $LOCAL_PATH $SYMLINK_PATH"
    ln -s $LOCAL_PATH $SYMLINK_PATH


    # set up init script and run any reprocessing we need
    output_log "setting up init script. Path: $LOCAL_PATH user: $LOCAL_USER"
    setup_init_script $LOCAL_PATH $LOCAL_USER

    service pm2-${LOCAL_USER} start

    if [ $MONGO_INSTALLED == true ] && [ $REDIS_INSTALLED == true ]; then
        RUN_INSTALL_CMD=false
        echo "[LL] do you want to set up the organisation now to complete the installation ? [y|n] (press enter for the default of 'y')"
        while true; do
            read -r -s -n 1 n
            if [[ $n == "" ]]; then
                n="y"
            fi
            if [[ $n == "y" ]]; then
                while true; do
                    echo "[LL] please enter the organisation name"
                    read e
                    if [[ $e != "" ]]; then
                        INSTALL_ORG=$e
                        break
                    fi
                done
                while true; do
                    echo "[LL] please enter the email address for the administrator account"
                    read e
                    if [[ $e != "" ]]; then
                        INSTALL_EMAIL=$e
                        break
                    fi
                done
                while true; do
                    while true; do
                        echo "[LL] please enter the password for the administrator account"
                        read -r -s e
                        if [[ $e != "" ]]; then
                            INSTALL_PASSWD=$e
                            break
                        fi
                    done
                    while true; do
                        echo "[LL] please confirm the password for the administrator account"
                        read -r -s e
                        if [[ $e != "" ]]; then
                            if [[ $e == $INSTALL_PASSWD ]]; then
                                break 2
                            else
                                echo "[LL] Sorry, passwords don't match. Please try again."
                                sleep 1
                                break
                            fi
                        fi
                    done
                done
                while true; do
                    echo
                    echo "[LL] Is the following information correct ?"
                    echo "     Organisation  : $INSTALL_ORG"
                    echo "     Email address : $INSTALL_EMAIL"
                    echo "[y|n]"
                    read -r -s -n 1 e
                    if [[ $e == "y" ]]; then
                        break;
                    elif [[ $e == "n" ]]; then
                        continue 2
                    fi
                done

                RUN_INSTALL_CMD=true
                break;
            elif [[ $n == "n" ]]; then
                break;
            fi
        done

        if [[ $RUN_INSTALL_CMD == true ]]; then
            d=`pwd`
            cd $LOCAL_PATH
            node cli/dist/server createSiteAdmin $INSTALL_EMAIL $INSTALL_ORG $INSTALL_PASSWD
            cd $d
        fi

    else
        echo
        if [[ $MONGO_INSTALLED == true ]]; then
            echo "[LL] Mongo: Installed"
        else
            echo "[LL] Mongo: Not Installed"
        fi
        if [[ $REDIS_INSTALLED == true ]]; then
            echo "[LL] Redis: Installed"
        else
            echo "[LL] Redis: Not Installed"
        fi
        echo
        echo "[LL] Everything is installed but either mongoDB and/or Redis are missing from the local installation. Please edit the .env file"
        echo "     in $LOCAL_PATH to point to your relevant servers then run this command:"
        echo "         cd ${LOCAL_PATH}; node cli/dist/server createSiteAdmin {your.email@address.com} {organisationName} {yourPassword}"
        echo
    fi

elif [[ $LOCAL_INSTALL == true ]] && [[ $UPDATE_MODE == true ]]; then
    #################################################################################
    #                         UPGRADE FROM EXISTING INSTALL                         #
    #################################################################################

    if [[ -d $LOCAL_PATH ]]; then
        output "the release directory in $LOCAL_PATH already exists - creating a new directory"
        i=0
        POSSIBLE_PATH=$LOCAL_PATH
        while true; do
            i=$((i + 1))
            POSSIBLE_PATH=${LOCAL_PATH}_${i}
            if [[ ! -d $POSSIBLE_PATH ]]; then
                LOCAL_PATH=$POSSIBLE_PATH
                output "Created release directory: $LOCAL_PATH"
                break
            fi
            if [[ $i -gt 20 ]]; then
                output "more than 20 installs today - this looks like something has gone wrong, exiting"
                exit 0
            fi
        done
    fi

    # copy to correct local dir
    mkdir -p $LOCAL_PATH
    cp -R $TMPDIR/* $LOCAL_PATH/

    # copy the .env from the existing install over to the new path
    output "Copying existing config to new version"
    cp ${SYMLINK_PATH}/.env ${LOCAL_PATH}/.env
    cp ${SYMLINK_PATH}/xapi/.env ${LOCAL_PATH}/xapi/.env

    # copy the existing .git over
    if [[ -d ${SYMLINK_PATH}/.git ]]; then
        cp -R ${SYMLINK_PATH}/.git ${LOCAL_PATH}/
    fi

    # copy the pm2 files from existing install over
    cp ${SYMLINK_PATH}/all.json ${LOCAL_PATH}/all.json
    cp ${SYMLINK_PATH}/xapi/xapi.json ${LOCAL_PATH}/xapi/xapi.json

    # copy anything in the storage dirs over
    output "Copying user uploaded data in storage/ folders to new install....." true
    cp -nR ${SYMLINK_PATH}/storage/* ${LOCAL_PATH}/storage/
    if [[ ! -d ${LOCAL_PATH}/xapi/storage ]]; then
        mkdir -p ${LOCAL_PATH}/xapi/storage
    fi
    cp -nR ${SYMLINK_PATH}/xapi/storage/* ${LOCAL_PATH}/xapi/storage/
    output "done!" false true

    # prompt user that we're about to do the swap over
    UPDATE_RESTART=false
    UPDATE_RELOAD=false
    echo "[LL] As we're upgrading, we need to do a few bits of switching over. This carries a risk of downtime so you have two options now"
    echo "     you can select a reload (r) or a complete restart (c). A complete restart will stop running services before starting new ones"
    echo "     whereas a reload will attempt to reload with minimal downtime but runs more of a risk of not being totally clean. If you do"
    echo "     experience any strange effects you should be able to run:"
    echo "         'service pm2-${LOCAL_USER} restart'"
    echo "         'service nginx restart'"
    echo "     which'll cause the system to be completely restarted. [r|c] (Press enter for the default of 'c')"
    echo "     Please note: There's a risk of downtime from the moment you select an option"
    while true; do
        read -r -s -n 1 t
        #t=c
        if [[ $t == "" ]] || [[ $t == c ]]; then
            UPDATE_RESTART=true
            break
        elif [[ $t == "r" ]]; then
            UPDATE_RELOAD=true
            break
        fi
    done

    # complete restart
    if [[ $UPDATE_RESTART == true ]]; then
        PM2_PATH=`command -v pm2`

        echo "[LL] Ok, performing a complete restart"
        echo
        echo "[LL] Stopping nginx...."
        service nginx stop
        echo "[LL] Stopping pm2 processes...."
        service pm2-${LOCAL_USER} stop
        echo "[LL] re-symlinking directory...."
        unlink $SYMLINK_PATH
        ln -s $LOCAL_PATH $SYMLINK_PATH
        echo "[LL] starting PM2 processes...."
        su - ${LOCAL_USER} -c "cd ${LOCAL_PATH}; $PM2_PATH start all.json"
        su - ${LOCAL_USER} -c "cd ${LOCAL_PATH}/xapi; $PM2_PATH start xapi.json"
        su - ${LOCAL_USER} -c "$PM2_PATH save"
        service pm2-${LOCAL_USER} restart
        echo "[LL] PM2 processes restarted"
        echo "[LL] restarting nginx...."
        service nginx start
    fi

    # reload only
    if [[ $UPDATE_RELOAD == true ]]; then
        echo "[LL] Ok, reloading...."

        echo "[LL] re-symlinking directory...."
        unlink $SYMLINK_PATH
        ln -s $LOCAL_PATH $SYMLINK_PATH

        echo "[LL] reloading nginx"
        service nginx reload

        echo "[LL] reloading pm2"
        service pm2-${LOCAL_USER} reload

    fi


elif [[ $PACKAGE_INSTALL == true ]]; then
    #################################################################################
    #                                PACKAGE INSTALL                                #
    #################################################################################
    echo "[LL] Package install"



    # APT
    if [[ $OS_VERSION == "Debian" ]] || [[ $OS_VERSION == "Ubuntu" ]]; then
        apt_package $TMPDIR
    elif [[ $OS_VERSION == "Redhat" ]]; then
    # Yum
        yum_package $TMPDIR
    fi



else
    echo "[LL] Got to a point which should be impossible - not in a package or local install"
fi



#################################################################################
#                                    CLEANUP                                    #
#################################################################################
echo "[LL] cleaning up temp directories"
if [[ -d $TMPDIR ]]; then
    rm -R $TMPDIR
fi
if [[ -d ${BUILDDIR}/learninglocker_node ]]; then
    rm -R ${BUILDDIR}/learninglocker_node
fi
