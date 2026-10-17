// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import { Server } from 'socket.io';
import { env } from '../config/env.js';
import { verifyToken } from '../middlewares/auth.js';

export const EVENTS = {
  ORDER_CREATED: 'order:created',
  ORDER_UPDATED: 'order:updated',
  ORDER_ITEM_UPDATED: 'order_item:updated',
  ORDER_PAID: 'order:paid',
  KITCHEN_TICKET: 'kitchen:ticket',
  TABLE_UPDATED: 'table:updated',
  SHIFT_OPENED: 'shift:opened',
  SHIFT_CLOSED: 'shift:closed',
  REFUND_CREATED: 'refund:created',
  SCALE_READING: 'scale:reading',
  STATION_STATUS: 'station:status',
};

/** ห้องแยกตาม role — ครัวรับเฉพาะตั๋วครัว, พนักงานเสิร์ฟรับสถานะอาหาร */
export const ROOMS = {
  KITCHEN: 'room:kitchen',
  SERVICE: 'room:service',
  MANAGEMENT: 'room:management',
};

let io = null;

const roomsForRole = (role) => {
  switch (role) {
    case 'kitchen':
      return [ROOMS.KITCHEN];
    case 'waiter':
      return [ROOMS.SERVICE];
    case 'cashier':
      return [ROOMS.SERVICE, ROOMS.MANAGEMENT];
    case 'admin':
    case 'manager':
      return [ROOMS.KITCHEN, ROOMS.SERVICE, ROOMS.MANAGEMENT];
    default:
      return [];
  }
};

export const initSocket = (httpServer) => {
  io = new Server(httpServer, {
    cors: { origin: env.corsOrigin, credentials: true },
  });

  // ใช้ JWT ตัวเดียวกับ REST API — ส่งมาที่ handshake.auth.token
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token ?? socket.handshake.query?.token;
    if (!token) return next(new Error('ไม่พบ access token'));
    try {
      const payload = verifyToken(token);
      socket.data.user = { id: payload.sub, role: payload.role, name: payload.name };
      return next();
    } catch {
      return next(new Error('Token ไม่ถูกต้องหรือหมดอายุ'));
    }
  });

  io.on('connection', (socket) => {
    const { user } = socket.data;
    for (const room of roomsForRole(user.role)) socket.join(room);
    socket.emit('connected', {
      message: `เชื่อมต่อสำเร็จ (${user.name})`,
      rooms: roomsForRole(user.role),
    });
  });

  return io;
};

/**
 * ส่ง event ออกไปยัง client
 * @param {string} event ชื่อ event จาก EVENTS
 * @param {unknown} payload ข้อมูล
 * @param {string[]} [rooms] ถ้าไม่ระบุจะ broadcast ให้ทุกคน
 */
export const emit = (event, payload, rooms) => {
  if (!io) return;
  if (rooms?.length) {
    io.to(rooms).emit(event, payload);
    return;
  }
  io.emit(event, payload);
};

export const getIo = () => io;

export const closeSocket = () => {
  if (io) {
    io.close();
    io = null;
  }
};
