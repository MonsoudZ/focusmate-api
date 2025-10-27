# Test Coverage

This project uses SimpleCov to track test coverage and prevent regressions.

## Current Status

- **Line Coverage**: 60.68% (2438 / 4018 lines)
- **Branch Coverage**: 60.85% (726 / 1193 branches)
- **Minimum Coverage Threshold**: 60%

## Coverage Gates

The test suite will fail if coverage drops below the configured thresholds:

- **Overall Coverage**: Must be at least 60%
- **Per-file Coverage**: Currently disabled (some files have 0% coverage)

## Viewing Coverage Reports

After running tests, open the coverage report:

```bash
open coverage/index.html
```

## Increasing Coverage

To increase coverage thresholds over time:

1. **Identify low-coverage files** in the coverage report
2. **Add tests** for uncovered code paths
3. **Gradually increase thresholds** in `spec/spec_helper.rb`:

```ruby
# Example progression:
minimum_coverage 60  # Current
minimum_coverage 65  # Next milestone
minimum_coverage 70  # Target
minimum_coverage 80  # Stretch goal
```

## CI Integration

The coverage gates are automatically enforced in CI:

- **Pass**: Coverage meets or exceeds thresholds
- **Fail**: Coverage drops below thresholds (exit code 2)

This prevents regressions from being merged into the main branch.

## Files Excluded from Coverage

The following directories are filtered out:
- `bin/` - Executable scripts
- `db/` - Database migrations and seeds
- `config/` - Configuration files
- `vendor/` - Third-party dependencies
