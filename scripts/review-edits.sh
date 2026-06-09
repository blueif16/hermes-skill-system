#!/usr/bin/env bash
# Reveal every skill-system edit in a time span — the periodic review (Principle 2).
# Skill-system edits use the convention:  skillsys(<owner>): <rule>
#
# Usage:
#   review-edits.sh                       # last month
#   review-edits.sh "2 weeks ago"
#   review-edits.sh "2026-05-01" "2026-06-01"
set -euo pipefail

since="${1:-1 month ago}"
until="${2:-now}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repo — run this from inside the repo whose skill edits you want to review" >&2
  exit 1
fi

count=$(git log --since="$since" --until="$until" --grep='^skillsys(' --oneline | wc -l | tr -d ' ')
echo "# skill-system edits   ${since} → ${until}   (${count} change(s))"
echo

# Full subject + body (why/lesson/verify), newest first, body indented 2 spaces.
git log --since="$since" --until="$until" --grep='^skillsys(' \
  --date=short --pretty=format:'## %s%n   %h · %ad · %an%n%w(0,3,3)%b%n'
