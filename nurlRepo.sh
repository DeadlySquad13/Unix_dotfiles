#!/usr/bin/env bash

set -e

spin[0]="-"
spin[1]="\\"
spin[2]="|"
spin[3]="/"

# Alternative way. It's slower but checks for auth (useful for private repos)
# user=$(gh api user -q .login)
user=$(git config --get user.name)
owner=$(printf "%s\n" ${user} $(gh org list) | fzf)

#   Get all pages of repositories where owner (or user) is owner. Sort by
# UPDATED_AT (most recent - first).
#   In `nodes` you can specify fields you want to fetch.
# I've used `gh repo list --help`, "JSON FIELDS" section for this,
# though, official api docs might be more relevant
# https://docs.github.com/en/graphql.
QUERY='
  query($owner: String!, $endCursor: String) {
    repositoryOwner(login: $owner) {
      repositories(first: 100, after: $endCursor, orderBy: { field: UPDATED_AT, direction: DESC }) {
        nodes {
            nameWithOwner
            description
            updatedAt
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
'

gh api graphql --paginate \
    -F owner="${1:-$owner}" -f query="${QUERY}" \
    --jq '.data.repositoryOwner.repositories.nodes' \
    > .repos.json & PID=$!

# Find longest nameWithOwner.
# To do this we:
# 1. Get object with maximum nameWithOwner.
# 2. Get value of nameWithOwner from this object.
# 3. Calculate length.
# columnLength=$(cat .repos.json | jq 'max_by(.nameWithOwner | length) | .nameWithOwner | length')
# echo $columnLength

echo "This may take a while. Please be patient while it runs" >&2
printf "[" >&2
while kill -0 $PID 2>/dev/null; do
  # for i in "${spin[@]}"; do
  # echo -ne "\b$i"
  printf "▓" >&2
  sleep 0.5
  # done
done
printf "] done!\n" >&2

# Get all fields in a single column like view.
# To determine columns, a separator (-s) '\t' is used.
# [Using jq and column][@/AnswertoHowtoformataJSONstringasatableusingjq?:Rahmatullin/AnswerHowFormat.2019]
# [Zotero][z@/AnswertoHowtoformataJSONstringasatableusingjq?:Rahmatullin/AnswerHowFormat.2019]
selected=$(cat .repos.json | jq -r '.[] | "\(.nameWithOwner)\t\(.description)"' \
    | sed "s,${owner}/,," \
    | column -ts $'\t' \
    | fzf)

# QUESTION: Not sure it works. At least not for Ctrl+c.
if [ -z "$selected" ]; then
  echo "Please choose a repository" >&2
  exit 1
fi

# Extract just the repo name (before the first space)
if [ -n "$selected" ]; then
    echo "Selected: $selected" >&2

    repo=${selected%% *}
    repoNameWithOwner="$repo"
    # / needed escaping here
    if [[ ! "$repo" == *\/* ]]; then
      repoNameWithOwner="$owner/$repo"
    fi
    nurl "git@github.com:$repoNameWithOwner.git"
    # nix-shell -p nurl --run "nurl git@github.com:DeadlySquad13/Unix_dotfiles.git"
fi

# option=$(echo "clone view fork archive" | tr " " "\n" | fzf)
# if [ -z $option ]; then
#   echo "Please choose an option"
#   exit 1
# fi

# References:
# Main inspiration: https://github.com/kavinvalli/gh-repo-fzf/blob/eceb769efecee53e559d66b1b09fcab5b26c2d0e/gh-repo-fzf
# [@/AnswertoHowtoformataJSONstringasatableusingjq?:Rahmatullin/AnswerHowFormat.2019]: <https://stackoverflow.com/a/54854136> 'Answer to "How to Format a JSON String as a Table Using Jq?"'
# [z@/AnswertoHowtoformataJSONstringasatableusingjq?:Rahmatullin/AnswerHowFormat.2019]: <zotero://select/items/@/AnswertoHowtoformataJSONstringasatableusingjq?:Rahmatullin/AnswerHowFormat.2019> 'Select in Zotero: Answer to "How to Format a JSON String as a Table Using Jq?"'
