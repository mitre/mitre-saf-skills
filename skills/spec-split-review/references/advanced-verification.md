# Phase 7: Advanced Verification

Run after carding findings (Phase 6), before closing the epic. These are deep verification steps that go beyond the basic split workflow.

## 7a. Test Isolation Verification

After the split, verify files work both individually AND together. A file that passes alone but fails in combination has an ordering dependency — the split exposed it.

```bash
# Run each file individually
for f in spec/requests/orders_*_spec.rb; do
  result=$(bundle exec rspec "$f" --format progress 2>&1 | grep 'examples')
  echo "$(basename $f): $result"
done

# Run all together (should match sum of individual counts)
bundle exec rspec spec/requests/orders_*_spec.rb --format progress

# If failures appear only in combined run, find the minimum failing combo:
bundle exec rspec spec/requests/orders_*_spec.rb --bisect
```

**Common causes of isolation failures:**
- `let_it_be` record created in file A, accidentally used by file B (fixed by global `refind: true`)
- Factory sequence producing same ID across files (fixed by process-scoped sequences)
- Shared class state (`@@class_var`, `Rails.cache`, module-level memoization)

## 7b. Race Condition Testing

For ANY model with callbacks that modify shared state, test concurrent access:

```ruby
# Pattern: two threads hitting the same record simultaneously
it 'handles concurrent updates without deadlock' do
  record = create(:order, :pending, ...)
  threads = 2.times.map do |i|
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        record.reload.update!(status: "approved", ...)
      end
    end
  end
  expect { threads.each(&:join) }.not_to raise_error
end
```

**When to add race condition tests:**
- Model has `before_save` / `after_save` callbacks that modify OTHER records (cascade)
- Controller action creates/destroys records in a loop without consistent lock ordering
- Any operation that uses `update_columns` or `update_all` on shared records
- Association cascade (sorted destroy order prevents deadlocks)
- Bulk operations that touch multiple records in a transaction

**What to check:**
- No `PG::TRDeadlockDetected` exceptions
- Final state is consistent regardless of execution order
- `ActiveRecord::StaleObjectError` if using optimistic locking (`lock_version` column)

## 7c. Mutation Testing (Optional Deep Verification)

The `mutant` gem systematically modifies production code and verifies tests catch the change. If a mutation passes all tests, the test is worthless — it proves weak-assertion violations at scale.

```bash
# Run mutant on a specific method (e.g., a critical business logic method)
bundle exec mutant run --use rspec 'Order#apply_discount'

# Run mutant on a class (expensive — 5-30 min per class)
bundle exec mutant run --use rspec 'Order'
```

**When to use:**
- After completing all test gap cards from the expert review
- On CRITICAL business logic (workflow state machine, export formatting, auth gates)
- As a final verification before declaring a model "fully covered"
- NOT during the split itself — the split should not change behavior

**Interpreting results:**
- `killed` — test caught the mutation (good)
- `alive` — mutation passed all tests (test gap — card it)
- `timeout` — mutation caused infinite loop (usually OK)

**Cost:** Mutation testing is expensive. Run on targeted methods, not entire classes. A 500-line model can take 30+ minutes. Use on the highest-risk code paths first.

## 7d. Flaky Test Prevention Checklist

Beyond parallel safety (Phase 5), check for these flakiness sources in EVERY split file:

| Source | Pattern | Fix |
|--------|---------|-----|
| **Time dependency** | `expect(record.created_at).to eq(Time.current)` | Use `be_within(5.seconds).of(Time.current)` |
| **Ordering dependency** | `expect(results.first.name).to eq('Alice')` without ORDER BY | Add explicit `.order(:name)` in the query or test |
| **Count dependency** | `expect(Order.count).to eq(5)` | Use `change(Order, :count).by(1)` or scope to test records |
| **Sleep dependency** | `sleep 1; expect(record.reload.status).to eq('done')` | Use `Timeout.timeout` or poll with backoff |
| **Locale dependency** | String comparison that assumes English | Use I18n.t or match against the constant |
| **Timezone dependency** | `Date.today` vs `Time.current.to_date` | Always use `Time.current` (respects `Time.zone`) |
| **Random seed dependency** | `Array.sample` in setup producing different data | Use deterministic data or `srand` |
| **File system dependency** | `File.exist?` on temp files from prior test | Use `Dir.mktmpdir` with cleanup |

**After split, run 3x with different seeds to catch ordering-dependent flakes:**

```bash
bundle exec rspec spec/requests/orders_*_spec.rb --seed 12345
bundle exec rspec spec/requests/orders_*_spec.rb --seed 54321
bundle exec rspec spec/requests/orders_*_spec.rb --seed 99999
```

If any seed fails but others pass, you have an ordering dependency. Use `--bisect` to find it.

## 7e. N+1 Query Detection

If the project uses `bullet` or `prosopite`, enable during the split file test runs:

```bash
BULLET=true bundle exec rspec spec/requests/orders_*_spec.rb
```

N+1 queries in the production code are often invisible in monolith spec files because eager loading from one test "accidentally" pre-loads associations for another test. After the split, each file runs independently — N+1s that were masked by coincidental eager loading will surface.

**If N+1s appear after the split:**
- They are NOT regressions — they were always there, just hidden
- Card them as WARNING-level findings
- Fix by adding `includes()` or `eager_load()` to the controller query
- Do NOT suppress them by adding eager loading to the test setup
