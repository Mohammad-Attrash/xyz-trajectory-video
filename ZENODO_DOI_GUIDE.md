# Creating a DOI for the Software

This checklist describes a practical GitHub-to-Zenodo release workflow.

## Before the first release

1. Put `xyz_to_video.py` and the companion repository files in a GitHub repository.
2. Replace every occurrence of `YOUR-USERNAME` with the GitHub account name.
3. Review the author spelling in `CITATION.cff`.
4. Add an ORCID to `CITATION.cff` if desired.
5. Confirm the version is `1.0.0` in both `pyproject.toml` and `CITATION.cff`.
6. Test installation in a clean virtual environment.
7. Test the example:

```bash
python xyz_to_video.py example_trajectory.xyz
```

## Connect GitHub and Zenodo

1. Sign in to Zenodo.
2. Open the GitHub integration page in the Zenodo account settings.
3. Authorize access to GitHub.
4. Enable archiving for the software repository.

## Create the release

1. In GitHub, open **Releases**.
2. Select **Draft a new release**.
3. Create the tag `v1.0.0`.
4. Use the release title `XYZ Trajectory Video Generator v1.0.0`.
5. Copy the version notes from `CHANGELOG.md`.
6. Publish the release.

Zenodo should archive the release and create a DOI. Zenodo may provide both a DOI for the specific software version and a concept DOI representing all versions. Use the version DOI when citing the exact release used in a study.

## After Zenodo creates the DOI

1. Replace the placeholder DOI in `CITATION.cff`.
2. Replace the placeholder citation in `README.md`.
3. Add a DOI badge near the top of `README.md`, for example:

```markdown
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
```

4. Commit the metadata update.
5. If needed, create a small metadata release such as `v1.0.1`.

## Suggested citation

```text
Attrash, M. (2026). XYZ Trajectory Video Generator (Version 1.0.0)
[Computer software]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX
```

## Manuscript wording

A Methods or Data Availability section could state:

> The Python program used to generate the dual-view XYZ trajectory videos is available from GitHub and archived in Zenodo under DOI: [insert DOI].
