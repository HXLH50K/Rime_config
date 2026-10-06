"""Real-engine tests with a controllable wall clock and tiny phonetic dictionary."""

import copy
import shutil
import tempfile
import time
import unittest
from pathlib import Path

import yaml
from lupa import LuaRuntime

from rime_test import ROOT, RimeTestCase, load_config

START = 1700000000
COMMON = "\u5403\u996d"
RARE = "\u6c60\u6cdb"
NEW_WORD = "\u6c60\u996d"


class RecentFrequencyTests(RimeTestCase):
    schema_id = "recent_windows"

    @classmethod
    def prepare_data(cls, data):
        for path in ROOT.glob("*.schema.yaml"):
            shutil.copy2(path, data / path.name)
        for name in ("moqi.yaml", "moqi_xh-weasel.custom.yaml", "symbols_caps_v.yaml"):
            shutil.copy2(ROOT / name, data / name)
        (data / "lua" / "sbxlm").mkdir(parents=True)
        for name in ("recent_frequency.lua", "kp_num_processor.lua",
                     "sharedkey_shuangpin_precise_input_processor.lua",
                     "sharedkey_shuangpin_precise_input_filter.lua",
                     r"sbxlm\key_binder.lua", r"sbxlm\lib.lua"):
            shutil.copy2(ROOT / "lua" / name, data / "lua" / name)
        (data / "clock").write_text(str(START), encoding="ascii")
        (data / "lua" / "recent_frequency_test.lua").write_text(
            'local real_time = os.time\n'
            'os.time = function(date)\n'
            '  if date then return real_time(date) end\n'
            '  local f = assert(io.open(rime_api.get_user_data_dir() .. package.config:sub(1, 1) .. "clock"))\n'
            '  local now = assert(tonumber(f:read("*a")))\n'
            '  assert(f:close())\n'
            '  return now\n'
            'end\n'
            'local module = require("recent_frequency")\n'
            'local init = module.init\n'
            'module.init = function(env)\n'
            '  init(env)\n'
            '  if env.enabled then\n'
            '    local c = env.engine.schema.config\n'
            '    assert(c:get_bool("translator/enable_user_dict") == true)\n'
            '    assert(c:get_bool("recent_frequency_base/enable_user_dict") == false)\n'
            '    for _, key in ipairs({"dictionary", "prism", "initial_quality", "contextual_suggestions", "max_homophones", "max_homographs"}) do\n'
            '      assert(c:get_string("translator/" .. key) == c:get_string("recent_frequency_base/" .. key), key)\n'
            '    end\n'
            '  end\n'
            'end\n'
            'return module\n', encoding="ascii")
        shutil.copy2(ROOT / "default.windows.yaml", data / "default.yaml")
        common = load_config("moqi.yaml")
        windows_patch = load_config("moqi_xh-weasel.custom.yaml")["patch"]
        schemas = []
        for platform, source in (("windows", "moqi_xh-weasel.schema.yaml"),
                                 ("android", "moqi_xh-18key.schema.yaml")):
            base = load_config(source)
            translator = dict(base["translator"], dictionary="recent_fixture", enable_user_dict=True)
            engine = windows_patch if platform == "windows" else base["engine"]
            processors = engine["engine/processors"] if platform == "windows" else engine["processors"]
            translators = engine["engine/translators"] if platform == "windows" else engine["translators"]
            assert "lua_translator@*recent_frequency" in translators
            schema = {
                "schema": {"schema_id": "recent_" + platform, "name": "Recent test", "version": "1"},
                "switches": common["switches_engine"]["switches"],
                "menu": {"page_size": 9},
                "engine": {
                    "processors": processors,
                    "segmentors": ["ascii_segmentor", "matcher", "abc_segmentor", "fallback_segmentor"],
                    "translators": ["lua_translator@*recent_frequency_test"],
                    "filters": (["lua_filter@*sharedkey_shuangpin_precise_input_filter"]
                                if platform == "android" else []),
                },
                "speller": base["speller"],
                "translator": translator,
                "recent_frequency": common["recent_frequency"]["recent_frequency"],
                "key_binder": base["key_binder"],
                "ascii_composer": load_config("default.windows.yaml")["ascii_composer"],
                "__patch": common["octagram"]["enable_for_sentence"]["__patch"],
            }
            if platform == "android":
                schema["precise_input"] = base["precise_input"]
            if platform == "windows":
                schema["key_binder"]["bindings"] += windows_patch["key_binder/bindings/+"]
                schema["ascii_composer"] = {
                    "switch_key": windows_patch["ascii_composer/switch_key"],
                    "good_old_caps_lock": windows_patch["ascii_composer/good_old_caps_lock"],
                }
                native = copy.deepcopy(schema)
                native["schema"]["schema_id"] = "recent_native"
                native["engine"]["translators"] = ["script_translator"]
                (data / "recent_native.schema.yaml").write_text(yaml.safe_dump(native), encoding="utf-8")
                schemas.append("recent_native")
                short = copy.deepcopy(schema)
                short["schema"]["schema_id"] = "recent_short"
                short["recent_frequency"] = {"enabled": True, "window_hours": 24, "half_life_hours": 4}
                (data / "recent_short.schema.yaml").write_text(yaml.safe_dump(short), encoding="utf-8")
                schemas.append("recent_short")
                disabled = copy.deepcopy(schema)
                disabled["schema"]["schema_id"] = "recent_disabled"
                disabled["recent_frequency"]["enabled"] = False
                (data / "recent_disabled.schema.yaml").write_text(yaml.safe_dump(disabled), encoding="utf-8")
                schemas.append("recent_disabled")
                large = copy.deepcopy(schema)
                large["schema"]["schema_id"] = "recent_large"
                large["translator"]["dictionary"] = "recent_large"
                (data / "recent_large.schema.yaml").write_text(yaml.safe_dump(large), encoding="utf-8")
                schemas.append("recent_large")
            name = schema["schema"]["schema_id"]
            (data / (name + ".schema.yaml")).write_text(yaml.safe_dump(schema), encoding="utf-8")
            schemas.append(name)
        entries = [
            ("\u5403", "ii[kv", 10000), ("\u6c60", "ii[dy", 100),
            ("\u996d", "fj[uy", 10000), ("\u6cdb", "fj[df", 100),
            (COMMON, "ii[kv fj[uy", 10000), (RARE, "ii[dy fj[df", 1),
        ]
        dictionary = "---\nname: recent_fixture\nversion: '1'\nsort: by_weight\n...\n"
        dictionary += "".join(f"{text}\t{code}\t{weight}\n" for text, code, weight in entries)
        (data / "recent_fixture.dict.yaml").write_text(dictionary, encoding="utf-8")
        large_dictionary = dictionary.replace("name: recent_fixture", "name: recent_large")
        large_dictionary += "".join(
            f"{chr(0x5000 + i)}{chr(0x6000 + i)}\tii[kv fj[uy\t1\n" for i in range(4096))
        (data / "recent_large.dict.yaml").write_text(large_dictionary, encoding="utf-8")
        return schemas

    def setUp(self):
        for slot in range(4):
            (self.data / f"recent_frequency.{slot}.tsv").unlink(missing_ok=True)
        self.at(START)
        super().setUp()

    def at(self, timestamp):
        (self.data / "clock").write_text(str(timestamp), encoding="ascii")

    def query(self, code="iifj"):
        self.reset()
        for char in code:
            self.assertTrue(self.key(char))
        candidates = self.state()[1]
        self.assertTrue(candidates)
        return candidates

    def choose(self, text, code="iifj"):
        candidates = self.query(code)
        self.assertIn(text, candidates)
        self.assertTrue(self.key(str(candidates.index(text) + 1)))
        self.assertEqual(self.committed(), text)

    def test_cold_word_recovers_on_both_platforms_without_other_typing(self):
        for index, platform in enumerate(("windows", "android")):
            with self.subTest(platform=platform):
                epoch = START + index * 4 * 86400
                self.at(epoch)
                self.assertTrue(self.lib.RimeSelectSchema(self.session, ("recent_" + platform).encode()))
                self.assertEqual(self.query()[0], COMMON)
                for _ in range(4):
                    self.choose(RARE)
                self.assertEqual(self.query()[0], RARE)
                self.at(epoch + 60 * 3600)
                self.assertEqual(self.query()[0], COMMON)
                self.assertIn(RARE, self.query())
                self.at(epoch + 72 * 3600)
                self.assertEqual(self.query()[0], COMMON)

    def test_exact_window_boundary_even_after_heavy_use(self):
        for _ in range(70):
            self.choose(RARE)
        self.at(START + 72 * 3600 - 1)
        self.assertEqual(self.query()[0], RARE)
        self.at(START + 72 * 3600)
        self.assertEqual(self.query()[0], COMMON)
        self.assertIn(RARE, self.query())

    def test_old_native_frequency_does_not_lock_first_place(self):
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_native"))
        for _ in range(10):
            self.choose(RARE)
        self.assertEqual(self.query()[0], RARE)
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_windows"))
        self.assertEqual(self.query()[0], COMMON)
        self.assertIn(RARE, self.query())

    def test_new_word_is_learned_and_retained_after_expiry(self):
        candidates = self.query("iifj")
        self.assertIn("\u6c60", candidates)
        self.key(str(candidates.index("\u6c60") + 1))
        remaining = self.state()[1]
        self.assertIn("\u996d", remaining)
        self.key(str(remaining.index("\u996d") + 1))
        self.assertEqual(self.committed(), NEW_WORD)
        self.assertIn(NEW_WORD, self.query())
        self.at(START + 72 * 3600)
        self.assertEqual(self.query()[0], COMMON)
        self.assertIn(NEW_WORD, self.query())

    def test_shorter_configurable_window(self):
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_short"))
        for _ in range(70):
            self.choose(RARE)
        self.at(START + 24 * 3600 - 1)
        self.assertEqual(self.query()[0], RARE)
        self.at(START + 24 * 3600)
        self.assertEqual(self.query()[0], COMMON)

    def test_disable_switch_restores_native_ranking_without_history_writes(self):
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_disabled"))
        for _ in range(4):
            self.choose(RARE)
        self.at(START + 72 * 3600)
        self.assertEqual(self.query()[0], RARE)
        self.assertFalse(list(self.data.glob("recent_frequency.*.tsv")))

    def test_actual_platform_configs_compile_with_shared_policy(self):
        for name in ("moqi_xh-weasel", "moqi_xh-18key"):
            with self.subTest(schema=name):
                self.assertTrue(self.lib.RimeDeployConfigFile((name + ".schema.yaml").encode(), b"schema/version"))
                config = yaml.safe_load((self.data / "build" / (name + ".schema.yaml")).read_text(encoding="utf-8"))
                self.assertIn("lua_translator@*recent_frequency", config["engine"]["translators"])
                self.assertEqual(config["recent_frequency"], {"enabled": True, "window_hours": 72, "half_life_hours": 12})
                self.assertTrue(config["translator"]["enable_user_dict"])
                self.assertTrue(config["translator"]["contextual_suggestions"])

    def test_restart_keeps_recent_history(self):
        for _ in range(4):
            self.choose(RARE)
        self.reset()
        self.assertTrue(self.lib.RimeDestroySession(self.session))
        self.session = self.lib.RimeCreateSession()
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_windows"))
        self.assertEqual(self.query()[0], RARE)
        self.reset()
        self.at(START + 71 * 3600)
        self.assertTrue(self.lib.RimeDestroySession(self.session))
        self.session = self.lib.RimeCreateSession()
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_windows"))
        self.assertIn(RARE, self.query())
        self.at(START + 72 * 3600)
        self.assertEqual(self.query()[0], COMMON)

    def test_single_use_fades_within_one_day(self):
        self.choose(RARE)
        self.assertEqual(self.query()[0], RARE)
        self.at(START + 24 * 3600)
        self.assertEqual(self.query()[0], COMMON)

    def test_fresh_usage_is_not_erased_when_older_usage_expires(self):
        for _ in range(70):
            self.choose(RARE)
        self.at(START + 71 * 3600)
        self.choose(RARE)
        self.at(START + 72 * 3600)
        self.assertEqual(self.query()[0], RARE)
        self.at(START + 95 * 3600)
        self.assertEqual(self.query()[0], COMMON)

    def test_android_precision_and_auxiliary_code_are_preserved(self):
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_android"))
        self.assertIn(COMMON, self.query("IIFJ"))
        candidates = self.query("ii[kvfj[uy")
        self.assertIn(COMMON, candidates)
        self.assertNotIn(RARE, candidates)

    def test_raw_return_and_keypad_input_do_not_learn_words(self):
        self.query()
        self.key(0xFF0D)
        self.assertEqual(self.committed(), "iifj")
        self.query()
        self.key(0xFFB8)
        self.key(0xFF8D)
        self.assertEqual(self.committed(), "iifj8")
        self.assertFalse(list(self.data.glob("recent_frequency.*.tsv")))
        self.assertEqual(self.query()[0], COMMON)

    def test_delete_clears_recent_boost(self):
        for _ in range(4):
            self.choose(RARE)
        self.assertEqual(self.query()[0], RARE)
        self.key(0xFFFF, 4)  # Control+Delete
        self.assertEqual(self.query()[0], COMMON)

    def test_repeated_queries_do_not_count_as_usage(self):
        for _ in range(10):
            self.query()
        self.assertFalse(list(self.data.glob("recent_frequency.*.tsv")))

    def test_history_uses_at_most_four_rotating_files(self):
        for day in range(8):
            self.at(START + day * 86400)
            self.choose(RARE)
        files = list(self.data.glob("recent_frequency.*.tsv"))
        self.assertEqual(len(files), 4)
        self.assertTrue(all(len(path.read_text().splitlines()) == 2 for path in files))

    def test_small_dictionary_latency(self):
        self.query()
        start = time.perf_counter()
        for _ in range(100):
            self.query()
        self.assertLess((time.perf_counter() - start) / 100, 0.05)

    def test_large_candidate_group_is_not_truncated_and_stays_responsive(self):
        self.assertTrue(self.lib.RimeSelectSchema(self.session, b"recent_large"))
        self.query()
        start = time.perf_counter()
        for _ in range(10):
            self.query()
        average = (time.perf_counter() - start) / 10
        print(f"\n4096-word group, average four-key query: {average * 1000:.1f} ms")
        self.assertLess(average, 0.1)
        seen = set(self.state()[1])
        page = self.state()[1]
        for _ in range(500):
            self.key(0xFF56)  # Page_Down
            next_page = self.state()[1]
            if next_page == page:
                break
            seen.update(next_page)
            page = next_page
        self.assertGreaterEqual(len(seen), 4098)


class HistoryFailureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rime-history-tests-")
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name)
        self.path = self.data / f"recent_frequency.{START // 86400 % 4}.tsv"
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().data_dir = str(self.data)
        self.lua.globals().now = START
        self.lua.execute("""
            os.time = function() return now end
            rime_api = { get_user_data_dir = function() return data_dir end }
            Component = { Translator = function() return {} end }
            ConfigValue = function(value) return { element = value } end
            ConfigMap = function()
                local map = { set = function() end }
                map.element = map
                return map
            end
            local options = {
                keys = function() return {} end,
                get = function() return nil end,
            }
            config = {
                get_bool = function() return true end,
                get_double = function(_, key)
                    if key == "recent_frequency/window_hours" then return 72 end
                    if key == "recent_frequency/half_life_hours" then return 12 end
                    return 10000
                end,
                get_string = function(_, key)
                    if key == "translator/dictionary" then return "test" end
                end,
                get_map = function() return options end,
                set_item = function() return true end,
            }
            local function notifier()
                return { connect = function(self, callback)
                    self.callback = callback
                    return { disconnect = function() end }
                end }
            end
            local candidate = {
                get_genuine = function()
                    return { to_phrase = function()
                        return { text = "word", lang_name = "test" }
                    end }
                end,
            }
            context = {
                commit_notifier = notifier(),
                delete_notifier = notifier(),
                composition = { toSegmentation = function()
                    return { get_segments = function()
                        return {{ get_selected_candidate = function() return candidate end }}
                    end }
                end },
            }
            env = { engine = { schema = { config = config }, context = context } }
        """)
        self.module = self.lua.execute((ROOT / "lua" / "recent_frequency.lua").read_text(encoding="utf-8"))
        self.addCleanup(lambda: self.module.fini(self.lua.globals().env))

    def test_invalid_policy_is_rejected(self):
        self.lua.execute('config.get_double = function() return 0 end')
        with self.assertRaisesRegex(Exception, "window_hours must be"):
            self.module.init(self.lua.globals().env)

    def test_corrupt_history_is_reported_not_silently_reset(self):
        content = f"v1\t{START // 86400}\n{START}\t1\tabc\n"
        self.path.write_text(content, encoding="ascii")
        with self.assertRaisesRegex(Exception, "invalid history record"):
            self.module.init(self.lua.globals().env)
        self.assertEqual(self.path.read_text(), content)

    def test_history_read_failure_is_reported(self):
        self.path.mkdir()
        with self.assertRaisesRegex(Exception, "cannot read history"):
            self.module.init(self.lua.globals().env)

    def test_history_write_failure_is_reported(self):
        self.module.init(self.lua.globals().env)
        self.path.mkdir()
        with self.assertRaisesRegex(Exception, "cannot write history"):
            self.lua.execute("context.commit_notifier.callback(context)")

    def test_clock_rollback_does_not_overwrite_future_slot(self):
        content = f"v1\t{START // 86400 + 4}\n"
        self.path.write_text(content, encoding="ascii")
        self.module.init(self.lua.globals().env)
        with self.assertRaisesRegex(Exception, "system clock moved backwards"):
            self.lua.execute("context.commit_notifier.callback(context)")
        self.assertEqual(self.path.read_text(), content)


if __name__ == "__main__":
    unittest.main(verbosity=2)
