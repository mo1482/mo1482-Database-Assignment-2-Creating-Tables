/*
    OPTIONAL RESET SCRIPT - DESTRUCTIVE

    Run ONLY if BidNile is the assignment database created for this exercise
    and contains no data you need to keep. This permanently deletes that database.

    Run this file separately, then run database/BidNile.sql once.
*/
USE master;
GO

IF DB_ID(N'BidNile') IS NOT NULL
BEGIN
    ALTER DATABASE BidNile SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BidNile;
    PRINT N'BidNile was deleted. You can now run database/BidNile.sql once.';
END
ELSE
BEGIN
    PRINT N'BidNile does not exist. You can run database/BidNile.sql now.';
END;
GO
