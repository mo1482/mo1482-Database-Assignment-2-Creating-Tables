# Task 1 — Relational Mapping

## Initial schemas

The initial design uses exactly four schemas. The `Marketing` schema is not part of Task 1; Task 3.12 creates it later and transfers `FollowedAuction` into it.

| Schema | Tables | Why they belong together |
|---|---|---|
| `Geo` | `Country`, `City` | Reference data for countries and the cities used by members and warehouses. |
| `Accounts` | `Member`, `Wallet` | Member profile, referrals, and the one-to-one wallet. |
| `Operations` | `Warehouse`, `Employee` | Warehouse locations, staff assignments, and warehouse management. |
| `Commerce` | `Category`, `Item`, `ItemPhoto`, `Auction`, `Bid`, `FollowedAuction` | Catalogue, listed goods, auction lifecycle, bidding, and followed auctions. |

## Relational schema (PKs are underlined in the diagram)

- `Geo.Country` (**PK** `CountryCode`, `NameEn`, `NameAr`, `PhoneCode`)
- `Geo.City` (**PK** `CityId`, `Name`, `CountryCode`); **UQ** (`CountryCode`, `Name`)
- `Accounts.Member` (**PK** `MemberId`, `FullName`, `Email`, `Mobile`, `NationalId`, `BirthDate`, `IsVerified`, `RegisteredAt`, `CityId`, `InvitedByMemberId`); **UQ** (`Email`), **UQ** (`NationalId`)
- `Accounts.Wallet` (**PK/FK** `MemberId`, `Balance`, `HeldAmount`, `CurrencyCode`, `UpdatedAt`)
- `Operations.Warehouse` (**PK** `WarehouseId`, `WarehouseName`, `Capacity`, `CityId`, `Latitude`, `Longitude`, `ManagerMemberId`, `ManagerSince`); **UQ** (`WarehouseName`), **UQ** (`ManagerMemberId`, filtered while the circular relationship is being populated)
- `Operations.Employee` (**PK/FK** `MemberId`, `WarehouseId`)
- `Commerce.Category` (**PK** `CategoryId`, `NameEn`, `NameAr`, `CommissionPercent`, `ParentCategoryId`); **UQ** (`NameEn`)
- `Commerce.Item` (**PK** `ItemId`, `Title`, `Description`, `ConditionScore`, `Specifications`, `SellerMemberId`, `InspectorMemberId`, `CategoryId`, `WarehouseId`, `ListedAt`)
- `Commerce.ItemPhoto` (**composite PK/FK** `ItemId`, **composite PK** `PhotoPosition`, `PhotoUrl`, `IsMain`)
- `Commerce.Auction` (**PK** `AuctionId`, `ItemId`, `StartingPrice`, `ReservePrice`, `BidIncrement`, `StartAt`, `EndAt`, `Status`)
- `Commerce.Bid` (**PK** `BidId`, `AuctionId`, `MemberId`, `Amount`, `PlacedAt`, `IPAddress`); **UQ** (`AuctionId`, `Amount`)
- `Commerce.FollowedAuction` (**composite PK/FK** `MemberId`, **composite PK/FK** `AuctionId`, `FollowedAt`)

`Country` includes the four attributes shown in the assignment's sample relational notation. Its text lengths and the phone-code length are implementation choices because the business description does not specify those lengths. `Capacity` and `IPAddress` are their original Task 1 names; Task 3.4 later renames them to `MaxItems` and `DeviceIp`.

## Foreign-key relationships

All arrows in `mapping.png` start at the child table's FK and point to the referenced parent PK:

1. `City.CountryCode` → `Country.CountryCode`
2. `Member.CityId` → `City.CityId`
3. `Member.InvitedByMemberId` → `Member.MemberId` (recursive)
4. `Wallet.MemberId` → `Member.MemberId`
5. `Warehouse.CityId` → `City.CityId`
6. `Employee.MemberId` → `Member.MemberId`
7. `Employee.WarehouseId` → `Warehouse.WarehouseId`
8. `Warehouse.ManagerMemberId` → `Employee.MemberId`
9. `Category.ParentCategoryId` → `Category.CategoryId` (recursive)
10. `Item.SellerMemberId` → `Member.MemberId`
11. `Item.InspectorMemberId` → `Employee.MemberId`
12. `Item.CategoryId` → `Category.CategoryId`
13. `Item.WarehouseId` → `Warehouse.WarehouseId` (nullable before the item arrives)
14. `ItemPhoto.ItemId` → `Item.ItemId` (`ON DELETE CASCADE`)
15. `Auction.ItemId` → `Item.ItemId`
16. `Bid.AuctionId` → `Auction.AuctionId`
17. `Bid.MemberId` → `Member.MemberId`
18. `FollowedAuction.MemberId` → `Member.MemberId`
19. `FollowedAuction.AuctionId` → `Auction.AuctionId`

## Relationship types required by the assignment

- **1:1 — Member and Wallet:** `Wallet.MemberId` is both its PK and FK. This prevents a member from owning two wallets and prevents a wallet from being shared.
- **1:0..1 — Member and Employee:** `Employee.MemberId` is both its PK and FK. An employee must be a member, while a member does not have to be an employee.
- **1:N — Country and City:** each city belongs to one country. The composite unique key on (`CountryCode`, `Name`) prevents a city name from repeating within the same country.
- **1:N — City and Member / Warehouse:** both child tables store `CityId`.
- **1:N — Member invitations (recursive):** a member can invite many members; each invited member has at most one inviter.
- **1:N — Warehouse and Employee:** each employee is assigned to one warehouse; a warehouse can have many employees.
- **1:1 — Warehouse manager and Employee (circular with the work assignment):** `Warehouse.ManagerMemberId` references `Employee.MemberId` and is unique, so an employee manages no more than one warehouse. The other direction is `Employee.WarehouseId` → `Warehouse.WarehouseId`.
- **1:N — Category tree (recursive):** `ParentCategoryId` points to another row in `Category`; top-level categories use `NULL`.
- **1:N — Member as seller and Item:** each item has one seller; a member may list many items.
- **1:N — Employee as inspector and Item:** each inspected item records one employee; an employee may inspect many items. `SellerMemberId <> InspectorMemberId` enforces that the seller cannot inspect their own item.
- **1:N — Category and Item; Warehouse and Item:** each item has one category and may have no warehouse yet; a category or warehouse can be related to many items.
- **Weak entity — ItemPhoto:** its identity depends on (`ItemId`, `PhotoPosition`); `ItemId` is part of the composite PK and an FK. Deleting the item deletes its photos.
- **1:N — Item and Auction:** one item may have several auctions over time; each auction belongs to one item.
- **M:N — Member and Auction through Bid:** each bid is one transaction with its own amount, timestamp, and device IP. The unique key (`AuctionId`, `Amount`) prevents equal bid amounts within one auction while allowing repeated bids by the same member.
- **M:N — Member and Auction through FollowedAuction:** the bridge table's composite PK (`MemberId`, `AuctionId`) prevents a member from following the same auction twice.

## Circular relationship and nullable manager fields

`Warehouse` refers to `Employee` through `ManagerMemberId`, while `Employee` refers to `Warehouse` through `WarehouseId`. Both tables therefore need to exist before the two FK constraints can be added. For the data-import workflow, the manager columns start nullable so warehouse rows can be imported first, then employee rows. After managers are assigned, `support/AfterImport.sql` changes those two columns to `NOT NULL` and restores the unique index and constraints. The final business rule is that every warehouse has one manager.

## Changes that belong to Task 3, not the initial Task 1 mapping

- Add `Member.AppLanguage`.
- Add `Item.Featured`.
- Rename `Warehouse.Capacity` to `MaxItems` and `Bid.IPAddress` to `DeviceIp`.
- Widen `Member.FullName` from 100 to 150 characters.
- Change `MaxItems` to `SMALLINT` and cap it at 30,000.
- Reduce the category commission maximum from 30% to 25%.
- Add `PendingReview` to auction statuses and make it the new default.
- Add nullable `Auction.BuyNowPrice`.
- Make `Member.Mobile` unique.
- Add nullable `VerifiedAt` and remove `IsVerified` (after dropping its default constraint).
- Create `Marketing` and transfer `FollowedAuction` from `Commerce`.
