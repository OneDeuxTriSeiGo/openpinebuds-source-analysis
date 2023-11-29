#!/bin/bash
#
# Copyright 2023 Jacob Abel <jacobabel@nullpo.dev>
# SPDX-License-Identifier: Apache-2.0
#
# Summary: Parses the OPB repo to determine contributors.
#
# Note: This script is somewhat hacky and overly tailored to the quirks of
# the OPB repo at time of creation. Changes may need to be made in the future
# to better address edge cases or actually parse contributor data properly.
#
# Usage: gen-contributors.sh <repo-dir> <base-commit> <head-commit>

#-----------------------------------------------------------------------------#

# Trap ERR is always inherited.
set -o errtrace

# Exit on any non-zero exit code.
set -o errexit

# Treat unset variables as errors.
set -o nounset

# Pipes return zero only when all commands exit successfully.
set -o pipefail

repo_dir="$1"
base_commit="$2"
head_commit="$3"

contrib_dir="./contributor-records"

#-----------------------------------------------------------------------------#

awk_filter_contrib=$(printf '%s'                           \
    'BEGIN {'                                              \
    '    FS = "\t";'                                       \
    '    PROCINFO["sorted_in"] = "@ind_str_asc";'          \
    '} {'                                                  \
    '    seen[$2][$1]++;'                                  \
    '    next;'                                            \
    '} END {'                                              \
    '    cnt = 0;'                                         \
    '    for (i in seen) {'                                \
    '        min = "";'                                    \
    '        max = "";'                                    \
    '        '                                             \
    '        PROCINFO["sorted_in"] = "@ind_str_asc";'      \
    '        for (j in seen[i]) {'                         \
    '            min = j;'                                 \
    '            break;'                                   \
    '        }'                                            \
    '        PROCINFO["sorted_in"] = "@ind_str_desc";'     \
    '        for (j in seen[i]) {'                         \
    '            max = j;'                                 \
    '            break;'                                   \
    '        }'                                            \
    '        PROCINFO["sorted_in"] = "@ind_str_asc";'      \
    '        '                                             \
    '        if (min == max) {'                            \
    '            contrib[cnt++] = ( min "\t" i );'         \
    '        } else {'                                     \
    '            contrib[cnt++] = ( min "-" max "\t" i );' \
    '        }'                                            \
    '    }'                                                \
    '    PROCINFO["sorted_in"] = "@val_str_asc";'          \
    '    for (i in contrib) {'                             \
    '        print contrib[i];'                            \
    '    };'                                               \
    '}'                                                    \
)

awk_group_contrib=$(printf '%s'                                      \
    'BEGIN {'                                                        \
    '    FS = "\t";'                                                 \
    '    PROCINFO["sorted_in"] = "@ind_str_asc";'                    \
    '    title["bes"] = "BES Technic";'                              \
    '    title["amazon"] = "Amazon";'                                \
    '    title["arm"] = "ARM";'                                      \
    '    title["fraunhofer"] = "Fraunhofer-Gesellschaft";'           \
    '    title["xiph"] = "Xiph.org Foundation";'                     \
    '    split(committer_list, commit_pairs, ";");'                  \
    '    for (i in commit_pairs) {'                                  \
    '        split(commit_pairs[i], result, "=");'                   \
    '        committers[result[2]] = result[1];'                     \
    '        title[result[1]] = result[2];'                          \
    '    }'                                                          \
    '    list_table[0]=".. list-table:: ";'                          \
    '    list_table[1]="   ::header-rows: 1";'                       \
    '    list_table[2]="   * - ";'                                   \
    '    list_table[3]="     - ";'                                   \
    '} {'                                                            \
    '    cat = "";'                                                  \
    '    '                                                           \
    '    IGNORECASE = 1;'                                            \
    '    if ($3 ~ /bes/) {'                                          \
    '        cat = "bes";'                                           \
    '    } else if ($3 ~ /amazon/) {'                                \
    '        cat = "amazon";'                                        \
    '    } else if ($3 ~ /arm/ || $3 ~ /keil/) {'                    \
    '        cat = "arm";'                                           \
    '    } else if ($3 ~ /fraunhofer/) {'                            \
    '        cat = "fraunhofer";'                                    \
    '    } else if ($3 ~ /xiph/ || $3 ~ /jean-marc valin/) {'        \
    '        cat = "xiph";'                                          \
    '    } else {'                                                   \
    '        cat = "misc";'                                          \
    '        normed = gensub(/(\w) \w\. (\w)/, "\\1 \\2", "g",'      \
    '           gensub(/\s*<.*>/, "", "g", $3)'                      \
    '        );'                                                     \
    '        if (normed in committers) {'                            \
    '            cat = committers[normed];'                          \
    '        }'                                                      \
    '    }'                                                          \
    '    '                                                           \
    '    IGNORECASE = 0;'                                            \
    '    if (cat == "misc") {'                                       \
    '        misc[$3][$1][$2]++;'                                    \
    '    } else {'                                                   \
    '        tag_id = ($2 " " $3);'                                  \
    '        seen[cat][$1][tag_id]["date"] = $2;'                    \
    '        seen[cat][$1][tag_id]["id"] = $3;'                      \
    '    }'                                                          \
    '    next;'                                                      \
    '} END {'                                                        \
    '    for (cat in seen) {'                                        \
    '        out_file=( out_dir "/contrib_" cat ".rst" );'           \
    '        '                                                       \
    '        header=('                                               \
    '           prefix " Copyright Attributions for "'               \
    '           "'"'"'" title[cat] "'"'"'"'                          \
    '        );'                                                     \
    '        header_len = length(header);'                           \
    '        header_bar = "";'                                       \
    '        for (i = 0; i < header_len; i++) {'                     \
    '           header_bar = ( header_bar "=" );'                    \
    '        }'                                                      \
    '        '                                                       \
    '        print header_bar > out_file;'                           \
    '        print header >> out_file;'                              \
    '        print header_bar >> out_file;'                          \
    '        print "" >> out_file;'                                  \
    '        print ('                                                \
    '           list_table[0] "Copyright Attributions"'              \
    '        ) >> out_file;'                                         \
    '        print list_table[1] >> out_file;'                       \
    '        print "" >> out_file;'                                  \
    '        print ('                                                \
    '           list_table[2] "Filename"'                            \
    '        ) >> out_file;'                                         \
    '        print ('                                                \
    '           list_table[3] "Date"'                                \
    '        ) >> out_file;'                                         \
    '        print ('                                                \
    '           list_table[3] "Attribution"'                         \
    '        ) >> out_file;'                                         \
    '        print "" >> out_file;'                                  \
    '        '                                                       \
    '        for (file in seen[cat]) {'                              \
    '            for (tag in seen[cat][file]) {'                     \
    '                print ('                                        \
    '                   list_table[2] "``" file "``"'                \
    '                ) >> out_file;'                                 \
    '                print ('                                        \
    '                   list_table[3] seen[cat][file][tag]["date"]'  \
    '                ) >> out_file;'                                 \
    '                print ('                                        \
    '                   list_table[3] seen[cat][file][tag]["id"]'    \
    '                ) >> out_file;'                                 \
    '                print "" >> out_file;'                          \
    '            }'                                                  \
    '        }'                                                      \
    '    }'                                                          \
    '    '                                                           \
    '    if (length(misc) == 0) {'                                   \
    '       exit 0;'                                                 \
    '    }'                                                          \
    '    '                                                           \
    '    out_file=( out_dir "/contrib_misc.rst" );'                  \
    '    '                                                           \
    '    header=("Miscellaneous Copyright Attributions");'           \
    '    header_len = length(header);'                               \
    '    header_bar = "";'                                           \
    '    for (i = 0; i < header_len; i++) {'                         \
    '        header_bar = ( header_bar "=" );'                       \
    '    }'                                                          \
    '    '                                                           \
    '    print header_bar > out_file;'                               \
    '    print header >> out_file;'                                  \
    '    print header_bar >> out_file;'                              \
    '    print "" >> out_file;'                                      \
    '    print "" >> out_file;'                                      \
    '    '                                                           \
    '    for (id in misc) {'                                         \
    '        header=('                                               \
    '           prefix " Copyright Attributions for "'               \
    '           "'"'"'" gensub(/ *<[^>]+>/, "", "g", id) "'"'"'"'    \
    '        );'                                                     \
    '        header_len = length(header);'                           \
    '        header_bar = "";'                                       \
    '        for (i = 0; i < header_len; i++) {'                     \
    '            header_bar = ( header_bar "-" );'                   \
    '        }'                                                      \
    '        '                                                       \
    '        print header_bar >> out_file;'                          \
    '        print header >> out_file;'                              \
    '        print header_bar >> out_file;'                          \
    '        print "" >> out_file;'                                  \
    '        print ('                                                \
    '           list_table[0] "Copyright Attributions"'              \
    '        ) >> out_file;'                                         \
    '        print list_table[1] >> out_file;'                       \
    '        print "" >> out_file;'                                  \
    '        print ('                                                \
    '           list_table[2] "Filename"'                            \
    '        ) >> out_file;'                                         \
    '        print ('                                                \
    '           list_table[3] "Date"'                                \
    '        ) >> out_file;'                                         \
    '        print ('                                                \
    '           list_table[3] "Attribution"'                         \
    '        ) >> out_file;'                                         \
    '        print "" >> out_file;'                                  \
    '        '                                                       \
    '        for (file in misc[id]) {'                               \
    '            for (date in misc[id][file]) {'                     \
    '                print ('                                        \
    '                   list_table[2] "``" file "``"'                \
    '                ) >> out_file;'                                 \
    '                print ('                                        \
    '                   list_table[3] date'                          \
    '                ) >> out_file;'                                 \
    '                print ('                                        \
    '                   list_table[3] id'                            \
    '                ) >> out_file;'                                 \
    '                print "" >> out_file;'                          \
    '            }'                                                  \
    '        }'                                                      \
    '    }'                                                          \
    '}'                                                              \
)

awk_print_contrib_file=$(printf '%s' \
    'BEGIN {'                        \
    '    FS="\t";'                   \
    '} {'                            \
    '    print ( "* " $1 " " $2 );'  \
    '}'                              \
)

awk_format_ids=$(printf '%s'                     \
    '{'                                          \
    '    id=gensub(" ", "_", "g", tolower($0));' \
    '    print ( id "=" $0 );'                   \
    '}'                                          \
)

pcre_filter_copyright=$(printf '%s' \
    '( *the .* source code is *)?'  \
    '( *(\(c\)|\xA9) *)?'           \
    '(@? *copyright *)+'            \
    '( *(\(c\)|\xA9) *)? *'         \
    '(\d{4}( *- *\d{4})?[ ,]+)+'    \
    '.*'                            \
)

xiph_regex='XIPHOPHORUS Company <http:\/\/www.xiph.org>'

#-----------------------------------------------------------------------------#

# Generate DCO Contributions
# TODO: Not yet implemented
#
# prefix: Text prefix for DCO category.
# range: commit range to check.
function gen_dco () {
    set -o errtrace &&
    set -o nounset &&

    local prefix=$1 &&
    local range=$2 &&

    dco_results=$(git -C "${repo_dir}" log \
        -i -G 'Signed-off-by:'             \
        "${range}"                         \
    )

    # Step 1B: Terminate early if pre-OPB DCOs present.
    if [[ "${dco_results}" ]]; then
        echo "error: ${prefix} DCO (Signed-off-by) signoffs exist." >&2 &&
        echo 'error: Handling DCOs not implemented yet. exiting...' >&2 &&
        exit -1
    fi
}

# Generate Commit Contributions per file.
#
# prefx: Text prefix for documents.
# range: commit range to check.
# base_dir: Directory to store contrib files in.
# cur_file: Current file to report contribs for.
function gen_commit_contrib_by_file () {
    set -o errtrace &&
    set -o nounset &&

    local prefix=$1 &&
    local range=$2 &&
    local base_dir=$3 &&
    local cur_file=$4 &&
    local out_file="${base_dir}/${cur_file}.rst" &&

    local out_header="${prefix} Copyright Info for '$(basename ${cur_file})'" &&
    local header_bar=$(printf "%0.s=" $(seq -s ' ' 1 $(echo "${out_header}" | wc -m) ) ) &&

    mkdir -p $(dirname "${out_file}") &&
    echo "${header_bar}" > "${out_file}" &&
    echo "${out_header}" >> "${out_file}" &&
    echo "${header_bar}" >> "${out_file}" &&
    echo '' >> "${out_file}" &&

    git -C "${repo_dir}" log --reverse                          \
        --date="format:%Y" --format="%cd%x09%aN <%aE>"          \
        "${range}" -- "${cur_file}"                             \
    | awk "${awk_filter_contrib}"                               \
    | tee >( awk "${awk_print_contrib_file}" >> "${out_file}" ) \
    | awk -v cur_file="${cur_file}" '{ print ( cur_file "\t" $0 ); }'
}

# Generate Contributions.
#
# prefx: Text prefix for documents.
# range: commit range to check.
# base_dir: Directory to store contrib files in.
# check_copyright: Attempt to parse in file copyrights.
# check_commits: Check commit authors.
function gen_contrib () {
    set -o errtrace &&
    set -o nounset &&

    local prefix=$1 &&
    local range=$2 &&
    local base_dir=$3 &&
    local check_copyrights=$4 &&
    local check_commits=$5 &&

    local committer_list=$(
        git -C "${repo_dir}" log --pretty=short --format="%aN" "${range}" \
            | sed -e 's/\(\w\) \w\. \(\w\)/\1 \2/I'                       \
            | awk '!seen[$0]++'                                           \
            | awk "${awk_format_ids}"                                     \
            | tr '\n' ';'                                                 \
            | sed -e 's/;$//'                                             \
    ) &&

    gen_dco "${prefix}" "${range}" &&

    (
        if [ "${check_copyrights}" = true ]; then
            ( LC_ALL=C git -C "${repo_dir}" grep                         \
                --ignore-case --perl-regexp --only-matching              \
                "${pcre_filter_copyright}"                               \
                $(git -C "${repo_dir}" rev-list "${range}")              \
            ) | ( LC_ALL=C sed                                           \
                -e 's/\xA9//'                                            \
                -e 's/\xF6/\xC3\xB6/'                                    \
            ) | ( LC_ALL=C.UTF-8 sed                                     \
                -e 's/^[^:]\+://'                                        \
                -e '/^[^:]\+\.a:/Id'                                     \
                -e 's/\s*\*\/\?//'                                       \
                -e 's/All rights reserved\.$//I'                         \
                -e 's/licensed under the .* license\.\?//I'              \
                -e 's/@\?copyright//gI'                                  \
                -e 's/(c)//gI'                                           \
                -e 's/\s\+-\s\+/-/g'                                     \
                -e 's/the \(.*\) source code is\s\+\([-0-9]\+\)/\2 \1/I' \
                -e 's/\([0-9]\+\) OggVorbis/\1 '"${xiph_regex}"'/'       \
                -e 's/(\(https:\/\/[^)]\+\))/<\1>/'                      \
                -e 's/[. ]\+$//'                                         \
                -e 's/\([0-9]\), *\([^0-9 ]\)/\1 \2/'                    \
                -e 's/\s\+/ /'                                           \
                -e 's/\([^:]\):\([-, 0-9]\+\)/\1\t\2\t/'                 \
            ) | ( awk '!seen[$0]++' )
        fi &&

        if [ "${check_commits}" = true ]; then
            ( git -C "${repo_dir}" ls-tree                  \
                -r --full-tree --name-only "${head_commit}" \
            ) | (                                           \
                sed -e '/^.*\.a$/Id'                        \
            ) | ( while read cur_file;                      \
                do                                          \
                    gen_commit_contrib_by_file              \
                        "${prefix}"                         \
                        "${range}"                          \
                        "${base_dir}/by-file"               \
                        "${cur_file}";                      \
                done
            )
        fi &&

        mkdir -p "${base_dir}/by-contrib"
    ) | (
        sed -e 's/  \+/ /g'    \
            -e 's/ *\t */\t/g' \
    ) | (
        awk                                       \
            -v out_dir="${base_dir}/by-contrib"   \
            -v committer_list="${committer_list}" \
            "${awk_group_contrib}"
    )
}

#-----------------------------------------------------------------------------#

gen_contrib                        \
    'Pre-OpenPineBuds Contributor' \
    "${base_commit}"               \
    "${contrib_dir}/pre-opb"       \
    true                           \
    false

gen_contrib                          \
    'OpenPineBuds Contributor'       \
    "${base_commit}..${head_commit}" \
    "${contrib_dir}/opb"             \
    false                            \
    true

