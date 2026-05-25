# _legacy

Archived scaffolding from earlier directions the project took but did not
ship. Not wired into the current Flutter app in [`../budget_app`](../budget_app).

- `amplify/` — AWS Amplify backend scaffold (auth + API). Abandoned in favour
  of fully local `shared_preferences` storage.
- `src/graphql/`, `src/models/` — generated AppSync GraphQL client and models
  from the Amplify experiment.

Kept in-tree for historical reference. Safe to delete if disk space is
needed; the Flutter app does not import any of it.
