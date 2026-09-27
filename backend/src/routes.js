// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Router } from 'express';
import authRoutes from './modules/auth/auth.routes.js';
import branchRoutes from './modules/branches/branch.routes.js';
import userRoutes from './modules/users/user.routes.js';
import categoryRoutes from './modules/categories/category.routes.js';
import menuRoutes from './modules/menu/menu.routes.js';
import ingredientRoutes from './modules/ingredients/ingredient.routes.js';
import tableRoutes from './modules/tables/table.routes.js';
import orderRoutes from './modules/orders/order.routes.js';
import promotionRoutes from './modules/promotions/promotion.routes.js';
import paymentRoutes from './modules/payments/payment.routes.js';
import reportRoutes from './modules/reports/report.routes.js';
import settingsRoutes from './modules/settings/settings.routes.js';
import shiftRoutes from './modules/shifts/shift.routes.js';
import taxInvoiceRoutes from './modules/tax-invoices/tax-invoice.routes.js';
import auditLogRoutes from './modules/audit-logs/audit-log.routes.js';
import customerRoutes from './modules/customers/customer.routes.js';
import aiAssistantRoutes from './modules/ai-assistant/ai-assistant.routes.js';
import publicOrderRoutes from './modules/public-order/public-order.routes.js';
import receivableRoutes from './modules/receivables/receivable.routes.js';
import scaleRoutes from './modules/scale/scale.routes.js';
import erpRoutes from './modules/erp/erp.routes.js';

const router = Router();

router.use('/auth', authRoutes);
router.use('/branches', branchRoutes);
router.use('/users', userRoutes);
router.use('/categories', categoryRoutes);
router.use('/menu-items', menuRoutes);
router.use('/ingredients', ingredientRoutes);
router.use('/tables', tableRoutes);
router.use('/orders', orderRoutes);
router.use('/promotions', promotionRoutes);
router.use('/payments', paymentRoutes);
router.use('/reports', reportRoutes);
router.use('/settings', settingsRoutes);
router.use('/shifts', shiftRoutes);
router.use('/tax-invoices', taxInvoiceRoutes);
router.use('/audit-logs', auditLogRoutes);
router.use('/customers', customerRoutes);
router.use('/ai', aiAssistantRoutes);
router.use('/public', publicOrderRoutes);
router.use('/receivables', receivableRoutes);
router.use('/scale', scaleRoutes);
router.use('/erp', erpRoutes);

export default router;
