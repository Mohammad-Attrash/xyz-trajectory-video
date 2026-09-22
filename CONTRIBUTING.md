# Contributing

Thank you for considering a contribution to the XYZ Trajectory Video Generator.

## Suitable contributions

Contributions may include:

- bug reports;
- corrections to documentation;
- support for additional chemical elements;
- improved rendering performance;
- optional periodic-boundary bond detection;
- additional video formats;
- tests using small XYZ trajectories; and
- accessibility or usability improvements.

## Reporting a bug

Please open a GitHub issue and include:

1. the operating system;
2. the Python version;
3. package versions from `python -m pip freeze`;
4. the exact command used;
5. the complete error message; and
6. a minimal XYZ file that reproduces the problem, when sharing the structure is permitted.

Do not upload confidential or unpublished simulation data without permission.

## Proposing a change

1. Fork the repository.
2. Create a branch with a descriptive name.
3. Make the change.
4. Test the program on a small multi-frame XYZ file.
5. Confirm that an MP4 file is created and that both views render correctly.
6. Update the README or changelog when behavior changes.
7. Open a pull request describing the reason for the change.

## Coding style

- Use clear function and variable names.
- Follow PEP 8 where practical.
- Add type annotations to new public functions.
- Keep visualization parameters near the beginning of `xyz_to_video()`.
- Avoid introducing a required dependency unless the feature justifies it.

## Scientific interpretation

Rendering radii and distance cutoffs are visualization parameters. Contributions should not describe automatically detected lines as definitive chemical bonds unless an explicit chemically grounded criterion is implemented and documented.

## License

By contributing, you agree that your contribution will be distributed under the repository's MIT License.
