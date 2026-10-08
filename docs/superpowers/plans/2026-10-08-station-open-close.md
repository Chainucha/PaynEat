# Station Open/Close Implementation Plan (ticket 36)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let kitchen staff and managers close a kitchen station at their branch so its dishes can't be ordered (greyed with a label for staff, hidden from QR customers) until it is reopened.

**Architecture:** A new `station_closures` table holds one row per (branch, station) that is closed. "Orderable" is derived at read time (dish available AND its resolved station open) — `menu_items.is_available` is never touched. The order write path (`buildItemRow`, plus `sendToKitchen` for unsent open orders) refuses closed-station dishes with 409. A `station:status` socket event makes staff screens refresh; a shared `StationStatusController` + sheet + banner serve the kitchen screen and the staff order screen. Demo mode mirrors every rule.

**Tech Stack:** Node 20 + Express + better-sqlite3 + zod + node:test/supertest (backend); Flutter 3.41 + GetX + flutter_test (app).

**Spec:** `docs/tickets/36-station-open-close.md` · glossary `CONTEXT.md`

## Global Constraints

- Every new source file starts with `Copyright 2026 Suruch Chakrapeesirisuk` + `SPDX-License-Identifier: Apache-2.0` (run `node scripts/license-headers.mjs --fix` at repo root).
- Migrations already on `main` (0001–0007) must not be edited, not even whitespace. New migration is `0008`; its checksum goes in `backend/src/db/migrations/checksums.json`.
- Every new backend error message (Thai source text) needs an `en` + `ko` entry in `backend/src/i18n/errorMessages.js` — `tests/error-i18n.test.js` fails otherwise.
- Every `auditLogService.log({...})` call must pass `summaryArgs` (`tests/audit-summary-args.test.js`), and the app must be able to render the action in th/en/ko (`AuditLogAction` + `audit_log_translations.dart`).
- Every new app string needs th/en/ko keys in the feature's translations file.
- Code comments are Thai, matching the surrounding code. Commit messages / PR text in English.
- Kitchen screen and order screen must not overflow at 360px width (DECISIONS #62).
- Demo mode mirrors every rule (DECISIONS #8).
- Closed ≠ inactive: never reuse or modify `kitchen_stations.is_active` for this feature.
- Pre-commit gate (CONTRIBUTING / CODING_STANDARDS §7): `cd backend && npm run format:check && npm run lint && npm test`; `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test`; `node scripts/license-headers.mjs`; `bash tool/check-architecture.sh`.
- Demo store files are `part of 'demo_store.dart'` — any new import they need (e.g. `app_clock.dart`, `UserRole` from `app_constants.dart`) goes in `demo_store.dart` itself.
- Branch: `feat/station-close-and-chime` (already created from `origin/main`). Commit after each task.

## Review Focus

1. **Open (unsent) order sent to the kitchen after its station closed** — a waiter saves a bill without sending, the bar closes, then they press "send to kitchen". Expected: 409 naming the dish and station, nothing sent. (Added to the ticket's scope here; tested in Task 3.)
2. **Inactive station that still has a closure row** — a closed station is later deactivated in setup. Expected: its leftover closure has no effect (dishes routed to it stay orderable, it's not in the status list). Tested in Task 2 and Task 4.
3. **Admin in "all branches" mode** — menu list still marks each dish by *its own* branch's closures; status/close/open endpoints answer 400. Tested in Task 2 and Task 4.
4. **Close twice / open twice / open a never-closed station** — idempotent 200, exactly one audit row per real change, no socket event when nothing changed. Tested in Task 2.
5. **QR basket submitted after the station closed while the customer browsed** — 409 with the dish name, nothing added to the order. Tested in Task 3.

---

## File Structure

Backend
- Create `backend/src/db/migrations/0008_station_closures.sql` / `.js` — the table.
- Modify `backend/src/db/migrations/index.js`, `checksums.json` — register.
- Modify `backend/src/modules/kitchen-stations/kitchen-station.repository.js` — closure queries.
- Modify `backend/src/modules/kitchen-stations/kitchen-station.service.js` — status, close/open, `isClosed`, `closedStationLookup`.
- Modify `backend/src/modules/kitchen-stations/kitchen-station.mapper.js` — `toStationStatusDto`.
- Modify `backend/src/modules/kitchen-stations/kitchen-station.controller.js`, `kitchen-station.routes.js`.
- Modify `backend/src/realtime/socket.js` — `STATION_STATUS` event.
- Modify `backend/src/modules/orders/order.service.js` — guard in `buildItemRow` and `sendToKitchen`.
- Modify `backend/src/modules/menu/menu.service.js` — `closedStation` on list DTOs.
- Modify `backend/src/modules/public-order/public-order.service.js` — hide closed dishes.
- Modify `backend/src/i18n/errorMessages.js`, `backend/docs/openapi.yaml`.
- Create `backend/tests/station-closures.test.js`; modify `backend/tests/migrations.test.js`.

App
- Create `app/lib/features/menu/domain/entities/station_status.dart`, `app/lib/features/menu/data/models/station_status_model.dart`.
- Create `app/lib/features/menu/domain/entities/closed_station.dart` — the small station reference carried on a menu item.
- Modify menu data layer: `menu_remote_data_source.dart`, `menu_repository.dart`, `menu_repository_impl.dart`, `menu_usecases.dart`, `menu_item.dart`, `menu_item_model.dart`, `api_endpoints.dart`, `use_case_bindings.dart`.
- Modify `app/lib/core/network/socket_client.dart` — `SocketEvents.stationStatus` + `dispatchLocal` for tests.
- Create `app/lib/features/kitchen/presentation/controllers/station_status_controller.dart`.
- Create `app/lib/features/kitchen/presentation/widgets/station_status_sheet.dart`, `station_closed_banner.dart`.
- Modify `kitchen_page.dart`, `home_binding.dart`, `order_taking_page.dart`, `order_bindings.dart`, `menu_controller.dart`, `menu_item_card.dart`.
- Modify demo: `demo_store.dart`, `demo_store_menu.dart`, `demo_store_order_items.dart`, `demo_store_orders.dart`, `demo_menu_data_source.dart`, `demo_self_order_data_source.dart`.
- Modify `audit_log_action.dart`, `audit_summary_text.dart` (only if a switch case is needed — not here), translations `kitchen_translations.dart`, `menu_translations.dart`, `audit_log_translations.dart`, `order_translations.dart`.
- Tests: `app/test/presentation/station_status_controller_test.dart`, `app/test/widget/station_status_sheet_test.dart`, additions to `app/test/core/demo_store_test.dart`, `app/test/presentation/menu_browse_controller_test.dart`, `app/test/domain/entities_test.dart`.

Docs: `README.md`, `README.en.md`, `README.ko.md`, `docs/DECISIONS.md` (#102), `docs/FEATURE-GAP-ANALYSIS.md`, `docs/tickets/36-station-open-close.md`, `docs/tickets/README.md`, `CONTEXT.md`.

---

### Task 1: Migration 0008 `station_closures`

**Files:**
- Create: `backend/src/db/migrations/0008_station_closures.sql`, `backend/src/db/migrations/0008_station_closures.js`
- Modify: `backend/src/db/migrations/index.js`, `backend/src/db/migrations/checksums.json`
- Test: `backend/tests/migrations.test.js`

**Interfaces:**
- Produces: table `station_closures(branch_id, station_id, closed_at, closed_by, closed_by_name)`, PK `(branch_id, station_id)`, both FKs `ON DELETE CASCADE`, `closed_by` → `users(id) ON DELETE SET NULL`.

- [ ] **Step 1: Write the failing test** — append to `backend/tests/migrations.test.js`:

```js
describe('0008 station_closures (ticket 36)', () => {
  test('starts with every station open, one row per branch and station, gone with its station', () => {
    const db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db, MIGRATIONS.slice(0, 7));

    assert.deepEqual(runMigrations(db, MIGRATIONS.slice(0, 8)), ['0008_station_closures']);
    assert.ok(tableExists(db, 'station_closures'));
    assert.equal(db.prepare('SELECT COUNT(*) AS c FROM station_closures').get().c, 0);

    const branch = db
      .prepare("INSERT INTO branches (name, code) VALUES ('สาขาทดสอบ', 'T36')")
      .run().lastInsertRowid;
    const station = db
      .prepare("INSERT INTO kitchen_stations (code, name) VALUES ('grill', 'เตาย่าง')")
      .run().lastInsertRowid;
    const close = db.prepare(
      "INSERT INTO station_closures (branch_id, station_id, closed_by_name) VALUES (?, ?, 'เชฟต้น')",
    );
    close.run(branch, station);
    assert.throws(() => close.run(branch, station), /UNIQUE constraint failed/);

    db.prepare('DELETE FROM kitchen_stations WHERE id = ?').run(station);
    assert.equal(db.prepare('SELECT COUNT(*) AS c FROM station_closures').get().c, 0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && node --test tests/migrations.test.js`
Expected: FAIL — `runMigrations(..., MIGRATIONS.slice(0, 8))` returns `[]` (only 7 migrations exist).

- [ ] **Step 3: Write the migration**

`backend/src/db/migrations/0008_station_closures.sql`:

```sql
-- Copyright 2026 Suruch Chakrapeesirisuk
-- SPDX-License-Identifier: Apache-2.0

-- Migration 0008 — ปิด/เปิดสถานีครัวรายสาขา (ticket 36, docs/DECISIONS.md #102)
-- มีแถว = สถานีนี้ปิดอยู่ที่สาขานี้, เปิดคืน = ลบแถว, ไม่มีแถว = เปิด (สาขาใหม่/สถานีใหม่เปิดเสมอ)
--
-- เป็น "สถานะตอนนี้" ไม่ใช่ประวัติ (ประวัติอยู่ใน audit_logs) จึง CASCADE ตามสาขาและสถานีได้
-- คนละเรื่องกับ kitchen_stations.is_active ซึ่งเป็นค่าตั้งระดับเครือร้าน (ดู CONTEXT.md)
-- ประทับชื่อคนปิดไว้ด้วย แบนเนอร์ "บาร์ปิดตั้งแต่ ... โดย ..." จึงไม่หายถ้าบัญชีนั้นถูกลบภายหลัง
CREATE TABLE IF NOT EXISTS station_closures (
  branch_id      INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  station_id     INTEGER NOT NULL REFERENCES kitchen_stations(id) ON DELETE CASCADE,
  closed_at      TEXT    NOT NULL DEFAULT (datetime('now')),
  closed_by      INTEGER REFERENCES users(id) ON DELETE SET NULL,
  closed_by_name TEXT,
  PRIMARY KEY (branch_id, station_id)
);

CREATE INDEX IF NOT EXISTS idx_station_closures_station ON station_closures(station_id);
```

`backend/src/db/migrations/0008_station_closures.js`:

```js
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/** Migration 0008 — ปิด/เปิดสถานีครัวรายสาขา (ticket 36, docs/DECISIONS.md #102) ทั้งหมดอยู่ใน .sql */

const sql = path.join(path.dirname(fileURLToPath(import.meta.url)), '0008_station_closures.sql');

export default {
  version: 8,
  name: 'station_closures',
  files: [fileURLToPath(import.meta.url), sql],
  up(db) {
    db.exec(fs.readFileSync(sql, 'utf8'));
  },
};
```

In `backend/src/db/migrations/index.js` add the import after `userStations` and append to `DEFINITIONS`:

```js
import stationClosures from './0008_station_closures.js';
// ...
  userStations,
  stationClosures,
];
```

- [ ] **Step 4: Record the checksum**

Run: `cd backend && node --test tests/migrations.test.js`
Expected: the new 0008 test passes; `match checksums.json` FAILS and prints the checksum for `0008_station_closures`. Add it to `checksums.json`:

```json
  "0007_user_stations": "ff0aad843c54b032a8451e5aa29433c1eed47a8c6987c95f7152048d008fad73",
  "0008_station_closures": "<checksum printed by the test>"
```

Re-run: `cd backend && node --test tests/migrations.test.js` → all PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/db/migrations backend/tests/migrations.test.js
git commit -m "feat(db): add station_closures table for per-branch station close"
```

---

### Task 2: Station status API — list, close, open, audit, socket event

**Files:**
- Modify: `backend/src/modules/kitchen-stations/kitchen-station.repository.js`, `kitchen-station.service.js`, `kitchen-station.mapper.js`, `kitchen-station.controller.js`, `kitchen-station.routes.js`
- Modify: `backend/src/realtime/socket.js`, `backend/src/i18n/errorMessages.js`, `backend/docs/openapi.yaml`
- Test: `backend/tests/station-closures.test.js` (new)

**Interfaces:**
- Consumes: table from Task 1.
- Produces (repository): `findClosures(): Row[]` (active stations only), `findClosure(branchId, stationId): Row|undefined` (active only), `findStatuses(branchId): Row[]`, `findStatus(branchId, stationId): Row|undefined`, `close(branchId, stationId, user): boolean`, `open(branchId, stationId): boolean`, `findAllBasic(): Row[]`.
- Produces (service): `closureKey(branchId, stationId): string` (exported function), `kitchenStationService.isClosed(branchId, stationId): boolean`, `.closedStationLookup(): (menuRow) => ClosedStationDto|null`, `.listStatus(branchId): StationStatusDto[]`, `.setClosed(id, closed, { branchId, user }): StationStatusDto`.
- Produces (DTO) `StationStatusDto = { stationId, code, name, nameEn, nameKo, icon, isClosed, closedAt, closedByName, pendingCount }`; `ClosedStationDto = { id, name, nameEn, nameKo }`.
- Produces (HTTP): `GET /api/v1/kitchen-stations/status` (every logged-in role — the waiter's banner needs it), `POST /api/v1/kitchen-stations/:id/close`, `POST /api/v1/kitchen-stations/:id/open` (admin/manager/kitchen only).
- Produces (socket): `EVENTS.STATION_STATUS = 'station:status'`, payload `{ branchId, ...StationStatusDto }`, rooms kitchen+service+management.
- Produces (audit): actions `kitchen_station.close`, `kitchen_station.open`, `summaryArgs: { station, pending }`.

- [ ] **Step 1: Write the failing tests** — create `backend/tests/station-closures.test.js`:

```js
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { api, login, authHeader, cleanup } from './helpers/testApp.js';

// ปิด/เปิดสถานีครัวรายสาขา (ticket 36) — สถานีปิด ≠ สถานีที่ปิดใช้งาน (CONTEXT.md)
// ทุกเทสต์สร้างสถานี/หมวด/เมนูของตัวเอง ไม่แตะสามสถานีตั้งต้น ปิดแล้วจึงไม่รั่วไปเทสต์อื่น

after(cleanup);

const get = (url, token) => api().get(url).set(authHeader(token));
const post = (url, token, body) =>
  api()
    .post(url)
    .set(authHeader(token))
    .send(body ?? {});
const patch = (url, token, body) => api().patch(url).set(authHeader(token)).send(body);

const unique = (prefix) =>
  `${prefix}${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`.slice(0, 20);

/** สถานีใหม่ + หมวดหมู่ที่ผูกสถานีนั้น + เมนูหนึ่งจานในสาขาของ token */
const stationWithDish = async (token) => {
  const station = await post('/api/v1/kitchen-stations', token, {
    code: unique('st'),
    name: unique('สถานี-'),
  });
  assert.equal(station.status, 201, JSON.stringify(station.body));
  const category = await post('/api/v1/categories', token, {
    name: unique('หมวด-'),
    stationId: station.body.data.id,
  });
  assert.equal(category.status, 201, JSON.stringify(category.body));
  const dish = await post('/api/v1/menu-items', token, {
    categoryId: category.body.data.id,
    name: unique('จาน-'),
    price: 60,
    branchId: 1,
  });
  assert.equal(dish.status, 201, JSON.stringify(dish.body));
  return { station: station.body.data, category: category.body.data, dish: dish.body.data };
};

const statusOf = async (token, stationId) => {
  const res = await get('/api/v1/kitchen-stations/status', token);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body.data.find((row) => row.stationId === stationId);
};

const auditFor = async (adminToken, action) =>
  (await get(`/api/v1/audit-logs?action=${action}&limit=200`, adminToken)).body.data;

test('ทุกสถานีเปิดอยู่ตั้งแต่แรก และสถานะคืนเฉพาะสถานีที่เปิดใช้งาน', async () => {
  const { token } = await login('admin', 'admin123');
  const { station } = await stationWithDish(token);

  const status = await statusOf(token, station.id);
  assert.equal(status.isClosed, false);
  assert.equal(status.closedAt, null);
  assert.equal(status.pendingCount, 0);
  assert.equal(status.code, station.code);

  await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isActive: false });
  assert.equal(await statusOf(token, station.id), undefined);
});

test('kitchen/manager/admin ปิดและเปิดได้ — waiter/cashier 403, ไม่ล็อกอิน 401', async () => {
  const admin = await login('admin', 'admin123');
  const { station } = await stationWithDish(admin.token);

  for (const username of ['waiter1', 'cashier']) {
    const password = username === 'cashier' ? 'cashier123' : 'waiter123';
    const { token } = await login(username, password);
    const res = await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
    assert.equal(res.status, 403, `${username} ต้องปิดสถานีไม่ได้`);
  }
  const anonymous = await api().post(`/api/v1/kitchen-stations/${station.id}/close`);
  assert.equal(anonymous.status, 401);

  // อ่านสถานะได้ทุกบทบาท — แบนเนอร์บนหน้าสั่งอาหารของพนักงานเสิร์ฟต้องใช้
  const waiter = await login('waiter1', 'waiter123');
  assert.equal((await get('/api/v1/kitchen-stations/status', waiter.token)).status, 200);

  const kitchen = await login('kitchen', 'kitchen123');
  const closed = await post(`/api/v1/kitchen-stations/${station.id}/close`, kitchen.token);
  assert.equal(closed.status, 200, JSON.stringify(closed.body));
  assert.equal(closed.body.data.isClosed, true);
  assert.equal(closed.body.data.closedByName, kitchen.user.name);
  assert.ok(closed.body.data.closedAt);

  const manager = await login('manager', 'manager123');
  const opened = await post(`/api/v1/kitchen-stations/${station.id}/open`, manager.token);
  assert.equal(opened.status, 200);
  assert.equal(opened.body.data.isClosed, false);
  assert.equal(opened.body.data.closedByName, null);
});

test('ปิดซ้ำ/เปิดซ้ำได้ 200 และ audit log บันทึกเฉพาะตอนสถานะเปลี่ยนจริง', async () => {
  const { token } = await login('admin', 'admin123');
  const { station } = await stationWithDish(token);
  const countFor = async (action) =>
    (await auditFor(token, action)).filter((log) => log.entityId === station.id).length;

  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/open`, token)).status, 200);
  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/close`, token)).status, 200);
  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/close`, token)).status, 200);
  assert.equal((await post(`/api/v1/kitchen-stations/${station.id}/open`, token)).status, 200);

  assert.equal(await countFor('kitchen_station.close'), 1);
  assert.equal(await countFor('kitchen_station.open'), 1);
  const [log] = (await auditFor(token, 'kitchen_station.close')).filter(
    (row) => row.entityId === station.id,
  );
  assert.deepEqual(log.metadata.summaryArgs, { station: station.name, pending: 0 });
});

test('ปิดที่สาขาหนึ่ง สาขาอื่นยังเปิดอยู่', async () => {
  const admin = await login('admin', 'admin123');
  const { station } = await stationWithDish(admin.token);
  await post(`/api/v1/kitchen-stations/${station.id}/close`, admin.token);

  const branches = (await get('/api/v1/branches', admin.token)).body.data;
  const thonglor = branches.find((branch) => branch.code === 'THONGLOR');
  const switched = await post('/api/v1/auth/select-branch', admin.token, {
    branchId: thonglor.id,
  });
  assert.equal(switched.status, 200, JSON.stringify(switched.body));

  const elsewhere = await statusOf(switched.body.data.token, station.id);
  assert.equal(elsewhere.isClosed, false);
});

test('โหมด "ทุกสาขา" ดูหรือเปลี่ยนสถานะไม่ได้ (400) และสถานีไม่มีจริงได้ 404', async () => {
  const admin = await login('admin', 'admin123');
  const all = await post('/api/v1/auth/select-branch', admin.token, { branchId: null });
  const allToken = all.body.data.token;

  assert.equal((await get('/api/v1/kitchen-stations/status', allToken)).status, 400);
  assert.equal((await post('/api/v1/kitchen-stations/1/close', allToken)).status, 400);
  assert.equal((await post('/api/v1/kitchen-stations/999999/close', admin.token)).status, 404);
});

test('ลบสถานีที่ปิดอยู่ได้ แถวปิดหายตาม', async () => {
  const { token } = await login('admin', 'admin123');
  const station = (
    await post('/api/v1/kitchen-stations', token, { code: unique('st'), name: 'ลบได้' })
  ).body.data;
  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const removed = await api()
    .delete(`/api/v1/kitchen-stations/${station.id}`)
    .set(authHeader(token));
  assert.equal(removed.status, 204, JSON.stringify(removed.body));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && node --test tests/station-closures.test.js`
Expected: FAIL — `GET /kitchen-stations/status` answers 422 (matched by `/:id` with `id=status`) and `/close` is 404.

- [ ] **Step 3: Repository** — add to `kitchenStationRepository` in `kitchen-station.repository.js` (before `remove`):

```js
  /** แถวสถานีล้วน ๆ ไม่นับเมนู — ใช้ทำตารางค้นชื่อสถานีตอนประกอบรายการเมนู */
  findAllBasic() {
    return getDb().prepare('SELECT * FROM kitchen_stations').all();
  },

  /**
   * สถานะปิดทั้งหมดของสถานีที่เปิดใช้งาน (ticket 36) — สถานีที่ถูกปิดใช้งานภายหลังแต่ยังมีแถวปิดค้าง
   * ไม่ถูกนับ เพราะ "ปิดใช้งาน" เป็นค่าตั้งของเครือร้านที่ทับทุกอย่างอยู่แล้ว (CONTEXT.md)
   */
  findClosures() {
    return getDb()
      .prepare(
        `SELECT sc.* FROM station_closures sc
           JOIN kitchen_stations s ON s.id = sc.station_id
          WHERE s.is_active = 1`,
      )
      .all();
  },

  findClosure(branchId, stationId) {
    return getDb()
      .prepare(
        `SELECT sc.* FROM station_closures sc
           JOIN kitchen_stations s ON s.id = sc.station_id
          WHERE s.is_active = 1 AND sc.branch_id = ? AND sc.station_id = ?`,
      )
      .get(branchId, stationId);
  },

  /**
   * สถานะของทุกสถานีที่เปิดใช้งานในสาขาหนึ่ง พร้อมจำนวนรายการที่ยังค้างในครัว (pending/cooking)
   * นับแบบเดียวกับคิวครัว: เฉพาะออเดอร์ที่ส่งครัวแล้ว และตั๋วที่ไม่มีสถานีถือเป็นของสถานีค่าเริ่มต้น
   */
  findStatuses(branchId, stationId = null) {
    return getDb()
      .prepare(
        `
        SELECT s.*, sc.closed_at, sc.closed_by_name, (
          SELECT COUNT(*)
            FROM order_items oi
            JOIN orders o ON o.id = oi.order_id
           WHERE oi.status IN ('pending', 'cooking')
             AND o.status IN ('in_kitchen', 'served')
             AND o.branch_id = @branchId
             AND COALESCE(oi.station_id, (SELECT id FROM kitchen_stations WHERE is_default = 1)) = s.id
        ) AS pending_count
          FROM kitchen_stations s
          LEFT JOIN station_closures sc ON sc.station_id = s.id AND sc.branch_id = @branchId
         WHERE s.is_active = 1 AND (@stationId IS NULL OR s.id = @stationId)
         ORDER BY s.sort_order, s.id
      `,
      )
      .all({ branchId, stationId });
  },

  findStatus(branchId, stationId) {
    return this.findStatuses(branchId, stationId)[0];
  },

  /** คืน true เมื่อสถานะเปลี่ยนจริง (ปิดซ้ำ = false) — service ใช้ตัดสินว่าต้องลง audit/ส่ง event ไหม */
  close(branchId, stationId, user) {
    return (
      getDb()
        .prepare(
          `INSERT OR IGNORE INTO station_closures (branch_id, station_id, closed_by, closed_by_name)
           VALUES (?, ?, ?, ?)`,
        )
        .run(branchId, stationId, user?.id ?? null, user?.name ?? null).changes > 0
    );
  },

  open(branchId, stationId) {
    return (
      getDb()
        .prepare('DELETE FROM station_closures WHERE branch_id = ? AND station_id = ?')
        .run(branchId, stationId).changes > 0
    );
  },
```

- [ ] **Step 4: Mapper** — add to `kitchen-station.mapper.js`:

```js
/** สถานะเปิด/ปิดของสถานีในสาขาหนึ่ง (ticket 36) */
export const toStationStatusDto = (row) => ({
  stationId: row.id,
  code: row.code,
  name: row.name,
  nameEn: row.name_en,
  nameKo: row.name_ko,
  icon: row.icon,
  isClosed: row.closed_at != null,
  closedAt: row.closed_at ?? null,
  closedByName: row.closed_by_name ?? null,
  pendingCount: row.pending_count ?? 0,
});
```

- [ ] **Step 5: Socket event** — in `backend/src/realtime/socket.js` add to `EVENTS`:

```js
  SCALE_READING: 'scale:reading',
  STATION_STATUS: 'station:status',
```

- [ ] **Step 6: Service** — in `kitchen-station.service.js` add imports and functions:

```js
import { emit, EVENTS, ROOMS } from '../../realtime/socket.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { toKitchenStationDto, toStationStatusDto } from './kitchen-station.mapper.js';

/** คีย์ของคู่ (สาขา, สถานี) ในชุดสถานีที่ปิดอยู่ */
export const closureKey = (branchId, stationId) => `${branchId}:${stationId}`;

const requireBranch = (branchId) => {
  if (!branchId) throw ApiError.badRequest('เลือกสาขาก่อนดูหรือเปลี่ยนสถานะสถานีครัว');
};
```

and these methods inside `kitchenStationService` (after `resolveForMenuItem`):

```js
  /** สถานีนี้ปิดอยู่ที่สาขานี้หรือไม่ (ticket 36) — ไม่มีสาขา (ข้อมูลเก่า) ถือว่าเปิด */
  isClosed(branchId, stationId) {
    if (!branchId || !stationId) return false;
    return Boolean(kitchenStationRepository.findClosure(branchId, stationId));
  },

  /**
   * ฟังก์ชันตัดสิน "สถานีที่ปิดอยู่ของจานนี้" สำหรับรายการเมนูทั้งก้อน — อ่านตารางปิดครั้งเดียว
   * แล้วตัดสินทีละแถวด้วยกฎเมนู → หมวดหมู่ → ค่าเริ่มต้น เทียบกับสาขาของจานเอง (admin โหมดทุกสาขา
   * จึงเห็นสถานะของแต่ละสาขาถูกต้อง) คืน null เมื่อสถานีเปิดอยู่
   */
  closedStationLookup() {
    const closed = new Set(
      kitchenStationRepository
        .findClosures()
        .map((row) => closureKey(row.branch_id, row.station_id)),
    );
    if (closed.size === 0) return () => null;
    const defaultId = this.defaultStation().id;
    const stations = new Map(kitchenStationRepository.findAllBasic().map((row) => [row.id, row]));
    return (menuRow) => {
      const stationId = menuRow.station_id ?? menuRow.category_station_id ?? defaultId;
      if (!closed.has(closureKey(menuRow.branch_id, stationId))) return null;
      const station = stations.get(stationId);
      return {
        id: station.id,
        name: station.name,
        nameEn: station.name_en,
        nameKo: station.name_ko,
      };
    };
  },

  listStatus(branchId) {
    requireBranch(branchId);
    return kitchenStationRepository.findStatuses(branchId).map(toStationStatusDto);
  },

  /**
   * ปิด/เปิดสถานีที่สาขาปัจจุบัน — idempotent: สถานะเดิมอยู่แล้วตอบ 200 โดยไม่ลง audit และไม่ส่ง event
   * รายการที่อยู่ในคิวแล้วไม่ถูกแตะ ครัวทำต่อจนเสร็จ (ticket 36)
   */
  setClosed(id, closed, { branchId, user }) {
    requireBranch(branchId);
    const before = kitchenStationRepository.findStatus(branchId, id);
    if (!before) throw ApiError.notFound('ไม่พบสถานีครัวนี้');

    const changed = getDb().transaction(() => {
      const didChange = closed
        ? kitchenStationRepository.close(branchId, id, user)
        : kitchenStationRepository.open(branchId, id);
      if (didChange) {
        const pending = before.pending_count ?? 0;
        auditLogService.log({
          actorUser: user,
          action: closed ? 'kitchen_station.close' : 'kitchen_station.open',
          summaryArgs: { station: before.name, pending },
          entityType: 'kitchen_station',
          entityId: id,
          summary: closed
            ? `ปิดสถานี ${before.name} (ค้างในครัว ${pending} รายการ)`
            : `เปิดสถานี ${before.name}`,
          metadata: { branchId, stationCode: before.code, pending },
        });
      }
      return didChange;
    })();

    const status = toStationStatusDto(kitchenStationRepository.findStatus(branchId, id));
    if (changed) {
      emit(EVENTS.STATION_STATUS, { branchId, ...status }, [
        ROOMS.KITCHEN,
        ROOMS.SERVICE,
        ROOMS.MANAGEMENT,
      ]);
    }
    return status;
  },
```

Remove the old `import { toKitchenStationDto } from './kitchen-station.mapper.js';` line (replaced by the combined import above).

- [ ] **Step 7: Controller + routes**

`kitchen-station.controller.js` — add:

```js
  status: asyncHandler(async (req, res) => ok(res, kitchenStationService.listStatus(req.branchId))),
  close: asyncHandler(async (req, res) =>
    ok(
      res,
      kitchenStationService.setClosed(req.validated.params.id, true, {
        branchId: req.branchId,
        user: req.user,
      }),
    ),
  ),
  open: asyncHandler(async (req, res) =>
    ok(
      res,
      kitchenStationService.setClosed(req.validated.params.id, false, {
        branchId: req.branchId,
        user: req.user,
      }),
    ),
  ),
```

`kitchen-station.routes.js` — add `const operator = authorize('admin', 'manager', 'kitchen');` next to `manager`, then register **before** `router.get('/:id', ...)`:

```js
// สถานะเปิด/ปิดรายสาขา (ticket 36) — ต้องอยู่ก่อน '/:id' ไม่งั้น "status" ถูกตีเป็น id แล้วได้ 422
// อ่านได้ทุกบทบาท (แบนเนอร์ "บาร์ปิดตั้งแต่ ... โดย ..." บนหน้าสั่งอาหารของพนักงานเสิร์ฟ) แต่ปิด/เปิด
// ได้เฉพาะครัว/ผู้จัดการ/แอดมิน — ครัวปิดได้ทุกสถานีในสาขาของตัวเอง ไม่จำกัดเฉพาะสถานีที่ผูก (#98)
router.get('/status', authenticate, kitchenStationController.status);
router.post(
  '/:id/close',
  authenticate,
  operator,
  validate({ params: idParamSchema }),
  kitchenStationController.close,
);
router.post(
  '/:id/open',
  authenticate,
  operator,
  validate({ params: idParamSchema }),
  kitchenStationController.open,
);
```

- [ ] **Step 8: Error message i18n** — add to `ERROR_MESSAGES` in `backend/src/i18n/errorMessages.js`, in the kitchen-stations group next to `'ปิดใช้งานสถานีค่าเริ่มต้นไม่ได้ ...'`:

```js
  {
    th: 'เลือกสาขาก่อนดูหรือเปลี่ยนสถานะสถานีครัว',
    en: 'Choose a branch before viewing or changing kitchen station status',
    ko: '주방 스테이션 상태를 보거나 바꾸려면 먼저 지점을 선택해 주세요',
  },
```

- [ ] **Step 9: OpenAPI** — in `backend/docs/openapi.yaml`, insert before `/kitchen-stations/{id}:`:

```yaml
  /kitchen-stations/status:
    get:
      tags: [Kitchen stations]
      summary: สถานะเปิด/ปิดของทุกสถานีที่เปิดใช้งานในสาขาปัจจุบัน (ทุกบทบาทที่ล็อกอิน) — ticket 36
      responses:
        '200': { description: 'สำเร็จ — [{ stationId, code, name, nameEn, nameKo, icon, isClosed, closedAt, closedByName, pendingCount }]' }
        '400': { description: โหมดทุกสาขา — ต้องเลือกสาขาก่อน }

  /kitchen-stations/{id}/close:
    parameters:
      - { in: path, name: id, required: true, schema: { type: integer } }
    post:
      tags: [Kitchen stations]
      summary: ปิดสถานีที่สาขาปัจจุบัน (admin/manager/kitchen) — จานของสถานีนี้สั่งไม่ได้จนกว่าจะเปิดคืน ปิดซ้ำได้ 200
      responses:
        '200': { description: สถานะหลังปิด }
        '400': { description: โหมดทุกสาขา }
        '404': { description: ไม่พบสถานี หรือสถานีถูกปิดใช้งาน }

  /kitchen-stations/{id}/open:
    parameters:
      - { in: path, name: id, required: true, schema: { type: integer } }
    post:
      tags: [Kitchen stations]
      summary: เปิดสถานีคืนที่สาขาปัจจุบัน (admin/manager/kitchen) — เปิดซ้ำได้ 200
      responses:
        '200': { description: สถานะหลังเปิด }
        '400': { description: โหมดทุกสาขา }
        '404': { description: ไม่พบสถานี หรือสถานีถูกปิดใช้งาน }
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `cd backend && node --test tests/station-closures.test.js tests/kitchen-stations.test.js tests/error-i18n.test.js tests/audit-summary-args.test.js`
Expected: all PASS.

- [ ] **Step 11: Commit**

```bash
git add backend/src/modules/kitchen-stations backend/src/realtime/socket.js backend/src/i18n/errorMessages.js backend/docs/openapi.yaml backend/tests/station-closures.test.js
git commit -m "feat(kitchen-stations): close and reopen a station per branch"
```

---

### Task 3: Refuse closed-station dishes on every order path

**Files:**
- Modify: `backend/src/modules/orders/order.service.js` (`buildItemRow`, `create`, `addItems`, `sendToKitchen`)
- Modify: `backend/src/i18n/errorMessages.js`
- Test: `backend/tests/station-closures.test.js`

**Interfaces:**
- Consumes: `kitchenStationService.isClosed(branchId, stationId)` from Task 2.
- Produces: `buildItemRow(input, branchId)` — second argument is the order's branch. 409 message `สถานี "{station}" ปิดอยู่ สั่ง "{menu}" ไม่ได้`.

- [ ] **Step 1: Write the failing tests** — append to `backend/tests/station-closures.test.js`:

```js
const createTable = async (token) => {
  const res = await post('/api/v1/tables', token, { name: unique('T').slice(0, 20) });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.data;
};

const openOrder = (token, tableId, menuItemId) =>
  post('/api/v1/orders', token, {
    type: 'dine_in',
    tableId,
    guestCount: 1,
    items: [{ menuItemId, quantity: 1 }],
  });

test('สั่งจานของสถานีที่ปิด → 409 ทั้งเปิดบิล สั่งเพิ่ม และ QR โดยไม่มีอะไรถูกบันทึก', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const other = (await get('/api/v1/menu-items?availableOnly=true&limit=1', token)).body.data[0];

  // สั่งเพิ่มเข้าออเดอร์ที่ส่งครัวแล้ว — เปิดออเดอร์ก่อนปิดสถานี
  const tableA = await createTable(token);
  const running = (await openOrder(token, tableA.id, other.id)).body.data;
  await post(`/api/v1/orders/${running.id}/send-to-kitchen`, token);

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const tableB = await createTable(token);
  const created = await openOrder(token, tableB.id, dish.id);
  assert.equal(created.status, 409);
  assert.match(created.body.message, new RegExp(`${station.name}.*${dish.name}`));

  const added = await post(`/api/v1/orders/${running.id}/items`, token, {
    items: [{ menuItemId: dish.id, quantity: 1 }],
  });
  assert.equal(added.status, 409);
  const after = (await get(`/api/v1/orders/${running.id}`, token)).body.data;
  assert.equal(after.items.length, 1, 'ไม่มีรายการใหม่ถูกเพิ่ม');

  const tableC = await createTable(token);
  const qr = await api()
    .post(`/api/v1/public/tables/${tableC.qrToken}/items`)
    .send({ items: [{ menuItemId: dish.id, quantity: 1 }] });
  assert.equal(qr.status, 409);
});

test('ออเดอร์ที่บันทึกไว้ยังไม่ส่งครัว แล้วสถานีปิด → ส่งครัวไม่ได้ (409)', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const table = await createTable(token);
  const saved = (await openOrder(token, table.id, dish.id)).body.data;
  assert.equal(saved.status, 'open');

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const sent = await post(`/api/v1/orders/${saved.id}/send-to-kitchen`, token);
  assert.equal(sent.status, 409);
  assert.equal((await get(`/api/v1/orders/${saved.id}`, token)).body.data.status, 'open');
});

test('รายการที่อยู่ในคิวก่อนปิด ยังอยู่บนจอครัวและเดินสถานะได้ตามปกติ', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const table = await createTable(token);
  const order = (await openOrder(token, table.id, dish.id)).body.data;
  await post(`/api/v1/orders/${order.id}/send-to-kitchen`, token);

  const closed = await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  assert.equal(closed.body.data.pendingCount, 1);

  const queue = (await get(`/api/v1/orders/kitchen/queue?station=${station.code}`, token)).body
    .data;
  const ticket = queue.find((item) => item.orderId === order.id);
  assert.ok(ticket, 'ตั๋วยังอยู่บนจอ');
  const cooking = await patch(`/api/v1/orders/${order.id}/items/${ticket.id}/status`, token, {
    status: 'cooking',
  });
  assert.equal(cooking.status, 200, JSON.stringify(cooking.body));
});

test('ไม่ถอยไปสถานีอื่น: ปิดสถานีค่าเริ่มต้น → จานที่ไม่ได้กำหนดสถานีสั่งไม่ได้', async () => {
  const { token } = await login('admin', 'admin123');
  const stations = (await get('/api/v1/kitchen-stations', token)).body.data;
  const fallback = stations.find((row) => row.isDefault);
  const category = (await post('/api/v1/categories', token, { name: unique('หมวด-') })).body.data;
  const dish = (
    await post('/api/v1/menu-items', token, {
      categoryId: category.id,
      name: unique('จาน-'),
      price: 50,
      branchId: 1,
    })
  ).body.data;

  await post(`/api/v1/kitchen-stations/${fallback.id}/close`, token);
  try {
    const table = await createTable(token);
    assert.equal((await openOrder(token, table.id, dish.id)).status, 409);
  } finally {
    // สถานีค่าเริ่มต้นใช้ร่วมกับเทสต์อื่นในไฟล์ — เปิดคืนเสมอ
    await post(`/api/v1/kitchen-stations/${fallback.id}/open`, token);
  }
});

test('สถานีที่ปิดอยู่แล้วถูกปิดใช้งานภายหลัง → แถวปิดค้างไม่มีผล จานสั่งได้', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  await patch(`/api/v1/kitchen-stations/${station.id}`, token, { isActive: false });

  const table = await createTable(token);
  assert.equal((await openOrder(token, table.id, dish.id)).status, 201);
});
```

Check the item-status route path against `backend/src/modules/orders/order.routes.js` before running (`grep -n "status" backend/src/modules/orders/order.routes.js`) and adjust the `patch` URL in the third test if it differs.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && node --test tests/station-closures.test.js`
Expected: the four ordering tests FAIL (201/200 where 409 expected); the "inactive" one passes already.

- [ ] **Step 3: Implement the guard** — in `order.service.js`:

Change the signature and add the check right after the station is resolved:

```js
const buildItemRow = (input, branchId) => {
  // ...existing body unchanged up to the station line...
  const station = kitchenStationService.resolveForMenuItem(menuItem);
  // สถานีปิดอยู่ที่สาขาของออเดอร์ (ticket 36) — ปฏิเสธทั้ง submit เหมือนเมนูปิดขาย ไม่ถอยไปสถานีอื่น
  // เพราะส่งตั๋วไปสถานีที่ทำจานนี้ไม่ได้แย่กว่า "สั่งไม่ได้"
  if (kitchenStationService.isClosed(branchId, station.id)) {
    throw ApiError.conflict(`สถานี "${station.name}" ปิดอยู่ สั่ง "${menuItem.name}" ไม่ได้`);
  }
```

Update the two callers:

```js
// create()
    const itemRows = (payload.items ?? []).map((input) => buildItemRow(input, branchId));
// addItems()
    const itemRows = items.map((input) => buildItemRow(input, order.branch_id));
```

In `sendToKitchen`, after `if (items.length === 0) throw ...`:

```js
    // ออเดอร์ที่บันทึกไว้แต่ยังไม่ส่งครัว — สถานีอาจปิดไปตอนที่บิลรออยู่ (ticket 36) ตรวจซ้ำก่อนส่ง
    // ออเดอร์ที่อยู่ในครัวแล้วไม่ต้องตรวจ รายการที่สั่งเพิ่มถูกตรวจตอน addItems ไปแล้ว
    if (order.status === 'open') {
      for (const item of items) {
        if (kitchenStationService.isClosed(order.branch_id, item.station_id)) {
          throw ApiError.conflict(
            `สถานี "${item.station_name_snapshot}" ปิดอยู่ สั่ง "${item.name_snapshot}" ไม่ได้`,
          );
        }
      }
    }
```

- [ ] **Step 4: Error message i18n** — add next to `'เมนู "{menu}" ปิดการขายอยู่'`:

```js
  {
    th: 'สถานี "{station}" ปิดอยู่ สั่ง "{menu}" ไม่ได้',
    en: '"{station}" is closed — "{menu}" can\'t be ordered right now',
    ko: '"{station}"이(가) 닫혀 있어 "{menu}"을(를) 지금 주문할 수 없습니다',
  },
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && node --test tests/station-closures.test.js tests/order-flow.test.js tests/public-order.test.js tests/kitchen-station-routing.test.js tests/error-i18n.test.js`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/orders/order.service.js backend/src/i18n/errorMessages.js backend/tests/station-closures.test.js
git commit -m "feat(orders): refuse dishes whose kitchen station is closed"
```

---

### Task 4: Menu DTO `closedStation` and hidden QR dishes

**Files:**
- Modify: `backend/src/modules/menu/menu.service.js` (`list`)
- Modify: `backend/src/modules/public-order/public-order.service.js` (`getMenu`)
- Test: `backend/tests/station-closures.test.js`

**Interfaces:**
- Consumes: `kitchenStationService.closedStationLookup()` from Task 2.
- Produces: every item from `GET /menu-items` carries `closedStation: { id, name, nameEn, nameKo } | null`. `GET /public/tables/:qrToken/menu` omits closed dishes and does not count them in `staffOnlyCount`.

- [ ] **Step 1: Write the failing tests** — append:

```js
test('เมนูพนักงานบอก closedStation ส่วนเมนู QR ไม่มีจานนั้นเลย — is_available ไม่ถูกแตะ', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  const table = await createTable(token);
  const findDish = async () =>
    (await get('/api/v1/menu-items?limit=500', token)).body.data.find((row) => row.id === dish.id);

  assert.equal((await findDish()).closedStation, null);

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);

  const closedRow = await findDish();
  assert.deepEqual(closedRow.closedStation, {
    id: station.id,
    name: station.name,
    nameEn: null,
    nameKo: null,
  });
  assert.equal(closedRow.isAvailable, true, 'ปิดสถานีไม่แตะ is_available');

  const publicMenu = (await api().get(`/api/v1/public/tables/${table.qrToken}/menu`)).body.data;
  assert.ok(!publicMenu.items.some((row) => row.id === dish.id), 'QR ไม่เห็นจานของสถานีที่ปิด');

  await post(`/api/v1/kitchen-stations/${station.id}/open`, token);
  assert.equal((await findDish()).closedStation, null);
});

test('เมนูที่ปิดขายไว้ก่อน → ปิดแล้วเปิดสถานีคืน เมนูนั้นยังปิดขายอยู่', async () => {
  const { token } = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(token);
  await patch(`/api/v1/menu-items/${dish.id}/availability`, token, { isAvailable: false });

  await post(`/api/v1/kitchen-stations/${station.id}/close`, token);
  await post(`/api/v1/kitchen-stations/${station.id}/open`, token);

  const row = (await get(`/api/v1/menu-items/${dish.id}`, token)).body.data;
  assert.equal(row.isAvailable, false);
});

test('admin โหมดทุกสาขาเห็น closedStation ตามสาขาของจานเอง', async () => {
  const admin = await login('admin', 'admin123');
  const { station, dish } = await stationWithDish(admin.token);
  await post(`/api/v1/kitchen-stations/${station.id}/close`, admin.token);

  const all = await post('/api/v1/auth/select-branch', admin.token, { branchId: null });
  const rows = (await get('/api/v1/menu-items?limit=1000', all.body.data.token)).body.data;
  assert.equal(rows.find((row) => row.id === dish.id).closedStation?.id, station.id);
});
```

Check the availability route against `backend/src/modules/menu/menu.routes.js` (`grep -n availability backend/src/modules/menu/menu.routes.js`) and adjust method/path if needed.

- [ ] **Step 2: Run to verify failure**

Run: `cd backend && node --test tests/station-closures.test.js`
Expected: FAIL — `closedStation` is `undefined`; QR menu still lists the dish.

- [ ] **Step 3: Implement** — `menu.service.js`, add the import and change `list`:

```js
import { kitchenStationService } from '../kitchen-stations/kitchen-station.service.js';
// ...
  list(filters, currentBranchId) {
    const { items, total } = menuRepository.findAll({ ...filters, branchId: currentBranchId });
    const groupsByItem = menuRepository.findOptionGroupsForItems(items.map((item) => item.id));
    const ingredientsByItem = menuRepository.findIngredientLinksForItems(
      items.map((item) => item.id),
    );
    // สถานีของจานปิดอยู่ไหม (ticket 36) — "สั่งได้" ตัดสินตอนอ่าน ไม่แตะ is_available
    const closedStationOf = kitchenStationService.closedStationLookup();
    return {
      items: items.map((item) => ({
        ...toMenuItemDto(item, groupsByItem.get(item.id) ?? [], ingredientsByItem.get(item.id) ?? []),
        closedStation: closedStationOf(item),
      })),
      total,
    };
  },
```

Check `kitchen-station.service.js` does not import `menu.service.js` (it must not — that would create a cycle). It doesn't today.

`public-order.service.js` `getMenu`:

```js
    const { items: listed } = menuService.list({ availableOnly: true }, table.branch_id);
    // จานของสถานีที่ปิดอยู่ (ticket 36) ซ่อนจากลูกค้าเหมือนจานปิดขาย และไม่นับเป็น "สั่งกับพนักงาน"
    // เพราะพนักงานก็สั่งให้ไม่ได้เหมือนกัน
    const items = listed.filter((item) => !item.closedStation);
```

(the following lines keep using `items` exactly as today).

- [ ] **Step 4: Run tests**

Run: `cd backend && npm test`
Expected: all PASS (whole backend suite — `menu.test.js` deep-equals may need `closedStation: null` added; if a test compares the full list DTO, add the field there).

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/menu/menu.service.js backend/src/modules/public-order/public-order.service.js backend/tests
git commit -m "feat(menu): mark dishes of closed stations and hide them from QR"
```

---

### Task 5: App data layer + demo mode mirror

**Files:**
- Create: `app/lib/features/menu/domain/entities/station_status.dart`, `app/lib/features/menu/domain/entities/closed_station.dart`, `app/lib/features/menu/data/models/station_status_model.dart`
- Modify: `app/lib/core/network/api_endpoints.dart`, `app/lib/core/network/socket_client.dart`
- Modify: `menu_remote_data_source.dart`, `menu_repository.dart`, `menu_repository_impl.dart`, `menu_usecases.dart`, `menu_item.dart`, `menu_item_model.dart`, `app/lib/app/di/bindings/use_case_bindings.dart`
- Modify demo: `demo_store.dart`, `demo_store_menu.dart`, `demo_store_order_items.dart`, `demo_store_orders.dart`, `demo_menu_data_source.dart`, `demo_self_order_data_source.dart`
- Modify: `app/lib/core/localization/translations/order_translations.dart`, `menu_translations.dart`
- Modify: `app/lib/features/audit_log/domain/entities/audit_log_action.dart`, `app/lib/core/localization/translations/audit_log_translations.dart`
- Test: `app/test/core/demo_store_test.dart`, `app/test/domain/entities_test.dart`

**Interfaces:**
- Consumes: HTTP contract from Tasks 2–4.
- Produces:
  - `class ClosedStation { int id; String name; String? nameEn; String? nameKo; String get displayName; }`
  - `MenuItem.closedStation: ClosedStation?` and `bool get isOrderable => isAvailable && closedStation == null`
  - `class StationStatus { int stationId; String code; String name; String? nameEn; String? nameKo; String? icon; bool isClosed; String? closedAt; String? closedByName; int pendingCount; String get displayName; String get labelWithIcon; }`
  - `MenuRepository.getStationStatuses(): Future<Result<List<StationStatus>>>`, `MenuRepository.setStationClosed(int stationId, {required bool closed}): Future<Result<StationStatus>>`
  - `GetStationStatusesUseCase` (NoParamsUseCase), `SetStationClosedUseCase` (UseCase<StationStatus, SetStationClosedParams>), `SetStationClosedParams({required int stationId, required bool closed})`
  - `SocketEvents.stationStatus = 'station:status'`; `SocketClient.dispatchLocal(String event, dynamic data)` (`@visibleForTesting`)
  - `ApiEndpoints.kitchenStationStatus`, `ApiEndpoints.closeKitchenStation(int id)`, `ApiEndpoints.openKitchenStation(int id)`
  - Demo: `DemoStore.stationClosures: Map<int, Map<String, dynamic>>` (stationId → {closedAt, closedByName}); `stationStatusList()`, `setStationClosed(int id, bool closed, {int? actorId})`, `closedStationFor(Map menu): Map?`

- [ ] **Step 1: Write the failing tests**

Append to `app/test/domain/entities_test.dart` (inside `main()`; import `menu_item_model.dart` / `station_status_model.dart` as the file already does for other models):

```dart
  group('ticket 36 — สถานีปิด', () {
    test('MenuItemModel อ่าน closedStation และ isOrderable ตามทั้งสองเงื่อนไข', () {
      final open = MenuItemModel.fromJson(const {
        'id': 1, 'categoryId': 1, 'name': 'ชาไทย', 'price': 45,
        'isAvailable': true, 'closedStation': null,
      });
      final closed = MenuItemModel.fromJson(const {
        'id': 2, 'categoryId': 1, 'name': 'ชาไทย', 'price': 45, 'isAvailable': true,
        'closedStation': {'id': 3, 'name': 'บาร์', 'nameEn': 'Bar', 'nameKo': '바'},
      });
      expect(open.isOrderable, isTrue);
      expect(closed.isOrderable, isFalse);
      expect(closed.closedStation!.name, 'บาร์');
    });

    test('StationStatusModel อ่านค่าปิด/เปิดและจำนวนค้าง', () {
      final status = StationStatusModel.fromJson(const {
        'stationId': 3, 'code': 'bar', 'name': 'บาร์', 'icon': '🥤',
        'isClosed': true, 'closedAt': '2026-10-08 14:03:00',
        'closedByName': 'เชฟต้น', 'pendingCount': 2,
      });
      expect(status.isClosed, isTrue);
      expect(status.pendingCount, 2);
      expect(status.labelWithIcon, '🥤 บาร์');
    });
  });
```

Append to `app/test/core/demo_store_test.dart` (follow the file's existing `setUp` that creates a fresh `DemoStore()`; reuse its helpers for opening an order if any — otherwise call the store methods directly as below):

```dart
  group('ticket 36 — ปิด/เปิดสถานีในโหมดสาธิต', () {
    late DemoStore store;
    setUp(() => store = DemoStore());

    Map<String, dynamic> barDish() => store.menuItems.firstWhere(
      (item) => store.resolveStationFor(item)['code'] == 'bar',
    );
    int barId() =>
        store.kitchenStations.firstWhere((s) => s['code'] == 'bar')['id'] as int;

    test('ปิดบาร์ → จานบาร์มี closedStation, ปิดซ้ำได้, เปิดคืนแล้วหาย', () {
      final dish = barDish();
      store.setStationClosed(barId(), true, actorId: 5);
      store.setStationClosed(barId(), true, actorId: 5);
      final listed = store.menuList().firstWhere((row) => row['id'] == dish['id']);
      expect(store.closedStationFor(listed)?['id'], barId());
      expect(
        store.stationStatusList().firstWhere((s) => s['stationId'] == barId())['isClosed'],
        isTrue,
      );
      store.setStationClosed(barId(), false, actorId: 5);
      expect(store.closedStationFor(listed), isNull);
    });

    test('สั่งจานบาร์ตอนบาร์ปิด → 409 และ is_available ไม่ถูกแตะ', () {
      final dish = barDish();
      store.setStationClosed(barId(), true, actorId: 5);
      final order = store.createOrder({
        'type': 'takeaway',
        'items': <Map<String, dynamic>>[],
      });
      expect(
        () => store.addItems(order['id'] as int, [
          {'menuItemId': dish['id'], 'quantity': 1},
        ]),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      expect(dish['isAvailable'], isTrue);
    });

    test('waiter ปิดสถานีไม่ได้ (403)', () {
      final waiterId = store.users.firstWhere((u) => u['role'] == 'waiter')['id'] as int;
      expect(
        () => store.setStationClosed(barId(), true, actorId: waiterId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    });
  });
```

If `DemoStore.createOrder` has a different name/shape, use the same call the existing demo order tests in this file use to open a takeaway order.

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/domain/entities_test.dart test/core/demo_store_test.dart`
Expected: compile errors — `isOrderable`, `StationStatusModel`, `setStationClosed` undefined.

- [ ] **Step 3: Entities and models**

`app/lib/features/menu/domain/entities/closed_station.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';

/// สถานีครัวที่ปิดอยู่ของจานหนึ่ง (ticket 36) — ติดมากับเมนูเฉพาะตอนสถานีปิด ใช้ทำป้าย "บาร์ปิด"
class ClosedStation {
  const ClosedStation({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameKo,
  });

  factory ClosedStation.fromJson(Map<String, dynamic> json) => ClosedStation(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    nameEn: json['nameEn'] as String?,
    nameKo: json['nameKo'] as String?,
  );

  final int id;
  final String name;
  final String? nameEn;
  final String? nameKo;

  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);
}
```

`app/lib/features/menu/domain/entities/station_status.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/localization/localized_name.dart';

/// สถานะเปิด/ปิดของสถานีครัวหนึ่งในสาขาปัจจุบัน (ticket 36)
///
/// "ปิด" เป็นเรื่องหน้างานรายสาขา ไม่ใช่ "ปิดใช้งาน" ของเครือร้าน (CONTEXT.md)
class StationStatus {
  const StationStatus({
    required this.stationId,
    required this.code,
    required this.name,
    this.nameEn,
    this.nameKo,
    this.icon,
    this.isClosed = false,
    this.closedAt,
    this.closedByName,
    this.pendingCount = 0,
  });

  final int stationId;
  final String code;
  final String name;
  final String? nameEn;
  final String? nameKo;
  final String? icon;
  final bool isClosed;

  /// เวลาที่ปิด (UTC จาก SQLite) — แสดงผ่าน `Formatters.dateTime`
  final String? closedAt;
  final String? closedByName;

  /// รายการของสถานีนี้ที่ยังค้างในครัว (รอทำ/กำลังทำ) — ใช้เตือนตอนจะปิด
  final int pendingCount;

  String get displayName =>
      LocalizedName.pick(name: name, nameEn: nameEn, nameKo: nameKo);

  String get labelWithIcon =>
      icon == null || icon!.isEmpty ? displayName : '$icon $displayName';
}
```

`app/lib/features/menu/data/models/station_status_model.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/station_status.dart';

class StationStatusModel extends StationStatus {
  const StationStatusModel({
    required super.stationId,
    required super.code,
    required super.name,
    super.nameEn,
    super.nameKo,
    super.icon,
    super.isClosed,
    super.closedAt,
    super.closedByName,
    super.pendingCount,
  });

  factory StationStatusModel.fromJson(Map<String, dynamic> json) =>
      StationStatusModel(
        stationId: (json['stationId'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nameEn: json['nameEn'] as String?,
        nameKo: json['nameKo'] as String?,
        icon: json['icon'] as String?,
        isClosed: json['isClosed'] as bool? ?? false,
        closedAt: json['closedAt'] as String?,
        closedByName: json['closedByName'] as String?,
        pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      );
}
```

`menu_item.dart` — add constructor param `this.closedStation,`, field and getter (import `closed_station.dart`):

```dart
  /// สถานีครัวที่ปิดอยู่ของจานนี้ (ticket 36) — null = สถานีเปิดอยู่
  final ClosedStation? closedStation;

  /// สั่งได้ตอนนี้ = เปิดขายอยู่ และสถานีของจานเปิดอยู่ (CONTEXT.md "Orderable dish")
  bool get isOrderable => isAvailable && closedStation == null;
```

`menu_item_model.dart` — add `super.closedStation,` to the constructor and in `fromJson`:

```dart
    closedStation: json['closedStation'] is Map<String, dynamic>
        ? ClosedStation.fromJson(json['closedStation'] as Map<String, dynamic>)
        : null,
```

If `MenuItem` has a `copyWith`, add `closedStation` to it as well.

- [ ] **Step 4: Endpoints, socket, data source, repository, use cases**

`api_endpoints.dart` (after `kitchenStation`):

```dart
  static const String kitchenStationStatus = '/kitchen-stations/status';
  static String closeKitchenStation(int id) => '/kitchen-stations/$id/close';
  static String openKitchenStation(int id) => '/kitchen-stations/$id/open';
```

`socket_client.dart` — in `SocketEvents` add `static const String stationStatus = 'station:status';`, and in `SocketClient`:

```dart
  /// ยิง event เข้า handler ที่ลงทะเบียนไว้โดยไม่ผ่าน socket จริง — ใช้ในเทสต์เท่านั้น
  @visibleForTesting
  void dispatchLocal(String event, dynamic data) {
    for (final handler in List.of(_handlers[event] ?? const [])) {
      handler(data);
    }
  }
```

`menu_remote_data_source.dart` — abstract:

```dart
  Future<List<StationStatusModel>> getStationStatuses();
  Future<StationStatusModel> setStationClosed(int stationId, {required bool closed});
```

impl:

```dart
  @override
  Future<List<StationStatusModel>> getStationStatuses() async {
    final result = await _client.get(ApiEndpoints.kitchenStationStatus);
    return result.asList
        .map(StationStatusModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<StationStatusModel> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    final result = await _client.post(
      closed
          ? ApiEndpoints.closeKitchenStation(stationId)
          : ApiEndpoints.openKitchenStation(stationId),
    );
    return StationStatusModel.fromJson(result.asMap);
  }
```

`menu_repository.dart`:

```dart
  /// สถานะเปิด/ปิดของสถานีในสาขาปัจจุบัน (ticket 36)
  Future<Result<List<StationStatus>>> getStationStatuses();
  Future<Result<StationStatus>> setStationClosed(int stationId, {required bool closed});
```

`menu_repository_impl.dart`:

```dart
  @override
  Future<Result<List<StationStatus>>> getStationStatuses() =>
      guard(() async => await _remote.getStationStatuses());

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) => guard(
    () async => await _remote.setStationClosed(stationId, closed: closed),
  );
```

`menu_usecases.dart`:

```dart
/// สถานะเปิด/ปิดของสถานีครัวรายสาขา (ticket 36)
class GetStationStatusesUseCase implements NoParamsUseCase<List<StationStatus>> {
  const GetStationStatusesUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<List<StationStatus>>> call() => _repository.getStationStatuses();
}

class SetStationClosedParams {
  const SetStationClosedParams({required this.stationId, required this.closed});

  final int stationId;
  final bool closed;
}

class SetStationClosedUseCase
    implements UseCase<StationStatus, SetStationClosedParams> {
  const SetStationClosedUseCase(this._repository);

  final MenuRepository _repository;

  @override
  Future<Result<StationStatus>> call(SetStationClosedParams params) =>
      _repository.setStationClosed(params.stationId, closed: params.closed);
}
```

`use_case_bindings.dart` — next to the kitchen-station use cases:

```dart
  Get.lazyPut(
    () => GetStationStatusesUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => SetStationClosedUseCase(Get.find<MenuRepository>()),
    fenix: true,
  );
```

- [ ] **Step 5: Demo mirror**

`demo_store.dart` — add the field and reset it:

```dart
  /// สถานีที่ปิดอยู่ (ticket 36) — โหมดสาธิตมีสาขาเดียว จึงเก็บตามสถานีอย่างเดียว
  final Map<int, Map<String, dynamic>> stationClosures = {};
```

and in `reset()` add `stationClosures.clear();`.

`demo_store_menu.dart` — inside the kitchen-stations section:

```dart
  /// สถานีที่ปิดอยู่ของจานนี้ (ticket 36) — mirror ของ kitchenStationService.closedStationLookup
  /// สถานีที่ถูกปิดใช้งานไม่นับ แม้ยังมีแถวปิดค้าง
  Map<String, dynamic>? closedStationFor(Map<String, dynamic> menu) {
    final station = resolveStationFor(menu);
    if (station['isActive'] == false) return null;
    if (!stationClosures.containsKey(station['id'])) return null;
    return {
      'id': station['id'],
      'name': station['name'],
      'nameEn': station['nameEn'],
      'nameKo': station['nameKo'],
    };
  }

  List<Map<String, dynamic>> stationStatusList() => [
    for (final station in kitchenStationList(activeOnly: true))
      {
        'stationId': station['id'],
        'code': station['code'],
        'name': station['name'],
        'nameEn': station['nameEn'],
        'nameKo': station['nameKo'],
        'icon': station['icon'],
        'isClosed': stationClosures.containsKey(station['id']),
        'closedAt': stationClosures[station['id']]?['closedAt'],
        'closedByName': stationClosures[station['id']]?['closedByName'],
        'pendingCount': kitchenQueue(const ['pending', 'cooking'])
            .where((item) => (item['stationId'] ?? defaultStation()['id']) == station['id'])
            .length,
      },
  ];

  /// mirror ของ kitchenStationService.setClosed — ครัว/ผู้จัดการ/แอดมินเท่านั้น, ปิดซ้ำได้
  Map<String, dynamic> setStationClosed(int id, bool closed, {int? actorId}) {
    final role = _actorRole(actorId);
    if (role != null &&
        role != UserRole.admin &&
        role != UserRole.manager &&
        role != UserRole.kitchen) {
      throw ApiException(message: 'error_forbidden'.tr, statusCode: 403);
    }
    final station = kitchenStations.firstWhere(
      (row) => row['id'] == id && row['isActive'] != false,
      orElse: () => throw ApiException(
        message: 'menu_station_not_found_error'.tr,
        statusCode: 404,
      ),
    );
    final wasClosed = stationClosures.containsKey(id);
    if (closed && !wasClosed) {
      stationClosures[id] = {
        'closedAt': AppClock.now().toUtc().toIso8601String(),
        'closedByName': actorId == null ? null : _findUser(actorId)['name'],
      };
    } else if (!closed && wasClosed) {
      stationClosures.remove(id);
    }
    if (closed != wasClosed) {
      final pending = stationStatusList()
          .firstWhere((row) => row['stationId'] == id)['pendingCount'];
      _logAudit(
        actorId: actorId,
        action: closed ? 'kitchen_station.close' : 'kitchen_station.open',
        summaryArgs: {'station': station['name'], 'pending': pending},
        entityType: 'kitchen_station',
        entityId: id,
        summary: closed
            ? 'ปิดสถานี ${station['name']} (ค้างในครัว $pending รายการ)'
            : 'เปิดสถานี ${station['name']}',
        metadata: {'stationCode': station['code'], 'pending': pending},
      );
    }
    return stationStatusList().firstWhere((row) => row['stationId'] == id);
  }
```

Use whatever key the demo store already uses for an unknown-station 404 instead of `menu_station_not_found_error` if one exists (`grep -n "statusCode: 404" app/lib/core/demo/demo_store_menu.dart`); otherwise add `menu_station_not_found_error` to `menu_translations.dart` (th: `ไม่พบสถานีครัวนี้`, en: `Kitchen station not found`, ko: `주방 스테이션을 찾을 수 없습니다`). Check `kitchenQueue` item keys — if queue rows store the station under a different key than `stationId`, use that key.

`demo_menu_data_source.dart` — in `getMenuItems` map each row to include `closedStation`:

```dart
        .map((row) => {..._store.presentMenuItem(row), 'closedStation': _store.closedStationFor(row)})
```

and add:

```dart
  @override
  Future<List<StationStatusModel>> getStationStatuses() => _delayed(
    () => _store
        .stationStatusList()
        .map(StationStatusModel.fromJson)
        .toList(growable: false),
  );

  @override
  Future<StationStatusModel> setStationClosed(
    int stationId, {
    required bool closed,
  }) => _delayed(
    () => StationStatusModel.fromJson(
      _store.setStationClosed(stationId, closed, actorId: _auth.currentUserId),
    ),
  );
```

`demo_store_order_items.dart` `_appendItems` — right after `final station = resolveStationFor(menu);`:

```dart
      // mirror ของ buildItemRow (ticket 36) — สถานีปิด = สั่งไม่ได้ ไม่ถอยไปสถานีอื่น
      if (closedStationFor(menu) != null) {
        throw ApiException(
          message: 'order_error_station_closed'.trParams({
            'station': DemoNames.of(station),
            'name': DemoNames.of(menu),
          }),
          statusCode: 409,
        );
      }
```

`demo_store_orders.dart` `sendToKitchen` — after the `active.isEmpty` check:

```dart
    // mirror ของ order.service.js#sendToKitchen (ticket 36) — บิลที่รออยู่แล้วสถานีปิดไปก่อนส่ง
    if (order['status'] == OrderStatus.open) {
      for (final item in active) {
        final closed = stationClosures.containsKey(item['stationId']);
        if (closed) {
          throw ApiException(
            message: 'order_error_station_closed'.trParams({
              'station': item['stationName'] as String? ?? '',
              'name': item['name'] as String? ?? '',
            }),
            statusCode: 409,
          );
        }
      }
    }
```

(Use the item keys the demo order item really stores for station id/name — see the map built after `resolveStationFor` in `_appendItems`.)

`demo_self_order_data_source.dart` `getMenu` — filter closed dishes before both uses:

```dart
    final available = _store
        .menuList(availableOnly: true)
        .where((item) => _store.closedStationFor(item) == null)
        .toList(growable: false);
```

`order_translations.dart` — add to th/en/ko maps:

```dart
  'order_error_station_closed': 'สถานี "@station" ปิดอยู่ สั่ง "@name" ไม่ได้',
  'order_error_station_closed': '"@station" is closed — "@name" can\'t be ordered right now',
  'order_error_station_closed': '"@station"이(가) 닫혀 있어 "@name"을(를) 지금 주문할 수 없습니다',
```

- [ ] **Step 6: Audit action in the app**

`audit_log_action.dart` — add constants, append to `all`, and to `_keys`:

```dart
  static const String kitchenStationClose = 'kitchen_station.close';
  static const String kitchenStationOpen = 'kitchen_station.open';
  // all: ..., kitchenStationClose, kitchenStationOpen,
  // _keys:
    kitchenStationClose: 'audit_log_action_kitchen_station_close',
    kitchenStationOpen: 'audit_log_action_kitchen_station_open',
```

`audit_log_translations.dart` — th/en/ko (summary keys follow `audit_summary_${action with '.'→'_'}`):

```dart
  // th
  'audit_log_action_kitchen_station_close': 'ปิดสถานีครัว',
  'audit_log_action_kitchen_station_open': 'เปิดสถานีครัว',
  'audit_summary_kitchen_station_close': 'ปิดสถานี @station (ค้างในครัว @pending รายการ)',
  'audit_summary_kitchen_station_open': 'เปิดสถานี @station',
  // en
  'audit_log_action_kitchen_station_close': 'Close kitchen station',
  'audit_log_action_kitchen_station_open': 'Reopen kitchen station',
  'audit_summary_kitchen_station_close': 'Closed @station (@pending still in the kitchen)',
  'audit_summary_kitchen_station_open': 'Reopened @station',
  // ko
  'audit_log_action_kitchen_station_close': '주방 스테이션 닫기',
  'audit_log_action_kitchen_station_open': '주방 스테이션 다시 열기',
  'audit_summary_kitchen_station_close': '@station 닫음 (주방에 남은 항목 @pending개)',
  'audit_summary_kitchen_station_open': '@station 다시 엶',
```

The Thai summary must match the backend `summary` string character for character (`expectAuditSummariesRenderable` checks it).

- [ ] **Step 7: Run tests**

Run: `cd app && flutter test test/domain/entities_test.dart test/core/demo_store_test.dart test/presentation/audit_summary_text_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 8: Commit**

```bash
git add app/lib app/test
git commit -m "feat(app): station status data layer and demo mirror"
```

---

### Task 6: `StationStatusController`, status sheet and closed banner

**Files:**
- Create: `app/lib/features/kitchen/presentation/controllers/station_status_controller.dart`
- Create: `app/lib/features/kitchen/presentation/widgets/station_status_sheet.dart`, `app/lib/features/kitchen/presentation/widgets/station_closed_banner.dart`
- Modify: `app/lib/core/localization/translations/kitchen_translations.dart`
- Test: `app/test/presentation/station_status_controller_test.dart`, `app/test/widget/station_status_sheet_test.dart`

**Interfaces:**
- Consumes: `GetStationStatusesUseCase`, `SetStationClosedUseCase`, `SessionService`, `SocketEvents.stationStatus` from Task 5.
- Produces:
  - `StationStatusController({required GetStationStatusesUseCase getStatuses, required SetStationClosedUseCase setClosed, required SessionService session})`
  - `RxList<StationStatus> statuses`, `RxBool isLoading`, `RxnString errorMessage`, `RxInt closedVersion` (bumped only when the set of closed station ids changes after the first load)
  - `List<StationStatus> get closed`
  - `Future<void> load()`, `Future<bool> setClosed(StationStatus station, bool closed)` (returns success)
  - `bool get canUse` → false when the session has no branch (admin all-branches mode)
  - `StationStatusSheet.show()` — static, opens the sheet; widget `StationStatusSheet` reads `Get.find<StationStatusController>()`
  - `StationClosedBanner` widget — reads the controller, renders nothing when no station is closed

- [ ] **Step 1: Write the failing controller test** — `app/test/presentation/station_status_controller_test.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';

class _FakeMenuRepository implements MenuRepository {
  List<StationStatus> statuses = [];
  Failure? nextFailure;
  int loads = 0;
  final calls = <String>[];

  @override
  Future<Result<List<StationStatus>>> getStationStatuses() async {
    loads++;
    return Result.success(List.of(statuses));
  }

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    calls.add('$stationId:$closed');
    if (nextFailure != null) return Result.failure(nextFailure!);
    statuses = [
      for (final s in statuses)
        s.stationId == stationId ? _status(s.stationId, s.code, closed: closed) : s,
    ];
    return Result.success(statuses.firstWhere((s) => s.stationId == stationId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StationStatus _status(int id, String code, {bool closed = false, int pending = 0}) =>
    StationStatus(
      stationId: id,
      code: code,
      name: code,
      isClosed: closed,
      closedByName: closed ? 'เชฟต้น' : null,
      pendingCount: pending,
    );

void main() {
  late _FakeMenuRepository repository;
  late SocketClient socket;
  late StationStatusController controller;

  setUp(() {
    repository = _FakeMenuRepository()
      ..statuses = [_status(1, 'hot'), _status(3, 'bar', pending: 2)];
    socket = SocketClient();
    controller = StationStatusController(
      getStatuses: GetStationStatusesUseCase(repository),
      setClosed: SetStationClosedUseCase(repository),
      session: SessionService(storage: StorageService.memory(), socket: socket),
    );
  });

  tearDown(() => controller.onClose());

  test('load เติมสถานะ และ closed คืนเฉพาะสถานีที่ปิด', () async {
    repository.statuses = [_status(1, 'hot'), _status(3, 'bar', closed: true)];
    await controller.load();
    expect(controller.statuses.length, 2);
    expect(controller.closed.single.code, 'bar');
  });

  test('closedVersion ไม่ขยับตอนโหลดแรก ขยับเมื่อชุดสถานีที่ปิดเปลี่ยนเท่านั้น', () async {
    await controller.load();
    expect(controller.closedVersion.value, 0);

    await controller.load();
    expect(controller.closedVersion.value, 0, reason: 'โหลดซ้ำ ชุดเดิม');

    await controller.setClosed(controller.statuses.last, true);
    expect(repository.calls, ['3:true']);
    expect(controller.closed.single.code, 'bar');
    expect(controller.closedVersion.value, 1);
  });

  test('event station:status → โหลดสถานะใหม่จากเซิร์ฟเวอร์', () async {
    controller.onInit();
    await Future<void>.delayed(Duration.zero);
    final before = repository.loads;

    socket.dispatchLocal(SocketEvents.stationStatus, {'branchId': 1});
    await Future<void>.delayed(Duration.zero);

    expect(repository.loads, before + 1);
  });

  test('ปิดไม่สำเร็จ → คืน false และสถานะเดิมไม่เปลี่ยน', () async {
    await controller.load();
    repository.nextFailure = const ServerFailure('สิทธิ์ไม่เพียงพอ');
    final ok = await controller.setClosed(controller.statuses.last, true);
    expect(ok, isFalse);
    expect(controller.closed, isEmpty);
  });
}
```

`StationStatusController.setClosed` must not open dialogs itself (the sheet does), so the test needs no Get setup.

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/presentation/station_status_controller_test.dart`
Expected: compile error — controller does not exist.

- [ ] **Step 3: Controller** — `station_status_controller.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/network/socket_client.dart';
import '../../../../core/services/session_service.dart';
import '../../../menu/domain/entities/station_status.dart';
import '../../../menu/domain/usecases/menu_usecases.dart';

/// สถานะเปิด/ปิดของสถานีครัวในสาขาปัจจุบัน (ticket 36) — ใช้ร่วมกันระหว่างจอครัวกับหน้าสั่งอาหาร
///
/// event `station:status` ไม่ได้แยกห้องตามสาขา จึงไม่กรอง payload แต่โหลดสถานะของสาขาตัวเองใหม่
/// ทุกครั้งที่มี event — ได้ค่าที่ถูกต้องเสมอ และตารางนี้เล็กมาก
class StationStatusController extends GetxController {
  StationStatusController({
    required GetStationStatusesUseCase getStatuses,
    required SetStationClosedUseCase setClosed,
    required SessionService session,
  }) : _getStatuses = getStatuses,
       _setClosed = setClosed,
       _session = session;

  final GetStationStatusesUseCase _getStatuses;
  final SetStationClosedUseCase _setClosed;
  final SessionService _session;

  final RxList<StationStatus> statuses = <StationStatus>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  /// ขยับเมื่อชุดสถานีที่ปิดเปลี่ยน (ไม่นับโหลดแรก) — หน้าสั่งอาหารฟังค่านี้เพื่อโหลดเมนูใหม่
  final RxInt closedVersion = 0.obs;

  Set<int>? _lastClosedIds;
  VoidCallback? _unsubscribe;

  /// admin โหมด "ทุกสาขา" ไม่มีสาขาปัจจุบัน backend จึงตอบ 400 — ซ่อนปุ่มและแบนเนอร์ไปเลย
  bool get canUse =>
      _session.currentUser == null || _session.currentUser!.branchId != null;

  List<StationStatus> get closed =>
      statuses.where((status) => status.isClosed).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    load();
    _unsubscribe = _session.socket.on(SocketEvents.stationStatus, (_) => load());
  }

  @override
  void onClose() {
    _unsubscribe?.call();
    super.onClose();
  }

  Future<void> load() async {
    if (!canUse) return;
    isLoading.value = true;
    final result = await _getStatuses();
    isLoading.value = false;
    result.fold(
      onSuccess: _apply,
      onFailure: (failure) => errorMessage.value = failure.message,
    );
  }

  /// คืน true เมื่อสำเร็จ — ข้อความ error อยู่ใน [errorMessage] ให้ชีตแสดงเอง
  Future<bool> setClosed(StationStatus station, bool closed) async {
    final result = await _setClosed(
      SetStationClosedParams(stationId: station.stationId, closed: closed),
    );
    return result.fold(
      onSuccess: (updated) {
        _apply([
          for (final row in statuses)
            row.stationId == updated.stationId ? updated : row,
        ]);
        return true;
      },
      onFailure: (failure) {
        errorMessage.value = failure.message;
        return false;
      },
    );
  }

  void _apply(List<StationStatus> rows) {
    errorMessage.value = null;
    statuses.assignAll(rows);
    final ids = {for (final row in rows) if (row.isClosed) row.stationId};
    final previous = _lastClosedIds;
    _lastClosedIds = ids;
    if (previous != null && !setEquals(previous, ids)) closedVersion.value++;
  }
}
```

- [ ] **Step 4: Run the controller test**

Run: `cd app && flutter test test/presentation/station_status_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Translations** — add to `kitchen_translations.dart` (th / en / ko):

```dart
  // th
  'station_status_button': 'สถานะสถานี',
  'station_status_title': 'เปิด/ปิดสถานีครัว',
  'station_status_subtitle': 'สถานีที่ปิด จานของสถานีนั้นสั่งไม่ได้จนกว่าจะเปิดคืน (เฉพาะสาขานี้)',
  'station_status_open': 'เปิดอยู่',
  'station_status_closed_by': 'ปิดตั้งแต่ @time โดย @name',
  'station_status_confirm_title': 'ปิด@station?',
  'station_status_confirm_pending': 'ยังมี @count รายการค้าง — ครัวทำต่อจนเสร็จ แต่จะสั่งเพิ่มไม่ได้',
  'station_status_confirm_button': 'ปิดสถานี',
  'station_closed_banner': '@station ปิดตั้งแต่ @time โดย @name',
  // en
  'station_status_button': 'Station status',
  'station_status_title': 'Open/close kitchen stations',
  'station_status_subtitle': "A closed station's dishes can't be ordered until it reopens (this branch only)",
  'station_status_open': 'Open',
  'station_status_closed_by': 'Closed since @time by @name',
  'station_status_confirm_title': 'Close @station?',
  'station_status_confirm_pending': "@count tickets are still in the queue — the kitchen finishes them, but nothing new can be ordered",
  'station_status_confirm_button': 'Close station',
  'station_closed_banner': '@station closed since @time by @name',
  // ko
  'station_status_button': '스테이션 상태',
  'station_status_title': '주방 스테이션 열기/닫기',
  'station_status_subtitle': '닫힌 스테이션의 메뉴는 다시 열 때까지 주문할 수 없습니다 (이 지점만)',
  'station_status_open': '열림',
  'station_status_closed_by': '@time부터 닫힘 · @name',
  'station_status_confirm_title': '@station을(를) 닫을까요?',
  'station_status_confirm_pending': '대기 중인 항목이 @count개 있습니다 — 주방은 마저 만들지만 새로 주문할 수 없습니다',
  'station_status_confirm_button': '스테이션 닫기',
  'station_closed_banner': '@station 닫힘 · @time부터 · @name',
```

(Thai `ปิด@station?` has no space by Thai convention — the station name follows the verb directly.)

- [ ] **Step 6: Sheet and banner widgets**

`station_status_sheet.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../menu/domain/entities/station_status.dart';
import '../controllers/station_status_controller.dart';

/// ชีตเปิด/ปิดสถานีครัวของสาขานี้ (ticket 36) — ใช้ทั้งจอครัวและหน้าสั่งอาหาร (ผู้จัดการ)
/// ชิปสถานีบนจอครัวใช้กรองอย่างเดียว ไม่ใช่สวิตช์ — แยกมาไว้ที่นี่กันแตะผิด
class StationStatusSheet extends GetView<StationStatusController> {
  const StationStatusSheet({super.key});

  static Future<void> show() {
    Get.find<StationStatusController>().load();
    return Get.bottomSheet<void>(
      const StationStatusSheet(),
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'station_status_title'.tr,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'station_status_subtitle'.tr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final station in controller.statuses)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(station.labelWithIcon),
                  subtitle: Text(
                    station.isClosed
                        ? 'station_status_closed_by'.trParams({
                            'time': Formatters.dateTime(station.closedAt),
                            'name': station.closedByName ?? '-',
                          })
                        : 'station_status_open'.tr,
                  ),
                  // สวิตช์ "เปิด" = สถานีเปิดรับออเดอร์
                  value: !station.isClosed,
                  onChanged: (open) => _toggle(station, open),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(StationStatus station, bool open) async {
    if (!open && station.pendingCount > 0) {
      final confirmed = await AppDialogs.confirm(
        title: 'station_status_confirm_title'.trParams({
          'station': station.displayName,
        }),
        message: 'station_status_confirm_pending'.trParams({
          'count': '${station.pendingCount}',
        }),
        confirmLabel: 'station_status_confirm_button'.tr,
        destructive: true,
      );
      if (!confirmed) return;
    }
    final ok = await controller.setClosed(station, !open);
    if (!ok) AppDialogs.error(controller.errorMessage.value ?? '');
  }
}
```

Check `AppDialogs.confirm`'s parameters (`grep -n "static Future<bool> confirm" -A10 app/lib/core/widgets/app_dialogs.dart`); `cancelLabel` is optional in the order page usage.

`station_closed_banner.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../controllers/station_status_controller.dart';

/// แถบเฉพาะพนักงาน: สถานีไหนปิดอยู่ ตั้งแต่เมื่อไหร่ ใครปิด (ticket 36)
/// ไม่มีการเปิดคืนอัตโนมัติ แถบนี้จึงเป็นตัวกันลืม — ลูกค้า QR ไม่เห็น
class StationClosedBanner extends GetView<StationStatusController> {
  const StationClosedBanner({super.key, this.onTap});

  /// แตะแถบเพื่อเปิดชีตสถานะ — null สำหรับบทบาทที่เปิด/ปิดไม่ได้
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final closed = controller.closed;
      if (closed.isEmpty) return const SizedBox.shrink();
      return Material(
        color: AppColors.warning.withValues(alpha: 0.14),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.do_not_disturb_on_rounded, size: 18, color: AppColors.warningInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final station in closed)
                        Text(
                          'station_closed_banner'.trParams({
                            'station': station.displayName,
                            'time': Formatters.dateTime(station.closedAt),
                            'name': station.closedByName ?? '-',
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningInk,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
```

- [ ] **Step 7: Widget test (360px)** — `app/test/widget/station_status_sheet_test.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/network/socket_client.dart';
import 'package:payneat_pos/core/services/session_service.dart';
import 'package:payneat_pos/core/services/storage_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/kitchen/presentation/controllers/station_status_controller.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/station_closed_banner.dart';
import 'package:payneat_pos/features/kitchen/presentation/widgets/station_status_sheet.dart';
import 'package:payneat_pos/features/menu/domain/entities/station_status.dart';
import 'package:payneat_pos/features/menu/domain/repositories/menu_repository.dart';
import 'package:payneat_pos/features/menu/domain/usecases/menu_usecases.dart';

class _FakeMenuRepository implements MenuRepository {
  final calls = <String>[];

  @override
  Future<Result<StationStatus>> setStationClosed(
    int stationId, {
    required bool closed,
  }) async {
    calls.add('$stationId:$closed');
    return Result.success(
      StationStatus(stationId: stationId, code: 'hot', name: 'ครัวร้อน', isClosed: closed),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeMenuRepository repository;
  late StationStatusController controller;

  setUp(() {
    repository = _FakeMenuRepository();
    controller = StationStatusController(
      getStatuses: GetStationStatusesUseCase(repository),
      setClosed: SetStationClosedUseCase(repository),
      session: SessionService(storage: StorageService.memory(), socket: SocketClient()),
    );
    Get.put<StationStatusController>(controller);
  });

  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('แบนเนอร์ว่างเมื่อไม่มีสถานีปิด และขึ้นชื่อสถานี/คนปิดเมื่อมี — ไม่ล้นที่ 360px', (
    tester,
  ) async {
    await pump(tester, const StationClosedBanner());
    expect(find.byType(Text), findsNothing);

    controller.statuses.assignAll(const [
      StationStatus(
        stationId: 3,
        code: 'bar',
        name: 'บาร์เครื่องดื่มและของหวานชื่อยาวมาก',
        isClosed: true,
        closedAt: '2026-10-08 14:03:00',
        closedByName: 'สมชาย (ผู้จัดการ)',
      ),
    ]);
    await tester.pump();
    expect(find.textContaining('บาร์เครื่องดื่ม'), findsOneWidget);
    expect(find.textContaining('สมชาย'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ชีต: สวิตช์ปิดสถานีที่ไม่มีรายการค้าง → ปิดทันทีโดยไม่ถาม', (tester) async {
    controller.statuses.assignAll(const [
      StationStatus(stationId: 1, code: 'hot', name: 'ครัวร้อน'),
    ]);
    await pump(tester, const StationStatusSheet());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repository.calls, ['1:true']);
    expect(controller.closed.single.stationId, 1);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 8: Run widget + analyzer**

Run: `cd app && flutter test test/widget/station_status_sheet_test.dart test/presentation/station_status_controller_test.dart && flutter analyze`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/kitchen app/lib/core/localization app/test
git commit -m "feat(app): station status sheet and closed-station banner"
```

---

### Task 7: Wire into the kitchen screen and the staff order screen

**Files:**
- Modify: `app/lib/features/home/presentation/bindings/home_binding.dart`, `app/lib/features/kitchen/presentation/pages/kitchen_page.dart`
- Modify: `app/lib/features/order/presentation/bindings/order_bindings.dart`, `app/lib/features/order/presentation/pages/order_taking_page.dart`
- Modify: `app/lib/features/menu/presentation/controllers/menu_controller.dart`, `app/lib/features/menu/presentation/widgets/menu_item_card.dart`
- Modify: `app/lib/core/constants/app_constants.dart` (`UserRole.canToggleStations`), `app/lib/core/localization/translations/menu_translations.dart`
- Note: `StationStatusController.canUse` is false in admin "all branches" mode — `StationClosedBanner` then stays empty because `statuses` never loads; no extra handling needed.
- Test: `app/test/presentation/menu_browse_controller_test.dart`, `app/test/widget/menu_item_card_closed_test.dart` (new)

**Interfaces:**
- Consumes: `StationStatusController`, `StationStatusSheet.show()`, `StationClosedBanner`, `MenuItem.closedStation` / `isOrderable`.
- Produces: `MenuBrowseController({..., StationStatusController? stationStatus})` reloads silently when `closedVersion` changes; `MenuBrowseController.load({bool showLoader = true})`; `UserRole.canToggleStations(String role)` (admin, manager, kitchen).

- [ ] **Step 1: Write the failing tests**

Append to `app/test/presentation/menu_browse_controller_test.dart` (reuse the file's fake menu repository; if it has none for statuses, add `getStationStatuses` returning a mutable list to its fake):

```dart
  test('ชุดสถานีที่ปิดเปลี่ยน → โหลดเมนูใหม่แบบไม่ขึ้น loader (ticket 36)', () async {
    final status = StationStatusController(
      getStatuses: GetStationStatusesUseCase(repository),
      setClosed: SetStationClosedUseCase(repository),
      session: SessionService(storage: StorageService.memory(), socket: SocketClient()),
    );
    final browse = MenuBrowseController(
      getMenuItems: GetMenuItemsUseCase(repository),
      getCategories: GetCategoriesUseCase(repository),
      stationStatus: status,
    )..onInit();
    await Future<void>.delayed(Duration.zero);
    final loadsBefore = repository.menuLoads;

    status.closedVersion.value++;
    await Future<void>.delayed(Duration.zero);

    expect(repository.menuLoads, loadsBefore + 1);
    expect(browse.isLoading.value, isFalse);
    browse.onClose();
  });
```

(`repository.menuLoads` = counter incremented in the fake's `getMenuItems`; add it if missing.)

Create `app/test/widget/menu_item_card_closed_test.dart`:

```dart
// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/features/menu/domain/entities/closed_station.dart';
import 'package:payneat_pos/features/menu/domain/entities/menu_item.dart';
import 'package:payneat_pos/features/menu/presentation/widgets/menu_item_card.dart';

void main() {
  testWidgets('จานของสถานีที่ปิด → ป้าย "บาร์ปิด" และแตะไม่ได้ (ticket 36)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: LocaleService.thai,
        home: Scaffold(
          body: SizedBox(
            width: 165,
            height: 190,
            child: MenuItemCard(
              item: const MenuItem(
                id: 1,
                categoryId: 1,
                name: 'ชาไทยเย็น',
                price: 45,
                closedStation: ClosedStation(id: 3, name: 'บาร์'),
              ),
              showAvailabilityBadge: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('บาร์ปิด'), findsOneWidget);
    await tester.tap(find.byType(MenuItemCard));
    expect(taps, 0);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd app && flutter test test/presentation/menu_browse_controller_test.dart test/widget/menu_item_card_closed_test.dart`
Expected: compile errors (`stationStatus` param missing) / badge not found.

- [ ] **Step 3: Menu card** — in `menu_item_card.dart`:

```dart
    // จานที่สั่งไม่ได้ตอนนี้: ปิดขาย หรือสถานีของจานปิดอยู่ (ticket 36)
    final disabled = !item.isOrderable;
    final badge = item.closedStation != null
        ? 'menu_station_closed_badge'.trParams({
            'station': item.closedStation!.displayName,
          })
        : 'menu_sold_out_badge'.tr;
```

and replace the overlay text `'menu_sold_out_badge'.tr` with `badge` (add `textAlign: TextAlign.center` and `maxLines: 2` on that `Text` so long station names wrap inside 165px tiles).

`menu_translations.dart` (th/en/ko):

```dart
  'menu_station_closed_badge': '@stationปิด',
  'menu_station_closed_badge': '@station closed',
  'menu_station_closed_badge': '@station 닫힘',
```

- [ ] **Step 4: Menu browse controller** — in `menu_controller.dart`:

```dart
  MenuBrowseController({
    required GetMenuItemsUseCase getMenuItems,
    required GetCategoriesUseCase getCategories,
    this.availableOnly = true,
    StationStatusController? stationStatus,
  }) : _getMenuItems = getMenuItems,
       _getCategories = getCategories,
       _stationStatus = stationStatus;

  final StationStatusController? _stationStatus;
  Worker? _stationWorker;

  @override
  void onInit() {
    super.onInit();
    load();
    // สถานีปิด/เปิดระหว่างที่หน้าสั่งอาหารเปิดอยู่ (ticket 36) — โหลดเมนูใหม่เงียบ ๆ ให้การ์ดเทา/หายเทา
    final status = _stationStatus;
    if (status != null) {
      _stationWorker = ever<int>(status.closedVersion, (_) => load(showLoader: false));
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _stationWorker?.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) isLoading.value = true;
    // ...rest unchanged
```

Import `../../../kitchen/presentation/controllers/station_status_controller.dart`.

- [ ] **Step 5: Role helper** — in `UserRole` (`app_constants.dart`):

```dart
  /// เปิด/ปิดสถานีครัวรายสาขาได้ (ticket 36) — mirror ของ authorize('admin', 'manager', 'kitchen')
  static bool canToggleStations(String role) =>
      role == admin || role == manager || role == kitchen;
```

- [ ] **Step 6: Bindings**

`home_binding.dart` — register once for the kitchen page (next to `KitchenController`):

```dart
    Get.lazyPut(
      () => StationStatusController(
        getStatuses: Get.find<GetStationStatusesUseCase>(),
        setClosed: Get.find<SetStationClosedUseCase>(),
        session: Get.find<SessionService>(),
      ),
      fenix: true,
    );
```

`order_bindings.dart` `OrderTakingBinding.dependencies()` — put the status controller first (every role may read `/status`) and pass it to the menu controller:

```dart
    final stationStatus = Get.put(
      StationStatusController(
        getStatuses: Get.find<GetStationStatusesUseCase>(),
        setClosed: Get.find<SetStationClosedUseCase>(),
        session: Get.find<SessionService>(),
      ),
    );
    Get.put(
      MenuBrowseController(
        getMenuItems: Get.find<GetMenuItemsUseCase>(),
        getCategories: Get.find<GetCategoriesUseCase>(),
        stationStatus: stationStatus,
      ),
    );
```

- [ ] **Step 7: Order taking page** — add a getter on `OrderTakingPage`:

```dart
  /// เปิด/ปิดสถานีได้จากหน้านี้เฉพาะผู้จัดการ/แอดมิน (ครัวไม่ได้ใช้หน้านี้) — ticket 36
  bool get canToggleStations => UserRole.canToggleStations(
    Get.find<SessionService>().currentUser?.role ?? '',
  );
```

In `_buildScaffold`, wrap the body so the banner sits above the menu and cart on every layout:

```dart
      body: Column(
        children: [
          // แบนเนอร์เฉพาะพนักงาน (ticket 36) — ลูกค้า QR ไม่เห็น; ผู้จัดการแตะเพื่อเปิดชีต
          StationClosedBanner(
            onTap: canToggleStations ? StationStatusSheet.show : null,
          ),
          Expanded(
            child: isWide
                ? Row(/* existing wide Row unchanged */)
                : const _MenuSection(),
          ),
        ],
      ),
```

and in `AppBar.actions`, before the cart button:

```dart
          if (canToggleStations)
            IconButton(
              tooltip: 'station_status_button'.tr,
              onPressed: StationStatusSheet.show,
              icon: const Icon(Icons.storefront_outlined),
            ),
```

- [ ] **Step 8: Kitchen page** — in `kitchen_page.dart`:

- In `KitchenPage.build`, between `const StationFilterBar()` and `const _OfflineBanner()` add:

```dart
        StationClosedBanner(onTap: StationStatusSheet.show),
```

- In `_KitchenHeader`, before the refresh `IconButton`, add:

```dart
            IconButton(
              tooltip: 'station_status_button'.tr,
              onPressed: StationStatusSheet.show,
              icon: const Icon(Icons.storefront_outlined),
            ),
```

- `KitchenPage` must make sure the controller exists: at the top of `build`, `Get.find<StationStatusController>();` is resolved lazily by `GetView` children; to start the socket listener and first load when the page opens, call it once in `build` — replace the first line of `build` with:

```dart
    // ให้ StationStatusController ถูกสร้าง (onInit โหลดสถานะและฟัง event) ตั้งแต่เปิดจอครัว
    Get.find<StationStatusController>();
```

The kitchen screen is only reachable by kitchen/manager/admin, all of whom may call `/status`.

- [ ] **Step 9: Run app tests + analyzer + 360px check**

Run: `cd app && flutter test && flutter analyze && dart format --set-exit-if-changed .`
Expected: all PASS. The existing `kitchen_station_filter_test.dart` 360px header test must still pass with the extra icon button — if the header overflows, move the station-status `IconButton` into the existing `Wrap` instead of the `Row`.

- [ ] **Step 10: Manual browser check (agent-browser)**

Start backend (`cd backend && DATABASE_FILE=data/t36.sqlite npm run dev`) and the web app (`cd app && flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3001`). With `/agent-browser` (claude-in-chrome as fallback): log in as `kitchen`, open the station sheet, close Bar → banner appears; log in as `waiter1` in a second session, open order taking → Bar dishes greyed with "บาร์ปิด", banner "บาร์ปิดตั้งแต่ … โดย เชฟต้น", no station-status button; open the table's QR URL → Bar dishes absent; reopen Bar as `manager` from the order screen's sheet → waiter screen un-greys without refresh. Repeat at 360px width.

- [ ] **Step 11: Commit**

```bash
git add app
git commit -m "feat(app): close stations from the kitchen and order screens"
```

---

### Task 8: Docs, counts, full verification

**Files:**
- Modify: `README.md`, `README.en.md`, `README.ko.md`, `docs/DECISIONS.md`, `docs/FEATURE-GAP-ANALYSIS.md`, `docs/tickets/36-station-open-close.md`, `docs/tickets/README.md`, `CONTEXT.md` (only if a term changed)

- [ ] **Step 1: Run every gate and record real test counts**

```bash
cd backend && npm run format:check && npm run lint && npm test
cd ../app && dart format --set-exit-if-changed . && flutter analyze && flutter test
cd .. && node scripts/license-headers.mjs
```

Note the exact pass counts printed by `npm test` and `flutter test`.

- [ ] **Step 2: README (th/en/ko, kept in sync)**

- Test-count badge + "🧪 การทดสอบ" section: real numbers from Step 1; add a sentence for `station-closures.test.js`, `station_status_controller_test.dart`, `station_status_sheet_test.dart`, `menu_item_card_closed_test.dart`.
- "🗺 ทัวร์ 5 นาที" → "กฎทางธุรกิจที่ทดลองได้": add a step — "จอครัว → ปุ่มสถานะสถานี → ปิดบาร์ → หน้าสั่งอาหารเห็นเมนูบาร์เป็นสีเทา 'บาร์ปิด', เมนู QR ไม่มีเครื่องดื่ม, เปิดคืนแล้วกลับมาทันที".
- "✨ ฟีเจอร์": ครัว — ปิด/เปิดสถานีรายสาขา; ผู้ดูแลระบบ — เปิด/ปิดสถานีจากหน้าสั่งอาหาร; ระบบ — จานของสถานีที่ปิดสั่งไม่ได้ทุกช่องทาง ไม่แตะสถานะปิดขาย.
- "🔭 สิ่งที่จะทำต่อ": tick ticket 36 with a one-line summary.

- [ ] **Step 3: DECISIONS #102** — append to `docs/DECISIONS.md` (number 102; #101 lives on the unmerged `perf/menu-images-and-db-stats` branch). Title: `## 102. ปิด/เปิดสถานีครัวรายสาขา: สถานะปิดแยกจาก "ปิดใช้งาน", "สั่งได้" คำนวณตอนอ่าน, ไม่ถอยไปสถานีอื่น (ticket 36, 2026-10-08)`. Sections บริบท / ที่เลือก / ไม่ทำ / ข้อเสียที่ยอมรับ, covering: per-(branch, station) table with row = closed; not touching `is_available`; 409 on all order paths including `sendToKitchen` for unsent bills; no fallback station; inactive station overrides a leftover closure; `/status` readable by every role (staff banner) while close/open is kitchen/manager/admin; socket event not branch-routed (clients reload their own branch); manual reopen only (banner as the guard). Ticket 37 will add its own section to #102 or take #103 — leave a one-line note.

- [ ] **Step 4: FEATURE-GAP-ANALYSIS + tickets** — add/update the kitchen-station line in `docs/FEATURE-GAP-ANALYSIS.md`; set ticket 36 status to ✅ with a pointer to DECISIONS #102 and tick its acceptance criteria; update the ticket 36 line in `docs/tickets/README.md` to ✅.

- [ ] **Step 5: Commit**

```bash
git add README.md README.en.md README.ko.md docs CONTEXT.md
git commit -m "docs: station open/close (ticket 36, DECISIONS #102)"
```
