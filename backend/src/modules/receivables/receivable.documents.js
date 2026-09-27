// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { ApiError } from '../../core/ApiError.js';
import { renderDocumentPdf } from '../../core/documentPdf.js';
import { mailer } from '../../core/mailer.js';
import { bahtText, money, thaiDate } from '../../core/thaiFormat.js';
import { getDb } from '../../db/index.js';
import { auditLogService } from '../audit-logs/audit-log.service.js';
import { settingsService } from '../settings/settings.service.js';
import { creditNoteService } from './credit-note.service.js';
import { documentEmailRepository } from './document-email.repository.js';
import { lateFeeService } from './late-fee.service.js';
import { receivableService } from './receivable.service.js';

/**
 * เอกสารลูกหนี้เป็น PDF + ส่งอีเมล (ดู docs/tickets/23-document-pdf-email.md, docs/DECISIONS.md #57)
 *
 * แต่ละชนิดเอกสารบอกแค่ "เนื้อหา" (spec) จาก DTO ตัวเดียวกับที่แอปใช้แสดงบนจอ — ตัวเลขใน PDF จึงตรงกับจอ
 * เสมอ ส่วนหน้าตา/ตัดหน้า/ฟอนต์ไทยอยู่ที่ core/documentPdf.js ที่เดียว
 */

const METHOD_LABELS = { cash: 'เงินสด', qr: 'QR พร้อมเพย์', card: 'บัตร', transfer: 'โอนเงิน' };

const baht = (value) => `${money(value)} บาท`;

const lateFeeNote = () => {
  const { lateFeeAnnualRatePercent: rate, lateFeeGraceDays: grace } = settingsService.get();
  if (!rate) return null;
  return (
    `ชำระเกินกำหนด${grace ? ` ${grace} วัน` : ''} คิดดอกเบี้ยผิดนัดอัตรา ${rate}% ต่อปี ` +
    'นับจากวันครบกำหนด (ดอกเบี้ยธรรมดา ไม่ทบต้น)'
  );
};

const billingNoteSpec = (doc) => ({
  title: 'ใบวางบิล',
  titleEn: 'BILLING NOTE',
  number: doc.noteNo,
  meta: [
    ['วันที่ออก', thaiDate(doc.issuedAt)],
    ['นัดชำระ', thaiDate(doc.dueDate)],
    ['จำนวนบิล', `${doc.items.length} บิล`],
    ['ผู้ออก', doc.issuedByName ?? '-'],
  ],
  columns: [
    { label: '#', width: 30, align: 'center' },
    { label: 'บิลเลขที่' },
    { label: 'วันที่ขาย', width: 100 },
    { label: 'ครบกำหนด', width: 100 },
    { label: 'จำนวนเงิน (บาท)', width: 110, align: 'right' },
  ],
  rows: doc.items.map((item, index) => [
    String(index + 1),
    `#${item.orderCode}`,
    thaiDate(item.createdAt),
    thaiDate(item.dueDate),
    money(item.amount),
  ]),
  totals: [
    { label: 'ยอดวางบิล', value: baht(doc.total), strong: true },
    // PDF ที่ส่งทีหลังหลังลูกค้าจ่ายมาบางส่วน — บอกยอดที่ยังค้างจริง ณ วันพิมพ์ด้วย
    ...(doc.status === 'open' && doc.remaining !== doc.total
      ? [{ label: 'คงค้าง ณ วันพิมพ์', value: baht(doc.remaining) }]
      : []),
  ],
  amountInWords: bahtText(doc.total),
  notes: [doc.note, lateFeeNote()],
  signatures: ['ผู้วางบิล', 'ผู้รับวางบิล'],
});

const receiptSpec = (doc) => ({
  title: 'ใบเสร็จรับเงิน',
  titleEn: 'RECEIPT',
  number: doc.receiptNo,
  customerLabel: 'ได้รับเงินจาก',
  meta: [
    ['วันที่รับเงิน', thaiDate(doc.receivedAt)],
    ['ชำระโดย', METHOD_LABELS[doc.method] ?? doc.method],
    ...(doc.reference ? [['เลขอ้างอิง', doc.reference]] : []),
    ['ผู้รับเงิน', doc.receivedByName ?? '-'],
  ],
  columns: [
    { label: '#', width: 30, align: 'center' },
    { label: 'ชำระค่าบิลเลขที่' },
    { label: 'วันที่ขาย', width: 100 },
    { label: 'ครบกำหนด', width: 100 },
    { label: 'ชำระครั้งนี้ (บาท)', width: 110, align: 'right' },
  ],
  rows: doc.allocations.map((item, index) => [
    String(index + 1),
    `#${item.orderCode}`,
    thaiDate(item.createdAt),
    thaiDate(item.dueDate),
    money(item.amount),
  ]),
  totals: [{ label: 'รับชำระรวม', value: baht(doc.amount), strong: true }],
  amountInWords: bahtText(doc.amount),
  notes: [doc.note],
  signatures: ['ผู้รับเงิน'],
});

const creditNoteSpec = (doc) => ({
  title: 'ใบลดหนี้',
  titleEn: 'CREDIT NOTE',
  number: doc.noteNo,
  meta: [
    ['วันที่', thaiDate(doc.issuedAt)],
    ['อ้างถึงบิล', `#${doc.orderCode}`],
    ['วันที่บิลเดิม', thaiDate(doc.invoiceDate)],
    ...(doc.taxInvoiceNo ? [['ใบกำกับภาษีเดิม', doc.taxInvoiceNo]] : []),
  ],
  columns: [{ label: 'รายการ' }, { label: 'จำนวนเงิน (บาท)', width: 140, align: 'right' }],
  rows: [
    [`มูลค่าตามบิลเดิม #${doc.orderCode}`, money(doc.originalAmount)],
    ...(doc.previousCredited > 0 ? [['ลดหนี้ไปแล้วก่อนหน้านี้', money(doc.previousCredited)]] : []),
    ['มูลค่าที่ถูกต้อง', money(doc.correctAmount)],
    ['ผลต่าง (ลดหนี้ครั้งนี้)', money(doc.amount)],
  ],
  totals: [
    { label: 'มูลค่าก่อนภาษี', value: money(doc.baseAmount) },
    { label: 'ภาษีมูลค่าเพิ่ม', value: money(doc.vatAmount) },
    { label: 'รวมลดหนี้', value: baht(doc.amount), strong: true },
  ],
  amountInWords: bahtText(doc.amount),
  notes: [`เหตุผลที่ลดหนี้: ${doc.reason}`],
  signatures: ['ผู้ออกเอกสาร', 'ผู้รับเอกสาร'],
});

const lateFeeSpec = (doc) => ({
  title: 'ใบแจ้งดอกเบี้ยผิดนัด',
  titleEn: 'LATE PAYMENT INTEREST',
  number: doc.chargeNo,
  meta: [
    ['วันที่', thaiDate(doc.issuedAt)],
    ['อัตรา', `${doc.annualRate}% ต่อปี`],
    ['คิดถึงวันที่', thaiDate(doc.asOf)],
    ['ผู้ออก', doc.issuedByName ?? '-'],
  ],
  columns: [
    { label: 'บิลเลขที่' },
    { label: 'ครบกำหนด', width: 72 },
    { label: 'ช่วงที่คิด', width: 148 },
    { label: 'วัน', width: 32, align: 'right' },
    { label: 'เงินต้นค้าง', width: 72, align: 'right' },
    { label: 'ดอกเบี้ย', width: 62, align: 'right' },
  ],
  rows: doc.items.map((item) => [
    `#${item.orderCode}`,
    thaiDate(item.dueDate),
    `${thaiDate(item.periodFrom)} – ${thaiDate(item.periodTo)}`,
    String(item.days),
    money(item.principal),
    money(item.amount),
  ]),
  totals: [{ label: 'ดอกเบี้ยรวม', value: baht(doc.total), strong: true }],
  amountInWords: bahtText(doc.total),
  notes: [
    doc.note,
    'คำนวณแบบดอกเบี้ยธรรมดา: เงินต้นค้าง × อัตราต่อปี × จำนวนวัน ÷ 365 ' +
      'ยอดดอกเบี้ยนี้รวมอยู่ในยอดค้างชำระของแต่ละบิลแล้ว',
  ],
  signatures: ['ผู้ออกเอกสาร'],
});

const KINDS = {
  billing_note: {
    title: 'ใบวางบิล',
    load: (id) => receivableService.getBillingNote(id),
    spec: billingNoteSpec,
    summary: (doc) => `ยอด ${baht(doc.total)} กำหนดชำระ ${thaiDate(doc.dueDate)}`,
  },
  receipt: {
    title: 'ใบเสร็จรับเงิน',
    load: (id) => receivableService.getReceipt(id),
    spec: receiptSpec,
    summary: (doc) => `ยอดรับชำระ ${baht(doc.amount)} เมื่อ ${thaiDate(doc.receivedAt)}`,
  },
  credit_note: {
    title: 'ใบลดหนี้',
    load: (id) => creditNoteService.get(id),
    spec: creditNoteSpec,
    summary: (doc) => `ลดหนี้ ${baht(doc.amount)} ของบิล #${doc.orderCode}`,
  },
  late_fee: {
    title: 'ใบแจ้งดอกเบี้ยผิดนัด',
    load: (id) => lateFeeService.get(id),
    spec: lateFeeSpec,
    summary: (doc) => `ดอกเบี้ยผิดนัด ${baht(doc.total)} (${doc.annualRate}% ต่อปี)`,
  },
};

const build = async (kind, id) => {
  const definition = KINDS[kind];
  const doc = definition.load(id);
  const spec = {
    ...definition.spec(doc),
    store: doc.store,
    customer: doc.customer,
    voided: doc.isVoided ? { at: doc.voidedAt, reason: doc.voidReason } : null,
  };
  return { definition, doc, spec, pdf: await renderDocumentPdf(spec) };
};

const emailBody = ({ doc, spec, definition, message }) =>
  [
    `เรียน ${doc.customer?.name ?? 'ลูกค้า'}`,
    '',
    `${doc.store.name} ขอส่ง${definition.title}เลขที่ ${spec.number} ${definition.summary(doc)} ` +
      'รายละเอียดตามไฟล์ PDF ที่แนบมา',
    ...(message ? ['', message] : []),
    '',
    'ขอแสดงความนับถือ',
    doc.store.name,
  ].join('\n');

export const documentService = {
  /** PDF ของเอกสาร — เอกสารที่ถูกยกเลิกก็ดาวน์โหลดได้ (มีตรา "ยกเลิก") ไว้เก็บเป็นหลักฐาน */
  async pdf(kind, id) {
    const { spec, pdf } = await build(kind, id);
    return { filename: `${spec.number}.pdf`, content: pdf };
  },

  /**
   * ส่งเอกสารเป็น PDF แนบอีเมล — ผู้รับเริ่มต้นคืออีเมลของลูกค้า (ตั้งในบัญชีเครดิต) ระบุอีเมลอื่นได้
   * เช่น ฝ่ายบัญชีของลูกค้า ทุกครั้งที่ส่งถูกบันทึกประวัติ + audit log ส่งเอกสารที่ยกเลิกแล้วไม่ได้
   */
  async email(kind, id, { to, message }, user) {
    const definition = KINDS[kind];
    const current = definition.load(id);
    if (current.isVoided) {
      throw ApiError.conflict(`${definition.title}นี้ถูกยกเลิกแล้ว ส่งให้ลูกค้าไม่ได้`);
    }
    const recipient = to || current.customer?.email;
    if (!recipient) {
      throw ApiError.badRequest(
        'ลูกค้ารายนี้ยังไม่มีอีเมล — ระบุอีเมลผู้รับ หรือบันทึกอีเมลไว้ในบัญชีเครดิตของลูกค้า',
      );
    }
    // เช็คก่อนสร้าง PDF — ไม่เสียเวลาเรนเดอร์ทั้งที่ส่งไม่ได้อยู่แล้ว
    mailer.assertConfigured();

    const { doc, spec, pdf } = await build(kind, id);
    const subject = `${definition.title} ${spec.number} — ${doc.store.name}`;
    const messageId = await mailer.send({
      to: recipient,
      subject,
      text: emailBody({ doc, spec, definition, message }),
      attachments: [
        { filename: `${spec.number}.pdf`, content: pdf, contentType: 'application/pdf' },
      ],
    });

    getDb().transaction(() => {
      documentEmailRepository.record({
        kind,
        documentId: id,
        toAddress: recipient,
        subject,
        messageId,
        sentBy: user.id,
      });
      auditLogService.log({
        actorUser: user,
        action: 'receivable.document_email',
        summaryArgs: {
          document: kind,
          number: spec.number,
          customer: doc.customer?.name,
          to: recipient,
        },
        entityType: kind,
        entityId: id,
        summary: `ส่ง${definition.title} ${spec.number} ของ "${doc.customer?.name}" ทางอีเมลถึง ${recipient}`,
        metadata: { documentNo: spec.number, to: recipient },
      });
    })();
    return definition.load(id);
  },
};

export default documentService;
