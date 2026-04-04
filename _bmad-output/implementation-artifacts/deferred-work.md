# Deferred Work

## Deferred from: code review of 1-1-dependency-check-and-script-bootstrap (2026-04-03)

- `USER_ID` global variable is unsanitized before future use in API URL/JSON interpolation — address when implementing API calls in Epic 2 (also flagged in story 1.2 review)
- macOS / bash 4.0+ version compatibility — script requires bash 4.0+ features but does not validate at startup. Spec defers version checking.
- fzf version check at startup — only the `--height=~` flag is affected, now handled with runtime detection. Full version validation deferred.

## Deferred from: code review of 1-2-active-assignment-display (2026-04-03)

- 1-second timeout unrealistic for Azure CLI cold path — Azure CLI often takes 2–5s on token refresh; the hard 1s ceiling virtually guarantees silent skip on first run after login. Product decision per AC2/NFR2; revisit if users report the feature never showing.

## Deferred from: code review of 1-3-category-picker-and-navigation-shell (2026-04-04)

- USER_ID embedded raw in OData filter URL — no encoding or validation before URL interpolation; Story 1.2 scope, address in Epic 2 API work
- Silent API error suppression in fetch functions — all errors return fake `{"value":[]}`, masking auth/network failures; Story 1.2 scope
- 1-second polling timeout too short on WAN/VPN — partial-timeout scenario also leaves truncated temp files read unconditionally; Story 1.2 scope
- `date +%s%3N` GNU-only millisecond timestamp — not portable to macOS BSD date; Story 1.2 scope
- `grep -c .` returns 1 for empty string — phantom count when all role names are null/empty; Story 1.2 scope
- `trap "rm -rf '$tmpdir'" RETURN` skipped on ERR exit — temp dir leaks if function exits on error; Story 1.2 scope
- `mktemp -d` failure not handled — silent empty path on full /tmp; Story 1.2 scope
- `curl` listed as required dependency but never called — unnecessary failure point on minimal environments; Story 1.1 scope
- `printf "${RED}..."` uses color escape as format string — safe now but fragile if escapes ever contain `%`; Story 1.1 scope
