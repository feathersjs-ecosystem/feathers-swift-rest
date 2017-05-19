# FeathersSwiftRest

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage) [![CocoaPods compatible](https://img.shields.io/cocoapods/v/FeathersSwiftRest.svg)](#cocoapods) [![GitHub release](https://img.shields.io/github/release/startupthekid/feathers-swift-rest.svg)](https://github.com/startupthekid/feathers-ios/releases) ![Swift 3.0.x](https://img.shields.io/badge/Swift-3.0.x-orange.svg) ![platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS-lightgrey.svg)

## What is FeathersSwiftRest?

FeathersSwiftRest is a promise-based REST HTTP provider for [FeathersSwift](https://github.com/startupthekid/feathers-swift).

## Installation

### Cocoapods
```
pod `FeathersSwiftRest`
```
### Carthage

Add the following line to your Cartfile:

```
github "startupthekid/feathers-swift-rest"
```

## Usage

To use FeathersSwiftRest, create an instance of `RestProvider` and initialize your FeathersSwift application:

```swift
let feathersRestApp = Feathers(provider: RestProvider(baseURL: URL(string: "https://myawesomefeathersapi.com")!)
```

That's it! Your feathers application will now support a REST API.
