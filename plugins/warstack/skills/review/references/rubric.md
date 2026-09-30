# Review rubric

Apply the lenses that bear on the change. A small fix needs no architecture essay.

## Task

- Does the change do what `task.md` asks, and meet each done check?
- Is anything the task asked for missing? Did anything change that the task never asked for?

## Correctness

- Empty, null, boundary and malformed inputs. Error paths: caught, propagated, or swallowed?
- Async and concurrency: races, stale state, ordering. What happens when it runs twice, or crashed halfway through last time?
- Trace a suspected bug to the input that triggers it. A finding with no reachable trigger is a hypothesis, so label it as one.

## Root cause

- Does the fix sit where every caller routes through? Or does it patch one path and leave sibling callers broken?
- Guards, retries or casts that hide a broken invariant instead of fixing it.

## Tests: the proof

- Changed behaviour has a test that fails without the change. A mechanical change (a config value, an asset, copy) is proven by testing's checks instead, and needs no test of its own.
- **Vacuous tests.** A test that would still pass if every function it imports returned `undefined` proves nothing. The usual shapes:
  - no assertion, or only a weak one (`toBeDefined`, `toBeTruthy`, `not.toThrow`);
  - only mock-call assertions;
  - an expected value computed by the code under test;
  - a restated constant;
  - an assertion on a fixture the subject never touched.
- A bug fix carries a regression test for the reported path, or `plan.md` records why none is practical.

## Complexity

- Something simpler would do: a single-use abstraction, config for cases that do not exist, dead code, logic that already exists nearby (name where).
- The change follows the patterns of the code around it.

## Security

- Input reaching a shell, SQL, HTML, `eval` or a file path unchecked.
- Missing authorization.
- Secrets or personal data in code, logs, tests or fixtures.

## Severity

- **critical**: wrong behaviour, an unmet done check, a security issue, data loss, a missing or vacuous test for a behaviour-bearing change.
- **warning**: works today but will hurt, with a concrete scenario.
- **nit**: style, naming, taste.

A good finding names the location, shows why it is a problem, and separates "this is broken" from "I would do it differently".
