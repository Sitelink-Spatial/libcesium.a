#!/bin/bash

# Examples:
#
#   Build for desktop
#   > ./build.sh build release arm64-apple-macos13.0
#
#   Build for iphone
#   > ./build.sh build release arm64-apple-ios12.0
#
#   Build for iphone
#   > ./build.sh build release x86_64-apple-ios12.0-simulator

# Package layout
#
# ├── Info.plist
# ├── [ios-arm64]
# │     ├── mylib.a
# │     └── [include]
# ├── [ios-arm64_x86_64-simulator]
# │     ├── mylib.a
# │     └── [include]
# └── [macos-arm64_x86_64]
#       ├── mylib.a
#       └── [include]


#--------------------------------------------------------------------
# Script params

LIBNAME="libcesium"

# What to do (build, test)
BUILDWHAT="$1"

# Build type (release, debug)
BUILDTYPE="$2"

# Build target, i.e. arm64-apple-macos13.0, aarch64-apple-ios12.0, x86_64-apple-ios12.0-simulator, ...
BUILDTARGET="$3"

# Build Output
BUILDOUT="$4"

#--------------------------------------------------------------------
# Functions

Log()
{
    echo ">>>>>> $@"
}

exitWithError()
{
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "$@"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit -1
}

exitOnError()
{
    if [[ 0 -eq $? ]]; then return 0; fi
    exitWithError $@
}

gitCheckout()
{
    local LIBGIT="$1"
    local LIBGITVER="$2"
    local LIBBUILD="$3"

    # Check out c++ library if needed
    if [ ! -d "${LIBBUILD}" ]; then
        Log "Checking out: ${LIBGIT} -> ${LIBGITVER}"
        if [ ! -z "${LIBGITVER}" ]; then
            git clone  --recurse-submodules --depth 1 -b ${LIBGITVER} ${LIBGIT} ${LIBBUILD}
        else
            git clone  --recurse-submodules ${LIBGIT} ${LIBBUILD}
        fi
    fi

    if [ ! -d "${LIBBUILD}" ]; then
        exitWithError "Failed to checkout $LIBGIT"
    fi
}

extractVersion()
{
    local tuple="$1"
    local key="$2"
    local version=""

    IFS='-' read -ra components <<< "$tuple"
    for component in "${components[@]}"; do
        if [[ $component == ${key}* ]]; then
        version="${component#$key}"
        break
        fi
    done

    echo "$version"
}


#--------------------------------------------------------------------
# Options

# Sync command
SYNC="rsync -a"

# Default build what
if [ -z "${BUILDWHAT}" ]; then
    BUILDWHAT="build"
fi

# Default build type
if [ -z "${BUILDTYPE}" ]; then
    BUILDTYPE="release"
fi

if [ -z "${BUILDTARGET}" ]; then
    BUILDTARGET="arm64-apple-macos"
fi

# ios-arm64_x86_64-simulator
if [[ $BUILDTARGET == *"ios"* ]]; then
    TGT_OS="ios"
else
    TGT_OS="macos"
fi

if [[ $BUILDTARGET == *"arm64"* ]]; then
    if [[ $BUILDTARGET == *"x86_64"* ]]; then
        TGT_ARCH="arm64_x86_64"
    elif [[ $BUILDTARGET == *"x86"* ]]; then
        TGT_ARCH="arm64_x86"
    else
        TGT_ARCH="arm64"
    fi
elif [[ $BUILDTARGET == *"x86_64"* ]]; then
    TGT_ARCH="x86_64"
elif [[ $BUILDTARGET == *"x86"* ]]; then
    TGT_ARCH="x86"
else
    exitWithError "Invalid architecture : $BUILDTARGET"
fi

TGT_OPTS=
if [[ $BUILDTARGET == *"simulator"* ]]; then
    TGT_OPTS="-simulator"
fi

# NUMCPUS=1
NUMCPUS=$(sysctl -n hw.physicalcpu)

#--------------------------------------------------------------------
# Get root script path
SCRIPTPATH=$(realpath $0)
if [ ! -z "$SCRIPTPATH" ]; then
    ROOTDIR=$(dirname $SCRIPTPATH)
else
    SCRIPTPATH=.
    ROOTDIR=.
fi

#--------------------------------------------------------------------
# Defaults

if [ -z $BUILDOUT ]; then
    BUILDOUT="${ROOTDIR}/build"
else
    # Get path to current directory if needed to use as custom directory
    if [ "$BUILDOUT" == "." ] || [ "$BUILDOUT" == "./" ]; then
        BUILDOUT="$(pwd)"
    fi
fi

# Add build type to output folder
BUILDOUT="${BUILDOUT}/${BUILDTYPE}"

# Make custom output directory if it doesn't exist
if [ ! -z "$BUILDOUT" ] && [ ! -d "$BUILDOUT" ]; then
    mkdir -p "$BUILDOUT"
fi

if [ ! -d "$BUILDOUT" ]; then
    exitWithError "Failed to create diretory : $BUILDOUT"
fi

TARGET="${TGT_OS}-${TGT_ARCH}${TGT_OPTS}"

LIBROOT="${BUILDOUT}/${BUILDTARGET}/lib3"
LIBINST="${BUILDOUT}/${BUILDTARGET}/install"

PKGNAME="${LIBNAME}.a.xcframework"
PKGROOT="${BUILDOUT}/pkg/${PKGNAME}"
PKGFILE="${BUILDOUT}/pkg/${PKGNAME}.zip"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then

    TGT_OSVER=$(extractVersion "$BUILDTARGET" "ios")
    if [ -z "$TGT_OSVER" ]; then
        TGT_OSVER="14.0"
    fi

    gitCheckout "https://github.com/leetal/ios-cmake.git" "4.3.0" "${LIBROOT}/ios-cmake"

    if [[ $BUILDWHAT == *"xbuild"* ]]; then
        TOOLCHAIN="${TOOLCHAIN} -GXcode"
    fi

    # https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake
    if [[ $BUILDTARGET == *"simulator"* ]]; then
        if [ "${TGT_ARCH}" == "x86" ]; then
            TGT_PLATFORM="SIMULATOR"
        elif [ "${TGT_ARCH}" == "x86_64" ]; then
            TGT_PLATFORM="SIMULATOR64"
        else
            TGT_PLATFORM="SIMULATORARM64"
        fi
    else
        if [ "${TGT_ARCH}" == "x86" ]; then
            TGT_PLATFORM="OS"
        elif [ "${TGT_ARCH}" == "x86_64" ]; then
            TGT_ARCH="arm64_x86_64"
            TGT_PLATFORM="OS64COMBINED"
        else
            TGT_PLATFORM="OS64"
        fi
    fi

    TARGET="${TGT_OS}-${TGT_ARCH}${TGT_OPTS}"
    TOOLCHAIN="${TOOLCHAIN} \
               -DCMAKE_TOOLCHAIN_FILE=${LIBROOT}/ios-cmake/ios.toolchain.cmake \
               -DPLATFORM=${TGT_PLATFORM} \
               -DENABLE_BITCODE=OFF \
               -DDEPLOYMENT_TARGET=$TGT_OSVER \
               "
else
    TGT_OSVER=$(extractVersion "$BUILDTARGET" "macos")
    if [ -z "$TGT_OSVER" ]; then
        TGT_OSVER="13.2"
    fi

    TOOLCHAIN="${TOOLCHAIN} \
               -DCMAKE_OSX_DEPLOYMENT_TARGET=$TGT_OSVER \
               -DCMAKE_OSX_ARCHITECTURES=$TGT_ARCH
               "
fi

TOOLCHAIN="${TOOLCHAIN} \
            -DCMAKE_CXX_STANDARD=17 \
            "


#--------------------------------------------------------------------
showParams()
{
    echo ""
    Log "#--------------------------------------------------------------------"
    Log "LIBNAME        : ${LIBNAME}"
    Log "BUILDWHAT      : ${BUILDWHAT}"
    Log "BUILDTYPE      : ${BUILDTYPE}"
    Log "BUILDTARGET    : ${BUILDTARGET}"
    Log "ROOTDIR        : ${ROOTDIR}"
    Log "BUILDOUT       : ${BUILDOUT}"
    Log "TARGET         : ${TARGET}"
    Log "OSVER          : ${TGT_OSVER}"
    Log "ARCH           : ${TGT_ARCH}"
    Log "PLATFORM       : ${TGT_PLATFORM}"
    Log "PKGNAME        : ${PKGNAME}"
    Log "PKGROOT        : ${PKGROOT}"
    Log "LIBROOT        : ${LIBROOT}"
    Log "#--------------------------------------------------------------------"
    echo ""
}
showParams

#-------------------------------------------------------------------
# Rebuild lib and copy files if needed
#-------------------------------------------------------------------
if [[ $BUILDWHAT == *"clean"* ]]; then
    if [ -d "${LIBROOT}" ]; then
        rm -Rf "${LIBROOT}"
    fi
fi

if [ ! -d "${LIBROOT}" ]; then

    Log "Reinitializing install..."

    mkdir -p "${LIBROOT}"

    REBUILDLIBS="YES"
fi


LIBBUILD="${LIBROOT}/${LIBNAME}"
LIBBUILDOUT="${LIBBUILD}/build"
LIBINSTFULL="${LIBINST}/${BUILDTARGET}/${BUILDTYPE}"

#-------------------------------------------------------------------
# Checkout and build library
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [[ $BUILDWHAT == *"rebuild"* ]] \
   || [ ! -f "${LIBINSTFULL}/lib/libCesium3DTiles.a" ]; then

    # Remove existing package
    rm -Rf "${PKGROOT}/${TARGET}"

    # rm -Rf "$LIBBUILD" "${PKGROOT}/${TARGET}"
    gitCheckout "https://github.com/CesiumGS/cesium-native.git" "v0.25.1" "${LIBBUILD}"

    Log "Building ${LIBNAME}"

    cd "${LIBBUILD}"

    echo "\n====================== CONFIGURING =====================\n"
    cmake . -B ./build -DCMAKE_BUILD_TYPE=${BUILDTYPE} \
                    ${TOOLCHAIN} \
                    -DCESIUM_TESTS_ENABLED=OFF \
                    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
                    -DCMAKE_INSTALL_PREFIX="${LIBINSTFULL}"
    exitOnError "Failed to configure ${LIBNAME}"

    echo "\n======================= PATCHING =======================\n"

    sed -i '' "s|#ifdef HAVE_REALLOCARRAY|// +++ CHANGE\n#undef HAVE_REALLOCARRAY\n# ifdef HAVE_REALLOCARRAY|g" \
        "${LIBBUILD}/extern/uriparser/src/UriMemory.c"

    sed -i '' "s|libjpeg-turbo -DCMAKE_INSTALL_PREFIX=|libjpeg-turbo -DPLATFORM=$\{PLATFORM\} -DCMAKE_INSTALL_PREFIX=|g" \
        "${LIBBUILD}/extern/CMakeLists.txt"


    if [[ $BUILDWHAT == *"xbuild"* ]]; then

        echo "\n==================== XCODE BUILDING ====================\n"

        # Get targets: xcodebuild -list -project mylib.xcodeproj
        xcodebuild -project "${LIBBUILDOUT}/cesium.xcodeproj" \
                   -target cesium_static \
                   -configuration Release \
                   -sdk iphonesimulator
        exitOnError "Failed to xbuild ${LIBNAME}"

        mkdir -p "${LIBINSTFULL}/include"
        cp -R "${LIBROOT}/${LIBNAME}/include/." "${LIBINSTFULL}/include/"

        mkdir -p "${LIBINSTFULL}/lib"
        cp -R "${LIBBUILDOUT}/lib/Release/." "${LIBINSTFULL}/lib/"

    else
        echo "\n======================= BUILDING =======================\n"
        cmake --build ./build -j$NUMCPUS
        exitOnError "Failed to build ${LIBNAME}"

        echo "\n====================== INSTALLING ======================\n"
        cmake --install ./build
        exitOnError "Failed to install ${LIBNAME}"
    fi

    cd "${BUILDOUT}"
fi

#-------------------------------------------------------------------
# Create target package
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -d "${PKGROOT}/${TARGET}" ]; then

    INCPATH="include"
    LIBPATH="${LIBNAME}.a"

    # Re initialize directory
    if [ -d "${PKGROOT}/${TARGET}" ]; then
        rm -Rf "${PKGROOT}/${TARGET}"
    fi
    mkdir -p "${PKGROOT}/${TARGET}"

    # Copy include files
    cp -R "${LIBINSTFULL}/." "${PKGROOT}/${TARGET}/"

    # Library postfix
    PF=.a
    if [[ "debug" == "$BUILDTYPE" ]]; then
        PF=d.a
    fi

    # Combine libs
    Log "Runnning libtool..."
    LIBSRC="\
            ${LIBINSTFULL}/lib/libasync++$PF \
            ${LIBINSTFULL}/lib/libCesium3DTiles$PF \
            ${LIBINSTFULL}/lib/libCesium3DTilesReader$PF \
            ${LIBINSTFULL}/lib/libCesium3DTilesSelection$PF \
            ${LIBINSTFULL}/lib/libCesium3DTilesWriter$PF \
            ${LIBINSTFULL}/lib/libCesiumAsync$PF \
            ${LIBINSTFULL}/lib/libCesiumGeometry$PF \
            ${LIBINSTFULL}/lib/libCesiumGeospatial$PF \
            ${LIBINSTFULL}/lib/libCesiumGltf$PF \
            ${LIBINSTFULL}/lib/libCesiumGltfReader$PF \
            ${LIBINSTFULL}/lib/libCesiumGltfWriter$PF \
            ${LIBINSTFULL}/lib/libCesiumIonClient$PF \
            ${LIBINSTFULL}/lib/libCesiumJsonReader$PF \
            ${LIBINSTFULL}/lib/libCesiumJsonWriter$PF \
            ${LIBINSTFULL}/lib/libCesiumUtility$PF \
            ${LIBINSTFULL}/lib/libcsprng$PF \
            ${LIBINSTFULL}/lib/libdraco$PF \
            ${LIBINSTFULL}/lib/libktx_read$PF \
            ${LIBINSTFULL}/lib/libmodp_b64$PF \
            ${LIBINSTFULL}/lib/libs2geometry$PF \
            ${LIBINSTFULL}/lib/libspdlog$PF \
            ${LIBINSTFULL}/lib/libsqlite3$PF \
            ${LIBINSTFULL}/lib/libtinyxml2$PF \
            ${LIBINSTFULL}/lib/libturbojpeg$PF \
            ${LIBINSTFULL}/lib/liburiparser$PF \
            ${LIBINSTFULL}/lib/libwebpdecoder$PF \
            ${LIBINSTFULL}/lib/libz$PF \
           "

    ls -l ${LIBSRC}
    libtool -static -o "${PKGROOT}/${TARGET}/${LIBNAME}.a" ${LIBSRC}
    exitOnError "Failed to build library ${LIBNAME}"

    lipo -info "${PKGROOT}/${TARGET}/${LIBNAME}.a"

    INCPATH="include"
    LIBPATH="${LIBNAME}.a"

    # Copy manifest
    cp "${ROOTDIR}/Info.target.plist.in" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%TARGET%%|${TARGET}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%OS%%|${TGT_OS}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%ARCH%%|${TGT_ARCH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%INCPATH%%|${INCPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"
    sed -i '' "s|%%LIBPATH%%|${LIBPATH}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

    EXTRA=
    if [[ $BUILDTARGET == *"simulator"* ]]; then
        EXTRA="<key>SupportedPlatformVariant</key><string>simulator</string>"
    fi
    sed -i '' "s|%%EXTRA%%|${EXTRA}|g" "${PKGROOT}/${TARGET}/Info.target.plist"

fi


#-------------------------------------------------------------------
# Create full package
#-------------------------------------------------------------------
if [ -d "${PKGROOT}" ]; then

    cd "${PKGROOT}"

    TARGETINFO=
    for SUB in */; do
        echo "Adding: $SUB"
        if [ -f "${SUB}/Info.target.plist" ]; then
            TARGETINFO="$TARGETINFO$(cat "${SUB}/Info.target.plist")"
        fi
    done

    if [ ! -z "$TARGETINFO" ]; then

        TARGETINFO=""${TARGETINFO//$'\n'/\\n}""

        cp "${ROOTDIR}/Info.plist.in" "${PKGROOT}/Info.plist"
        sed -i '' "s|%%TARGETS%%|${TARGETINFO}|g" "${PKGROOT}/Info.plist"

        cd "${PKGROOT}/.."

        # Remove old package if any
        if [ -f "${PKGFILE}" ]; then
            rm "${PKGFILE}"
        fi

        # Create new package
        zip -r "${PKGFILE}" "$PKGNAME" -x "*.DS_Store"

        # Calculate sha256
        openssl dgst -sha256 < "${PKGFILE}" > "${PKGFILE}.sha256.txt"

        cd "${BUILDOUT}"

    fi
fi

showParams
