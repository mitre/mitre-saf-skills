# Card-Rule Incident Histories — why each rule exists

Moved out of SKILL.md (token economy: the rules stay in the skill; the
incident histories load on demand).

## ac-completeness
Cards were closed with "deferred" ACs documented in notes. That breaks trust —
documenting what was skipped is transparent laziness, still laziness. The root
cause was optimizing for card-close velocity instead of AC completeness.

## response-shape
A new field was added to two serializers (layers 1-3) but the API schema,
contract tests, and live test (layers 4-7) were not done, and the card was
closed as "done." If you change one layer you must update all downstream
layers — live-tested with real data.

## linter-disable
A linter disable was added to bypass a validation-skipping warning, but the
fields were already in the model's audit-exception list — the standard save
path was the correct call with no warnings. The disable hid a failure to read
the existing code.

## callback-validation
A `before_save` callback silently undid what a controller action explicitly
set: the endpoint cleared a timestamp field, the callback re-set it because a
status field was terminal. The user saw success but the database reverted.
Tests missed it because they tested one enum value out of five. ORM lifecycle
hook fights controller — invisible to single-layer tests, and it applies to
any stack with lifecycle hooks (Rails callbacks, Django signals, Sequelize
hooks).
