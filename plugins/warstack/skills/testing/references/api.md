# API: a local service

## Launch

- Use the repo's own way to start the service:
  - `docker compose -p warstack-<run id in lowercase> up -d <services>`. The `-p` project name keeps your containers apart from the user's, and compose accepts lowercase names only.
  - or its dev script, on a free port.
- It is ready when its health route answers (`curl -sf http://127.0.0.1:<port>/health`). After 3 minutes without an answer, read the logs and report.
- Data comes from the repo's seeds or fixtures. A check that needs production data or real credentials is NOT RUN, with that reason.
- Stop it with `docker compose -p warstack-<run id in lowercase> down -v`, or kill the PID you started.

## Checks

- First choice: the repo's integration or API test suite, pointed at the local service.
- Otherwise, scenario requests, one per done check:
  - `curl -s -o <run folder>/evidence/<n>/<check>.json -w '%{http_code}' <request>`;
  - assert the status code and the fields the task names;
  - for a mutation, read the stored value back with a second request.
- Save every request and response under `evidence/<n>/`.

## Harness

Once the scenarios grow past a few curls, move them into repo memory `e2e/` as a small runnable suite in the repo's own language.
