/*
    BidNile Task 3 only.
    Run this file ONLY after Task 2 completed successfully and all 12 tables exist.
    It adds the FK constraints and performs ALTER tasks 3.1 through 3.12.
    Do not run it more than once on the same database.
*/
USE BidNile;
GO

/* ============================================================================
   TASK 3 - ALTER: BUSINESS CHANGES

   These are migrations for existing tables. They do not drop or recreate any
   table. Run this whole file once, from the beginning, on a fresh database.
   If Task 2 was already run successfully, run only this Task 3 section once.
   ============================================================================ */

USE BidNile;
GO

/* --------------------------------------------------------------------------
   3.1 Connect everything.
   All foreign keys use NO ACTION except ItemPhoto -> Item, which cascades
   deletes as required by the business case. WITH CHECK validates existing
   rows before SQL Server trusts each relationship.
   -------------------------------------------------------------------------- */

-- 3.1 FK_City_Country
ALTER TABLE Geo.City WITH CHECK
ADD CONSTRAINT FK_City_Country
    FOREIGN KEY (CountryCode)
    REFERENCES Geo.Country (CountryCode)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Member_City
ALTER TABLE Accounts.Member WITH CHECK
ADD CONSTRAINT FK_Member_City
    FOREIGN KEY (CityId)
    REFERENCES Geo.City (CityId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Member_Inviter (recursive relationship)
ALTER TABLE Accounts.Member WITH CHECK
ADD CONSTRAINT FK_Member_Inviter
    FOREIGN KEY (InvitedByMemberId)
    REFERENCES Accounts.Member (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Wallet_Member (also enforces the 1:1 wallet relationship)
ALTER TABLE Accounts.Wallet WITH CHECK
ADD CONSTRAINT FK_Wallet_Member
    FOREIGN KEY (MemberId)
    REFERENCES Accounts.Member (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Warehouse_City
ALTER TABLE Operations.Warehouse WITH CHECK
ADD CONSTRAINT FK_Warehouse_City
    FOREIGN KEY (CityId)
    REFERENCES Geo.City (CityId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Employee_Member
ALTER TABLE Operations.Employee WITH CHECK
ADD CONSTRAINT FK_Employee_Member
    FOREIGN KEY (MemberId)
    REFERENCES Accounts.Member (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Employee_Warehouse
ALTER TABLE Operations.Employee WITH CHECK
ADD CONSTRAINT FK_Employee_Warehouse
    FOREIGN KEY (WarehouseId)
    REFERENCES Operations.Warehouse (WarehouseId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Warehouse_ManagerEmployee (completes the circular relationship)
ALTER TABLE Operations.Warehouse WITH CHECK
ADD CONSTRAINT FK_Warehouse_ManagerEmployee
    FOREIGN KEY (ManagerMemberId)
    REFERENCES Operations.Employee (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Category_ParentCategory (recursive relationship)
ALTER TABLE Commerce.Category WITH CHECK
ADD CONSTRAINT FK_Category_ParentCategory
    FOREIGN KEY (ParentCategoryId)
    REFERENCES Commerce.Category (CategoryId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Item_SellerMember
ALTER TABLE Commerce.Item WITH CHECK
ADD CONSTRAINT FK_Item_SellerMember
    FOREIGN KEY (SellerMemberId)
    REFERENCES Accounts.Member (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Item_InspectorEmployee (the inspector must be an employee)
ALTER TABLE Commerce.Item WITH CHECK
ADD CONSTRAINT FK_Item_InspectorEmployee
    FOREIGN KEY (InspectorMemberId)
    REFERENCES Operations.Employee (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Item_Category
ALTER TABLE Commerce.Item WITH CHECK
ADD CONSTRAINT FK_Item_Category
    FOREIGN KEY (CategoryId)
    REFERENCES Commerce.Category (CategoryId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Item_Warehouse (nullable until the item arrives)
ALTER TABLE Commerce.Item WITH CHECK
ADD CONSTRAINT FK_Item_Warehouse
    FOREIGN KEY (WarehouseId)
    REFERENCES Operations.Warehouse (WarehouseId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_ItemPhoto_Item (the only cascading delete in the database)
ALTER TABLE Commerce.ItemPhoto WITH CHECK
ADD CONSTRAINT FK_ItemPhoto_Item
    FOREIGN KEY (ItemId)
    REFERENCES Commerce.Item (ItemId)
    ON DELETE CASCADE ON UPDATE NO ACTION;
GO

-- 3.1 FK_Auction_Item
ALTER TABLE Commerce.Auction WITH CHECK
ADD CONSTRAINT FK_Auction_Item
    FOREIGN KEY (ItemId)
    REFERENCES Commerce.Item (ItemId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Bid_Auction
ALTER TABLE Commerce.Bid WITH CHECK
ADD CONSTRAINT FK_Bid_Auction
    FOREIGN KEY (AuctionId)
    REFERENCES Commerce.Auction (AuctionId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_Bid_Member
ALTER TABLE Commerce.Bid WITH CHECK
ADD CONSTRAINT FK_Bid_Member
    FOREIGN KEY (MemberId)
    REFERENCES Accounts.Member (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_FollowedAuction_Member
ALTER TABLE Commerce.FollowedAuction WITH CHECK
ADD CONSTRAINT FK_FollowedAuction_Member
    FOREIGN KEY (MemberId)
    REFERENCES Accounts.Member (MemberId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- 3.1 FK_FollowedAuction_Auction
ALTER TABLE Commerce.FollowedAuction WITH CHECK
ADD CONSTRAINT FK_FollowedAuction_Auction
    FOREIGN KEY (AuctionId)
    REFERENCES Commerce.Auction (AuctionId)
    ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

/* --------------------------------------------------------------------------
   3.2 Members choose ar or en. The NOT NULL column and its DEFAULT are added
   together. WITH VALUES supplies 'ar' to rows that already exist.
   -------------------------------------------------------------------------- */

-- 3.2
ALTER TABLE Accounts.Member
ADD AppLanguage VARCHAR(2) NOT NULL
    CONSTRAINT DF_Member_AppLanguage DEFAULT ('ar') WITH VALUES;
GO

-- 3.2 Language values are limited to the two supported choices.
ALTER TABLE Accounts.Member WITH CHECK
ADD CONSTRAINT CK_Member_AppLanguage
    CHECK (AppLanguage IN ('ar', 'en'));
GO

/* --------------------------------------------------------------------------
   3.3 Add the featured flag. Existing rows receive 0 (No).
   -------------------------------------------------------------------------- */

-- 3.3
ALTER TABLE Commerce.Item
ADD Featured BIT NOT NULL
    CONSTRAINT DF_Item_Featured DEFAULT (0) WITH VALUES;
GO

/* --------------------------------------------------------------------------
   3.4 Rename columns with sp_rename (not ALTER TABLE ... ALTER COLUMN).
   -------------------------------------------------------------------------- */

-- 3.4 Rename the bid IP column.
EXEC sys.sp_rename
    @objname = N'Commerce.Bid.IPAddress',
    @newname = N'DeviceIp',
    @objtype = N'COLUMN';
GO

-- 3.4 Rename warehouse Capacity.
EXEC sys.sp_rename
    @objname = N'Operations.Warehouse.Capacity',
    @newname = N'MaxItems',
    @objtype = N'COLUMN';
GO

/* --------------------------------------------------------------------------
   3.5 Increase FullName to 150 characters and keep it NOT NULL.
   -------------------------------------------------------------------------- */

-- 3.5
ALTER TABLE Accounts.Member
ALTER COLUMN FullName NVARCHAR(150) NOT NULL;
GO

/* --------------------------------------------------------------------------
   3.6 The smallest integer type that can store 30,000 is SMALLINT.
   The first ALTER attempt is expected to fail because the old CHECK constraint
   depends on MaxItems. TRY/CATCH records that expected error; then the old
   dependency is removed, existing capacities are brought within the new
   business limit, the type is changed, and the new CHECK is added.
   -------------------------------------------------------------------------- */

-- 3.6 Expected first attempt: CK_Warehouse_Capacity depends on MaxItems.
BEGIN TRY
    ALTER TABLE Operations.Warehouse
    ALTER COLUMN MaxItems SMALLINT NOT NULL;

    PRINT '3.6: The initial ALTER COLUMN unexpectedly succeeded; continue with the migration.';
END TRY
BEGIN CATCH
    PRINT '3.6 expected error (dependent CHECK constraint): ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.6 Remove the old CHECK before changing the data type.
ALTER TABLE Operations.Warehouse
DROP CONSTRAINT CK_Warehouse_Capacity;
GO

-- 3.6 Existing values above the new business maximum must be corrected.
UPDATE Operations.Warehouse
SET MaxItems = 30000
WHERE MaxItems > 30000;
GO

-- 3.6 Change INT to SMALLINT (range supports 30,000).
ALTER TABLE Operations.Warehouse
ALTER COLUMN MaxItems SMALLINT NOT NULL;
GO

-- 3.6 Keep the original positive-value rule and add the new upper limit.
ALTER TABLE Operations.Warehouse WITH CHECK
ADD CONSTRAINT CK_Warehouse_MaxItems
    CHECK (MaxItems > 0 AND MaxItems <= 30000);
GO

/* --------------------------------------------------------------------------
   3.7 The commission maximum changes from 30% to 25%.
   Existing rates above 25% are adjusted to the new business maximum before
   the replacement CHECK is validated.
   -------------------------------------------------------------------------- */

-- 3.7 Drop the old 0-to-30 commission CHECK.
ALTER TABLE Commerce.Category
DROP CONSTRAINT CK_Category_Commission;
GO

-- 3.7 Bring existing data into line with the new maximum.
UPDATE Commerce.Category
SET CommissionPercent = 25.00
WHERE CommissionPercent > 25.00;
GO

-- 3.7 Add the replacement 0-to-25 commission CHECK.
ALTER TABLE Commerce.Category WITH CHECK
ADD CONSTRAINT CK_Category_Commission
    CHECK (CommissionPercent BETWEEN 0 AND 25);
GO

/* --------------------------------------------------------------------------
   3.8 Allow PendingReview and make it the DEFAULT for new auctions.
   Existing auction statuses are not rewritten.
   -------------------------------------------------------------------------- */

-- 3.8 Replace the status CHECK.
ALTER TABLE Commerce.Auction
DROP CONSTRAINT CK_Auction_Status;
GO

-- 3.8
ALTER TABLE Commerce.Auction WITH CHECK
ADD CONSTRAINT CK_Auction_Status
    CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled', 'PendingReview'));
GO

-- 3.8 Replace the old default constraint.
ALTER TABLE Commerce.Auction
DROP CONSTRAINT DF_Auction_Status;
GO

-- 3.8 New auctions now start as PendingReview.
ALTER TABLE Commerce.Auction
ADD CONSTRAINT DF_Auction_Status
    DEFAULT ('PendingReview') FOR Status;
GO

/* --------------------------------------------------------------------------
   3.9 Add an optional Buy Now price. The column and CHECK are in separate
   batches so SQL Server compiles the constraint after the column exists.
   WITH CHECK validates existing rows too; existing rows receive NULL, which
   is allowed. NOCHECK would skip validation and leave an untrusted constraint.
   -------------------------------------------------------------------------- */

-- 3.9 Add the nullable column.
ALTER TABLE Commerce.Auction
ADD BuyNowPrice DECIMAL(12,2) NULL;
GO

-- 3.9 Enforce BuyNowPrice > StartingPrice whenever BuyNowPrice is supplied.
ALTER TABLE Commerce.Auction WITH CHECK
ADD CONSTRAINT CK_Auction_BuyNowPrice
    CHECK (BuyNowPrice IS NULL OR BuyNowPrice > StartingPrice);
GO

/* --------------------------------------------------------------------------
   3.10 Mobile numbers must be unique. Existing duplicates, if any, must be
   resolved by the business before this constraint can be validated.
   -------------------------------------------------------------------------- */

-- 3.10
ALTER TABLE Accounts.Member WITH CHECK
ADD CONSTRAINT UQ_Member_Mobile UNIQUE (Mobile);
GO

/* --------------------------------------------------------------------------
   3.11 Add the optional verification timestamp, then remove the old BIT flag.
   IsVerified has a named DEFAULT constraint; SQL Server requires that dependent
   constraint to be dropped before the column can be dropped.
   -------------------------------------------------------------------------- */

-- 3.11 Add the replacement nullable timestamp.
ALTER TABLE Accounts.Member
ADD VerifiedAt DATETIME2(3) NULL;
GO

-- 3.11 Remove the DEFAULT attached to IsVerified.
ALTER TABLE Accounts.Member
DROP CONSTRAINT DF_Member_IsVerified;
GO

-- 3.11 Now the old Yes/No column can be dropped.
ALTER TABLE Accounts.Member
DROP COLUMN IsVerified;
GO

/* --------------------------------------------------------------------------
   3.12 Marketing takes ownership of the followed-auctions table.
   ALTER SCHEMA transfers the existing table; it does not recreate it.
   -------------------------------------------------------------------------- */

-- 3.12 Create the fifth schema only when the business change requires it.
CREATE SCHEMA Marketing AUTHORIZATION dbo;
GO

-- 3.12 Move the table while preserving its data, columns, and constraints.
ALTER SCHEMA Marketing TRANSFER Commerce.FollowedAuction;
GO

/* ============================================================================
   TASK 3 VERIFICATION
   Expected: 12 tables, 19 foreign keys, five schemas after Task 3.12.
   Only FK_ItemPhoto_Item should have ON DELETE CASCADE.
   ============================================================================ */

-- List all tables and their final schemas.
SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'Geo', N'Accounts', N'Operations', N'Commerce', N'Marketing')
ORDER BY s.name, t.name;
GO

-- Count tables and foreign keys added by Task 3.1.
SELECT COUNT(*) AS FinalTableCount
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'Geo', N'Accounts', N'Operations', N'Commerce', N'Marketing');
GO

SELECT COUNT(*) AS ForeignKeyCount
FROM sys.foreign_keys;
GO

-- Review delete actions. FK_ItemPhoto_Item must be the only CASCADE.
SELECT
    fk.name AS ForeignKeyName,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ChildSchema,
    OBJECT_NAME(fk.parent_object_id) AS ChildTable,
    fk.delete_referential_action_desc AS OnDelete,
    fk.update_referential_action_desc AS OnUpdate,
    fk.is_disabled,
    fk.is_not_trusted
FROM sys.foreign_keys AS fk
ORDER BY ChildSchema, ChildTable, fk.name;
GO

-- Confirm the final renamed and added columns.
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS DataType,
    c.max_length,
    c.is_nullable
FROM sys.columns AS c
INNER JOIN sys.tables AS t ON t.object_id = c.object_id
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE (s.name = N'Operations' AND t.name = N'Warehouse'
       AND c.name IN (N'MaxItems'))
   OR (s.name = N'Commerce' AND t.name = N'Bid'
       AND c.name IN (N'DeviceIp'))
   OR (s.name = N'Accounts' AND t.name = N'Member'
       AND c.name IN (N'AppLanguage', N'FullName', N'VerifiedAt', N'Mobile'))
   OR (s.name = N'Commerce' AND t.name = N'Item'
       AND c.name IN (N'Featured'))
   OR (s.name = N'Commerce' AND t.name = N'Auction'
       AND c.name IN (N'Status', N'BuyNowPrice'))
ORDER BY s.name, t.name, c.name;
GO
