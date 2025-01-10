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
        url: "https://github.com/Imajion/libcesium.a/releases/download/r5/libcesium.a.xcframework.zip",
        checksum: "fe8b44535c2c7fb95836e6a6461cae63925b7128a92dcd104a664bad7faaf6cb"
    )

```
