# Contributing to TOONEncoder

Thank you for your interest in contributing to the official Swift implementation of TOON!

## Project Setup

This project uses Swift Package Manager for dependency management and build automation.

```bash
# Clone the repository
git clone https://github.com/toon-format/toon-swift.git
cd TOONEncoder

# Build the project
swift build

# Run tests
swift test

# Generate Xcode project (optional)
swift package generate-xcodeproj
```

## Development Workflow

1. **Fork the repository** and create a feature branch
2. **Make your changes** following the coding standards below
3. **Add tests** for any new functionality
4. **Ensure all tests pass** and follow existing patterns
5. **Submit a pull request** with a clear description

### New Features

1. **Open a discussion topic** about the new feature explaining the advantages or the motivation for this new feature.
2. **After approval** create an Issue linked to the discussion topic.
3. **Follow the development workflow** to implement the new feature.

### Bugs

1. **Open an issue** reporting the bug with detailed reproduction steps.

## Coding Standards

### Swift Version Support

This project requires Swift 6.0 and above.

### Code Style

- Follow standard Swift coding conventions
- Use meaningful variable and method names
- Keep methods focused and concise
- Add documentation comments for public APIs
- Format code consistently using the `.swift-format` configuration
  ```bash
  # Format code (if you have swift-format installed)
  swift-format format --in-place --recursive Sources/ Tests/
  ```

### Testing

- All new features must include tests using Swift Testing framework
- Tests should cover edge cases and spec compliance
- Run the full test suite:
  ```bash
  swift test

  # Verbose output
  swift test -v
  ```

### Build Tasks

Common Swift Package Manager commands you'll use:

```bash
# Build the project
swift build

# Run tests
swift test

# Run tests with verbose output
swift test -v

# Clean build artifacts
swift package clean

# Generate Xcode project
swift package generate-xcodeproj
```

## SPEC Compliance

All implementations must comply with the [TOON specification](https://github.com/toon-format/spec/blob/main/SPEC.md).

Before submitting changes that affect encoding/decoding behavior:

1. Verify against the official SPEC.md
2. Add tests for the specific spec sections you're implementing
3. Document any spec version requirements

## Pull Request Guidelines

- **Title**: Use a clear, descriptive title (e.g., "Add support for nested arrays", "Fix: Handle edge case in encoder")
- **Description**: Explain what changes you made and why
- **Tests**: Include tests for your changes
- **Documentation**: Update README or code comments if needed
- **Commits**: Use clear commit messages ([Conventional Commits](https://www.conventionalcommits.org/) preferred)

## Communication

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Pull Requests**: For code reviews and implementation discussion

## Maintainers

This project is maintained by:

- [@mattt](https://github.com/mattt)

For major architectural decisions, please open a discussion issue first.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
