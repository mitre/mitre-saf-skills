# Periodic Audit Cadence

Test suites drift. Production code changes but tests don't keep up. Run the skill's audit mode on these triggers:

| Trigger | Action |
|---------|--------|
| After any production model gains 3+ new methods | Audit the model spec for coverage gaps |
| After any callback is added/modified | Audit the model spec for callback x enum coverage |
| After any controller gains new before_actions | Audit the request spec for auth gaps |
| Before any major release/deploy | Audit all spec files over 300 lines |
| After a collaborator splits a spec file | Audit the split for grouping quality + gaps |
| After a bug is found in production | Audit whether the bug's code path had test coverage — if not, the test suite drifted |

## Test Drift Detection (Audit Mode)

When running in audit mode, compare test coverage against production code:

1. List all public methods in the production file
2. List all test descriptions in the spec file
3. Cross-reference: which methods have zero tests?
4. Check callback coverage: for models with callbacks, are ALL enum values tested?
5. Check auth coverage: for controllers with before_actions, is every action tested both authenticated and unauthenticated?

Flag gaps as CRITICAL (untested public method), WARNING (untested edge case), or INFO (untested but low-risk).
