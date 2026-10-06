"""Shared isolated librime harness; never uses the live Rime user directory."""

import ctypes as c
import os
from pathlib import Path
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
WEASEL = Path(os.environ.get("WEASEL_DIR", r"C:\Program Files\Rime\weasel-0.17.4"))


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
        ("length", c.c_int), ("cursor_pos", c.c_int),
        ("sel_start", c.c_int), ("sel_end", c.c_int), ("preedit", c.c_char_p),
    ]


class Candidate(c.Structure):
    _fields_ = [("text", c.c_char_p), ("comment", c.c_char_p), ("reserved", c.c_void_p)]


class Menu(c.Structure):
    _fields_ = [
        ("page_size", c.c_int), ("page_no", c.c_int), ("is_last_page", c.c_int),
        ("highlighted_candidate_index", c.c_int), ("num_candidates", c.c_int),
        ("candidates", c.POINTER(Candidate)), ("select_keys", c.c_char_p),
    ]


class Context(c.Structure):
    _fields_ = [
        ("data_size", c.c_int), ("composition", Composition), ("menu", Menu),
        ("commit_text_preview", c.c_char_p), ("select_labels", c.POINTER(c.c_char_p)),
    ]


class Commit(c.Structure):
    _fields_ = [("data_size", c.c_int), ("text", c.c_char_p)]


def versioned(struct_type):
    value = struct_type()
    value.data_size = c.sizeof(struct_type) - c.sizeof(c.c_int)
    return value


def load_config(name):
    return yaml.safe_load((ROOT / name).read_text(encoding="utf-8"))


class RimeTestCase(unittest.TestCase):
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
            "DeployConfigFile": (c.c_int, [c.c_char_p, c.c_char_p]),
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
            "SetProperty": (None, [c.c_size_t, c.c_char_p, c.c_char_p]),
            "ClearComposition": (None, [c.c_size_t]),
        }
        for name, (result, args) in signatures.items():
            function = getattr(cls.lib, "Rime" + name)
            function.restype, function.argtypes = result, args
        cls.temp = tempfile.TemporaryDirectory(prefix="rime-tests-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.data = Path(cls.temp.name)
        schemas = cls.prepare_data(cls.data)
        cls.traits = versioned(Traits)
        cls.traits.shared_data_dir = str(WEASEL / "data").encode()
        cls.traits.user_data_dir = str(cls.data).encode()
        cls.traits.app_name = b"rime.integration_tests"
        cls.traits.min_log_level = 2
        cls.traits.log_dir = b""
        cls.lib.RimeSetup(c.byref(cls.traits))
        cls.lib.RimeInitialize(c.byref(cls.traits))
        cls.addClassCleanup(cls.lib.RimeFinalize)
        cls.lib.RimeDeployerInitialize(c.byref(cls.traits))
        for name in schemas:
            if not cls.lib.RimeDeploySchema(str(cls.data / (name + ".schema.yaml")).encode()):
                raise RuntimeError("Could not deploy isolated schema: " + name)

    def setUp(self):
        self.session = self.lib.RimeCreateSession()
        self.assertNotEqual(self.session, 0)
        self.addCleanup(lambda: self.lib.RimeDestroySession(self.session))
        self.assertTrue(self.lib.RimeSelectSchema(self.session, self.schema_id.encode()))
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
