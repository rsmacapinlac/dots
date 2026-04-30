#!/usr/bin/env bash
# Claude Code statusLine: git branch + model name + context progress bar

input=$(cat)

model=$(echo "$input" | jq -r '.model.id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Shorten model name: "claude-sonnet-4-6" -> "sonnet-4-6"
if [[ -n "$model" ]]; then
  model_short="${model#claude-}"
else
  model_short="claude"
fi

# Git branch (skip optional locks to avoid blocking)
branch=""
if [[ -n "$cwd" ]]; then
  branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Build context progress bar from pre-calculated percentage
if [[ -n "$used_pct" ]]; then
  pct=$(printf "%.0f" "$used_pct")
  filled=$(( pct * 10 / 100 ))
  empty=$(( 10 - filled ))
  bar=""
  for ((i=0; i<filled; i++)); do bar+="#"; done
  for ((i=0; i<empty; i++)); do bar+="-"; done
  context_str="[${bar}] ${pct}%"
else
  context_str=""
fi

# Rate limit reset time
reset_str=""
if [[ -n "$resets_at" ]]; then
  reset_str="↺ $(date -d "@${resets_at}" '+%H:%M' 2>/dev/null)"
fi

# Assemble output, joining non-empty parts with " | "
parts=()
[[ -n "$branch" ]] && parts+=("$branch")
parts+=("$model_short")
[[ -n "$context_str" ]] && parts+=("$context_str")
[[ -n "$reset_str" ]] && parts+=("$reset_str")

output=""
for part in "${parts[@]}"; do
  if [[ -z "$output" ]]; then
    output="$part"
  else
    output="${output} | ${part}"
  fi
done

echo "$output"
