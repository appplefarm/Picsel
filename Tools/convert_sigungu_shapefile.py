#!/usr/bin/env python3
"""Convert SIG SHP / Vworld ZIP to validated WGS84 GeoJSON (offline tool only).

Install BoundaryData/requirements.txt; the iOS app has no GIS dependency.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import io
import json
import math
from pathlib import Path
import re
import zipfile

import shapefile
from pyproj import CRS, Transformer
from shapely import make_valid, orient_polygons, set_precision
from shapely.geometry import MultiPolygon, mapping, shape
from shapely.geometry.base import BaseGeometry
from shapely.ops import transform, unary_union


@dataclass
class Region:
    record_number: int
    code: str
    name: str
    geometry: BaseGeometry


def zip_components(archive: zipfile.ZipFile) -> dict[str, bytes]:
    shapes = [n for n in archive.namelist() if n.lower().endswith(".shp")]
    if len(shapes) != 1:
        raise ValueError("Expected exactly one SIG Shapefile")
    stem = str(Path(shapes[0]).with_suffix(""))
    return {
        Path(n).suffix.lower(): archive.read(n)
        for n in archive.namelist()
        if str(Path(n).with_suffix("")) == stem
        and Path(n).suffix.lower() in {".shp", ".shx", ".dbf", ".prj", ".cpg"}
    }


def source_components(source: Path) -> dict[str, bytes]:
    """Read only SIG sidecars; never extract ZIP paths to disk."""
    if source.suffix.lower() == ".shp":
        return {
            ext: source.with_suffix(ext).read_bytes()
            for ext in (".shp", ".shx", ".dbf", ".prj", ".cpg")
            if source.with_suffix(ext).exists()
        }
    with zipfile.ZipFile(source) as archive:
        nested = [n for n in archive.namelist() if n.upper().endswith("(SIG).ZIP")]
        if len(nested) == 1:
            with zipfile.ZipFile(io.BytesIO(archive.read(nested[0]))) as sig:
                return zip_components(sig)
        if nested:
            raise ValueError("Multiple SIG archives: select one snapshot")
        return zip_components(archive)


def read_regions(source: Path) -> tuple[list[Region], CRS]:
    parts = source_components(source)
    missing = {".shp", ".shx", ".dbf", ".prj"} - parts.keys()
    if missing:
        raise ValueError(f"Missing Shapefile components: {sorted(missing)}")
    crs = CRS.from_wkt(parts[".prj"].decode("utf-8-sig"))
    if crs.to_epsg() not in (5179, 5186):
        raise ValueError(f"Unverified source CRS: {crs.name}")
    encoding = parts.get(".cpg", b"cp949").decode("ascii").strip()
    if encoding == "949":
        encoding = "cp949"
    with shapefile.Reader(
        shp=io.BytesIO(parts[".shp"]), shx=io.BytesIO(parts[".shx"]),
        dbf=io.BytesIO(parts[".dbf"]), encoding=encoding,
    ) as reader:
        fields = {f[0] for f in reader.fields[1:]}
        if {"A1", "A2"} <= fields:
            code_field, name_field = "A1", "A2"
        elif {"SIG_CD", "SIG_KOR_NM"} <= fields:
            code_field, name_field = "SIG_CD", "SIG_KOR_NM"
        else:
            raise ValueError(f"Unrecognized SIG attributes: {sorted(fields)}")
        if reader.numRecords != reader.numShapes:
            raise ValueError("DBF/SHP record count mismatch")
        regions = [
            Region(item.record.oid + 1, str(item.record[code_field]).strip(),
                   str(item.record[name_field]).strip(), shape(item.shape.__geo_interface__))
            for item in reader.iterShapeRecords()
        ]
        if len(regions) != reader.numRecords:
            raise ValueError("Deleted or missing DBF records require review")
    return regions, crs


def validate_regions(regions: list[Region]) -> None:
    if not regions:
        raise ValueError("No SIG regions")
    duplicates = sorted(c for c, n in Counter(r.code for r in regions).items() if n > 1)
    if duplicates:
        raise ValueError(f"Duplicate region codes: {duplicates}; do not merge/discard")
    for region in regions:
        if not re.fullmatch(r"[0-9]{5}", region.code) or not region.name:
            raise ValueError(f"Invalid code/name in record {region.record_number}")
        if region.geometry.is_empty or region.geometry.geom_type not in ("Polygon", "MultiPolygon"):
            raise ValueError(f"Empty or non-polygon region: {region.code}")


def apply_corrections(regions: list[Region], source_hash: str, crs: CRS, config: dict) -> list[dict]:
    """Apply only reviewed records bound to the exact source hash, CRS and bounds."""
    if config["sourceSHA256"] != source_hash or config["sourceEPSG"] != crs.to_epsg():
        raise ValueError("Correction file does not match source snapshot/CRS")
    by_number = {r.record_number: r for r in regions}
    for correction in config["records"]:
        region = by_number.get(correction["recordNumber"])
        if region is None or (region.code, region.name) != (
            correction["expectedCode"], correction["expectedName"]
        ):
            raise ValueError("Correction source record no longer matches")
        bounds = correction["expectedBounds"]
        if len(bounds) != 4 or any(
            abs(a - b) > 0.001 for a, b in zip(region.geometry.bounds, bounds)
        ):
            raise ValueError("Correction geometry bounds no longer match")
        region.code = correction["correctedCode"]
        region.name = correction["correctedName"]
    return config["records"]


def display_name(full_name: str) -> str:
    """Remove province only; preserve '화성시 효행구' for city grouping."""
    first, separator, remainder = full_name.partition(" ")
    is_province = first.endswith(("특별시", "광역시", "특별자치시", "특별자치도", "도"))
    return remainder if separator and is_province else full_name


def polygonal_geometry(geometry: BaseGeometry) -> BaseGeometry:
    if geometry.geom_type in ("Polygon", "MultiPolygon"):
        return geometry
    polygons = []
    for child in getattr(geometry, "geoms", []):
        result = polygonal_geometry(child)
        if not result.is_empty:
            polygons.extend(result.geoms if result.geom_type == "MultiPolygon" else [result])
    return unary_union(polygons) if polygons else MultiPolygon()


def rounded_coordinates(value):
    if isinstance(value, (list, tuple)):
        return [rounded_coordinates(item) for item in value]
    return round(value, 7)


def convert_regions(regions: list[Region], crs: CRS, grid_meters: float) -> tuple[dict, list[dict]]:
    if not math.isfinite(grid_meters) or grid_meters <= 0:
        raise ValueError("grid-meters must be a finite positive number")
    validate_regions(regions)
    to_wgs84 = Transformer.from_crs(crs, 4326, always_xy=True)
    features, changes = [], []
    for region in sorted(regions, key=lambda r: r.code):
        original = region.geometry
        valid = original if original.is_valid else polygonal_geometry(make_valid(original))
        if valid.is_empty or valid.area <= 0:
            raise ValueError(f"No valid area in region {region.code}")
        if not original.is_valid and abs(valid.area - original.area) / valid.area > 0.01:
            raise ValueError(f"Geometry repair changes >1% of region {region.code}; review source")
        reduced = set_precision(valid, grid_meters)
        if reduced.is_empty:
            raise ValueError(f"Grid collapses entire region {region.code}")
        geographic = orient_polygons(transform(to_wgs84.transform, reduced))
        geometry = mapping(geographic)
        geometry["coordinates"] = rounded_coordinates(geometry["coordinates"])
        result = shape(geometry)
        west, south, east, north = result.bounds
        if not (124 <= west <= east <= 132 and 32 <= south <= north <= 39.5):
            raise ValueError(f"Coordinates outside Korea: {region.code} {result.bounds}")
        if not result.is_valid or result.is_empty:
            raise ValueError(f"Invalid output geometry: {region.code}")
        features.append({
            "type": "Feature",
            "properties": {"code": region.code, "name": display_name(region.name),
                           "parentCode": region.code[:2]},
            "geometry": geometry,
        })
        changes.append({
            "code": region.code, "repaired": not original.is_valid,
            "sourceAreaSquareMeters": round(valid.area, 2),
            "outputAreaSquareMeters": round(reduced.area, 2),
        })
    return {"type": "FeatureCollection", "features": features}, changes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="SIG .shp, SIG ZIP or Vworld nationwide ZIP")
    parser.add_argument("output", type=Path, help="App-ready GeoJSON")
    parser.add_argument("--grid-meters", type=float, default=250)
    parser.add_argument("--corrections", type=Path, help="Reviewed corrections JSON")
    parser.add_argument("--report", type=Path, help="Audit report outside the app bundle")
    args = parser.parse_args()
    outputs = [args.output] + ([args.report] if args.report else [])
    if len({p.resolve() for p in [args.source, *outputs]}) != 1 + len(outputs):
        parser.error("Source, output and report must be different paths")
    source_hash = hashlib.sha256(args.source.read_bytes()).hexdigest()
    regions, crs = read_regions(args.source)
    applied = []
    if args.corrections:
        applied = apply_corrections(
            regions, source_hash, crs, json.loads(args.corrections.read_text(encoding="utf-8"))
        )
    collection, changes = convert_regions(regions, crs, args.grid_meters)
    encoded = json.dumps(collection, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n"
    # Nothing is written until every input record and output geometry passes.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(encoded, encoding="utf-8")
    if args.report:
        report = {
            "source": args.source.name, "sourceSHA256": source_hash,
            "sourceEPSG": crs.to_epsg(), "outputEPSG": 4326,
            "gridMeters": args.grid_meters, "regionCount": len(regions),
            "outputSHA256": hashlib.sha256(encoded.encode()).hexdigest(),
            "corrections": applied, "geometryChanges": changes,
        }
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(regions)} regions (EPSG:{crs.to_epsg()} → 4326) to {args.output}")


if __name__ == "__main__":
    main()
