#!/bin/bash

set -e

#### Config

NODE_DOWNLOAD='http://nodejs.org/dist/v0.6.10/node-v0.6.10.tar.gz'
NPM_DOWNLOAD='http://npmjs.org/install.sh'
VIRTUALENV_DOWNLOAD='http://github.com/pypa/virtualenv/raw/develop/virtualenv.py'
MONGODB_DOWNLOAD='http://fastdl.mongodb.org/OS/mongodb-OS-ARCH-2.0.0.tgz'

LOCKER_REPO=${LOCKER_REPO:-https://github.com/LockerProject/Locker.git}
LOCKER_BRANCH=${LOCKER_BRANCH:-master}

#### Helper functions

# check_for name exec_name version_command [minimum_version]
check_for() {
    name="$1"
    command="$2"
    get_version="$3"
    min_version="$4"
    max_version="$5"

    if which $command >/dev/null 2>&1; then
        # It's installed
        version=$($get_version 2>&1 | grep -o -E [-0-9.]\{1,\} | head -n 1)
        echo "$name version $version found."

        if [ -n "$min_version" ]; then
            if ! perl -e 'exit 1 unless v'$version' ge v'$min_version
            then
                echo "$1 version $version found (>=$min_version required)"
                return 1
            fi

            if [ -n "$max_version" ]; then
                if ! perl -e 'exit 1 unless v'$version' lt v'$max_version
                then
                    echo "$1 version $version found (<$max_version required)"
                    return 1
                fi
            fi
        fi

        return 0
    fi

    return 1
}

# check_for_pkg_config name pkg_config_name [minimum_version [optional]]
check_for_pkg_config() {
    name="$1"
    pkg_config_name="$2"
    min_version="$3"

    if ! which pkg-config >/dev/null 2>&1; then
        echo "pkg-config is not installed: assuming $name is not present either"
        return 1
    fi

    if ! pkg-config --exists "$pkg_config_name"
    then
        echo "$name not found!" >&2
        return 1
    fi
    version="$(pkg-config --modversion "$pkg_config_name")"
    echo "${name} version ${version} found."

    [ -z "$min_version" ] && return 0
    if pkg-config --atleast-version="$min_version" "$pkg_config_name"
    then
        return 0
    else
        echo "$name version $min_version or greater required!" >&2
        return 1
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

BASEDIR="$(pwd)/lockerbox"
mkdir -p "${BASEDIR}"
cd "${BASEDIR}"

envscript="${BASEDIR}/lockerbox_environment.sh"
cat > "${envscript}" <<MRBARGLES
export PATH="${BASEDIR}/local/bin":${PATH}
export NODE_PATH="${BASEDIR}/local/lib/node_modules":${NODE_PATH}
export PKG_CONFIG_PATH="${BASEDIR}/local/lib/pkgconfig":${PKG_CONFIG_PATH}
export CXXFLAGS="-I${BASEDIR}/local/include"
export LD_LIBRARY_PATH="${BASEDIR}/local/lib"
export LIBRARY_PATH="${BASEDIR}/local/lib"
MRBARGLES

. "${envscript}"

check_for Git git 'git --version'
check_for Python python 'python -V' 2.6

mkdir -p local/build
cd local/build

if ! check_for Node.js node 'node -v' 0.6.0
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
if ! check_for npm npm "npm -v" 1
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
    if ! check_for virtualenv virtualenv "virtualenv --version" 1.4
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

if ! check_for mongoDB mongod "mongod --version" 1.8.0
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
make build
cp Config/config.json.example Config/config.json

echo "Installing Python modules"
if ! python setupEnv.py; then
    echo "Failed to install Python modules" >&2
    exit 1
fi

# Install a script to launch locker
bindir="${BASEDIR}/local/bin"
mkdir -p "$bindir"
lockerbin="$bindir/locker"
cat > "$lockerbin" <<EOF
#!/bin/sh

cd "${BASEDIR}/Locker"
exec ./locker
EOF
chmod 755 "$lockerbin"

echo
echo "One final check to see if everything is as it should be..."
if ! ./checkEnv.sh; then
    echo "Installation appeared to succeed, but dependency check failed :-/" >&2
    exit 1
fi

echo
echo "Looks like everything worked!"
echo "Get some API keys (https://github.com/LockerProject/Locker/wiki/GettingAPIKeys) and then try running:"
echo "PATH=`pwd`/lockerbox/local/bin:$PATH && cd lockerbox/Locker && ./locker"
echo " "
echo "Once running, visit http://localhost:8042 in your web browser."

# This won't work until we have API keys -mdz 2011-12-01
# node lockerd.js
