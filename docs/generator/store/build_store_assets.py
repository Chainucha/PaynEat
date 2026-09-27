#!/usr/bin/env python3
# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
#
# ภาพสำหรับหน้า Google Play และไอคอนแอป Android (ticket 29a, docs/store/README.md, DECISIONS #75)
#
#   python3 docs/generator/store/build_store_assets.py
#
# - ไอคอนแอป: วาดโลโก้ PaynEat (ชุดเดียวกับ favicon ของ landing) เป็น mipmap-*/ic_launcher.png สำหรับ Android รุ่นเก่า
#   ส่วน Android 8+ ใช้ adaptive icon แบบ vector (res/mipmap-anydpi-v26, res/drawable/ic_launcher_foreground.xml)
# - ภาพหน้า store: ไอคอน 512, feature graphic 1024x500 และภาพหน้าจอมือถือ 1080x1920 / แท็บเล็ต 1920x1080 พร้อมคำบรรยาย
#   ทุกภาพหน้าจอมาจาก golden test ที่มีอยู่แล้วใน docs/screenshots (app/tool/screenshots) ไม่ถ่ายใหม่ด้วยมือ
#   ต้องการภาพใหม่ → รันตัวถ่ายภาพหน้าจอก่อน แล้วรันสคริปต์นี้ซ้ำ
#
# ใช้ Pillow ที่มี raqm (จัดสระ/วรรณยุกต์ไทยให้ถูกตำแหน่ง) และฟอนต์ Noto Sans Thai ที่ฝังในแอปอยู่แล้ว (มีตัวละตินในตัว)
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, features

ROOT = Path(__file__).resolve().parents[3]
SHOTS = ROOT / 'docs' / 'screenshots'
OUT = ROOT / 'docs' / 'store' / 'assets'
RES = ROOT / 'app' / 'android' / 'app' / 'src' / 'main' / 'res'
FONTS = ROOT / 'app' / 'assets' / 'fonts'

BRAND = (255, 107, 44)
INK = (42, 26, 16)
INK_2 = (84, 57, 42)
CREAM = (255, 248, 240)
ESPRESSO = (31, 19, 12)
MUSTARD = (255, 197, 61)
LINE = (240, 223, 206)

# โลโก้ใน viewBox 24x24 (ตรงกับ LOGO ใน docs/generator/landing/build_landing.py)
LOGO_RADIUS = 6 / 24


def font(weight, size):
    return ImageFont.truetype(str(FONTS / f'NotoSansThai-{weight}.ttf'), size)


def draw_p(draw, ox, oy, unit):
    """ตัว P สีขาวของโลโก้ — แท่งตั้ง (rect 5.6,3.6 3.8x16.8 rx 1.9) + ชามครึ่งวงกลม (path M7.8 3.6h4.6a5.6 5.6 …)"""
    def x(v):
        return ox + v * unit

    def y(v):
        return oy + v * unit

    draw.rounded_rectangle((x(5.6), y(3.6), x(9.4), y(20.4)), radius=1.9 * unit, fill='white')
    draw.rectangle((x(7.8), y(3.6), x(12.4), y(14.8)), fill='white')
    draw.pieslice((x(12.4 - 5.6), y(3.6), x(12.4 + 5.6), y(14.8)), start=-90, end=90, fill='white')


def logo(size, full_bleed=False):
    """โลโก้ขนาด size×size วาดที่ 4 เท่าแล้วย่อให้ขอบเนียน — full_bleed = พื้นส้มเต็มกรอบ (ไอคอน Play ใส่มุมมนเอง)"""
    scale = 4
    big = size * scale
    im = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    if full_bleed:
        draw.rectangle((0, 0, big, big), fill=BRAND)
    else:
        draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=big * LOGO_RADIUS, fill=BRAND)
    draw_p(draw, 0, 0, big / 24)
    return im.resize((size, size), Image.LANCZOS)


def launcher_icons():
    # ไอคอนแบบเดิม (ก่อน Android 8) — กรอบ 48dp มีขอบใส 2dp ตามแนวทาง Material
    for density, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        inner = round(px * 44 / 48)
        offset = (px - inner) // 2
        canvas.alpha_composite(logo(inner), (offset, offset))
        canvas.save(RES / f'mipmap-{density}' / 'ic_launcher.png', optimize=True)


def fit(draw, text, fnt, limit):
    """ความกว้างของข้อความ — ยาวเกินที่ว่างให้หยุดพร้อมบอกว่าข้อความไหน แทนที่จะได้ภาพที่ตัวหนังสือทับกัน"""
    width = draw.textlength(text, font=fnt)
    if width > limit:
        raise SystemExit(f'ข้อความยาวเกินที่ว่าง ({width:.0f} > {limit:.0f} px): {text}')
    return width


def text_center(draw, cx, top, text, fnt, fill, limit):
    width = fit(draw, text, fnt, limit)
    draw.text((cx - width / 2, top), text, font=fnt, fill=fill)


def rounded(im, radius):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=radius, fill=255)
    out = im.convert('RGBA')
    out.putalpha(mask)
    return out


def device(shot, height, bezel, radius):
    """ภาพหน้าจอในกรอบเครื่องสีเข้ม มุมมน — คืนภาพ RGBA และเงา"""
    src = Image.open(SHOTS / f'{shot}.png').convert('RGB')
    width = round(src.width * height / src.height)
    screen = rounded(src.resize((width, height), Image.LANCZOS), max(radius - bezel, 8))
    frame = Image.new('RGBA', (width + 2 * bezel, height + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), radius=radius, fill=ESPRESSO)
    frame.alpha_composite(screen, (bezel, bezel))
    shadow = Image.new('RGBA', (frame.width + 120, frame.height + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((60, 76, 60 + frame.width, 76 + frame.height), radius=radius,
                                             fill=(74, 33, 10, 90))
    return frame, shadow.filter(ImageFilter.GaussianBlur(28))


def captioned(size, shot, title, sub, screen_height, bezel, radius, top, title_size, sub_size):
    w, h = size
    canvas = Image.new('RGBA', size, CREAM + (255,))
    glow = Image.new('RGBA', size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((w * 0.55, -h * 0.25, w * 1.35, h * 0.3), fill=MUSTARD + (70,))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))
    draw = ImageDraw.Draw(canvas)
    text_center(draw, w / 2, top, title, font(800, title_size), INK, w * 0.9)
    text_center(draw, w / 2, top + title_size * 1.45, sub, font(500, sub_size), INK_2, w * 0.9)
    frame, shadow = device(shot, screen_height, bezel, radius)
    x = (w - frame.width) // 2
    y = h - frame.height - round(h * 0.03)
    canvas.alpha_composite(shadow, (x - 60, y - 60))
    canvas.alpha_composite(frame, (x, y))
    return canvas.convert('RGB')


def feature_graphic(lang):
    w, h = 1024, 500
    canvas = Image.new('RGBA', (w, h), ESPRESSO + (255,))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((520, -160, 1180, 520), fill=BRAND + (110,))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(110)))
    draw = ImageDraw.Draw(canvas)
    frame, shadow = device(lang['feature_shot'], 440, 10, 34)
    x = w - frame.width - 96
    limit = x - 64 - 32
    canvas.alpha_composite(logo(64), (64, 70))
    draw.text((146, 76), 'PaynEat POS', font=font(800, 40), fill='white')
    line1, line2, sub = lang['feature']
    for text, size, top, fill in ((line1, 58, 172, 'white'), (line2, 58, 248, BRAND), (sub, 26, 350, (217, 196, 180))):
        fit(draw, text, font(800 if size > 30 else 500, size), limit)
        draw.text((64, top), text, font=font(800 if size > 30 else 500, size), fill=fill)
    canvas.alpha_composite(shadow, (x - 60, 30 - 60))
    canvas.alpha_composite(frame, (x, 30))
    return canvas.convert('RGB')


LANGS = {
    'th': {
        'feature': ('ระบบขายหน้าร้าน', 'สำหรับร้านอาหาร', 'ฟรีทุกฟีเจอร์ · โอเพนซอร์ส · มือถือและแท็บเล็ต'),
        'feature_shot': 'phone-02-tables',
        'phone': [
            ('phone-02-tables', 'เห็นทุกโต๊ะในจอเดียว', 'โต๊ะว่าง มีลูกค้า ยอดค้าง บอกด้วยสี'),
            ('phone-03-order-taking', 'รับออเดอร์ที่โต๊ะ', 'ส่งเข้าครัวทันที ไม่ต้องเดินไปบอก'),
            ('phone-08-kitchen', 'ครัวเห็นคิวตามลำดับ', 'ออเดอร์ที่รอนานขึ้นเตือนให้เห็น'),
            ('phone-09-checkout', 'เก็บเงินไม่ต้องคิดเลข', 'ระบบคิดเงินทอนให้ รับได้หลายช่องทาง'),
            ('phone-34-promptpay-qr', 'QR พร้อมเพย์ยอดตรงบิล', 'ลูกค้าสแกนจ่าย ไม่ต้องพิมพ์ยอดเอง'),
            ('phone-10-receipt', 'ใบเสร็จครบทุกบรรทัด', 'ส่วนลด ค่าบริการ และ VAT แยกให้ชัด'),
        ],
        'tablet': [
            ('tablet-12-tables', 'ผังโต๊ะทั้งร้านบนแท็บเล็ต', 'แบ่งโซน เห็นยอดค้างของแต่ละโต๊ะ'),
            ('tablet-14-kitchen', 'จอครัวบนแท็บเล็ตเครื่องไหนก็ได้', 'รอทำ กำลังทำ พร้อมเสิร์ฟ แยกคอลัมน์'),
            ('tablet-26-kitchen-high-contrast', 'โหมดคอนทราสต์สูง', 'อ่านชัดใต้แสงจ้าในครัว'),
            ('tablet-16-checkout', 'จุดเก็บเงินบนแท็บเล็ต', 'เงินสด พร้อมเพย์ บัตร หรือโอน'),
        ],
    },
    'en': {
        'feature': ('Point of sale', 'for restaurants', 'Free · open source · phones and tablets'),
        'feature_shot': 'en-50-phone-tables',
        'phone': [
            ('en-50-phone-tables', 'Every table at a glance', 'Free, seated and unpaid tables by colour'),
            ('en-51-phone-option-sheet', 'Options priced for you', 'Spice level, add-ons and notes to the kitchen'),
            ('en-52-phone-takeaway-order', 'Takeaway and delivery', 'Queue numbers, straight to the kitchen'),
            ('en-53-phone-takeaway-detail', 'Follow every order', 'See when the kitchen starts cooking'),
            ('en-54-phone-checkout', 'Change worked out', 'Cash, PromptPay QR, card or transfer'),
        ],
        'tablet': [
            ('en-55-tablet-kitchen', 'A kitchen screen on any tablet', 'Pending, cooking and ready in columns'),
            ('en-56-tablet-kitchen-high-contrast', 'High-contrast mode', 'Readable under harsh kitchen lights'),
            ('en-57-tablet-checkout', 'A checkout counter on a tablet', 'Cash, PromptPay QR, card or transfer'),
        ],
    },
}


def main():
    if not features.check('raqm'):
        raise SystemExit('Pillow ไม่มี raqm — สระและวรรณยุกต์ไทยจะวางผิดที่ ติดตั้ง libraqm แล้วลองใหม่')
    launcher_icons()
    print('app/android/app/src/main/res/mipmap-*/ic_launcher.png')
    OUT.mkdir(parents=True, exist_ok=True)
    logo(512, full_bleed=True).convert('RGB').save(OUT / 'icon-512.png', optimize=True)
    for code, lang in LANGS.items():
        folder = OUT / code
        folder.mkdir(exist_ok=True)
        feature_graphic(lang).save(folder / 'feature-graphic.png', optimize=True)
        for i, (shot, title, sub) in enumerate(lang['phone'], start=1):
            im = captioned((1080, 1920), shot, title, sub, 1500, 14, 64, 118, 72, 40)
            im.save(folder / f'phone-{i}.png', optimize=True)
        for i, (shot, title, sub) in enumerate(lang['tablet'], start=1):
            im = captioned((1920, 1080), shot, title, sub, 850, 14, 34, 40, 56, 30)
            im.save(folder / f'tablet-{i}.png', optimize=True)
        print(f"docs/store/assets/{code}/  feature graphic + {len(lang['phone'])} phone + {len(lang['tablet'])} tablet")


if __name__ == '__main__':
    main()
