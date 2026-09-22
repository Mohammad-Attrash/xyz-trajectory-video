# XYZ Trajectory Video Generator

Create publication-quality, dual-view MP4 videos from multi-frame XYZ trajectories.

The program renders:

- exact top and side views;
- smooth three-dimensional atomic spheres;
- element-specific atom colors;
- two-colored bonds based on the connected atoms;
- bonds visible only between atomic surfaces;
- fixed trajectory-wide coordinate limits;
- independent side-view magnification; and
- optional frame number and simulation time.

## Example output

Add a screenshot or animated preview here after creating the repository:

```markdown
![Example dual-view trajectory](docs/example_frame.png)
```

## Requirements

- Python 3.10 or newer
- NumPy
- Matplotlib
- imageio
- imageio-ffmpeg

FFmpeg is supplied through `imageio-ffmpeg` in most installations.

## Installation

### Option 1: Install from the repository

```bash
git clone https://github.com/Mohammad-Attrash/xyz-trajectory-video.git
cd xyz-trajectory-video
python -m pip install -r requirements.txt
```

### Option 2: Install in an isolated virtual environment

#### Windows

```bash
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

#### Linux or macOS

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## Usage

### Command line

```bash
python xyz_to_video.py trajectory.xyz
```

Example:

```bash
python xyz_to_video.py "MD1-60eV-pos-1.xyz"
```

The output is saved beside the input file:

```text
MD1-60eV-pos-1.xyz  ->  MD1-60eV-pos-1.mp4
```

### From another Python script

```python
from xyz_to_video import xyz_to_video

output_video = xyz_to_video("MD1-60eV-pos-1.xyz")
print(output_video)
```

### Process every XYZ file in a folder

```python
from pathlib import Path
from xyz_to_video import xyz_to_video

folder = Path(r"D:\CP2K\trajectories")

for xyz_file in folder.glob("*.xyz"):
    xyz_to_video(xyz_file)
```

## XYZ format

The input must be a standard multi-frame XYZ trajectory:

```text
3
Frame 1
O  0.0000  0.0000  2.0000
O  1.2100  0.0000  2.0000
C  0.5000  0.5000  0.0000
3
Frame 2
O  0.0000  0.0000  1.8000
O  1.2500  0.0000  1.8500
C  0.5000  0.5000  0.0500
```

Each frame must contain:

1. the atom count;
2. one comment line; and
3. one line per atom containing the element symbol and Cartesian coordinates in angstrom.

## Main configuration controls

The settings are located near the beginning of `xyz_to_video()`.

### Video speed and frame selection

```python
fps = 10
frame_stride = 1
```

For a faster preview:

```python
frame_stride = 5
```

### Simulation time

```python
time_per_xyz_frame_fs = 2.5
```

For example, a 0.5 fs molecular-dynamics timestep with coordinates written every five steps gives 2.5 fs between saved XYZ frames.

### Atom size

```python
atom_radii = {
    "C": 0.47,
    "O": 0.50,
    "N": 0.45,
    "H": 0.25,
}
```

### Sphere smoothness

```python
sphere_resolution = 24
```

Suggested values:

- `12` for a fast preview;
- `18` for a balanced result;
- `24` for the final video; and
- `32` for very smooth spheres at higher rendering cost.

### Side-view size

```python
side_view_zoom = 0.65
```

Values below `1.0` make the structure smaller inside the unchanged side-view panel.

### Bond appearance

```python
bond_line_width = 4.0
use_atom_colored_bonds = True
bond_surface_factor = 0.88
```

### Bond cutoffs

Bond detection is distance-based and can be edited for each element pair:

```python
bond_cutoffs = {
    frozenset(("C", "C")): 1.75,
    frozenset(("C", "O")): 1.85,
    frozenset(("O", "O")): 1.70,
}
```

These cutoffs are visualization criteria and should not be interpreted automatically as rigorous chemical bond definitions.

## Repository structure

```text
xyz-trajectory-video/
├── xyz_to_video.py
├── README.md
├── requirements.txt
├── pyproject.toml
├── CITATION.cff
├── LICENSE
├── CONTRIBUTING.md
├── CHANGELOG.md
├── .gitignore
└── examples/
    └── example_trajectory.xyz
```

## Reproducibility notes

- The same coordinate limits are used for every frame to prevent visual jumping.
- Bond connectivity is recalculated for every frame.
- The rendered atomic radii are visualization parameters rather than covalent or van der Waals radii.
- The program does not account for periodic boundary conditions when detecting bonds.
- For periodic structures, atoms should be wrapped or unwrapped appropriately before visualization.

## Citation

If this program contributes to a publication, cite the archived software release rather than only the moving GitHub branch. After connecting the repository to Zenodo and creating a release, replace the placeholder DOI in `CITATION.cff` and this section.

Suggested citation format:

> Attrash, M. (2026). *XYZ Trajectory Video Generator* (Version 1.0.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

## Creating a DOI

1. Create a public GitHub repository.
2. Upload all repository files.
3. Create a Zenodo account and connect Zenodo to GitHub.
4. Enable archiving for the repository in Zenodo.
5. Create a GitHub release, for example `v1.0.0`.
6. Zenodo will archive the release and assign a version-specific DOI.
7. Update `CITATION.cff`, this README, and the repository metadata with the DOI.
8. Commit the DOI update and create a small follow-up release if desired.

## License

This project is distributed under the MIT License. See [LICENSE](LICENSE).

## Contributing

Bug reports, documentation corrections, and improvements are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Author

Mohammad Attrash
