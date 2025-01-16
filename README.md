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
        url: "https://github.com/Imajion/libcesium.a/releases/download/r6/libcesium.a.xcframework.zip",
        checksum: "803f21dd59689c4e17d714e7243c81bd832c080ebf136366015e73bb729cd767"
    )

```
