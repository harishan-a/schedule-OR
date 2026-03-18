# Contributing to OR Scheduler

Thank you for your interest in contributing! This guide will help you get started.

## How to Contribute

1. **Fork** the repository
2. **Create a branch** from `main` for your changes
3. **Make your changes** following the code style guidelines below
4. **Run checks** to make sure everything passes:
   ```bash
   make check    # Runs analyze + test + format check
   ```
5. **Open a pull request** against `main`

## Development Setup

See [DEVELOPMENT.md](DEVELOPMENT.md) for full instructions on setting up the local development environment with Firebase emulators.

```bash
make setup    # Install dependencies
make dev      # Start emulators + seed + run app
```

## Code Style

- Follow the rules in `analysis_options.yaml`
- Run `dart format .` before committing
- Use feature-first organization — new features go in `lib/features/<feature>/`
- Follow the existing MVVM pattern: screens, viewmodels, repositories, services

## Commit Messages

Use clear, descriptive commit messages:

```
Add patient search to staff directory

Update conflict detection to check equipment overlap

Fix month view not showing weekend surgeries
```

## Pull Request Process

1. Ensure `flutter analyze` reports no issues
2. Ensure `flutter test` passes
3. Run `dart format .` to format all code
4. Update documentation if your changes affect setup or usage
5. Fill out the PR template with a summary and test plan

## Reporting Bugs

Please use the [bug report template](https://github.com/harishan-a/schedule-OR/issues/new?template=bug_report.md) when filing issues. Include steps to reproduce, expected behavior, and your environment details.

## Questions?

Open a [GitHub Discussion](https://github.com/harishan-a/schedule-OR/discussions) or file an issue if something is unclear.
