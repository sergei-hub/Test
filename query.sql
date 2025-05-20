WITH LaptopDataPrepared AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as rn, -- Generate a unique ID for each physical row
        L.code,
        L.model,
        L.screen,
        L.ram,
        L.speed,
        L.price,
        CAST(L.screen AS FLOAT) AS tile_dim1_calc,
        CAST(L.ram AS FLOAT) AS tile_dim2_calc,
        CAST(L.speed AS FLOAT) AS path_dim1_calc,
        CAST(L.price AS FLOAT) AS path_dim2_calc
    FROM Laptop L
),
Orientations AS (
    -- Propagate rn and generate 4 orientations
    SELECT rn, code, model, screen, ram, speed, price,
           path_dim1_calc AS PathL, path_dim2_calc AS PathW,
           tile_dim1_calc AS TileL, tile_dim2_calc AS TileW
    FROM LaptopDataPrepared
    UNION ALL
    SELECT rn, code, model, screen, ram, speed, price,
           path_dim2_calc AS PathL, path_dim1_calc AS PathW,
           tile_dim1_calc AS TileL, tile_dim2_calc AS TileW
    FROM LaptopDataPrepared
    UNION ALL
    SELECT rn, code, model, screen, ram, speed, price,
           path_dim1_calc AS PathL, path_dim2_calc AS PathW,
           tile_dim2_calc AS TileL, tile_dim1_calc AS TileW
    FROM LaptopDataPrepared
    UNION ALL
    SELECT rn, code, model, screen, ram, speed, price,
           path_dim2_calc AS PathL, path_dim1_calc AS PathW,
           tile_dim2_calc AS TileL, tile_dim1_calc AS TileW
    FROM LaptopDataPrepared
),
CalculatedTilesPerOrientation AS (
    SELECT
        rn, code, model, screen, ram, speed, price, -- Propagate rn
        CASE
            -- If any dimension is invalid (NULL, non-positive for tiles, negative for paths), 0 tiles.
            WHEN TileL IS NULL OR TileL <= 0 OR
                 TileW IS NULL OR TileW <= 0 OR
                 PathL IS NULL OR PathL < 0 OR
                 PathW IS NULL OR PathW < 0 THEN 0
            ELSE
                (
                    -- Tiles from unshifted (odd-indexed) rows:
                    -- Number of unshifted rows: (total_full_rows - FLOOR(total_full_rows / 2.0))
                    (
                        FLOOR(PathW / TileW) - FLOOR(FLOOR(PathW / TileW) / 2.0)
                    )
                    *
                    -- Tiles per unshifted row: FLOOR(PathL / TileL)
                    FLOOR(PathL / TileL)
                )
                +
                (
                    -- Tiles from shifted (even-indexed) rows:
                    -- Number of shifted rows: FLOOR(total_full_rows / 2.0)
                    FLOOR(FLOOR(PathW / TileW) / 2.0)
                    *
                    -- Tiles per shifted row:
                    FLOOR(
                        -- Effective non-negative length for shifted row tiling
                        (CASE WHEN (PathL - TileL / 2.0) > 0.0 THEN (PathL - TileL / 2.0) ELSE 0.0 END)
                        / TileL -- TileL is > 0 due to the outer CASE condition checking TileL <= 0
                    )
                )
        END AS num_tiles
    FROM Orientations
)
SELECT
    model,
    screen,
    ram,
    speed,
    price,
    CAST(MAX(COALESCE(num_tiles, 0)) AS BIGINT) AS maxcnt
FROM CalculatedTilesPerOrientation
GROUP BY rn, code, model, screen, ram, speed, price -- Group by rn and all selected non-aggregated columns
ORDER BY model, screen, ram, speed, price
