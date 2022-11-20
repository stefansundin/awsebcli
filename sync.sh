#!/bin/bash -e
if [[ ! -d main ]]; then
  echo "Please clone the main branch to a subdirectory:"
  echo
  echo "  git clone git@github.com:stefansundin/awsebcli.git main"
  echo
  exit 1
fi

curl -sf -o api.json https://pypi.org/pypi/awsebcli/json

export GIT_COMMITTER_NAME="$(cat api.json | jq -Mr '.info | .author')"
export GIT_COMMITTER_EMAIL="$(cat api.json | jq -Mr '.info | .author_email')"
author="$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>"

cat api.json | jq -Mr '.releases | to_entries | sort_by(.value[0].upload_time+"Z" | fromdateiso8601)[] | [.key, .value[0].upload_time, .value[0].filename, .value[0].url] | join(" ")' | while read -r version upload_time filename url; do
  tag="v$version"
  if git -C main rev-parse "$tag" >/dev/null 2>&1; then
    # tag already exists
    continue
  fi

  [[ ! -f "$filename" ]] && wget -O "$filename" "$url"
  echo "$version $filename"

  # delete everything in the main directory except the .git directory
  find main -path main/.git -prune -o -type f -print | grep -v '^main$' | xargs rm -f

  # extract the new version, commit it, and tag it
  tar -xzf "$filename" -C main --strip-components=1
  git -C main add .
  git -C main commit --no-verify --author="$author" --date="$upload_time" -m "$version"
  git -C main tag "$tag"
  git -C main --no-pager log --stat -n 1
  echo
done

echo
echo "Manually verify the git log and then run 'git push' and 'git push --tags' in the main directory."
