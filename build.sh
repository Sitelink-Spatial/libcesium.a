#!/bin/bash

# Examples:
#
#   Build for desktop
#   > ./build.sh build release arm64-apple-macosx
#
#   Build for iphone
#   > ./build.sh build release arm64-apple-ios14.0
#
#   Build for iphone
#   > ./build.sh build release x86_64-apple-ios14.0-simulator

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

# Build target, i.e. arm64-apple-macosx, aarch64-apple-ios14.0, x86_64-apple-ios14.0-simulator, ...
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
    BUILDTARGET="arm64-apple-macosx"
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
PKGROOT="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}"
PKGFILE="${BUILDOUT}/pkg/${BUILDTYPE}/${PKGNAME}.zip"

# iOS toolchain
if [[ $BUILDTARGET == *"ios"* ]]; then

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
               -DCMAKE_CXX_STANDARD=17 \
               -DDEPLOYMENT_TARGET=\"14.0\" \
               "
                    # -DCMAKE_OSX_SYSROOT_INT=14 \

fi


#--------------------------------------------------------------------
echo ""
Log "#--------------------------------------------------------------------"
Log "LIBNAME        : ${LIBNAME}"
Log "BUILDWHAT      : ${BUILDWHAT}"
Log "BUILDTYPE      : ${BUILDTYPE}"
Log "BUILDTARGET    : ${BUILDTARGET}"
Log "ROOTDIR        : ${ROOTDIR}"
Log "BUILDOUT       : ${BUILDOUT}"
Log "TARGET         : ${TARGET}"
Log "PLATFORM       : ${TGT_PLATFORM}"
Log "PKGNAME        : ${PKGNAME}"
Log "PKGROOT        : ${PKGROOT}"
Log "LIBROOT        : ${LIBROOT}"
Log "#--------------------------------------------------------------------"
echo ""

#-------------------------------------------------------------------
# Rebuild lib and copy files if needed
#-------------------------------------------------------------------
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
   || [ ! -f "${LIBINSTFULL}/lib/libCesium3DTiles.a" ]; then

    # rm -Rf "$LIBBUILD" "${PKGROOT}/${TARGET}"
    gitCheckout "https://github.com/CesiumGS/cesium-native.git" "v0.25.1" "${LIBBUILD}"

    Log "Building ${LIBNAME}"

    cd "${LIBBUILD}"

    echo "\n====================== CONFIGURING =====================\n"
    cmake . -B ./build -DCMAKE_BUILD_TYPE=${BUILDTYPE} \
                    ${TOOLCHAIN} \
                    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
                    -DCMAKE_INSTALL_PREFIX="${LIBINSTFULL}"


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

        mkdir -p "${LIBINSTFULL}/include"
        cp -R "${LIBROOT}/${LIBNAME}/include/." "${LIBINSTFULL}/include/"

        mkdir -p "${LIBINSTFULL}/lib"
        cp -R "${LIBBUILDOUT}/lib/Release/." "${LIBINSTFULL}/lib/"

    else
        echo "\n======================= BUILDING =======================\n"
        cmake --build ./build -j$NUMCPUS

        echo "\n====================== INSTALLING ======================\n"
        cmake --install ./build
    fi

    cd "${BUILDOUT}"
fi

#-------------------------------------------------------------------
# Create target package
#-------------------------------------------------------------------
if    [ ! -z "${REBUILDLIBS}" ] \
   || [ ! -f "${PKGROOT}/${TARGET}" ]; then

    INCPATH="include"
    LIBPATH="${LIBNAME}.a"

    # Re initialize directory
    if [ -d "${PKGROOT}/${TARGET}" ]; then
        rm -Rf "${PKGROOT}/${TARGET}"
    fi
    mkdir -p "${PKGROOT}/${TARGET}"

    # Copy include files
    cp -R "${LIBINSTFULL}/." "${PKGROOT}/${TARGET}/"

    # Combine libs
    Log "Runnning libtool..."
    LIBSRC="\
            ${LIBINSTFULL}/lib/libasync++.a \
            ${LIBINSTFULL}/lib/libCesium3DTiles.a \
            ${LIBINSTFULL}/lib/libCesium3DTilesReader.a \
            ${LIBINSTFULL}/lib/libCesium3DTilesSelection.a \
            ${LIBINSTFULL}/lib/libCesium3DTilesWriter.a \
            ${LIBINSTFULL}/lib/libCesiumAsync.a \
            ${LIBINSTFULL}/lib/libCesiumGeometry.a \
            ${LIBINSTFULL}/lib/libCesiumGeospatial.a \
            ${LIBINSTFULL}/lib/libCesiumGltf.a \
            ${LIBINSTFULL}/lib/libCesiumGltfReader.a \
            ${LIBINSTFULL}/lib/libCesiumGltfWriter.a \
            ${LIBINSTFULL}/lib/libCesiumIonClient.a \
            ${LIBINSTFULL}/lib/libCesiumJsonReader.a \
            ${LIBINSTFULL}/lib/libCesiumJsonWriter.a \
            ${LIBINSTFULL}/lib/libCesiumUtility.a \
            ${LIBINSTFULL}/lib/libcsprng.a \
            ${LIBINSTFULL}/lib/libdraco.a \
            ${LIBINSTFULL}/lib/libktx_read.a \
            ${LIBINSTFULL}/lib/libmodp_b64.a \
            ${LIBINSTFULL}/lib/libs2geometry.a \
            ${LIBINSTFULL}/lib/libspdlog.a \
            ${LIBINSTFULL}/lib/libsqlite3.a \
            ${LIBINSTFULL}/lib/libtinyxml2.a \
            ${LIBINSTFULL}/lib/libturbojpeg.a \
            ${LIBINSTFULL}/lib/liburiparser.a \
            ${LIBINSTFULL}/lib/libwebpdecoder.a \
            ${LIBINSTFULL}/lib/libz.a \
            "

    ls -l ${LIBSRC}
    libtool -static -o "${PKGROOT}/${TARGET}/${LIBNAME}.a" ${LIBSRC}

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
        # touch "${PKGFILE}"

        # Calculate sha256
        openssl dgst -sha256 < "${PKGFILE}" > "${PKGFILE}.sha256.txt"

        cd "${BUILDOUT}"

    fi
fi
