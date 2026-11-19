# BidNile - Notes

## 1. The four schemas

I split the tables by the part of the system they belong to:

| Schema | Tables | Reason |
|---|---|---|
| `Geo` | `Country`, `City` | Stores country and city information used by members and warehouses. |
| `Accounts` | `Member`, `Wallet` | Stores member details, invitations, and each member's wallet. |
| `Operations` | `Warehouse`, `Employee` | Stores the warehouses and the employees working in them. |
| `Commerce` | `Category`, `Item`, `ItemPhoto`, `Auction`, `Bid`, `FollowedAuction` | Stores the items, categories, auctions, bids, and follows. |

In Task 3.12, I create the `Marketing` schema and move `FollowedAuction` from `Commerce` to `Marketing`. The design in Task 1 starts with four schemas; the fifth schema is added later because the assignment asks for it.

## 2. Relationships

- **1:1 - Member and Wallet:** `Wallet.MemberId` is both its primary key and a foreign key to `Member.MemberId`. This means a member cannot have two wallets and a wallet cannot belong to two members.
- **1:1 optional - Member and Employee:** `Employee.MemberId` is a PK and FK to `Member`. A member can be an employee, but not every member has to be one.
- **1:N - Country and City:** `City.CountryCode` points to `Country.CountryCode`. The unique key on `(CountryCode, Name)` allows the same city name in different countries but not twice in one country.
- **1:N - City and Member/Warehouse:** both tables store `CityId`, so each member and warehouse has one city, while a city can have many members and warehouses.
- **1:N - Warehouse and Employee:** `Employee.WarehouseId` points to `Warehouse.WarehouseId`. Each employee works in one warehouse and a warehouse can have many employees.
- **1:N - Category and Item:** `Item.CategoryId` points to `Category.CategoryId`.
- **1:N - Member and Item:** `SellerMemberId` identifies the seller. `InspectorMemberId` points to `Employee.MemberId`, so the inspector must be an employee. `CK_Item_Seller_NotInspector` stops the seller from inspecting their own item.
- **1:N - Item and Auction:** `Auction.ItemId` points to an item. The same item can have more than one auction over time.
- **1:N - Auction/Member and Bid:** each bid belongs to one auction and one member. A member can bid more than once on the same auction. `BIGINT` is used for the bid ID, and `(AuctionId, Amount)` is unique.
- **M:N - Member and Auction follows:** `FollowedAuction` is the bridge table. Its composite PK `(MemberId, AuctionId)` prevents the same member from following the same auction twice. `FollowedAt` stores when the follow started.
- **M:N - Member and Auction bidding:** bids also connect members and auctions, but `Bid` is a separate transaction table because every bid has its own amount, time, and device IP. Repeated bids by one member are allowed.
- **Recursive - Member invitations:** `Member.InvitedByMemberId` points back to `Member.MemberId`. A member can invite many people, while each invited member has at most one inviter.
- **Recursive - Category tree:** `Category.ParentCategoryId` points back to `Category.CategoryId`. A top-level category has `NULL` in this column.
- **Circular - Warehouse and Employee:** `Employee.WarehouseId` points to `Warehouse`, and `Warehouse.ManagerMemberId` points to `Employee`. The filtered unique index on `ManagerMemberId` means one employee cannot manage more than one warehouse while manager values are still nullable. The manager columns are nullable during the initial data import so I can add the warehouse rows first and employees second. `AfterImport.sql` assigns the managers, makes both columns required, and recreates the index as a normal unique index.
- **Weak entity - ItemPhoto:** its key is `(ItemId, PhotoPosition)`. The item ID is part of the photo's PK and FK, and deleting an item deletes its photos with `ON DELETE CASCADE`. The position check allows only 1 through 20.

## 3. Data types

- **GUID for members:** the app can create the member ID before sending the request to the server. `UNIQUEIDENTIFIER` allows the app to send that ID. `NEWID()` is the database default when the app does not provide one; the app can still send its own GUID.
- **BIGINT for bids:** the assignment says the number of bids will pass 2.1 billion. An `INT` has a maximum of 2,147,483,647, so `BIGINT` gives more room.
- **FLOAT for GPS:** GPS values are approximate measurements, so an approximate numeric type is suitable. I also check that latitude is between -90 and 90 and longitude is between -180 and 180.
- **DECIMAL for money:** money needs exact decimal values. `DECIMAL(12,2)` stores two decimal places and supports the wallet maximum of `9,999,999,999.99`.
- **DATETIMEOFFSET for auction dates:** auctions can be in Cairo (+02:00), Riyadh (+03:00), or Dubai (+04:00). `DATETIMEOFFSET` keeps the local time and its offset together.
- **DATETIME2(3) for other timestamps:** registration, bids, wallet updates, item listing, and follows need millisecond precision. The defaults use UTC time.
- **VARCHAR/NVARCHAR:** I use `VARCHAR` for fields expected to contain Latin text, such as email, mobile, URLs, and IP addresses. I use `NVARCHAR` for names and descriptions because they can contain Arabic.
- **JSON:** the script targets SQL Server 2019+, so specifications are stored in `NVARCHAR(MAX)` with `CHECK (ISJSON(Specifications) = 1)`. This checks that each value is valid JSON.

## 4. Why the circular relationship is added with ALTER

When I create `Warehouse`, the `Employee` table does not exist yet. If I create `Employee` first, the `Warehouse` table does not exist. For that reason, I create both tables first with their FK columns, then add the two foreign keys in Task 3.1 using `ALTER TABLE`.

The data has the same issue. I import warehouses with the manager columns empty, import employees, and then run `AfterImport.sql` to assign each warehouse manager. The `CK_Warehouse_ManagerPair` check makes sure `ManagerMemberId` and `ManagerSince` are either both filled or both empty.

## 5. Data import order

I use this order because the foreign keys are already enabled. Each parent table needs to have its rows before I import the rows that reference it:

1. `Geo.Country` - the city table needs its country rows first.
2. `Geo.City` - members and warehouses both reference a city.
3. `Accounts.Member` - wallets, employees, items, bids, and follows reference members. The inviter rows are ordered so the inviter is already in the table.
4. `Accounts.Wallet` - each wallet references an existing member.
5. `Operations.Warehouse` - employees reference a warehouse. I leave the manager columns empty for now because employees have not been imported yet.
6. `Operations.Employee` - each employee references a member and a warehouse.
7. Run `support/AfterImport.sql` - it fills the manager ID and manager date after the employee rows exist, checks that no warehouse was missed, and makes both manager columns `NOT NULL`.
8. `Commerce.Category` - parent categories are in the sheet before their child categories.
9. `Commerce.Item` - each item needs its seller, inspector, category, and (when it has arrived) warehouse.
10. `Commerce.ItemPhoto` - every photo needs its item first.
11. `Commerce.Auction` - every auction needs its item first.
12. `Commerce.Bid` - every bid needs an existing auction and member.
13. `Marketing.FollowedAuction` - each follow needs an existing member and auction.

The Excel workbook has 10 members and 40 bids. It has at least five rows in every table: Country 5, City 5, Member 10, Wallet 10, Warehouse 5, Employee 5, Category 5, Item 5, ItemPhoto 5, Auction 5, Bid 40, and FollowedAuction 6. The active cities are in Egypt, Saudi Arabia, and the UAE. Bahrain and Kuwait are included only as country reference rows to meet the five-row minimum; no cities are assigned to them.
Member 3 lists an item and also places bids on another auction. The 40 bids are placed while Auctions 1 and 2 are open; their `PlacedAt` values are UTC, while the auction start and end values keep the local offsets. The auction rows include +02:00, +03:00, and +04:00. The item JSON examples include different fields for a car and a phone.

## 6. ALTER tasks and the errors

- **3.1 - Foreign keys:** I add all 19 foreign keys with `ALTER TABLE ... ADD CONSTRAINT`. All relationships use `ON DELETE NO ACTION` and `ON UPDATE NO ACTION`, except `FK_ItemPhoto_Item`, which uses `ON DELETE CASCADE` so an item's photos are removed with it. `WITH CHECK` validates existing rows when each relationship is added. The Employee/Warehouse manager relationship is circular, so both tables and their FK columns are created first, then both FKs are added here.
- **3.2 - AppLanguage:** I add it as `VARCHAR(2) NOT NULL` with a default of `ar`. `WITH VALUES` fills `ar` into rows that already exist. I add a check allowing only `ar` or `en`.
- **3.3 - Featured:** I add `Featured` as `BIT NOT NULL` with default `0`, so old and new rows start as not featured.
- **3.4 - Rename:** I use `sys.sp_rename` for `IPAddress` to `DeviceIp` and `Capacity` to `MaxItems`, because a column rename is not done with `ALTER COLUMN`.
- **3.5 - FullName:** I change it to `NVARCHAR(150) NOT NULL`, keeping the required `NOT NULL` property.
- **3.6 - MaxItems:** I change the column from `INT` to `SMALLINT`. The first attempt reports the expected dependency error because `CK_Warehouse_Capacity` is attached to the column. I catch and print that error, drop the old check, bring any old value above 30,000 down to the new limit, alter the type, and add `CK_Warehouse_MaxItems` again. The new check keeps the value between 1 and 30,000. `SMALLINT` is the smallest integer type that can hold 30,000.
- **3.7 - Commission:** I drop the old 0-to-30 check. If old rows have values above 25, I change those values to 25, then add the new 0-to-25 check.
- **3.8 - Auction status:** I replace the status check to include `PendingReview`, remove the old default, and set `PendingReview` as the new default. Existing statuses stay as they are.
- **3.9 - BuyNowPrice:** I add it as nullable, then add a named check requiring it to be greater than `StartingPrice` when supplied. I use `WITH CHECK` because I want SQL Server to validate existing rows too. Existing rows get `NULL`, which is allowed; `WITH NOCHECK` would skip validation and leave an untrusted constraint.
- **3.10 - Mobile:** I add the named unique constraint `UQ_Member_Mobile`. If duplicate mobile numbers are already in a live database, they must be reviewed and fixed before this constraint can be added.
- **3.11 - VerifiedAt:** I add the nullable `VerifiedAt` column, drop `DF_Member_IsVerified`, then drop `IsVerified`. SQL Server does not allow dropping the column while its default constraint is still attached. The exact old verification time cannot be recovered from a Yes/No value, so a live system would need an audit record for that date.
- **3.12 - FollowedAuction:** I create `Marketing` and move the existing table with `ALTER SCHEMA ... TRANSFER`; the table is not dropped or recreated.

## 7. LeetCode 238 trace

For the input `[1, 2, 3, 4]`, the prefix value is the product of the values before the current index, and the suffix value is the product after it.

| Index | Input | Prefix | Suffix | Result |
|---:|---:|---:|---:|---:|
| 0 | 1 | 1 | 24 | 24 |
| 1 | 2 | 1 | 12 | 12 |
| 2 | 3 | 2 | 4 | 8 |
| 3 | 4 | 6 | 1 | 6 |

- `prefix[] = [1, 1, 2, 6]`
- `suffix[] = [24, 12, 4, 1]`
- Output: `[24, 12, 8, 6]`

The first method stores the prefix and suffix values in two arrays, so it takes `O(n)` time and `O(n)` extra space. The second method stores the prefix products in the output array and uses one variable for the suffix product. It takes `O(n)` time and `O(1)` extra space, not counting the output array. Neither method uses division.
