# PaynEat POS

Restaurant point-of-sale for single shops and multi-branch chains: staff and QR self-ordering, kitchen display,
cashier, back office.

## Language

### Kitchen

**Kitchen station** (สถานีครัว):
A part of the kitchen that cooks a subset of the menu and has its own kitchen screen, e.g. Hot Kitchen, Cold
Kitchen, Bar. Defined once for the whole chain.
_Avoid_: Kitchen (when one station is meant), section, printer

**Inactive station**:
A kitchen station switched off in setup because the chain does not use it; it vanishes from menus and screens.
_Avoid_: Closed station, disabled

**Closed station** (สถานีปิด):
A kitchen station that is not taking new orders right now at one branch, e.g. the bar after 21:00. It still
exists and still finishes the tickets it already has; reopening is one tap.
_Avoid_: Inactive station, offline, paused

**Ticket arrival**:
The moment new items enter the pending queue of a kitchen station, from a new order, items added to an open
order, or a QR order. Status changes and cancellations are not arrivals.
_Avoid_: New order (an arrival may add to an existing order)

### Menu

**Orderable dish**:
A dish that can be added to an order now: it is available and its kitchen station is open at the branch.
_Avoid_: Available (that is only the dish's own on/off flag)

**Available dish**:
A dish whose own on/off flag is on, set by staff or by stock running out. Says nothing about its station.
_Avoid_: Orderable, in stock
