#!/bin/bash

# Vercel Ignore Build Step Script
# Exit 0 = Skip build (ignore)
# Exit 1 = Proceed with build

set -o pipefail

is_skip_file() {
  case "$1" in
    community/*)
      return 0
      ;;
    @community/*)
      return 0
      ;;
    *.md|*.MD)
      return 0
      ;;
    package.json|package-lock.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

get_changed_files() {
  local files=""

  if [ -n "${VERCEL_GIT_PULL_REQUEST_BASE_BRANCH:-}" ] && [ -n "${VERCEL_GIT_COMMIT_SHA:-}" ]; then
    git fetch origin "${VERCEL_GIT_PULL_REQUEST_BASE_BRANCH}" --depth=1 2>/dev/null || true
    files=$(git diff "origin/${VERCEL_GIT_PULL_REQUEST_BASE_BRANCH}...${VERCEL_GIT_COMMIT_SHA}" --name-only 2>/dev/null || true)
  fi

  if [ -z "$files" ] && [ -n "${VERCEL_GIT_PREVIOUS_SHA:-}" ] && [ -n "${VERCEL_GIT_COMMIT_SHA:-}" ]; then
    files=$(git diff "${VERCEL_GIT_PREVIOUS_SHA}...${VERCEL_GIT_COMMIT_SHA}" --name-only 2>/dev/null || true)
  fi

  if [ -z "$files" ]; then
    files=$(git diff HEAD~1 HEAD --name-only 2>/dev/null || true)
  fi

  if [ -z "$files" ]; then
    files=$(git show --name-only --pretty="" HEAD 2>/dev/null || true)
  fi

  printf '%s\n' "$files"
}

LAST_COMMIT_MESSAGE=$(git log -1 --pretty=%s 2>/dev/null || true)
if [[ "$LAST_COMMIT_MESSAGE" == chore\(automation\):* ]]; then
  echo "🔵 Automation commit detected; skipping build."
  exit 0
fi

if [ -n "${VERCEL_GIT_COMMIT_SHA:-}" ] || [ -n "${VERCEL_GIT_PREVIOUS_SHA:-}" ] || [ -n "${VERCEL_GIT_PULL_REQUEST_BASE_BRANCH:-}" ]; then
  echo "Vercel Git context detected (env vars present)."
else
  echo "Vercel Git context not detected (env vars missing)."
fi

CHANGED_FILES="$(get_changed_files | tr -d '\r' | sed '/^$/d')"

if [ -z "$CHANGED_FILES" ]; then
  echo "🟡 Could not determine changed files via git diff. Proceeding with build."
  exit 1
fi

REMAINING_FILES=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if is_skip_file "$file"; then
    echo "Skipping non-production file: $file"
    continue
  fi
  REMAINING_FILES="${REMAINING_FILES}${file}"$'\n'
done <<EOF
$CHANGED_FILES
EOF

REMAINING_FILES="$(printf '%s' "$REMAINING_FILES" | sed '/^$/d')"

if [ -z "$REMAINING_FILES" ]; then
  echo "Only community, markdown, or package manifest files changed. Skipping build."
  exit 0
fi

# Patterns to ignore (won't trigger a build)
IGNORE_PATTERNS=(
  # Documentation (excluding .mdx which is used for blog posts)
  "\\.[mM][dD]$"
  "^LICENSE\\.md$"
  "^SECURITY\\.md$"
  "^CONTRIBUTING\\.md$"
  "^CODE_OF_CONDUCT\\.md$"
  "^CHANGELOG\\.md$"
  "^AGENTS\\.md$"
  "^CLAUDE\\.md$"
  "^SEO_IMPROVEMENTS_SUMMARY\\.md$"
  "^SOLUTION\\.md$"
  "^TODO_.*\\.md$"
  "^llms\\.txt$"
  "^docs/"
  
  # Scripts and tooling
  "^scripts/"
  "^\\.storybook/"
  
  # IDE and editor configs
  "^\\.agent/"
  "^\\.claude/"
  "^\\.kiro/"
  "^\\.vscode/"
  "^\\.idea/"
  "^\\.editorconfig$"
  
  # Git and GitHub
  "^\\.github/"
  "^\\.husky/"
  "^\\.gitattributes$"
  "^\\.gitignore$"
  
  # Linting and formatting configs
  "^\\.npmrc$"
  "^\\.prettierrc$"
  "^\\.prettierignore$"
  "^\\.claudeignore$"
  "^eslint\\.config\\.mjs$"
  "^lint-staged\\.config\\.js$"
  
  # Test files and configs
  "^vitest\\.config\\.ts$"
  "\\.test\\.(ts|tsx)$"
  "\\.spec\\.(ts|tsx)$"
  "/__tests__/"
  
  # Docker files
  "^Dockerfile$"
  "^Dockerfile\\..+$"
  "^docker-compose\\.yml$"
  "^\\.dockerignore$"
  
  # Environment examples
  "^\\.env\\.example$"
  "^\\.env\\.sample$"
  
  # Generated/Build artifacts
  "^tsconfig\\.tsbuildinfo$"
  "^next-env\\.d\\.ts$"
  
  # Custom type definitions (non-affecting)
  "^canvas-confetti\\.d\\.ts$"
  "^kuroshiro\\.d\\.ts$"
  "^sql\\.js\\.d\\.ts$"
  "^global\\.d\\.ts$"
  "^vitest\\.shims\\.d\\.ts$"
  
  # Auto-generated sitemaps and SEO files
  "^public/sitemap(-[0-9]+)?\\.xml$"
  "^public/robots\\.txt$"
  "^public/browserconfig\\.xml$"
  
  # Verification files
  "^public/google[a-z0-9]+\\.html$"
  "^public/\\.well-known/"
  
  # Config files (non-build-affecting)
  "^next-sitemap\\.config\\.js$"
  "^components\\.json$"
  "^package-lock\\.json$"
  
  # Data and community content (non-build affecting)
  "^features/Preferences/data/themes\\.ts$"
  "^community/content/community-themes\\.json$"
  "^community/content/japan-facts\\.json$"
  "^community/content/japanese-proverbs\\.json$"
  "^community/content/japanese-grammar\\.json$"
  "^community/content/anime-quotes\\.json$"
  "^community/content/japan-trivia\\.json$"
  "^community/content/japan-trivia-(easy|medium|hard)\\.json$"
  "^community/backlog/automation-state\\.json$"
  "^community/content/"
  "^community/backlog/"
  "^@community/content/"
  "^@community/backlog/"
  "^data/.*\\.json$"
  "^data/"
)

# Build the combined regex pattern
COMBINED_PATTERN=$(IFS="|"; echo "${IGNORE_PATTERNS[*]}")

# Filter out ignored files and count remaining
REMAINING=$(printf '%s\n' "$REMAINING_FILES" | grep -vE "$COMBINED_PATTERN" | grep -v '^$' | wc -l)

if [ "$REMAINING" -eq 0 ]; then
  echo "🔵 Only non-production files changed. Skipping build."
  exit 0
else
  echo "🟢 Production files changed. Proceeding with build."
  exit 1
fi
