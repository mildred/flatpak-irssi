#!/bin/bash

log(){
  >&2 echo "$@"
}

apiv1=https://fastapi.metacpan.org/v1
curlapi(){
  curl -s -H "User-Agent: spam@mildred.fr" "$@"
}

# $1      in  URL
# $sha512 out Hash
get-archive-hash(){
  local urlmd5="$(<<<"$1" md5sum | cut -d' ' -f1)"
  mkdir -p .url-cache
  if [[ -e .url-cache/$urlmd5.sha512 ]]; then
    sha512="$(cat ".url-cache/$urlmd5.sha512")"
  else
    sha512="$(curl -s "$download_url" | sha512sum | cut -d' ' -f1)"
    echo "$sha512" >".url-cache/$urlmd5.sha512"
  fi
}

# $1      in  URL
# $json   out JSON
get-json(){
  local urlmd5="$(<<<"$1" md5sum | cut -d' ' -f1)"
  mkdir -p .url-cache
  if [[ -e .url-cache/$urlmd5.json ]]; then
    json="$(cat ".url-cache/$urlmd5.json")"
  else
    json="$(curlapi "$1")"
    echo "$json" >".url-cache/$urlmd5.json"
  fi
}

# $1            in  Perl module
# $download_url out Download URL
get-module-dl-url(){
  local json
  get-json "$apiv1/download_url/$1"
  download_url="$(jq -r .download_url <<<"$json")"
}

# $1            in  Perl module
# $download_url out Download URL
# $author       out Author ID
# $release      out Release ID
get-module-info(){
  local json
  get-json "$apiv1/module/$1"
  if [[ "$1" == "Extutils::Depends" ]]; then
    download_url="https://cpan.metacpan.org/authors/id/X/XA/XAOC/ExtUtils-Depends-0.405.tar.gz"
    author="XAOC"
    releast="ExtUtils-Depends-0.405"
    return 0
  fi
  download_url="$(jq -r .download_url <<<"$json")"
  author="$(jq -r .author <<<"$json")"
  release="$(jq -r .release <<<"$json")"
}

# $1              in  Author ID
# $2              in  Release ID
# $runtime_deps   out Runtime required dependencies
# $configure_deps out Configure required dependencies
get-release-deps(){
  local json
  get-json "$apiv1/release/$1/$2"
  runtime_deps=($(jq -r '.release.dependency[] | select(.relationship == "requires") | select(.phase == "runtime") | .module' <<<"$json"))
  configure_deps=($(jq -r '.release.dependency[] | select(.relationship == "requires") | select(.phase == "configure") | .module' <<<"$json"))
}

# $deps   out List of dependencies this module depends on
convert-module(){
  log convert-module $1
  local name="${1//::/-}"
  local download_url author release runtime_deps configure_deps sha512
  get-module-info "$1"
  local fname="$(basename "$download_url")"
  if [[ "${fname%%-*}" == perl ]]; then
    log "convert-module $1: release $author/$release included in perl [skip]"
    return 0
  fi
  log "convert-module $1: release $author/$release"
  get-archive-hash "$download_url"
  get-release-deps "$author" "$release"
  mkdir -p perl
  echo "perl/$name.json" >&3
  cat >"perl/$name.json" <<EOF
    {
      "name": "perl-$name",
      "buildsystem": "simple",
      "build-commands": [
        "perl Makefile.PL",
        "make",
        "make install"
      ],
      "post-install": [
        "find /app/lib ! -writable -exec chmod u+w '{}' +"
      ],
      "ensure-writable": [
        "/lib/perl5/*/*/perllocal.pod",
        ".packlist"
      ],
      "sources": [
        {
          "type":   "archive",
          "url":    "$download_url",
          "sha512": "$sha512"
        }
      ]
    }
EOF
  for dep in "${runtime_deps[@]}" "${configure_deps[@]}"; do
    local depname="${dep//::/-}"
    if [[ "$dep" == perl ]]; then
      continue
    elif [[ -e "perl/$depname.json" ]]; then
      log "convert-module $1: dependency to $dep [skip]"
      continue
    fi
    log "convert-module $1: dependency to $dep"
    convert-module "$dep"
  done
}

while true; do
  case "$1" in
    *) break ;;
  esac
done

exec 3>$1.deps
convert-module "$1"
