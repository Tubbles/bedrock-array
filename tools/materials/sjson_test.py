"""Tests for the SJSON reader in sjson.py."""

import unittest

import sjson


class ParseTest(unittest.TestCase):
    def test_material_preset_without_commas(self):
        text = "painted_steel = { albedo = [0.20, 0.24, 0.30] roughness = 0.55 metallic = 0 }"
        expected = {"painted_steel": {"albedo": [0.20, 0.24, 0.30], "roughness": 0.55, "metallic": 0}}
        self.assertEqual(sjson.parse(text), expected)

    def test_comments(self):
        text = "// line comment\na = 1 /* block\ncomment */ b = 2 // trailing\n/**/c = 3"
        self.assertEqual(sjson.parse(text), {"a": 1, "b": 2, "c": 3})

    def test_quoted_key_with_colon(self):
        self.assertEqual(sjson.parse('"a key: with colon" : 1'), {"a key: with colon": 1})

    def test_nested_arrays(self):
        self.assertEqual(sjson.parse("grid = [[1 2] [3, 4], []]"), {"grid": [[1, 2], [3, 4], []]})

    def test_int_and_float(self):
        result = sjson.parse("a = 3 b = -3 c = 3.0 d = 3e2 e = +1.5E-1")
        self.assertEqual([type(result[key]) for key in "abcde"], [int, int, float, float, float])
        self.assertEqual(result, {"a": 3, "b": -3, "c": 3.0, "d": 300.0, "e": 0.15})

    def test_literals(self):
        self.assertEqual(sjson.parse("a = true b = false c = null"), {"a": True, "b": False, "c": None})

    def test_trailing_decimal_point(self):
        result = sjson.parse("a = 1.")
        self.assertEqual(result, {"a": 1.0})
        self.assertIs(type(result["a"]), float)

    def test_root_in_braces(self):
        self.assertEqual(sjson.parse("{ a = 1 }"), {"a": 1})

    def test_string_escapes(self):
        result = sjson.parse(r'a = "q\" b\\ s\/ \n\té"')
        self.assertEqual(result, {"a": 'q" b\\ s/ \n\té'})


class ErrorTest(unittest.TestCase):
    def assert_error_on_line(self, text, line):
        with self.assertRaises(sjson.SjsonError) as context:
            sjson.parse(text)
        self.assertIn("line %d:" % line, str(context.exception))

    def test_unterminated_object(self):
        self.assert_error_on_line("a = {\n  b = 1\n  c = 2\n", 4)

    def test_missing_value(self):
        self.assert_error_on_line("a = 1\nb = 2\nc =\n}", 4)

    def test_missing_value_before_next_key(self):
        self.assert_error_on_line("a = 1\nb = 2\nc = = 3", 3)

    def test_duplicate_key(self):
        self.assert_error_on_line("a = 1\na = 2", 2)

    def test_text_after_braced_root(self):
        self.assert_error_on_line("{ a = 1 }\nb = 2", 2)

    def test_leading_decimal_point(self):
        self.assert_error_on_line("a = 1\nb = .5", 2)

    def test_stray_comma_at_root(self):
        self.assert_error_on_line("a = 1,\n, b = 2", 2)


if __name__ == "__main__":
    unittest.main()
