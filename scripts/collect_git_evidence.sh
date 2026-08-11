#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' "Usage: collect_git_evidence.sh [--date YYYY-MM-DD] [--repo PATH] [--no-fetch]"
}

report_date="$(date +%F)"
repo_path="."
skip_fetch=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --date)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      report_date="$2"
      shift 2
      ;;
    --repo)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      repo_path="$2"
      shift 2
      ;;
    --no-fetch)
      skip_fetch=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$report_date" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *)
    printf 'Invalid date: %s\n' "$report_date" >&2
    exit 2
    ;;
esac

cd "$repo_path"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf '%s\n' 'Not inside a Git repository.' >&2
  exit 3
}
cd "$repo_root"

fetch_status="skipped_by_option"
if [ "$skip_fetch" = false ]; then
  if git fetch --all --prune >/dev/null 2>&1; then
    fetch_status="ok"
  else
    fetch_status="failed"
  fi
fi

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf '%s' '(detached HEAD)')"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
git_user_name="$(git config --get user.name 2>/dev/null || true)"
git_user_email="$(git config --get user.email 2>/dev/null || true)"
window_start="${report_date} 00:00:00"
window_end="${report_date} 23:59:59"

printf 'report_date\t%s\n' "$report_date"
printf 'collected_at\t%s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
printf 'repo_root\t%s\n' "$repo_root"
printf 'fetch_all_remotes\t%s\n' "$fetch_status"
printf 'branch\t%s\n' "$branch"
printf 'upstream\t%s\n' "${upstream:-'(none)'}"
printf 'git_user_name\t%s\n' "${git_user_name:-'(unset)'}"
printf 'git_user_email\t%s\n' "${git_user_email:-'(unset)'}"
printf 'window\t%s .. %s\n' "$window_start" "$window_end"

if [ -n "$upstream" ]; then
  printf 'ahead_behind\t'
  git rev-list --left-right --count HEAD..."$upstream" 2>/dev/null || printf '%s' 'unavailable'
  printf '\n'
fi

printf '\n=== all_branch_refs ===\n'
branch_refs="$(git for-each-ref --format='%(refname:short) %(objectname:short)' refs/heads refs/remotes)"
if [ -n "$branch_refs" ]; then
  printf '%s\n' "$branch_refs"
else
  printf '%s\n' '(no branch refs)'
fi

printf '\n=== today_records_for_current_git_user ===\n'
matching_records=""
if [ -n "$git_user_name" ] || [ -n "$git_user_email" ]; then
  matching_records="$(
    git log --all --since="$window_start" --until="$window_end" \
      --date=iso-strict-local \
      --format='%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%ad%x1f%s' |
    awk -v name="$git_user_name" -v email="$git_user_email" '
      BEGIN { FS = sprintf("%c", 31) }
      ((name != "" && ($2 == name || $4 == name)) ||
       (email != "" && ($3 == email || $5 == email))) {
        printf "commit\t%s\tauthor=%s <%s>\tcommitter=%s <%s>\tdate=%s\tsubject=%s\n", $1, $2, $3, $4, $5, $6, $7
      }
    ' |
    sort -u -t $'\t' -k2,2
  )"
fi

if [ -n "$matching_records" ]; then
  printf '%s\n' "$matching_records"
else
  if [ -z "$git_user_name" ] && [ -z "$git_user_email" ]; then
    printf '%s\n' '(Git identity unavailable)'
  else
    printf '%s\n' '(no matching records)'
  fi
fi

printf '\n=== matching_commit_refs_and_upstream_visibility ===\n'
if [ -n "$matching_records" ]; then
  matching_shas="$(printf '%s\n' "$matching_records" | awk -F '\t' '{print $2}' | sort -u)"
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    refs="$(git branch --all --contains "$sha" --format='%(refname:short)' | paste -sd, -)"
    [ -n "$refs" ] || refs='(none)'
    if [ -z "$upstream" ]; then
      visibility='upstream unavailable'
    elif git merge-base --is-ancestor "$sha" "$upstream"; then
      visibility='visible in current upstream ref'
    else
      visibility='not visible in current upstream ref'
    fi
    printf 'sha\t%s\trefs=%s\t%s\n' "$sha" "$refs" "$visibility"
  done <<< "$matching_shas"
else
  printf '%s\n' '(no matching commits)'
fi

printf '\n=== worktree_status_excluding_report_dir ===\n'
git status --short --untracked-files=all -- \
  . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report' || true

printf '\n=== diff_candidate_summary_excluding_report_dir ===\n'
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  tracked_diff_names="$(git diff HEAD --name-only -- \
    . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report')"
  if [ -n "$tracked_diff_names" ]; then
    printf 'tracked_diff_candidate\tpresent\n'
    printf '%s\n' "$tracked_diff_names"
  else
    printf 'tracked_diff_candidate\tabsent\n'
  fi
else
  printf 'tracked_diff_candidate\tno HEAD; inspect untracked files\n'
fi

untracked_names="$(git ls-files --others --exclude-standard -- \
  . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report')"
if [ -n "$untracked_names" ]; then
  printf 'untracked_diff_candidate\tpresent\n'
  printf '%s\n' "$untracked_names"
else
  printf 'untracked_diff_candidate\tabsent\n'
fi

printf '\n=== unstaged_name_status_excluding_report_dir ===\n'
git diff --name-status -- \
  . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report' || true

printf '\n=== staged_name_status_excluding_report_dir ===\n'
git diff --cached --name-status -- \
  . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report' || true

printf '\n=== tracked_diff_stat_excluding_report_dir ===\n'
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git diff HEAD --stat -- \
    . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report' || true
else
  printf '%s\n' '(no HEAD; inspect untracked files separately)'
fi

printf '\n=== untracked_files_excluding_report_dir ===\n'
git ls-files --others --exclude-standard -- \
  . ':(exclude)docs/daily-report/**' ':(exclude)docs/daily-report' || true
