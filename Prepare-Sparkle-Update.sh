#!/usr/bin/env bash
# Usage: ./Prepare-Sparkle-Update.sh PATH_TO_APP [DSA_PRIV_KEY] [BASE_URL]
# 
# Creates a zip archive of the given app, signs it and outputs an RSS item tag
# for Sparkle appcast.
# 
# The name of the zip archive will be APPNAME-VERSION.zip, where the VERSION is
# the value of CFBundleVersion in Info.plist of the given app.
# The default for DSA_PRIV_KEY, path to DSA private key is: dsa_priv.pem
# The default BASE_URL is derived from the value of SUFeedURL of the app's
# Info.plist.
# 
# Sparkle distribution with the Extras folder (e.g., Sparkle 1.5b6/) should
# exist in the current directory, or sign_update.rb must be on PATH.
#
# Author: Jaeho Shin <netj@sparcs.org>
# Created: 2013-02-02
set -eu

usage() { sed -n '2,/^#$/ s/^# //p' <"$0"; exit 1; }
[ $# -gt 0 ] || usage
app=$1; shift
[ -e "$app" ] || usage
name=$(basename "$app" .app)
version=$(
    cat "$app"/Contents/Info.plist | plutil -convert json - -o - |
    sed 's/.*"CFBundleVersion":"\([^"]*\).*/\1/'
)
sparkleKey=${1:-dsa_priv.pem}
sparkleBaseURL=${2:-$(
    cat "$app"/Contents/Info.plist | plutil -convert json - -o - |
    sed 's/.*"SUFeedURL":"\([^"]*\).*/\1/; s:\\/:/:g; s:/[^/]*$::'
)}

# Create a zip archive
zip="$name-$version.zip"
ditto -ck --keepParent "$app" "$zip"

# Sign it with Sparkle private key
for d in Sparkle\ */Extras/"Signing Tools"/; do
    [ -d "$d" ] || continue
    PATH+=:"$d"
done
signature=$(sign_update.rb "$zip" dsa_priv.pem)

# Output an item for the Sparkle appcast
cat <<EOF
<item>  
  <title>$name version $version</title>
  <sparkle:releaseNotesLink>$sparkleBaseURL/$version.html</sparkle:releaseNotesLink>
  <pubDate>$(date --rfc-822)</pubDate>
  <enclosure
    url="${sparkleBaseURL%.Updates}/$zip"
    sparkle:version="$version"
    type="application/octet-stream"
    length="$(perl -e 'print -s $ARGV[0]' "$zip")"
    sparkle:dsaSignature="$signature"
  />
</item>
EOF
