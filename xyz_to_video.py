from __future__ import annotations

import argparse
import warnings
from dataclasses import dataclass
from pathlib import Path

import imageio.v2 as imageio
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


@dataclass
class XYZFrame:
    symbols: list[str]
    coordinates: np.ndarray
    comment: str


def xyz_to_video(xyz_file: str | Path) -> Path:
    """Create a dual-view ball-and-stick MP4 from a multi-frame XYZ file."""

    # ---------------- Video settings ----------------
    fps = 10
    frame_stride = 1
    video_crf = 18
    final_frame_hold_s = 1.0
    figure_width = 1600
    figure_height = 800
    figure_dpi = 100

    # ---------------- Time settings ----------------
    show_time = True
    time_per_xyz_frame_fs = 2.5

    # ---------------- Atom appearance ----------------
    atom_radii = {
        "C": 0.47,
        "O": 0.50,
        "N": 0.45,
        "H": 0.25,
    }
    other_radius_a = 0.40
    sphere_resolution = 24

    atom_colors = {
        "C": (0.22, 0.22, 0.22),
        "O": (0.92, 0.02, 0.02),
        "N": (0.05, 0.05, 0.60),
        "H": (0.95, 0.95, 0.95),
    }
    other_color = (0.85, 0.10, 0.85)

    # Virtual light direction used to shade spheres.
    light_azimuth_deg = 315.0
    light_altitude_deg = 45.0

    # ---------------- Bond appearance ----------------
    fallback_bond_color = (0.15, 0.15, 0.15)
    bond_line_width = 4.0
    use_atom_colored_bonds = True
    bond_surface_factor = 0.88

    # ---------------- Bond cutoffs ----------------
    use_element_specific_cutoffs = True
    default_bond_cutoff_a = 1.65
    bond_cutoffs = {
        frozenset(("C", "C")): 1.75,
        frozenset(("C", "O")): 1.85,
        frozenset(("O", "O")): 1.70,
        frozenset(("C", "H")): 1.25,
        frozenset(("O", "H")): 1.25,
        frozenset(("N", "H")): 1.25,
        frozenset(("C", "N")): 1.75,
        frozenset(("N", "O")): 1.75,
    }
    maximum_bonds_per_frame = 1500

    # ---------------- Coordinate display ----------------
    axis_margin_a = 0.55
    use_manual_limits = False
    manual_x_limits = (-7.0, 7.0)
    manual_y_limits = (-6.0, 6.0)
    manual_z_limits = (0.0, 24.0)

    # ---------------- Views ----------------
    top_azimuth = 0.0
    top_elevation = 90.0
    side_azimuth = 0.0
    side_elevation = 0.0
    top_view_title = "Top view"
    side_view_title = "Side view"
    use_orthographic_projection = True
    background_color = (1.0, 1.0, 1.0)
    title_font_size = 16
    main_title_font_size = 17

    # Values below 1 make only the side-view model smaller.
    side_view_zoom = 0.65

    # Equal-sized panels with almost no central gap.
    top_axis_position = [0.005, 0.06, 0.495, 0.86]
    side_axis_position = [0.500, 0.06, 0.495, 0.86]

    xyz_path = Path(xyz_file).expanduser().resolve()
    if not xyz_path.exists():
        raise FileNotFoundError(f"The XYZ file does not exist: {xyz_path}")
    if xyz_path.suffix.lower() != ".xyz":
        raise ValueError(f"The input file must have an .xyz extension: {xyz_path}")

    output_video = xyz_path.with_suffix(".mp4")
    base_name = xyz_path.stem

    print()
    print("=" * 60)
    print("XYZ trajectory video generator")
    print("=" * 60)
    print(f"Input file:      {xyz_path}")
    print(f"Output file:     {output_video}")
    print(f"Side-view zoom:  {side_view_zoom:.2f}")
    print("=" * 60)

    frames = read_xyz_trajectory(xyz_path)
    if not frames:
        raise RuntimeError(f"No valid XYZ frames were found in {xyz_path}")

    original_number_frames = len(frames)
    selected_original_indices = list(range(0, original_number_frames, frame_stride))
    frames = [frames[index] for index in selected_original_indices]

    reference_atom_count = len(frames[0].symbols)
    reference_symbols = frames[0].symbols

    validated_frames: list[XYZFrame] = []
    validated_original_indices: list[int] = []

    for selected_index, frame in enumerate(frames):
        if len(frame.symbols) != reference_atom_count:
            warnings.warn(
                f"Selected frame {selected_index + 1} has {len(frame.symbols)} atoms "
                f"instead of {reference_atom_count}; skipping it."
            )
            continue
        if frame.symbols != reference_symbols:
            warnings.warn(
                f"Element ordering differs in selected frame {selected_index + 1}; "
                "the frame will still be processed."
            )
        validated_frames.append(frame)
        validated_original_indices.append(selected_original_indices[selected_index])

    frames = validated_frames
    selected_original_indices = validated_original_indices
    number_frames = len(frames)

    if number_frames == 0:
        raise RuntimeError("No valid and consistent XYZ frames remain.")

    print(f"Original frames: {original_number_frames}")
    print(f"Frames selected: {number_frames}")
    print(f"Atoms per frame: {reference_atom_count}")

    all_coordinates = np.concatenate([frame.coordinates for frame in frames], axis=0)

    if use_manual_limits:
        x_limits = manual_x_limits
        y_limits = manual_y_limits
        z_limits = manual_z_limits
    else:
        largest_radius = max([*atom_radii.values(), other_radius_a])
        total_margin = axis_margin_a + largest_radius
        x_limits = (
            float(np.min(all_coordinates[:, 0]) - total_margin),
            float(np.max(all_coordinates[:, 0]) + total_margin),
        )
        y_limits = (
            float(np.min(all_coordinates[:, 1]) - total_margin),
            float(np.max(all_coordinates[:, 1]) + total_margin),
        )
        z_limits = (
            float(np.min(all_coordinates[:, 2]) - total_margin),
            float(np.max(all_coordinates[:, 2]) + total_margin),
        )

    x_limits = ensure_valid_limits(x_limits)
    y_limits = ensure_valid_limits(y_limits)
    z_limits = ensure_valid_limits(z_limits)

    print(f"x range: {x_limits[0]:.3f} to {x_limits[1]:.3f} Angstrom")
    print(f"y range: {y_limits[0]:.3f} to {y_limits[1]:.3f} Angstrom")
    print(f"z range: {z_limits[0]:.3f} to {z_limits[1]:.3f} Angstrom")

    print("Precomputing bonds...")
    all_bond_pairs: list[list[tuple[int, int]]] = []

    for frame_number, frame in enumerate(frames, start=1):
        bond_pairs = calculate_bond_pairs(
            coordinates=frame.coordinates,
            symbols=frame.symbols,
            use_element_specific_cutoffs=use_element_specific_cutoffs,
            default_bond_cutoff_a=default_bond_cutoff_a,
            bond_cutoffs=bond_cutoffs,
        )
        if len(bond_pairs) > maximum_bonds_per_frame:
            warnings.warn(
                f"Frame {frame_number} has {len(bond_pairs)} proposed bonds; "
                f"only the first {maximum_bonds_per_frame} will be shown."
            )
            bond_pairs = bond_pairs[:maximum_bonds_per_frame]
        all_bond_pairs.append(bond_pairs)

    unit_sphere = create_unit_sphere(sphere_resolution)

    writer = imageio.get_writer(
        str(output_video),
        fps=fps,
        codec="libx264",
        pixelformat="yuv420p",
        macro_block_size=8,
        ffmpeg_params=["-crf", str(video_crf), "-preset", "medium"],
    )

    final_rendered_frame: np.ndarray | None = None

    try:
        for frame_index, frame in enumerate(frames):
            if frame_index == 0 or (frame_index + 1) % 10 == 0 or frame_index == number_frames - 1:
                print(f"Writing frame {frame_index + 1} of {number_frames}")

            coordinates = frame.coordinates
            symbols = frame.symbols
            bond_pairs = all_bond_pairs[frame_index]

            figure = plt.figure(
                figsize=(figure_width / figure_dpi, figure_height / figure_dpi),
                dpi=figure_dpi,
                facecolor=background_color,
            )
            top_axis = figure.add_axes(top_axis_position, projection="3d")
            side_axis = figure.add_axes(side_axis_position, projection="3d")

            draw_atomic_structure(
                top_axis,
                coordinates,
                symbols,
                bond_pairs,
                atom_colors,
                other_color,
                atom_radii,
                other_radius_a,
                unit_sphere,
                fallback_bond_color,
                bond_line_width,
                bond_surface_factor,
                use_atom_colored_bonds,
                light_azimuth_deg,
                light_altitude_deg,
            )
            configure_axis(
                top_axis,
                x_limits,
                y_limits,
                z_limits,
                top_azimuth,
                top_elevation,
                top_view_title,
                title_font_size,
                background_color,
                use_orthographic_projection,
                1.0,
            )

            draw_atomic_structure(
                side_axis,
                coordinates,
                symbols,
                bond_pairs,
                atom_colors,
                other_color,
                atom_radii,
                other_radius_a,
                unit_sphere,
                fallback_bond_color,
                bond_line_width,
                bond_surface_factor,
                use_atom_colored_bonds,
                light_azimuth_deg,
                light_altitude_deg,
            )
            configure_axis(
                side_axis,
                x_limits,
                y_limits,
                z_limits,
                side_azimuth,
                side_elevation,
                side_view_title,
                title_font_size,
                background_color,
                use_orthographic_projection,
                side_view_zoom,
            )

            if show_time:
                original_frame_index = selected_original_indices[frame_index]
                current_time_fs = original_frame_index * time_per_xyz_frame_fs
                main_title = (
                    f"{base_name} | Frame {frame_index + 1}/{number_frames} | "
                    f"Time = {current_time_fs:.1f} fs"
                )
            else:
                main_title = f"{base_name} | Frame {frame_index + 1}/{number_frames}"

            figure.suptitle(
                main_title,
                fontsize=main_title_font_size,
                fontweight="bold",
                y=0.985,
            )
            figure.canvas.draw()
            rendered_frame = np.asarray(figure.canvas.buffer_rgba())[:, :, :3].copy()
            writer.append_data(rendered_frame)

            if frame_index == number_frames - 1:
                final_rendered_frame = rendered_frame

            plt.close(figure)

        if final_rendered_frame is not None:
            for _ in range(round(final_frame_hold_s * fps)):
                writer.append_data(final_rendered_frame)

    finally:
        writer.close()
        plt.close("all")

    print("=" * 60)
    print("Video completed successfully:")
    print(output_video)
    print("=" * 60)
    return output_video


def read_xyz_trajectory(filename: Path) -> list[XYZFrame]:
    """Read valid frames from a standard multi-frame XYZ file."""

    frames: list[XYZFrame] = []

    with filename.open("r", encoding="utf-8", errors="replace") as stream:
        while True:
            first_line = stream.readline()
            if first_line == "":
                break
            first_line = first_line.strip()
            if not first_line:
                continue

            try:
                number_atoms = int(first_line)
            except ValueError:
                continue

            if number_atoms <= 0:
                continue

            comment_line = stream.readline()
            if comment_line == "":
                break

            symbols: list[str] = []
            coordinates: list[list[float]] = []
            valid_frame = True

            for _ in range(number_atoms):
                atom_line = stream.readline()
                if atom_line == "":
                    valid_frame = False
                    break

                parts = atom_line.split()
                if len(parts) < 4:
                    valid_frame = False
                    break

                try:
                    xyz = [float(parts[1]), float(parts[2]), float(parts[3])]
                except ValueError:
                    valid_frame = False
                    break

                if not np.all(np.isfinite(xyz)):
                    valid_frame = False
                    break

                symbols.append(parts[0])
                coordinates.append(xyz)

            if valid_frame and len(symbols) == number_atoms:
                frames.append(
                    XYZFrame(
                        symbols=symbols,
                        coordinates=np.asarray(coordinates, dtype=float),
                        comment=comment_line.strip(),
                    )
                )

    return frames


def calculate_bond_pairs(
    coordinates: np.ndarray,
    symbols: list[str],
    use_element_specific_cutoffs: bool,
    default_bond_cutoff_a: float,
    bond_cutoffs: dict[frozenset[str], float],
) -> list[tuple[int, int]]:
    """Calculate visualization bonds from interatomic distances."""

    pairs: list[tuple[int, int]] = []
    number_atoms = coordinates.shape[0]

    for atom_1 in range(number_atoms - 1):
        displacements = coordinates[atom_1 + 1 :] - coordinates[atom_1]
        distances = np.linalg.norm(displacements, axis=1)

        for offset, distance in enumerate(distances):
            atom_2 = atom_1 + 1 + offset
            if use_element_specific_cutoffs:
                pair = frozenset(
                    (symbols[atom_1].strip().upper(), symbols[atom_2].strip().upper())
                )
                cutoff = bond_cutoffs.get(pair, default_bond_cutoff_a)
            else:
                cutoff = default_bond_cutoff_a

            if distance <= cutoff:
                pairs.append((atom_1, atom_2))

    return pairs


def create_unit_sphere(resolution: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Create a reusable smooth unit-sphere mesh."""

    azimuth = np.linspace(0.0, 2.0 * np.pi, 2 * resolution + 1)
    polar = np.linspace(0.0, np.pi, resolution + 1)
    azimuth_grid, polar_grid = np.meshgrid(azimuth, polar)

    unit_x = np.cos(azimuth_grid) * np.sin(polar_grid)
    unit_y = np.sin(azimuth_grid) * np.sin(polar_grid)
    unit_z = np.cos(polar_grid)
    return unit_x, unit_y, unit_z


def draw_atomic_structure(
    axis_handle,
    coordinates: np.ndarray,
    symbols: list[str],
    bond_pairs: list[tuple[int, int]],
    atom_colors: dict[str, tuple[float, float, float]],
    other_color: tuple[float, float, float],
    atom_radii: dict[str, float],
    other_radius_a: float,
    unit_sphere: tuple[np.ndarray, np.ndarray, np.ndarray],
    fallback_bond_color: tuple[float, float, float],
    bond_line_width: float,
    bond_surface_factor: float,
    use_atom_colored_bonds: bool,
    light_azimuth_deg: float,
    light_altitude_deg: float,
) -> None:
    """Draw bonds first and illuminated atom spheres afterward."""

    for atom_1, atom_2 in bond_pairs:
        point_1 = coordinates[atom_1]
        point_2 = coordinates[atom_2]
        vector = point_2 - point_1
        length = np.linalg.norm(vector)
        if length < 1.0e-12:
            continue

        direction = vector / length
        radius_1 = get_element_radius(symbols[atom_1], atom_radii, other_radius_a)
        radius_2 = get_element_radius(symbols[atom_2], atom_radii, other_radius_a)
        start = point_1 + bond_surface_factor * radius_1 * direction
        end = point_2 - bond_surface_factor * radius_2 * direction

        if np.dot(end - start, direction) <= 0:
            continue

        middle = 0.5 * (start + end)
        if use_atom_colored_bonds:
            color_1 = get_element_color(symbols[atom_1], atom_colors, other_color)
            color_2 = get_element_color(symbols[atom_2], atom_colors, other_color)
        else:
            color_1 = fallback_bond_color
            color_2 = fallback_bond_color

        axis_handle.plot(
            [start[0], middle[0]],
            [start[1], middle[1]],
            [start[2], middle[2]],
            color=color_1,
            linewidth=bond_line_width,
            solid_capstyle="round",
            antialiased=True,
        )
        axis_handle.plot(
            [middle[0], end[0]],
            [middle[1], end[1]],
            [middle[2], end[2]],
            color=color_2,
            linewidth=bond_line_width,
            solid_capstyle="round",
            antialiased=True,
        )

    unit_x, unit_y, unit_z = unit_sphere

    for atom_index, center in enumerate(coordinates):
        color = get_element_color(symbols[atom_index], atom_colors, other_color)
        radius = get_element_radius(symbols[atom_index], atom_radii, other_radius_a)
        sphere_x = center[0] + radius * unit_x
        sphere_y = center[1] + radius * unit_y
        sphere_z = center[2] + radius * unit_z

        face_colors = create_sphere_face_colors(
            unit_x,
            unit_y,
            unit_z,
            color,
            light_azimuth_deg,
            light_altitude_deg,
        )
        axis_handle.plot_surface(
            sphere_x,
            sphere_y,
            sphere_z,
            facecolors=face_colors,
            rstride=1,
            cstride=1,
            linewidth=0,
            edgecolor="none",
            antialiased=True,
            shade=False,
        )


def create_sphere_face_colors(
    unit_x: np.ndarray,
    unit_y: np.ndarray,
    unit_z: np.ndarray,
    base_color: tuple[float, float, float],
    light_azimuth_deg: float,
    light_altitude_deg: float,
) -> np.ndarray:
    """Create soft illumination while preserving element colors."""

    azimuth = np.deg2rad(light_azimuth_deg)
    altitude = np.deg2rad(light_altitude_deg)
    light_direction = np.array(
        [
            np.cos(altitude) * np.cos(azimuth),
            np.cos(altitude) * np.sin(azimuth),
            np.sin(altitude),
        ]
    )

    diffuse = np.clip(
        unit_x * light_direction[0]
        + unit_y * light_direction[1]
        + unit_z * light_direction[2],
        0.0,
        1.0,
    )
    intensity = 0.34 + 0.66 * diffuse
    rgb = np.asarray(base_color, dtype=float)
    colors = np.empty(unit_x.shape + (4,), dtype=float)

    for channel in range(3):
        colors[..., channel] = np.clip(rgb[channel] * intensity, 0.0, 1.0)

    highlight = np.power(diffuse, 20.0) * 0.24
    colors[..., :3] = np.clip(colors[..., :3] + highlight[..., None], 0.0, 1.0)
    colors[..., 3] = 1.0
    return colors


def configure_axis(
    axis_handle,
    x_limits: tuple[float, float],
    y_limits: tuple[float, float],
    z_limits: tuple[float, float],
    azimuth_deg: float,
    elevation_deg: float,
    title: str,
    title_font_size: int,
    background_color: tuple[float, float, float],
    orthographic: bool,
    box_zoom: float,
) -> None:
    """Configure one exact orthographic or perspective 3D view."""

    axis_handle.set_xlim(*x_limits)
    axis_handle.set_ylim(*y_limits)
    axis_handle.set_zlim(*z_limits)
    axis_handle.view_init(elev=elevation_deg, azim=azimuth_deg)
    axis_handle.set_proj_type("ortho" if orthographic else "persp")

    ranges = (
        x_limits[1] - x_limits[0],
        y_limits[1] - y_limits[0],
        z_limits[1] - z_limits[0],
    )

    try:
        axis_handle.set_box_aspect(ranges, zoom=box_zoom)
    except TypeError:
        axis_handle.set_box_aspect(ranges)
        if box_zoom != 1.0:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                try:
                    axis_handle.dist = axis_handle.dist / box_zoom
                except Exception:
                    pass

    axis_handle.set_facecolor(background_color)
    axis_handle.set_axis_off()
    axis_handle.set_title(title, fontsize=title_font_size, fontweight="bold", pad=2)


def get_element_color(
    element_symbol: str,
    atom_colors: dict[str, tuple[float, float, float]],
    other_color: tuple[float, float, float],
) -> tuple[float, float, float]:
    return atom_colors.get(element_symbol.strip().upper(), other_color)


def get_element_radius(
    element_symbol: str,
    atom_radii: dict[str, float],
    other_radius_a: float,
) -> float:
    return atom_radii.get(element_symbol.strip().upper(), other_radius_a)


def ensure_valid_limits(limits: tuple[float, float]) -> tuple[float, float]:
    minimum_value, maximum_value = limits
    if maximum_value - minimum_value < 0.1:
        center = 0.5 * (minimum_value + maximum_value)
        return center - 1.0, center + 1.0
    return minimum_value, maximum_value


def select_xyz_file() -> Path | None:
    """Open a graphical file selector for Spyder or other IDEs."""

    try:
        from tkinter import Tk, filedialog

        root = Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        root.update()
        selected_file = filedialog.askopenfilename(
            title="Select a multi-frame XYZ trajectory",
            filetypes=[
                ("XYZ trajectory files", "*.xyz"),
                ("All files", "*.*"),
            ],
        )
        root.destroy()
    except Exception as error:
        raise RuntimeError(
            "The XYZ file-selection dialog could not be opened. "
            "Supply the XYZ filename as a command-line argument instead."
        ) from error

    return Path(selected_file) if selected_file else None


def main() -> None:
    """Run from Spyder, another IDE, or a command-line terminal."""

    parser = argparse.ArgumentParser(
        description="Create a dual-view MP4 video from a multi-frame XYZ trajectory."
    )
    parser.add_argument(
        "xyz_file",
        nargs="?",
        type=Path,
        default=None,
        help="XYZ trajectory path. If omitted, a file-selection window opens.",
    )

    # Spyder/IPython can pass unrelated options, so ignore unknown arguments.
    arguments, unknown_arguments = parser.parse_known_args()
    if unknown_arguments:
        print("Ignoring unrelated IDE arguments: " + " ".join(unknown_arguments))

    xyz_file = arguments.xyz_file
    if xyz_file is None:
        xyz_file = select_xyz_file()

    if xyz_file is None:
        print("No XYZ file was selected. Nothing was generated.")
        return

    output_video = xyz_to_video(xyz_file)
    print()
    print("Generated video:")
    print(output_video)


if __name__ == "__main__":
    main()
