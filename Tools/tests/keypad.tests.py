"""Isolated Windows keypad integration tests using Weasel's real librime."""

import shutil
import unittest

import yaml

from rime_test import ROOT, RimeTestCase, load_config

KP_0, KP_ENTER, RETURN = 0xFFB0, 0xFF8D, 0xFF0D


class KeypadTests(RimeTestCase):
    schema_id = "keypad_test"

    @classmethod
    def prepare_data(cls, data):
        (data / "lua" / "sbxlm").mkdir(parents=True)
        for name in ("kp_num_processor.lua", r"sbxlm\key_binder.lua", r"sbxlm\lib.lua"):
            shutil.copy2(ROOT / "lua" / name, data / "lua" / name)
        shutil.copy2(ROOT / "default.windows.yaml", data / "default.yaml")
        base = load_config("moqi_xh-weasel.schema.yaml")
        common = load_config("moqi.yaml")["switches_engine"]
        patch = load_config("moqi_xh-weasel.custom.yaml")
        # Keep the deployed Windows processors/bindings; isolate large dictionaries
        # and unrelated translators/filters with a small nine-candidate fixture.
        del patch["patch"]["engine/translators"]
        schema = {
            "schema": {"schema_id": "keypad_test", "name": "Keypad test", "version": "1"},
            "switches": common["switches"],
            "engine": {
                "processors": common["engine"]["processors"],
                "segmentors": ["ascii_segmentor", "matcher", "abc_segmentor", "fallback_segmentor"],
                "translators": ["table_translator"],
            },
            "speller": base["speller"],
            "key_binder": base["key_binder"],
            "translator": {"dictionary": "keypad_test", "enable_user_dict": False},
        }
        for name, config in (("keypad_test.schema.yaml", schema), ("keypad_test.custom.yaml", patch)):
            (data / name).write_text(yaml.safe_dump(config, allow_unicode=True), encoding="utf-8")
        baseline_schema = dict(schema, schema=dict(schema["schema"], schema_id="keypad_baseline"))
        baseline_patch = {"patch": dict(patch["patch"])}
        baseline_patch["patch"]["engine/processors"] = patch["patch"]["engine/processors"][1:]
        for name, config in (("keypad_baseline.schema.yaml", baseline_schema),
                             ("keypad_baseline.custom.yaml", baseline_patch)):
            (data / name).write_text(yaml.safe_dump(config, allow_unicode=True), encoding="utf-8")
        dictionary = "---\nname: keypad_test\nversion: '1'\nsort: by_weight\n...\n"
        dictionary += "".join(f"{chr(0x4E00 + i)}\tc\t{100 - i}\n" for i in range(9))
        (data / "keypad_test.dict.yaml").write_text(dictionary, encoding="utf-8")
        return ("keypad_test", "keypad_baseline")

    def assert_raw(self, text):
        preedit, candidates = self.state()
        self.assertEqual(preedit, text)
        self.assertTrue(all(candidate == text for candidate in candidates), candidates)
        self.assertEqual(self.committed(), "")

    def start_chinese(self):
        self.assertTrue(self.key("c"))
        preedit, candidates = self.state()
        self.assertEqual(preedit, "c")
        self.assertEqual(len(candidates), 9)
        self.assertEqual(self.committed(), "")
        return candidates

    def test_each_keypad_digit_stays_in_composition(self):
        for digit in range(10):
            with self.subTest(digit=digit):
                self.reset()
                self.start_chinese()
                self.assertTrue(self.key(KP_0 + digit))
                self.assert_raw("c" + str(digit))

    def test_main_row_numbers_still_select_candidates(self):
        for digit in range(1, 10):
            with self.subTest(digit=digit):
                self.reset()
                candidates = self.start_chinese()
                self.assertTrue(self.key(str(digit)))
                self.assertEqual(self.committed(), candidates[digit - 1])
                self.assertEqual(self.state(), ("", []))

    def test_both_enter_keys_commit_raw_and_restore_chinese(self):
        for enter in (RETURN, KP_ENTER):
            for with_digit in (False, True):
                with self.subTest(enter=enter, with_digit=with_digit):
                    self.reset()
                    self.start_chinese()
                    if with_digit:
                        self.key(KP_0 + 8)
                    self.assertTrue(self.key(enter))
                    self.assertEqual(self.committed(), "c8" if with_digit else "c")
                    self.assertEqual(self.state(), ("", []))
                    self.assertFalse(self.lib.RimeGetOption(self.session, b"ascii_mode"))
                    self.start_chinese()

    def test_mixed_verification_code_and_long_input(self):
        self.start_chinese()
        self.key(KP_0 + 8)
        for char in "a2B7xyz123":
            self.key(char)
        self.key(KP_0)
        self.assert_raw("c8a2B7xyz1230")
        self.key(KP_ENTER)
        self.assertEqual(self.committed(), "c8a2B7xyz1230")

    def test_keypad_digits_without_composition_commit_directly(self):
        for ascii_mode in (False, True):
            self.lib.RimeSetOption(self.session, b"ascii_mode", ascii_mode)
            for digit in range(10):
                with self.subTest(ascii_mode=ascii_mode, digit=digit):
                    self.assertTrue(self.key(KP_0 + digit))
                    self.assertEqual(self.committed(), str(digit))
                    self.assertEqual(self.state(), ("", []))
                    self.assertEqual(bool(self.lib.RimeGetOption(self.session, b"ascii_mode")), ascii_mode)

    def test_keypad_enter_without_composition_passes_through(self):
        for ascii_mode in (False, True):
            self.lib.RimeSetOption(self.session, b"ascii_mode", ascii_mode)
            self.assertFalse(self.key(KP_ENTER))
            self.assertEqual(self.committed(), "")

    def test_escape_and_backspace_restore_chinese(self):
        for cancel in (0xFF1B, 0xFF08):
            with self.subTest(cancel=cancel):
                self.reset()
                self.start_chinese()
                self.key(KP_0 + 8)
                if cancel == 0xFF08:
                    self.key(cancel)
                    self.assert_raw("c")
                self.key(cancel)
                self.assertEqual(self.state(), ("", []))
                self.assertEqual(self.committed(), "")
                self.assertFalse(self.lib.RimeGetOption(self.session, b"ascii_mode"))
                self.start_chinese()

    def test_digits_insert_at_caret(self):
        self.start_chinese()
        self.key(KP_0 + 8)
        self.key("a")
        self.key(0xFF51)  # Left
        self.key(KP_0 + 3)
        self.assert_raw("c83a")

    def test_release_and_shortcuts_keep_native_behavior(self):
        baseline = self.lib.RimeCreateSession()
        self.assertNotEqual(baseline, 0)
        self.addCleanup(self.lib.RimeDestroySession, baseline)
        self.assertTrue(self.lib.RimeSelectSchema(baseline, b"keypad_baseline"))
        for modifier in (1 << 30, 1, 4, 8, 1 << 26):
            with self.subTest(modifier=modifier):
                self.reset()
                self.start_chinese()
                self.lib.RimeClearComposition(baseline)
                self.lib.RimeSetOption(baseline, b"ascii_mode", False)
                self.lib.RimeProcessKey(baseline, ord("c"), 0)
                self.lib.RimeProcessKey(baseline, KP_0 + 8, modifier)
                self.key(KP_0 + 8, modifier)
                self.assertEqual(self.committed(), self.committed(baseline))
                self.assertEqual(self.state(), self.state(baseline))
                self.assertFalse(self.lib.RimeGetOption(self.session, b"ascii_mode"))

    def test_caps_lock_modifier_does_not_hide_keypad_digits(self):
        self.start_chinese()
        self.key(KP_0 + 8, 2)
        self.assert_raw("c8")

    def test_existing_inline_ascii_mode_is_preserved(self):
        self.start_chinese()
        self.lib.RimeSetOption(self.session, b"ascii_mode", True)
        self.key(KP_0 + 8)
        self.assert_raw("c8")
        self.key(KP_ENTER)
        self.assertEqual(self.committed(), "c8")
        self.assertTrue(self.lib.RimeGetOption(self.session, b"ascii_mode"))

    def test_native_shift_inline_ascii_still_restores_chinese(self):
        self.start_chinese()
        self.key(0xFFE1)  # Shift_L
        self.key(0xFFE1, 1 << 30)
        self.assertTrue(self.lib.RimeGetOption(self.session, b"ascii_mode"))
        self.key(KP_0 + 8)
        self.assert_raw("c8")
        self.key(KP_ENTER)
        self.assertEqual(self.committed(), "c8")
        self.assertFalse(self.lib.RimeGetOption(self.session, b"ascii_mode"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
