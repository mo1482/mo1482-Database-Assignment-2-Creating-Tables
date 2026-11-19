/*
    BidNile Task 4 validation - run AFTER the Excel import and AfterImport.sql.
    This file is read-only. It does not insert, update, or delete data.
*/
USE BidNile;
GO

/* 1) Row counts. Expected minimums are based on the assignment. */
SELECT N'Geo.Country' AS TableName, COUNT_BIG(*) AS RowCount FROM Geo.Country
UNION ALL SELECT N'Geo.City', COUNT_BIG(*) FROM Geo.City
UNION ALL SELECT N'Accounts.Member', COUNT_BIG(*) FROM Accounts.Member
UNION ALL SELECT N'Accounts.Wallet', COUNT_BIG(*) FROM Accounts.Wallet
UNION ALL SELECT N'Operations.Warehouse', COUNT_BIG(*) FROM Operations.Warehouse
UNION ALL SELECT N'Operations.Employee', COUNT_BIG(*) FROM Operations.Employee
UNION ALL SELECT N'Commerce.Category', COUNT_BIG(*) FROM Commerce.Category
UNION ALL SELECT N'Commerce.Item', COUNT_BIG(*) FROM Commerce.Item
UNION ALL SELECT N'Commerce.ItemPhoto', COUNT_BIG(*) FROM Commerce.ItemPhoto
UNION ALL SELECT N'Commerce.Auction', COUNT_BIG(*) FROM Commerce.Auction
UNION ALL SELECT N'Commerce.Bid', COUNT_BIG(*) FROM Commerce.Bid
UNION ALL SELECT N'Marketing.FollowedAuction', COUNT_BIG(*) FROM Marketing.FollowedAuction
ORDER BY TableName;
GO

/* 2) Headline assignment requirements. All results should be PASS. */
SELECT N'At least 5 countries' AS CheckName,
       IIF((SELECT COUNT(*) FROM Geo.Country) >= 5, N'PASS', N'FAIL') AS Result
UNION ALL SELECT N'At least 5 cities',
       IIF((SELECT COUNT(*) FROM Geo.City) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 10 members',
       IIF((SELECT COUNT(*) FROM Accounts.Member) >= 10, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 rows in Wallet',
       IIF((SELECT COUNT(*) FROM Accounts.Wallet) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 rows in Warehouse',
       IIF((SELECT COUNT(*) FROM Operations.Warehouse) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 rows in Employee',
       IIF((SELECT COUNT(*) FROM Operations.Employee) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 categories',
       IIF((SELECT COUNT(*) FROM Commerce.Category) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 items',
       IIF((SELECT COUNT(*) FROM Commerce.Item) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 item photos',
       IIF((SELECT COUNT(*) FROM Commerce.ItemPhoto) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 auctions',
       IIF((SELECT COUNT(*) FROM Commerce.Auction) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 40 bids',
       IIF((SELECT COUNT(*) FROM Commerce.Bid) >= 40, N'PASS', N'FAIL')
UNION ALL SELECT N'At least 5 followed-auction rows',
       IIF((SELECT COUNT(*) FROM Marketing.FollowedAuction) >= 5, N'PASS', N'FAIL')
UNION ALL SELECT N'Every member has a wallet',
       IIF(NOT EXISTS (
           SELECT 1 FROM Accounts.Member AS m
           LEFT JOIN Accounts.Wallet AS w ON w.MemberId = m.MemberId
           WHERE w.MemberId IS NULL
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'Every warehouse has a manager and manager date',
       IIF(NOT EXISTS (
           SELECT 1 FROM Operations.Warehouse
           WHERE ManagerMemberId IS NULL OR ManagerSince IS NULL
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'Every warehouse has at least one employee',
       IIF(NOT EXISTS (
           SELECT 1 FROM Operations.Warehouse AS w
           WHERE NOT EXISTS (
               SELECT 1 FROM Operations.Employee AS e
               WHERE e.WarehouseId = w.WarehouseId
           )
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'Every manager works in the warehouse he manages',
       IIF(NOT EXISTS (
           SELECT 1 FROM Operations.Warehouse AS w
           WHERE NOT EXISTS (
               SELECT 1 FROM Operations.Employee AS e
               WHERE e.MemberId = w.ManagerMemberId
                 AND e.WarehouseId = w.WarehouseId
           )
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'At least one member joined through an invitation',
       IIF(EXISTS (
           SELECT 1 FROM Accounts.Member WHERE InvitedByMemberId IS NOT NULL
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'At least one seller also placed a bid',
       IIF(EXISTS (
           SELECT 1
           FROM Commerce.Item AS i
           INNER JOIN Commerce.Bid AS b ON b.MemberId = i.SellerMemberId
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'Car specifications contain car-specific JSON keys',
       IIF(EXISTS (
           SELECT 1 FROM Commerce.Item
           WHERE CategoryId = 110
             AND JSON_VALUE(Specifications, '$.brand') IS NOT NULL
             AND JSON_VALUE(Specifications, '$.model') IS NOT NULL
             AND JSON_VALUE(Specifications, '$.mileageKm') IS NOT NULL
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'Phone specifications contain phone-specific JSON keys',
       IIF(EXISTS (
           SELECT 1 FROM Commerce.Item
           WHERE CategoryId = 210
             AND JSON_VALUE(Specifications, '$.brand') IS NOT NULL
             AND JSON_VALUE(Specifications, '$.storageGb') IS NOT NULL
             AND JSON_VALUE(Specifications, '$.color') IS NOT NULL
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'No item is inspected by its own seller',
       IIF(NOT EXISTS (
           SELECT 1 FROM Commerce.Item
           WHERE SellerMemberId = InspectorMemberId
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'Every item specifications value is valid JSON',
       IIF(NOT EXISTS (
           SELECT 1 FROM Commerce.Item WHERE ISJSON(Specifications) <> 1
       ), N'PASS', N'FAIL')
UNION ALL SELECT N'At least 2 auction time-zone offsets',
       IIF((SELECT COUNT(DISTINCT DATEPART(TZOFFSET, StartAt)) FROM Commerce.Auction) >= 2,
           N'PASS', N'FAIL')
ORDER BY CheckName;
GO

/* 3) Status coverage: the output should include all five statuses. */
SELECT Status, COUNT(*) AS AuctionCount
FROM Commerce.Auction
GROUP BY Status
ORDER BY Status;
GO

/* 4) Exact local offsets stored on auction start/end values. */
SELECT DISTINCT
    DATEPART(TZOFFSET, StartAt) AS StartOffsetMinutes,
    DATEPART(TZOFFSET, EndAt) AS EndOffsetMinutes
FROM Commerce.Auction
ORDER BY StartOffsetMinutes;
GO

/* 5) Duplicate bid amounts per auction (should return no rows). */
SELECT AuctionId, Amount, COUNT(*) AS DuplicateCount
FROM Commerce.Bid
GROUP BY AuctionId, Amount
HAVING COUNT(*) > 1;
GO

/* 6) Each bid should be placed during its auction's UTC time window. */
SELECT b.BidId, b.AuctionId, b.PlacedAt, a.StartAt, a.EndAt
FROM Commerce.Bid AS b
INNER JOIN Commerce.Auction AS a ON a.AuctionId = b.AuctionId
WHERE b.PlacedAt < CONVERT(DATETIME2(3), SWITCHOFFSET(a.StartAt, '+00:00'))
   OR b.PlacedAt > CONVERT(DATETIME2(3), SWITCHOFFSET(a.EndAt, '+00:00'));
GO

