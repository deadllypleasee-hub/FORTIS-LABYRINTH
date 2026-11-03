import unittest

from scripts.configure_places import configure


class ConfigurePlacesTests(unittest.TestCase):
    SOURCE = "return {\n\tHubPlaceId = 0,\n\tDungeonPlaceId = 0,\n}\n"

    def test_both_ids_apply_and_unrelated_source_is_preserved(self):
        self.assertEqual(
            configure(self.SOURCE, " 12345 ", "9007199254740991"),
            "return {\n\tHubPlaceId = 12345,\n\tDungeonPlaceId = 9007199254740991,\n}\n",
        )

    def test_default_ci_build_leaves_source_unchanged(self):
        self.assertEqual(configure(self.SOURCE, "", ""), self.SOURCE)

    def test_invalid_partial_duplicate_and_shell_inputs_are_rejected(self):
        for hub, dungeon in (
            ("", "123"), ("123", ""), ("123", "123"), ("0", "123"),
            ("-1", "123"), ("1.5", "123"), ("1e3", "123"),
            ("9007199254740992", "123"), ("$(echo unsafe)", "123"),
            ("`echo unsafe`", "123"), ("123; echo unsafe", "456"),
        ):
            with self.subTest(hub=hub, dungeon=dungeon), self.assertRaises(ValueError):
                configure(self.SOURCE, hub, dungeon)

    def test_missing_or_ambiguous_config_entries_fail_before_writing(self):
        for source in ("return {}", self.SOURCE + "HubPlaceId = 0,\n"):
            with self.assertRaises(ValueError):
                configure(source, "123", "456")


if __name__ == "__main__":
    unittest.main()
