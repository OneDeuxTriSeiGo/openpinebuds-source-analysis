#!/bin/bash
#
# Copyright 2023 Jacob Abel <jacobabel@nullpo.dev>
# SPDX-License-Identifier: Apache-2.0
#
# Summary: Reads in the alt_source sources file and generates diffs
# for each file relative to the current working directory.
#
# Usage: gen-alt-source-diffs.sh <alt-sources-file> <base-commit>

#-----------------------------------------------------------------------------#

# Trap ERR is always inherited.
set -o errtrace

# Exit on any non-zero exit code.
set -o errexit

# Treat unset variables as errors.
set -o nounset

# Pipes return zero only when all commands exit successfully.
set -o pipefail

alt_source_file="$1"
base_commit="$2"

opb_base='https:\/\/raw.githubusercontent.com\/pine64\/OpenPineBuds'

#-----------------------------------------------------------------------------#

# Check if GNU Parallel is available
if ! command -v parallel &> /dev/null; then
    echo "ERROR: GNU Parallel is not available. Exiting."
    exit 255
fi

#-----------------------------------------------------------------------------#

parse_cmd=$(printf '%s'                                                      \
    '/   \* - ``.*``/'                                                       \
    '{N;N;N;N;'                                                              \
    's/'                                                                     \
        '(   \* - ``[^`]+``\n'                                               \
        '     - [^\n]*\n'                                                    \
        '     - [^\n]*\n'                                                    \
        '     - )(`[^ ]+ <[^>]+>`_) AND (`[^ ]+ <[^>]+>`_)(\n'               \
        '     - )(`[^ ]+ <[^>]+>`_) AND (`[^ ]+ <[^>]+>`_)'                  \
    '/'                                                                      \
        '\1\2\4\5\n\1\3\4\6'                                                 \
    '/;'                                                                     \
    's/'                                                                     \
        '<https:\/\/github.com\/([^\/]+\/[^[\/]+)\/blob\/([^\/]+)\/([^>]+)>' \
    '/'                                                                      \
        '<https:\/\/raw.githubusercontent.com\/\1\/\2\/\3>'                  \
    '/g;'                                                                    \
    's/'                                                                     \
        '   \* - ``([^`]+)``\n'                                              \
        '     - [^\n]*\n'                                                    \
        '     - [^\n]*\n'                                                    \
        '     - `[^ ]+ <([^>]+)>`_\n'                                        \
        '     - `[^ ]+ <([^>]+)>`_'                                          \
    '/'                                                                      \
        "${opb_base}" '\/' "${base_commit}" '\/'                             \
        '\1\t\2\t\3'                                                         \
    '/gp;'                                                                   \
    'd}'                                                                     \
)


function gen_diffs () {
    set -o errtrace &&
    set -o nounset &&

    local local_url=$1 &&
    local remote_url=$2 &&
    local out_file=$3 &&
    local identical_diff_regex=$(printf '%s'   \
        's/'                                   \
        'Files [^ ]+ and [^ ]+ are identical'  \
        '/'                                    \
        'Files local and remote are identical' \
        '/'                                    \
    ) &&

    echo "Fetching local: ${local_url}" &&
    local_file=$(wget -qO- "${local_url}" | sed -e 's/\r$//' -e 's/\s+$//') &&

    echo "Fetching remote: ${remote_url}" &&
    remote_file=$(wget -qO- "${remote_url}" | sed -e 's/\r$//' -e 's/\s+$//') &&

    mkdir -p "$(dirname ${out_file})" &&

    echo "Writing diff: ${out_file}" &&
    echo -e $(printf '%s'              \
        "local: ${local_url}\n"        \
        "remote: ${remote_url}\n"      \
        "diff -sw local remote\n---\n" \
    ) > "${out_file}" &&

    diff -sw                     \
        <(echo "${local_file}")  \
        <(echo "${remote_file}") \
    | sed -E "${identical_diff_regex}" >> "${out_file}" &&
    echo ""
}

export -f gen_diffs

sed --regexp-extended --quiet -e "${parse_cmd}" "${alt_source_file}" \
    | parallel                                                       \
        --load=90% --jobs=0                                          \
        -keep-order --halt-on-err=soon,fail,1                        \
        --colsep '\t'                                                \
        gen_diffs


echo "[SUCCESS] Alt Source Diffs Generated"
