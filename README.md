# libcesium.a
iOS build for cesium-native

## Dependencies

    * xcode
    * brew install git


## Build

    ./build.sh build release arm64-apple-ios14.0

    or

    ./build-all.sh release


## Reference in Swift Module

``` swift

    .binaryTarget(
        name: "libcesium.a",
        url: "https://github.com/Imajion/libcesium.a/releases/download/r2/libcesium.a.xcframework.zip",
        checksum: "977cc7cb243d1ada6201cee742597298273159ed117ba714ddd42558fd264629"
    )

```