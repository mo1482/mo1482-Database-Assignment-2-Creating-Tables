/*
    BidNile environment check - SAFE / READ ONLY
    Run this before running database/BidNile.sql.
    The assignment requires SQL Server 2019 (15.x) or newer.
*/
USE master;
GO

SELECT
    @@VERSION AS FullVersion,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductMajorVersion') AS ProductMajorVersion,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('EngineEdition') AS EngineEdition;
GO

SELECT
    name AS DatabaseName,
    state_desc AS DatabaseState,
    compatibility_level AS CompatibilityLevel
FROM sys.databases
WHERE name = N'BidNile';
GO

/* ISJSON was introduced in SQL Server 2016 (13.x).
   The assignment still requires SQL Server 2019 (15.x) or newer. */
SELECT ISJSON(N'{"ready":true}') AS IsJsonFunctionAvailable;
GO
