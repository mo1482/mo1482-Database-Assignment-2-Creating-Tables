# Task 4 - Import Guide (SSMS Wizard Only)

This workbook is source data only. Do not type `INSERT` statements by hand. Import the sheets into the existing tables with the SSMS Import and Export Wizard, or use **Edit Top 200 Rows**.

## Before importing

1. Run `database/BidNile.sql` once on a clean `BidNile` database. It includes Task 2 and Task 3, so the final table names and columns are already in place.
2. Confirm that the database has the final schemas: `Geo`, `Accounts`, `Operations`, `Commerce`, and `Marketing`.
3. Do not import the `START_HERE` worksheet.
4. The worksheet omits SQL Server IDENTITY columns. This is intentional. On a fresh database, SQL Server generates these IDs in the sheet row order:
   - `Geo.City.CityId`: 1-5
   - `Operations.Warehouse.WarehouseId`: 1-5
   - `Commerce.Item.ItemId`: 1-5
   - `Commerce.Auction.AuctionId`: 1-5
   - `Commerce.Bid.BidId`: generated automatically
5. The references in the other sheets expect those generated values. Therefore, do not import into tables that already contain rows.

## Import order and destination

Import one worksheet at a time, or select the matching source/destination pairs in the wizard, in this order:

| Order | Excel worksheet | Existing SQL Server table |
|---:|---|---|
| 1 | `Geo_Country` | `Geo.Country` |
| 2 | `Geo_City` | `Geo.City` |
| 3 | `Accounts_Member` | `Accounts.Member` |
| 4 | `Accounts_Wallet` | `Accounts.Wallet` |
| 5 | `Operations_Warehouse` | `Operations.Warehouse` |
| 6 | `Operations_Employee` | `Operations.Employee` |
| 7 | Run `AfterImport.sql` | Assigns each warehouse's manager after Employee rows exist |
| 8 | `Commerce_Category` | `Commerce.Category` |
| 9 | `Commerce_Item` | `Commerce.Item` |
| 10 | `Commerce_ItemPhoto` | `Commerce.ItemPhoto` |
| 11 | `Commerce_Auction` | `Commerce.Auction` |
| 12 | `Commerce_Bid` | `Commerce.Bid` |
| 13 | `Marketing_FollowedAuction` | `Marketing.FollowedAuction` |

`Operations_Warehouse` intentionally has blank `ManagerMemberId` and `ManagerSince` values. The two columns are nullable during the circular relationship import. After `Operations_Employee` is imported, run `support/AfterImport.sql`. It assigns one employee manager to each warehouse and then changes both manager columns to `NOT NULL`.

## Wizard settings

1. In SSMS, right-click `BidNile` > **Tasks** > **Import Data**.
2. Choose **Microsoft Excel** as the data source and browse to `support/BidNile_Import_Data.xlsx`.
3. Check **First row has column names**.
4. Choose the SQL Server destination and connect to the same server and `BidNile` database.
5. Choose **Copy data from one or more tables or views**.
6. In the mapping page, map each source worksheet to the existing destination table shown above. Confirm column mappings by name; do not map source columns into IDENTITY columns.
7. Check the preview for blank manager cells and confirm that date/time values are being interpreted correctly before running the import.
8. Run the import in the listed order. If the wizard is run once for every worksheet, keep the same order.

Important type notes:

- `MemberId` and foreign-key GUID values are supplied by the workbook; do not replace them with generated IDs.
- `Mobile`, `PhoneCode`, national IDs, and IP addresses are text values. Keep their text values intact, including the leading `+` in mobile numbers.
- `Auction.StartAt` and `Auction.EndAt` are ISO-8601 values with offsets (`+02:00`, `+03:00`, `+04:00`) and must land in `DATETIMEOFFSET` columns.
- `Bid.PlacedAt` values are UTC timestamps without an offset because the destination is `DATETIME2(3)`.
- `Item.Specifications` contains JSON text. Do not strip quotation marks or braces.
- The `Featured` and `IsMain` values are Boolean values for SQL Server `BIT` columns.

## After import

1. Run `support/AfterImport.sql` once after importing Employees.
2. Run `support/ValidateData.sql`.
3. Review the row counts and ensure every `PASS` check is returned. Check that all five auction statuses appear and that auction offsets include at least two distinct values.
4. Confirm that the generated identity IDs are 1-5 in City, Warehouse, Item, and Auction. If they are not, stop and fix the import into a clean database before exporting data.

## Required constraint-error screenshots

Capture the error messages from SSMS itself. Do not create sample screenshots or write DML statements for these tests. Use **Edit Top 200 Rows** and enter an invalid value in the grid; the constraint should reject the edit.

1. **Duplicate bid amount:** Open `Commerce.Bid` in Edit Top 200 Rows. Add a new row with `AuctionId = 1`, a valid existing `MemberId`, `Amount = 120500.00` (already used in Auction 1), a new valid timestamp, and a valid IP such as `192.0.2.10`. Save the row and capture the UNIQUE constraint error (`UQ_Bid_Auction_Amount`). Do not keep the invalid row.
2. **Held amount greater than balance:** Open `Accounts.Wallet` in Edit Top 200 Rows. For the first wallet (`Balance = 12000.00`), temporarily enter `HeldAmount = 12001.00`. Save and capture the CHECK constraint error (`CK_Wallet_HeldAmount_Range`). The invalid edit should be rejected.
3. **Seller is also inspector:** Open `Commerce.Item` in Edit Top 200 Rows. For Item 1, copy its `SellerMemberId` value into `InspectorMemberId`. Save and capture the CHECK constraint error (`CK_Item_Seller_NotInspector`). The invalid edit should be rejected.

Save the three real screenshots under `docs/screenshots/` using these names:

- `duplicate-bid-amount.png`
- `held-greater-than-balance.png`
- `seller-is-inspector.png`

## Export the actual data-only script

After the import and validation succeed:

1. Right-click `BidNile` > **Tasks** > **Generate Scripts**.
2. Select all 12 tables in the final database, including `Marketing.FollowedAuction`.
3. Open **Advanced** and set **Types of data to script** to **Data only**.
4. Save the generated output as `database/BidNile_Data.sql`, replacing the comments-only reminder file.

This export is generated by SSMS. Do not hand-write the `INSERT` statements. The comments-only file in the project is not the final export.
