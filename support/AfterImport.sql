/*
    Run AFTER importing the Excel sheets in the order documented in README.md.
    This resolves the circular Warehouse <-> Employee manager relationship.
    It uses UPDATE only; no row is inserted here.

    ManagerMemberId and ManagerSince are nullable only during import. After the
    employee rows exist, this script assigns managers and makes both columns required.
    Their FK, CHECK, and filtered unique index are temporarily removed because SQL
    Server does not allow ALTER COLUMN while those objects depend on the columns.
    They are recreated and validated before the transaction is committed.
*/
USE BidNile;
GO

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE w
    SET
        ManagerMemberId = CASE w.WarehouseName
            WHEN N'Cairo Central Warehouse' THEN 'A1000000-0000-4000-8000-000000000006'
            WHEN N'Alexandria North Warehouse' THEN 'A1000000-0000-4000-8000-000000000007'
            WHEN N'Riyadh Main Warehouse' THEN 'A1000000-0000-4000-8000-000000000008'
            WHEN N'Jeddah West Warehouse' THEN 'A1000000-0000-4000-8000-000000000009'
            WHEN N'Dubai Logistics Warehouse' THEN 'A1000000-0000-4000-8000-000000000010'
        END,
        ManagerSince = CASE w.WarehouseName
            WHEN N'Cairo Central Warehouse' THEN CONVERT(date, '2024-02-01')
            WHEN N'Alexandria North Warehouse' THEN CONVERT(date, '2024-03-15')
            WHEN N'Riyadh Main Warehouse' THEN CONVERT(date, '2024-05-01')
            WHEN N'Jeddah West Warehouse' THEN CONVERT(date, '2024-06-01')
            WHEN N'Dubai Logistics Warehouse' THEN CONVERT(date, '2024-08-01')
        END
    FROM Operations.Warehouse AS w
    WHERE w.ManagerMemberId IS NULL;

    IF EXISTS
    (
        SELECT 1
        FROM Operations.Warehouse
        WHERE ManagerMemberId IS NULL OR ManagerSince IS NULL
    )
        THROW 51100, 'A warehouse manager was not assigned. Check the WarehouseName values in AfterImport.sql.', 1;

    /* Drop dependencies before changing either column's nullability. */
    ALTER TABLE Operations.Warehouse DROP CONSTRAINT FK_Warehouse_ManagerEmployee;
    DROP INDEX UQ_Warehouse_ManagerMemberId ON Operations.Warehouse;
    ALTER TABLE Operations.Warehouse DROP CONSTRAINT CK_Warehouse_ManagerPair;

    ALTER TABLE Operations.Warehouse
        ALTER COLUMN ManagerMemberId UNIQUEIDENTIFIER NOT NULL;

    ALTER TABLE Operations.Warehouse
        ALTER COLUMN ManagerSince DATE NOT NULL;

    /* Restore the named constraints and index, validating the imported values. */
    ALTER TABLE Operations.Warehouse WITH CHECK
        ADD CONSTRAINT CK_Warehouse_ManagerPair
        CHECK
        (
            (ManagerMemberId IS NULL AND ManagerSince IS NULL)
            OR (ManagerMemberId IS NOT NULL AND ManagerSince IS NOT NULL)
        );

    ALTER TABLE Operations.Warehouse WITH CHECK
        ADD CONSTRAINT FK_Warehouse_ManagerEmployee
        FOREIGN KEY (ManagerMemberId) REFERENCES Operations.Employee(MemberId);

    CREATE UNIQUE INDEX UQ_Warehouse_ManagerMemberId
        ON Operations.Warehouse(ManagerMemberId);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT WarehouseId, WarehouseName, ManagerMemberId, ManagerSince
FROM Operations.Warehouse
ORDER BY WarehouseId;
GO
