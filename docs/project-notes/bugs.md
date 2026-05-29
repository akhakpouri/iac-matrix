# Bug Log

Tracks defects discovered in this repo with their root cause and fix. New entries go at the top, numbered `BUG-NNN`.

Suggested template:

```
## BUG-001 — short title

**File:** path/to/file
**Discovered:** YYYY-MM-DD
**Status:** Open | Fixed
**Branch:** feature/issue-N (if applicable)

### Description
What was observed.

### Root cause
Why it happened.

### Fix
What changed.
```

---

## BUG-001 — `log_connections` rejected as invalid value on PG18 parameter group apply

**File:** `aws/modules/rds/main.tf`
**Discovered:** 2026-05-29
**Status:** Fixed
**Branch:** `feature/issue-13`

### Description

Applying `platform-shared` against the `postgres18` parameter family failed at the parameter-group modify step:

```
modifying RDS DB Parameter Group (shared): operation error RDS: ModifyDBParameterGroup,
api error InvalidParameterValue: Invalid parameter value: 1 for: log_connections
allowed values are: receipt, authentication, authorization, setup_durations, all
```

### Root cause

`log_connections` is a boolean parameter in PostgreSQL ≤ 17 (`0` / `1` / `on` / `off`), but PostgreSQL 18 converted it to an enum to control connection-log granularity. The module's `aws_db_parameter_group "shared"` was still using `value = "1"` — valid on `postgres17`, invalid on `postgres18`. The default `resource_family = "postgres18"` was newer than the parameter literal.

### Fix

Changed `value = "1"` → `value = "all"` (the closest semantic match — log every stage of every connection). For lighter production logging, `"authentication"` would log only successful/failed auth events. Comment added pointing at the PG18 enum values so the next reader doesn't repeat this.
