# libcesium.a
iOS build for cesium-native

## Dependencies

    * xcode
    * brew install git


## Build

    ./build.sh build release arm64-apple-ios14.0


## Reference in Swift Module

``` swift

    .binaryTarget(
        name: "libcesium.a",
        url: "https://github.com/Imajion/libcesium.a/releases/download/r1/libcesium.a.xcframework.zip",
        checksum: "46280554ec64e1de4ec837ace825d50a6dee557b7ec90481861c24c6d5e2022c"
    )

```