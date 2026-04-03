# Deferred Work

## Deferred from: code review of 1-1-dependency-check-and-script-bootstrap (2026-04-03)

- `USER_ID` global variable is unsanitized before future use in API URL/JSON interpolation — address when implementing API calls in Epic 2
- macOS / bash 4.0+ version compatibility — script requires bash 4.0+ features but does not validate at startup. Spec defers version checking.
- fzf version check at startup — only the `--height=~` flag is affected, now handled with runtime detection. Full version validation deferred.
