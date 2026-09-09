#!/usr/bin/env python3
"""Convert the supplied Korean SIG Shapefile into an app-ready GeoJSON file.

The source used by this prototype contains 250 SIG records encoded in CP949
and coordinates in EPSG:5179. Only Python's standard library is required.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class DBFRecord:
    code: str
    name: str


@dataclass
class Ring:
    points: list[tuple[float, float]]
    area: float
    bounds: tuple[float, float, float, float]
    parent: int | None = None
    depth: int | None = None


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Path to sig.shp")
    parser.add_argument("output", type=Path, help="Output GeoJSON path")
    parser.add_argument(
        "--grid-meters",
        type=float,
        default=250.0,
        help="Quantization grid used to reduce boundary detail (default: 250)",
    )
    return parser.parse_args()


def read_dbf(path: Path) -> list[DBFRecord | None]:
    data = path.read_bytes()
    record_count = struct.unpack_from("<I", data, 4)[0]
    header_length = struct.unpack_from("<H", data, 8)[0]
    record_length = struct.unpack_from("<H", data, 10)[0]

    fields: list[tuple[str, int]] = []
    offset = 32
    while data[offset] != 0x0D:
        descriptor = data[offset : offset + 32]
        name = descriptor[:11].split(b"\0", 1)[0].decode("ascii")
        fields.append((name, descriptor[16]))
        offset += 32

    records: list[DBFRecord | None] = []
    for index in range(record_count):
        start = header_length + index * record_length
        raw_record = data[start : start + record_length]
        if not raw_record or raw_record[0] == 0x2A:
            records.append(None)
            continue

        values: dict[str, str] = {}
        field_offset = 1
        for name, length in fields:
            raw_value = raw_record[field_offset : field_offset + length]
            field_offset += length
            values[name] = raw_value.decode("cp949", errors="replace").strip()

        records.append(
            DBFRecord(
                code=values["SIG_CD"],
                name=values["SIG_KOR_NM"],
            )
        )
    return records


def read_polygon_parts(path: Path) -> list[list[list[tuple[float, float]]]]:
    data = path.read_bytes()
    records: list[list[list[tuple[float, float]]]] = []
    offset = 100

    while offset < len(data):
        _, content_words = struct.unpack_from(">2i", data, offset)
        content_start = offset + 8
        content_end = content_start + content_words * 2
        shape_type = struct.unpack_from("<i", data, content_start)[0]

        if shape_type == 0:
            records.append([])
        elif shape_type in (5, 15, 25):
            part_count, point_count = struct.unpack_from(
                "<2i", data, content_start + 36
            )
            parts_start = content_start + 44
            part_indices = list(
                struct.unpack_from(f"<{part_count}i", data, parts_start)
            )
            points_start = parts_start + part_count * 4
            points = [
                struct.unpack_from("<2d", data, points_start + index * 16)
                for index in range(point_count)
            ]

            parts: list[list[tuple[float, float]]] = []
            for index, start in enumerate(part_indices):
                end = (
                    part_indices[index + 1]
                    if index + 1 < len(part_indices)
                    else point_count
                )
                parts.append(points[start:end])
            records.append(parts)
        else:
            raise ValueError(f"Unsupported Shapefile shape type: {shape_type}")

        offset = content_end

    return records


def quantize_ring(
    points: Iterable[tuple[float, float]], grid_meters: float
) -> list[tuple[float, float]]:
    quantized: list[tuple[float, float]] = []
    for x, y in points:
        point = (
            round(x / grid_meters) * grid_meters,
            round(y / grid_meters) * grid_meters,
        )
        if not quantized or quantized[-1] != point:
            quantized.append(point)

    if quantized and quantized[0] != quantized[-1]:
        quantized.append(quantized[0])
    return quantized if len(quantized) >= 4 else []


def signed_area(points: list[tuple[float, float]]) -> float:
    return 0.5 * sum(
        x1 * y2 - x2 * y1
        for (x1, y1), (x2, y2) in zip(points, points[1:])
    )


def ring_bounds(
    points: list[tuple[float, float]],
) -> tuple[float, float, float, float]:
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return min(xs), min(ys), max(xs), max(ys)


def bounds_contain(
    outer: tuple[float, float, float, float],
    inner: tuple[float, float, float, float],
) -> bool:
    return (
        outer[0] <= inner[0]
        and outer[1] <= inner[1]
        and outer[2] >= inner[2]
        and outer[3] >= inner[3]
    )


def point_in_ring(point: tuple[float, float], ring: list[tuple[float, float]]) -> bool:
    x, y = point
    inside = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        crosses = (y1 > y) != (y2 > y)
        if crosses:
            intersection_x = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < intersection_x:
                inside = not inside
    return inside


def make_rings(
    parts: list[list[tuple[float, float]]], grid_meters: float
) -> list[Ring]:
    rings: list[Ring] = []
    for part in parts:
        points = quantize_ring(part, grid_meters)
        if not points:
            continue
        area = signed_area(points)
        if area == 0:
            continue
        rings.append(Ring(points=points, area=area, bounds=ring_bounds(points)))

    for child_index, child in enumerate(rings):
        candidates: list[tuple[float, int]] = []
        sample_point = child.points[0]
        for parent_index, parent in enumerate(rings):
            if child_index == parent_index or abs(parent.area) <= abs(child.area):
                continue
            if not bounds_contain(parent.bounds, child.bounds):
                continue
            if point_in_ring(sample_point, parent.points):
                candidates.append((abs(parent.area), parent_index))
        if candidates:
            child.parent = min(candidates)[1]

    def resolve_depth(index: int) -> int:
        ring = rings[index]
        if ring.depth is not None:
            return ring.depth
        ring.depth = 0 if ring.parent is None else resolve_depth(ring.parent) + 1
        return ring.depth

    for index in range(len(rings)):
        resolve_depth(index)
    return rings


def inverse_epsg5179(x: float, y: float) -> tuple[float, float]:
    """Return longitude/latitude from Korea 2000 / Unified CS coordinates."""
    semi_major_axis = 6_378_137.0
    inverse_flattening = 298.257222101
    flattening = 1.0 / inverse_flattening
    eccentricity_squared = flattening * (2.0 - flattening)
    second_eccentricity_squared = eccentricity_squared / (1.0 - eccentricity_squared)
    scale = 0.9996
    latitude_origin = math.radians(38.0)
    longitude_origin = math.radians(127.5)
    false_easting = 1_000_000.0
    false_northing = 2_000_000.0

    def meridional_arc(latitude: float) -> float:
        e2 = eccentricity_squared
        return semi_major_axis * (
            (1 - e2 / 4 - 3 * e2**2 / 64 - 5 * e2**3 / 256) * latitude
            - (3 * e2 / 8 + 3 * e2**2 / 32 + 45 * e2**3 / 1024)
            * math.sin(2 * latitude)
            + (15 * e2**2 / 256 + 45 * e2**3 / 1024)
            * math.sin(4 * latitude)
            - (35 * e2**3 / 3072) * math.sin(6 * latitude)
        )

    arc = meridional_arc(latitude_origin) + (y - false_northing) / scale
    e1 = (1 - math.sqrt(1 - eccentricity_squared)) / (
        1 + math.sqrt(1 - eccentricity_squared)
    )
    mu = arc / (
        semi_major_axis
        * (
            1
            - eccentricity_squared / 4
            - 3 * eccentricity_squared**2 / 64
            - 5 * eccentricity_squared**3 / 256
        )
    )
    footprint = (
        mu
        + (3 * e1 / 2 - 27 * e1**3 / 32) * math.sin(2 * mu)
        + (21 * e1**2 / 16 - 55 * e1**4 / 32) * math.sin(4 * mu)
        + (151 * e1**3 / 96) * math.sin(6 * mu)
        + (1097 * e1**4 / 512) * math.sin(8 * mu)
    )

    sin_footprint = math.sin(footprint)
    cos_footprint = math.cos(footprint)
    tan_footprint = math.tan(footprint)
    n1 = semi_major_axis / math.sqrt(
        1 - eccentricity_squared * sin_footprint**2
    )
    r1 = (
        semi_major_axis
        * (1 - eccentricity_squared)
        / (1 - eccentricity_squared * sin_footprint**2) ** 1.5
    )
    t1 = tan_footprint**2
    c1 = second_eccentricity_squared * cos_footprint**2
    d = (x - false_easting) / (n1 * scale)

    latitude = footprint - (n1 * tan_footprint / r1) * (
        d**2 / 2
        - (5 + 3 * t1 + 10 * c1 - 4 * c1**2 - 9 * second_eccentricity_squared)
        * d**4
        / 24
        + (
            61
            + 90 * t1
            + 298 * c1
            + 45 * t1**2
            - 252 * second_eccentricity_squared
            - 3 * c1**2
        )
        * d**6
        / 720
    )
    longitude = longitude_origin + (
        d
        - (1 + 2 * t1 + c1) * d**3 / 6
        + (
            5
            - 2 * c1
            + 28 * t1
            - 3 * c1**2
            + 8 * second_eccentricity_squared
            + 24 * t1**2
        )
        * d**5
        / 120
    ) / cos_footprint

    return round(math.degrees(longitude), 6), round(math.degrees(latitude), 6)


def geojson_ring(points: list[tuple[float, float]]) -> list[list[float]]:
    return [list(inverse_epsg5179(x, y)) for x, y in points]


def make_geometry(parts: list[list[tuple[float, float]]], grid_meters: float) -> dict:
    rings = make_rings(parts, grid_meters)
    polygons: list[list[list[list[float]]]] = []

    for index, ring in enumerate(rings):
        if ring.depth is None or ring.depth % 2 != 0:
            continue
        polygon = [geojson_ring(ring.points)]
        direct_holes = [
            candidate
            for candidate in rings
            if candidate.parent == index and candidate.depth == ring.depth + 1
        ]
        polygon.extend(geojson_ring(hole.points) for hole in direct_holes)
        polygons.append(polygon)

    if len(polygons) == 1:
        return {"type": "Polygon", "coordinates": polygons[0]}
    return {"type": "MultiPolygon", "coordinates": polygons}


def main() -> None:
    arguments = parse_arguments()
    dbf_records = read_dbf(arguments.source.with_suffix(".dbf"))
    shape_records = read_polygon_parts(arguments.source)

    if len(dbf_records) != len(shape_records):
        raise ValueError(
            f"DBF/SHP record count mismatch: {len(dbf_records)} / {len(shape_records)}"
        )

    features = []
    for record, parts in zip(dbf_records, shape_records):
        if record is None or not parts:
            continue
        features.append(
            {
                "type": "Feature",
                "properties": {
                    "code": record.code,
                    "name": record.name,
                    "parentCode": record.code[:2],
                },
                "geometry": make_geometry(parts, arguments.grid_meters),
            }
        )

    collection = {"type": "FeatureCollection", "features": features}
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(collection, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"Wrote {len(features)} regions to {arguments.output}")


if __name__ == "__main__":
    main()
