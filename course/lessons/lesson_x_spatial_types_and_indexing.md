**Language:** English | [Українська](../../i18n/uk/course/lessons/lesson_x_spatial_types_and_indexing.md)

<h2 align="center">Bonus — Spatial types and spatial indexing (overview)</h2>

*Intro:* Spatial queries fail in subtle ways when SRID, units, or coordinate order are misunderstood. This bonus lesson gives a careful overview of geometry vs geography, common spatial shapes, and simple distance/radius patterns—plus the mindset to validate results before you trust a map.

Spatial work is deceptively “visual”: outputs often look plausible even when they’re wrong. A point with swapped coordinates may still render somewhere, and a distance computed in unexpected units can still be a number that seems reasonable until you sanity-check it.

We’ll focus on the few decisions that matter most early: which type matches your reality (Earth vs plane), what SRID means in your system, and how to interpret distance/area results. You’ll also see how to combine correctness checks with performance thinking—narrow candidates first, then apply spatial predicates, and only then consider spatial indexes where they genuinely help.

## Goal
Get a safe, correct introduction to SQL Server spatial data types and typical queries.

## Who this lesson is for
- People doing geo features (radius search, distance checks) who need correct fundamentals.
- Learners who want to recognize when spatial is the right tool (and when it’s overkill).

## Prerequisites
- Basic `SELECT`/`WHERE`.
- You don’t need GIS experience, but you must be careful with coordinate systems.

## Notes
Spatial is a specialized topic. This lesson focuses on correct fundamentals and simple, verifiable demos.

The main reason teams get into trouble with spatial is not the syntax — it’s assumptions. If you assume the wrong coordinate system, swap latitude/longitude, or interpret units incorrectly, you can get answers that look plausible but are wrong.

Treat spatial work like you would treat time zones: always name your assumptions, store SRID consistently, and validate with a couple of known distances/points before you trust results.

For learning, the goal is to build correct instincts: choose the right type (`geography` vs `geometry`), keep SRID explicit, and verify outputs.

## Types
- `geometry`: planar (Euclidean) calculations.
- `geography`: round-earth model (latitude/longitude on a spheroid).

**Quick comparison**

| Type | What it models | Typical input coordinates | Distance/area units (common case) | Good for |
|---|---|---|---|---|
| `geography` | Round-earth (ellipsoidal) | Latitude/longitude (degrees) + SRID | Typically meters / square meters (depends on SRID) | Real-world Earth distances, radius search by meters |
| `geometry` | Planar (Euclidean) | Projected X/Y (or any planar system) + SRID | Same unit as your coordinates | Local/planar calculations, engineered coordinate systems |

**Spatial object instance types (shapes)**

SQL Server spatial types recognize a set of OGC-like instance types. The most commonly instantiable ones are:

| Instance type | Category | What it represents |
|---|---|---|
| `Point` | Simple | Single location |
| `LineString` | Simple | Connected line segments |
| `CircularString` | Simple | Circular arc segments |
| `CompoundCurve` | Simple | Mix of line and circular segments |
| `Polygon` | Simple | Area boundary (straight edges) |
| `CurvePolygon` | Simple | Area boundary (can include curves) |
| `MultiPoint` | Collection | Set of points |
| `MultiLineString` | Collection | Set of lines |
| `MultiPolygon` | Collection | Set of polygons |
| `GeometryCollection` | Collection | Mixed set of spatial objects |
| `FullGlobe` | Geography-only | Special geography polygon covering the entire globe |

If your data is latitude/longitude on Earth, `geography` is usually the right starting point. Distances are reported in meters, and calculations follow a curved-earth model.

If your data is already in a projected, planar coordinate system (or you are working on small areas where planar math is acceptable), `geometry` can be appropriate — but then “distance units” are whatever your coordinate system uses.

In both cases, SRID is not decoration. It’s part of the meaning of the coordinates, and mixing SRIDs is a fast path to incorrect results.

## Why spatial types exist
**What problem they solve:** storing shapes/points and doing geometry operations (distance, containment, intersections) correctly.

The practical value is that the engine becomes responsible for the hard parts: distance math, containment checks, and shape operations. That reduces the number of “hand-rolled trigonometry” bugs that show up later as customer-facing issues.

Spatial also gives you an ecosystem of functions (`STDistance`, `STIntersects`, and friends) that are consistent and composable. Instead of scattering geo math across application code, you keep it near the data.

The trade-off is that spatial is opinionated: you must respect coordinate systems and be deliberate about validation and performance.

**Benefits:**
- correctness: distance/containment logic lives in the engine
- expressiveness: fewer “hand-rolled” math bugs

**Pitfalls:**
- coordinate system matters (SRID); lat/long must use the correct type and SRID
- units differ: `geography` distance is in meters; `geometry` distance is in the coordinate system’s units

## Labs (minimal, self-contained)

### Lab 1 — Create a table with a `geography` column
This lab sets up the smallest possible “places table”: an ID, a name, and a location. Keeping it minimal is helpful because it forces you to focus on the spatial column and the operations around it.

We use `geography` to represent latitude/longitude on Earth. In real schemas you might also store metadata (country, city, category) to support non-spatial filtering before you apply spatial predicates.

After you create the table, your next job is to keep SRID and coordinate meaning consistent across all rows — consistency is what makes spatial queries trustworthy.
```sql
DROP TABLE IF EXISTS dbo.Places;
GO

CREATE TABLE dbo.Places(
  PlaceID int NOT NULL PRIMARY KEY,
  Name nvarchar(50) NOT NULL,
  Location geography NOT NULL
);
GO
```

### Lab 2 — Insert a couple of points
Now we add two points with SRID 4326 (the common latitude/longitude SRID). The important part is not the numbers themselves, but that both points share the same SRID and represent the same coordinate model.

When you work with real data, always validate the coordinate order expected by your constructor and your data source. A lat/long swap can place points in the wrong country while still producing “reasonable” distances.

If you can, test one or two known reference points (for example, two nearby locations with an approximate known distance). That kind of sanity check saves hours later.
```sql
INSERT INTO dbo.Places(PlaceID, Name, Location)
VALUES
  (1, N'Point A', geography::Point(50.4501, 30.5234, 4326)),
  (2, N'Point B', geography::Point(49.8397, 24.0297, 4326));
```

### Lab 3 — Compute distance (meters)
Distance queries are the first thing most people do with spatial. Here we compute the distance between the two inserted points.

Because this is `geography`, `STDistance` returns meters. That unit guarantee is one of the reasons `geography` is convenient for Earth coordinates.

When you run it, focus on whether the magnitude makes sense. You don’t need an exact expected value, but you should be able to say “this is hundreds of kilometers, not 5 meters or 50,000 km”.
```sql
SELECT a.Name AS FromName,
       b.Name AS ToName,
       a.Location.STDistance(b.Location) AS DistanceMeters
FROM dbo.Places AS a
CROSS JOIN dbo.Places AS b
WHERE a.PlaceID = 1 AND b.PlaceID = 2;
```

### Lab 4 — Simple radius search (within X meters)
Radius search is a very common product feature: “places within 1 km”, “stores near me”, “deliveries within a zone”. The naive version is exactly what you see here: compute distance to a center point and filter by a radius.

This pattern is correct, but performance depends on how many rows you scan. In production, you typically combine it with additional filters (category, city, active flag) and—when appropriate—use spatial indexing to avoid checking distance against every row.

As a correctness habit, keep the radius unit explicit. Here it’s meters, so a radius of 500000 means 500 km.
```sql
DECLARE @Center geography = geography::Point(50.4501, 30.5234, 4326);
DECLARE @RadiusMeters float = 500000; -- 500 km

SELECT PlaceID, Name
FROM dbo.Places
WHERE Location.STDistance(@Center) <= @RadiusMeters;
```

### Lab 5 — Spatial index (template)
Spatial indexes exist for the same reason as any index: avoid scanning everything. They can dramatically speed up spatial predicates when used appropriately.

The catch is that spatial indexing is configuration-heavy and data-dependent. The right settings depend on your data distribution, your query shapes, and whether you use `geography` or `geometry`.

Treat this lab as a placeholder: the important lesson is not the exact syntax, but that you should test spatial queries with and without an index on representative data and validate the plan.
Spatial indexes have required options and depend on your table/data. This is a typical shape:
```sql
-- Example template (adjust BOUNDING_BOX / GRIDS per your data)
-- CREATE SPATIAL INDEX IX_Places_Location
-- ON dbo.Places(Location)
-- USING GEOGRAPHY_GRID;
```

## Summary
Spatial is powerful when you need correct geo behavior and expressive spatial predicates close to your data. It’s also unforgiving when assumptions are wrong.

If you take one thing away, let it be this: always keep SRID and units explicit, and always sanity-check a couple of results before you trust a spatial feature.

Once correctness is established, start thinking about performance: reduce the candidate set with normal filters, then apply spatial predicates and indexes where they help.
- Use `geography` for lat/long on Earth, `geometry` for planar.
- Validate results and coordinate systems (SRID).

**Microsoft Docs (Learn):**
- [Spatial data types overview](https://learn.microsoft.com/sql/relational-databases/spatial/spatial-data-types-overview)
- [Spatial reference identifiers (SRIDs)](https://learn.microsoft.com/sql/relational-databases/spatial/spatial-reference-identifiers-srids)
- [STDistance (geography data type)](https://learn.microsoft.com/sql/t-sql/spatial-geography/stdistance-geography-data-type)
- [STDistance (geometry data type)](https://learn.microsoft.com/sql/t-sql/spatial-geometry/stdistance-geometry-data-type)
- [Spatial indexes overview](https://learn.microsoft.com/sql/relational-databases/spatial/spatial-indexes-overview)

*Conclusion:* Make assumptions explicit: SRID, units, and coordinate order. Once results pass sanity checks, layer on performance with normal filters and spatial indexes where they actually help.
