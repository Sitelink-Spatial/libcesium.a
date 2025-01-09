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
        url: "https://github.com/Imajion/libcesium.a/releases/download/r4/libcesium.a.xcframework.zip",
        checksum: "fe71d9b42768419d4d195a2b3d04a2a8e5ec9327787f6e50b0538aa591a401ee"
    )

```