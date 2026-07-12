#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dev_dir="${script_dir}/.dev"
grammar_dir="${dev_dir}/grammar"
extension_dir="${dev_dir}/extension"

mkdir -p "${grammar_dir}" "${extension_dir}"

rsync -a --delete \
    --exclude '.git/' \
    --exclude 'node_modules/' \
    "${script_dir}/TreeSitter/" \
    "${grammar_dir}/"

if [[ ! -d "${grammar_dir}/.git" ]]; then
    git -C "${grammar_dir}" init --quiet
fi

grammar_root="$(git -C "${grammar_dir}" rev-parse --show-toplevel)"
if [[ "${grammar_root}" != "${grammar_dir}" ]]; then
    echo "Refusing to use Git repository outside ${grammar_dir}" >&2
    exit 1
fi

git -C "${grammar_dir}" add --all
git -C "${grammar_dir}" \
    -c user.name='Silex Development' \
    -c user.email='dev@silex.local' \
    commit --quiet --allow-empty -m 'Local grammar snapshot'

grammar_revision="$(git -C "${grammar_dir}" rev-parse HEAD)"
grammar_repository="file://${grammar_dir}"

rsync -a --delete "${script_dir}/languages/" "${extension_dir}/languages/"
rsync -a --delete "${script_dir}/snippets/" "${extension_dir}/snippets/"
cp "${script_dir}/extension.toml" "${extension_dir}/extension.toml"

GRAMMAR_REPOSITORY="${grammar_repository}" \
GRAMMAR_REVISION="${grammar_revision}" \
perl -0pi -e '
    s{(\[grammars\.silex\].*?repository = ")[^"]+(".*?rev = ")[^"]+}{
        $1 . $ENV{GRAMMAR_REPOSITORY} . $2 . $ENV{GRAMMAR_REVISION}
    }se
' "${extension_dir}/extension.toml"

echo "Silex dev extension prepared:"
echo "  ${extension_dir}"
echo
echo "First use: run 'zed: install dev extension' and select this directory."
echo "Later updates: run 'zed: rebuild dev extension'."
