# BidNile Online Auctions

**Name:** [محمد ابراهيم فتحي]  
**Group:**  
**ID:** 

## Files

```text
BidNile-Submission/
├── docs/
│   ├── mapping.png
│   ├── mapping.svg
│   ├── mapping.dot
│   ├── Task1_Mapping_Notes.md
│   ├── erd.png
│   └── screenshots/
│       └── README.md
├── database/
│   ├── BidNile.sql
│   └── BidNile_Data.sql
├── dsa/
│   └── ProductExceptSelf.cs
├── NOTES.md
├── README.md
└── support/
    ├── BidNile_Import_Data.xlsx
    ├── CheckEnvironment.sql
    ├── Reset_BidNile.sql (optional, destructive)
    ├── Task3_Only.sql (run only after Task 2)
    ├── AfterImport.sql
    └── ValidateData.sql
```

The files in `support` are only there to help with Task 4. `support/Task4_Import_Guide.md` gives the import sequence, type notes, constraint-error test values, and Data only export steps. `docs/screenshots/README.md` explains how to capture the four required real screenshots. The required files are in the folders shown in the assignment.

## Task 1 mapping

Open `docs/mapping.png` for the relational mapping diagram. PK columns (including every part of a composite PK) are underlined, and arrows point from FK columns to their referenced PKs. `docs/Task1_Mapping_Notes.md` lists the tables, all FK relationships, the four initial schemas, and the required relationship types.

## Run the database

1. Open SSMS 20 or newer and connect to the SQL Server Database Engine 2019 (15.x) or newer. Installing SSMS alone does not install or upgrade the Database Engine.
2. Run `support/CheckEnvironment.sql` first. Confirm `ProductMajorVersion` is at least 15 and the `ISJSON` test returns 1.
3. Open `database/BidNile.sql` and run it once on a fresh BidNile database.
4. It creates the four original schemas: `Geo`, `Accounts`, `Operations`, and `Commerce`.
5. At the end of Task 3.12, it creates `Marketing` and moves `FollowedAuction` into it.
6. The same file continues below the CREATE section with all Task 3.1–3.12 migrations. Run the full file once from a clean database, or run only the Task 3 section if Task 2 has already completed successfully. Do not rerun the full file over existing objects.
7. Task 3 adds the final import columns (`AppLanguage`, `VerifiedAt`, `Featured`, `BuyNowPrice`) and renames `Capacity`/`IPAddress` to `MaxItems`/`DeviceIp`; the Excel headers match this final layout.
8. If Task 2 already ran successfully and you do not want to run its CREATE section again, `support/Task3_Only.sql` contains only Task 3. Run it once.

The script does not create tables in `dbo`. It also does not contain any `INSERT` statements. It is intended for a fresh BidNile database, so do not run it again over the same tables. If an earlier attempt left a partial BidNile database, inspect it first. Only when it contains no data you need to keep, run `support/Reset_BidNile.sql` once, then run `database/BidNile.sql` once. The reset script permanently deletes the BidNile database.

## Import the Task 4 data

Use the Excel file `support/BidNile_Import_Data.xlsx`. Do not import the `START_HERE` sheet. For the full table mapping, import order, type notes, and error tests, follow `support/Task4_Import_Guide.md`. Use the SSMS Import and Export Wizard or **Edit Top 200 Rows** and map the sheets to the existing tables in this order:

1. `Geo_Country` → `Geo.Country`
2. `Geo_City` → `Geo.City`
3. `Accounts_Member` → `Accounts.Member`
4. `Accounts_Wallet` → `Accounts.Wallet`
5. `Operations_Warehouse` → `Operations.Warehouse`
6. `Operations_Employee` → `Operations.Employee`
7. Run `support/AfterImport.sql` to set the warehouse managers. It checks that every warehouse received a manager, temporarily removes the dependent FK/CHECK/index, changes `ManagerMemberId` and `ManagerSince` to `NOT NULL`, then recreates and validates those dependencies. They are nullable in the original table definition only to let the circular relationship be imported in two steps.
8. `Commerce_Category` → `Commerce.Category`
9. `Commerce_Item` → `Commerce.Item`
10. `Commerce_ItemPhoto` → `Commerce.ItemPhoto`
11. `Commerce_Auction` → `Commerce.Auction`
12. `Commerce_Bid` → `Commerce.Bid`
13. `Marketing_FollowedAuction` → `Marketing.FollowedAuction`
14. Run `support/ValidateData.sql`. It reports row-count and business-rule checks; review any `CHECK` result.

The identity columns are not included in Excel. SQL Server generates them while importing, so this order and a fresh empty database are important. The member, seller, employee, and follow records use the supplied GUIDs. Auction start/end values include their offsets. Bid `PlacedAt` values are UTC because the database column is `DATETIME2(3)` and its default uses `SYSUTCDATETIME()`.

The workbook contains 10 members and 40 bids. It has at least five rows in every table. The active cities are in Egypt, Saudi Arabia, and the UAE. Bahrain and Kuwait are reference-only country rows included to meet the five-row minimum; there are no cities for them in this data.

## Finish the data export

`database/BidNile_Data.sql` is currently a reminder file, not the generated data export. After the data has been imported successfully:

1. In SSMS, right-click `BidNile` and choose **Tasks → Generate Scripts**.
2. Select all 12 tables, including `Marketing.FollowedAuction`.
3. Open **Advanced** and set **Types of data to script** to **Data only**.
4. Save the generated script as `database/BidNile_Data.sql`, replacing the reminder file.

Do not type the data `INSERT` statements yourself. They must come from the SSMS export.

## Screenshots

Save the three constraint-error screenshots and the LeetCode Accepted screenshot in `docs/screenshots/`. The file `docs/screenshots/README.md` lists how to produce each one. They need to be captured from your own SSMS and LeetCode sessions.

## LeetCode 238

`dsa/ProductExceptSelf.cs` contains both requested versions:

- `UsingPrefixAndSuffixArrays` uses `prefix[]` and `suffix[]` arrays.
- `UsingConstantExtraSpace` stores prefix products in the result array and uses one variable for suffix products.
- `Solution.ProductExceptSelf` is the method to submit. It calls the O(1) extra-space version.

Both versions use `O(n)` time and do not use division. The second version uses `O(1)` extra space, not counting the result array.

## GitHub

Use the repository that Simulation Academy created for you. Do not create another repository and do not commit to `main`. Copy the branch name and Pull Request title exactly from the assignment page on the website, then commit as you complete each task and open the PR into `main`.

## Before submitting

- [ ] Fill in your name, group, and ID at the top.
- [ ] Run `database/BidNile.sql` on a fresh SQL Server database.
- [ ] Import every Excel data sheet in the listed order.
- [ ] Run `support/AfterImport.sql` and `support/ValidateData.sql`.
- [ ] Replace `database/BidNile_Data.sql` with the real SSMS Data only export.
- [ ] Add all four screenshots to `docs/screenshots/`.
- [ ] Check the GitHub branch and PR title on Simulation Academy, commit the tasks, and open the PR.
