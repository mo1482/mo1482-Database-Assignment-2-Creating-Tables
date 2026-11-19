/* 0. Create the database if it does not exist. */
USE master;
GO

IF DB_ID(N'BidNile') IS NULL
BEGIN
    CREATE DATABASE BidNile;
END;
GO

USE BidNile;
GO

/* SQL Server 2019 compatibility enables the JSON functions used below. */
ALTER DATABASE BidNile SET COMPATIBILITY_LEVEL = 150;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
GO

/* 1. Exactly four initial schemas. Marketing is added later in Task 3.12. */
CREATE SCHEMA Geo AUTHORIZATION dbo;
GO
CREATE SCHEMA Accounts AUTHORIZATION dbo;
GO
CREATE SCHEMA Operations AUTHORIZATION dbo;
GO
CREATE SCHEMA Commerce AUTHORIZATION dbo;
GO

-- Country is the reference table for the countries supported by the platform.
CREATE TABLE Geo.Country
(
    CountryCode CHAR(2) NOT NULL,
    NameEn      VARCHAR(60) NOT NULL,
    NameAr      NVARCHAR(60) NOT NULL,
    PhoneCode   VARCHAR(5) NOT NULL,

    CONSTRAINT PK_Country PRIMARY KEY (CountryCode),
    CONSTRAINT UQ_Country_NameEn UNIQUE (NameEn)
);
GO

CREATE TABLE Geo.City
(
    CityId      INT IDENTITY(1,1) NOT NULL,
    Name        NVARCHAR(60) NOT NULL,
    CountryCode CHAR(2) NOT NULL, -- FK constraint is added in Task 3.1.

    CONSTRAINT PK_City PRIMARY KEY (CityId),
    CONSTRAINT UQ_City_Country_Name UNIQUE (CountryCode, Name),
    CONSTRAINT CK_City_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(Name))) > 0)
);
GO

/* ============================================================================
   ACCOUNTS
   ============================================================================ */

CREATE TABLE Accounts.Member
(
    MemberId           UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_Member_MemberId DEFAULT (NEWID()),
    FullName           NVARCHAR(100) NOT NULL,
    Email              VARCHAR(254) NOT NULL,
    Mobile             VARCHAR(16) NOT NULL,
    NationalId         VARCHAR(20) NOT NULL,
    BirthDate          DATE NOT NULL,
    IsVerified         BIT NOT NULL
        CONSTRAINT DF_Member_IsVerified DEFAULT (0),
    RegisteredAt       DATETIME2(3) NOT NULL
        CONSTRAINT DF_Member_RegisteredAt DEFAULT (SYSUTCDATETIME()),
    CityId             INT NOT NULL, -- FK constraint is added in Task 3.1.
    InvitedByMemberId  UNIQUEIDENTIFIER NULL, -- Recursive FK is added in Task 3.1.

    CONSTRAINT PK_Member PRIMARY KEY (MemberId),
    CONSTRAINT UQ_Member_Email UNIQUE (Email),
    CONSTRAINT UQ_Member_NationalId UNIQUE (NationalId),
    CONSTRAINT CK_Member_Mobile_International CHECK
    (
        LEN(Mobile) BETWEEN 9 AND 16
        AND Mobile LIKE '+[1-9]%'
        AND SUBSTRING(Mobile, 2, 15) NOT LIKE '%[^0-9]%'
    ),
    CONSTRAINT CK_Member_NationalId_Alphanumeric CHECK
    (
        LEN(NationalId) BETWEEN 1 AND 20
        AND NationalId NOT LIKE '%[^A-Za-z0-9]%'
    ),
    CONSTRAINT CK_Member_Age18 CHECK
    (
        BirthDate <= DATEADD(YEAR, -18, CONVERT(DATE, RegisteredAt))
    )
);
GO

CREATE TABLE Accounts.Wallet
(
    MemberId     UNIQUEIDENTIFIER NOT NULL, -- PK and FK; FK is added in Task 3.1.
    Balance      DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Wallet_Balance DEFAULT (0.00),
    HeldAmount   DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Wallet_HeldAmount DEFAULT (0.00),
    CurrencyCode CHAR(3) NOT NULL
        CONSTRAINT DF_Wallet_CurrencyCode DEFAULT ('EGP'),
    UpdatedAt    DATETIME2(3) NOT NULL
        CONSTRAINT DF_Wallet_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Wallet PRIMARY KEY (MemberId),
    CONSTRAINT CK_Wallet_Balance_NonNegative CHECK (Balance >= 0),
    CONSTRAINT CK_Wallet_HeldAmount_Range CHECK
    (
        HeldAmount >= 0 AND HeldAmount <= Balance
    )
);
GO

/* ============================================================================
   OPERATIONS
   ============================================================================ */

CREATE TABLE Operations.Warehouse
(
    WarehouseId     INT IDENTITY(1,1) NOT NULL,
    WarehouseName   NVARCHAR(80) NOT NULL,
    Capacity        INT NOT NULL,
    CityId          INT NOT NULL, -- FK constraint is added in Task 3.1.
    Latitude        FLOAT(53) NOT NULL,
    Longitude       FLOAT(53) NOT NULL,
    ManagerMemberId UNIQUEIDENTIFIER NULL, -- Circular FK is added in Task 3.1.
    ManagerSince    DATE NULL,

    CONSTRAINT PK_Warehouse PRIMARY KEY (WarehouseId),
    CONSTRAINT UQ_Warehouse_WarehouseName UNIQUE (WarehouseName),
    CONSTRAINT CK_Warehouse_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Warehouse_Latitude CHECK (Latitude BETWEEN -90 AND 90),
    CONSTRAINT CK_Warehouse_Longitude CHECK (Longitude BETWEEN -180 AND 180),
    CONSTRAINT CK_Warehouse_ManagerPair CHECK
    (
        (ManagerMemberId IS NULL AND ManagerSince IS NULL)
        OR
        (ManagerMemberId IS NOT NULL AND ManagerSince IS NOT NULL)
    )
);
GO

/*
   A filtered UNIQUE INDEX is used here (not a table constraint) because the
   manager columns must temporarily allow NULL while the circular Warehouse /
   Employee relationship is populated. It ensures that one employee cannot
   manage more than one warehouse, while allowing several warehouses to have
   a temporary NULL manager during the import sequence. Task 4's AfterImport
   step assigns managers and makes both columns NOT NULL.
*/
CREATE UNIQUE INDEX UQ_Warehouse_ManagerMemberId
    ON Operations.Warehouse (ManagerMemberId)
    WHERE ManagerMemberId IS NOT NULL;
GO

CREATE TABLE Operations.Employee
(
    MemberId    UNIQUEIDENTIFIER NOT NULL, -- PK and FK to Member (Task 3.1).
    WarehouseId INT NOT NULL,              -- FK to Warehouse (Task 3.1).

    CONSTRAINT PK_Employee PRIMARY KEY (MemberId)
);
GO

/* ============================================================================
   COMMERCE
   ============================================================================ */

CREATE TABLE Commerce.Category
(
    CategoryId        INT NOT NULL, -- Assigned by the business; not IDENTITY.
    NameEn            VARCHAR(50) NOT NULL,
    NameAr            NVARCHAR(50) NOT NULL,
    CommissionPercent DECIMAL(4,2) NOT NULL,
    ParentCategoryId  INT NULL, -- Recursive FK is added in Task 3.1.

    CONSTRAINT PK_Category PRIMARY KEY (CategoryId),
    CONSTRAINT UQ_Category_NameEn UNIQUE (NameEn),
    CONSTRAINT CK_Category_Commission CHECK
    (
        CommissionPercent BETWEEN 0 AND 30
    )
);
GO

CREATE TABLE Commerce.Item
(
    ItemId            INT IDENTITY(1,1) NOT NULL,
    Title             NVARCHAR(150) NOT NULL,
    Description       NVARCHAR(MAX) NULL,
    ConditionScore    TINYINT NOT NULL
        CONSTRAINT CK_Item_ConditionScore CHECK (ConditionScore BETWEEN 1 AND 10),
    Specifications    NVARCHAR(MAX) NOT NULL,
    SellerMemberId    UNIQUEIDENTIFIER NOT NULL, -- FK is added in Task 3.1.
    InspectorMemberId UNIQUEIDENTIFIER NULL,     -- Employee FK is added in Task 3.1.
    CategoryId        INT NOT NULL,              -- FK is added in Task 3.1.
    WarehouseId       INT NULL,                  -- NULL until the item arrives.
    ListedAt          DATETIME2(3) NOT NULL
        CONSTRAINT DF_Item_ListedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Item PRIMARY KEY (ItemId),
    CONSTRAINT CK_Item_Specifications_Json CHECK
    (
        ISJSON(Specifications) = 1
    ),
    CONSTRAINT CK_Item_Seller_NotInspector CHECK
    (
        InspectorMemberId IS NULL
        OR SellerMemberId <> InspectorMemberId
    )
);
GO

CREATE TABLE Commerce.ItemPhoto
(
    ItemId        INT NOT NULL, -- FK is added in Task 3.1.
    PhotoPosition TINYINT NOT NULL,
    PhotoUrl      VARCHAR(500) NOT NULL,
    IsMain        BIT NOT NULL
        CONSTRAINT DF_ItemPhoto_IsMain DEFAULT (0),

    CONSTRAINT PK_ItemPhoto PRIMARY KEY (ItemId, PhotoPosition),
    CONSTRAINT CK_ItemPhoto_Position CHECK
    (
        PhotoPosition BETWEEN 1 AND 20
    )
);
GO

CREATE TABLE Commerce.Auction
(
    AuctionId     INT IDENTITY(1,1) NOT NULL,
    ItemId        INT NOT NULL, -- FK is added in Task 3.1.
    StartingPrice DECIMAL(12,2) NOT NULL,
    ReservePrice  DECIMAL(12,2) NULL,
    BidIncrement  DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_Auction_BidIncrement DEFAULT (50.00),
    StartAt       DATETIMEOFFSET(0) NOT NULL,
    EndAt         DATETIMEOFFSET(0) NOT NULL,
    Status        VARCHAR(20) NOT NULL
        CONSTRAINT DF_Auction_Status DEFAULT ('Draft'),

    CONSTRAINT PK_Auction PRIMARY KEY (AuctionId),
    CONSTRAINT CK_Auction_StartingPrice CHECK (StartingPrice > 0),
    CONSTRAINT CK_Auction_ReservePrice CHECK
    (
        ReservePrice IS NULL OR ReservePrice >= StartingPrice
    ),
    CONSTRAINT CK_Auction_BidIncrement CHECK (BidIncrement > 0),
    CONSTRAINT CK_Auction_DateRange CHECK (EndAt > StartAt),
    CONSTRAINT CK_Auction_Status CHECK
    (
        Status IN ('Draft', 'Live', 'Ended', 'Cancelled')
    )
);
GO

CREATE TABLE Commerce.Bid
(
    BidId     BIGINT IDENTITY(1,1) NOT NULL,
    AuctionId INT NOT NULL, -- FK is added in Task 3.1.
    MemberId  UNIQUEIDENTIFIER NOT NULL, -- FK is added in Task 3.1.
    Amount    DECIMAL(12,2) NOT NULL,
    PlacedAt  DATETIME2(3) NOT NULL
        CONSTRAINT DF_Bid_PlacedAt DEFAULT (SYSUTCDATETIME()),
    IPAddress VARCHAR(45) NOT NULL,

    CONSTRAINT PK_Bid PRIMARY KEY (BidId),
    CONSTRAINT UQ_Bid_Auction_Amount UNIQUE (AuctionId, Amount),
    CONSTRAINT CK_Bid_Amount CHECK (Amount > 0)
);
GO

CREATE TABLE Commerce.FollowedAuction
(
    MemberId   UNIQUEIDENTIFIER NOT NULL, -- FK is added in Task 3.1.
    AuctionId  INT NOT NULL,              -- FK is added in Task 3.1.
    FollowedAt DATETIME2(3) NOT NULL
        CONSTRAINT DF_FollowedAuction_FollowedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_FollowedAuction PRIMARY KEY (MemberId, AuctionId)
);
GO

/* ============================================================================
   TASK 2 VERIFICATION
   There must be 12 tables, exactly four user schemas, and no FK constraints yet.
   ============================================================================ */

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'Geo', N'Accounts', N'Operations', N'Commerce')
ORDER BY s.name, t.name;
GO

SELECT
    COUNT(*) AS CreatedTableCount
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'Geo', N'Accounts', N'Operations', N'Commerce');
GO

SELECT
    COUNT(*) AS ForeignKeyCount_Task2
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS t ON t.object_id = fk.parent_object_id
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name IN (N'Geo', N'Accounts', N'Operations', N'Commerce');
GO


USE BidNile;
GO

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


-- 3.10
ALTER TABLE Accounts.Member WITH CHECK
ADD CONSTRAINT UQ_Member_Mobile UNIQUE (Mobile);
GO


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

-- 3.12 Create the fifth schema only when the business change requires it.
CREATE SCHEMA Marketing AUTHORIZATION dbo;
GO

-- 3.12 Move the table while preserving its data, columns, and constraints.
ALTER SCHEMA Marketing TRANSFER Commerce.FollowedAuction;
GO

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
