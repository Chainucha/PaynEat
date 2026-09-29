#!/usr/bin/env python3
# Copyright 2026 Suruch Chakrapeesirisuk
# SPDX-License-Identifier: Apache-2.0
#
# สร้างหน้า Landing ทั้ง 3 ภาษา (docs/landing/index.html, index.en.html, index.ko.html) จากเทมเพลตเดียว
# พร้อมหน้าคู่มือติดตั้ง (install*.html) และนโยบายความเป็นส่วนตัว (privacy*.html)
# และเขียนหัวข้อ "เมนูแก้ปัญหา" ลง README.md / README.en.md / README.ko.md (ระหว่าง <!-- stories:start/end -->)
# ธีม "เว็บสั่งอาหารของร้านใหญ่" — ปัญหาของร้านถูกเล่าเป็น "เมนู" แต่ละจานรวมหลายฟีเจอร์ (docs/DECISIONS.md #70)
#
#   python3 docs/generator/landing/build_landing.py
#
# แก้เนื้อหาที่ content.py แล้วรันใหม่ — อย่าแก้ไฟล์ HTML ที่สร้างออกมาตรง ๆ เพราะจะถูกเขียนทับ
# ภาพประกอบมาจาก app/tool/screenshots/story_test.dart → publish_story.py → docs/landing/img/story/
import json
from html import escape
from pathlib import Path

from content import LANGS, TESTS
from install_content import ACCOUNTS, INSTALL_LANGS
from privacy_content import PRIVACY_LANGS

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs' / 'landing'
SITE = 'https://suruchboss.github.io/PaynEat/'
DEMO = 'app/'
REPO = 'https://github.com/SuruchBoss/PaynEat'

# ข้อมูลสำหรับ search engine / ผู้ช่วย AI (docs/DECISIONS.md #90) — ใส่เฉพาะสิ่งที่หน้าแสดงจริง
OG_LOCALE = {'th': 'th_TH', 'en': 'en_US', 'ko': 'ko_KR'}
AUTHOR = {
    '@type': 'Person',
    '@id': SITE + '#author',
    'name': 'Suruch Chakrapeesirisuk',
    'url': 'https://github.com/SuruchBoss',
    'sameAs': ['https://www.linkedin.com/in/suruchboss'],
}

# ขนาดจริงของไฟล์ WebP ที่ publish_story.py ย่อไว้ — ใส่ width/height ให้เบราว์เซอร์จองที่ไว้ก่อนภาพโหลด
SIZES = {'phone': (780, 1688), 'tablet': (1600, 1118), 'desktop': (1600, 1000)}

LOGO = (
    '<svg viewBox="0 0 24 24" width="34" height="34" aria-hidden="true">'
    '<rect width="24" height="24" rx="6" fill="#FF6B2C"/>'
    '<rect x="5.6" y="3.6" width="3.8" height="16.8" rx="1.9" fill="#fff"/>'
    '<path d="M7.8 3.6h4.6a5.6 5.6 0 0 1 0 11.2H7.8V3.6Z" fill="#fff"/></svg>'
)
FAVICON = (
    "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E"
    "%3Crect width='24' height='24' rx='5.3' fill='%23FF6B2C'/%3E%3Crect x='5.6' y='3.6' "
    "width='3.8' height='16.8' rx='1.9' fill='white'/%3E%3Cpath d='M7.8 3.6h4.6a5.6 5.6 0 0 1 0 "
    "11.2H7.8V3.6Z' fill='white'/%3E%3C/svg%3E"
)

# EAN-13 วาดด้วย CSS gradient ทีละโมดูล (2px × 95) ให้สแกนจากจอได้จริง — เทียบแล้วตรงกับฉลากเดิมที่ตรวจด้วย zxing
# (docs/DECISIONS.md #58) ทุกแท่ง
_L = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011']
_G = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111']
_R = [''.join('1' if bit == '0' else '0' for bit in code) for code in _L]
_PARITY = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL']


def ean13_gradient(code, module=2):
    digits = [int(ch) for ch in code]
    checksum = sum(d * (3 if i % 2 else 1) for i, d in enumerate(digits[:12]))
    if len(digits) != 13 or (10 - checksum % 10) % 10 != digits[12]:
        raise ValueError(f'EAN-13 ไม่ถูกต้อง: {code}')
    bits = '101'
    for side, digit in zip(_PARITY[digits[0]], digits[1:7]):
        bits += (_L if side == 'L' else _G)[digit]
    bits += '01010' + ''.join(_R[d] for d in digits[7:]) + '101'
    stops, start = [], 0
    while start < len(bits):
        end = start
        while end < len(bits) and bits[end] == bits[start]:
            end += 1
        colour = '#111' if bits[start] == '1' else '#0000'
        stops.append(f'{colour} {start * module}px {end * module}px')
        start = end
    return 'linear-gradient(90deg,' + ','.join(stops) + ')'


CSS = r"""
:root{
  --bg:#FFF8F0;--paper:#fff;--cream:#FFEEDD;--ink:#2A1A10;--ink-2:#54392A;--muted:#6F5445;
  --line:#F0DFCE;--brand:#FF6B2C;--brand-ink:#B8400B;--cta:#D9480F;--cta-hover:#B93A0A;
  --chili:#B42318;--mustard:#FFC53D;--basil:#1F7A45;--basil-bg:#E6F4EA;--espresso:#1F130C;
  --radius:22px;--shadow:0 18px 40px -22px rgba(74,33,10,.45);--shadow-sm:0 6px 18px -10px rgba(74,33,10,.35);
  --wrap:1180px;--gutter:clamp(16px,4vw,32px);
  color-scheme:light;
}
*{box-sizing:border-box}
html{scroll-behavior:smooth;-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--ink);font:400 16px/1.65 var(--font-body);overflow-x:hidden}
img{max-width:100%;height:auto;display:block}
a{color:inherit}
h1,h2,h3,h4{font-family:var(--font-display);line-height:1.2;margin:0}
p{margin:0}
:focus-visible{outline:3px solid var(--mustard);outline-offset:3px;border-radius:8px}
.skip{position:absolute;left:-999px;top:8px;background:var(--ink);color:#fff;padding:8px 14px;border-radius:10px;z-index:99}
.skip:focus{left:12px}
.wrap{max-width:var(--wrap);margin:0 auto;padding:0 var(--gutter)}
[id]{scroll-margin-top:84px}

/* ---- แถบโปรบนสุด + header ---- */
.promo{background:var(--espresso);color:#FFE7D1;font-size:14px;text-align:center;padding:8px var(--gutter)}
.promo a{color:var(--mustard);font-weight:600;text-decoration:none;white-space:nowrap}
.promo a:hover{text-decoration:underline}
header.site{position:sticky;top:0;z-index:40;background:rgba(255,255,255,.94);backdrop-filter:saturate(1.4) blur(10px);
  -webkit-backdrop-filter:saturate(1.4) blur(10px);border-bottom:1px solid var(--line)}
.nav{display:flex;align-items:center;gap:18px;height:68px}
.brand{display:flex;align-items:center;gap:10px;text-decoration:none;font:800 22px/1 var(--font-display);letter-spacing:-.01em}
.brand small{font:600 11px/1 var(--font-body);background:var(--cream);color:var(--brand-ink);padding:4px 7px;border-radius:99px;letter-spacing:.06em}
.links{display:flex;gap:2px;margin-left:4px}
.links a{text-decoration:none;font-weight:500;color:var(--ink-2);padding:8px 8px;border-radius:99px;white-space:nowrap}
.links a:hover{background:var(--cream);color:var(--ink)}
.links a.inst{color:var(--brand-ink);border:1.5px solid var(--line);font-weight:600}
.links a.inst:hover{border-color:var(--brand)}
.links a.inst .short{display:none}
.lang{display:flex;gap:2px;margin-left:auto;background:var(--cream);border-radius:99px;padding:3px}
.lang a{text-decoration:none;font-size:13px;font-weight:600;padding:5px 10px;border-radius:99px;color:var(--ink-2)}
.lang a[aria-current="page"]{background:#fff;color:var(--ink);box-shadow:var(--shadow-sm)}
.lang .ko{font-family:'Noto Sans KR',var(--font-body)}
.cart{display:flex;align-items:center;gap:10px;text-decoration:none;background:var(--cta);color:#fff;font-weight:600;
  padding:9px 10px 9px 16px;border-radius:99px;box-shadow:var(--shadow-sm);white-space:nowrap}
.cart:hover{background:var(--cta-hover)}
.cart b{background:#fff;color:var(--cta);font-size:12px;padding:3px 8px;border-radius:99px}

/* ---- hero ---- */
.hero{padding:28px 0 0}
.banner{position:relative;overflow:hidden;border-radius:32px;color:#fff;
  background:radial-gradient(900px 420px at 85% -10%,rgba(255,197,61,.45),transparent 60%),
  radial-gradient(600px 400px at -10% 110%,rgba(255,107,44,.55),transparent 60%),
  linear-gradient(135deg,#D9480F 0%,#B42318 58%,#86170F 100%);box-shadow:var(--shadow)}
.banner::after{content:"";position:absolute;inset:0;pointer-events:none;opacity:.12;
  background-image:radial-gradient(#fff 1.2px,transparent 1.3px);background-size:22px 22px}
.hero-grid{position:relative;z-index:1;display:grid;grid-template-columns:1.02fr 1fr;gap:28px;align-items:center;padding:clamp(28px,5vw,64px)}
.eyebrow{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.16);border:1px solid rgba(255,255,255,.28);
  padding:6px 14px;border-radius:99px;font-size:14px;font-weight:500}
.hero h1{font-size:clamp(40px,6.2vw,74px);font-weight:800;letter-spacing:-.02em;margin:18px 0 16px}
.hero h1 em{font-style:normal;color:var(--mustard)}
html[lang="en"] .hero h1{font-size:clamp(38px,5vw,62px)}
.hero .lead{font-size:clamp(16px,1.6vw,19px);color:#FFE9DA;max-width:34em}
.ctas{display:flex;flex-wrap:wrap;gap:12px;margin-top:26px}
.btn{display:inline-flex;align-items:center;gap:8px;text-decoration:none;font-weight:600;border-radius:99px;padding:14px 22px;font-size:16px}
.btn-light{background:#fff;color:var(--chili);box-shadow:0 10px 24px -12px rgba(0,0,0,.5)}
.btn-light:hover{background:#FFF3E8}
.btn-ghost{color:#fff;border:1.5px solid rgba(255,255,255,.6)}
.btn-ghost:hover{background:rgba(255,255,255,.12)}
.hero-art{position:relative;min-height:420px}
.hero-art .dev.tablet{position:absolute;right:0;top:6%;width:92%;transform:rotate(1.5deg)}
.hero-art .dev.phone{position:absolute;left:0;bottom:-6%;width:34%;transform:rotate(-4deg)}
.float{position:absolute;display:flex;gap:10px;align-items:center;background:#fff;color:var(--ink);border-radius:16px;
  padding:10px 14px;box-shadow:var(--shadow);font-size:14px;line-height:1.3;z-index:3}
.float i{font-style:normal;font-size:22px}
.float small{display:block;color:var(--muted);font-size:12px}
.float.f1{right:4%;top:-2%}
.float.f2{right:10%;bottom:-2%}
.emoji{position:absolute;font-size:44px;filter:drop-shadow(0 8px 10px rgba(0,0,0,.25));z-index:2;user-select:none}
.emoji.e1{left:38%;top:-4%;transform:rotate(-12deg)}
.emoji.e2{left:30%;bottom:6%;transform:rotate(10deg);font-size:38px}
.facts{display:grid;grid-template-columns:repeat(4,1fr);gap:0;background:#fff;border-radius:20px;margin:-34px auto 0;
  position:relative;z-index:2;box-shadow:var(--shadow);max-width:calc(var(--wrap) - 2*var(--gutter) - 64px)}
.fact{display:flex;gap:12px;align-items:center;padding:18px 20px}
.fact+.fact{border-left:1px dashed var(--line)}
.fact i{font-style:normal;font-size:26px;width:46px;height:46px;display:grid;place-items:center;background:var(--cream);border-radius:14px;flex:none}
.fact b{display:block;font-family:var(--font-display);font-size:18px;line-height:1.2}
.fact small{color:var(--muted);font-size:13px;line-height:1.35;display:block}

/* ---- ตัวเลือกปัญหา (หมวดแบบแอปสั่งอาหาร) ---- */
.section{padding:clamp(56px,8vw,96px) 0 0}
.head{display:flex;flex-wrap:wrap;align-items:end;justify-content:space-between;gap:12px 24px;margin-bottom:26px}
.head h2{font-size:clamp(28px,3.6vw,42px);font-weight:800;letter-spacing:-.01em}
.head p{color:var(--muted);max-width:40em}
.kick{display:inline-block;font-weight:600;color:var(--brand-ink);font-size:14px;letter-spacing:.04em;margin-bottom:6px}
.cats{list-style:none;margin:0;padding:4px 2px 12px;display:grid;grid-template-columns:repeat(9,1fr);gap:12px}
.cats a{display:flex;flex-direction:column;align-items:center;gap:10px;text-decoration:none;text-align:center;font-weight:500;font-size:14px;line-height:1.3;color:var(--ink-2)}
.cats span.ico{width:74px;height:74px;border-radius:50%;display:grid;place-items:center;font-size:34px;background:#fff;
  box-shadow:var(--shadow-sm);border:2px solid transparent;transition:transform .15s,border-color .15s}
.cats a:hover span.ico{transform:translateY(-3px);border-color:var(--brand)}

/* ---- การ์ดเมนู ---- */
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:22px}
.card{background:var(--paper);border-radius:var(--radius);overflow:hidden;box-shadow:var(--shadow-sm);display:flex;flex-direction:column;
  border:1px solid var(--line);transition:transform .15s,box-shadow .15s}
.card:hover{transform:translateY(-4px);box-shadow:var(--shadow)}
.card-img{position:relative;display:block;aspect-ratio:16/10;overflow:hidden;background:var(--cream)}
.card-img img{width:100%;height:100%;object-fit:cover;object-position:top center}
.card-img.phone img{object-position:center 12%}
.badge{position:absolute;left:12px;top:12px;background:#fff;color:var(--ink);font-size:12.5px;font-weight:600;padding:5px 10px;border-radius:99px;box-shadow:var(--shadow-sm)}
.card-body{padding:18px 20px 20px;display:flex;flex-direction:column;gap:10px;flex:1}
.card h3{font-size:21px;font-weight:700}
.pain{color:var(--ink-2);font-size:15px;line-height:1.55}
.tags{list-style:none;padding:0;margin:0;display:flex;flex-wrap:wrap;gap:6px}
.tags li{font-size:12.5px;font-weight:500;background:var(--cream);color:var(--ink-2);padding:4px 10px;border-radius:99px}
.card-foot{margin-top:auto;display:flex;align-items:center;justify-content:space-between;gap:14px;padding-top:12px;border-top:1px dashed var(--line)}
.price{font-family:var(--font-display);font-weight:700;color:var(--brand-ink);font-size:16px;line-height:1.3}
.price small{display:block;font:500 11.5px/1.2 var(--font-body);color:var(--muted);letter-spacing:.04em;margin-bottom:2px}
.add{flex:none;width:44px;height:44px;border-radius:50%;background:var(--cta);color:#fff;display:grid;place-items:center;text-decoration:none;
  font-size:26px;font-weight:600;line-height:1;box-shadow:var(--shadow-sm)}
.add:hover{background:var(--cta-hover)}

/* ---- เรื่องเล่าทีละจาน ---- */
.stories-band{background:linear-gradient(180deg,var(--bg),#FFF1E3 30%,#FFF1E3 70%,var(--bg))}
.story{background:var(--paper);border-radius:28px;border:1px solid var(--line);box-shadow:var(--shadow-sm);padding:clamp(22px,4vw,48px);margin-bottom:28px}
.story-grid{display:grid;grid-template-columns:1fr 1.22fr;gap:clamp(24px,4vw,56px);align-items:start}
.story.flip .story-grid{grid-template-columns:1.22fr 1fr}
.story.flip .story-copy{order:2}
.story-kicker{display:flex;align-items:center;gap:10px;font-weight:600;color:var(--brand-ink);font-size:15px}
.story-kicker .num{font-family:var(--font-display);background:var(--cta);color:#fff;border-radius:10px;padding:2px 9px;font-size:14px}
.story h3{font-size:clamp(24px,2.6vw,32px);font-weight:800;margin:10px 0 16px;letter-spacing:-.01em}
.problem{background:#FFF4EA;border-left:4px solid var(--brand);border-radius:0 14px 14px 0;padding:12px 16px;color:var(--ink-2)}
.problem b{display:block;font-size:13px;letter-spacing:.04em;color:var(--brand-ink);margin-bottom:2px}
.story h4{font-size:15px;letter-spacing:.04em;color:var(--muted);font-weight:600;margin:22px 0 8px}
.features{list-style:none;padding:0;margin:0;display:grid;gap:10px}
.features li{display:grid;grid-template-columns:26px 1fr;gap:10px;align-items:start}
.features li::before{content:"✓";width:24px;height:24px;border-radius:50%;background:var(--basil-bg);color:var(--basil);display:grid;place-items:center;font-weight:700;font-size:13px;margin-top:2px}
.features b{display:block;font-weight:600}
.features span{color:var(--ink-2);font-size:15px}
.result{margin-top:18px;display:inline-flex;gap:8px;align-items:center;background:var(--basil-bg);color:var(--basil);font-weight:600;padding:8px 14px;border-radius:12px}
.recipe{margin-top:20px;border:2px dashed #E9CDB3;border-radius:16px;padding:14px 18px;background:#FFFCF8}
.recipe b{font-family:var(--font-display);font-size:16px}
.recipe ol{margin:8px 0 10px;padding-left:22px;color:var(--ink-2);font-size:15px}
.recipe a{font-weight:600;color:var(--brand-ink);text-decoration:none}
.recipe a:hover{text-decoration:underline}
.media{display:grid;gap:18px;justify-items:center}
.media figure{margin:0;width:100%}
.media figcaption{font-size:13px;color:var(--muted);text-align:center;margin-top:10px}
.media.stack figure:nth-child(2){width:88%;justify-self:end;margin-top:-14%;position:relative}
.media.combo{position:relative;padding-bottom:10%}
.media.combo figure.p{position:absolute;left:-2%;bottom:0;width:32%}
.media.combo figure.p figcaption{display:none}
.dev{background:#141414;box-shadow:var(--shadow);overflow:hidden}
.dev img{width:100%}
.dev.phone{border-radius:34px;padding:9px;max-width:300px;margin:0 auto}
.dev.phone img{border-radius:26px}
.dev.tablet{border-radius:24px;padding:12px}
.dev.tablet img{border-radius:12px}
.dev.desktop{border-radius:14px;padding:0;background:#fff;border:1px solid #E7D7C7}
.dev.desktop::before{content:"";display:block;height:26px;border-bottom:1px solid #E7D7C7;
  background:radial-gradient(circle at 14px 50%,#FF5F57 4px,transparent 4.5px),radial-gradient(circle at 28px 50%,#FEBC2E 4px,transparent 4.5px),
  radial-gradient(circle at 42px 50%,#28C840 4px,transparent 4.5px),#F4ECE4}
.media.stack .dev.desktop{box-shadow:0 22px 50px -24px rgba(74,33,10,.55)}

/* ---- ฉลากตาชั่ง (สแกนได้จริง) ---- */
.scale{margin:18px 0 0;display:flex;gap:16px;align-items:center;flex-wrap:wrap}
.lb{width:260px;max-width:100%;background:#fff;color:#111;border-radius:10px;padding:14px 16px 10px;border:1px solid #E3DDD3;box-shadow:var(--shadow-sm)}
.lb-store{font-size:11.5px;color:#4A4A4A;text-align:center;padding-bottom:5px;border-bottom:1.5px solid #111}
.lb-item{font-family:var(--font-display);font-weight:800;font-size:19px;line-height:1.2;margin:8px 0}
.lb-grid{display:grid;grid-template-columns:1fr 1fr 1.15fr;margin:0;border:1.5px solid #111}
.lb-grid>div{padding:5px 7px;border-left:1.5px solid #111;min-width:0}
.lb-grid>div:first-child{border-left:0}
.lb-grid dt{font-size:10.5px;line-height:1.3;color:#3A3A3A}
.lb-grid dd{margin:2px 0 0;font-family:'IBM Plex Mono',ui-monospace,monospace;font-size:15px;font-weight:500}
.lb-grid .lb-total{background:#111;color:#fff}
.lb-grid .lb-total dt{color:#E4E4E4}
.lb-bars{width:190px;height:52px;margin:12px auto 0}
.lb-code{text-align:center;font-family:'IBM Plex Mono',ui-monospace,monospace;font-size:12.5px;letter-spacing:.16em;margin-top:3px}
.scale figcaption{flex:1;min-width:180px;font-size:14px;color:var(--ink-2)}
.scale code{font-family:'IBM Plex Mono',ui-monospace,monospace;background:var(--cream);padding:1px 6px;border-radius:6px}

/* ---- AI ---- */
.ai{background:var(--espresso);color:#F6E9DE;margin-top:clamp(56px,8vw,96px);padding:clamp(56px,8vw,96px) 0}
.ai .head p,.ai .muted{color:#D9C4B4}
.ai .kick{color:var(--mustard)}
.ai-grid{display:grid;grid-template-columns:1fr 1.25fr;gap:clamp(24px,4vw,56px);align-items:center}
.ai ul{list-style:none;padding:0;margin:18px 0 0;display:grid;gap:12px}
.ai li{display:grid;grid-template-columns:28px 1fr;gap:10px}
.ai li i{font-style:normal}
.ai li b{color:#fff}
.ai figure{margin:0}
.ai figure img{border-radius:16px;border:1px solid #3A2A20;box-shadow:0 30px 60px -30px #000}
.ai figcaption{font-size:13px;color:#BFA999;margin-top:10px}

/* ---- มาตรฐานครัวหลังบ้าน ---- */
.std{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
.std div{background:#fff;border:1px solid var(--line);border-radius:18px;padding:20px 22px;display:grid;grid-template-columns:48px 1fr;gap:14px;align-items:start}
.std i{font-style:normal;font-size:24px;width:48px;height:48px;border-radius:14px;background:var(--cream);display:grid;place-items:center}
.std b{display:block;font-family:var(--font-display);font-size:20px;line-height:1.25}
.std span{color:var(--ink-2);font-size:14.5px;line-height:1.5}

/* ---- ตะกร้า / ราคา ---- */
.checkout-grid{display:grid;grid-template-columns:1fr 1fr;gap:24px;align-items:start}
.receipt{background:#fff;border-radius:18px;padding:26px 26px 30px;box-shadow:var(--shadow);position:relative;
  -webkit-mask:radial-gradient(10px at 50% 100%,#0000 98%,#000) 50% 100%/20px 100% repeat-x;
  mask:radial-gradient(10px at 50% 100%,#0000 98%,#000) 50% 100%/20px 100% repeat-x;padding-bottom:40px}
.receipt h3{font-size:22px;display:flex;align-items:center;gap:10px}
.receipt .shop{color:var(--muted);font-size:14px;margin:4px 0 16px}
.line{display:flex;justify-content:space-between;gap:16px;padding:9px 0;border-bottom:1px dashed var(--line);font-size:15px}
.line small{display:block;color:var(--muted);font-size:12.5px}
.line .amt{font-family:'IBM Plex Mono',ui-monospace,monospace;font-weight:500;white-space:nowrap}
.line.total{border-bottom:0;font-family:var(--font-display);font-weight:800;font-size:22px;padding-top:14px}
.line.total .amt{color:var(--brand-ink);font-family:'IBM Plex Mono',ui-monospace,monospace;font-weight:600}
.receipt .btn{width:100%;justify-content:center;margin-top:16px;background:var(--cta);color:#fff}
.receipt .btn:hover{background:var(--cta-hover)}
.receipt .thanks{text-align:center;color:var(--muted);font-size:13px;margin-top:12px}
.options{display:grid;gap:14px}
.opt{display:grid;grid-template-columns:52px 1fr auto;gap:14px;align-items:center;background:#fff;border:1.5px solid var(--line);border-radius:18px;
  padding:16px 18px;text-decoration:none}
.opt:hover{border-color:var(--brand)}
.opt i{font-style:normal;font-size:26px;width:52px;height:52px;border-radius:16px;background:var(--cream);display:grid;place-items:center}
.opt b{display:block;font-weight:600}
.opt span{color:var(--ink-2);font-size:14px;line-height:1.45;display:block}
.opt .go{color:var(--brand-ink);font-weight:700;font-size:20px}
.opt.erp{background:linear-gradient(135deg,#1F130C,#3A2418);border-color:#3A2418;color:#F6E9DE}
.opt.erp span{color:#D9C4B4}
.opt.erp i{background:#3A2418}
.opt.erp .go{color:var(--mustard)}
.note{font-size:13.5px;color:var(--muted);margin-top:4px}
.note a{color:var(--brand-ink)}

/* ---- footer ---- */
footer.site-foot{margin-top:clamp(56px,8vw,96px);background:var(--espresso);color:#D9C4B4;padding:44px 0 110px;font-size:14px}
.foot{display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,.7fr) minmax(0,1fr);gap:32px 48px}
.foot .brand{color:#fff;margin-bottom:12px}
.foot p+p{margin-top:8px}
.foot a{color:#FFE2C8}
.foot h2{font:600 14.5px/1.3 var(--font-body);color:#C9AE99;margin:6px 0 14px}
/* ตัวพิมพ์ใหญ่ + ระยะห่างตัวอักษรใช้กับภาษาอังกฤษเท่านั้น — อักษรไทยและฮันกึลถูกถ่างจนอ่านเป็นตัว ๆ */
html[lang="en"] .foot h2{font-size:13px;letter-spacing:.08em;text-transform:uppercase}
.foot-links ul,.foot-contact ul{list-style:none;padding:0;margin:0;display:grid;gap:10px}
.foot-links a{text-decoration:none}
.foot-links a:hover{text-decoration:underline}
.foot-contact>p{margin:0 0 14px;color:#D9C4B4}
.contact{display:grid;grid-template-columns:40px minmax(0,1fr);gap:12px;align-items:center;padding:10px 12px;border-radius:14px;
  background:#2C1B12;border:1px solid #3A2418;text-decoration:none;color:#FFF3E8;transition:border-color .15s}
.contact:hover{border-color:var(--mustard)}
.contact .ci{width:40px;height:40px;border-radius:12px;background:#3A2418;color:var(--mustard);display:grid;place-items:center}
.contact b{display:block;font-weight:600;font-size:14.5px;line-height:1.35}
.contact small{display:block;color:#D9C4B4;font-size:13.5px;line-height:1.4;overflow-wrap:anywhere}

/* ---- แถบตะกร้าล่างจอ (มือถือ) ---- */
.mcart{display:none}
@media (max-width:760px){
  .mcart{display:flex;position:fixed;left:12px;right:12px;bottom:12px;z-index:50;align-items:center;justify-content:space-between;gap:12px;
    background:var(--espresso);color:#fff;border-radius:18px;padding:10px 10px 10px 16px;box-shadow:0 16px 30px -12px rgba(0,0,0,.55)}
  .mcart b{display:block;font-family:var(--font-display);font-size:15px}
  .mcart small{display:block;color:#D9C4B4;font-size:12px}
  .mcart a{background:var(--cta);color:#fff;text-decoration:none;font-weight:600;padding:11px 16px;border-radius:12px;white-space:nowrap}
}

/* ---- responsive ---- */
.brand,.lang,.cart,.links a.inst{flex:none}
.lang a{white-space:nowrap}
@media (max-width:1500px){.cart b{display:none}}
@media (max-width:1180px){.links a:not(.inst){display:none}}
@media (max-width:1080px){
  .foot{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}
  .foot-about{grid-column:1/-1}
  .cats{grid-template-columns:none;grid-auto-flow:column;grid-auto-columns:92px;overflow-x:auto;scroll-snap-type:x mandatory;padding-bottom:16px}
  .cats li{scroll-snap-align:start}
  .cards{grid-template-columns:repeat(2,1fr)}
  .std{grid-template-columns:repeat(2,1fr)}
  .facts{grid-template-columns:repeat(2,1fr)}
  .fact:nth-child(3){border-left:0}
  .fact:nth-child(n+3){border-top:1px dashed var(--line)}
}
@media (max-width:900px){
  .hero-grid,.story-grid,.ai-grid,.checkout-grid,.foot{grid-template-columns:1fr}
  .story.flip .story-copy{order:0}
  .story.flip .story-grid{grid-template-columns:1fr}
  .hero-art{min-height:0;aspect-ratio:1.25/1;margin-top:8px}
  .facts{margin:18px 0 0;max-width:none}
}
@media (max-width:760px){
  .nav{height:60px;gap:10px}
  .links a.inst{padding:6px 10px;font-size:14px}
  .links a.inst .full{display:none}
  .links a.inst .short{display:inline}
  .cart{display:none}
  .lang a{padding:5px 8px}
  .cards{grid-template-columns:1fr}
  .std{grid-template-columns:1fr}
  .emoji,.float.f1{display:none}
  .float.f2{right:0;bottom:-4%;font-size:13px}
  .hero-art .dev.phone{width:36%;bottom:-8%}
  .media.combo figure.p{width:36%}
  .banner{border-radius:24px}
}
@media (max-width:420px){
  .nav{gap:6px}
  .lang a{padding:5px 6px}
  .links a.inst{padding:6px 8px;font-size:13px}
  .nav .brand span{display:none}
  .facts{grid-template-columns:1fr}
  .fact+.fact{border-left:0;border-top:1px dashed var(--line)}
  .brand small{display:none}
}
@media (prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}
"""


def e(text):
    return escape(text, quote=True)


def img(c, scene, kind, alt, lazy=True, cls=''):
    width, height = SIZES[kind]
    loading = ' loading="lazy"' if lazy else ' fetchpriority="high"'
    klass = f' class="{cls}"' if cls else ''
    return (
        f'<img{klass} src="img/story/{c["shot"]}-{scene}.webp" width="{width}" height="{height}" '
        f'alt="{e(alt)}"{loading} decoding="async">'
    )


def device(c, scene, kind, alt, caption=None, lazy=True, extra=''):
    cap = f'<figcaption>{e(caption)}</figcaption>' if caption else ''
    return f'<figure class="{extra}"><div class="dev {kind}">{img(c, scene, kind, alt, lazy)}</div>{cap}</figure>'


def header(c):
    langs = []
    for code, label, href in (('th', 'ไทย', 'index.html'), ('en', 'EN', 'index.en.html'), ('ko', '한국어', 'index.ko.html')):
        current = ' aria-current="page"' if code == c['code'] else ''
        cls = ' class="ko"' if code == 'ko' else ''
        langs.append(f'<a href="{href}" hreflang="{code}" lang="{code}"{cls}{current}>{label}</a>')
    # ลิงก์ "วิธีติดตั้ง" ไปอีกหน้า — เป็นลิงก์เดียวที่ยังเห็นบนแท็บเล็ต/มือถือ (ลิงก์ในหน้าเดียวกันซ่อนไป, DECISIONS #72)
    links = ''.join(
        f'<a class="inst" href="{href}"><span class="full">{e(label)}</span><span class="short">{e(c["nav_install_short"])}</span></a>'
        if href.startswith('install') else f'<a href="{href}">{e(label)}</a>'
        for href, label in c['nav']
    )
    return f"""<a class="skip" href="#menu">{e(c['skip'])}</a>
<div class="promo">🎉 {e(c['promo'])} <a href="{DEMO}">{e(c['promo_link'])}</a></div>
<header class="site"><div class="wrap nav">
  <a class="brand" href="#top" aria-label="PaynEat POS">{LOGO}<span>PaynEat</span><small>POS</small></a>
  <nav class="links" aria-label="{e(c['nav_label'])}">{links}</nav>
  <div class="lang" role="navigation" aria-label="{e(c['lang_label'])}">{''.join(langs)}</div>
  <a class="cart" href="{DEMO}">🛒 {e(c['cart'])} <b>฿0</b></a>
</div></header>"""


def hero(c):
    h = c['hero']
    s1, s2 = c['stories'][0], c['stories'][2]
    facts = ''.join(
        f'<div class="fact"><i aria-hidden="true">{icon}</i><div><b>{e(big)}</b><small>{e(small)}</small></div></div>'
        for icon, big, small in h['facts']
    )
    floats = ''.join(
        f'<div class="float f{i}"><i aria-hidden="true">{icon}</i><div><b>{e(big)}</b><small>{e(small)}</small></div></div>'
        for i, (icon, big, small) in enumerate(h['floats'], start=1)
    )
    return f"""<section class="hero" id="top"><div class="wrap">
  <div class="banner"><div class="hero-grid">
    <div>
      <span class="eyebrow">{e(h['eyebrow'])}</span>
      <h1>{h['title_html']}</h1>
      <p class="lead">{e(h['lead'])}</p>
      <div class="ctas"><a class="btn btn-light" href="{DEMO}">{e(h['cta'])}</a><a class="btn btn-ghost" href="#menu">{e(h['cta2'])}</a></div>
    </div>
    <div class="hero-art">
      <span class="emoji e1" aria-hidden="true">🍜</span><span class="emoji e2" aria-hidden="true">🍗</span>
      <div class="dev tablet">{img(c, s1['shots'][0][0], 'tablet', s1['shots'][0][2], lazy=False)}</div>
      <div class="dev phone">{img(c, s2['shots'][0][0], 'phone', s2['shots'][0][2], lazy=False)}</div>
      {floats}
    </div>
  </div></div>
  <div class="facts">{facts}</div>
</div></section>"""


def picker(c):
    items = ''.join(
        f'<li><a href="#s-{s["id"]}"><span class="ico" aria-hidden="true">{s["emoji"]}</span><span>{e(s["chip"])}</span></a></li>'
        for s in c['stories']
    )
    p = c['picker']
    return f"""<section class="section" aria-labelledby="picker-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(p['kick'])}</span><h2 id="picker-h">{e(p['title'])}</h2></div><p>{e(p['sub'])}</p></div>
  <ul class="cats">{items}</ul>
</div></section>"""


def menu(c):
    cards = []
    for s in c['stories']:
        scene, kind, alt, _ = s['shots'][0]
        tags = ''.join(f'<li>{e(t)}</li>' for t in s['tags'])
        cards.append(f"""<article class="card">
  <a class="card-img {kind}" href="#s-{s['id']}" tabindex="-1" aria-hidden="true">{img(c, scene, kind, alt)}<span class="badge">{s['emoji']} {e(s['role'])}</span></a>
  <div class="card-body">
    <h3>{e(s['title'])}</h3>
    <p class="pain">{e(s['pain'])}</p>
    <ul class="tags" aria-label="{e(c['labels']['tags'])}">{tags}</ul>
    <div class="card-foot"><p class="price"><small>{e(c['labels']['outcome'])}</small>{e(s['outcome'])}</p>
      <a class="add" href="#s-{s['id']}" aria-label="{e(c['labels']['more'])}: {e(s['title'])}">+</a></div>
  </div>
</article>""")
    m = c['menu']
    return f"""<section class="section" id="menu" aria-labelledby="menu-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(m['kick'])}</span><h2 id="menu-h">{e(m['title'])}</h2></div><p>{e(m['sub'])}</p></div>
  <div class="cards">{''.join(cards)}</div>
</div></section>"""


def scale_label(label):
    code = '2000101012504'  # prefix 20 + PLU 00101 หมูสามชั้น + 01250 กรัม (ฉลากเดียวกับข้อมูลเดโม)
    grad = ean13_gradient(code)
    return f"""<figure class="scale">
      <div class="lb" role="img" aria-label="{e(label['aria'])}">
        <p class="lb-store">{e(label['store'])}</p>
        <p class="lb-item">{e(label['item'])}</p>
        <dl class="lb-grid"><div><dt>{e(label['weight'])}</dt><dd>1.250</dd></div><div><dt>{e(label['per_kg'])}</dt><dd>280.00</dd></div>
          <div class="lb-total"><dt>{e(label['total'])}</dt><dd>350.00</dd></div></dl>
        <div class="lb-bars" style="background:{grad}"></div>
        <p class="lb-code">2 000101 012504</p>
      </div>
      <figcaption>{label['caption_html']}</figcaption>
    </figure>"""


def story(c, index, s):
    features = ''.join(f'<li><div><b>{e(n)}</b><span>{e(t)}</span></div></li>' for n, t in s['features'])
    steps = ''.join(f'<li>{e(step)}</li>' for step in s['try'])
    shots = s['shots']
    kinds = [kind for _, kind, _, _ in shots]
    if len(shots) == 2 and kinds[1] == 'phone':
        media_cls = 'combo'
        figs = device(c, shots[0][0], shots[0][1], shots[0][2], shots[0][3]) + device(
            c, shots[1][0], 'phone', shots[1][2], shots[1][3], extra='p'
        )
    else:
        media_cls = 'stack' if len(shots) == 2 else ''
        figs = ''.join(device(c, scene, kind, alt, cap) for scene, kind, alt, cap in shots)
    flip = ' flip' if index % 2 else ''
    L = c['labels']
    return f"""<article class="story{flip}" id="s-{s['id']}" aria-labelledby="s-{s['id']}-h">
  <div class="story-grid">
    <div class="story-copy">
      <p class="story-kicker"><span class="num">{index + 1:02d}</span><span aria-hidden="true">{s['emoji']}</span> {e(s['title'])}</p>
      <h3 id="s-{s['id']}-h">{e(s['headline'])}</h3>
      <div class="problem"><b>{e(L['problem'])}</b>{e(s['problem'])}</div>
      <h4>{e(L['inside'])}</h4>
      <ul class="features">{features}</ul>
      <p class="result">✓ {e(s['outcome'])}</p>
      <div class="recipe"><b>{e(L['try'])}</b><ol>{steps}</ol><a href="{DEMO}">{e(L['open_demo'])}</a></div>
      {scale_label(s['label']) if 'label' in s else ''}
    </div>
    <div class="media {media_cls}">{figs}</div>
  </div>
</article>"""


def stories(c):
    st = c['stories_head']
    body = ''.join(story(c, i, s) for i, s in enumerate(c['stories']))
    return f"""<section class="section stories-band" id="stories" aria-labelledby="stories-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(st['kick'])}</span><h2 id="stories-h">{e(st['title'])}</h2></div><p>{e(st['sub'])}</p></div>
  {body}
</div></section>"""


def ai(c):
    a = c['ai']
    items = ''.join(f'<li><i aria-hidden="true">{icon}</i><div><b>{e(b)}</b> {e(t)}</div></li>' for icon, b, t in a['points'])
    return f"""<section class="ai" id="ai" aria-labelledby="ai-h"><div class="wrap ai-grid">
  <div>
    <span class="kick">{e(a['kick'])}</span>
    <h2 id="ai-h" style="font-size:clamp(28px,3.6vw,42px);font-weight:800;color:#fff">{e(a['title'])}</h2>
    <p class="muted" style="margin-top:14px">{e(a['text'])}</p>
    <ul>{items}</ul>
  </div>
  <figure><img src="ai-demo/ai-assistant-demo.gif" width="800" height="500" alt="{e(a['alt'])}" loading="lazy" decoding="async">
    <figcaption>{e(a['caption'])}</figcaption></figure>
</div></section>"""


def standards(c):
    s = c['standards']
    tiles = ''.join(f'<div><i aria-hidden="true">{icon}</i><p><b>{e(b)}</b><span>{e(t)}</span></p></div>' for icon, b, t in s['items'])
    return f"""<section class="section" aria-labelledby="std-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(s['kick'])}</span><h2 id="std-h">{e(s['title'])}</h2></div><p>{e(s['sub'])}</p></div>
  <div class="std">{tiles}</div>
</div></section>"""


def checkout(c):
    k = c['checkout']
    lines = ''.join(
        f'<div class="line"><div>{e(name)}<small>{e(sub)}</small></div><span class="amt">{e(amt)}</span></div>'
        for name, sub, amt in k['lines']
    )
    opts = ''.join(
        f'<a class="opt{" erp" if key == "erp" else ""}" href="{href}"><i aria-hidden="true">{icon}</i>'
        f'<div><b>{e(b)}</b><span>{e(t)}</span></div><span class="go" aria-hidden="true">→</span></a>'
        for key, icon, b, t, href in k['options']
    )
    return f"""<section class="section" id="checkout" aria-labelledby="co-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(k['kick'])}</span><h2 id="co-h">{e(k['title'])}</h2></div><p>{e(k['sub'])}</p></div>
  <div class="checkout-grid">
    <div class="receipt">
      <h3>🛒 {e(k['cart_title'])}</h3>
      <p class="shop">{e(k['shop'])}</p>
      {lines}
      <div class="line total"><span>{e(k['total'])}</span><span class="amt">฿0.00</span></div>
      <a class="btn" href="{DEMO}">{e(k['pay'])}</a>
      <p class="thanks">{e(k['thanks'])}</p>
    </div>
    <div class="options">
      <h3 style="font-size:20px">{e(k['options_title'])}</h3>
      {opts}
      <p class="note">{k['note_html']}</p>
    </div>
  </div>
</div></section>"""


# ไอคอนช่องทางติดต่อท้ายหน้า — วาด inline ไม่โหลดจากที่อื่น (เส้นใช้ currentColor)
CONTACT_ICONS = {
    'mail': '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" '
    'stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m4 7 8 6 8-6"/></svg>',
    'linkedin': '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" '
    'stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="4"/><path d="M8 10.5V17M8 7.2v.1'
    'M12 17v-6.5M12 13.5a2.8 2.8 0 0 1 5 0V17"/></svg>',
    'issues': '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" '
    'stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 0 1-11.6 7.1L4 20l1-4.1A8 8 0 1 1 20 12Z"/>'
    '<path d="M9 10.5h6M9 13.5h4"/></svg>',
}


def footer(c, home='#top'):
    f = c['footer']
    ct = f['contact']
    links = ''.join(f'<li><a href="{href}">{e(label)}</a></li>' for label, href in f['links'])
    paras = ''.join(f'<p>{p}</p>' for p in f['paras_html'])
    contacts = ''.join(
        f'<li><a class="contact" href="{href}"><span class="ci" aria-hidden="true">{CONTACT_ICONS[icon]}</span>'
        f'<span><b>{e(label)}</b><small>{e(value)}</small></span></a></li>'
        for icon, label, value, href in ct['items']
    )
    return f"""<footer class="site-foot"><div class="wrap foot">
  <div class="foot-about"><a class="brand" href="{home}">{LOGO}<span>PaynEat</span><small>POS</small></a>{paras}</div>
  <nav class="foot-links" aria-labelledby="foot-links-h"><h2 id="foot-links-h">{e(f['links_title'])}</h2><ul>{links}</ul></nav>
  <section class="foot-contact" aria-labelledby="foot-contact-h"><h2 id="foot-contact-h">{e(ct['title'])}</h2>
    <p>{e(ct['lead'])}</p><ul>{contacts}</ul></section>
</div></footer>
<div class="mcart" role="complementary" aria-label="{e(c['mcart']['label'])}"><div><b>🛒 PaynEat POS</b><small>{e(c['mcart']['sub'])}</small></div><a href="{DEMO}">{e(c['mcart']['cta'])}</a></div>"""


PAGES = ('index.html', 'index.en.html', 'index.ko.html')
INSTALL_PAGES = ('install.html', 'install.en.html', 'install.ko.html')


def url_of(file):
    return SITE + ('' if file == 'index.html' else file)


def structured_data(c):
    """JSON-LD ของหน้าหลัก: เว็บไซต์ + ตัวแอป + ผู้สร้าง
    ใส่เฉพาะสิ่งที่หน้าแสดงจริง — ราคา ฿0 (ตะกร้า), ฟีเจอร์ 9 ชุด, ภาพหน้าจอจริง, ผู้สร้างในส่วนท้าย ไม่มี rating/review
    เพราะไม่มีรีวิวจริงบนหน้า (ใส่ของปลอมเสี่ยงโดน manual action)"""
    code = c['code']
    install = INSTALL_PAGES[('th', 'en', 'ko').index(code)]
    shots = [f"{SITE}img/story/{c['shot']}-{story['shots'][0][0]}.webp" for story in c['stories'][:4]]
    return {
        '@context': 'https://schema.org',
        '@graph': [
            {
                '@type': 'WebSite',
                '@id': SITE + '#website',
                'url': SITE,
                'name': 'PaynEat POS',
                'inLanguage': ['th', 'en', 'ko'],
                'publisher': {'@id': AUTHOR['@id']},
            },
            {
                '@type': 'SoftwareApplication',
                '@id': SITE + '#software',
                'name': 'PaynEat POS',
                'url': url_of(c['file']),
                'description': c['description'],
                'inLanguage': code,
                'applicationCategory': 'BusinessApplication',
                'applicationSubCategory': 'Restaurant point of sale (POS)',
                'operatingSystem': 'Web browser, Windows, macOS, Linux',
                'isAccessibleForFree': True,
                'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'THB'},
                'license': REPO + '/blob/main/LICENSE',
                'image': SITE + c['og_image'],
                'screenshot': shots,
                'featureList': [story['title'] for story in c['stories']],
                'softwareHelp': {'@type': 'CreativeWork', 'url': url_of(install)},
                'sameAs': [REPO],
                'author': {'@id': AUTHOR['@id']},
                'isPartOf': {'@id': SITE + '#website'},
            },
            AUTHOR,
        ],
    }


def document(code, file, pages, title, description, og_image, body, css=CSS, script='', jsonld=None):
    """<head> ร่วมของทุกหน้าใน docs/landing — ฟอนต์, og, hreflang ไปหน้าเดียวกันของภาษาอื่น"""
    fonts = (
        'https://fonts.googleapis.com/css2?family=Kanit:wght@500;600;700;800&family=Anuphan:wght@400;500;600'
        '&family=IBM+Plex+Mono:wght@500;600&display=swap'
    )
    ko_font = (
        'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;600;700;800&display=swap'
        if code == 'ko'
        # ป้ายสลับภาษา "한국어" ใช้ฮันกึลที่ Kanit/Anuphan ไม่มี — text= ตัด subset ให้เหลือ 3 ตัวอักษร (~2KB)
        else 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@600&text=%ED%95%9C%EA%B5%AD%EC%96%B4&display=swap'
    )
    if code == 'ko':
        font_vars = "--font-display:'Noto Sans KR','Kanit',system-ui,sans-serif;--font-body:'Noto Sans KR','Anuphan',system-ui,sans-serif"
    else:
        font_vars = "--font-display:'Kanit',system-ui,sans-serif;--font-body:'Anuphan',system-ui,sans-serif"
    alternates = ''.join(
        f'<link rel="alternate" hreflang="{lang}" href="{url_of(other)}">' for lang, other in zip(('th', 'en', 'ko'), pages)
    )
    # ภาษาอื่นนอกจาก 3 ภาษานี้ไปหน้าอังกฤษ
    alternates += f'<link rel="alternate" hreflang="x-default" href="{url_of(pages[1])}">'
    locales = ''.join(
        f'\n<meta property="og:locale:alternate" content="{OG_LOCALE[other]}">' for other in OG_LOCALE if other != code
    )
    url = url_of(file)
    og = SITE + og_image
    js = f'\n<script>{script}</script>' if script else ''
    # "</" ในข้อความทำให้ปิด <script> ก่อนเวลา
    ld = (
        '\n<script type="application/ld+json">'
        + json.dumps(jsonld, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
        + '</script>'
        if jsonld
        else ''
    )
    return f"""<!doctype html>
<!-- สร้างจาก docs/generator/landing/build_landing.py — แก้เนื้อหาที่ content.py / install_content.py แล้วรันใหม่ อย่าแก้ไฟล์นี้ตรง ๆ -->
<html lang="{code}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{e(title)}</title>
<meta name="description" content="{e(description)}">
<meta name="theme-color" content="#D9480F">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(description)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="PaynEat POS">
<meta property="og:locale" content="{OG_LOCALE[code]}">{locales}
<meta property="og:url" content="{url}">
<meta property="og:image" content="{og}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="{og}">
<link rel="canonical" href="{url}">
{alternates}{ld}
<link rel="icon" href="{FAVICON}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="{fonts}">
<link rel="stylesheet" href="{ko_font}">
<style>:root{{{font_vars}}}{css}</style>
</head>
<body>
{body}{js}
</body>
</html>
"""


def page(c):
    body = ''.join([
        header(c),
        '<main>',
        hero(c),
        picker(c),
        menu(c),
        stories(c),
        ai(c),
        standards(c),
        checkout(c),
        '</main>',
        footer(c),
    ])
    return document(
        c['code'], c['file'], PAGES, c['title'], c['description'], c['og_image'], body, jsonld=structured_data(c)
    )


# ---------------------------------------------------------------------------------------------
# หน้า "คู่มือติดตั้ง" (docs/landing/install*.html) — คนไม่ใช่สาย IT ทำตามได้โดยไม่ต้องเปิด GitHub (DECISIONS #72)
# ใช้ token/header/footer ชุดเดียวกับหน้า Landing แล้วเพิ่ม CSS เฉพาะหน้านี้ต่อท้าย

INSTALL_CSS = r"""
/* ---- คู่มือติดตั้ง ---- */
.links a.home{color:var(--brand-ink)}
.ghero{padding:28px 0 0}
.ghero .panel{position:relative;overflow:hidden;background:var(--paper);border:1px solid var(--line);border-radius:28px;
  padding:clamp(24px,4.5vw,52px);box-shadow:var(--shadow-sm)}
.ghero .panel::after{content:"";position:absolute;right:-60px;top:-60px;width:260px;height:260px;border-radius:50%;
  background:radial-gradient(circle,rgba(255,197,61,.35),transparent 70%);pointer-events:none}
.crumb{display:flex;flex-wrap:wrap;gap:6px;align-items:center;font-size:14px;color:var(--muted);margin-bottom:14px}
.crumb a{color:var(--brand-ink);text-decoration:none;font-weight:500}
.crumb a:hover{text-decoration:underline}
.ghero h1{font-size:clamp(32px,4.8vw,54px);font-weight:800;letter-spacing:-.015em;max-width:18em;text-wrap:balance}
.ghero .lead{margin-top:14px;font-size:clamp(16px,1.5vw,18.5px);color:var(--ink-2);max-width:38em}
.chips{list-style:none;padding:0;margin:20px 0 0;display:flex;flex-wrap:wrap;gap:8px}
.chips li{background:var(--cream);color:var(--ink-2);font-size:14px;font-weight:500;padding:6px 12px;border-radius:99px}

.paths{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(4,1fr);gap:18px}
.path{position:relative;display:flex;flex-direction:column;gap:14px;background:var(--paper);border:1.5px solid var(--line);
  border-radius:var(--radius);padding:22px 20px 20px;box-shadow:var(--shadow-sm)}
.path.rec{border-color:var(--brand);box-shadow:var(--shadow)}
.path .ico{width:54px;height:54px;border-radius:16px;background:var(--cream);display:grid;place-items:center;font-size:28px}
.path h3{font-size:20px;font-weight:700;text-wrap:balance}
.flag{position:absolute;right:16px;top:18px;background:var(--mustard);color:var(--ink);font-size:12.5px;font-weight:600;
  padding:4px 10px;border-radius:99px}
.meta{margin:0;display:grid;gap:10px}
.meta div{display:grid;gap:1px}
.meta dt{font-size:12.5px;font-weight:600;color:var(--muted);letter-spacing:.03em}
.meta dd{margin:0;font-size:15px;line-height:1.45;color:var(--ink)}
.go-btn{margin-top:auto;display:flex;justify-content:center;align-items:center;gap:8px;text-decoration:none;font-weight:600;
  border-radius:99px;padding:12px 16px;border:1.5px solid var(--cta);color:var(--cta)}
.go-btn:hover{background:var(--cream)}
.path.rec .go-btn{background:var(--cta);color:#fff}
.path.rec .go-btn:hover{background:var(--cta-hover)}

.guide{display:grid;grid-template-columns:minmax(0,320px) minmax(0,1fr);gap:clamp(24px,4vw,48px);background:var(--paper);
  border:1px solid var(--line);border-radius:28px;padding:clamp(20px,3.5vw,40px);box-shadow:var(--shadow-sm)}
.guide-side{align-self:start;position:sticky;top:92px;display:flex;flex-direction:column;gap:14px}
.guide-side .ico{width:60px;height:60px;border-radius:18px;background:var(--cream);display:grid;place-items:center;font-size:32px}
.guide-side h2{font-size:clamp(26px,3vw,34px);font-weight:800;letter-spacing:-.01em;text-wrap:balance}
.guide-side p{color:var(--ink-2)}
.facts2{margin:4px 0 0;display:grid;gap:0;border-top:1px dashed var(--line)}
.facts2 div{display:grid;gap:2px;padding:10px 0;border-bottom:1px dashed var(--line)}
.facts2 dt{font-size:12.5px;font-weight:600;color:var(--muted);letter-spacing:.03em}
.facts2 dd{margin:0;font-weight:500;overflow-wrap:anywhere}
.steps{list-style:none;margin:0;padding:0;counter-reset:step;display:grid;gap:22px}
.steps>li{counter-increment:step;display:grid;grid-template-columns:40px minmax(0,1fr);gap:14px}
.steps>li::before{content:counter(step);width:40px;height:40px;border-radius:50%;background:var(--cta);color:#fff;display:grid;
  place-items:center;font:700 18px/1 var(--font-display)}
.steps h3{font-size:19px;font-weight:700;margin-top:6px}
.steps p{margin-top:6px;color:var(--ink-2)}
.steps a,.note a,.devices a,.live a,.faq a,.stuck a{color:var(--brand-ink)}
code,kbd{font:500 .92em/1.4 'IBM Plex Mono',ui-monospace,monospace;background:var(--cream);border-radius:6px;padding:1px 6px;
  overflow-wrap:anywhere}
kbd{border:1px solid var(--line);border-bottom-width:2px;background:#fff}
.cmd{position:relative;margin-top:12px;background:var(--espresso);border-radius:14px;box-shadow:var(--shadow-sm)}
.cmd-head{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:8px 8px 0 16px}
.cmd-lang{font:600 12px/1 'IBM Plex Mono',ui-monospace,monospace;color:#D9C4B4;letter-spacing:.06em;text-transform:uppercase}
.copy{font:600 13px/1 var(--font-body);color:var(--espresso);background:var(--mustard);border:0;border-radius:99px;padding:8px 14px;cursor:pointer}
.copy:hover{background:#FFD56E}
.cmd pre{margin:0;padding:10px 16px 16px;overflow-x:auto}
.cmd pre code{background:none;padding:0;color:#FFE7D1;font-size:14px;line-height:1.65;white-space:pre-wrap;overflow-wrap:anywhere}
.ok{display:flex;gap:12px;align-items:flex-start;margin-top:26px;background:var(--basil-bg);color:#14532D;border-radius:16px;padding:14px 16px}
.ok i{font-style:normal;font-size:20px;line-height:1.3}
.ok b{color:#0F3D22}
.after{margin-top:26px}
.after h3{font-size:18px;font-weight:700;margin-bottom:10px}
.after dl{margin:0;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
.after dl.n3{grid-template-columns:repeat(3,minmax(0,1fr))}
.after dl div{background:var(--bg);border:1px solid var(--line);border-radius:14px;padding:12px 14px}
.after dt{font-weight:600}
.after dd{margin:4px 0 0;color:var(--ink-2);font-size:14.5px;line-height:1.5;overflow-wrap:anywhere}
.note{margin-top:18px;font-size:14.5px;color:var(--muted)}

.tbl{width:100%;border-collapse:separate;border-spacing:0;background:var(--paper);border:1px solid var(--line);border-radius:18px;
  overflow:hidden;box-shadow:var(--shadow-sm)}
.tbl th,.tbl td{text-align:left;padding:13px 16px;vertical-align:top;border-bottom:1px solid var(--line)}
.tbl tr:last-child td{border-bottom:0}
.tbl th{background:var(--cream);font-size:13.5px;font-weight:600;color:var(--ink-2)}
.tbl td:first-child{font-weight:600}
.tbl td:last-child{color:var(--ink-2)}
.devices{margin-top:18px;display:flex;gap:14px;align-items:flex-start;background:var(--cream);border-radius:18px;padding:16px 18px}
.devices i{font-style:normal;font-size:24px}
.devices b{display:block;font-family:var(--font-display);font-size:17px;margin-bottom:2px}
.devices p{color:var(--ink-2);font-size:15px}

.live{background:var(--espresso);color:#F6E9DE;border-radius:28px;padding:clamp(22px,4vw,44px);display:grid;
  grid-template-columns:minmax(0,1fr) minmax(0,1.3fr);gap:clamp(20px,4vw,48px)}
.live .kick{color:var(--mustard)}
.live h2{font-size:clamp(26px,3.2vw,36px);font-weight:800;text-wrap:balance}
.live .sub{margin-top:12px;color:#D9C4B4}
.live ul{list-style:none;margin:0;padding:0;display:grid;gap:12px}
.live li{display:grid;grid-template-columns:24px minmax(0,1fr);gap:12px;align-items:start;background:#2C1B12;border:1px solid #3A2418;
  border-radius:14px;padding:13px 14px;line-height:1.55}
.live li::before{content:"";width:20px;height:20px;margin-top:3px;border:2px solid var(--mustard);border-radius:6px}
.live code{background:#3A2418;color:#FFE7D1}
.live a{color:var(--mustard)}
.live .more{margin-top:14px;font-size:14.5px;color:#D9C4B4}

.faq{display:grid;gap:10px}
.faq details{background:var(--paper);border:1px solid var(--line);border-radius:16px}
.faq details[open]{border-color:var(--brand);box-shadow:var(--shadow-sm)}
.faq summary{cursor:pointer;list-style:none;display:flex;justify-content:space-between;align-items:center;gap:14px;
  padding:15px 18px;font-weight:600}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:"+";flex:none;width:28px;height:28px;border-radius:50%;background:var(--cream);color:var(--brand-ink);
  display:grid;place-items:center;font-size:20px;line-height:1}
.faq details[open] summary::after{content:"–"}
.faq details p{padding:0 18px 16px;color:var(--ink-2)}
.stuck{margin-top:22px;display:flex;flex-wrap:wrap;gap:6px 14px;align-items:baseline;background:var(--cream);border-radius:18px;padding:16px 18px}
.stuck b{font-family:var(--font-display);font-size:18px}

@media (max-width:1080px){
  .paths{grid-template-columns:repeat(2,1fr)}
}
@media (max-width:900px){
  .guide,.live{grid-template-columns:minmax(0,1fr)}
  .guide-side{position:static}
  .after dl.n3{grid-template-columns:repeat(2,minmax(0,1fr))}
}
@media (max-width:620px){
  .paths{grid-template-columns:1fr}
  .after dl,.after dl.n3{grid-template-columns:1fr}
  .tbl thead{display:none}
  .tbl,.tbl tbody,.tbl tr,.tbl td{display:block;width:100%}
  .tbl tr{border-bottom:1px solid var(--line);padding:6px 0}
  .tbl tr:last-child{border-bottom:0}
  .tbl td{border:0;padding:6px 16px;display:grid;grid-template-columns:7.5em minmax(0,1fr);gap:10px}
  .tbl td::before{content:attr(data-label);font-size:12.5px;font-weight:600;color:var(--muted)}
  .steps>li{grid-template-columns:34px minmax(0,1fr);gap:12px}
  .steps>li::before{width:34px;height:34px;font-size:16px}
}
"""

# ปุ่มคัดลอกคำสั่ง — ซ่อนไว้ก่อน เปิดเฉพาะเบราว์เซอร์ที่คัดลอกได้จริง (ไม่มี JS ก็ยังเลือกข้อความเองได้)
INSTALL_JS = (
    "document.querySelectorAll('.copy').forEach(function(b){if(!navigator.clipboard)return;b.hidden=false;"
    "b.addEventListener('click',function(){navigator.clipboard.writeText(b.closest('.cmd').querySelector('code').textContent)"
    ".then(function(){b.textContent=b.dataset.done;setTimeout(function(){b.textContent=b.dataset.label},1800)})})})"
)


def install_header(c, ic):
    langs = []
    for code, label, href in (('th', 'ไทย', INSTALL_PAGES[0]), ('en', 'EN', INSTALL_PAGES[1]), ('ko', '한국어', INSTALL_PAGES[2])):
        current = ' aria-current="page"' if code == ic['code'] else ''
        cls = ' class="ko"' if code == 'ko' else ''
        langs.append(f'<a href="{href}" hreflang="{code}" lang="{code}"{cls}{current}>{label}</a>')
    links = f'<a class="home" href="{ic["home"]}">← {e(ic["home_label"])}</a>' + ''.join(
        f'<a href="{href}">{e(label)}</a>' for href, label in ic['nav']
    )
    return f"""<a class="skip" href="#choose">{e(ic['skip'])}</a>
<header class="site"><div class="wrap nav">
  <a class="brand" href="{ic['home']}" aria-label="PaynEat POS">{LOGO}<span>PaynEat</span><small>POS</small></a>
  <nav class="links" aria-label="{e(c['nav_label'])}">{links}</nav>
  <div class="lang" role="navigation" aria-label="{e(c['lang_label'])}">{''.join(langs)}</div>
  <a class="cart" href="{DEMO}">🖥 {e(c['cart'])}</a>
</div></header>"""


def cmd_block(ic, code, lang):
    return (
        f'<div class="cmd"><div class="cmd-head"><span class="cmd-lang">{e(lang)}</span>'
        f'<button class="copy" type="button" hidden aria-live="polite" data-label="{e(ic["copy"])}" data-done="{e(ic["copied"])}">'
        f'{e(ic["copy"])}</button></div><pre><code>{e(code)}</code></pre></div>'
    )


def install_hero(ic):
    h = ic['hero']
    chips = ''.join(f'<li>{e(chip)}</li>' for chip in h['chips'])
    return f"""<section class="ghero" id="top"><div class="wrap"><div class="panel">
  <p class="crumb"><a href="{ic['home']}">PaynEat POS</a><span aria-hidden="true">/</span><span>{e(h['kick'])}</span></p>
  <h1>{e(h['title'])}</h1>
  <p class="lead">{e(h['lead'])}</p>
  <ul class="chips">{chips}</ul>
</div></div></section>"""


def install_choose(ic):
    ch = ic['choose']
    t_label, n_label, w_label = ch['labels']
    cards = []
    for p in ic['paths']:
        rec = p.get('recommended')
        flag = f'<span class="flag">{e(ch["recommended"])}</span>' if rec else ''
        cards.append(
            f'<li class="path{" rec" if rec else ""}">{flag}<span class="ico" aria-hidden="true">{p["icon"]}</span>'
            f'<h3>{e(p["name"])}</h3><dl class="meta">'
            f'<div><dt>{e(t_label)}</dt><dd>{e(p["time"])}</dd></div>'
            f'<div><dt>{e(n_label)}</dt><dd>{e(p["need"])}</dd></div>'
            f'<div><dt>{e(w_label)}</dt><dd>{e(p["who"])}</dd></div></dl>'
            f'<a class="go-btn" href="{p["href"]}">{e(p["cta"])} <span aria-hidden="true">→</span></a></li>'
        )
    return f"""<section class="section" id="choose" aria-labelledby="choose-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(ch['kick'])}</span><h2 id="choose-h">{e(ch['title'])}</h2></div><p>{e(ch['sub'])}</p></div>
  <ul class="paths">{''.join(cards)}</ul>
</div></section>"""


def install_section(ic, sec):
    facts = ''.join(f'<div><dt>{e(k)}</dt><dd>{e(v)}</dd></div>' for k, v in sec['facts'])
    steps = []
    for st in sec['steps']:
        body = f'<p>{st["html"]}</p>' if st.get('html') else ''
        block = cmd_block(ic, st['code'], st['lang']) if st.get('code') else ''
        steps.append(f'<li><div><h3>{e(st["title"])}</h3>{body}{block}</div></li>')
    after = ''.join(f'<div><dt>{e(k)}</dt><dd>{v}</dd></div>' for k, v in sec['after'])
    hid = f'{sec["id"]}-h'
    return f"""<section class="section" id="{sec['id']}" aria-labelledby="{hid}"><div class="wrap"><div class="guide">
  <div class="guide-side">
    <span class="ico" aria-hidden="true">{sec['icon']}</span>
    <div><span class="kick">{e(sec['kick'])}</span><h2 id="{hid}">{e(sec['title'])}</h2></div>
    <p>{e(sec['intro'])}</p>
    <dl class="facts2">{facts}</dl>
  </div>
  <div>
    <ol class="steps">{''.join(steps)}</ol>
    <p class="ok"><i aria-hidden="true">✅</i><span>{sec['ok_html']}</span></p>
    <div class="after"><h3>{e(sec['after_title'])}</h3><dl{' class="n3"' if len(sec['after']) == 3 else ''}>{after}</dl></div>
    <p class="note">{sec['note_html']}</p>
  </div>
</div></div></section>"""


def install_accounts(ic):
    a = ic['accounts']
    cols = a['cols']
    rows = ''.join(
        f'<tr><td data-label="{e(cols[0])}">{e(role)}</td><td data-label="{e(cols[1])}"><code>{user}</code></td>'
        f'<td data-label="{e(cols[2])}"><code>{pw}</code></td><td data-label="{e(cols[3])}">{e(sees)}</td></tr>'
        for (role, sees), (user, pw) in zip(a['rows'], ACCOUNTS)
    )
    head = ''.join(f'<th scope="col">{e(col)}</th>' for col in cols)
    return f"""<section class="section" id="accounts" aria-labelledby="acc-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(a['kick'])}</span><h2 id="acc-h">{e(a['title'])}</h2></div><p>{e(a['sub'])}</p></div>
  <table class="tbl"><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table>
  <div class="devices"><i aria-hidden="true">📱</i><div><b>{e(a['devices_title'])}</b><p>{a['devices_html']}</p></div></div>
</div></section>"""


def install_live(ic):
    lv = ic['live']
    items = ''.join(f'<li><span>{item}</span></li>' for item in lv['items_html'])
    return f"""<section class="section" id="live" aria-labelledby="live-h"><div class="wrap"><div class="live">
  <div><span class="kick">{e(lv['kick'])}</span><h2 id="live-h">{e(lv['title'])}</h2><p class="sub">{e(lv['sub'])}</p>
    <p class="more">{lv['more_html']}</p></div>
  <ul>{items}</ul>
</div></div></section>"""


def install_help(ic):
    h = ic['help']
    rows = ''.join(f'<details><summary><span>{q}</span></summary><p>{a}</p></details>' for q, a in h['rows'])
    return f"""<section class="section" id="help" aria-labelledby="help-h"><div class="wrap">
  <div class="head"><div><span class="kick">{e(h['kick'])}</span><h2 id="help-h">{e(h['title'])}</h2></div></div>
  <div class="faq">{rows}</div>
  <p class="stuck"><b>{e(h['stuck_title'])}</b><span>{h['stuck_html']}</span></p>
</div></section>"""


def install_page(c, ic):
    body = ''.join([
        install_header(c, ic),
        '<main>',
        install_hero(ic),
        install_choose(ic),
        ''.join(install_section(ic, sec) for sec in ic['sections']),
        install_accounts(ic),
        install_live(ic),
        install_help(ic),
        '</main>',
        footer(c, home=ic['home']),
    ])
    return document(ic['code'], ic['file'], INSTALL_PAGES, ic['title'], ic['description'], c['og_image'], body,
                    css=CSS + INSTALL_CSS, script=INSTALL_JS)


# ---------------------------------------------------------------------------------------------
# หน้า "นโยบายความเป็นส่วนตัว" (docs/landing/privacy*.html) — URL ที่กรอกใน Google Play Console (ticket 29a, DECISIONS #75)
# เนื้อหาอยู่ที่ privacy_content.py ใช้ header/hero/footer ชุดเดียวกับคู่มือติดตั้ง

PRIVACY_PAGES = ('privacy.html', 'privacy.en.html', 'privacy.ko.html')

PRIVACY_CSS = r"""
/* ---- นโยบายความเป็นส่วนตัว ---- */
.ghero .updated{margin-top:18px;font-size:14.5px;color:var(--muted)}
.policy{max-width:46em;display:grid;gap:clamp(22px,3vw,30px)}
.policy section{background:var(--paper);border:1px solid var(--line);border-radius:var(--radius);padding:clamp(20px,3vw,30px);
  box-shadow:var(--shadow-sm)}
.policy h2{font-size:clamp(21px,2.4vw,26px);font-weight:700;text-wrap:balance}
.policy p,.policy ul{margin:12px 0 0;color:var(--ink-2)}
.policy ul{padding-left:1.25em;display:grid;gap:6px}
.policy b{color:var(--ink)}
.policy a{color:var(--brand-ink)}
"""


def privacy_header(c, pc):
    langs = []
    for code, label, href in (('th', 'ไทย', PRIVACY_PAGES[0]), ('en', 'EN', PRIVACY_PAGES[1]), ('ko', '한국어', PRIVACY_PAGES[2])):
        current = ' aria-current="page"' if code == pc['code'] else ''
        cls = ' class="ko"' if code == 'ko' else ''
        langs.append(f'<a href="{href}" hreflang="{code}" lang="{code}"{cls}{current}>{label}</a>')
    return f"""<a class="skip" href="#policy">{e(pc['skip'])}</a>
<header class="site"><div class="wrap nav">
  <a class="brand" href="{pc['home']}" aria-label="PaynEat POS">{LOGO}<span>PaynEat</span><small>POS</small></a>
  <nav class="links" aria-label="{e(c['nav_label'])}"><a class="home" href="{pc['home']}">← {e(pc['home_label'])}</a></nav>
  <div class="lang" role="navigation" aria-label="{e(c['lang_label'])}">{''.join(langs)}</div>
  <a class="cart" href="{DEMO}">🖥 {e(c['cart'])}</a>
</div></header>"""


def privacy_block(item):
    """ย่อหน้าเป็น str (HTML), รายการเป็น list ของ str (HTML)"""
    if isinstance(item, list):
        return '<ul>' + ''.join(f'<li>{li}</li>' for li in item) + '</ul>'
    return f'<p>{item}</p>'


def privacy_page(c, pc):
    chips = ''.join(f'<li>{e(chip)}</li>' for chip in pc['chips'])
    sections = ''.join(
        f'<section id="{sid}" aria-labelledby="{sid}-h"><h2 id="{sid}-h">{e(title)}</h2>'
        + ''.join(privacy_block(item) for item in items) + '</section>'
        for sid, title, items in pc['sections']
    )
    body = ''.join([
        privacy_header(c, pc),
        '<main>',
        f"""<section class="ghero" id="top"><div class="wrap"><div class="panel">
  <p class="crumb"><a href="{pc['home']}">PaynEat POS</a><span aria-hidden="true">/</span><span>{e(pc['kick'])}</span></p>
  <h1>{e(pc['heading'])}</h1>
  <p class="lead">{e(pc['lead'])}</p>
  <ul class="chips">{chips}</ul>
  <p class="updated">{e(pc['updated_label'])} {e(pc['updated'])}</p>
</div></div></section>""",
        f'<section class="section" id="policy"><div class="wrap"><article class="policy">{sections}</article></div></section>',
        '</main>',
        footer(c, home=pc['home']),
    ])
    return document(pc['code'], pc['file'], PRIVACY_PAGES, pc['title'], pc['description'], c['og_image'], body,
                    css=CSS + INSTALL_CSS + PRIVACY_CSS)


README_START = '<!-- stories:start -->'
README_END = '<!-- stories:end -->'
README_WIDTH = {'phone': 220, 'tablet': 560, 'desktop': 560}


def readme_images(c, shots):
    """ภาพของแต่ละเรื่องใน README — 2 ภาพวางคู่กัน (GitHub ไม่มี CSS จึงคุมได้แค่ความกว้าง)"""
    tags = []
    for scene, kind, alt, _ in shots:
        width = README_WIDTH[kind] if len(shots) > 1 else {'phone': 260, 'tablet': 720, 'desktop': 720}[kind]
        if len(shots) == 2 and kind == 'desktop' and shots[1][1] != 'phone':
            width = 420
        tags.append(f'<img src="docs/landing/img/story/{c["shot"]}-{scene}.webp" width="{width}" alt="{e(alt)}">')
    return '<p align="center">\n  ' + '\n  '.join(tags) + '\n</p>'


def readme_block(c):
    r = c['readme']
    L = c['labels']
    rows = '\n'.join(
        f"| {i} | {s['emoji']} {s['chip']} | {' · '.join(s['tags'])} | {s['outcome']} |"
        for i, s in enumerate(c['stories'], start=1)
    )
    stories_md = []
    for i, s in enumerate(c['stories'], start=1):
        features = '\n'.join(f'- **{name}** — {text}' for name, text in s['features'])
        steps = ' → '.join(s['try'])
        extra = f"\n\n{r['label_note']}" if 'label' in s else ''
        stories_md.append(
            f"### {i}. {s['emoji']} {s['title']}\n\n"
            f"{readme_images(c, s['shots'])}\n\n"
            f"**{L['problem']}** — {s['problem']}\n\n"
            f"**{L['inside']}**\n\n{features}\n\n"
            f"✅ **{s['outcome']}**  \n"
            f"🧪 **{L['try']}:** {steps}{extra}"
        )
    return (
        f"{README_START}\n"
        '<!-- สร้างจาก docs/generator/landing/content.py (ชุดเดียวกับหน้า Landing) — แก้ที่นั่นแล้วรัน '
        'python3 docs/generator/landing/build_landing.py อย่าแก้ส่วนนี้ตรง ๆ -->\n\n'
        f"## {r['title']}\n\n{r['intro']}\n\n"
        f"| # | {r['cols'][0]} | {r['cols'][1]} | {r['cols'][2]} |\n|---|---|---|---|\n{rows}\n\n"
        + '\n\n'.join(stories_md)
        + f"\n\n{README_END}"
    )


def update_readme(c):
    path = ROOT / c['readme']['file']
    text = path.read_text(encoding='utf-8')
    if README_START not in text or README_END not in text:
        raise SystemExit(f"{path.name}: ไม่พบ {README_START} … {README_END} — ใส่ marker ตรงที่ต้องการให้หัวข้อนี้อยู่ก่อน")
    head, rest = text.split(README_START, 1)
    _, tail = rest.split(README_END, 1)
    block = readme_block(c).replace('{tests}', f'{TESTS:,}')
    path.write_text(head + block + tail, encoding='utf-8')
    print(f"{c['readme']['file']}  หัวข้อเมนูแก้ปัญหา {len(c['stories'])} เรื่อง")


def sitemap():
    """sitemap.xml ของทุกหน้าที่ควรติด index พร้อมลิงก์ภาษาอื่น — ไม่ใส่ lastmod เพราะไม่มีวันที่แก้เนื้อหาที่เชื่อถือได้
    (lastmod ที่ไม่ตรงจริงถูก search engine เมินอยู่แล้ว) ไม่ใส่ app/ เพราะเป็นแอป Flutter ที่ไม่มีข้อความใน HTML"""
    entries = []
    for pages in (PAGES, INSTALL_PAGES, PRIVACY_PAGES):
        links = ''.join(
            f'\n    <xhtml:link rel="alternate" hreflang="{lang}" href="{url_of(other)}"/>'
            for lang, other in zip(('th', 'en', 'ko', 'x-default'), (*pages, pages[1]))
        )
        entries += [f'  <url>\n    <loc>{url_of(file)}</loc>{links}\n  </url>' for file in pages]
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!-- สร้างจาก docs/generator/landing/build_landing.py — อย่าแก้ตรง ๆ -->\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
        + '\n'.join(entries)
        + '\n</urlset>\n'
    )
    (OUT / 'sitemap.xml').write_text(xml, encoding='utf-8')
    print(f'docs/landing/sitemap.xml  {len(entries)} URL')


def main():
    for c in LANGS:
        html = page(c).replace('{tests}', f'{TESTS:,}')
        (OUT / c['file']).write_text(html, encoding='utf-8')
        print(f"docs/landing/{c['file']}  {len(html.encode('utf-8')) // 1024} KB")
        update_readme(c)
    for c, ic in zip(LANGS, INSTALL_LANGS):
        html = install_page(c, ic)
        (OUT / ic['file']).write_text(html, encoding='utf-8')
        print(f"docs/landing/{ic['file']}  {len(html.encode('utf-8')) // 1024} KB")
    for c, pc in zip(LANGS, PRIVACY_LANGS):
        html = privacy_page(c, pc)
        (OUT / pc['file']).write_text(html, encoding='utf-8')
        print(f"docs/landing/{pc['file']}  {len(html.encode('utf-8')) // 1024} KB")
    sitemap()


if __name__ == '__main__':
    main()
