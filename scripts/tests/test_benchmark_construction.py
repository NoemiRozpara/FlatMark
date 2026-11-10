import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "benchmark-construction.py"
spec = importlib.util.spec_from_file_location("benchmark_construction", SCRIPT)
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)


class ConstructionBenchmarkTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = pathlib.Path(self.directory.name) / "run.csv"
        self.lines = ["Release benchmark", "fixture,scenario,samples,median_ms,p95_ms,min_ms"]
        self.lines += [f"{fixture},{scenario},30,2,3,1"
                       for fixture in sorted(benchmark.FIXTURES)
                       for scenario in sorted(benchmark.SCENARIOS)]
        self.lines.append("Consumed snapshot checksum: 123")

    def validate(self):
        self.path.write_text("\n".join(self.lines) + "\n")
        return benchmark.validate(self.path)

    def test_complete_run(self):
        self.assertEqual(self.validate(), 123)

    def test_rejects_incomplete_run(self):
        self.lines.pop()
        with self.assertRaises(ValueError):
            self.validate()

    def test_rejects_duplicate_scenario(self):
        self.lines[2] = self.lines[3]
        with self.assertRaises(ValueError):
            self.validate()

    def test_rejects_wrong_sample_count(self):
        self.lines[2] = self.lines[2].replace(",30,", ",29,")
        with self.assertRaises(ValueError):
            self.validate()

    def test_rejects_zero_checksum(self):
        self.lines[-1] = "Consumed snapshot checksum: 0"
        with self.assertRaises(ValueError):
            self.validate()

    def test_rejects_invalid_timings(self):
        for timings in ["nan,3,1", "2,inf,1", "2,3,-1", "4,3,1"]:
            with self.subTest(timings=timings):
                self.lines[2] = f"ordinary,baseURL-change,30,{timings}"
                with self.assertRaises(ValueError):
                    self.validate()

    def test_rejects_changed_revision(self):
        with patch.object(benchmark, "output", return_value="other"):
            with self.assertRaises(ValueError):
                benchmark.require_committed_inputs("original")

    def test_rejects_dirty_inputs(self):
        with patch.object(benchmark, "output", side_effect=["original", " M Package.swift"]):
            with self.assertRaises(ValueError):
                benchmark.require_committed_inputs("original")

    def test_existing_destination_does_not_build(self):
        with patch("sys.argv", [str(SCRIPT), self.directory.name]), \
                patch.object(benchmark, "output", return_value="original"), \
                patch.object(benchmark, "require_committed_inputs"), \
                patch.object(benchmark.subprocess, "run") as run:
            with self.assertRaises(FileExistsError):
                benchmark.main()
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
