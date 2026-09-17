"""Offline converter regression tests; run with unittest discover."""
import copy
import io
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

import shapefile
from pyproj import CRS, Transformer
from shapely.geometry import MultiPolygon, Polygon, box, shape

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_sigungu_shapefile import (
    Region, apply_corrections, convert_regions, display_name, read_regions,
    source_components, validate_regions,
)


def sample_region(code="11110", name="서울특별시 종로구"):
    return Region(1, code, name, box(200000, 600000, 202000, 602000))


def sample_zip(epsg=5186, legacy=False):
    files = {ext: io.BytesIO() for ext in ("shp", "shx", "dbf")}
    with shapefile.Writer(**files, encoding="cp949") as writer:
        writer.field("SIG_CD" if legacy else "A1", "C", 5)
        writer.field("SIG_KOR_NM" if legacy else "A2", "C", 60)
        writer.poly([[[200000,600000],[200000,602000],[202000,602000],[202000,600000],[200000,600000]]])
        writer.record("11110", "서울특별시 종로구")
    payload = io.BytesIO()
    with zipfile.ZipFile(payload, "w") as archive:
        for ext, data in files.items():
            archive.writestr("sig." + ext, data.getvalue())
        archive.writestr("sig.prj", CRS.from_epsg(epsg).to_wkt())
        archive.writestr("sig.cpg", "949")
    return payload.getvalue()


class ConversionTests(unittest.TestCase):
    def test_vworld_nested_sig_zip_and_cp949(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "nationwide.zip"
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr("sample(SIG).zip", sample_zip())
                archive.writestr("sample(EMD).zip", b"not needed")
            regions, crs = read_regions(source)
        self.assertEqual(crs.to_epsg(), 5186)
        self.assertEqual(regions[0].name, "서울특별시 종로구")
        self.assertEqual(regions[0].code, "11110")

    def test_legacy_attributes_and_projection(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "legacy.zip"
            source.write_bytes(sample_zip(5179, legacy=True))
            regions, crs = read_regions(source)
        self.assertEqual(crs.to_epsg(), 5179)
        self.assertEqual(regions[0].code, "11110")

    def test_unknown_projection_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown.zip"
            source.write_bytes(sample_zip(3857))
            with self.assertRaisesRegex(ValueError, "Unverified source CRS"):
                read_regions(source)

    def test_missing_components_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "missing.zip"
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr("sig.shp", b"not a shapefile")
            with self.assertRaisesRegex(ValueError, "Missing"):
                read_regions(source)

    def test_ambiguous_archive_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "ambiguous.zip"
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr("one.shp", b"")
                archive.writestr("two.shp", b"")
            with self.assertRaisesRegex(ValueError, "exactly one"):
                source_components(source)

    def test_duplicates_and_empty_input_rejected(self):
        for regions in ([], [sample_region(), sample_region()]):
            with self.assertRaises(ValueError):
                validate_regions(regions)

    def test_bad_code_and_empty_geometry_rejected(self):
        for region in (sample_region("1111"), sample_region("abcde"), Region(1,"11110","종로구",Polygon())):
            with self.assertRaises(ValueError):
                validate_regions([region])

    def test_display_name_preserves_city(self):
        self.assertEqual(display_name("경기도 화성시 효행구"), "화성시 효행구")
        self.assertEqual(display_name("전남광주통합특별시 목포시"), "목포시")
        self.assertEqual(display_name("세종특별자치시"), "세종특별자치시")
        self.assertEqual(display_name("수원시 장안구"), "수원시 장안구")

    def test_projection_origin_and_xy_order(self):
        result = Transformer.from_crs(5186, 4326, always_xy=True).transform(200000, 600000)
        self.assertAlmostEqual(result[0], 127, places=7)
        self.assertAlmostEqual(result[1], 38, places=7)

    def test_holes_and_islands_survive(self):
        outer = box(200000,600000,210000,610000)
        hole = box(202000,602000,204000,604000)
        region = sample_region()
        region.geometry = MultiPolygon([Polygon(outer.exterior.coords, [hole.exterior.coords]),
                                        box(212000,600000,214000,602000)])
        result, _ = convert_regions([region], CRS.from_epsg(5186), 250)
        geometry = shape(result["features"][0]["geometry"])
        self.assertTrue(geometry.is_valid)
        self.assertEqual(len(geometry.geoms), 2)
        self.assertEqual(sum(len(p.interiors) for p in geometry.geoms), 1)
        self.assertEqual(result["features"][0]["properties"]["name"], "종로구")

    def test_sorting_and_reproducibility(self):
        regions = [sample_region("50110"), sample_region("11110")]
        first, _ = convert_regions(regions, CRS.from_epsg(5186), 250)
        second, _ = convert_regions(list(reversed(regions)), CRS.from_epsg(5186), 250)
        self.assertEqual(first, second)
        self.assertEqual(first["features"][0]["properties"]["code"], "11110")

    def test_invalid_grid_and_collapsed_region_rejected(self):
        for grid in (0, -1, float("nan"), float("inf"), 1e8):
            with self.assertRaises(ValueError):
                convert_regions([sample_region()], CRS.from_epsg(5186), grid)

    def test_coordinates_outside_korea_rejected(self):
        region = sample_region()
        region.geometry = box(200000,-600000,201000,-599000)
        with self.assertRaisesRegex(ValueError, "outside Korea"):
            convert_regions([region], CRS.from_epsg(5186), 250)

    def test_corrections_bound_to_exact_source(self):
        correction = {
            "sourceSHA256": "test-hash", "sourceEPSG": 5186,
            "records": [{"recordNumber": 1, "expectedCode": "11110",
                         "expectedName": "서울특별시 종로구", "expectedBounds": [200000,600000,202000,602000],
                         "correctedCode": "27200", "correctedName": "대구광역시 남구"}],
        }
        region = sample_region()
        apply_corrections([region], "test-hash", CRS.from_epsg(5186), correction)
        self.assertEqual(region.code, "27200")
        for key, value in (("sourceSHA256", "wrong"), ("sourceEPSG", 5179)):
            wrong = copy.deepcopy(correction)
            wrong[key] = value
            with self.assertRaises(ValueError):
                apply_corrections([sample_region()], "test-hash", CRS.from_epsg(5186), wrong)
        wrong = copy.deepcopy(correction)
        wrong["records"][0]["expectedBounds"][0] = 0
        with self.assertRaises(ValueError):
            apply_corrections([sample_region()], "test-hash", CRS.from_epsg(5186), wrong)


if __name__ == "__main__":
    unittest.main()
