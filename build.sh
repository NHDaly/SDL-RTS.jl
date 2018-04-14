#!/bin/bash

APPNAME="rts"
jl_main="main"
dist_certificate="Developer ID Application: nhdalyMadeThis, LLC"  # outside App Store
appstore_certificate="3rd Party Mac Developer Application: nhdalyMadeThis, LLC"

# Build for distribution
julia ~/src/build-jl-app-bundle/build_app.jl -v \
 -R assets -L "libs/*" -- bundle_identifier "com.nhdalyMadeThis.rts"
 "$jl_main.jl" "$APPNAME"

# # Build for macOS App Store
# julia ~/src/build-jl-app-bundle/build_app.jl -v \
#  -R assets -L "libs/*" --bundle_identifier "com.nhdalyMadeThis.paddlebattle" --icns "icns.icns" \
#  --certificate "$appstore_certificate" --entitlements "./entitlements.entitlements" \
#  --app_version=0.2 "$jl_main.jl" "$APPNAME" "./builddir/AppStore/"
