"""Tests for the part mapping in parts.py."""

import os
import tempfile
import unittest

import parts


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


if __name__ == "__main__":
    unittest.main()
