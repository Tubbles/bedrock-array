"""Tests for the part mapping in parts.py."""

import math
import os
import tempfile
import unittest

import parts


def grid_panel(centre, half_size, surface, step=0.0005):
    """Return a square grid of positions around the centre in x and y at the height the surface gives."""
    count = round(2 * half_size / step)
    positions = []
    for row in range(count + 1):
        for column in range(count + 1):
            x, y = centre[0] - half_size + column * step, centre[1] - half_size + row * step
            positions.append((x, y, surface(x, y)))
    return positions


class PartsTest(unittest.TestCase):
    def test_turn_brings_the_front_to_plus_z(self):
        fronts = {"+x": (1, 0, 0), "-x": (-1, 0, 0), "+z": (0, 0, 1), "-z": (0, 0, -1)}
        for front, axis in fronts.items():
            self.assertEqual(parts.turn(front, axis), (0, 0, 1), front)
            self.assertEqual(parts.turn(front, (0, 1, 0)), (0, 1, 0), front)

    def test_assign_prefers_the_override(self):
        result = parts.assign("part_0", {"part_0": "lid"}, ["body", "lid"], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0])
        self.assertEqual(result, ("lid", "override"))

    def test_assign_picks_the_largest_share(self):
        positions = [(0, 0, 0), (0.1, 0, 0), (2, 0, 0)]
        body = [((0, 0, 0), (0.1, 0.1, 0.1))]
        lid = [((2, 0, 0), (0.1, 0.1, 0.1))]
        shares = [parts.share_inside(positions, boxes, 0.06) for boxes in (body, lid)]
        self.assertEqual(parts.assign("part_0", {}, ["body", "lid"], shares, [0.0, 0.0], [1.0, 1.0]), ("body", "share"))

    def test_assign_breaks_a_tie_by_the_smaller_blockout(self):
        volumes = [parts.blockout_volume([((0, 0, 0), (1, 1, 1))]), parts.blockout_volume([((0, 0, 0), (0.5, 0.5, 0.5))])]
        self.assertEqual(parts.assign("part_0", {}, ["body", "hearth"], [1.0, 1.0], [0.0, 0.0], volumes), ("hearth", "share"))

    def test_assign_falls_back_to_the_nearest_box(self):
        centre = (5, 0, 0)
        boxes = [[((0, 0, 0), (1, 1, 1))], [((4, 0, 0), (1, 1, 1)), ((9, 0, 0), (1, 1, 1))]]
        distances = [parts.nearest_box_distance(centre, part_boxes) for part_boxes in boxes]
        self.assertEqual(parts.assign("part_0", {}, ["body", "lid"], [0.0, 0.0], distances, [1.0, 1.0]), ("lid", "nearest"))

    def test_write_ply_round_trips_the_header_and_counts(self):
        vertices = [((0, 0, 0), (0, 1, 0)), ((1, 0, 0), (0, 1, 0)), ((0, 0, 1), (0, 1, 0)), ((1, 0, 1), (0, 1, 0))]
        indices = [0, 1, 2, 1, 3, 2]
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "part.ply")
            parts.write_ply(path, vertices, indices)
            with open(path, "rb") as source:
                data = source.read()
        header_end = data.index(b"end_header\n") + len(b"end_header\n")
        header = data[:header_end].decode("ascii").splitlines()
        self.assertEqual(header[1], "format binary_little_endian 1.0")
        self.assertIn("element vertex 4", header)
        self.assertIn("element face 2", header)
        self.assertEqual(len(data) - header_end, 4 * 6 * 4 + 2 * (1 + 3 * 4))

    def test_closing_defaults_to_poisson(self):
        closings = {"fittings": "none"}
        self.assertEqual(parts.closing_for(closings, "body"), "poisson")
        self.assertEqual(parts.closing_for(closings, "fittings"), "none")
        with self.assertRaises(SystemExit):
            parts.closing_for({"body": "voxel"}, "body")

    def test_panel_level_is_the_median_of_the_outer_ring(self):
        origin = (0.3, 0.2, 0.5)

        def surface(x, y):
            distance = math.hypot(x - origin[0], y - origin[1])
            return origin[2] - (0.01 if distance < 0.012 else 0.0) + (0.002 if distance > 0.016 else 0.0)

        panel = grid_panel(origin, 0.03, surface)
        back = grid_panel(origin, 0.03, lambda x, y: origin[2] - 0.5)
        self.assertAlmostEqual(parts.panel_level(origin, "+z", panel + back), 0.5)

    def test_cut_radius_finds_the_recess_floor(self):
        origin = (0.0, 0.0, 0.0)

        def surface(x, y):
            distance = 1000 * math.hypot(x, y)
            if distance < 6:
                return -0.001
            if distance < 10.5:
                return -0.001 - 0.005 * (distance - 6) / 4.5
            return min(0.0, -0.006 + 0.006 * (distance - 10.5) / 3.5)

        radius, half_radius, floor_radius = parts.cut_radius(origin, "+z", grid_panel(origin, 0.03, surface))
        self.assertAlmostEqual(half_radius, 0.0085)
        self.assertAlmostEqual(floor_radius, 0.0105)
        self.assertAlmostEqual(radius, 0.0095)

    def test_cut_radius_fails_without_a_screw(self):
        with self.assertRaises(SystemExit):
            parts.cut_radius((0.0, 0.0, 0.0), "+z", grid_panel((0.0, 0.0, 0.0), 0.03, lambda x, y: 0.0))

    def test_quarter_turn_between_facings(self):
        for source in ("+x", "-x", "+z", "-z", "+y"):
            for target in ("+x", "-x", "+z", "-z"):
                rotation = parts.quarter_turn(source, target)
                turned = parts.multiply(rotation, parts.facing_vector(source))
                self.assertEqual(tuple(round(value) for value in turned), parts.facing_vector(target), (source, target))
                if source != "+y":
                    self.assertEqual(tuple(round(value) for value in parts.multiply(rotation, (0, 1, 0))), (0, 1, 0), (source, target))
        self.assertEqual(parts.quarter_turn("-z", "-z"), ((1, 0, 0), (0, 1, 0), (0, 0, 1)))


if __name__ == "__main__":
    unittest.main()
