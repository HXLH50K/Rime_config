"""Isolated Windows keypad integration tests using Weasel's real librime."""

import ctypes as c
import os
from pathlib import Path
import shutil
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
WEASEL = Path(os.environ.get("WEASEL_DIR", r"C:\Program Files\Rime\weasel-0.17.4"))
KP_0, KP_ENTER, RETURN = 0xFFB0, 0xFF8D, 0xFF0D


class Traits(c.Structure):
    _fields_ = [
        ("data_size", c.c_int),
        ("shared_data_dir", c.c_char_p),
        ("user_data_dir", c.c_char_p),
        ("distribution_name", c.c_char_p),
        ("distribution_code_name", c.c_char_p),
        ("distribution_version", c.c_char_p),
        ("app_name", c.c_char_p),
        ("modules", c.POINTER(c.c_char_p)),
        ("min_log_level", c.c_int),
        ("log_dir", c.c_char_p),
        ("prebuilt_data_dir", c.c_char_p),
        ("staging_dir", c.c_char_p),
    ]


class Composition(c.Structure):
    _fields_ = [
        ("length", c.c_int),
        ("cursor_pos", c.c_int),
        ("sel_start", c.c_int),
        ("sel_end", c.c_int),
        ("preedit", c.c_char_p),
    ]


class Candidate(c.Structure):
    _fields_ = [("text", c.c_char_p), ("comment", c.c_char_p), ("reserved", c.c_void_p)]


class Menu(c.Structure):
    _fields_ = [
        ("page_size", c.c_int),
        ("page_no", c.c_int),
        ("is_last_page", c.c_int),
        ("highlighted_candidate_index", c.c_int),
        ("num_candidates", c.c_int),
        ("candidates", c.POINTER(Candidate)),
        ("select_keys", c.c_char_p),
    ]


class Context(c.Structure):
    _fields_ = [
        ("data_size", c.c_int),
        ("composition", Composition),
        ("menu", Menu),
        ("commit_text_preview", c.c_char_p),
        ("select_labels", c.POINTER(c.c_char_p)),
    ]


class Commit(c.Structure):
    _fields_ = [("data_size", c.c_int), ("text", c.c_char_p)]


def versioned(struct_type):
    value = struct_type()
    value.data_size = c.sizeof(struct_type) - c.sizeof(c.c_int)
    return value


def load_config(name):
    return yaml.safe_load((ROOT / name).read_text(encoding="utf-8"))


class KeypadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll_directory = os.add_dll_directory(str(WEASEL))
        cls.addClassCleanup(cls.dll_directory.close)
        cls.lib = c.CDLL(str(WEASEL / "rime.dll"))
        signatures = {
            "Setup": (None, [c.POINTER(Traits)]),
            "Initialize": (None, [c.POINTER(Traits)]),
            "DeployerInitialize": (None, [c.POINTER(Traits)]),
            "Finalize": (None, []),
            "DeploySchema": (c.c_int, [c.c_char_p]),
            "CreateSession": (c.c_size_t, []),
            "DestroySession": (c.c_int, [c.c_size_t]),
            "SelectSchema": (c.c_int, [c.c_size_t, c.c_char_p]),
            "ProcessKey": (c.c_int, [c.c_size_t, c.c_int, c.c_int]),
            "GetContext": (c.c_int, [c.c_size_t, c.POINTER(Context)]),
            "FreeContext": (c.c_int, [c.POINTER(Context)]),
            "GetCommit": (c.c_int, [c.c_size_t, c.POINTER(Commit)]),
            "FreeCommit": (c.c_int, [c.POINTER(Commit)]),
            "GetOption": (c.c_int, [c.c_size_t, c.c_char_p]),
            "SetOption": (None, [c.c_size_t, c.c_char_p, c.c_int]),
            "ClearComposition": (None, [c.c_size_t]),
        }
        for name, (result, args) in signatures.items():
            function = getattr(cls.lib, "Rime" + name)
            function.restype, function.argtypes = result, args

        cls.temp = tempfile.TemporaryDirectory(prefix="rime-keypad-")
        cls.addClassCleanup(cls.temp.cleanup)
        data = Path(cls.temp.name)
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
        cls.traits = versioned(Traits)
        cls.traits.shared_data_dir = str(WEASEL / "data").encode()
        cls.traits.user_data_dir = str(data).encode()
        cls.traits.app_name = b"rime.keypad_tests"
        cls.traits.min_log_level = 2
        cls.traits.log_dir = b""
        cls.lib.RimeSetup(c.byref(cls.traits))
        cls.lib.RimeInitialize(c.byref(cls.traits))
        cls.addClassCleanup(cls.lib.RimeFinalize)
        cls.lib.RimeDeployerInitialize(c.byref(cls.traits))
        for name in ("keypad_test", "keypad_baseline"):
            if not cls.lib.RimeDeploySchema(str(data / (name + ".schema.yaml")).encode()):
                raise RuntimeError("Could not deploy isolated schema: " + name)

    def setUp(self):
        self.session = self.lib.RimeCreateSession()
        self.assertNotEqual(self.session, 0)
        self.addCleanup(self.lib.RimeDestroySession, self.session)
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"keypad_test"))
        self.reset()

    def reset(self):
        self.lib.RimeClearComposition(self.session)
        self.lib.RimeSetOption(self.session, b"ascii_mode", False)
        self.assertEqual(self.committed(), "")

    def key(self, code, modifiers=0):
        return self.lib.RimeProcessKey(self.session, ord(code) if isinstance(code, str) else code, modifiers)

    def state(self, session=None):
        context = versioned(Context)
        self.assertTrue(self.lib.RimeGetContext(self.session if session is None else session, c.byref(context)))
        try:
            return (
                (context.composition.preedit or b"").decode(),
                [context.menu.candidates[i].text.decode() for i in range(context.menu.num_candidates)],
            )
        finally:
            self.lib.RimeFreeContext(c.byref(context))

    def committed(self, session=None):
        commit = versioned(Commit)
        if not self.lib.RimeGetCommit(self.session if session is None else session, c.byref(commit)):
            return ""
        try:
            return (commit.text or b"").decode()
        finally:
            self.lib.RimeFreeCommit(c.byref(commit))

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
