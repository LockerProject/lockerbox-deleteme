#!/bin/bash

set -e

#### Config

NODE_DOWNLOAD='http://nodejs.org/dist/node-v0.4.11.tar.gz'
NPM_DOWNLOAD='http://npmjs.org/install.sh'
VIRTUALENV_DOWNLOAD='http://github.com/pypa/virtualenv/raw/develop/virtualenv.py'
MONGODB_DOWNLOAD='http://fastdl.mongodb.org/OS/mongodb-OS-ARCH-2.0.0.tgz'
CLUCENE_REPO='git://clucene.git.sourceforge.net/gitroot/clucene/clucene'

LOCKER_REPO=${LOCKER_REPO:-https://github.com/LockerProject/Locker.git}
LOCKER_BRANCH=${LOCKER_BRANCH:-master}

#### Helper functions

# check_for name exec_name version_command [minimum_version [optional]]
check_for() {
    found="$(which $2 || true)"
    version="$($3 2>&1 | grep -o -E [-0-9.]\{1,\} | head -n 1)"
    if [ -z "${found}" ]
    then
        echo "$1 not found!" >&2
    else
        echo "$1 version ${version} found."
        if [ -z "$4" ]
        then
            return
        fi
    fi

    if [ -n "$4" ]
    then
        if echo $version|grep -q -v -E [0-9]
        then
            result="False"
        else
            result=$(python -c "print tuple(int(x) for x in '$version'.split('.')) >= tuple(int(x) for x in '$4'.split('.'))")
        fi
        if [ "${result}" = "False" ]
        then
            echo "$1 version $4 or greater required!" >&2

            if [ -z "$5" ]
            then
                exit 1
            else
                return 1
            fi
        fi
    else
        exit 1
    fi
}

# check_for_pkg_config name pkg_config_name [minimum_version [optional]]
check_for_pkg_config() {
    if ! which pkg-config >/dev/null 2>&1; then
        echo "pkg-config is not installed: assuming $1 is not present"
        return 1
    fi

    if ! pkg-config --exists "$2"
    then
        echo "$1 not found!" >&2
        return 1
    fi
    version="$(pkg-config --modversion "$2")"
    echo "$1 version ${version} found."

    [ -z "$3" ] && return 0
    if pkg-config --atleast-version="$3" "$2"
    then
        return 0
    else
        echo "$1 version $3 or greater required!" >&2
        [ -z "$4" ] && exit 1 || return 1
    fi
}

download () {
    base="$(basename $1)"
    if [ -f ${base} ]
    then
        echo "$1 already downloaded."
    else
        if wget "$1" 2>/dev/null || curl -L -o ${base} "$1"
        then
            echo "Downloaded $1."
        else
            echo "Download of $1 failed!" >&2
            exit 1
        fi
    fi
}

#### Main script
THIS="$(basename $0)"

BASEDIR="$(pwd)"
if [[ ${BASEDIR} != */lockerbox ]]
then
    BASEDIR="${BASEDIR}/lockerbox"
    mkdir -p "${BASEDIR}"
    cd "${BASEDIR}"
fi

envscript="${BASEDIR}/lockerbox_environment.sh"
cat >> "$envscript" <<"EOF"
export PATH="${BASEDIR}/local/bin":${PATH}
export NODE_PATH="${BASEDIR}/local/lib/node_modules":${NODE_PATH}
export PKG_CONFIG_PATH="${BASEDIR}/local/lib/pkgconfig":${PKG_CONFIG_PATH}
export CXXFLAGS="-I${BASEDIR}/local/include"
export LD_LIBRARY_PATH="${BASEDIR}/local/lib"
export LIBRARY_PATH="${BASEDIR}/local/lib"
EOF

. "$envscript"

check_for Git git 'git --version'
check_for Python python 'python -V' 2.6
check_for cmake cmake 'cmake --version'

mkdir -p local/build
cd local/build

if ! check_for Node.js node 'node -v' 0.4.8 optional
then
    echo ""
    echo "You don't seem to have node.js installed."
    echo "I will download, build, and install it locally."
    echo -n "This could take quite some time!"
    sleep 1 ; printf "." ; sleep 1 ; printf "." ; sleep 1 ; printf "." ; sleep 1
    download "${NODE_DOWNLOAD}"
    if tar zxf "$(basename "${NODE_DOWNLOAD}")" &&
        cd $(basename "${NODE_DOWNLOAD}" .tar.gz) &&
        ./configure --prefix="${BASEDIR}/local" &&
        make &&
        make install
    then
        echo "Installed node.js into ${BASEDIR}"
    else
        echo "Failed to install node.js into ${BASEDIR}" >&2
        exit 1
    fi
fi

cd "${BASEDIR}/local/build"
if ! check_for npm npm "npm -v" 1 optional
then
    echo ""
    echo "About to download and install locally npm."
    download "${NPM_DOWNLOAD}"
    if cat "$(basename ${NPM_DOWNLOAD})" | clean=no sh
    then
        echo "Installed npm into ${BASEDIR}"
    else
        echo "Failed to install npm into ${BASEDIR}" >&2
        exit 1
    fi
fi

if [ ! -e "${BASEDIR}/local/bin/activate" ]
then
    if ! check_for virtualenv virtualenv "virtualenv --version" 1.4 optional
    then
        echo ""
        echo "About to download virtualenv.py."
        download "${VIRTUALENV_DOWNLOAD}"
    fi

    if python -m virtualenv --no-site-packages "${BASEDIR}/local"
    then
        echo "Set up virtual Python environment."
    else
        echo "Failed to set up virtual Python environment." >&2
        exit 1
    fi
fi

if . "${BASEDIR}/local/bin/activate"
then
    echo "Activated virtual Python environment."
else
    echo "Failed to activate virtual Python environment." >&2
fi

if ! check_for mongoDB mongod "mongod --version" 1.4.0
then
    OS=`uname -s`
    case "${OS}" in
        Linux)
            OS=linux
            ;;
        Darwin)
            OS=osx
            ;;
        *)
            echo "Don't recognize OS ${OS}" >&2
            exit 1
    esac
    BITS=`getconf LONG_BIT`
    ARCH='x86_64'
    if [ "${BITS}" -ne 64 ]
    then
        ARCH="i386"
        if [ "${OS}" != "osx" ]
        then
            ARCH="i686"
        fi
    fi
    echo ""
    echo "Downloading and installing locally mongoDB"
    MONGODB_DOWNLOAD=$(echo ${MONGODB_DOWNLOAD} | sed -e "s/OS/${OS}/g" -e "s/ARCH/${ARCH}/g")
    download "${MONGODB_DOWNLOAD}"
    if tar zxf $(basename "${MONGODB_DOWNLOAD}") &&
        cp $(basename "${MONGODB_DOWNLOAD}" .tgz)/bin/* "${BASEDIR}/local/bin"
    then
        echo "Installed local mongoDB."
    else
        echo "Failed to install local mongoDB." >&2
        exit 1
    fi
fi

if ! check_for_pkg_config CLucene libclucene-core 2.3.3.4 optional
then
    echo ""
    echo "About to download, build, and install locally CLucene."
    echo -n "This could take a while."
    sleep 1 ; printf "." ; sleep 1 ; printf "." ; sleep 1 ; printf "." ; sleep 1
    cd "${BASEDIR}/local/build"
    base="$(basename "${CLUCENE_REPO}")"
    if [ -d "${base}" ]
    then
        echo "${CLUCENE_REPO} already downloaded."
    else
        if git clone "${CLUCENE_REPO}"
        then
            echo "Downloaded ${CLUCENE_REPO}."
        else
            echo "Download of ${CLUCENE_REPO} failed!" >&2
            exit 1
        fi
    fi
    if mkdir -p "${base}/build" && cd "${base}/build" &&
        cmake -D CMAKE_INSTALL_PREFIX:PATH="${BASEDIR}/local" -G "Unix Makefiles" .. &&
        make &&
        make install
    then
        echo "Installed CLucene into ${BASEDIR}"
    else
        echo "Failed to install CLucene into ${BASEDIR}" >&2
        exit 1
    fi
fi

cd "${BASEDIR}"

if [ ! -d Locker/.git ]
then
    echo "Checking out Locker repo."
    if git clone "${LOCKER_REPO}" -b "${LOCKER_BRANCH}"
    then
        echo "Checked out Locker repo."
    else
        echo "Failed to check out Locker repo." >&2
        exit 1
    fi
fi

cd Locker
echo "Checking out submodules"
git submodule update --init

npm install

echo "Installing Python modules"
if ! python setupEnv.py; then
    echo "Failed to install Python modules" >&2
    exit 1
fi

echo "One final check to see if everything is as it should be..."
if ! ./checkEnv.sh; then
    echo "Installation appeared to succeed, but dependency check failed :-/" >&2
    exit 1
fi

echo "Looks like everything worked."

# This won't work until we have API keys -mdz 2011-12-01
# node lockerd.js
